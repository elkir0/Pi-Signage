#!/bin/sh
# Zaforge — Couche B : durcissement au 1er boot de l'image SD durcie.
#
# CONTEXTE : l'image est DÉJÀ partitionnée boot / root / data (le partitionnement délicat est
# fait HORS-LIGNE au build, où rétrécir root est permis). /opt/pisignage est déjà sur /data
# (bind via fstab), binds NM/SSH posés. L'overlay root-ro n'est PAS encore actif → ce 1er boot
# tourne en root RW pour finir le travail :
#   1) AGRANDIR /data (DERNIÈRE partition) pour remplir la SD réelle — grow online = SÛR
#      (aucun shrink, aucune partition après → exactement ce que fait raspi-config pour root).
#   2) Activer l'overlay root-ro EN DERNIER, puis reboot.
#
# SÉCURITÉ : idempotent (marker sur /data). ORDRE STRICT : overlay EN DERNIER → si une étape
# échoue avant, root reste RW et la box reste récupérable (pas de demi-état non-bootable).
# Tourne via systemd oneshot AVANT graphical.target. root:root 0755.
set -eu

LOG=/data/firstboot-harden.log
# /data doit exister+être monté (l'image le garantit). Sinon on s'ARRÊTE (ne jamais agir à l'aveugle).
mountpoint -q /data || { echo "[firstboot-harden] /data non monté -> abort (rien fait)" >&2; exit 0; }
exec >>"$LOG" 2>&1
echo "================ firstboot-harden $(date -u +%FT%TZ) ================"

MARKER=/data/.zaforge-hardened
PENDING=/data/.zaforge-overlay-pending
FAILED=/data/.zaforge-overlay-failed
overlay_active() { findmnt -no FSTYPE / 2>/dev/null | grep -qi 'overlay'; }

if [ -f "$MARKER" ]; then
    echo "déjà durci (marker présent) -> rien à faire"
    exit 0
fi

# Retour du reboot post-config : si l'overlay est ACTIF, le durcissement a RÉUSSI -> on finalise
# (marker VÉRIFIÉ, pas posé à l'aveugle comme avant — c'était le bug qui bloquait tout retry).
if overlay_active; then
    echo "root en overlay (read-only) confirmé -> finalisation"
    rm -f "$PENDING" 2>/dev/null || true
    touch "$MARKER"; sync
    echo "marker .zaforge-hardened posé (état durci VÉRIFIÉ)"
    exit 0
fi

# Overlay PAS actif alors qu'on avait déjà configuré+rebooté (pending) = ÉCHEC d'activation.
# On NE reboucle PAS : root reste RW (récupérable), on trace l'échec et on s'arrête.
if [ -f "$PENDING" ]; then
    echo "ÉCHEC: overlay configuré+rebooté mais root toujours RW -> abandon, root RW (récupérable)"
    rm -f "$PENDING" 2>/dev/null || true
    touch "$FAILED" 2>/dev/null || true
    exit 0
fi

# --- Identifier la partition /data et son disque ---
DATA_SRC="$(findmnt -no SOURCE /data)" || { echo "findmnt /data KO -> abort"; exit 0; }
PK="$(lsblk -no PKNAME "$DATA_SRC" 2>/dev/null || true)"
[ -n "$PK" ] || { echo "disque parent introuvable pour $DATA_SRC -> abort"; exit 0; }
DISK="/dev/$PK"
PARTNUM="$(echo "$DATA_SRC" | grep -o '[0-9]*$')"
echo "data=$DATA_SRC disk=$DISK partnum=$PARTNUM"

# Garde-fou : /data DOIT être la DERNIÈRE partition (sinon resizepart à 100% écraserait une voisine).
LAST_PARTNUM="$(parted -ms "$DISK" print 2>/dev/null | awk -F: '/^[0-9]+:/{n=$1} END{print n}')"
if [ "$PARTNUM" != "$LAST_PARTNUM" ]; then
    echo "ERREUR: /data (part $PARTNUM) n'est pas la dernière partition ($LAST_PARTNUM) -> on NE touche À RIEN"
    exit 0
fi

