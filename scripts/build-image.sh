#!/bin/bash
# Zaforge — construit l'image SD GOLDEN « flash & go » (Couche B : 3 partitions boot/root/data +
# overlay root-ro au boot). À lancer EN ROOT sur la VM de build (Debian + parted/e2fsprogs/xz +
# qemu-user-static + binfmt ARM flag F).
#
# L'app est PRÉ-INSTALLÉE dans l'image via un CHROOT au build (install.sh est conçu pour ce contexte
# « chroot image-build »). Le client FLASHE et BOOTE : PLUS d'install de ~45 min ni de RJ45 requis
# chez lui. Le durcissement (overlayroot) est aussi baké -> le 1er boot est 100% HORS-LIGNE.
#
# Sortie : $WORK/zaforge-trixie-<ts>.img.gz
#
# Modèle :
#   BUILD  : partition hors-ligne -> chroot qemu -> install.sh --auto (en 'pi') + bake overlayroot
#            -> bake-strip (neutralise l'identité par-device)
#   1er BOOT client (HORS-LIGNE) : firstboot (identité: hostname/mdp admin/AP) -> harden (grow /data +
#            overlay root-ro) -> reboot -> AP onboarding (le client choisit SON WiFi + code d'enrôlement)
set -euo pipefail

BASE_URL="${BASE_URL:-https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2026-06-19/2026-06-18-raspios-trixie-arm64.img.xz}"
WORK="${WORK:-/home/zaforge/imgbuild}"
ROOT_MB="${ROOT_MB:-10240}"     # root read-only : doit contenir l'install bakée (php/nginx/go/chromium...)
DATA_MB="${DATA_MB:-2048}"      # /data initial (app+config ; agrandi au 1er boot pour remplir la SD)
BRANCH="${BRANCH:-feature/zaforge}"
GHRAW="https://raw.githubusercontent.com/elkir0/Pi-Signage/${BRANCH}"
PI_PASS="${PI_PASS:-palmer00}"  # mdp du user 'pi'
TS="$(date +%Y%m%d-%H%M)"
IMG="$WORK/work-$TS.img"
OUT="$WORK/zaforge-trixie-$TS.img"

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"   # scripts/ du dépôt
REPO_DIR="$(dirname "$SCRIPTS_DIR")"           # racine du dépôt (contient install.sh)
[ "$(id -u)" = "0" ] || { echo "lancer en root" >&2; exit 1; }
[ -f "$REPO_DIR/install.sh" ] || { echo "install.sh introuvable ($REPO_DIR/install.sh)" >&2; exit 1; }
command -v qemu-aarch64-static >/dev/null || { echo "qemu-aarch64-static requis (chroot ARM)" >&2; exit 1; }
mkdir -p "$WORK"
LOG="$WORK/build-$TS.log"; exec > >(tee -a "$LOG") 2>&1
echo "================ build-image $TS ================"

cleanup() {
    set +e
    if [ -n "${MNT:-}" ]; then
        umount -R -l "$MNT/run" "$MNT/dev" "$MNT/sys" "$MNT/proc" "$MNT/opt/pisignage" 2>/dev/null
        umount -l "$MNT/boot/firmware" 2>/dev/null
        umount -R -l "$MNT" 2>/dev/null
    fi
    [ -n "${MNTD:-}" ] && umount -l "$MNTD" 2>/dev/null
    [ -n "${LOOP:-}" ] && losetup -d "$LOOP" 2>/dev/null
}
trap cleanup EXIT
MNT="$WORK/mnt"; MNTD="$WORK/mnt-data"; mkdir -p "$MNT" "$MNTD"

# HYGIÈNE pré-build : purger les résidus d'un build précédent avorté (montages EMPILÉS sur mnt + loops
# orphelins). Sans ça le nouveau mount s'empile et le umount final échoue "target is busy" (bug vécu :
# l'image était bonne mais la compression ne se lançait pas).
for _ in 1 2 3; do umount -R -l "$MNT" 2>/dev/null; done
umount -l "$MNTD" 2>/dev/null || true
losetup -j "$WORK"/work-*.img 2>/dev/null | cut -d: -f1 | xargs -r losetup -d 2>/dev/null || true

