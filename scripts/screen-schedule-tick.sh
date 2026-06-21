#!/bin/sh
# PiSignage — applique le planning d'extinction d'écran.
# Lancé CHAQUE MINUTE par /etc/cron.d/pisignage-screen (en root). Lit screen_schedule.json
# (écrit par l'API kiosk PUT /screen) et applique l'état désiré via screen-power.sh, exécuté
# en tant que 'pi' (session Wayland). Idempotent : ne bascule que si l'état réel diffère.
set -eu

CFG=/opt/pisignage/config/screen_schedule.json
POWER=/opt/pisignage/scripts/screen-power.sh
RT=/run/user/1000

[ -f "$CFG" ] || exit 0
[ -x "$POWER" ] || exit 0

# Parse le JSON en variables shell sûres (valeurs single-quotées par python).
eval "$(python3 - "$CFG" <<'PY'
import json, sys
def q(s): return "'" + str(s).replace("'", "'\\''") + "'"
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("EN=0"); sys.exit()
en = 1 if d.get("enabled") else 0
on = d.get("on_time") or ""
off = d.get("off_time") or ""
days = d.get("days")
days = ",".join(str(int(x)) for x in days) if isinstance(days, list) and days else "all"
print("EN=%d ON=%s OFF=%s DAYS=%s" % (en, q(on), q(off), q(days)))
PY
)"

[ "${EN:-0}" = "1" ] || exit 0
[ -n "${ON:-}" ] && [ -n "${OFF:-}" ] || exit 0

# Jour courant (0=dimanche .. 6=samedi, convention date +%w == celle de l'UI kiosk).
NOWDAY=$(date +%w)
if [ "$DAYS" != "all" ]; then
    echo ",$DAYS," | grep -q ",$NOWDAY," || exit 0
fi

# État désiré : "on" si l'heure courante est dans la plage [ON, OFF). Gère le passage minuit.
NOW=$(date +%H:%M)
want=off
if [ "$ON" \< "$OFF" ]; then
    if { [ "$NOW" = "$ON" ] || [ "$NOW" \> "$ON" ]; } && [ "$NOW" \< "$OFF" ]; then want=on; fi
else
    # plage qui passe minuit, ex: ON=18:00 OFF=08:00
    if [ "$NOW" = "$ON" ] || [ "$NOW" \> "$ON" ] || [ "$NOW" \< "$OFF" ]; then want=on; fi
fi

# État réel (via wlr-randr en pi) ; ne change que si nécessaire -> pas de re-trigger chaque minute.
WL=$(ls "$RT" 2>/dev/null | grep -m1 '^wayland-[0-9]*$' || echo wayland-0)
cur=$(sudo -u pi env XDG_RUNTIME_DIR="$RT" WAYLAND_DISPLAY="$WL" wlr-randr 2>/dev/null \
      | awk '/Enabled: yes/{e=1} END{print (e ? "on" : "off")}')
[ "$cur" = "$want" ] && exit 0

sudo -u pi "$POWER" "$want" >/dev/null 2>&1 || true