# --- 1) Agrandir /data pour remplir la SD (grow de la DERNIÈRE partition, EN LIGNE) ---
# PIÈGE : `parted -s resizepart` REFUSE une partition MONTÉE ("Partition is being used. Are you
# sure?") en mode script et n'applique RIEN -> /data restait à la taille de l'image (2 Go au lieu
# de remplir la SD). On grandit donc EN LIGNE, sans démonter (/data porte des binds, démontage
# impossible) :
#   - growpart (cloud-guest-utils) si présent : réécrit la table + ioctl BLKPG (resize in-kernel) ;
#   - sinon parted via ---pretend-input-tty en répondant "Yes" (même mécanisme BLKPG).
# Puis resize2fs agrandit l'ext4 MONTÉ (online resize supporté).
echo "--- grow partition $PARTNUM -> 100% (en ligne, /data monté) ---"
if command -v growpart >/dev/null 2>&1; then
    growpart "$DISK" "$PARTNUM" || echo "WARN growpart (peut-être déjà à 100%)"
else
    echo "Yes" | parted ---pretend-input-tty "$DISK" resizepart "$PARTNUM" 100% || echo "WARN parted resizepart"
fi
partprobe "$DISK" 2>/dev/null || true
sleep 2
echo "--- resize2fs $DATA_SRC (online) ---"
resize2fs "$DATA_SRC" || echo "WARN resize2fs"
df -h /data || true

# --- 2) Configurer l'overlay root-ro via le paquet Debian `overlayroot` ---
# PAS `raspi-config do_overlayfs` : il posait `overlayroot=tmpfs` en cmdline SANS reconstruire
# l'initramfs (pas de hook overlayroot dedans) -> paramètre ignoré au boot, root restait RW, et il
# renvoyait quand même 0 (mensonge). Ici la source de vérité est /etc/overlayroot.conf, BAKÉE dans
# l'initramfs par update-initramfs. On retire tout token overlayroot= du cmdline pour qu'il
# n'override PAS la conf (sans recurse=0 il overlayrait aussi /data + les binds -> perte de données).
CMDLINE=/boot/firmware/cmdline.txt
# /boot/firmware est monté `ro` (fstab) -> remonter rw pour pouvoir nettoyer le token, puis VÉRIFIER.
mount -o remount,rw /boot/firmware 2>/dev/null || true
[ -f "$CMDLINE" ] && sed -i 's/[[:space:]]*overlayroot=[^[:space:]]*//g' "$CMDLINE" || true
# GARDE-FOU : si un overlayroot= subsiste dans le cmdline (remount rw KO), il overriderait la conf
# SANS recurse=0 -> overlay récursif sur /data = PERTE DE DONNÉES. On ANNULE plutôt que risquer ça.
if [ -f "$CMDLINE" ] && grep -q 'overlayroot=' "$CMDLINE"; then
    echo "ÉCHEC: overlayroot= toujours dans le cmdline (/boot/firmware ro ?) -> overlay ANNULÉ, root reste RW (récupérable)."
    exit 0
fi

if ! command -v overlayroot-chroot >/dev/null 2>&1; then
    echo "--- installation du paquet overlayroot ---"
    if ! { apt-get update >/dev/null 2>&1; apt-get install -y overlayroot >/dev/null 2>&1; }; then
        echo "ÉCHEC install overlayroot -> root reste RW (récupérable). Pas de reboot."
        exit 0
    fi
fi

# recurse=0 = n'overlaye QUE / ; /data et les binds (/opt/pisignage, /etc/ssh, NM) restent
# PERSISTANTS (sous-montages non touchés). cfgdisk=disabled = pas de recherche de disque de conf.
cat > /etc/overlayroot.conf <<'ORC'
overlayroot_cfgdisk="disabled"
overlayroot="tmpfs:recurse=0"
ORC

echo "--- update-initramfs -u -k all (bake le hook overlayroot) ---"
if ! update-initramfs -u -k all; then
    echo "ÉCHEC update-initramfs -> root reste RW (récupérable). Pas de reboot."
    exit 0
fi

# Marker PENDING (pas .zaforge-hardened !) : au prochain boot on VÉRIFIE que root est bien en
# overlay avant de marquer « durci ». Si l'overlay échoue, le bloc PENDING en tête s'arrête sans
# boucler et laisse root RW (récupérable).
touch "$PENDING"; sync
echo "overlay configuré -> reboot pour basculer root en read-only (vérif au prochain boot)"
systemctl reboot