# --- 1) Base image (cache) ---
BASEXZ="$WORK/$(basename "$BASE_URL")"
[ -f "$BASEXZ" ] || { echo "DL base..."; wget -q -O "$BASEXZ" "$BASE_URL"; }
echo "décompression base -> $IMG"; xz -dc "$BASEXZ" > "$IMG"

# --- 2) Agrandir root (l'install bakée y écrit php/nginx/go/...) puis /data. Grow only (sûr). ---
LOOP="$(losetup -fP --show "$IMG")"; sleep 1
echo "loop=$LOOP"; lsblk "$LOOP"
P2_START_MIB="$(parted -ms "$IMG" unit MiB print | awk -F: '/^2:/{gsub(/MiB/,"",$2); print int($2)}')"
losetup -d "$LOOP"; LOOP=""
P2_END=$((P2_START_MIB + ROOT_MB))
P3_END=$((P2_END + DATA_MB))
echo "p2(root): ${P2_START_MIB}..${P2_END} MiB ; p3(data): ${P2_END}..${P3_END} MiB"

# --- 3) Agrandir le fichier image, la partition root, créer /data ---
truncate -s "$((P3_END + 16))M" "$IMG"
parted -s "$IMG" unit MiB resizepart 2 "${P2_END}"
parted -s "$IMG" unit MiB mkpart primary ext4 "${P2_END}" "${P3_END}"
parted -ms "$IMG" unit MiB print free || true

# --- 4) Grandir fs root + mkfs /data ---
LOOP="$(losetup -fP --show "$IMG")"; sleep 1
e2fsck -fy "${LOOP}p2" || true
resize2fs "${LOOP}p2"
mkfs.ext4 -F -L ZFDATA "${LOOP}p3"
DATA_UUID="$(blkid -s UUID -o value "${LOOP}p3")"
echo "data uuid=$DATA_UUID"

# --- 5) Monter + customiser ---
mount "${LOOP}p2" "$MNT"
mount "${LOOP}p1" "$MNT/boot/firmware"
mount "${LOOP}p3" "$MNTD"

# 5a) Layout /data (préserver la conf ssh sinon le bind la masque)
mkdir -p "$MNTD/pisignage" "$MNTD/etc/NetworkManager/system-connections"
cp -a "$MNT/etc/ssh" "$MNTD/etc/ssh"
mkdir -p "$MNT/data" "$MNT/opt/pisignage"

# 5b) fstab : /data + binds (root reste RW jusqu'à l'activation overlay par firstboot-harden)
cat >> "$MNT/etc/fstab" <<FSTAB
# --- Zaforge Couche B : data persistant + binds (avant activation overlay) ---
UUID=${DATA_UUID}  /data  ext4  defaults,noatime,nofail  0  2
/data/pisignage  /opt/pisignage  none  bind  0  0
/data/etc/ssh    /etc/ssh         none  bind  0  0
/data/etc/NetworkManager/system-connections  /etc/NetworkManager/system-connections  none  bind  0  0
FSTAB

# 5c) Helpers de durcissement / maintenance
install -m 0755 "$SCRIPTS_DIR/firstboot-harden.sh"   "$MNT/usr/local/sbin/zaforge-firstboot-harden"
install -m 0755 "$SCRIPTS_DIR/zaforge-maintenance.sh" "$MNT/usr/local/sbin/zaforge-maintenance"

# 5d) User 'pi' (existe dans la base RPi OS) + SSH + userconf + NOPASSWD. AVANT le chroot : install.sh
#     tourne en 'pi' (refuse root) et escalade via sudo NON-interactif.
HASH="$(openssl passwd -6 "$PI_PASS")"
echo "pi:${HASH}" > "$MNT/boot/firmware/userconf.txt"
touch "$MNT/boot/firmware/ssh"
install -d -m 0755 "$MNT/etc/sudoers.d"
echo 'pi ALL=(ALL) NOPASSWD: ALL' > "$MNT/etc/sudoers.d/010-pi-nopasswd"
chmod 0440 "$MNT/etc/sudoers.d/010-pi-nopasswd"

