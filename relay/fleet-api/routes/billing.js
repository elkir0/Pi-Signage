'use strict';

// =============================================================================
// fleet-api/routes/billing.js — Stripe billing core (per-screen, licensed qty).
//
// HARD INVARIANT (cardinal): billing gates the CLOUD CONTROL PLANE ONLY via
// tenants.managed_state. The ONLY side effect any billing path may trigger after
// a managed_state write is debounceSyncQuantity(). NO billing path EVER calls
// wg.removePeer / dynsec.disableClient / publishCommand(play|pause|switch|stop)
// and NEVER deletes cached content. A lapsed/over-quota/canceled subscription
// only flips managed_state -> managed-off, which routes/admin.js + routes/console
// .js translate into 402 on console mutations + command issuance + NEW
// enrollment. The Pi keeps playing local content with zero relay dependency.
//
// WEBHOOK ORDER (MUST-FIX 4): verify signature (stripe.verifyWebhook, BEFORE
// JSON.parse) -> idempotency latch in processed_events (INSERT OR IGNORE,
// changes===0 => already processed) -> RE-FETCH the object from Stripe (never
// trust the webhook body) -> mutate managed_state in ONE transaction -> append a
// billing_events forensic row -> (optional) debounceSyncQuantity. The server.js
// webhook branch owns the processed_events latch + early 200; applyWebhookEvent()
// here does the verified re-fetch + mutate.
//
// TAX / OSS: automatic_tax[enabled]=true on Checkout + customer_update[address]=
// auto lets Stripe Tax compute EU VAT/OSS per customer country (EUR anchor, USD
// variant). Enable Stripe Tax + register the OSS scheme in the dashboard; set the
// origin address. For B2B reverse-charge collect a VAT id via the Billing Portal
// (tax_id_collection) — Stripe-side, no code change. Quantity is licensed, so tax
// is computed on quantity*unit_price at invoice time by Stripe; we never compute
// tax ourselves.
//
// SELF-HEAL (MUST-FIX 4): reconcileBilling() (alias nightlyReconcile) runs on
// boot + nightly, re-fetches each subscribed tenant's Stripe status, and moves
// managed_state TOWARD Stripe truth (heals a tenant stuck managed-off after a
// missed invoice.paid). It ONLY moves toward truth; NEVER removePeer / disable /
// stop.
// =============================================================================

const cfg = require('../config');
const { get } = require('../db');
const stripe = require('../stripe');
const entitlement = require('../entitlement');

function now() { return Math.floor(Date.now() / 1000); }

// ---- Price catalog -----------------------------------------------------------
// tier in {pro, business}; interval in {month, year}; currency in {eur, usd}.
// community has NO Stripe object -> not checkout-able.
function priceFor(tier, interval, currency) {
  const key = `${tier}_${interval}_${currency}`;
  const p = cfg.stripe.prices[key];
  return p && p !== '' ? p : null;
}

// A console-facing catalog of which (tier,interval,currency) combos are live.
function priceCatalog() {
  const out = {};
  for (const tier of ['pro', 'business']) {
    for (const interval of ['month', 'year']) {
      for (const currency of ['eur', 'usd']) {
        const id = priceFor(tier, interval, currency);
        if (id) out[`${tier}_${interval}_${currency}`] = true;
      }
    }
  }
  return out;
}

// ---- Lazy customer creation --------------------------------------------------
async function ensureCustomer(tenant) {
  if (tenant.stripe_customer_id) return tenant.stripe_customer_id;
  const cust = await stripe.createCustomer(
    { name: tenant.name, metadata: { tenant_id: tenant.tenant_id } },
    'cust_' + tenant.tenant_id
  );
  get().prepare('UPDATE tenants SET stripe_customer_id=? WHERE tenant_id=?')
    .run(cust.id, tenant.tenant_id);
  return cust.id;
}

function tenantRow(tenantId) {
  return get().prepare('SELECT * FROM tenants WHERE tenant_id=?').get(tenantId);
}

