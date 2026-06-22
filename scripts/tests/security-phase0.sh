#!/bin/bash
# Phase-0 security verification suite — runs ON the Pi (localhost).
set +e
B="http://${PI_HOST:-localhost}"
NEWPW="ZaforgeAdmin2026!"
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
ko(){ echo "  [FAIL] $1"; fail=$((fail+1)); }

echo "== 1. Default-password must_change forcing =="
C1=$(mktemp)
curl -s -c "$C1" -b "$C1" -d "username=admin&password=signage2025" "$B/login.php" -o /dev/null
T1=$(curl -s -c "$C1" -b "$C1" "$B/settings.php" | grep -oP 'name="csrf-token" content="\K[0-9a-f]{64}' | head -1)
code=$(curl -s -c "$C1" -b "$C1" -o /dev/null -w "%{http_code}" -X POST -H "X-CSRF-Token: $T1" -H "Content-Type: application/json" -d '{"action":"reboot"}' "$B/api/system.php")
[ "$code" = "403" ] && ok "default-pw session: reboot POST blocked 403 (must_change)" || ko "reboot during must_change = $code (want 403)"

echo "== 2. CSRF-positive via update_password (clears must_change) =="
resp=$(curl -s -c "$C1" -b "$C1" -X POST -H "X-CSRF-Token: $T1" -H "Content-Type: application/json" -d "{\"action\":\"update_password\",\"old_password\":\"signage2025\",\"new_password\":\"$NEWPW\"}" "$B/api/settings.php")
echo "$resp" | grep -q '"success":true' && ok "update_password with valid CSRF token succeeded (CSRF-positive + pw hardened)" || ko "update_password failed: $resp"

echo "== 3. CSRF enforcement on a normal session =="
C2=$(mktemp)
curl -s -c "$C2" -b "$C2" -d "username=admin&password=$NEWPW" "$B/login.php" -o /dev/null
T2=$(curl -s -c "$C2" -b "$C2" "$B/dashboard.php" | grep -oP 'name="csrf-token" content="\K[0-9a-f]{64}' | head -1)
[ -n "$T2" ] && ok "csrf meta present (len ${#T2})" || ko "no csrf meta on dashboard"
g=$(curl -s -c "$C2" -b "$C2" -o /dev/null -w "%{http_code}" "$B/api/stats.php"); [ "$g" = "200" ] && ok "GET stats unprotected = 200" || ko "GET stats = $g"
n=$(curl -s -c "$C2" -b "$C2" -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d '{"action":"get_volume"}' "$B/api/system.php"); [ "$n" = "403" ] && ok "POST no-token = 403" || ko "POST no-token = $n (want 403)"
w=$(curl -s -c "$C2" -b "$C2" -o /dev/null -w "%{http_code}" -X POST -H "X-CSRF-Token: wrong" -H "Content-Type: application/json" -d '{"action":"get_volume"}' "$B/api/system.php"); [ "$w" = "403" ] && ok "POST wrong-token = 403" || ko "POST wrong-token = $w (want 403)"
v=$(curl -s -c "$C2" -b "$C2" -o /dev/null -w "%{http_code}" -X POST -H "X-CSRF-Token: $T2" -H "Content-Type: application/json" -d '{"action":"get_volume"}' "$B/api/system.php"); [ "$v" = "200" ] && ok "POST valid-token = 200" || ko "POST valid-token = $v (want 200)"

echo "== 4. Exec injection neutralized (tail logs argv) =="
rm -f /tmp/PWNED
curl -s -c "$C2" -b "$C2" -X POST -H "X-CSRF-Token: $T2" -H "Content-Type: application/json" -d '{"action":"logs","lines":"5 /etc/passwd; touch /tmp/PWNED"}' "$B/api/system.php" >/dev/null 2>&1
[ -e /tmp/PWNED ] && ko "INJECTION SUCCEEDED (/tmp/PWNED created)" || ok "log-tail injection neutralized (no /tmp/PWNED)"

