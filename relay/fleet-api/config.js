'use strict';

// Centralised, validated configuration. Read once at boot. Fail fast on missing
// critical secrets so we never run an insecure relay by accident.
//
// SECRETS (MUST-FIX L): every secret below comes from the process environment,
// which is populated ONLY from the 0600 .env file by docker compose. Secrets are
// NEVER hard-coded here, NEVER logged, and NEVER printed. `req()` logs only the
// NAME of a missing var, never a value.

function req(name) {
  const v = process.env[name];
  if (!v || v.length === 0) {
    console.error(`[config] FATAL: required env ${name} is missing`);
    process.exit(1);
  }
  return v;
}

function opt(name, def) {
  const v = process.env[name];
  return v === undefined || v === '' ? def : v;
}

function intOpt(name, def) {
  const v = process.env[name];
  if (v === undefined || v === '') return def;
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : def;
}

module.exports = {
  // ---- HTTP ----
  httpPort: intOpt('PORT', 3200),
  // Bound to the private IP by compose (10.10.10.160). CT101 terminates public TLS
  // and proxies here. Default kept conservative.
  httpHost: opt('HTTP_HOST', '0.0.0.0'),

  // ---- DB ----
  dbPath: opt('DB_PATH', '/data/zaforge.db'),

  // ---- Secrets ----
  // Admin secret is env-only, hashed-compared, cross-tenant. Never stored in DB.
  adminSecret: req('ADMIN_SECRET'), // "zfadm_" + 48 chars

  // ---- WireGuard ----
  wg: {
    // The wireguard container service/container name (docker compose) + interface.
    containerName: opt('WG_CONTAINER', 'zf-wireguard'),
    iface: opt('WG_IFACE', 'wg0'),
    // Server-side facts handed to the Pi at enrollment.
    serverPubKey: req('WG_SERVER_PUBLIC_KEY'),
    endpoint: opt('WG_ENDPOINT', 'relay.zaforge.com:51840'),
    relayIp: opt('WG_RELAY_IP', '10.70.0.1'), // the /32 the Pi is allowed to reach
    persistentKeepalive: intOpt('WG_KEEPALIVE', 25),
    // Pool the tenant /28 blocks are carved from. 10.70.0.0/16.
    poolCidr: opt('WG_POOL_CIDR', '10.70.0.0/16'),
    // RESERVED server block (holds the relay 10.70.0.1). Tenant blocks start AFTER
    // this — first tenant /28 is 10.70.0.16/28. (MUST-FIX F.)
    reservedCidr: opt('WG_RESERVED_CIDR', '10.70.0.0/28')
  },

  // ---- MQTT ----
  // The fleet-api connects to the broker over the TLS 8883 control/service plane
  // (private IP, CA-verified). The plaintext 1883 listener is bound to wg0
  // (10.70.0.1) for AGENTS ONLY — fleet-api never uses it. (MUST-FIX H.)
  mqtt: {
    url: opt('MQTT_URL', 'mqtts://10.10.10.160:8883'),
    caFile: opt('MQTT_CA_FILE', '/certs/ca.crt'),
    // Privileged service user (role fleet_service: pub/sub zf/#). Provisioned in dynsec.
    svcUser: opt('MQTT_SVC_USER', 'svc_fleetapi'),
    svcPassword: req('MQTT_SVC_PASSWORD'),
    clientId: opt('MQTT_SVC_CLIENT_ID', 'fleetapi'),
    // Admin client for the $CONTROL/dynamic-security/v1 topic (createClient/createRole...).
    dynsecAdminUser: opt('DYNSEC_ADMIN_USER', 'dynsec-admin'),
    dynsecAdminPassword: req('DYNSEC_ADMIN_PASSWORD')
  },

  // ---- Enrollment ----
  enroll: {
    codeTtlSeconds: intOpt('ENROLL_CODE_TTL', 3600), // 60 min default per contract
    heartbeatIntervalS: intOpt('HEARTBEAT_INTERVAL_S', 30),
    // Brute-force guard on /enroll per source IP.
    rateMaxPerMin: intOpt('ENROLL_RATE_PER_MIN', 20),
    maxBodyBytes: intOpt('ENROLL_MAX_BODY', 16 * 1024)
  },

  // ---- Liveness thresholds (contract: stale 3x, offline 6x interval) ----
  staleAfterS: intOpt('STALE_AFTER_S', 90),
  offlineAfterS: intOpt('OFFLINE_AFTER_S', 180)
};
