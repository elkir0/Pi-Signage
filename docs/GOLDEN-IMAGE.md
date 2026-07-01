# Image Golden « Flash & Go » (Zaforge)

Image SD **pré-installée, durcie et neutre** pour déploiement client. Le client **flashe la carte,
branche le Pi, et c'est tout** : le 1er boot est **100 % hors-ligne** (pas d'Ethernet, pas d'install
de 45 min) et débouche en ~2 minutes sur l'assistant d'onboarding où le client choisit son WiFi et
lie son compte Zaforge.

> **Historique.** On a d'abord tenté un modèle « install au 1er boot » (l'image ne contenait que
> RPi OS + un service qui lançait `install.sh` au démarrage). Rejeté : exige un réseau filaire (RJ45)
> et ~45 min chez le client. Le modèle actuel **bake l'installation dans l'image au build**.

---

## 1. Expérience client

1. Flasher `zaforge-trixie-<ts>.img.gz` sur une carte SD (Raspberry Pi Imager, `dd`, balenaEtcher…).
2. Insérer la carte, brancher l'écran (HDMI) et l'alimentation. **Aucun réseau requis.**
3. 1er boot (~2 min) : identité par-device → durcissement (overlay) → **reboot** → l'écran affiche
   l'assistant : un **QR code** + un **mot de passe administrateur** + un point d'accès WiFi
   `Zaforge-Setup-XXXX`.
