#!/bin/sh
# PiSignage / Zaforge — bascule la sortie audio via raspi-config, ARGUMENTS FIXES.
# Appelé en root via une grant sudoers verrouillée :
#   www-data ALL=(root) NOPASSWD: /opt/pisignage/scripts/audio-output.sh hdmi,
#                                 /opt/pisignage/scripts/audio-output.sh jack
# INVARIANT DE SÉCURITÉ : ce script DOIT rester root:root 0755. Si www-data pouvait le
# réécrire, la grant deviendrait une escalade vers root. raspi-config n'est PLUS accordé
# directement à www-data — il n'est atteignable que via ce wrapper à arguments littéraux.
set -eu

case "${1:-}" in
    hdmi) DEV=2 ;;   # 2 = HDMI
    jack) DEV=1 ;;   # 1 = jack/casque
    *) echo "usage: audio-output.sh hdmi|jack" >&2; exit 2 ;;
esac

# Refuser tout argument supplémentaire (la grant sudoers fige déjà l'arg, défense en profondeur).
if [ "$#" -ne 1 ]; then
    echo "usage: audio-output.sh hdmi|jack" >&2
    exit 2
fi

exec /usr/bin/raspi-config nonint do_audio "$DEV"
