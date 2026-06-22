'use strict';

// =============================================================================
// fleet-api/stripe.js — stdlib-only Stripe client + webhook verifier.
//
// NO npm SDK (MUST-FIX 3). package.json deps are only better-sqlite3 + mqtt; the
// project ethos is stdlib http / no express. The needed Stripe REST surface is
// tiny (a handful of create/retrieve calls + form-encoded bodies). The official
// SDK pulls a large dependency tree into a control-plane container that already
// runs WireGuard/dynsec side effects; this ~auditable https wrapper is
// dependency-free and matches the verify-sig -> re-fetch -> mutate convention.
// The SDK stays a drop-in alternative if Stripe API drift becomes a burden.
//
// SECURITY:
//   - The secret key and full request/response bodies are NEVER logged.
//   - verifyWebhook() recomputes HMAC-SHA256 over (t + '.' + rawBody), enforces a
//     5-minute tolerance, and constant-time compares BEFORE any JSON.parse of the
//     payload (reject tampered/forged events before they touch the parser).
//   - Run the self-test with:  node stripe.js --selftest
// =============================================================================

const https = require('https');
const crypto = require('crypto');

// cfg is required lazily inside call() so this module can be require()d for the
// self-test without a full config/env (the self-test exercises only crypto).
function cfg() { return require('./config'); }

// Deep form-encode a params object into Stripe bracket notation, e.g.
//   { 'line_items[0][price]': 'price_x', subscription_data: { metadata: { tenant_id: 't_1' } } }
// -> line_items%5B0%5D%5Bprice%5D=price_x&subscription_data%5Bmetadata%5D%5Btenant_id%5D=t_1
// Already-bracketed string keys are passed through; nested objects/arrays are
// expanded into bracket paths. Booleans/numbers are stringified.
function formEncode(params) {
  const pairs = [];
  const add = (key, val) => {
    if (val === undefined || val === null) return;
    pairs.push(encodeURIComponent(key) + '=' + encodeURIComponent(String(val)));
  };
  const walk = (prefix, val) => {
    if (val === undefined || val === null) return;
    if (Array.isArray(val)) {
      val.forEach((v, i) => walk(`${prefix}[${i}]`, v));
    } else if (typeof val === 'object') {
      for (const k of Object.keys(val)) walk(`${prefix}[${k}]`, val[k]);
    } else {
      add(prefix, val);
    }
  };
  for (const k of Object.keys(params || {})) {
    const v = params[k];
    if (v !== null && typeof v === 'object') walk(k, v);
    else add(k, v);
  }
  return pairs.join('&');
}

// Low-level Stripe REST call. Throws an Error carrying { status, stripeCode } on
// a non-2xx response. NEVER logs the secret key or full request body.
function call(method, apiPath, params, opts) {
  opts = opts || {};
  const c = cfg();
  const secretKey = c.stripe.secretKey;
  if (!secretKey) return Promise.reject(new Error('stripe_not_configured'));

  const body = (method === 'GET' || !params) ? '' : formEncode(params);
  let path = '/v1/' + String(apiPath).replace(/^\/+/, '');
  if (method === 'GET' && body) path += '?' + body;

  const headers = {
    'Authorization': 'Bearer ' + secretKey,
    'Stripe-Version': c.stripe.apiVersion,
    'Content-Type': 'application/x-www-form-urlencoded',
    'Accept': 'application/json'
  };
  if (method !== 'GET' && body) headers['Content-Length'] = Buffer.byteLength(body);
  if (opts.idempotencyKey) headers['Idempotency-Key'] = String(opts.idempotencyKey);

  return new Promise((resolve, reject) => {
    const req = https.request(
      { method, hostname: 'api.stripe.com', port: 443, path, headers, timeout: 15000 },
      (res) => {
        const chunks = [];
        res.on('data', (d) => chunks.push(d));
        res.on('end', () => {
          const raw = Buffer.concat(chunks).toString('utf8');
          let json;
          try { json = raw ? JSON.parse(raw) : {}; } catch (_) { json = {}; }
          if (res.statusCode >= 200 && res.statusCode < 300) return resolve(json);
          const e = new Error('stripe_api_error');
          e.status = res.statusCode;
          e.stripeCode = (json && json.error && json.error.code) || null;
          e.stripeType = (json && json.error && json.error.type) || null;
          // Do not attach the request body or secret; only the sanitized message.
          e.message = `stripe_api_error ${res.statusCode}` +
            (json && json.error && json.error.code ? ' ' + json.error.code : '');
          reject(e);
        });
      }
    );
    req.on('timeout', () => { req.destroy(new Error('stripe_timeout')); });
    req.on('error', reject);
    if (method !== 'GET' && body) req.write(body);
    req.end();
  });
}

// ---- Thin wrappers over call() -------------------------------------------------
function createCheckoutSession(params, idempotencyKey) {
  return call('POST', 'checkout/sessions', params, { idempotencyKey });
}
function createBillingPortalSession(params, idempotencyKey) {
  return call('POST', 'billing_portal/sessions', params, { idempotencyKey });
}
function retrieveSubscription(id) {
  return call('GET', 'subscriptions/' + encodeURIComponent(id), null);
}
function retrieveCustomer(id) {
  return call('GET', 'customers/' + encodeURIComponent(id), null);
}
function createCustomer(params, idempotencyKey) {
  return call('POST', 'customers', params, { idempotencyKey });
}
function updateSubscriptionItem(itemId, params, idempotencyKey) {
  return call('POST', 'subscription_items/' + encodeURIComponent(itemId), params, { idempotencyKey });
}

