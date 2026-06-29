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
if [ -f "$MARKER" ]; then
    echo "déjà durci (marker présent) -> rien à faire"
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

# --- 1) Agrandir /data pour remplir la SD (grow de la dernière partition = sûr) ---
echo "--- resizepart $PARTNUM -> 100% ---"
parted -s "$DISK" resizepart "$PARTNUM" 100% || echo "WARN resizepart (peut-être déjà à 100%)"
partprobe "$DISK" 2>/dev/null || true
sleep 2
echo "--- resize2fs $DATA_SRC ---"
resize2fs "$DATA_SRC" || echo "WARN resize2fs"
df -h /data || true

# Marker AVANT l'overlay : si le reboot post-overlay boucle, on ne ré-agrandit pas en boucle.
touch "$MARKER"; sync
echo "marker posé"

# --- 2) Activer l'overlay root-ro EN DERNIER ---
if ! command -v raspi-config >/dev/null 2>&1; then
    echo "raspi-config absent -> overlay NON activé (Couche A seule). Box reste RW."
    exit 0
fi
echo "--- activation overlayfs (root read-only) ---"
# raspi-config nonint do_overlayfs 0 = ACTIVER l'overlay (laisse /boot inscriptible pour la
# récupération via cmdline.txt). Si échec : on laisse root RW (récupérable), pas de reboot.
if raspi-config nonint do_overlayfs 0; then
    echo "overlay activé -> reboot pour basculer en root read-only"
    sync
    systemctl reboot
else
    echo "ÉCHEC activation overlay -> root reste RW (récupérable). Pas de reboot."
    exit 0
fi
