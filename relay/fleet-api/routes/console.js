'use strict';

// =============================================================================
// fleet-api/routes/console.js — same-origin BFF for app.zaforge.com.
//
// AUTH MODEL: the browser NEVER holds ADMIN_SECRET or a zfk_live_ key. A console
// operator authenticates with email+password -> we mint an OPAQUE session id,
// store ONLY sha256(sid) in console_sessions, and set it as an httpOnly cookie
// (zf_console). Every subsequent request is resolved to a { kind:'console',
// tenantId } principal by auth.authenticate() from that cookie.
//
// MUST-FIX 2 (routing isolation): /console/* is NOT blanket-forwarded to the
// admin handler. This dedicated handler:
//   - authenticates the console session (cookie),
//   - enforces CSRF double-submit on EVERY state-changing request (httpOnly
//     zf_console + readable zf_csrf cookie + X-CSRF-Token header, constant-time),
//   - whitelists ONLY: devices(list/detail/confirm/retire/command), codes,
//     billing(checkout/portal). /tenants and /console-users are NEVER reachable
//     from the console surface.
// Fleet operations are THIN re-dispatches into the EXISTING admin.js handlers
// (with the console principal) so badges/gates/behavior are identical and never
// duplicated. resolveTenantScope clamps the console principal to its own tenant
// (auth.js), so the browser can never name another tenant.
// =============================================================================

const crypto = require('crypto');
const { promisify } = require('util');
const scryptAsync = promisify(crypto.scrypt);
const cfg = require('../config');
const { get } = require('../db');
const ids = require('../ids');
const { authenticate } = require('../auth');
const adminRoute = require('./admin');
const billing = require('./billing');
const entitlement = require('../entitlement');
const { send } = require('../http');

function now() { return Math.floor(Date.now() / 1000); }

// Read a single cookie value from the request.
function readCookie(req, name) {
  const raw = req.headers['cookie'];
  if (!raw) return null;
  for (const p of String(raw).split(';')) {
    const i = p.indexOf('=');
    if (i < 0) continue;
    if (p.slice(0, i).trim() === name) return p.slice(i + 1).trim();
  }
  return null;
}

// Constant-time string compare via sha256+timingSafeEqual (reuses the ids idiom).
function ctEqual(a, b) {
  const ha = crypto.createHash('sha256').update(String(a)).digest();
  const hb = crypto.createHash('sha256').update(String(b)).digest();
  return crypto.timingSafeEqual(ha, hb) && String(a).length === String(b).length;
}

// scrypt verifier matching admin.js scryptHash: 'scrypt$N$salt$hash'. ASYNC: the
// KDF runs in libuv's threadpool (crypto.scrypt), NOT scryptSync, so a flood of
// login attempts cannot block the single Node event loop (which would freeze the
// whole control plane). The handler awaits this.
async function verifyPassword(password, stored) {
  if (typeof stored !== 'string') return false;
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'scrypt') return false;
  const N = parseInt(parts[1], 10);
  if (!Number.isFinite(N)) return false;
  let salt, expected;
  try {
    salt = Buffer.from(parts[2], 'base64url');
    expected = Buffer.from(parts[3], 'base64url');
  } catch (_) { return false; }
  let dk;
  try { dk = await scryptAsync(String(password), salt, expected.length, { N, r: 8, p: 1 }); }
  catch (_) { return false; }
  return dk.length === expected.length && crypto.timingSafeEqual(dk, expected);
}