// ---- Checkout ----------------------------------------------------------------
// ENTITLEMENT IS NEVER GRANTED HERE. Only a verified webhook flips managed_state;
// the success_url is never trusted. Quantity floor >= 1 (MUST-FIX 4).
async function createCheckout(tenantId, opts) {
  if (!cfg.stripe.apiReady()) { const e = new Error('billing_not_configured'); e.code = 'not_configured'; throw e; }
  opts = opts || {};
  const tier = opts.tier;
  const interval = opts.interval === 'year' ? 'year' : 'month';
  const currency = opts.currency === 'usd' ? 'usd' : 'eur';
  if (tier !== 'pro' && tier !== 'business') { const e = new Error('bad_tier'); e.code = 'bad_tier'; throw e; }
  const price = priceFor(tier, interval, currency);
  if (!price) { const e = new Error('price_unavailable'); e.code = 'price_unavailable'; throw e; }

  const tenant = tenantRow(tenantId);
  if (!tenant) { const e = new Error('bad_tenant'); e.code = 'bad_tenant'; throw e; }

  const qty = Math.max(1, entitlement.billableCount(tenantId)); // floor >= 1
  const customer = await ensureCustomer(tenant);

  const session = await stripe.createCheckoutSession({
    mode: 'subscription',
    customer,
    client_reference_id: tenantId,
    line_items: [{ price, quantity: qty }],
    subscription_data: { metadata: { tenant_id: tenantId } },
    automatic_tax: { enabled: 'true' },
    customer_update: { address: 'auto' },
    success_url: cfg.consolePublicUrl + '/billing?ok=1',
    cancel_url: cfg.consolePublicUrl + '/billing?cancel=1'
  }, 'sub_' + tenantId + '_' + tier + '_' + interval + '_' + currency);

  return { url: session.url };
}

// ---- Billing portal ----------------------------------------------------------
async function createPortal(tenantId) {
  if (!cfg.stripe.apiReady()) { const e = new Error('billing_not_configured'); e.code = 'not_configured'; throw e; }
  const tenant = tenantRow(tenantId);
  if (!tenant) { const e = new Error('bad_tenant'); e.code = 'bad_tenant'; throw e; }
  if (!tenant.stripe_customer_id) { const e = new Error('no_customer'); e.code = 'no_customer'; throw e; }
  const session = await stripe.createBillingPortalSession({
    customer: tenant.stripe_customer_id,
    return_url: cfg.consolePublicUrl + '/billing'
  }, 'portal_' + tenantId + '_' + Math.floor(Date.now() / 3600000));
  return { url: session.url };
}

// ---- Per-screen quantity sync (the licensing core) --------------------------
// Reads billableCount and PATCHes the SubscriptionItem quantity. Stripe is the
// meter of record. Only acts on a subscription that is currently billable
// (trialing|active|past_due). Never throws into the caller's hot path.
async function syncSubscriptionQuantity(tenantId) {
  if (!cfg.stripe.apiReady()) return;
  const tenant = tenantRow(tenantId);
  if (!tenant || !tenant.stripe_subscription_id || !tenant.stripe_sub_item_id) return;
  if (!['trialing', 'active', 'past_due'].includes(tenant.sub_status)) return;

  const count = entitlement.billableCount(tenantId);
  const proration = tenant.plan === 'business' ? 'create_prorations' : 'none';
  // Stamp the idempotency key on (item, count, billing-period) so identical
  // bursts collapse to a single PATCH at Stripe.
  const periodStamp = Math.floor(Date.now() / 86400000); // day bucket
  try {
    await stripe.updateSubscriptionItem(
      tenant.stripe_sub_item_id,
      { quantity: count, proration_behavior: proration },
      'qty_' + tenant.stripe_sub_item_id + '_' + count + '_' + periodStamp
    );
    get().prepare('UPDATE tenants SET qty_synced_at=? WHERE tenant_id=?').run(now(), tenantId);
  } catch (e) {
    console.error('[billing] syncSubscriptionQuantity', tenantId, e.message);
  }
}

// DEBOUNCE: coalesce bursts (confirm/retire/content-synced storms) into one
// PATCH. In-module timer map; safe no-op when billing is unconfigured.
const _debounceTimers = new Map();
function debounceSyncQuantity(tenantId, delayMs) {
  if (!tenantId || !cfg.stripe.apiReady()) return;
  const delay = Number.isFinite(delayMs) ? delayMs : 5000;
  const existing = _debounceTimers.get(tenantId);
  if (existing) clearTimeout(existing);
  const t = setTimeout(() => {
    _debounceTimers.delete(tenantId);
    syncSubscriptionQuantity(tenantId).catch((e) =>
      console.error('[billing] debounced sync', tenantId, e.message));
  }, delay);
  if (t.unref) t.unref();
  _debounceTimers.set(tenantId, t);
}