4. Le client scanne le QR avec son téléphone (rejoint l'AP), le **portail captif** s'ouvre :
   - **Étape 1** — WiFi du lieu (SSID + mot de passe).
   - **Étape 2** — mot de passe admin (facultatif, sinon celui affiché à l'écran) + compte Zaforge
     (login e-mail/mdp, ou code d'enrôlement `ZF-XXXX-XXXX-XXXX`).
5. La box se connecte au WiFi, s'enrôle (tunnel WireGuard + MQTT vers le relais), et l'écran bascule
   sur le lecteur (`/player`). Terminé.

L'internet n'est nécessaire **qu'à l'enrôlement**, via le WiFi que le client fournit dans l'assistant.

---

## 2. Construire l'image (build-image.sh)

### Prérequis (VM de build)
- Debian/Ubuntu **x86_64** avec : `parted e2fsprogs xz-utils pigz wget` **+ `qemu-user-static` +
  `binfmt-support`** (binfmt ARM enregistré avec le **flag `F`** → les binaires ARM tournent en chroot
  sans copier qemu dedans). Vérifier : `cat /proc/sys/fs/binfmt_misc/qemu-aarch64` doit exister.
- Le dépôt cloné (le script lit `install.sh` à la racine + `scripts/*`).
- **~15 Go libres** (image de travail décompressée ~13 Go) et de préférence **≥ 4 Go RAM / 2 vCPU**.

### Lancer
```sh
sudo bash scripts/build-image.sh
# Sortie : $WORK/zaforge-trixie-<ts>.img.gz   (WORK par défaut = /home/zaforge/imgbuild)
```
Variables surchargeables : `BASE_URL`, `WORK`, `ROOT_MB` (défaut 10240), `DATA_MB` (défaut 2048),
`BRANCH` (défaut `feature/zaforge`), `PI_PASS` (défaut `palmer00`).

> ⚠️ **Long sous qemu** : l'install tourne en émulation ARM (postinst php/`phpenmod`, build Go…) →
> compter **~45 min à 1 h**. C'est un coût **unique au build**, jamais chez le client.

### Ce que fait le script
1. Décompresse l'image de base RPi OS Trixie, **agrandit root** (10 Go) et **ajoute une partition
   `/data`** (2 Go, agrandie au 1er boot). 3 partitions : `boot / root / data`.
2. `fstab` : monte `/data` + **binds** `/data/pisignage→/opt/pisignage`, `/data/etc/ssh→/etc/ssh`,
   `/data/etc/NetworkManager/system-connections→…`.
3. Crée l'user `pi` (userconf) + **sudoers NOPASSWD** + le service de durcissement 1er boot.
4. **Install en chroot qemu** : lance `install.sh --auto` **dans le rootfs monté** (voir §3).
5. **Bake overlayroot + cloud-guest-utils** (durcissement 1er boot hors-ligne, voir §4).
6. **Neutralise** (`bake-strip.sh`, voir §5) + `touch /data/.zaforge-installed`.
7. Compresse en `.img.gz` (`pigz` en `nice/ionice`, 1 cœur laissé libre).

---

## 3. Install en chroot — les pièges (qemu-user) et leurs correctifs

Ce sont les points **non-évidents** qui rendent l'install-en-chroot fonctionnelle. Tous sont
implémentés dans `build-image.sh` :

| Piège | Correctif |
|---|---|
| **Le setuid ne marche pas sous qemu-user** → `sudo` lancé par un non-root échoue (« effective uid is not 0 »). | On lance `install.sh` **EN root** via **`ZF_ALLOW_ROOT=1`** (override de `check_root` dans install.sh ; sudo-en-root ne requiert pas de setuid). |
| `$HOME` vaut `/root` quand install tourne en root → la conf kiosk (`kanshi`/`labwc`/autostart via `kiosk-apply`, tous en `$HOME/.config`) partirait dans `/root`. | On force **`HOME=/home/pi`** ; après install on **regénère l'autostart** (`kiosk-apply`) et on rend `.config` à `pi`. |
| `install.sh` met `kiosk_url = https://time.is` (défaut générique) → écran ≠ player. | On pose **`kiosk_url = http://127.0.0.1/player`** et on regénère l'autostart. |
| `systemctl start/restart/daemon-reload` sont **ignorés** en chroot (« Running in chroot »). | Sans effet : `systemctl enable` **fonctionne** (crée les symlinks) → les services démarrent au vrai boot. |
| Pas de réseau dans le chroot. | Bind d'un `resolv.conf` (nameservers publics) le temps du chroot, restauré ensuite. |
| L'app irait sur le **root** au lieu de `/data` (le bind runtime la masquerait). | On **bind `/opt/pisignage→/data/pisignage`** pendant le chroot → l'app est écrite sur `/data`, comme au runtime. |

---

## 4. Séquence 1er boot (100 % hors-ligne)

Trois services `systemd` (tous `WantedBy=multi-user.target`), enchaînés par l'ordre + des sentinelles
sur `/data` :

1. **`zaforge-firstboot.service`** → `scripts/firstboot.sh` (gardé par `config/.provisioned`) :
   régénère l'**identité par-device** — hostname `zaforge-<machineid8>`, token agent, secret relais,
   **mot de passe admin aléatoire** (`credentials.json` bcrypt + `.setup-admin-password` affiché à
   l'écran), **host keys SSH** (`ssh-keygen -A`), pays WiFi (BE), dossier d'état agent
   `config/relay/`. Puis lève l'**AP d'onboarding** si non configuré. `ConditionPathExists=/data/.zaforge-installed`.
2. **`zaforge-firstboot-harden.service`** → `scripts/firstboot-harden.sh` (`After=zaforge-firstboot`,
   gardé par `.zaforge-installed` + `!/data/.zaforge-hardened`) :
   - **grow `/data`** à 100 % de la SD réelle (`growpart` en ligne + `resize2fs`).
   - **overlay root-ro** via le paquet **`overlayroot`** (`/etc/overlayroot.conf` = `tmpfs:recurse=0` —
     `recurse=0` garde `/data` + binds persistants) + `update-initramfs` **hors-ligne** (overlayroot
     est **baké** au build → pas d'apt au 1er boot). Puis **reboot**.
   - **Marqueur vérifié** : `.zaforge-hardened` n'est posé qu'**après** confirmation que `/` est bien
     en overlay au reboot suivant (sinon root reste RW, récupérable).
3. Reboot → overlay actif, AP `Zaforge-Setup-XXXX` prêt, `/setup` servi. Onboarding client (§1).

> **En chroot-bake, `.zaforge-installed` est baké** → au 1er boot, install NE tourne PAS (aucun
> service install), et firstboot+harden s'enchaînent directement via l'ordre `multi-user.target`.

### Partitionnement & overlay
- `boot` (vfat, `ro`) · `root` (ext4 10 Go, **overlay tmpfs** au runtime) · `data` (ext4, agrandie).
- Persistant = **`/data` uniquement** (app, config, médias, host keys, connexions WiFi). Le reste du
  root est éphémère (tmpfs) → **écritures SD minimisées**, robuste aux coupures.
- Récupération : `overlayroot=disabled` dans `cmdline.txt` (partition boot, éditable depuis un lecteur
  SD) désactive l'overlay au boot suivant.

---

## 5. Neutralisation (image neutre, identité unique par carte)

`scripts/bake-strip.sh <rootfs>` (lancé au build **pendant que le bind `/opt/pisignage` est actif**)
retire tout état par-device : `agent.json`, `credentials.json`, secret relais, `.provisioned`,
`.onboard*`, `wifi-networks.json`, dossier `relay/`, **host keys SSH** (+ `/data/etc/ssh`),
`machine-id`, connexions NetworkManager du builder, logs. `relay.json` → gabarit non-enrôlé,
`ENABLE_RELAY=0`. Chaque carte flashée régénère donc une **identité unique** au 1er boot.

---

## 6. Vérifier / dépanner une box bootée

Brancher l'Ethernet **uniquement pour vérifier** (la box ne s'en sert pas ; il n'y a plus de service
install). Elle prend un bail DHCP ; SSH `pi` / mot de passe de l'image.

```sh
uptime -p; hostname                       # zaforge-xxxx = identité provisionnée
systemctl list-unit-files 'zaforge-*'     # PAS de zaforge-install (baké)
ls /data/.zaforge-*                        # .zaforge-installed + .zaforge-hardened
findmnt -no FSTYPE /                        # overlay = durci
df -h /data                                # ~taille SD = grow OK
sudo /opt/pisignage/scripts/onboard-ap.sh status   # ap_up=yes avant onboarding
pgrep -af chromium | grep -o 'http[^ ]*'  # http://127.0.0.1/player = kiosk OK
```

Symptômes & causes fréquents :
- **Écran vide (pas de chromium)** : `kiosk_url` ≠ `/player`, ou autostart absent dans
  `/home/pi/.config/labwc/autostart` (droits/HOME). Regénérer : `sudo -u pi env HOME=/home/pi bash
  /opt/pisignage/scripts/kiosk-apply` puis `sudo systemctl restart display-manager`.
- **Root reste RW** (`findmnt / ` = ext4) : overlay non activé — voir `/data/firstboot-harden.log`
  (marqueur `.zaforge-overlay-failed` = échec, root récupérable).
- **Pas d'AP** : `/data/.zaforge-installed` absent → firstboot ne provisionne pas.

---

## 7. Reconstruire après un changement

1. Committer + **pousser** (l'install en chroot clone l'app depuis GitHub `BRANCH`).
2. Sur la VM de build : `git pull` puis relancer `scripts/build-image.sh`.
3. Récupérer `zaforge-trixie-<ts>.img.gz`, vérifier `gzip -t` + `sha256sum`.
4. Flasher une carte de test, booter (Ethernet pour vérif), valider §6, puis onboarding au téléphone.

> ⚠️ **Hygiène VM** : `build-image.sh` purge les montages/loops orphelins d'un build avorté au début
> (sinon montages empilés → `umount` final « target is busy »). Si la VM se fige pendant la
> compression (petite VM saturée), reset via l'hyperviseur ; l'image de travail survit sur le disque
> (finir manuellement : `mv work-*.img …img && pigz`).
