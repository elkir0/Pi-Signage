'use strict';

const cfg = require('../config');
const { get } = require('../db');
const ids = require('../ids');
const alloc = require('../alloc');
const wg = require('../wg');
const dynsec = require('../dynsec');
const { send } = require('../http');

function now() { return Math.floor(Date.now() / 1000); }

// Build the 200 response body from a device row + the mqtt password that was
// issued for THIS enrollment. The same nonce always yields the same body
// (including the password) because the password is persisted, keyed to the code,
// on first success — see the idempotency note below. (MUST-FIX G.)
function buildResponse(dev, mqttPassword) {
  const mqtt = {
    host: cfg.wg.relayIp,   // 10.70.0.1 — broker's in-tunnel 1883 listener
    port: 1883,
    tls: false,             // confidentiality is the WireGuard tunnel (plaintext-over-WG)
    username: dev.mqtt_username,
    client_id: dev.device_id,
    keepalive: 30,
    base_topic: `zf/${dev.tenant_id}/${dev.device_id}`
  };
  if (mqttPassword) mqtt.password = mqttPassword; // shown each time for THIS code
  return {
    v: 1,
    device_id: dev.device_id,
    tenant_id: dev.tenant_id,
    fingerprint: dev.fingerprint,
    wg: {
      address: `${dev.wg_ip}/32`,
      allowed_ips: `${cfg.wg.relayIp}/32`, // RELAY ONLY — LAN-safe, client-side /32
      dns: null,
      peer: {
        public_key: cfg.wg.serverPubKey,
        endpoint: cfg.wg.endpoint,
        persistent_keepalive: cfg.wg.persistentKeepalive
      }
    },
    mqtt,
    heartbeat_interval_s: cfg.enroll.heartbeatIntervalS
  };
}

