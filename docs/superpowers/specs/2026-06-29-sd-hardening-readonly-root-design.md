# Spec — Durcissement prod : root read-only + réduction d'écritures (fiabilité SD)

**Date** : 2026-06-29
**Branche** : `feature/zaforge`
**Statut** : validé périmètre (proprio : « tout, A+B »), spec à relire avant code

## Problème / objectif

La box de prod a corrompu son stockage **deux fois** (web 500 + sshd kex-reset), y compris
**sur SSD** → la cause n'est PAS l'usure ni le médium, c'est l'**écriture interrompue par une
coupure/sous-voltage**. Objectif : une box Zaforge qui **survit à une coupure de courant
arbitraire sans corruption** (boot propre garanti) ET qui **écrit le moins possible** sur SD.

Principe directeur : rendre les crashs **sans conséquence** (root immuable) plutôt que juste
« écrire moins ». La réduction d'écritures prolonge la durée de vie (usure) ; le **root
read-only (overlayfs)** apporte l'**immunité à la corruption**.

## Architecture cible (image C1/C2)

Partitionnement :
- **p1 `/boot/firmware`** (FAT) — monté **ro** (firmware/kernel/cmdline).
- **p2 `/` (ext4)** — **read-only via overlayfs** au runtime (couche haute = tmpfs en RAM,
  jetée au reboot). Contient l'OS Debian + binaires système. Immuable.
- **p3 `/data` (ext4)** — **read-write persistant**. Porte TOUT l'état applicatif.

Découpage des écritures :
- **Root overlay (ro, RAM jetable)** : OS Debian, nginx, php-fpm, systemd. Aucune écriture
  critique n'y survit — et c'est voulu.
- **tmpfs (éphémère, RAM)** : `/tmp`, `/var/tmp`, `/var/log` (+ journald `Storage=volatile`),
  cache + profil Chromium, `/opt/pisignage/logs`, `web/screenshots`, `/run` (déjà).
- **`/data` (rw persistant)** : **`/opt/pisignage` en entier** (bind-mount `/opt/pisignage`
  → `/data/pisignage`) → code web, `media/`, `playlists/`, `config/`, `data/` tous rw+persistants
  → **les déploiements `scp` et les sauvegardes de config UI continuent de marcher**. Plus les
  états OS qui DOIVENT persister, en bind-mount depuis `/data` :
  - **`/etc/NetworkManager/system-connections`** (identifiants WiFi du multi-wifi) → `/data/etc/NetworkManager/system-connections`
  - **clés d'hôte SSH** `/etc/ssh/ssh_host_*` → `/data/etc/ssh` (sinon l'empreinte change à chaque boot)
  - `/etc/machine-id`, hostname, timezone : fixés à l'install (sur root ro, OK car per-device).

Pourquoi `/opt/pisignage` sur `/data` (et pas sur le root ro) : garde le **déploiement
identique à aujourd'hui** (scp dans `web/`), permet à l'admin d'écrire `config/` et aux médias
d'arriver, tout en gardant **l'OS bootable bulletproof**. Une coupure pendant une écriture
`/data` peut perdre le DERNIER fichier en vol mais **ne casse jamais le boot** (services sur
root ro) ; les écritures app sont déjà **atomiques** (tempnam+rename) → dégâts bornés.

## Inventaire des écritures (routage)

| Écriture | Destination |
|---|---|
| logs système/journald | tmpfs (`Storage=volatile`) |
| logs nginx, `/opt/pisignage/logs` | tmpfs |
| cache/profil Chromium | tmpfs (`/run/chromium-*`) |
| swap | **zram** (RAM compressée), `dphys-swapfile` désactivé |
| `/tmp`, `/var/tmp` | tmpfs |
| screenshots | tmpfs |
| `media/`, `playlists/`, `config/*`, `data/schedules.json` | **/data** (atomique) |
| relay.json, agent.json, relay/enrollment | **/data** (config/) |
| profils WiFi NetworkManager | **/data** (bind /etc/NM/system-connections) |
| clés hôte SSH | **/data** (bind /etc/ssh) |
| `player-state.json`, `player-command.json` | `/run` (transient, pas besoin de persister) |

## Couche A — réduction d'écritures (sûre, déployable sans overlay)

