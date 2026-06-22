'use strict';

const mqtt = require('mqtt');
const cfg = require('./config');
const { get } = require('./db');

let client = null;

function now() { return Math.floor(Date.now() / 1000); }

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
    client = mqtt.connect(cfg.mqtt.url, {
      username: cfg.mqtt.svcUser,
      password: cfg.mqtt.svcPassword,
      clientId: cfg.mqtt.clientId,
      reconnectPeriod: 2000,
      clean: true,
      keepalive: 30
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
  // topic = zf/<tenant>/<device>/<kind>
  const parts = topic.split('/');
  if (parts.length !== 4 || parts[0] !== 'zf') return;
  const username = parts[2];
  const kind = parts[3];

  const dev = deviceByUsername(username);
  if (!dev) return; // unknown device — broker ACLs should prevent this anyway
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
  // De-dupe redelivery on (device, seq).
  const key = `${dev.device_id}:hb:${msg.seq != null ? msg.seq : ts}`;
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
}

// Publish a targeted command to a device. Caller (routes) has already verified the
// device is 'active' and derived the tenant. Topic is built from the AUTHORITATIVE
// device row, never from request input.
function publishCommand(dev, cmd) {
  const topic = `zf/${dev.tenant_id}/${dev.device_id}/cmd`;
  client.publish(topic, JSON.stringify(cmd), { qos: 1 });
}

module.exports = { connect, publishCommand };
