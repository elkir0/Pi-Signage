#!/bin/sh
# Zaforge — worker systemd au boot : applique la sortie audio persistée.
#
# Lit /opt/pisignage/config/audio-output (créé par audio-output.sh ou settings.php)
# et applique la préférence via audio-output.sh.
#
# RÉSILIENCE face au timing EDID TV au boot :
#   - 30 retries × 5s = 2.5 minutes
#   - Tous les 5 retries : re-trigger DRM detect (force le kernel à relire l'EDID
#     via I2C — utile si la TV était en veille au boot) + restart wireplumber
#     (force la création du sink HDMI si l'EDID est enfin lisible)
#   - Si ÉCHEC final : pas d'erreur fatale (default WirePlumber automatique = jack)
#
# Appelé par pisignage-audio-apply.service en tant que 'pi' (User=pi).
set -eu

PREF_FILE="/opt/pisignage/config/audio-output"
AUDIO_OUTPUT_SCRIPT="/opt/pisignage/scripts/audio-output.sh"

# Le service systemd fournit parfois un XDG_RUNTIME_DIR ERRONÉ : le spécificateur %U
# s'expanse en 0 (root) au lieu de l'UID de 'pi' sur certaines versions systemd, donc
# pactl parlerait à /run/user/0 (vide) au lieu de la session graphique de pi → il ne
# verrait jamais le sink HDMI. On force le runtime dir de l'utilisateur courant (pi).
_UID="$(id -u)"
export XDG_RUNTIME_DIR="/run/user/${_UID}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${_UID}/bus"

pref=""
if [ -r "$PREF_FILE" ]; then
    pref=$(tr -d '[:space:]' < "$PREF_FILE")
fi
case "$pref" in
    hdmi|jack) ;;
    *) pref="jack" ;;   # défaut safe : jack (bcm2835 toujours présent)
esac

echo "audio-output-apply : préférence = $pref"

attempt=0
max=30
while [ "$attempt" -lt "$max" ]; do
    attempt=$((attempt + 1))
    if "$AUDIO_OUTPUT_SCRIPT" "$pref" 2>&1; then
        echo "audio-output-apply : OK après $attempt tentative(s)"
        exit 0
    fi
    # Tous les 5 retries : re-trigger DRM detect (helper ROOT — 'pi' ne peut pas écrire
    # le sysfs DRM) + restart wireplumber. audio-output.sh force déjà détection+profil à
    # chaque tentative ; ce restart borné est un filet supplémentaire pour les TV lentes.
    if [ "$pref" = "hdmi" ] && [ $((attempt % 5)) -eq 0 ]; then
        echo "audio-output-apply : retry $attempt/$max — re-detect DRM (root) + restart wireplumber"
        sudo -n /opt/pisignage/scripts/hdmi-detect.sh 2>/dev/null || true
        sleep 3
        systemctl --user restart wireplumber 2>/dev/null || true
        sleep 5
    elif [ "$attempt" -lt "$max" ]; then
        echo "audio-output-apply : retry $attempt/$max dans 5s..."
        sleep 5
    fi
done

echo "audio-output-apply : ÉCHEC après $max tentatives (sink '$pref' pas disponible)" >&2
# Pas d'erreur fatale : on garde le default WirePlumber automatique (fallback jack).
exit 0