// ---- managed_state mapping (toward Stripe truth) ----------------------------
// Maps a Stripe subscription status -> { sub_status, managed_state }. Full
// function during dunning (past_due => grace, still managed-on-equivalent for the
// gate since grace !== 'managed-off'). canceled/unpaid => managed-off.
function mapStatus(stripeStatus) {
  switch (stripeStatus) {
    case 'active':
    case 'trialing':
      return { sub_status: stripeStatus, managed_state: 'managed-on' };
    case 'past_due':
      return { sub_status: 'past_due', managed_state: 'grace' };
    case 'unpaid':
      return { sub_status: 'unpaid', managed_state: 'managed-off' };
    case 'canceled':
    case 'incomplete_expired':
      return { sub_status: 'canceled', managed_state: 'managed-off' };
    default:
      // incomplete / paused / unknown -> conservative grace (still functional).
      return { sub_status: stripeStatus || 'none', managed_state: 'grace' };
  }
}

// Derive plan/interval/currency from a Stripe subscription's first item price.
function derivePlanFromSub(sub) {
  const item = sub && sub.items && sub.items.data && sub.items.data[0];
  const price = item && item.price;
  const out = { plan: null, interval: null, currency: null, sub_item_id: item ? item.id : null };
  if (!price) return out;
  out.currency = price.currency || null;
  out.interval = (price.recurring && price.recurring.interval) || null;
  // Match the price id back to our catalog to name the tier (pro|business).
  for (const tier of ['pro', 'business']) {
    for (const interval of ['month', 'year']) {
      for (const currency of ['eur', 'usd']) {
        if (priceFor(tier, interval, currency) === price.id) {
          out.plan = tier; out.interval = interval; out.currency = currency;
        }
      }
    }
  }
  return out;
}

// Persist a tenant's billing projection from a freshly RE-FETCHED subscription.
// ONLY moves toward Stripe truth. One transaction; appends a billing_events row.
function persistFromSubscription(tenantId, sub, eventId, eventType) {
  const map = mapStatus(sub.status);
  const derived = derivePlanFromSub(sub);
  const tx = get().transaction(() => {
    get().prepare(
      `UPDATE tenants SET
         stripe_subscription_id=?,
         stripe_sub_item_id=COALESCE(?, stripe_sub_item_id),
         plan=COALESCE(?, plan),
         billing_interval=COALESCE(?, billing_interval),
         billing_currency=COALESCE(?, billing_currency),
         sub_status=?,
         managed_state=?
       WHERE tenant_id=?`
    ).run(
      sub.id, derived.sub_item_id, derived.plan, derived.interval, derived.currency,
      map.sub_status, map.managed_state, tenantId
    );
    appendBillingEvent(tenantId, eventId, eventType, sub);
  });
  tx();
}

function appendBillingEvent(tenantId, eventId, type, payloadObj) {
  try {
    get().prepare(
      `INSERT OR IGNORE INTO billing_events(tenant_id, stripe_event_id, type, payload_json, ts)
       VALUES (?,?,?,?,?)`
    ).run(tenantId || null, eventId || null, type, payloadObj ? JSON.stringify(payloadObj) : null, now());
  } catch (e) { console.error('[billing] appendBillingEvent', e.message); }
}

// Resolve the tenant a subscription belongs to: metadata first, then the local
// stripe_subscription_id mapping (never trust the webhook body for identity).
function tenantForSub(sub) {
  if (sub && sub.metadata && sub.metadata.tenant_id) return sub.metadata.tenant_id;
  const row = get().prepare('SELECT tenant_id FROM tenants WHERE stripe_subscription_id=?').get(sub.id);
  return row ? row.tenant_id : null;
}

