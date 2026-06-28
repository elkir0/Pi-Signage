#!/bin/sh
# Zaforge — restart wireplumber dans la session user de 'pi'.
#
# PipeWire/WirePlumber tient son routage audio en mémoire. Quand on change la
# sortie par défaut via raspi-config (audio-output.sh), il faut restart
# wireplumber pour qu'il relise la config ALSA et re-route les flux.
#
# Helper root:root 0755, appelé par www-data via sudo (sudoers grant fixe).
# runuser est préféré à sudo -u (pas de credentials PAM, plus simple, plus sûr).
set -eu
exec runuser -u pi -- systemctl --user restart wireplumber