async function handle(req, res, ctx) {
  // 1) Rate-limit per source IP (brute-force guard on codes).
  if (!ctx.enrollLimiter(ctx.ip)) return send(res, 429, { v: 1, error: 'rate_limited' });

  // 2) Structural validation — uniform bad_request, no oracle.
  const b = ctx.body;
  if (!b || b.v !== 1 || typeof b.enrollment_code !== 'string' ||
      typeof b.nonce !== 'string' || b.nonce.length === 0 ||
      !ids.isValidWgPubKey(b.wg_public_key)) {
    return send(res, 400, { v: 1, error: 'bad_request' });
  }

  const db = get();
  const codeHash = ids.sha256hex(b.enrollment_code);
  const facts = (b.device_facts && typeof b.device_facts === 'object') ? b.device_facts : {};
  const ts = now();

  // ===========================================================================
  // 3) IDEMPOTENCY (MUST-FIX G): a lost-response retry MUST NOT burn the code.
  //
  //    ORDERING: this RE-READ happens BEFORE any atomic consume below. If the
  //    SAME (code_hash, nonce) was already consumed on a prior attempt, we
  //    re-read the persisted device row AND the persisted mqtt password and
  //    return the byte-identical 200 body. The Pi that missed the first
  //    response gets a usable config (incl. password) without re-consuming.
  //
  //    We key the replay on (code_hash, nonce) — the nonce is the agent's
  //    idempotency key, written atomically when the code was consumed. A
  //    DIFFERENT nonce against an already-consumed code is NOT a replay; it
  //    falls through and fails 'invalid_code' (single-use enforced).
  // ===========================================================================
  const prior = db.prepare(
    'SELECT * FROM enrollment_codes WHERE code_hash=? AND nonce=? AND consumed_at IS NOT NULL'
  ).get(codeHash, b.nonce);
  if (prior && prior.consumed_by) {
    const dev = db.prepare('SELECT * FROM devices WHERE device_id=?').get(prior.consumed_by);
    if (dev) {
      // Return the SAME body, including the password issued on first success.
      // issued_mqtt_password is stored once at consume time precisely so an
      // idempotent retry is non-destructive AND complete.
      return send(res, 200, buildResponse(dev, prior.issued_mqtt_password || null));
    }
    // Consumed but device vanished (should never happen) — fail closed, do NOT
    // re-consume or mint a new code.
    return send(res, 409, { v: 1, error: 'enroll_state_conflict' });
  }

  // 4) WG pubkey conflict: bound to a DIFFERENT, non-retired device -> 409.
  const conflict = db.prepare(
    "SELECT device_id FROM devices WHERE wg_public_key=? AND state!='retired'"
  ).get(b.wg_public_key);

  // Pre-compute identity that may be needed; only persisted if the tx consumes a code.
  const fingerprint = ids.wgFingerprint(b.wg_public_key);
  const mqttPassword = ids.newMqttPassword();
  const mqttPwFp = ids.sha256hex(mqttPassword);

  let result; // { dev, rebind }
  try {
    const tx = db.transaction(() => {
      // Atomic single-use consumption. Bind tenant from the code, not the client.
      const code = db.prepare(
        'SELECT * FROM enrollment_codes WHERE code_hash=? AND consumed_at IS NULL AND expires_at > ?'
      ).get(codeHash, ts);
      if (!code) throw new Error('invalid_code');
      const tenantId = code.tenant_id; // AUTHORITATIVE tenant binding

      // Rebind path: code.rebind=1 AND machine_id matches an existing non-retired
      // device in this tenant -> keep device_id, rotate wg key + mqtt password.
      let dev = null;
      let rebind = false;
      if (code.rebind === 1 && facts.machine_id) {
        dev = db.prepare(
          "SELECT * FROM devices WHERE tenant_id=? AND machine_id=? AND state!='retired'"
        ).get(tenantId, facts.machine_id);
      }

      if (dev) {
        // Rebind: the new pubkey must not collide with ANOTHER device.
        if (conflict && conflict.device_id !== dev.device_id) throw new Error('wg_key_conflict');
        rebind = true;
        db.prepare(`UPDATE devices SET
          wg_public_key=?, fingerprint=?, mqtt_pw_fp=?, agent_version=?,
          hostname=?, model=?, player_version=?, last_facts_json=?
          WHERE device_id=? AND tenant_id=?`)
          .run(b.wg_public_key, fingerprint, mqttPwFp,
            (b.agent && b.agent.version) || null, facts.hostname || null,
            facts.model || null, facts.player_version || null, JSON.stringify(facts),
            dev.device_id, tenantId);
        dev = db.prepare('SELECT * FROM devices WHERE device_id=?').get(dev.device_id);
      } else {
        // Fresh enroll. New device gets a server-allocated /32.
        if (conflict) throw new Error('wg_key_conflict');
        const deviceId = ids.newDeviceId();
        const { ip } = alloc.allocateDeviceIp(db, tenantId, ts); // asserts != relay ip
        db.prepare(`INSERT INTO devices(
          device_id, tenant_id, state, hostname, machine_id, model, player_version,
          agent_version, wg_public_key, wg_ip, fingerprint, mqtt_username, mqtt_pw_fp,
          online, last_facts_json, created_at)
          VALUES (?,?,'pending',?,?,?,?,?,?,?,?,?,?,0,?,?)`)
          .run(deviceId, tenantId, facts.hostname || null, facts.machine_id || null,
            facts.model || null, facts.player_version || null,
            (b.agent && b.agent.version) || null, b.wg_public_key, ip, fingerprint,
            deviceId, mqttPwFp, JSON.stringify(facts), ts);
        dev = db.prepare('SELECT * FROM devices WHERE device_id=?').get(deviceId);
      }

      // Consume the code atomically (single-use). Must affect exactly 1 row.
      // We persist the issued password + nonce HERE so the idempotent re-read in
      // step 3 can return the identical body on a lost-response retry.
      const upd = db.prepare(
        `UPDATE enrollment_codes
           SET consumed_at=?, consumed_by=?, nonce=?, issued_mqtt_password=?
         WHERE code_hash=? AND consumed_at IS NULL`
      ).run(ts, dev.device_id, b.nonce, mqttPassword, codeHash);
      if (upd.changes !== 1) throw new Error('invalid_code');

      db.prepare('INSERT INTO events(tenant_id, device_id, type, payload_json, ts) VALUES (?,?,?,?,?)')
        .run(tenantId, dev.device_id, rebind ? 'reenrolled' : 'enrolled',
          JSON.stringify({ rebind, ip: dev.wg_ip }), ts);

      return { dev, rebind };
    });
    result = tx();
  } catch (e) {
    if (e.message === 'wg_key_conflict') return send(res, 409, { v: 1, error: 'wg_key_conflict' });
    if (e.message === 'invalid_code') return send(res, 401, { v: 1, error: 'invalid_code' });
    if (e.message === 'wg_pool_exhausted') {
      console.error('[enroll] wg pool exhausted');
      return send(res, 503, { v: 1, error: 'capacity' });
    }
    // Never log the body (it carries the enrollment code) or any secret.
    console.error('[enroll] tx error:', e.message);
    return send(res, 400, { v: 1, error: 'bad_request' });
  }

  // 5) Side-effects AFTER commit (DB is source of truth; these are projections).
  //    Failures here are logged (no secrets); a boot-time reconcile re-converges.
  try { await wg.addPeer(result.dev.wg_public_key, result.dev.wg_ip); }
  catch (e) { console.error('[enroll] wg addPeer:', e.message); }
  try { await dynsec.provisionDevice(result.dev.tenant_id, result.dev.device_id, mqttPassword); }
  catch (e) { console.error('[enroll] dynsec provision:', e.message); }

  // 6) Return the wg + mqtt config. Password is part of the body; an identical
  //    retry (same nonce) returns the identical body via step 3.
  return send(res, 200, buildResponse(result.dev, mqttPassword));
}

module.exports = { handle };
