#!/bin/sh
# Test d'intégration LIVE de wifi-apply.sh — À LANCER SUR LA BOX, en root.
# SÛRETÉ : slot 1 = le SSID réel courant (mode keep) ; les slots de secours utilisent
# des SSID INEXISTANTS (hors de portée → NM ne s'y associe jamais → aucune coupure).
# Les profils sont nommés par hash de SSID (zf-wifi-<sha1[:12]>), pas par numéro de slot.
set -u
H=/opt/pisignage/scripts/wifi-apply.sh
NM=/usr/bin/nmcli
STATE=/opt/pisignage/config/wifi-networks.json
NMDIR=/etc/NetworkManager/system-connections
fail=0
t() { if eval "$2" >/dev/null 2>&1; then echo "ok   - $1"; else echo "FAIL - $1"; fail=$((fail+1)); fi; }

active_ssid() { "$NM" -t -g GENERAL.CONNECTION dev show wlan0 >/dev/null 2>&1; "$NM" -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print substr($0,5); exit}'; }
count_ours()  { c=0; for u in $("$NM" -t -f UUID,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1}'); do id="$("$NM" -g connection.id con show "$u" 2>/dev/null)"; printf '%s' "$id" | grep -Eq '^zf-wifi-[0-9a-f]{12}$' && c=$((c+1)); done; echo "$c"; }
prio_of()     { for u in $("$NM" -t -f UUID,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1}'); do id="$("$NM" -g connection.id con show "$u" 2>/dev/null)"; printf '%s' "$id" | grep -Eq '^zf-wifi-[0-9a-f]{12}$' || continue; s="$("$NM" -g 802-11-wireless.ssid con show "$u" 2>/dev/null)"; [ "$s" = "$1" ] && { "$NM" -g connection.autoconnect-priority con show "$u" 2>/dev/null; return; }; done; }
ssid_present(){ for u in $("$NM" -t -f UUID,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1}'); do id="$("$NM" -g connection.id con show "$u" 2>/dev/null)"; printf '%s' "$id" | grep -Eq '^zf-wifi-[0-9a-f]{12}$' || continue; s="$("$NM" -g 802-11-wireless.ssid con show "$u" 2>/dev/null)"; [ "$s" = "$1" ] && return 0; done; return 1; }

REAL="$(active_ssid)"
[ -n "$REAL" ] || { echo "ABORT: pas de WiFi actif"; exit 1; }
echo "== SSID réel courant: [$REAL] =="
TAB="$(printf '\t')"

echo "--- 1) apply : slot1=keep(réel) + 2 bidons hors-portée ---"
printf '30%s%s%skeep%s\n20%sZZ-bidon-A%snew%smotdepasse1\n10%sZZ-bidon-B%snew%smotdepasse2\n' \
  "$TAB" "$REAL" "$TAB" "$TAB" "$TAB" "$TAB" "$TAB" "$TAB" "$TAB" "$TAB" | "$H" apply
t "3 profils a nous"             '[ "$(count_ours)" -eq 3 ]'
t "reel priorite 30"             '[ "$(prio_of "$REAL")" = "30" ]'
t "bidon-A priorite 20"          '[ "$(prio_of ZZ-bidon-A)" = "20" ]'
t "bidon-B priorite 10"          '[ "$(prio_of ZZ-bidon-B)" = "10" ]'
t "ssid round-trip bidon-A"      'ssid_present ZZ-bidon-A'
t "toujours connecte au reel"    '[ "$(active_ssid)" = "$REAL" ]'
t "json sans secret"             '! grep -Eqi "psk|password|motdepasse" "$STATE"'
t "json contient le reel"        'grep -Fq "$REAL" "$STATE"'
t "keyfiles a nous en 0600"      '[ -z "$(find "$NMDIR" -name "zf-wifi-*.nmconnection" ! -perm 600 2>/dev/null)" ]'

echo "--- 2) idempotence (re-apply identique) ---"
printf '30%s%s%skeep%s\n20%sZZ-bidon-A%snew%smotdepasse1\n10%sZZ-bidon-B%snew%smotdepasse2\n' \
  "$TAB" "$REAL" "$TAB" "$TAB" "$TAB" "$TAB" "$TAB" "$TAB" "$TAB" "$TAB" | "$H" apply
t "toujours 3 profils"           '[ "$(count_ours)" -eq 3 ]'
t "toujours connecte"            '[ "$(active_ssid)" = "$REAL" ]'

echo "--- 3) réordonnancement : réel -> slot2, bidon-A -> slot1 (réel doit RESTER connecté) ---"
printf '30%sZZ-bidon-A%snew%smotdepasse1\n20%s%s%skeep%s\n' \
  "$TAB" "$TAB" "$TAB" "$TAB" "$REAL" "$TAB" "$TAB" | "$H" apply
t "reorder: reel TOUJOURS connecte" '[ "$(active_ssid)" = "$REAL" ]'
t "reorder: reel priorite 20"       '[ "$(prio_of "$REAL")" = "20" ]'
t "reorder: bidon-A priorite 30"    '[ "$(prio_of ZZ-bidon-A)" = "30" ]'
t "reorder: 2 profils"              '[ "$(count_ours)" -eq 2 ]'

echo "--- 4) injection rejetée (ssid avec guillemet) : rien ne change ---"
before="$(count_ours)"
printf '30%sa"b%snew%smotdepasse1\n' "$TAB" "$TAB" "$TAB" | "$H" apply >/dev/null 2>&1 \
  && { echo "FAIL - injection acceptee"; fail=$((fail+1)); } || echo "ok   - injection rejetee (exit != 0)"
t "injection: nb profils inchange"  '[ "$(count_ours)" -eq "$before" ]'
t "injection: toujours connecte"    '[ "$(active_ssid)" = "$REAL" ]'

echo "--- 5) restauration état nominal : réel seul en slot 1 ---"
printf '30%s%s%skeep%s\n' "$TAB" "$REAL" "$TAB" "$TAB" | "$H" apply
t "restore: 1 profil"               '[ "$(count_ours)" -eq 1 ]'
t "restore: connecte au reel"       '[ "$(active_ssid)" = "$REAL" ]'

echo
[ "$fail" -eq 0 ] && echo "INTEGRATION OK" || echo "$fail ECHEC(S)"
exit "$fail"
