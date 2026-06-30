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

# --- 2) La base RPi OS est PETITE (root ~5.5G, déjà ~88% plein) -> on AGRANDIT root (install.sh
#        installe php/nginx/golang/etc.) puis on ajoute /data. AUCUN shrink (grow only = sûr). ---
LOOP="$(losetup -fP --show "$IMG")"; sleep 1
echo "loop=$LOOP"; lsblk "$LOOP"
P2_START_MIB="$(parted -ms "$IMG" unit MiB print | awk -F: '/^2:/{gsub(/MiB/,"",$2); print int($2)}')"
losetup -d "$LOOP"; LOOP=""
P2_END=$((P2_START_MIB + ROOT_MB))     # nouvelle fin de root (grow)
P3_END=$((P2_END + DATA_MB))           # /data juste après
echo "p2(root): ${P2_START_MIB}..${P2_END} MiB ; p3(data): ${P2_END}..${P3_END} MiB"

# --- 3) Agrandir le FICHIER image, puis la partition root, puis créer /data ---
truncate -s "$((P3_END + 16))M" "$IMG"
parted -s "$IMG" unit MiB resizepart 2 "${P2_END}"
parted -s "$IMG" unit MiB mkpart primary ext4 "${P2_END}" "${P3_END}"
parted -ms "$IMG" unit MiB print free || true

# --- 4) Grandir le fs root (remplit la partition agrandie) + mkfs /data ---
LOOP="$(losetup -fP --show "$IMG")"; sleep 1
e2fsck -fy "${LOOP}p2" || true
resize2fs "${LOOP}p2"                  # sans taille = remplit la partition root agrandie
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
# Attendre que le user 'pi' soit CRÉÉ par userconf (asynchrone au 1er boot, peut arriver APRÈS
# network-online.target). install.sh tourne en 'pi' -> sans attente, runuser échoue
# ("This account is currently not available"). Bug observé au 2e test B2. Max ~180s.
i=0
while ! id -u pi >/dev/null 2>&1; do
    i=\$((i+1)); [ "\$i" -ge 90 ] && { echo "FATAL: user pi absent apres 180s"; exit 1; }
    sleep 2
done
echo "user pi pret apres \$((i*2))s"
curl -fsSL ${GHRAW}/install.sh -o /tmp/install.sh
chmod 0644 /tmp/install.sh
# install.sh REFUSE root (check_root) et escalade via sudo en interne -> on le lance en 'pi' (NOPASSWD
# posé au build). runuser -u (PAS -l) : bash directement en pi (HOME=/home/pi) sans shell de login
# (évite le nologin transitoire + le bruit profile.d). Root = échec immédiat (1er test B2).
runuser -u pi -- bash /tmp/install.sh --auto
touch /data/.zaforge-installed
echo "install OK -> provisioning identité (firstboot) puis durcissement (harden)"
# firstboot.service est DÉPLOYÉ par install.sh -> absent au début du 1er boot, il ne peut pas
# participer à la transaction multi-user.target initiale. On le déclenche EXPLICITEMENT ici, APRÈS
# l'install (php présent, système prêt), AVANT harden.
# --no-block OBLIGATOIRE sur les deux : on est DANS l'ExecStart de zaforge-install et firstboot/harden
# ont After=zaforge-install -> un start BLOQUANT = DEADLOCK (install attend la fin de leur job, eux
# attendent la fin de l'install). harden a After=zaforge-firstboot -> il attend la fin du provisioning
# avant de basculer l'overlay (identité posée sur root RW, pas sous tmpfs éphémère).
systemctl start --no-block zaforge-firstboot.service || true
systemctl start --no-block zaforge-firstboot-harden.service || true
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
# After firstboot AUSSI : l'identité par-device (hostname /etc/hostname) doit être posée pendant un
# boot RW ; après la bascule overlay tmpfs, /etc/hostname serait éphémère (et .provisioned sur /data
# empêche firstboot de re-tourner). En pratique l'install (long) précède déjà harden, mais on l'ancre.
After=zaforge-install.service zaforge-firstboot.service
ConditionPathExists=!/data/.zaforge-hardened
# GATING CRITIQUE : ne durcir (overlay root-ro) QU'APRÈS une install RÉUSSIE (.zaforge-installed posé
# en fin d'install). Sinon l'overlay s'active sur un système non installé et l'install re-tente sur un
# root tmpfs éphémère = boucle cassée (bug observé au 1er test B2).
ConditionPathExists=/data/.zaforge-installed
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

# pi en NOPASSWD : install.sh tourne en 'pi' (refuse root) et escalade via sudo en NON-interactif
# (--auto au 1er boot). Sans ça, chaque 'sudo' de l'install bloquerait/échouerait sur un prompt.
install -d -m 0755 "$MNT/etc/sudoers.d"
echo 'pi ALL=(ALL) NOPASSWD: ALL' > "$MNT/etc/sudoers.d/010-pi-nopasswd"
chmod 0440 "$MNT/etc/sudoers.d/010-pi-nopasswd"

# 5g) Désactiver le resize auto RPi OS. Sur Trixie c'est le token 'resize' du cmdline qui
#     déclenche l'expand de root (initramfs) -> il mangerait /data. On le RETIRE. (userconf-service
#     applique userconf.txt indépendamment, le user pi existe déjà -> pas besoin du resize/firstboot.)
sed -i 's/ resize\b//g; s# init=/usr/lib/raspberrypi-sys-mods/firstboot##; s# init=/usr/lib/raspi-config/init_resize\.sh##' "$MNT/boot/firmware/cmdline.txt" || true
rm -f "$MNT/etc/systemd/system/multi-user.target.wants/rpi-resizerootfs.service" 2>/dev/null || true
rm -f "$MNT/etc/init.d/resize2fs_once" 2>/dev/null || true

echo "--- fstab ---"; tail -6 "$MNT/etc/fstab"
echo "--- cmdline ---"; cat "$MNT/boot/firmware/cmdline.txt"
echo "--- services actifs ---"; ls -l "$MNT/etc/systemd/system/multi-user.target.wants/" | grep zaforge

sync
umount "$MNT/boot/firmware"; umount "$MNT"; umount "$MNTD"
losetup -d "$LOOP"; LOOP=""
trap - EXIT

# --- 6) Finaliser (compression RAPIDE : pigz multi-thread -> .img.gz compatible RPi Imager) ---
mv "$IMG" "$OUT"
if command -v pigz >/dev/null 2>&1; then
    echo "compression pigz ($(nproc) threads) -> ${OUT}.gz"
    pigz -p "$(nproc)" -f "$OUT"
else
    echo "compression gzip -> ${OUT}.gz"; gzip -f "$OUT"
fi
echo "================ IMAGE PRÊTE : ${OUT}.gz ================"
ls -lh "${OUT}.gz"
