'use strict';

const cfg = require('./config');
const { get } = require('./db');
const { sha256hex, constantTimeEqual } = require('./ids');

function now() { return Math.floor(Date.now() / 1000); }

// Parse "Authorization: Bearer <token>". Returns the raw token or null.
function bearer(req) {
  const h = req.headers['authorization'] || '';
  const m = /^Bearer\s+(.+)$/.exec(h);
  return m ? m[1].trim() : null;
}

// Parse a single cookie value out of the Cookie header. Returns the raw value or
// null. Used to read the opaque httpOnly console session cookie (zf_console) and
// the readable CSRF cookie (zf_csrf). The browser NEVER holds ADMIN_SECRET or a
// zfk_live_ key — the console principal is derived purely from this cookie.
function cookie(req, name) {
  const raw = req.headers['cookie'];
  if (!raw) return null;
  const parts = String(raw).split(';');
  for (const p of parts) {
    const idx = p.indexOf('=');
    if (idx < 0) continue;
    if (p.slice(0, idx).trim() === name) return p.slice(idx + 1).trim();
  }
  return null;
}

// Resolve the authenticated principal.
//  - Admin: header X-Admin-Secret (or Bearer == admin secret) matches ADMIN_SECRET.
//           Cross-tenant; tenant must be supplied & validated by the route.
//  - Tenant: Bearer zfk_live_... whose sha256 matches a non-revoked api_keys row.
//  - Console: opaque httpOnly cookie zf_console whose sha256 matches a live
//             console_sessions row -> { kind:'console', tenantId, ... }.
//
// ORDERING (preserve): admin (X-Admin-Secret) and tenant (Bearer zfk_live_)
// checks stay FIRST and UNCHANGED so /admin/* and existing tenant API behavior
// are byte-identical. The console kind is purely additive, resolved LAST.
//
// Returns { kind:'admin'|'tenant'|'console', tenantId, label, ... } or null.
function authenticate(req) {
  const token = bearer(req);
  const adminHeader = req.headers['x-admin-secret'] || (token || '');

  // Admin path (constant-time, env-only secret, no DB).
  if (adminHeader && constantTimeEqual(adminHeader, cfg.adminSecret)) {
    return { kind: 'admin', tenantId: null, label: 'admin' };
  }

  // Tenant API key path.
  if (token && token.startsWith('zfk_live_')) {
    const row = get().prepare(
      'SELECT tenant_id, label FROM api_keys WHERE key_hash = ? AND revoked_at IS NULL'
    ).get(sha256hex(token));
    if (row) return { kind: 'tenant', tenantId: row.tenant_id, label: row.label || 'api_key' };
  }

  // Console session path (same-origin BFF). Opaque httpOnly cookie -> sha256
  // lookup. Bumps last_seen_at on a live, non-revoked, unexpired session.
  const sid = cookie(req, 'zf_console');
  if (sid) {
    const ts = now();
    const row = get().prepare(
      `SELECT id, console_user_id, tenant_id FROM console_sessions
       WHERE session_id_hash = ? AND revoked_at IS NULL AND expires_at > ?`
    ).get(sha256hex(sid), ts);
    if (row) {
      try { get().prepare('UPDATE console_sessions SET last_seen_at=? WHERE id=?').run(ts, row.id); }
      catch (_) { /* best-effort; never blocks auth */ }
      return {
        kind: 'console',
        tenantId: row.tenant_id,
        consoleUserId: row.console_user_id,
        label: 'console:' + row.console_user_id
      };
    }
  }

  return null;
}

// For admin acting on a specific tenant: validate the tenant exists, return its id.
//
// CLAMP (MUST-FIX 1, BLOCKING isolation): for BOTH 'tenant' AND 'console'
// principals we IGNORE any client-supplied tenant and return the principal's OWN
// tenantId. A console operator can NEVER name another tenant via body/query — the
// console principal must NOT fall through to the admin body-trusting branch.
// Only the 'admin' principal may name an arbitrary (existing) tenant.
function resolveTenantScope(principal, requestedTenantId) {
  if (principal.kind === 'tenant' || principal.kind === 'console') {
    return principal.tenantId; // never trust the body/query — clamp to own tenant
  }
  // admin: must name an existing tenant for tenant-scoped operations
  const row = get().prepare('SELECT tenant_id FROM tenants WHERE tenant_id = ?').get(requestedTenantId);
  return row ? row.tenant_id : null;
}

module.exports = { authenticate, resolveTenantScope, cookie };
