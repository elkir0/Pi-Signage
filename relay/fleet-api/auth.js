'use strict';

const cfg = require('./config');
const { get } = require('./db');
const { sha256hex, constantTimeEqual } = require('./ids');

// Parse "Authorization: Bearer <token>". Returns the raw token or null.
function bearer(req) {
  const h = req.headers['authorization'] || '';
  const m = /^Bearer\s+(.+)$/.exec(h);
  return m ? m[1].trim() : null;
}

// Resolve the authenticated principal.
//  - Admin: header X-Admin-Secret (or Bearer == admin secret) matches ADMIN_SECRET.
//           Cross-tenant; tenant must be supplied & validated by the route.
//  - Tenant: Bearer zfk_live_... whose sha256 matches a non-revoked api_keys row.
// Returns { kind:'admin'|'tenant', tenantId, label } or null.
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
  return null;
}

// For admin acting on a specific tenant: validate the tenant exists, return its id.
// For tenant principals: ignore any client-supplied tenant and use the key's tenant.
function resolveTenantScope(principal, requestedTenantId) {
  if (principal.kind === 'tenant') return principal.tenantId; // never trust the body
  // admin: must name an existing tenant for tenant-scoped operations
  const row = get().prepare('SELECT tenant_id FROM tenants WHERE tenant_id = ?').get(requestedTenantId);
  return row ? row.tenant_id : null;
}

module.exports = { authenticate, resolveTenantScope };
