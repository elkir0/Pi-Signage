'use strict';

// =============================================================================
// fleet-api/entitlement.js
//
// The LOCAL projection of Stripe truth. managed_state on the tenants row is the
// ONLY gate consulted on the hot path — there is NO external Stripe call here.
// managed_state is written ONLY by verified webhooks (routes/billing.js) and by
// nightlyReconcile()/reconcileBilling(); this module just READS it.
//
// HARD INVARIANT (brief): billing gates the CLOUD CONTROL PLANE ONLY. A
// managed-off tenant is refused console mutations + command issuance + NEW
// enrollment (402 payment_required). It NEVER triggers wg.removePeer /
// dynsec.disableClient / publishCommand(play|pause|switch|stop) and NEVER
// deletes cached content. The Pi keeps playing local content with zero relay
// dependency.
//
// FAIL-OPEN: a tenant with no billing row (or an unknown tenant) is treated as
// managed-on. The 003 migration defaults every existing tenant to
// plan='community', sub_status='none', managed_state='managed-on', so the live
// enrolled tenant keeps full function with zero behavior change.
// =============================================================================

const { get } = require('./db');
const { send } = require('./http');

// Resolve a tenant's entitlement projection. Missing tenant -> fail-open
// managed-on (community). Returns { managedState, plan, subStatus, ok }.
function entitlement(tenantId) {
  let row = null;
  try {
    row = get().prepare(
      'SELECT managed_state, plan, sub_status FROM tenants WHERE tenant_id = ?'
    ).get(tenantId);
  } catch (_) {
    // Defensive: if the column does not exist yet (pre-003), fail-open.
    row = null;
  }
  const managedState = (row && row.managed_state) || 'managed-on';
  const plan = (row && row.plan) || 'community';
  const subStatus = (row && row.sub_status) || 'none';
  return { managedState, plan, subStatus, ok: managedState !== 'managed-off' };
}

// The per-screen licensing quantity: ACTIVE devices whose content is locally
// cached. content_cached=1 is set only after the agent reports a full local
// cache (mqtt content-synced event) — a screen is NEVER billed before its
// content is locally cached (brick-proof invariant).
function billableCount(tenantId) {
  try {
    const r = get().prepare(
      "SELECT COUNT(*) AS n FROM devices WHERE tenant_id=? AND state='active' AND content_cached=1"
    ).get(tenantId);
    return r ? r.n : 0;
  } catch (_) {
    return 0;
  }
}

// Gate helper for the control-plane mutation routes. Returns true if the tenant
// may proceed; otherwise sends 402 and returns false. NO-OP for managed-on
// tenants, so current behavior is preserved exactly.
function requireEntitled(res, tenantId) {
  if (entitlement(tenantId).ok) return true;
  send(res, 402, { v: 1, error: 'payment_required' });
  return false;
}

module.exports = { entitlement, billableCount, requireEntitled };
