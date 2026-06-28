#!/bin/sh
# Zaforge — worker systemd au boot : applique la sortie audio persistée.
#
# Lit /opt/pisignage/config/audio-output (créé par audio-output.sh ou settings.php)
# et applique la préférence via audio-output.sh. Si le sink demandé n'existe pas
# (ex: TV éteinte au boot, EDID pas encore lu), retry toutes les 5s jusqu'à 12 fois
# (= 1 minute totale) avant d'abandonner.
#
# Appelé par pisignage-audio-apply.service en tant que 'pi' (User=pi).
# Au prochain branchement TV, le user peut re-basculer via l'admin OU juste
# attendre : WirePlumber va automatiquement utiliser le default sink persisté
# dès qu'il sera créé.
set -eu

PREF_FILE="/opt/pisignage/config/audio-output"
AUDIO_OUTPUT_SCRIPT="/opt/pisignage/scripts/audio-output.sh"

pref=""
if [ -r "$PREF_FILE" ]; then
    pref=$(tr -d '[:space:]' < "$PREF_FILE")
fi
case "$pref" in
    hdmi|jack) ;;
    *) pref="jack" ;;   # défaut safe : jack (bcm2835 toujours présent)
esac

echo "audio-output-apply : préférence = $pref"

# Jusqu'à 12 retries de 5s (= 1 min) : WirePlumber peut mettre du temps à créer
# les sinks (notamment HDMI après lecture EDID de la TV).
attempt=0
max=12
while [ "$attempt" -lt "$max" ]; do
    attempt=$((attempt + 1))
    if "$AUDIO_OUTPUT_SCRIPT" "$pref" 2>&1; then
        echo "audio-output-apply : OK après $attempt tentative(s)"
        exit 0
    fi
    if [ "$attempt" -lt "$max" ]; then
        echo "audio-output-apply : retry $attempt/$max dans 5s..."
        sleep 5
    fi
done

echo "audio-output-apply : ÉCHEC après $max tentatives (sink '$pref' pas disponible)" >&2
# Pas d'erreur fatale : on garde le default WirePlumber automatique (fallback jack).
exit 0
