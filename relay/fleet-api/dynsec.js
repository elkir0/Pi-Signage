'use strict';

// =============================================================================
// fleet-api/dynsec.js
// Drives the mosquitto dynamic-security plugin over its $CONTROL topic.
//
// CONNECTION (MUST-FIX H): we connect to the broker on the 8883 *TLS* listener
// (mqtts://10.10.10.160:8883), CA-verified with MQTT_CA_FILE. We do NOT use the
// plaintext in-tunnel 1883 listener — that one is bound to wg0 (10.70.0.1) for
// AGENTS ONLY. fleet-api lives on the private-IP service plane.
//
// PER-DEVICE AUTHZ MODEL:
//   On enroll, atomically with the SQLite write, provisionDevice() creates:
//     1) createClient(username=device_id, password=<issued once>)
//     2) createRole(device_<device_id>) with LITERAL ACLs — tenant_id + device_id
//        are baked into every topic. NO %c / %u substitution, NO wildcards. A
//        rooted Pi cannot widen its own scope because the broker, not the client,
//        owns these ACLs.
//          publish   zf/<t>/<d>/hb,status,result,event
//          subscribe zf/<t>/<d>/cmd   (+ publishClientReceive so it can RECEIVE)
//     3) addClientRole(device_id, device_<device_id>)
//   On retire: disableClient + removeClientRole + deleteRole + deleteClient.
//
// RECONCILE-ON-BOOT (source of truth = SQLite): rebuilds every active device's
// role + binding AND PRUNES orphans — any dynsec client/role named device_*
// that has no matching active device row is deleted. This converges the broker
// to the DB after restores, manual edits, or partial failures.
// =============================================================================

const mqtt = require('mqtt');
const fs = require('fs');
const crypto = require('crypto');
const cfg = require('./config');

const CONTROL = '$CONTROL/dynamic-security/v1';
const RESPONSE = '$CONTROL/dynamic-security/v1/response';

let client = null;
let ready = false;
const pending = new Map(); // correlationData(hex) -> { resolve, reject, timer }

// Build the 5 LITERAL ACLs for a device's own two-deep subtree. No wildcards,
// no %c/%u — tenant_id + device_id are concrete strings owned by the broker.
function deviceAcls(base) {
  return [
    { acltype: 'publishClientSend',    topic: `${base}/hb`,     priority: 0, allow: true },
    { acltype: 'publishClientSend',    topic: `${base}/status`, priority: 0, allow: true },
    { acltype: 'publishClientSend',    topic: `${base}/result`, priority: 0, allow: true },
    { acltype: 'publishClientSend',    topic: `${base}/event`,  priority: 0, allow: true },
    // 'subscribeLiteral' is the real dynsec acltype — a bare 'subscribe' is
    // SILENTLY DROPPED by mosquitto, leaving the device unable to SUBSCRIBE to its
    // own cmd topic (heartbeats still flow, but commands never arrive).
    { acltype: 'subscribeLiteral',     topic: `${base}/cmd`,    priority: 0, allow: true },
    // A device must also be allowed to RECEIVE what it subscribed to.
    { acltype: 'publishClientReceive', topic: `${base}/cmd`,    priority: 0, allow: true }
  ];
}

