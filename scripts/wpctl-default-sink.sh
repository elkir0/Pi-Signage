#!/bin/sh
# Zaforge — wrapper wpctl pour exécuter dans la session user de 'pi'.
#
# PipeWire écoute sur le bus D-Bus de session de 'pi'. Pour que www-data
# (php-fpm) puisse parler à PipeWire via wpctl, on doit fournir :
#   - XDG_RUNTIME_DIR=/run/user/<uid_pi>
#   - DBUS_SESSION_BUS_ADDRESS=unix:path=.../bus
# Sinon wpctl démarre un PipeWire vide (sans accès au vrai daemon) et échoue
# en silence (RTKit errors visibles mais pas de donnée volume retournée).
#
# Helper root:root 0755, sudoers grant : www-data ALL=(pi) NOPASSWD: ce script.
# Args passés tels quels à wpctl.
set -eu
PI_UID=$(id -u pi)
export XDG_RUNTIME_DIR="/run/user/${PI_UID}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
exec /usr/bin/wpctl "$@"
