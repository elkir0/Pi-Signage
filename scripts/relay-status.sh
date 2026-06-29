#!/bin/sh
# Zaforge — état de liaison au relais, en LECTURE SEULE, JSON SANITISÉ sur stdout.
# www-data ne peut pas lire relay.json (pi:pi 0640) ni relay/ (pi:pi 0700) → ce helper
# root les lit et n'émet QUE des champs non-secrets (code masqué ; jamais le token agent,
# le mot de passe MQTT ou les clés WireGuard).
#
# INVARIANT SÉCURITÉ : root:root 0755. Appelé par www-data via sudo (sudoers, sans arg).
# Usage :  sudo /opt/pisignage/scripts/relay-status.sh
#
# Test hors-ligne : RELAY_CONF_DIR=<dir> RELAY_STATUS_SKIP_RUNTIME=1 (saute systemctl/wg/ip).
set -eu

CONF="${RELAY_CONF_DIR:-/opt/pisignage/config}"
RELAY_JSON="$CONF/relay.json"
FF="$CONF/feature_flags"
ENROLL_JSON="$CONF/relay/enrollment.json"

# --- Signaux runtime (best-effort ; sautés en test) ---
agent_active="unknown"
tunnel_up="no"
handshake_age=""   # vide = inconnu
if [ "${RELAY_STATUS_SKIP_RUNTIME:-0}" != "1" ]; then
    agent_active="$(systemctl is-active zaforge-agent.service 2>/dev/null || echo inactive)"
    if ip link show zf0 >/dev/null 2>&1; then tunnel_up="yes"; fi
    # Âge du dernier handshake WireGuard (proxy fiable de « connecté au relais »).
    hs="$(wg show zf0 latest-handshakes 2>/dev/null | awk '{print $2; exit}' || true)"
    if [ -n "${hs:-}" ] && [ "$hs" -gt 0 ] 2>/dev/null; then
        now="$(date +%s)"
        handshake_age="$((now - hs))"
    fi
fi

# --- Lecture + sanitisation via python3 (parse JSON robuste, jamais de secret en sortie) ---
RELAY_JSON="$RELAY_JSON" FF="$FF" ENROLL_JSON="$ENROLL_JSON" \
AGENT_ACTIVE="$agent_active" TUNNEL_UP="$tunnel_up" HANDSHAKE_AGE="$handshake_age" \
python3 - <<'PY'
import os, json, re

def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}

relay  = load(os.environ.get("RELAY_JSON", ""))
enroll = load(os.environ.get("ENROLL_JSON", ""))
# L'agent persiste { nonce, enrolled_at, response:{...} }. On lit sous "response"
# si présent, sinon à plat (tolère les deux formes + les tests).
if isinstance(enroll.get("response"), dict):
    enroll = enroll["response"]

# feature_flags : ENABLE_RELAY=1 ?
enabled = False
try:
    with open(os.environ.get("FF", "")) as f:
        for line in f:
            if line.strip() == "ENABLE_RELAY=1":
                enabled = True
except Exception:
    pass

code = str(relay.get("enrollment_code", "") or "")
valid = bool(re.match(r'^ZF-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$', code))
code_masked = ("ZF-\u2022\u2022\u2022\u2022-\u2022\u2022\u2022\u2022-" + code.split('-')[3]) if valid else ""

mqtt = enroll.get("mqtt", {}) if isinstance(enroll.get("mqtt", {}), dict) else {}
fp = str(enroll.get("fingerprint", "") or "")
fp_short = fp[:12]

agent_active = os.environ.get("AGENT_ACTIVE", "unknown")
tunnel_up = os.environ.get("TUNNEL_UP", "no") == "yes"
hs_raw = os.environ.get("HANDSHAKE_AGE", "")
last_handshake_age_s = int(hs_raw) if hs_raw.isdigit() else None

# « connecté » = agent actif ET handshake récent (< 240s). Si handshake inconnu
# (skip-runtime/test), on retombe sur agent_active seul.
if last_handshake_age_s is not None:
    connected = (agent_active == "active") and (last_handshake_age_s < 240)
else:
    connected = (agent_active == "active") and tunnel_up

out = {
    "linked": valid,
    "enabled": enabled,
    "relay_url": str(relay.get("relay_url", "") or ""),
    "code_masked": code_masked,
    "rebind": bool(relay.get("rebind", False)),
    "device_id": str(enroll.get("device_id", "") or ""),
    "tenant_id": str(enroll.get("tenant_id", "") or ""),
    "fingerprint": fp_short,
    "base_topic": str(mqtt.get("base_topic", "") or ""),
    "heartbeat_interval_s": int(enroll.get("heartbeat_interval_s", 0) or 0),
    "agent_active": agent_active,
    "tunnel_up": tunnel_up,
    "last_handshake_age_s": last_handshake_age_s,
    "connected": connected,
}
print(json.dumps(out, ensure_ascii=False))
PY