echo "== 5. GET screenshot capture is POST-only =="
gc=$(curl -s -c "$C2" -b "$C2" -o /dev/null -w "%{http_code}" "$B/api/screenshot.php?action=capture"); [ "$gc" = "405" ] && ok "GET ?action=capture = 405 (no cross-site grim)" || ko "GET capture = $gc (want 405)"

echo "== 6. Agent loopback auth bridge =="
TOK=$(sudo python3 -c "import json;print(json.load(open('/opt/pisignage/config/agent.json'))['token'])" 2>/dev/null)
a1=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Agent-Token: $TOK" "http://127.0.0.1/api/playlists.php"); [ "$a1" = "200" ] && ok "loopback + valid token = 200" || ko "loopback+token = $a1 (want 200)"
a2=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1/api/playlists.php"); [ "$a2" = "401" ] && ok "loopback + no token = 401" || ko "loopback no-token = $a2 (want 401)"
a3=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Agent-Token: deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "http://127.0.0.1/api/playlists.php"); [ "$a3" = "401" ] && ok "loopback + wrong token = 401 (no oracle)" || ko "loopback wrong-token = $a3 (want 401)"
ap=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-Agent-Token: $TOK" -H "Content-Type: application/json" -d '{}' "http://127.0.0.1/api/playlists.php"); [ "$ap" != "403" ] && ok "agent POST skips CSRF (= $ap, not 403)" || ko "agent POST hit CSRF 403"
perms=$(stat -c "%a %U %G" /opt/pisignage/config/agent.json); [ "$perms" = "640 pi www-data" ] && ok "agent.json perms = $perms" || ko "agent.json perms = $perms (want 640 pi www-data)"

echo "== 7. Sudoers least-privilege (www-data) =="
sudo -u www-data sudo -n raspi-config nonint do_audio 2 >/dev/null 2>&1 && ko "www-data CAN sudo raspi-config (escalation!)" || ok "www-data sudo raspi-config DENIED"
sudo -u www-data sudo -n /opt/pisignage/scripts/audio-output.sh evil >/dev/null 2>&1 && ko "audio-output.sh evil ALLOWED" || ok "audio-output.sh evil DENIED"
sudo -u www-data sudo -n /opt/pisignage/scripts/audio-output.sh hdmi >/dev/null 2>&1 && ok "audio-output.sh hdmi ALLOWED (volume path works)" || ko "audio-output.sh hdmi denied (volume path broken)"
smode=$(stat -c "%a %U:%G" /etc/sudoers.d/pisignage); [ "$smode" = "440 root:root" ] && ok "sudoers mode = $smode" || ko "sudoers mode = $smode (want 440 root:root)"

echo "== 8. Cookie flags (real HTTP, no Secure) =="
ck=$(curl -s -i -d "username=admin&password=$NEWPW" "$B/login.php" | grep -i "^set-cookie: PHPSESSID" | head -1)
echo "$ck" | grep -qi "httponly" && ok "cookie HttpOnly present" || ko "cookie missing HttpOnly: $ck"
echo "$ck" | grep -qi "samesite=lax" && ok "cookie SameSite=Lax present" || ko "cookie missing SameSite"
echo "$ck" | grep -qi "secure" && ko "cookie Secure set on plain HTTP (self-DoS)" || ok "cookie not Secure on HTTP (correct)"
sp=$(curl -s -i -H "X-Forwarded-Proto: https" -d "username=admin&password=$NEWPW" "$B/login.php" | grep -i "^set-cookie: PHPSESSID" | head -1)
echo "$sp" | grep -qi "secure" && ko "spoofed X-Forwarded-Proto set Secure (lockout risk)" || ok "spoofed X-Forwarded-Proto ignored (no Secure)"

echo "== 9. Regression: public player + playlist =="
p=$(curl -s -o /dev/null -w "%{http_code}" "$B/player"); [ "$p" = "200" ] && ok "/player = 200" || ko "/player = $p"
pl=$(curl -s -o /dev/null -w "%{http_code}" "$B/api/playlist"); { [ "$pl" = "200" ] || [ "$pl" = "404" ]; } && ok "/api/playlist (public GET) = $pl" || ko "/api/playlist = $pl"

echo ""
echo "==================== RESULT: $pass passed, $fail failed ===================="