# 5e) Service de durcissement 1er boot (grow /data + overlay root-ro). Gardé sur .zaforge-installed
#     (baké par le chroot) + After=zaforge-firstboot (identité posée sur root RW avant l'overlay).
cat > "$MNT/etc/systemd/system/zaforge-firstboot-harden.service" <<UNIT
[Unit]
Description=Zaforge first-boot hardening (grow /data + overlay root-ro)
After=zaforge-firstboot.service
ConditionPathExists=!/data/.zaforge-hardened
ConditionPathExists=/data/.zaforge-installed
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/zaforge-firstboot-harden
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf ../zaforge-firstboot-harden.service "$MNT/etc/systemd/system/multi-user.target.wants/zaforge-firstboot-harden.service"

# 5f) INSTALL EN CHROOT (qemu ARM via binfmt flag F) — l'image sort DÉJÀ INSTALLÉE.
echo "=== install en chroot (qemu ARM) — long (~45 min) ==="
mount --bind "$MNTD/pisignage" "$MNT/opt/pisignage"   # l'app est écrite sur /data (comme au runtime)
mount -t proc proc "$MNT/proc"
mount --rbind /sys "$MNT/sys"
mount --rbind /dev "$MNT/dev"
mount --rbind /run "$MNT/run"
mv "$MNT/etc/resolv.conf" "$MNT/etc/resolv.conf.zfsave" 2>/dev/null || true
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$MNT/etc/resolv.conf"
install -m 0644 "$REPO_DIR/install.sh" "$MNT/tmp/install.sh"
# En chroot qemu, le SETUID ne fonctionne pas (émulation user-mode) -> 'sudo' lancé par un non-root
# NE PEUT PAS escalader ("effective uid is not 0"). On lance donc install.sh EN ROOT (sudo-en-root ne
# requiert pas setuid) via ZF_ALLOW_ROOT=1. En chroot : systemctl enable crée les symlinks (OK),
# start/restart/daemon-reload y sont ignorés (services démarrent au vrai boot). L'ownership de
# /opt/pisignage est normalisée par les chown explicites d'install.sh.
chroot "$MNT" env HOME=/home/pi ZF_ALLOW_ROOT=1 GITHUB_BRANCH="$BRANCH" bash /tmp/install.sh --auto
rm -f "$MNT/tmp/install.sh"

# KIOSK : install.sh écrit la conf kiosk via $HOME (kanshi/labwc/autostart généré par kiosk-apply).
# Lancé en root, $HOME irait dans /root -> on a forcé HOME=/home/pi ci-dessus. De plus install.sh met
# kiosk_url=time.is (défaut générique) -> pour une box signage on pointe sur le PLAYER et on REGÉNÈRE
# l'autostart (kiosk-apply l'avait généré avec time.is), puis on rend .config à pi (droits d'écriture).
echo 'http://127.0.0.1/player' > "$MNT/opt/pisignage/config/kiosk_url"
chroot "$MNT" env HOME=/home/pi bash /opt/pisignage/scripts/kiosk-apply || true
chroot "$MNT" chown -R pi:pi /home/pi/.config 2>/dev/null || true
chroot "$MNT" chown www-data:www-data /opt/pisignage/config/kiosk_url 2>/dev/null || true
chroot "$MNT" rm -rf /home/pi/.cache /home/pi/go 2>/dev/null || true

# 5g) Baker le durcissement HORS-LIGNE : overlayroot (overlay root-ro) + cloud-guest-utils (growpart).
#     Ainsi harden au 1er boot ne fait que conf + update-initramfs (offline), sans apt -> pas de réseau
#     requis chez le client. (overlayroot s'installe DÉSACTIVÉ par défaut ; harden l'active au 1er boot.)
echo "=== bake overlayroot + cloud-guest-utils (durcissement hors-ligne) ==="
chroot "$MNT" env DEBIAN_FRONTEND=noninteractive apt-get install -y overlayroot cloud-guest-utils

