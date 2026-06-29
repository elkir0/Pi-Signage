#!/usr/bin/env bash
# Zaforge — tests CLI pour la liaison compte (relay-lib.php + relay-status.sh).
# Hors-ligne : ne touche ni au relais ni au système (RELAY_STATUS_SKIP_RUNTIME=1).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/web/api/relay-lib.php"
STATUS_SH="$ROOT/scripts/relay-status.sh"
FAILED=0
ok()   { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILED=1; }

# ---------------------------------------------------------------------------
# 1) relay-lib.php : validation + masque (fonctions pures, sans réseau)
# ---------------------------------------------------------------------------
php -r '
  require "'"$LIB"'";
  $okv = relayValidateCode("ZF-AB12-CD34-EF56") === true;
  $bad = relayValidateCode("ZF-abc-1-2") === false
      && relayValidateCode("nope") === false
      && relayValidateCode("ZF-AB12-CD34-EF5") === false;
  $mask = relayMaskCode("ZF-AB12-CD34-EF56");
  $maskok = (strpos($mask, "EF56") !== false)            // dernier groupe visible
         && (strpos($mask, "AB12") === false)            // 1er groupe masqué
         && (strpos($mask, "CD34") === false);           // 2e groupe masqué
  fwrite(STDOUT, ($okv?"V1":"v0").($bad?"B1":"b0").($maskok?"M1":"m0"));
' 2>/tmp/relay-lib.err
RES="$(cat /tmp/relay-lib.err 2>/dev/null)"
OUT="$(php -r 'require "'"$LIB"'"; echo (relayValidateCode("ZF-AB12-CD34-EF56")?"1":"0").(relayValidateCode("bad")?"1":"0");' 2>/dev/null)"
[ "$OUT" = "10" ] && ok "relayValidateCode accepte un code valide, rejette l'invalide" || fail "relayValidateCode (got '$OUT')"
MASK="$(php -r 'require "'"$LIB"'"; echo relayMaskCode("ZF-AB12-CD34-EF56");' 2>/dev/null)"
case "$MASK" in
  *EF56) case "$MASK" in *AB12*|*CD34*) fail "relayMaskCode expose un groupe (got '$MASK')";; *) ok "relayMaskCode masque tout sauf le dernier groupe ('$MASK')";; esac ;;
  *) fail "relayMaskCode ne garde pas le dernier groupe (got '$MASK')" ;;
esac

# ---------------------------------------------------------------------------
# 2) relay-status.sh : parse des fichiers, JSON sanitisé, AUCUN secret
# ---------------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/relay"
cat > "$TMP/relay.json" <<'J'
{ "relay_url": "https://relay.zaforge.com", "enrollment_code": "ZF-AB12-CD34-EF56", "rebind": false }
J
printf 'ENABLE_KIOSK=1\nENABLE_RELAY=1\n' > "$TMP/feature_flags"
# Forme réelle persistée par l'agent : { nonce, enrolled_at, response:{...} }.
cat > "$TMP/relay/enrollment.json" <<'J'
{ "nonce":"abc", "enrolled_at":1782653676,
  "response": { "v":1, "device_id":"d_test123", "tenant_id":"t_test456", "fingerprint":"abcdef0123456789",
    "heartbeat_interval_s":30,
    "mqtt": { "base_topic":"zf/t_test456/d_test123", "username":"d_test123", "password":"SUPERSECRETMQTTPW" } } }
J

if [ ! -x "$STATUS_SH" ]; then
  fail "relay-status.sh absent ou non exécutable ($STATUS_SH)"
else
  JSON="$(RELAY_CONF_DIR="$TMP" RELAY_STATUS_SKIP_RUNTIME=1 "$STATUS_SH" 2>/tmp/relay-status.err)"
  echo "$JSON" | python3 -c '
import sys,json
d=json.load(sys.stdin)
assert d["linked"] is True, "linked"
assert d["enabled"] is True, "enabled"
assert d["relay_url"]=="https://relay.zaforge.com", "relay_url"
assert d["device_id"]=="d_test123", "device_id"
assert d["tenant_id"]=="t_test456", "tenant_id"
assert d["base_topic"]=="zf/t_test456/d_test123", "base_topic"
assert "EF56" in d["code_masked"] and "AB12" not in d["code_masked"], "code_masked"
' 2>/tmp/relay-status-assert.err && ok "relay-status.sh émet l'état attendu" || { fail "relay-status.sh JSON inattendu: $(cat /tmp/relay-status-assert.err)"; echo "  >> $JSON"; }

  # AUCUN secret ne doit fuiter (mot de passe MQTT, code complet en clair).
  if echo "$JSON" | grep -q "SUPERSECRETMQTTPW"; then fail "relay-status.sh FUITE le mot de passe MQTT"; else ok "relay-status.sh ne fuit pas le secret MQTT"; fi
  if echo "$JSON" | grep -q "ZF-AB12-CD34-EF56"; then fail "relay-status.sh expose le code en clair"; else ok "relay-status.sh masque le code d'enrôlement"; fi
fi

echo "---"
[ "$FAILED" -eq 0 ] && { echo "relay-account: ALL OK"; exit 0; } || { echo "relay-account: FAILURES"; exit 1; }