Applicable même SANS overlayfs (utile dès la réinstall, testable vite, faible risque) :
- `journald` : drop-in `Storage=volatile` + `RuntimeMaxUse=32M`.
- `/var/log` en **tmpfs** (la rotation de logs app existe déjà ; logs = diagnostic, non vitaux).
- **swap zram** via `zram-generator` (ou `zram-tools`) ; `systemctl disable dphys-swapfile`.
- **Chromium** (dans `kiosk-apply`) : `--disk-cache-dir=/run/chromium-cache`
  `--disk-cache-size=8388608` + profil/`--user-data-dir` sur tmpfs (kiosk sans état) ;
  `--media-cache-dir=/run/chromium-cache`.
- `noatime` sur `/` et `/data`.
- `/tmp`, `/var/tmp` en tmpfs (drop-ins `tmp.mount` / fstab).

## Couche B — overlayfs root read-only + /data

- Activation overlay : **initramfs overlay** (mécanisme `raspi-config do_overlayfs`, ou
  unité/initramfs custom maîtrisé) → `/` ro + tmpfs upper.
- `/data` créé à la construction d'image (ou `install.sh BUILD_MODE`) ; `/opt/pisignage`
  déplacé puis **bind-mount** depuis `/data/pisignage` (fstab ou unité mount + tmpfiles).
- Binds NM + SSH depuis `/data`.
- Flag `ENABLE_READONLY_ROOT` (rollback facile : désactiver overlay au prochain boot).
- **Helper `zaforge-maintenance on|off`** : `on` = désactive l'overlay (root rw) + reboot pour
  apt/MAJ système rares ; `off` = réactive ro + reboot. Les déploiements app NORMAUX (scp dans
  `/opt/pisignage` = `/data`) ne nécessitent PAS la maintenance (data toujours rw).

## Intégration install.sh / image

- `install.sh` : Couche A toujours appliquée (paquets zram, drop-ins journald/tmp,
  flags Chromium dans `kiosk-apply`, noatime).
- Construction image (C1/C2) : crée `/data`, relocalise `/opt/pisignage`, pose les binds,
  active overlay si `ENABLE_READONLY_ROOT=1`.
- `mount` ro/rw idempotent ; tmpfiles pour recréer l'arbo tmpfs au boot (logs, caches).

## Plan de test (post-reflash, Pi4 + ÉCRAN attaché)

1. **Couche A seule d'abord** : `mount` confirme tmpfs (/var/log, /tmp), zram actif
   (`zramctl`), swap SD absent (`swapon`), cache Chromium dans /run. Lecture OK.
2. **Couche B** (écran branché pour récupération) : root ro (`mount | grep ' / '` → ro/overlay),
   `/data` rw, `/opt/pisignage` = bind /data, WiFi creds + SSH host keys persistent après reboot.
3. **Pull-the-plug ×10** : pendant lecture ET pendant une sauvegarde config UI → **boot propre
   à chaque fois**, web + SSH up, config intacte (dernier write éventuellement perdu, FS sain).
4. **Déploiement** : `scp` dans `/opt/pisignage/web` marche sans maintenance.
5. **MAJ système** : `zaforge-maintenance on` → apt → `off`.

## Risques / mitigations

- **Overlay mal configuré → box non-bootable** : ne JAMAIS activer la Couche B sans écran +
  accès clavier/console (édition `cmdline.txt` pour désactiver l'overlay = recovery). Tester
  d'abord en présence physique. ⚠️ **Ne pas implémenter/activer overlay à l'aveugle à distance.**
- **/data corrompu sur coupure** : possible mais **non-fatal** (boot garanti par root ro) ;
  écritures app atomiques (tempnam+rename) → au pire perte du dernier fichier, FS intact.
  Option dure : `/data` en `data=journal` ou f2fs (à évaluer).
- **WiFi/SSH non persistés** = perte d'accès → couverts par les binds /data (à valider test 2).

## Hors scope (pour l'instant)

- f2fs sur /data ; UPS/HAT d'alim ; A/B partitions OTA. (À considérer plus tard.)

## Pré-requis avant ce chantier

- Pi4 réinstallé sur **SD neuve** + **alim 5V/3A**.
- **Commit + push** du travail de session (music + account + audio robuste) AVANT reflash,
  sinon la box réinstallée ne les aura pas (install.sh clone depuis GitHub).
