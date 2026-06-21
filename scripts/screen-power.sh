#!/bin/sh
# PiSignage — Allume / éteint l'écran du kiosk Wayland (labwc) via wlr-randr, et renvoie l'état.
# Appelé par www-data via: sudo -u pi /opt/pisignage/scripts/screen-power.sh on|off|state
# (autorisé sans mot de passe par /etc/sudoers.d/pisignage). S'exécute en tant que 'pi'.
#
# Usage: screen-power.sh on|off|state
set -eu

ACTION="${1:-}"
case "$ACTION" in
    on|off|state) ;;
    *) echo "usage: $0 on|off|state" >&2; exit 2 ;;
esac

RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
WL="$(ls "$RUNTIME_DIR" 2>/dev/null | grep -m1 '^wayland-[0-9]*$' || true)"
export WAYLAND_DISPLAY="${WL:-wayland-0}"

DUMP="$(/usr/bin/wlr-randr 2>/dev/null || true)"

# IMPORTANT : quand toutes les vraies sorties sont éteintes, wlroots crée une sortie
# VIRTUELLE "NOOP-1" (Enabled: yes). Il ne faut JAMAIS la cibler (sinon impossible de
# rallumer la vraie sortie). On cible toujours HDMI-A-1 (sortie kiosk via kanshi) si elle
# existe, sinon la 1re sortie réelle (non-NOOP), sinon repli HDMI-A-1.
REAL="$(printf '%s\n' "$DUMP" | awk '/^[^[:space:]]/ {print $1}' | grep -vi 'noop' || true)"
OUTPUT=""
for o in $REAL; do
    if [ "$o" = "HDMI-A-1" ]; then OUTPUT="$o"; break; fi
done
[ -z "$OUTPUT" ] && OUTPUT="$(printf '%s\n' "$REAL" | head -n1)"
OUTPUT="${OUTPUT:-HDMI-A-1}"

if [ "$ACTION" = "state" ]; then
    # "on" si une sortie RÉELLE est Enabled: yes (on ignore la NOOP virtuelle), sinon "off".
    st="$(printf '%s\n' "$DUMP" | awk '
        /^[^[:space:]]/ { name = $1 }
        /Enabled: yes/  { if (tolower(name) !~ /noop/) { print "on"; found = 1; exit } }
        END { if (!found) print "off" }')"
    echo "${st:-off}"
    exit 0
fi

/usr/bin/wlr-randr --output "$OUTPUT" --"$ACTION"
echo "$OUTPUT $ACTION"