// ---- Webhook signature verification (MUST-FIX 3) ------------------------------
// Parse the Stripe-Signature header 't=...,v1=...,v1=...'. Returns { t, v1: [..] }.
function parseSigHeader(sigHeader) {
  const out = { t: null, v1: [] };
  String(sigHeader || '').split(',').forEach((part) => {
    const idx = part.indexOf('=');
    if (idx < 0) return;
    const k = part.slice(0, idx).trim();
    const v = part.slice(idx + 1).trim();
    if (k === 't') out.t = v;
    else if (k === 'v1') out.v1.push(v);
  });
  return out;
}

// Constant-time hex compare (equal-length buffers). Returns false on length
// mismatch without leaking via timingSafeEqual's throw.
function timingSafeHexEqual(aHex, bHex) {
  const a = Buffer.from(String(aHex), 'utf8');
  const b = Buffer.from(String(bHex), 'utf8');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

// Verify a Stripe webhook and return the parsed event. Throws on any failure.
// signed_payload = t + '.' + rawBody ; HMAC-SHA256 with the endpoint secret ;
// 5-min tolerance ; constant-time compare. REJECTS BEFORE JSON.parse.
function verifyWebhook(rawBuf, sigHeader, secret, toleranceSec) {
  const tolerance = Number.isFinite(toleranceSec) ? toleranceSec : 300;
  if (!secret) throw new Error('webhook_secret_missing');
  const raw = Buffer.isBuffer(rawBuf) ? rawBuf : Buffer.from(String(rawBuf), 'utf8');
  const parsed = parseSigHeader(sigHeader);
  if (!parsed.t || parsed.v1.length === 0) throw new Error('invalid_signature_header');

  const tNum = parseInt(parsed.t, 10);
  if (!Number.isFinite(tNum)) throw new Error('invalid_signature_timestamp');

  // signed_payload = "<t>.<rawBody>" — concatenate as bytes (string t + '.' + raw).
  const signedPayload = Buffer.concat([
    Buffer.from(parsed.t + '.', 'utf8'),
    raw
  ]);
  const expected = crypto.createHmac('sha256', secret).update(signedPayload).digest('hex');

  // Accept if ANY provided v1 matches (Stripe may send multiple during rotation).
  const matched = parsed.v1.some((sig) => timingSafeHexEqual(sig, expected));
  if (!matched) throw new Error('signature_mismatch');

  // Tolerance check AFTER signature so we never reveal more via timing.
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - tNum) > tolerance) throw new Error('timestamp_out_of_tolerance');

  // Only NOW do we parse the (authenticated) payload.
  let event;
  try { event = JSON.parse(raw.toString('utf8')); }
  catch (_) { throw new Error('invalid_json'); }
  return event;
}

module.exports = {
  call, formEncode, verifyWebhook,
  createCheckoutSession, createBillingPortalSession,
  retrieveSubscription, retrieveCustomer, createCustomer, updateSubscriptionItem
};

// -----------------------------------------------------------------------------
// SELF-TEST (MUST-FIX 3): fixed secret + payload + timestamp -> verify accepts
// the good signature and rejects a tampered one. Run:  node stripe.js --selftest
// The tolerance is disabled (large value) here so the fixed-timestamp vector does
// not expire; the production path uses the 5-minute default.
// -----------------------------------------------------------------------------
function selftest() {
  const secret = 'whsec_test_selftest_fixed_secret';
  const rawBody = Buffer.from('{"id":"evt_test_123","type":"checkout.session.completed"}', 'utf8');
  const t = 1700000000; // fixed timestamp
  const signedPayload = Buffer.concat([Buffer.from(t + '.', 'utf8'), rawBody]);
  const goodSig = crypto.createHmac('sha256', secret).update(signedPayload).digest('hex');
  const HUGE = 10 ** 12; // disable tolerance for the frozen-timestamp vector

  // 1) Good signature is accepted and yields the parsed event.
  const evt = verifyWebhook(rawBody, `t=${t},v1=${goodSig}`, secret, HUGE);
  if (!evt || evt.id !== 'evt_test_123') throw new Error('FAIL: good sig not accepted / event not parsed');

  // 2) Tampered signature is rejected.
  const tamperedSig = goodSig.slice(0, -1) + (goodSig.slice(-1) === '0' ? '1' : '0');
  let rejected = false;
  try { verifyWebhook(rawBody, `t=${t},v1=${tamperedSig}`, secret, HUGE); }
  catch (_) { rejected = true; }
  if (!rejected) throw new Error('FAIL: tampered sig was accepted');

  // 3) Tampered BODY (same sig) is rejected — sig no longer covers the bytes.
  const tamperedBody = Buffer.from('{"id":"evt_evil","type":"checkout.session.completed"}', 'utf8');
  let bodyRejected = false;
  try { verifyWebhook(tamperedBody, `t=${t},v1=${goodSig}`, secret, HUGE); }
  catch (_) { bodyRejected = true; }
  if (!bodyRejected) throw new Error('FAIL: tampered body was accepted');

  // 4) Out-of-tolerance timestamp (real 300s default vs frozen t) is rejected.
  let toleranceRejected = false;
  try { verifyWebhook(rawBody, `t=${t},v1=${goodSig}`, secret, 300); }
  catch (e) { toleranceRejected = /tolerance/.test(e.message); }
  if (!toleranceRejected) throw new Error('FAIL: stale timestamp was accepted under 300s tolerance');

  console.log('[stripe selftest] OK — good sig accepted, tampered sig/body rejected, tolerance enforced.');
}

if (require.main === module && process.argv.includes('--selftest')) {
  selftest();
}
