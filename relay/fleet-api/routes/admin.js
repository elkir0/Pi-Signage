'use strict';

const cfg = require('../config');
const { get } = require('../db');
const ids = require('../ids');
const wg = require('../wg');
const dynsec = require('../dynsec');
const mqttClient = require('../mqtt');
const { authenticate, resolveTenantScope } = require('../auth');
const { send } = require('../http');

function now() { return Math.floor(Date.now() / 1000); }

// Derive a liveness badge per contract: online (hb<90s) / stale (90-180s) / offline.
function badge(dev, ts) {
  if (dev.online === 0) return 'offline'; // LWT landed or graceful offline
  const seen = dev.last_seen_at || 0;
  const age = ts - seen;
  if (age <= cfg.staleAfterS) return 'online';
  if (age <= cfg.offlineAfterS) return 'stale';
  return 'offline';
}

const KNOWN_CMD_TYPES = new Set([
  'push-playlist', 'switch', 'reload', 'play', 'pause', 'next', 'prev',
  'screenshot', 'get-stats', 'reboot', 'ota'
]);

async function handle(req, res, ctx) {
  const principal = authenticate(req);
  if (!principal) return send(res, 401, { v: 1, error: 'unauthorized' });

  const url = new URL(req.url, 'http://relay.local');
  const seg = url.pathname.replace(/^\/(admin|api)\/?/, '').split('/').filter(Boolean);
  const ts = now();

  // ---- GET /admin/devices  (list, tenant-scoped) ----
  if (req.method === 'GET' && seg[0] === 'devices' && seg.length === 1) {
    const tenantId = resolveTenantScope(principal, url.searchParams.get('tenant_id'));
    if (!tenantId) return send(res, 400, { v: 1, error: 'bad_tenant' });
    const rows = get().prepare(
      "SELECT * FROM devices WHERE tenant_id=? AND state!='retired' ORDER BY created_at DESC"
    ).all(tenantId);
    const devices = rows.map((d) => ({
      device_id: d.device_id, state: d.state, hostname: d.hostname, model: d.model,
      fingerprint: d.fingerprint, wg_ip: d.wg_ip, agent_version: d.agent_version,
      player_version: d.player_version, badge: badge(d, ts),
      last_seen_at: d.last_seen_at, last_heartbeat_at: d.last_heartbeat_at,
      online: d.online === 1, created_at: d.created_at, confirmed_at: d.confirmed_at
    }));
    return send(res, 200, { v: 1, devices });
  }

  // ---- GET /admin/devices/:id  (detail + latest telemetry) ----
  if (req.method === 'GET' && seg[0] === 'devices' && seg.length === 2) {
    const tenantId = resolveTenantScope(principal, url.searchParams.get('tenant_id'));
    if (!tenantId) return send(res, 400, { v: 1, error: 'bad_tenant' });
    const d = get().prepare('SELECT * FROM devices WHERE device_id=? AND tenant_id=?').get(seg[1], tenantId);
    if (!d) return send(res, 404, { v: 1, error: 'not_found' });
    const tel = get().prepare('SELECT * FROM device_telemetry WHERE device_id=? AND tenant_id=?').get(d.device_id, tenantId);
    return send(res, 200, {
      v: 1, device: { ...d, online: d.online === 1, badge: badge(d, ts) },
      telemetry: tel ? { ts: tel.ts, seq: tel.seq,
        player: tel.player_json ? JSON.parse(tel.player_json) : null,
        system: tel.system_json ? JSON.parse(tel.system_json) : null } : null
    });
  }

  // ---- POST /admin/devices/:id/confirm  (pending -> active) ----
  if (req.method === 'POST' && seg[0] === 'devices' && seg[2] === 'confirm') {
    const tenantId = resolveTenantScope(principal, (ctx.body && ctx.body.tenant_id) || url.searchParams.get('tenant_id'));
    if (!tenantId) return send(res, 400, { v: 1, error: 'bad_tenant' });
    const r = get().prepare(
      "UPDATE devices SET state='active', confirmed_at=? WHERE device_id=? AND tenant_id=? AND state='pending'"
    ).run(ts, seg[1], tenantId);
    if (r.changes !== 1) return send(res, 409, { v: 1, error: 'not_pending' });
    return send(res, 200, { v: 1, device_id: seg[1], state: 'active' });
  }

  // ---- POST /admin/devices/:id/retire ----
  if (req.method === 'POST' && seg[0] === 'devices' && seg[2] === 'retire') {
    const tenantId = resolveTenantScope(principal, (ctx.body && ctx.body.tenant_id) || url.searchParams.get('tenant_id'));
    if (!tenantId) return send(res, 400, { v: 1, error: 'bad_tenant' });
    const d = get().prepare('SELECT * FROM devices WHERE device_id=? AND tenant_id=?').get(seg[1], tenantId);
    if (!d) return send(res, 404, { v: 1, error: 'not_found' });
    get().prepare("UPDATE devices SET state='retired', retired_at=?, online=0 WHERE device_id=? AND tenant_id=?")
      .run(ts, d.device_id, tenantId);
    // Revoke at the WG + broker layers immediately (frees the /32 implicitly: retired
    // rows are excluded from the taken-set in alloc).
    try { await wg.removePeer(d.wg_public_key); } catch (e) { console.error('[retire] wg:', e.message); }
    try { await dynsec.retireDevice(d.device_id); } catch (e) { console.error('[retire] dynsec:', e.message); }
    get().prepare('INSERT INTO events(tenant_id, device_id, type, payload_json, ts) VALUES (?,?,?,?,?)')
      .run(tenantId, d.device_id, 'retired', '{}', ts);
    return send(res, 200, { v: 1, device_id: d.device_id, state: 'retired' });
  }

  // ---- POST /admin/devices/:id/command  (publish a command) ----
  if (req.method === 'POST' && seg[0] === 'devices' && seg[2] === 'command') {
    const body = ctx.body || {};
    const tenantId = resolveTenantScope(principal, body.tenant_id || url.searchParams.get('tenant_id'));
    if (!tenantId) return send(res, 400, { v: 1, error: 'bad_tenant' });
    if (!KNOWN_CMD_TYPES.has(body.type)) return send(res, 400, { v: 1, error: 'unknown_command' });

    const d = get().prepare('SELECT * FROM devices WHERE device_id=? AND tenant_id=?').get(seg[1], tenantId);
    if (!d) return send(res, 404, { v: 1, error: 'not_found' });
    // SERVER-SIDE GATE: never publish to a non-active (pending/retired) device.
    if (d.state !== 'active') return send(res, 409, { v: 1, error: 'device_not_active' });

    const cmdId = ids.newCmdId();
    const cmd = { v: 1, ts, cmd_id: cmdId, type: body.type, args: body.args || {} };
    get().prepare(`INSERT INTO commands(cmd_id, tenant_id, device_id, type, args_json, issued_by, issued_at)
      VALUES (?,?,?,?,?,?,?)`)
      .run(cmdId, tenantId, d.device_id, body.type, JSON.stringify(cmd.args), principal.label, ts);
    mqttClient.publishCommand(d, cmd);
    return send(res, 202, { v: 1, cmd_id: cmdId, device_id: d.device_id, type: body.type });
  }

  // ---- POST /admin/codes  (generate an enrollment code) ----
  if (req.method === 'POST' && seg[0] === 'codes' && seg.length === 1) {
    const body = ctx.body || {};
    const tenantId = resolveTenantScope(principal, body.tenant_id || url.searchParams.get('tenant_id'));
    if (!tenantId) return send(res, 400, { v: 1, error: 'bad_tenant' });
    const code = ids.newEnrollmentCode();
    const ttl = Number.isInteger(body.ttl_seconds) ? body.ttl_seconds : cfg.enroll.codeTtlSeconds;
    const rebind = body.rebind === true ? 1 : 0;
    get().prepare(`INSERT INTO enrollment_codes(code_hash, tenant_id, rebind, created_at, expires_at)
      VALUES (?,?,?,?,?)`)
      .run(ids.sha256hex(code), tenantId, rebind, ts, ts + ttl);
    // The plaintext code is returned ONCE to the console for the operator to copy.
    return send(res, 201, { v: 1, code, tenant_id: tenantId, expires_at: ts + ttl, rebind: rebind === 1 });
  }

  // ---- ADMIN-ONLY: POST /admin/tenants  (bootstrap a tenant + first API key) ----
  if (req.method === 'POST' && seg[0] === 'tenants' && seg.length === 1) {
    if (principal.kind !== 'admin') return send(res, 403, { v: 1, error: 'forbidden' });
    const body = ctx.body || {};
    if (!body.name) return send(res, 400, { v: 1, error: 'bad_request' });
    const tenantId = ids.newTenantId();
    const apiKey = ids.newApiKey();
    const tx = get().transaction(() => {
      get().prepare('INSERT INTO tenants(tenant_id, name, status, created_at) VALUES (?,?,?,?)')
        .run(tenantId, body.name, 'active', ts);
      get().prepare('INSERT INTO api_keys(tenant_id, key_hash, label, created_at) VALUES (?,?,?,?)')
        .run(tenantId, ids.sha256hex(apiKey), body.key_label || 'default', ts);
    });
    tx();
    return send(res, 201, { v: 1, tenant_id: tenantId, api_key: apiKey }); // key shown once
  }

  return send(res, 404, { v: 1, error: 'not_found' });
}

module.exports = { handle };
