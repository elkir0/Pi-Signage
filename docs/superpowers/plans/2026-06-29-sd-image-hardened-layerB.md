# Plan — Image SD durcie (Couche B : overlay root-ro + /data)

**Spec** : `docs/superpowers/specs/2026-06-29-sd-hardening-readonly-root-design.md`
**Date** : 2026-06-29 · **Branche** : `feature/zaforge`

## Le piège de partitionnement (décision centrale)

On veut 3 partitions : `boot` (FAT) / `root` (ext4, ro via overlay) / `data` (ext4, rw).
Contrainte ext4 : **on peut AGRANDIR une partition montée en ligne, mais JAMAIS la rétrécir
en ligne**. Donc toute stratégie qui « rétrécit root pour caser /data » sur un système booté
est impossible/dangereuse.

**Deux stratégies viables (sans shrink en ligne) :**

### Stratégie 1 — Image 3-partitions pré-bâtie + grow /data au 1er boot (RECOMMANDÉE)
- Un **constructeur d'image** (sdm) produit une `.img` avec DÉJÀ 3 partitions :
  `boot` + `root` (taille fixe ~8-12 Go) + `data` (petite, ex. 1 Go).
- Au 1er boot : on **agrandit `data` (DERNIÈRE partition) pour remplir la SD** → grow du
  dernier partitionnement = **opération online sûre et standard** (aucun shrink, aucun
  déplacement de partition). overlay activé.
- ✅ Sûr (grow last-partition only), ✅ flash = image complète, ✅ pas de repartition risquée
  sur root. ❌ Demande le pipeline sdm (chantier C1).

### Stratégie 2 — Flash RPi OS standard + install.sh + firstboot qui CARVE /data
- Flash image RPi OS standard, `install.sh`, puis un service **firstboot** : désactive le
  resize auto, agrandit root à une cible, **crée `data` dans l'espace libre restant**, monte,
  déplace `/opt/pisignage`, binds, overlay, reboot.
- ✅ Pas de pipeline d'image. ❌ Opérations parted/partprobe sur le **disque root monté**
  (création de partition + grow root online) = plus fragile, partprobe capricieux sur root
  monté, plus de cas d'erreur à mi-chemin.

**Recommandation : Stratégie 1** (sdm, image 3-part, grow /data last au boot) — c'est la
seule qui évite toute opération risquée sur le root monté.

## Layout cible (Stratégie 1)

```
p1 boot  FAT32   ~512M   ro (firmware/kernel/cmdline)
p2 root  ext4    ~10G    READ-ONLY via overlay (tmpfs upper en RAM)
p3 data  ext4    reste   READ-WRITE persistant
```

`/data` contient : `/opt/pisignage` (bind → /opt/pisignage : code, media, playlists, config)
+ binds : `/etc/NetworkManager/system-connections` (WiFi) + `/etc/ssh` (clés hôte).
tmpfs : /var/log (journald volatile déjà), cache Chromium (déjà /run), /tmp (déjà).

## Étapes d'implémentation

1. **Pipeline sdm** (`scripts/build-image.sh`) : base RPi OS Trixie Lite/Desktop → applique
   `install.sh` (chroot) → repartitionne en 3 (root taille fixe + data 1G) → sort `zaforge-vX.img`.
   - Décision build host : Docker-Mac + VM600 (cf. mémoire onboarding).
2. **`scripts/firstboot-harden.sh`** (oneshot systemd, idempotent, marker `.hardened`) :
   - grow p3 (data) pour remplir la SD (`parted resizepart 3 100%` + `resize2fs`) — last-part, sûr.
   - si pas déjà fait : `rsync /opt/pisignage → /data/pisignage`, écrire fstab (bind /opt/pisignage,
     bind NM, bind SSH), poser le marker.
   - **overlay activé EN DERNIER** (`raspi-config nonint do_overlayfs 0`), puis reboot.
   - Ordre = si une étape échoue AVANT l'overlay, root reste rw → box récupérable.
3. **`zaforge-maintenance on|off`** : désactive/réactive l'overlay (root rw) + reboot, pour les
   MAJ apt rares. Déploiement app normal (scp dans /opt/pisignage=/data) = PAS de maintenance.
4. **fstab / mounts** : `/data` (PARTLABEL/UUID), binds via fstab `x-systemd` ou unités mount +
   tmpfiles pour recréer l'arbo tmpfs au boot.
5. **install.sh** : flag `ENABLE_READONLY_ROOT`, installe firstboot-harden.service (enabled),
   ne fait RIEN de destructif lui-même (toute la partition au firstboot/au build).

## Protocole de test (proprio, ÉCRAN + CLAVIER branchés)

1. Flash `zaforge-vX.img` sur **SD neuve** → boot → firstboot-harden grow /data + overlay + reboot.
2. `mount` : `/` ro (overlay), `/data` rw, `/opt/pisignage` = bind /data. `df` : /data remplit la SD.
3. Persistance : WiFi (re-onboard), clés SSH stables, upload média → **survit au reboot**.
4. **Pull-the-plug ×10** (pendant lecture ET pendant un upload/save config) → **boot propre à
   chaque fois**, web+SSH up, config intacte.
5. Déploiement : `scp` dans `/opt/pisignage/web` marche sans maintenance.
6. `zaforge-maintenance on` → `apt` → `off`.

## Récupération si le boot casse (overlay)

- Écran+clavier : connecté → corriger. OU sortir la SD, éditer `/boot/firmware/cmdline.txt`
  (retirer le hook overlay) sur un autre PC. overlay = réversible.

## Risques

- partprobe/parted sur disque booté (Strat. 2) → évité en Strat. 1 (grow last-part only).
- /data corrompu sur coupure = possible mais NON-fatal (boot garanti root ro) ; écritures app
  atomiques (tempnam+rename).
- sdm/qemu-arm sur Mac : build via VM600 si besoin (cf. build B2).

## Hors scope

- A/B partitions OTA ; f2fs sur /data ; UPS.
