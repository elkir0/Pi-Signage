#!/bin/sh
# Zaforge — bascule maintenance du root read-only (overlay).
#
#   zaforge-maintenance on      -> root READ-WRITE (overlay OFF) + reboot   [pour apt / MAJ système]
#   zaforge-maintenance off     -> root READ-ONLY  (overlay ON)  + reboot   [retour prod]
#   zaforge-maintenance status  -> état courant
#
# IMPORTANT : le déploiement applicatif NORMAL (scp dans /opt/pisignage, qui est sur /data rw)
# ne nécessite PAS la maintenance. On ne bascule en RW que pour modifier l'OS (apt, /etc système).
#
# root:root 0755. Réservé root (modifie l'état overlay + reboot).
set -eu

if [ "$(id -u)" != "0" ]; then echo "doit être lancé en root (sudo)" >&2; exit 1; fi
if ! command -v raspi-config >/dev/null 2>&1; then echo "raspi-config absent" >&2; exit 1; fi

# get_overlay_now : 0 = overlay actif (root ro), 1 = inactif (root rw).
overlay_active() { raspi-config nonint get_overlay_now >/dev/null 2>&1; }

case "${1:-status}" in
    on)
        if overlay_active; then
            echo "Maintenance ON : désactivation de l'overlay (root RW), reboot…"
            raspi-config nonint do_overlayfs 1
            sync; systemctl reboot
        else
            echo "Déjà en maintenance (root RW)."
        fi
        ;;
    off)
        if overlay_active; then
            echo "Déjà en prod (root read-only)."
        else
            echo "Maintenance OFF : réactivation de l'overlay (root RO), reboot…"
            raspi-config nonint do_overlayfs 0
            sync; systemctl reboot
        fi
        ;;
    status)
        if overlay_active; then echo "root = READ-ONLY (overlay actif, prod)"; else echo "root = READ-WRITE (maintenance)"; fi
        ;;
    *)
        echo "usage: zaforge-maintenance on|off|status" >&2; exit 2 ;;
esac