// Per-ACCOUNT login throttle (in addition to the per-IP limiter). Bounds horizontal
// password spraying against a single account regardless of source IP. Fixed window,
// bounded-size map (lazily swept). Cleared on a successful login.
const emailAttempts = new Map();
const EMAIL_WINDOW_MS = 300000; // 5 min
const EMAIL_MAX = 25;           // attempts per account per window
function emailAllow(email) {
  const nowMs = Date.now();
  const key = String(email).toLowerCase();
  if (emailAttempts.size > 20000) {
    for (const [k, w] of emailAttempts) if (nowMs - w.windowStart >= EMAIL_WINDOW_MS) emailAttempts.delete(k);
  }
  const w = emailAttempts.get(key);
  if (!w || nowMs - w.windowStart >= EMAIL_WINDOW_MS) { emailAttempts.set(key, { windowStart: nowMs, count: 1 }); return true; }
  if (w.count >= EMAIL_MAX) return false;
  w.count += 1;
  return true;
}
function emailClear(email) { emailAttempts.delete(String(email).toLowerCase()); }

function cookieHeader(name, value, maxAgeS, httpOnly) {
  const flags = [
    `${name}=${value}`,
    'Path=/',
    'Secure',
    'SameSite=Strict',
    `Max-Age=${maxAgeS}`
  ];
  if (httpOnly) flags.push('HttpOnly');
  return flags.join('; ');
}
function clearCookieHeader(name, httpOnly) {
  const flags = [`${name}=`, 'Path=/', 'Secure', 'SameSite=Strict', 'Max-Age=0'];
  if (httpOnly) flags.push('HttpOnly');
  return flags.join('; ');
}

// Send with extra Set-Cookie headers. setHeader() accepts an array for Set-Cookie
// but MUST be called BEFORE writeHead() flushes the head — otherwise it throws
// ERR_HTTP_HEADERS_SENT, which (as an async-handler rejection) would crash the
// whole relay process. Order is load-bearing.
function sendWithCookies(res, status, obj, cookies) {
  const body = JSON.stringify(obj);
  if (cookies && cookies.length) res.setHeader('Set-Cookie', cookies);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body)
  });
  res.end(body);
}

// CSRF double-submit: zf_csrf cookie must equal the X-CSRF-Token header. Applied
// to ALL state-changing methods. Returns true if OK; else sends 403 and false.
function csrfOk(req, res) {
  const cookieTok = readCookie(req, 'zf_csrf');
  const headerTok = req.headers['x-csrf-token'];
  if (!cookieTok || !headerTok || !ctEqual(cookieTok, headerTok)) {
    send(res, 403, { v: 1, error: 'csrf' });
    return false;
  }
  return true;
}

// Re-dispatch a console fleet request into the EXISTING admin.js handler. We
// rewrite req.url from /console/... to /admin/... so admin.js's own path parser
// and authenticate() (which reads the zf_console cookie) produce the console
// principal; resolveTenantScope then clamps it to the session tenant. No handler
// logic is duplicated; the entitlement gate inside admin.js still applies.
function redispatchToAdmin(req, res, ctx, subPath) {
  const qs = req.url.indexOf('?') >= 0 ? req.url.slice(req.url.indexOf('?')) : '';
  req.url = '/admin/' + subPath + qs;
  return adminRoute.handle(req, res, { body: ctx.body });
}

