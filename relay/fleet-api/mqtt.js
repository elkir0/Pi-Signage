'use strict';

const mqtt = require('mqtt');
const fs = require('fs');
const cfg = require('./config');
const { get } = require('./db');

let client = null;

function now() { return Math.floor(Date.now() / 1000); }

// Hard cap on an inbound broker payload. Telemetry/status/result/event are all
// small JSON; this bounds the buffer+toString+JSON.parse cost so a rooted enrolled
// device cannot push multi-MB messages to exhaust the single shared Node process.
// Mirrors the broker-side message_size_limit. (Kept >= broker limit.)
const MAX_MQTT_PAYLOAD = 131072; // 128 KB

// Per-device inbound message throttle. A compromised device cannot flood the
// growth tables (events / processed_events) or the parser. Bounded-size, lazily
// swept. Generous vs legitimate cadence (heartbeat ~2/min + occasional status/
// result/event); sustained abuse beyond the cap is silently dropped before any
// DB write. Topic ACLs already confine a device to its OWN subtree.
const deviceMsgWindows = new Map();
function deviceRateOk(deviceId) {
  const nowMs = Date.now();
  if (deviceMsgWindows.size > 100000) {
    for (const [k, w] of deviceMsgWindows) if (nowMs - w.windowStart >= 60000) deviceMsgWindows.delete(k);
  }
  const w = deviceMsgWindows.get(deviceId);
  if (!w || nowMs - w.windowStart >= 60000) { deviceMsgWindows.set(deviceId, { windowStart: nowMs, count: 1 }); return true; }
  if (w.count >= 120) return false; // 120 msgs/min/device
  w.count += 1;
  return true;
}

// Look up a device by its MQTT username (== device_id). The relay AUTHORITATIVELY
// derives tenant_id from THIS row, never from any client-supplied field.
function deviceByUsername(username) {
  return get().prepare('SELECT * FROM devices WHERE mqtt_username = ?').get(username);
}

// Idempotency guard: returns true if this msg_key was already processed.
function alreadyProcessed(msgKey, tenantId) {
  const ins = get().prepare(
    'INSERT OR IGNORE INTO processed_events(msg_key, tenant_id, processed_at) VALUES (?,?,?)'
  );
  const r = ins.run(msgKey, tenantId, now());
  return r.changes === 0; // 0 => row already existed => duplicate
}

function connect() {
  return new Promise((resolve, reject) => {
    let ca;
    try { if (cfg.mqtt.caFile) ca = fs.readFileSync(cfg.mqtt.caFile); }
    catch (e) { console.error('[mqtt] cannot read CA', cfg.mqtt.caFile, e.message); }
    client = mqtt.connect(cfg.mqtt.url, {
      username: cfg.mqtt.svcUser,
      password: cfg.mqtt.svcPassword,
      clientId: cfg.mqtt.clientId,
      reconnectPeriod: 2000,
      clean: true,
      keepalive: 30,
      ca: ca ? [ca] : undefined,
      rejectUnauthorized: true
    });

    client.on('connect', () => {
      const subs = ['zf/+/+/hb', 'zf/+/+/status', 'zf/+/+/result', 'zf/+/+/event'];
      client.subscribe(subs, { qos: 1 }, (err) => {
        if (err) return reject(err);
        console.log('[mqtt] svc_fleetapi connected, subscribed control plane');
        resolve();
      });
    });

    client.on('message', onMessage);
    client.on('error', (e) => { console.error('[mqtt]', e.message); });
  });
}

function onMessage(topic, payload) {
  // Bound memory + parse cost: drop oversized payloads BEFORE toString()/JSON.parse.
  if (payload.length > MAX_MQTT_PAYLOAD) return;
  // topic = zf/<tenant>/<device>/<kind>
  const parts = topic.split('/');
  if (parts.length !== 4 || parts[0] !== 'zf') return;
  const username = parts[2];
  const kind = parts[3];

  const dev = deviceByUsername(username);
  if (!dev) return; // unknown device — broker ACLs should prevent this anyway
  if (!deviceRateOk(dev.device_id)) return; // shed per-device floods before any INSERT
  const tenantId = dev.tenant_id; // AUTHORITATIVE

  let msg;
  try { msg = JSON.parse(payload.toString()); } catch (_) { return; }
  if (msg && typeof msg.v === 'number' && msg.v > 1) return; // forward-compat: ignore higher v

  const ts = now();
  try {
    switch (kind) {
      case 'hb': return onHeartbeat(dev, tenantId, msg, ts);
      case 'status': return onStatus(dev, tenantId, msg, ts);
      case 'result': return onResult(dev, tenantId, msg, ts);
      case 'event': return onEvent(dev, tenantId, msg, ts);
    }
  } catch (e) {
    console.error(`[mqtt] handler error ${kind} ${dev.device_id}:`, e.message);
  }
}

