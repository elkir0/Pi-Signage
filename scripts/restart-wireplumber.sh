#!/bin/sh
# Zaforge — restart wireplumber dans la session user de 'pi'.
#
# PipeWire/WirePlumber tient son routage audio en mémoire. Quand on change la
# sortie par défaut via raspi-config (audio-output.sh), il faut restart
# wireplumber pour qu'il relise la config ALSA et re-route les flux.
#
# Helper root:root 0755, appelé par www-data via sudo (sudoers grant fixe).
# runuser est préféré à sudo -u (pas de credentials PAM, plus simple, plus sûr).
# XDG_RUNTIME_DIR + DBUS_SESSION_BUS_ADDRESS OBLIGATOIRES pour atteindre le
# bus user de 'pi' (sinon systemctl --user ne peut pas se connecter).
set -eu
PI_UID=$(id -u pi)
exec runuser -u pi -- env \
    XDG_RUNTIME_DIR="/run/user/${PI_UID}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${PI_UID}/bus" \
    systemctl --user restart wireplumber
