#!/bin/sh
# Zaforge — watchdog de sortie audio (idempotent, silencieux).
#
# But : couvrir le cas « TV éteinte au boot, rallumée plus tard ». Déclenché par :
#   - pisignage-audio-watchdog.timer  (vérification périodique, ~2 min)
#   - règle udev 99-pisignage-hdmi-audio.rules (event DRM « change » = hotplug TV)
#
# Tourne en tant que 'pi' (via le service systemd User=pi qui fournit XDG_RUNTIME_DIR
# + DBUS_SESSION_BUS_ADDRESS). N'effectue une action que si NÉCESSAIRE :
#   - applique la préférence persistée si le sink correspondant existe ;
#   - si pref=hdmi mais pas de sink HDMI ALORS QUE la TV présente un ELD audio lisible,
#     redémarre WirePlumber UNE fois pour forcer la (re)création du sink, puis réapplique ;
#   - si la TV est éteinte (aucun ELD), ne touche à RIEN (on réessaiera au prochain tick).
set -u

PREF_FILE=/opt/pisignage/config/audio-output
AUDIO_OUT=/opt/pisignage/scripts/audio-output.sh

pref=jack
[ -r "$PREF_FILE" ] && pref=$(tr -d '[:space:]' < "$PREF_FILE" 2>/dev/null)
case "$pref" in hdmi|jack) ;; *) pref=jack ;; esac

# 1er essai : si le sink demandé existe déjà, audio-output.sh bascule (idempotent) et c'est fini.
if "$AUDIO_OUT" "$pref" >/dev/null 2>&1; then
    exit 0
fi

# Échec. Pour 'jack' il n'y a rien d'autre à tenter.
[ "$pref" = "jack" ] && exit 0

# pref=hdmi sans sink HDMI. Ne RIEN faire si la TV ne présente pas d'ELD audio (éteinte) :
# inutile — et perturbant — de redémarrer WirePlumber en boucle pour rien.
if ! grep -aqs 'monitor_name[^A-Za-z0-9]*[A-Za-z0-9]' /proc/asound/card*/eld#* 2>/dev/null; then
    exit 0
fi

# Une TV audio est présente (ELD lisible) mais WirePlumber n'a pas (encore) créé le sink :
# un redémarrage borné (UN seul par invocation) force la (re)création, puis on réapplique.
systemctl --user restart wireplumber 2>/dev/null || true
sleep 3
"$AUDIO_OUT" "$pref" >/dev/null 2>&1 || true
exit 0
