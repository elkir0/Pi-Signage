#!/bin/sh
# PiSignage — Capture l'écran Wayland (labwc) du kiosk.
# Conçu pour être appelé par www-data via: sudo -u pi /opt/pisignage/scripts/grim-capture.sh
# (autorisé sans mot de passe par /etc/sudoers.d/pisignage). S'exécute donc en tant que 'pi',
# dans sa session Wayland, et écrit un PNG dans /tmp dont il imprime le chemin sur stdout.
set -eu

RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"

# Détecte le socket Wayland actif (wayland-0, wayland-1, ...) ; repli sur wayland-0.
WL="$(ls "$RUNTIME_DIR" 2>/dev/null | grep -m1 '^wayland-[0-9]*$' || true)"
export WAYLAND_DISPLAY="${WL:-wayland-0}"

OUT="/tmp/pisignage-screenshot.png"

# Capture l'écran composité complet (vidéo VLC/Chromium incluse).
/usr/bin/grim -t png "$OUT" 2>/dev/null
chmod 0644 "$OUT" 2>/dev/null || true
echo "$OUT"
