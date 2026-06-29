#!/bin/bash
# Zaforge — construit l'image SD DURCIE (Couche B : 3 partitions boot/root/data + overlay au boot).
# À lancer EN ROOT sur la VM de build (Debian + parted/kpartx/e2fsprogs/xz). PAS de chroot/qemu :
# tout le partitionnement délicat (shrink root) se fait HORS-LIGNE sur le fichier .img, le reste
# (install.sh + Couche A + grow /data + overlay) se fait au 1er boot de la box.
#
# Sortie : $WORK/zaforge-trixie-<ts>.img.xz  (à flasher).
#
# Modèle 1er boot (réseau requis, ex. ethernet pour le test) :
#   1) fstab monte /data + binds /opt/pisignage,/etc/ssh,/etc/NetworkManager (root encore RW)
#   2) zaforge-install.service -> install.sh --auto (écrit dans /opt/pisignage = /data) + Couche A
#   3) zaforge-firstboot-harden.service -> agrandit /data (dernière part) + overlay root-ro + reboot
set -euo pipefail

BASE_URL="${BASE_URL:-https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2026-06-19/2026-06-18-raspios-trixie-arm64.img.xz}"
WORK="${WORK:-/home/zaforge/imgbuild}"
ROOT_MB="${ROOT_MB:-10240}"     # taille root cible (read-only) dans l'image
DATA_MB="${DATA_MB:-2048}"      # /data initial (agrandi au 1er boot pour remplir la SD)
BRANCH="${BRANCH:-feature/zaforge}"
GHRAW="https://raw.githubusercontent.com/elkir0/Pi-Signage/${BRANCH}"
PI_PASS="${PI_PASS:-palmer00}"  # mdp du user 'pi' de l'image de test
TS="$(date +%Y%m%d-%H%M)"
IMG="$WORK/work-$TS.img"
OUT="$WORK/zaforge-trixie-$TS.img"

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"   # scripts/ du dépôt (contient firstboot-harden.sh, zaforge-maintenance.sh)
[ "$(id -u)" = "0" ] || { echo "lancer en root" >&2; exit 1; }
mkdir -p "$WORK"
LOG="$WORK/build-$TS.log"; exec > >(tee -a "$LOG") 2>&1
echo "================ build-image $TS ================"

cleanup() { set +e; [ -n "${LOOP:-}" ] && { umount "$MNT/boot/firmware" 2>/dev/null; umount "$MNT" 2>/dev/null; umount "$MNTD" 2>/dev/null; losetup -d "$LOOP" 2>/dev/null; }; }
trap cleanup EXIT
MNT="$WORK/mnt"; MNTD="$WORK/mnt-data"; mkdir -p "$MNT" "$MNTD"

# --- 1) Base image (cache) ---
BASEXZ="$WORK/$(basename "$BASE_URL")"
[ -f "$BASEXZ" ] || { echo "DL base..."; wget -q -O "$BASEXZ" "$BASE_URL"; }
echo "décompression base -> $IMG"; xz -dc "$BASEXZ" > "$IMG"

# --- 2) Shrink root fs (hors-ligne, permis) ---
LOOP="$(losetup -fP --show "$IMG")"; sleep 1
echo "loop=$LOOP"; lsblk "$LOOP"
e2fsck -fy "${LOOP}p2" || true
resize2fs "${LOOP}p2" "${ROOT_MB}M"
losetup -d "$LOOP"; LOOP=""

# --- 3) Repartition : resize p2 + créer p3 (/data) + tronquer le fichier ---
P2_START_MIB="$(parted -ms "$IMG" unit MiB print | awk -F: '/^2:/{gsub("MiB","",$2); print int($2)}')"
# +16 MiB de marge : la partition root doit être >= au fs shrinké (le start réel peut avoir une
# fraction de MiB tronquée par int()). Le fs reste à ROOT_MB ; ~16 MiB de slack dans la partition.
P2_END=$((P2_START_MIB + ROOT_MB + 16))
P3_END=$((P2_END + DATA_MB))
echo "p2: ${P2_START_MIB}..${P2_END} MiB ; p3(data): ${P2_END}..${P3_END} MiB"
parted -s "$IMG" unit MiB resizepart 2 "${P2_END}"
parted -s "$IMG" unit MiB mkpart primary ext4 "${P2_END}" "${P3_END}"
truncate -s "$((P3_END + 8))M" "$IMG"
parted -ms "$IMG" unit MiB print free || true