// Connect the dedicated admin client over TLS 8883 and subscribe to RESPONSE.
function connect() {
  return new Promise((resolve, reject) => {
    let ca;
    try {
      ca = fs.readFileSync(cfg.mqtt.caFile);
    } catch (e) {
      return reject(new Error(`[dynsec] cannot read MQTT_CA_FILE ${cfg.mqtt.caFile}: ${e.message}`));
    }
    client = mqtt.connect(cfg.mqtt.url, {
      username: cfg.mqtt.dynsecAdminUser,
      password: cfg.mqtt.dynsecAdminPassword,
      clientId: 'fleetapi-dynsec',
      protocolVersion: 5,        // MQTT5 -> correlationData for request/response
      ca,
      rejectUnauthorized: true,  // CA-verify the broker's 8883 cert
      reconnectPeriod: 2000,
      clean: true
    });
    client.on('connect', () => {
      client.subscribe(RESPONSE, { qos: 1 }, (err) => {
        if (err) return reject(err);
        ready = true;
        console.log('[dynsec] admin connected (8883/TLS)');
        resolve();
      });
    });
    client.on('message', (topic, payload, packet) => {
      if (topic !== RESPONSE) return;
      let body;
      try { body = JSON.parse(payload.toString()); } catch (_) { body = { responses: [] }; }
      const corr = packet && packet.properties && packet.properties.correlationData
        ? packet.properties.correlationData.toString('hex') : null;
      let key = corr;
      let p = corr ? pending.get(corr) : null;
      // The mosquitto dynsec plugin does NOT reliably echo the MQTT5 correlationData
      // property on its response (every response was being dropped -> dynsec_timeout).
      // send() is awaited sequentially, so when exactly ONE request is in flight we
      // match it unambiguously by FIFO.
      if (!p && pending.size === 1) {
        key = pending.keys().next().value;
        p = pending.get(key);
      }
      if (!p) return;
      pending.delete(key);
      clearTimeout(p.timer);
      p.resolve(body);
    });
    client.on('error', (e) => { if (!ready) reject(e); else console.error('[dynsec]', e.message); });
  });
}

// Send a batch of dynsec commands; await the correlated response (MQTT5).
function send(commands) {
  if (!ready) return Promise.reject(new Error('dynsec not ready'));
  return new Promise((resolve, reject) => {
    const corr = crypto.randomBytes(12);
    const key = corr.toString('hex');
    const timer = setTimeout(() => {
      pending.delete(key);
      reject(new Error('dynsec_timeout'));
    }, 8000);
    pending.set(key, { resolve, reject, timer });
    client.publish(CONTROL, JSON.stringify({ commands }), {
      qos: 1,
      properties: { correlationData: corr, responseTopic: RESPONSE }
    }, (err) => {
      if (err) { clearTimeout(timer); pending.delete(key); reject(err); }
    });
  });
}

// Tolerate "already exists" / "not found" so provisioning + pruning are idempotent.
function ignorable(errStr) {
  return /already exists|not found|does not exist/i.test(errStr || '');
}

function assertOk(res, ctx) {
  const errs = (res.responses || []).filter((r) => r.error && !ignorable(r.error));
  if (errs.length) {
    // Generic — never echo the password or full payload.
    throw new Error(`dynsec_${ctx}_failed: ${errs.map((e) => e.command + ':' + e.error).join(',')}`);
  }
}

// List all dynsec clients/roles so reconcile can find orphans. mosquitto returns
// { responses:[{ command:'listClients', data:{ clients:[...] } }] }.
async function listClients() {
  const res = await send([{ command: 'listClients', verbose: false, count: -1, offset: 0 }]);
  const r = (res.responses || []).find((x) => x.command === 'listClients');
  const c = r && r.data && r.data.clients ? r.data.clients : [];
  // listClients may return objects or bare usernames depending on verbose.
  return c.map((x) => (typeof x === 'string' ? x : x.username)).filter(Boolean);
}

async function listRoles() {
  const res = await send([{ command: 'listRoles', verbose: false, count: -1, offset: 0 }]);
  const r = (res.responses || []).find((x) => x.command === 'listRoles');
  const roles = r && r.data && r.data.roles ? r.data.roles : [];
  return roles.map((x) => (typeof x === 'string' ? x : x.rolename)).filter(Boolean);
}

