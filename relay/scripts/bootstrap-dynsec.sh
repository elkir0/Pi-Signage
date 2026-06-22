#!/usr/bin/env bash
# =============================================================================
# VM600 ONLY — one-time dynamic-security bootstrap.
# Precondition: wireguard + mosquitto containers are UP (mosquitto on 10.70.0.1).
# Reads DYNSEC_ADMIN_PASSWORD + MQTT_SVC_PASSWORD from ./.env (the same names
# fleet-api/config.js + docker-compose.yml use, so the svc_fleetapi password set
# here is identical to the one fleet-api authenticates with).
# Idempotent-ish: re-running setClientPassword/createRole is safe; createClient
# on an existing client errors harmlessly (we ignore 'already exists').
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

MC="docker exec -i zf-mosquitto mosquitto_ctrl"
# mosquitto_ctrl talks to the local broker on the in-tunnel listener.
CONN="-h 10.70.0.1 -p 1883 -u dynsec-admin -P ${DYNSEC_ADMIN_PASSWORD}"

# 0) FIRST-EVER init only: if dynamic-security.json is still the placeholder,
#    initialise it properly. `dynsec init` writes the file + sets admin pw.
if docker exec zf-mosquitto sh -c 'grep -q REPLACE_ME /mosquitto/data/dynamic-security.json' 2>/dev/null; then
  echo '== first-time dynsec init =='
  docker exec -i zf-mosquitto mosquitto_ctrl dynsec init \
    /mosquitto/data/dynamic-security.json dynsec-admin "${DYNSEC_ADMIN_PASSWORD}"
  echo 'Restarting broker to load the initialised dynsec file...'
  docker compose restart mosquitto
  sleep 5
fi

# 1) svc_fleetapi role + client (the privileged control-plane principal).
$MC $CONN dynsec createRole fleet_service       2>/dev/null || true
$MC $CONN dynsec addRoleACL fleet_service subscribePattern   'zf/#' allow 2>/dev/null || true
$MC $CONN dynsec addRoleACL fleet_service publishClientSend    'zf/#' allow 2>/dev/null || true
$MC $CONN dynsec addRoleACL fleet_service publishClientReceive 'zf/#' allow 2>/dev/null || true
$MC $CONN dynsec createClient svc_fleetapi      2>/dev/null || true
$MC $CONN dynsec setClientPassword svc_fleetapi "${MQTT_SVC_PASSWORD}"
$MC $CONN dynsec addClientRole svc_fleetapi fleet_service 2>/dev/null || true

echo 'dynsec bootstrap complete. Per-device clients are created by fleet-api at enrollment.'