async function handle(req, res, ctx) {
  const url = new URL(req.url, 'http://relay.local');
  const seg = url.pathname.replace(/^\/console\/?/, '').split('/').filter(Boolean);
  const method = req.method;
  const isWrite = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method);

  // ---- POST /console/login  (public within the console surface) ----
  if (method === 'POST' && seg[0] === 'login' && seg.length === 1) {
    if (ctx.loginLimiter && !ctx.loginLimiter(ctx.ip)) {
      return send(res, 429, { v: 1, error: 'rate_limited' });
    }
    const b = ctx.body || {};
    if (typeof b.email !== 'string' || typeof b.password !== 'string') {
      return send(res, 400, { v: 1, error: 'bad_request' });
    }
    // Per-account throttle (defends a single account against IP-rotated spraying).
    if (!emailAllow(b.email)) return send(res, 429, { v: 1, error: 'rate_limited' });
    const user = get().prepare(
      'SELECT * FROM console_users WHERE email=? AND disabled_at IS NULL'
    ).get(String(b.email).toLowerCase());
    // Always run a verify to keep timing uniform whether or not the user exists.
    const ok = user ? await verifyPassword(b.password, user.pw_hash)
      : await verifyPassword(b.password, 'scrypt$16384$AAAA$AAAA');
    if (!user || !ok) return send(res, 401, { v: 1, error: 'invalid_credentials' });
    emailClear(b.email); // successful auth: reset the per-account counter

    const rawSid = crypto.randomBytes(32).toString('base64url');
    const rawCsrf = crypto.randomBytes(24).toString('base64url');
    const ts = now();
    const ttl = cfg.consoleSessionTtlS;
    get().prepare(
      `INSERT INTO console_sessions(session_id_hash, console_user_id, tenant_id, created_at, expires_at, last_seen_at)
       VALUES (?,?,?,?,?,?)`
    ).run(ids.sha256hex(rawSid), user.id, user.tenant_id, ts, ts + ttl, ts);

    return sendWithCookies(res, 200, { v: 1, tenant_id: user.tenant_id, role: user.role }, [
      cookieHeader('zf_console', rawSid, ttl, true),   // httpOnly opaque session
      cookieHeader('zf_csrf', rawCsrf, ttl, false)     // readable CSRF token
    ]);
  }

  // ---- Everything below requires a live console session ----
  const principal = authenticate(req);
  if (!principal || principal.kind !== 'console') {
    return send(res, 401, { v: 1, error: 'unauthorized' });
  }
  const tenantId = principal.tenantId; // clamped; the browser cannot name another

  // CSRF on every state-changing console request (GET is cookie-only).
  if (isWrite && !csrfOk(req, res)) return;

  // ---- POST /console/logout ----
  if (method === 'POST' && seg[0] === 'logout' && seg.length === 1) {
    const sid = readCookie(req, 'zf_console');
    if (sid) {
      try { get().prepare('UPDATE console_sessions SET revoked_at=? WHERE session_id_hash=?').run(now(), ids.sha256hex(sid)); }
      catch (_) {}
    }
    return sendWithCookies(res, 200, { v: 1, ok: true }, [
      clearCookieHeader('zf_console', true),
      clearCookieHeader('zf_csrf', false)
    ]);
  }

  // ---- GET /console/me  (UI bootstrap) ----
  if (method === 'GET' && seg[0] === 'me' && seg.length === 1) {
    const u = get().prepare('SELECT email, role FROM console_users WHERE id=?').get(principal.consoleUserId);
    const ent = entitlement.entitlement(tenantId);
    return send(res, 200, {
      v: 1, tenant_id: tenantId,
      email: u ? u.email : null, role: u ? u.role : null,
      plan: ent.plan, managed_state: ent.managedState, sub_status: ent.subStatus
    });
  }

  // ---- BILLING (cookie + CSRF; tenant from session) ----
  if (seg[0] === 'billing') {
    if (method === 'GET' && seg.length === 1) {
      const ent = entitlement.entitlement(tenantId);
      return send(res, 200, {
        v: 1, plan: ent.plan, sub_status: ent.subStatus, managed_state: ent.managedState,
        billable_count: entitlement.billableCount(tenantId),
        billing_configured: cfg.stripe.apiReady(),
        prices: billing.priceCatalog()
      });
    }
    if (method === 'POST' && seg[1] === 'checkout' && seg.length === 2) {
      if (!cfg.stripe.apiReady()) return send(res, 503, { v: 1, error: 'billing_not_configured' });
      try {
        const out = await billing.createCheckout(tenantId, ctx.body || {});
        return send(res, 200, { v: 1, url: out.url });
      } catch (e) {
        return send(res, billingErrStatus(e), { v: 1, error: e.code || 'checkout_failed' });
      }
    }
    if (method === 'POST' && seg[1] === 'portal' && seg.length === 2) {
      if (!cfg.stripe.apiReady()) return send(res, 503, { v: 1, error: 'billing_not_configured' });
      try {
        const out = await billing.createPortal(tenantId);
        return send(res, 200, { v: 1, url: out.url });
      } catch (e) {
        return send(res, billingErrStatus(e), { v: 1, error: e.code || 'portal_failed' });
      }
    }
    return send(res, 404, { v: 1, error: 'not_found' });
  }

  // ---- FLEET: devices (list/detail/confirm/retire/command) ----
  // Whitelist the exact device sub-actions; re-dispatch into admin.js.
  if (seg[0] === 'devices') {
    if (method === 'GET' && seg.length === 1) return redispatchToAdmin(req, res, ctx, 'devices');
    if (method === 'GET' && seg.length === 2) return redispatchToAdmin(req, res, ctx, 'devices/' + encodeURIComponent(seg[1]));
    // Poll a command result (issue via POST .../command, then GET .../command/:cmd_id).
    if (method === 'GET' && seg.length === 4 && seg[2] === 'command') {
      return redispatchToAdmin(req, res, ctx, 'devices/' + encodeURIComponent(seg[1]) + '/command/' + encodeURIComponent(seg[3]));
    }
    if (method === 'POST' && seg.length === 3 &&
        (seg[2] === 'confirm' || seg[2] === 'retire' || seg[2] === 'command')) {
      return redispatchToAdmin(req, res, ctx, 'devices/' + encodeURIComponent(seg[1]) + '/' + seg[2]);
    }
    // ---- FULL-UI proxy session ("mode complet") ----
    // Mint a short-lived HMAC token binding {device, tenant, wg_ip, exp}. The
    // operator opens https://<label>.<box-domain>/?__zf=<token>; zf-uiproxy (in the
    // wg netns) validates it and serves the device's full LAN UI over the tunnel.
    // Tenant-clamped: a principal can only mint for its OWN device.
    if (method === 'POST' && seg.length === 3 && seg[2] === 'proxy-session') {
      if (!cfg.proxy.enabled()) return send(res, 503, { v: 1, error: 'proxy_not_configured' });
      const dev = get().prepare(
        'SELECT device_id, wg_ip, state FROM devices WHERE device_id=? AND tenant_id=?'
      ).get(seg[1], tenantId);
      if (!dev) return send(res, 404, { v: 1, error: 'not_found' });
      if (dev.state !== 'active') return send(res, 409, { v: 1, error: 'device_not_active' });
      if (!/^10\.70\.\d{1,3}\.\d{1,3}$/.test(dev.wg_ip || '')) return send(res, 409, { v: 1, error: 'no_wg_ip' });
      const exp = now() + cfg.proxy.sessionTtlS;
      const payload = Buffer.from(JSON.stringify({ d: dev.device_id, t: tenantId, ip: dev.wg_ip, e: exp })).toString('base64url');
      const sig = crypto.createHmac('sha256', cfg.proxy.tokenSecret).update(payload).digest('base64url');
      const label = dev.device_id.replace(/_/g, '-'); // DNS-safe subdomain label
      const url = 'https://' + label + '.' + cfg.proxy.boxDomain + '/?__zf=' + payload + '.' + sig;
      return send(res, 200, { v: 1, url, expires_at: exp });
    }
    return send(res, 404, { v: 1, error: 'not_found' });
  }

  // ---- FLEET: codes (mint an enrollment code) ----
  if (seg[0] === 'codes' && seg.length === 1 && method === 'POST') {
    return redispatchToAdmin(req, res, ctx, 'codes');
  }

  // EXCLUDED from the console surface: /tenants, /console-users (admin-only).
  return send(res, 404, { v: 1, error: 'not_found' });
}

function billingErrStatus(e) {
  switch (e && e.code) {
    case 'not_configured': return 503;
    case 'bad_tier':
    case 'price_unavailable': return 400;
    case 'bad_tenant':
    case 'no_customer': return 409;
    default: return 502;
  }
}

module.exports = { handle };