// ---- Webhook apply (called AFTER verify + processed_events latch) ------------
// RE-FETCHES from Stripe and mutates managed_state. Never trusts the webhook
// body's mutable fields. The ONLY side effect after the state write is
// debounceSyncQuantity. NEVER removePeer / disableClient / stop.
async function applyWebhookEvent(event) {
  const type = event && event.type;
  const obj = event && event.data && event.data.object ? event.data.object : {};

  switch (type) {
    case 'checkout.session.completed': {
      const tenantId = obj.client_reference_id ||
        (obj.metadata && obj.metadata.tenant_id) || null;
      if (!obj.subscription || !tenantId) { appendBillingEvent(tenantId, event.id, type, obj); return; }
      const sub = await stripe.retrieveSubscription(obj.subscription);
      // Backfill the customer id if Checkout created one.
      if (obj.customer) {
        try { get().prepare('UPDATE tenants SET stripe_customer_id=COALESCE(stripe_customer_id,?) WHERE tenant_id=?').run(obj.customer, tenantId); } catch (_) {}
      }
      persistFromSubscription(tenantId, sub, event.id, type);
      debounceSyncQuantity(tenantId, 1000);
      return;
    }
    case 'customer.subscription.created':
    case 'customer.subscription.updated': {
      const sub = await stripe.retrieveSubscription(obj.id); // never trust body
      const tenantId = tenantForSub(sub);
      if (!tenantId) { appendBillingEvent(null, event.id, type, sub); return; }
      persistFromSubscription(tenantId, sub, event.id, type);
      debounceSyncQuantity(tenantId, 1000);
      return;
    }
    case 'customer.subscription.deleted': {
      // Canceled -> managed-off. NO removePeer / NO stop publish.
      const sub = obj; // deleted object body is terminal; still re-map status.
      const tenantId = tenantForSub(sub);
      if (!tenantId) { appendBillingEvent(null, event.id, type, sub); return; }
      const tx = get().transaction(() => {
        get().prepare(
          "UPDATE tenants SET sub_status='canceled', managed_state='managed-off' WHERE tenant_id=?"
        ).run(tenantId);
        appendBillingEvent(tenantId, event.id, type, sub);
      });
      tx();
      return;
    }
    case 'invoice.payment_failed': {
      // Dunning: full function during smart-retries. grace, not managed-off.
      const tenantId = invoiceTenant(obj);
      if (!tenantId) { appendBillingEvent(null, event.id, type, obj); return; }
      const tx = get().transaction(() => {
        get().prepare(
          "UPDATE tenants SET sub_status='past_due', managed_state='grace' WHERE tenant_id=?"
        ).run(tenantId);
        appendBillingEvent(tenantId, event.id, type, obj);
      });
      tx();
      return;
    }
    case 'invoice.paid': {
      // Heals a tenant back to managed-on. RE-FETCH the sub for the true status.
      const tenantId = invoiceTenant(obj);
      if (!tenantId) { appendBillingEvent(null, event.id, type, obj); return; }
      if (obj.subscription) {
        const sub = await stripe.retrieveSubscription(obj.subscription);
        persistFromSubscription(tenantId, sub, event.id, type);
        debounceSyncQuantity(tenantId, 1000);
      } else {
        appendBillingEvent(tenantId, event.id, type, obj);
      }
      return;
    }
    default:
      appendBillingEvent(null, event.id, type, null); // forensic only
      return;
  }
}

// Map an invoice object -> tenant (subscription mapping, then customer mapping).
function invoiceTenant(invoice) {
  if (invoice && invoice.subscription) {
    const row = get().prepare('SELECT tenant_id FROM tenants WHERE stripe_subscription_id=?').get(invoice.subscription);
    if (row) return row.tenant_id;
  }
  if (invoice && invoice.customer) {
    const row = get().prepare('SELECT tenant_id FROM tenants WHERE stripe_customer_id=?').get(invoice.customer);
    if (row) return row.tenant_id;
  }
  return null;
}

// ---- Self-heal reconcile (boot + nightly) ------------------------------------
// For every tenant with a stripe_subscription_id: RE-FETCH the subscription,
// re-map sub_status -> managed_state (catches missed webhooks), and sync the
// quantity (corrects drift). ONLY moves toward truth; idempotent; never churns
// peers / dynsec / the player.
async function reconcileBilling() {
  if (!cfg.stripe.apiReady()) return;
  const tenants = get().prepare(
    "SELECT tenant_id, stripe_subscription_id FROM tenants WHERE stripe_subscription_id IS NOT NULL AND stripe_subscription_id != ''"
  ).all();
  for (const t of tenants) {
    try {
      const sub = await stripe.retrieveSubscription(t.stripe_subscription_id);
      persistFromSubscription(t.tenant_id, sub, null, 'reconcile');
      await syncSubscriptionQuantity(t.tenant_id);
    } catch (e) {
      console.error('[billing] reconcile', t.tenant_id, e.message);
    }
  }
}

// Alias kept for server.js wiring clarity.
const nightlyReconcile = reconcileBilling;

module.exports = {
  priceFor, priceCatalog, ensureCustomer, createCheckout, createPortal,
  syncSubscriptionQuantity, debounceSyncQuantity, applyWebhookEvent,
  reconcileBilling, nightlyReconcile, mapStatus, derivePlanFromSub
};
