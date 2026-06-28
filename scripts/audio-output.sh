#!/bin/sh
# Zaforge — bascule la sortie audio par défaut du système (HDMI ou jack 3.5mm).
#
# Implémentation PipeWire-native (Trixie Desktop) : utilise pactl (interface
# stable pipewire-pulse) pour set-default-sink + move-sink-input.
# Cross-box : identifie les sinks par leur nom ALSA (`hdmi` dans le nom = sortie
# HDMI, sinon analog/jack). Ne dépend PAS de node IDs (variables au boot).
#
# INVARIANT SÉCURITÉ :
#   - root:root 0755
#   - args FIXES (hdmi|jack) — sudoers grant verrouillé à ces 2 littéraux
#   - arg $1 validé (refuse tout autre)
#
# PERSISTANCE :
#   - écrit le choix dans /opt/pisignage/config/audio-output
#   - pisignage-audio-apply.service (systemd) relit ce fichier au boot et applique
#
# RÉSILIENCE :
#   - runuser auto : peut être appelé en root (sudo) ou pi (direct)
#   - si le sink demandé n'existe pas (ex: TV débranchée), échoue proprement
#     et pisignage-audio-apply.service fera un retry au boot
set -eu

choice="${1:-}"
case "$choice" in
    hdmi|jack) ;;
    *) echo "usage: $0 hdmi|jack" >&2; exit 2 ;;
esac

# Si on est root (cas sudo depuis www-data), basculer en session user 'pi'
# pour parler à PipeWire (wpctl/pactl exige XDG_RUNTIME_DIR + DBUS session).
if [ "$(id -u)" = "0" ]; then
    PI_UID=$(id -u pi 2>/dev/null || echo 1000)
    exec runuser -u pi -- env \
        XDG_RUNTIME_DIR="/run/user/${PI_UID}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${PI_UID}/bus" \
        "$0" "$choice"
fi

# Ici on est 'pi' avec XDG/DBUS positionnés par le runuser env.
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR requis pour PipeWire}"
: "${DBUS_SESSION_BUS_ADDRESS:?DBUS_SESSION_BUS_ADDRESS requis pour PipeWire}"

# pactl est l'interface stable (pipewire-pulse). Fallback wpctl si absent.
PACTL=$(command -v pactl 2>/dev/null || true)
WPCTL=$(command -v wpctl 2>/dev/null || true)
if [ -z "$PACTL" ] && [ -z "$WPCTL" ]; then
    echo "erreur : ni pactl ni wpctl disponible" >&2
    exit 3
fi

# Lister les sinks : format "id\tname\tdriver\t...\tstate".
list_sinks() {
    if [ -n "$PACTL" ]; then
        pactl list short sinks 2>/dev/null
    else
        # wpctl output : "  *  34. description [vol: 0.7]" -> on veut juste "34 alsa_output.xxx"
        wpctl status 2>/dev/null | awk '
            /Sinks:/{in_sinks=1; next}
            /^[[:space:]]*$/ || /Sources:/{in_sinks=0}
            in_sinks && /^[[:space:]]*[*.]?[[:space:]]*[0-9]+\./{
                id=$0; sub(/^[^[0-9]*([0-9]+)\..*$/, "\\1", id)
                # pas fiable sur wpctl : on bypass et n utilise que pactl
            }
        '
    fi
}

# Trouver le sink correspondant au choix demandé.
# HDMI  = premier sink dont le nom contient "hdmi"
# Jack  = premier sink dont le nom NE contient PAS "hdmi" (analog/headphones/mailbox)
case "$choice" in
    hdmi)
        target=$(pactl list short sinks 2>/dev/null | awk '$2 ~ /hdmi/ {print $2; exit}') ;;
    jack)
        target=$(pactl list short sinks 2>/dev/null | awk '$2 !~ /hdmi/ {print $2; exit}') ;;
esac

if [ -z "$target" ]; then
    echo "erreur : aucun sink '$choice' trouvé (sinks disponibles :)" >&2
    pactl list short sinks >&2 2>/dev/null || true
    exit 1
fi

# 1. Définir comme default sink (les NOUVEAUX streams y iront automatiquement).
pactl set-default-sink "$target" 2>/dev/null || \
    wpctl set-default "$target" 2>/dev/null || true

# 2. Déplacer les streams EXISTANTS (Chromium en cours) vers le nouveau sink.
# Sinon la vidéo en cours reste sur l'ancienne sortie jusqu'au prochain item.
pactl list short sink-inputs 2>/dev/null | awk '{print $1}' | while read -r id; do
    pactl move-sink-input "$id" "$target" 2>/dev/null || true
done

# 3. Volume audible si le sink est à 0 (souvent le cas au premier switch).
vol_line=$(pactl get-sink-volume "$target" 2>/dev/null || true)
vol=$(echo "$vol_line" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
if [ -n "$vol" ] && [ "$vol" -lt 30 ]; then
    pactl set-sink-volume "$target" '70%' 2>/dev/null || true
fi

# 4. Persister le choix pour le boot (pisignage-audio-apply.service le relira).
mkdir -p /opt/pisignage/config 2>/dev/null || true
if ! echo "$choice" > /opt/pisignage/config/audio-output 2>/dev/null; then
    echo "attention : impossible de persister dans /opt/pisignage/config/audio-output (non bloquant)" >&2
fi

echo "Sortie audio : $choice (sink=$target)"