# --- 4) mkfs /data ---
LOOP="$(losetup -fP --show "$IMG")"; sleep 1
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

# 5b) fstab : /data + binds (root reste RW au 1er boot ; overlay activé seulement par firstboot-harden)
cat >> "$MNT/etc/fstab" <<FSTAB
# --- Zaforge Couche B : data persistant + binds (avant activation overlay) ---
UUID=${DATA_UUID}  /data  ext4  defaults,noatime,nofail  0  2
/data/pisignage  /opt/pisignage  none  bind  0  0
/data/etc/ssh    /etc/ssh         none  bind  0  0
/data/etc/NetworkManager/system-connections  /etc/NetworkManager/system-connections  none  bind  0  0
FSTAB

# 5c) Helpers (depuis le dépôt déjà cloné dans /opt côté build, ou via GHRAW)
install -m 0755 "$SCRIPTS_DIR/firstboot-harden.sh"   "$MNT/usr/local/sbin/zaforge-firstboot-harden"
install -m 0755 "$SCRIPTS_DIR/zaforge-maintenance.sh" "$MNT/usr/local/sbin/zaforge-maintenance"

# 5d) Service install 1er boot
cat > "$MNT/usr/local/sbin/zaforge-firstboot-install" <<INSTALL
#!/bin/sh
set -e
exec >>/data/firstboot-install.log 2>&1
echo "=== zaforge-install \$(date -u) ==="
curl -fsSL ${GHRAW}/install.sh -o /tmp/install.sh
bash /tmp/install.sh --auto
touch /data/.zaforge-installed
echo "install OK -> déclenche durcissement"
systemctl start zaforge-firstboot-harden.service || true
INSTALL
chmod 0755 "$MNT/usr/local/sbin/zaforge-firstboot-install"

cat > "$MNT/etc/systemd/system/zaforge-install.service" <<UNIT
[Unit]
Description=Zaforge first-boot install (install.sh --auto)
After=network-online.target NetworkManager.service
Wants=network-online.target
ConditionPathExists=!/data/.zaforge-installed
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/zaforge-firstboot-install
RemainAfterExit=yes
TimeoutStartSec=2700
[Install]
WantedBy=multi-user.target
UNIT

cat > "$MNT/etc/systemd/system/zaforge-firstboot-harden.service" <<UNIT
[Unit]
Description=Zaforge first-boot hardening (grow /data + overlay root-ro)
After=zaforge-install.service
ConditionPathExists=!/data/.zaforge-hardened
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/zaforge-firstboot-harden
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT

# 5e) Activer les services (symlinks offline)
mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf ../zaforge-install.service          "$MNT/etc/systemd/system/multi-user.target.wants/zaforge-install.service"
ln -sf ../zaforge-firstboot-harden.service "$MNT/etc/systemd/system/multi-user.target.wants/zaforge-firstboot-harden.service"

# 5f) User 'pi' pré-créé + SSH activé (image headless, RPi OS Trixie exige un user)
HASH="$(openssl passwd -6 "$PI_PASS")"
echo "pi:${HASH}" > "$MNT/boot/firmware/userconf.txt"
touch "$MNT/boot/firmware/ssh"

# 5g) Désactiver le resize auto RPi OS (sinon il remplit le disque et écrase notre /data)
sed -i 's# init=/usr/lib/raspberrypi-sys-mods/firstboot##; s# init=/usr/lib/raspi-config/init_resize\.sh##' "$MNT/boot/firmware/cmdline.txt" || true
rm -f "$MNT/etc/systemd/system/multi-user.target.wants/rpi-resizerootfs.service" 2>/dev/null || true
rm -f "$MNT/etc/init.d/resize2fs_once" 2>/dev/null || true

echo "--- fstab ---"; tail -6 "$MNT/etc/fstab"
echo "--- cmdline ---"; cat "$MNT/boot/firmware/cmdline.txt"
echo "--- services actifs ---"; ls -l "$MNT/etc/systemd/system/multi-user.target.wants/" | grep zaforge

sync
umount "$MNT/boot/firmware"; umount "$MNT"; umount "$MNTD"
losetup -d "$LOOP"; LOOP=""
trap - EXIT

# --- 6) Finaliser ---
mv "$IMG" "$OUT"
echo "compression -> ${OUT}.xz"; xz -T0 -f "$OUT"
echo "================ IMAGE PRÊTE : ${OUT}.xz ================"
ls -lh "${OUT}.xz"