function onHeartbeat(dev, tenantId, msg, ts) {
  // De-dupe QoS1 redelivery. Key by the heartbeat's own emission timestamp
  // (msg.ts), NOT its seq: the agent resets seq to 0 on every boot ("seq
  // increments per boot"), so a seq-keyed dedup collides with a PRIOR boot's
  // already-processed keys and silently drops EVERY heartbeat after an agent
  // restart until the counter climbs past the old max — the device looks offline
  // while happily heartbeating. msg.ts is wall-clock monotonic across reboots, so
  // a restarted agent's heartbeats are always fresh keys. (Re-processing a hb is
  // harmless anyway: the devices UPDATE and the telemetry UPSERT are idempotent.)
  const key = `${dev.device_id}:hb:${msg.ts != null ? msg.ts : ts}`;
  if (alreadyProcessed(key, tenantId)) return;

  const db = get();
  const tx = db.transaction(() => {
    db.prepare(`UPDATE devices
      SET last_heartbeat_at=?, online=1,
          last_seen_at=MAX(COALESCE(last_status_at,0), ?),
          agent_version=COALESCE(?, agent_version)
      WHERE device_id=? AND tenant_id=?`)
      .run(ts, ts, msg.agent_version || null, dev.device_id, tenantId);

    db.prepare(`INSERT INTO device_telemetry(device_id, tenant_id, ts, player_json, system_json, seq)
      VALUES (?,?,?,?,?,?)
      ON CONFLICT(device_id) DO UPDATE SET
        ts=excluded.ts, player_json=excluded.player_json,
        system_json=excluded.system_json, seq=excluded.seq`)
      .run(dev.device_id, tenantId, ts,
        msg.player ? JSON.stringify(msg.player) : null,
        msg.system ? JSON.stringify(msg.system) : null,
        msg.seq != null ? msg.seq : null);
  });
  tx();
}

function onStatus(dev, tenantId, msg, ts) {
  // retained lifecycle. online:false may be the LWT (reason:"lwt") or graceful.
  const online = msg && msg.online === true ? 1 : 0;
  const db = get();
  db.prepare(`UPDATE devices
    SET online=?, last_status_at=?, last_seen_at=MAX(COALESCE(last_heartbeat_at,0), ?)
    WHERE device_id=? AND tenant_id=?`)
    .run(online, ts, ts, dev.device_id, tenantId);
}

function onResult(dev, tenantId, msg, ts) {
  if (!msg || !msg.cmd_id) return;
  const key = `${dev.device_id}:result:${msg.cmd_id}`;
  if (alreadyProcessed(key, tenantId)) return;
  // Correlate to the issued command — scoped by tenant + device (never trust body).
  get().prepare(`UPDATE commands
    SET result_code=?, result_json=?, result_at=?
    WHERE cmd_id=? AND tenant_id=? AND device_id=?`)
    .run(msg.code || (msg.ok ? 'applied' : 'error'), JSON.stringify(msg), ts,
      msg.cmd_id, tenantId, dev.device_id);
}

function onEvent(dev, tenantId, msg, ts) {
  const key = `${dev.device_id}:event:${msg.event_id || msg.type + ':' + (msg.ts || ts)}`;
  if (alreadyProcessed(key, tenantId)) return;
  get().prepare('INSERT INTO events(tenant_id, device_id, type, payload_json, ts) VALUES (?,?,?,?,?)')
    .run(tenantId, dev.device_id, msg.type || 'unknown', JSON.stringify(msg), ts);

  // ---- Billing trigger (MUST-FIX 7) ----------------------------------------
  // content-synced: the agent reports the assigned playlist is FULLY cached
  // locally. content_cached=1 is the brick-proof gate that guarantees a screen is
  // never billed before its content is locally cached. content-cleared /
  // content-stale flips it back to 0. After either change we debounce a
  // per-screen quantity sync so Stripe reflects the new active+cached count.
  // NOTE: this NEVER mutates the player or the broker — it only updates the
  // billable-count projection. The heartbeat/status/result handlers are untouched.
  const t = msg && typeof msg.type === 'string' ? msg.type : '';
  if (t === 'content-synced' || t === 'content-cleared' || t === 'content-stale') {
    const cached = t === 'content-synced' ? 1 : 0;
    try {
      get().prepare(
        'UPDATE devices SET content_cached=?, content_cached_at=? WHERE device_id=? AND tenant_id=?'
      ).run(cached, ts, dev.device_id, tenantId);
    } catch (e) { console.error('[mqtt] content_cached update:', e.message); }
    // Lazy require avoids a load-time cycle (billing -> entitlement -> db). If
    // billing is unconfigured, debounceSyncQuantity is a cheap no-op.
    try { require('./routes/billing').debounceSyncQuantity(tenantId); }
    catch (e) { console.error('[mqtt] debounce qty:', e.message); }
  }
}

// Publish a targeted command to a device. Caller (routes) has already verified the
// device is 'active' and derived the tenant. Topic is built from the AUTHORITATIVE
// device row, never from request input.
function publishCommand(dev, cmd) {
  const topic = `zf/${dev.tenant_id}/${dev.device_id}/cmd`;
  client.publish(topic, JSON.stringify(cmd), { qos: 1 });
}

module.exports = { connect, publishCommand };