// Provision a device: create its client (with the issued password), a per-device
// role scoped LITERALLY to its own subtree, then attach the role. On re-enroll
// (client already exists) we rotate the password and re-attach instead.
async function provisionDevice(tenantId, deviceId, password) {
  const base = `zf/${tenantId}/${deviceId}`;
  const roleName = `device_${deviceId}`;

  // createClient first; if it already exists, rotate the password + re-enable.
  const createRes = await send([{ command: 'createClient', username: deviceId, password }]);
  const createErr = (createRes.responses || []).find((r) => r.error);
  if (createErr && /already exists/i.test(createErr.error)) {
    await send([
      { command: 'setClientPassword', username: deviceId, password },
      { command: 'enableClient', username: deviceId }
    ]);
  } else {
    assertOk(createRes, 'createClient');
  }

  // (Re)build the role with the literal ACLs, then bind it. deleteRole-then-create
  // keeps the ACL set authoritative even if a stale role lingered.
  await send([{ command: 'deleteRole', rolename: roleName }]); // ignorable if absent
  assertOk(await send([
    { command: 'createRole', rolename: roleName, acls: deviceAcls(base) },
    { command: 'addClientRole', username: deviceId, rolename: roleName, priority: -1 }
  ]), 'provisionDevice');
}

// Retire a device: kill the live session and remove ALL of its dynsec footprint
// (client + role) so the topic ACLs vanish immediately. Idempotent.
async function retireDevice(deviceId) {
  const roleName = `device_${deviceId}`;
  const res = await send([
    { command: 'disableClient', username: deviceId },
    { command: 'removeClientRole', username: deviceId, rolename: roleName },
    { command: 'deleteRole', rolename: roleName },
    { command: 'deleteClient', username: deviceId }
  ]);
  assertOk(res, 'retireDevice');
}

// Reconcile dynsec from SQLite on boot (SQLite is the source of truth):
//   (1) (re)provision the role + binding for every ACTIVE device, and
//   (2) PRUNE ORPHANS — delete any dynsec client/role named device_* that has no
//       matching active device row. This converges the broker to the DB after a
//       restore, a manual edit, or a partial enroll/retire failure.
// `devices` is the non-retired device set; we never reset passwords (no plaintext).
async function reconcile(devices) {
  // Expected dynsec identity for every active device.
  const expectedClients = new Set();
  const expectedRoles = new Set();
  for (const d of devices) {
    expectedClients.add(d.device_id);
    expectedRoles.add(`device_${d.device_id}`);
  }

  // (1) Rebuild role + binding for each active device (NOT the password).
  for (const d of devices) {
    const roleName = `device_${d.device_id}`;
    const base = `zf/${d.tenant_id}/${d.device_id}`;
    try {
      await send([{ command: 'deleteRole', rolename: roleName }]); // ignorable
      assertOk(await send([
        { command: 'createRole', rolename: roleName, acls: deviceAcls(base) },
        { command: 'addClientRole', username: d.device_id, rolename: roleName, priority: -1 }
      ]), 'reconcile.provision');
    } catch (e) {
      console.warn('[dynsec reconcile] provision', d.device_id, e.message);
    }
  }

  // (2) Prune orphan device_* clients (anything not backed by an active row).
  try {
    const clients = await listClients();
    for (const username of clients) {
      // Only touch device clients; never delete admin / svc_fleetapi / dynsec-admin.
      if (!/^d_/.test(username)) continue;
      if (expectedClients.has(username)) continue;
      try {
        await send([
          { command: 'disableClient', username },
          { command: 'deleteClient', username }
        ]);
        console.log('[dynsec reconcile] pruned orphan client', username);
      } catch (e) { console.warn('[dynsec reconcile] prune client', username, e.message); }
    }
  } catch (e) {
    console.warn('[dynsec reconcile] listClients failed:', e.message);
  }

  // (3) Prune orphan device_* roles.
  try {
    const roles = await listRoles();
    for (const rolename of roles) {
      if (!/^device_d_/.test(rolename)) continue; // device roles only
      if (expectedRoles.has(rolename)) continue;
      try {
        await send([{ command: 'deleteRole', rolename }]);
        console.log('[dynsec reconcile] pruned orphan role', rolename);
      } catch (e) { console.warn('[dynsec reconcile] prune role', rolename, e.message); }
    }
  } catch (e) {
    console.warn('[dynsec reconcile] listRoles failed:', e.message);
  }
}

module.exports = { connect, provisionDevice, retireDevice, reconcile };