# 5h) Neutraliser l'identité par-device (regénérée au 1er boot). bake-strip TANT QUE le bind
#     /opt/pisignage -> /data est ACTIF (nettoie la config applicative sur /data).
bash "$SCRIPTS_DIR/bake-strip.sh" "$MNT" || true
rm -f "$MNTD"/etc/ssh/ssh_host_* 2>/dev/null || true   # host keys actives au runtime (bind /data)
touch "$MNTD/.zaforge-installed"                        # install déjà faite -> gate firstboot + harden

# restaurer resolv.conf + démonter le chroot
rm -f "$MNT/etc/resolv.conf"
mv "$MNT/etc/resolv.conf.zfsave" "$MNT/etc/resolv.conf" 2>/dev/null || true
umount -R "$MNT/run" 2>/dev/null || true
umount -R "$MNT/dev" 2>/dev/null || true
umount -R "$MNT/sys" 2>/dev/null || true
umount "$MNT/proc" 2>/dev/null || true
umount "$MNT/opt/pisignage" 2>/dev/null || true

# 5i) Désactiver le resize auto RPi OS (le token 'resize' du cmdline mangerait /data).
sed -i 's/ resize\b//g; s# init=/usr/lib/raspberrypi-sys-mods/firstboot##; s# init=/usr/lib/raspi-config/init_resize\.sh##' "$MNT/boot/firmware/cmdline.txt" || true
rm -f "$MNT/etc/systemd/system/multi-user.target.wants/rpi-resizerootfs.service" 2>/dev/null || true
rm -f "$MNT/etc/init.d/resize2fs_once" 2>/dev/null || true

echo "--- fstab ---"; tail -6 "$MNT/etc/fstab"
echo "--- cmdline ---"; cat "$MNT/boot/firmware/cmdline.txt"
echo "--- services zaforge (multi-user.wants) ---"; ls -l "$MNT/etc/systemd/system/multi-user.target.wants/" | grep -i zaforge || true
echo "--- .zaforge-installed baké ? ---"; ls -la "$MNTD/.zaforge-installed"
echo "--- overlayroot présent ? ---"; ls "$MNT/usr/sbin/overlayroot-chroot" 2>/dev/null || echo "MANQUANT"
echo "--- app sur /data ? ---"; ls "$MNTD/pisignage" 2>/dev/null | head

sync
# Teardown TOLÉRANT : l'image est déjà écrite -> ne JAMAIS avorter sur un umount busy (lazy en secours).
umount "$MNT/opt/pisignage" 2>/dev/null || true
umount "$MNT/boot/firmware" 2>/dev/null || umount -l "$MNT/boot/firmware" 2>/dev/null || true
umount "$MNTD" 2>/dev/null || umount -l "$MNTD" 2>/dev/null || true
umount "$MNT" 2>/dev/null || umount -R -l "$MNT" 2>/dev/null || true
sync; sleep 1
losetup -d "$LOOP" 2>/dev/null || true
LOOP=""; MNT=""; MNTD=""
trap - EXIT

# --- 6) Finaliser (compression pigz -> .img.gz compatible RPi Imager) ---
mv "$IMG" "$OUT"
# nice/ionice + 1 cœur laissé LIBRE : une image bakée fait ~13G ; sur une petite VM, pigz à fond sur
# tous les cœurs affame sshd (VM injoignable ~15 min, vécu). On garde la VM réactive.
NCPU="$(nproc)"; PZ=$(( NCPU > 1 ? NCPU - 1 : 1 ))
if command -v pigz >/dev/null 2>&1; then
    echo "compression pigz ($PZ/$NCPU threads, nice+ionice) -> ${OUT}.gz"
    nice -n 19 ionice -c3 pigz -p "$PZ" -f "$OUT"
else
    echo "compression gzip -> ${OUT}.gz"; nice -n 19 gzip -f "$OUT"
fi
echo "================ IMAGE PRÊTE : ${OUT}.gz ================"
ls -lh "${OUT}.gz"
