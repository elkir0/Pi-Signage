'use strict';

// =============================================================================
// zf-uiproxy — "mode complet" reverse proxy: serves the FULL PiSignage LAN UI of
// a device to a console operator, over the WireGuard tunnel.
//
// Topology: it runs with network_mode: service:wireguard, so it shares the
// WireGuard container's netns and can reach each enrolled Pi at its wg IP
// (10.70.0.x:80). CT101 fronts it: <label>.box.zaforge.com -> VM600:UIPROXY_PORT.
//
// AUTH (two layers, both required):
//   1. A console-minted, HMAC-signed, short-lived token binds {device_id,
//      tenant_id, wg_ip, exp}. fleet-api issues it ONLY to an authenticated,
//      tenant-scoped console session. The proxy verifies the HMAC (constant-time)
//      and expiry; it trusts the signed wg_ip (no DB needed). The token arrives as
//      ?__zf=... once, is moved into an httpOnly cookie, then the URL is cleaned.
//   2. Toward the Pi, the proxy injects X-Zaforge-Proxy: <RELAY_PROXY_SECRET>. The
//      Pi's auth bridge only honors it from source 10.70.0.1 (this proxy, on wg0).
//
// HARDENING: any client-supplied X-Zaforge-Proxy / X-Forwarded-* is STRIPPED (the
// proxy is the sole injector). wg_ip from the token must match 10.70.0.0/16. Only
// port 80 on the Pi is reached. No redirect-following (the Pi returns relative
// redirects the browser re-requests on the same subdomain).
// =============================================================================

const http = require('http');
const crypto = require('crypto');

const PORT = parseInt(process.env.UIPROXY_PORT || '8090', 10);
const HOST = process.env.UIPROXY_HOST || '0.0.0.0';
const TOKEN_SECRET = req('PROXY_TOKEN_SECRET');     // shared with fleet-api (HMAC)
const RELAY_PROXY_SECRET = req('RELAY_PROXY_SECRET'); // injected toward the Pi
const COOKIE = 'zf_uiproxy';
const MAX_BODY = 600 * 1024 * 1024; // 600MB (media uploads through the real UI)

function req(name) {
  const v = process.env[name];
  if (!v || v.length < 16) { console.error(`[uiproxy] FATAL: env ${name} missing/short`); process.exit(1); }
  return v;
}
function b64urlDecode(s) { return Buffer.from(String(s).replace(/-/g, '+').replace(/_/g, '/'), 'base64'); }
function ctEqual(a, b) {
  const ha = crypto.createHash('sha256').update(String(a)).digest();
  const hb = crypto.createHash('sha256').update(String(b)).digest();
  return crypto.timingSafeEqual(ha, hb);
}

// Verify "payload.sig" (both base64url). payload = JSON{d,t,ip,e}. Returns the
// claims object or null.
function verifyToken(tok) {
  if (typeof tok !== 'string' || tok.indexOf('.') < 0) return null;
  const [payload, sig] = tok.split('.');
  if (!payload || !sig) return null;
  const expected = crypto.createHmac('sha256', TOKEN_SECRET).update(payload).digest();
  let got;
  try { got = b64urlDecode(sig); } catch (_) { return null; }
  if (got.length !== expected.length || !crypto.timingSafeEqual(got, expected)) return null;
  let claims;
  try { claims = JSON.parse(b64urlDecode(payload).toString('utf8')); } catch (_) { return null; }
  if (!claims || typeof claims.ip !== 'string' || typeof claims.d !== 'string') return null;
  if (typeof claims.e !== 'number' || claims.e < Math.floor(Date.now() / 1000)) return null;
  // wg_ip must be inside the tenant pool 10.70.0.0/16 (defensive even though signed).
  if (!/^10\.70\.\d{1,3}\.\d{1,3}$/.test(claims.ip)) return null;
  return claims;
}

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

function deny(res, code, msg) {
  res.writeHead(code, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(`<!doctype html><meta charset=utf-8><title>Zaforge</title>` +
    `<body style="font-family:system-ui;background:#0a0f12;color:#e8f1ef;padding:3rem;text-align:center">` +
    `<h1 style="color:#10b981">Zaforge</h1><p>${msg}</p>` +
    `<p style="opacity:.6">Ouvre le mode complet depuis <a style="color:#34d399" href="https://app.zaforge.com">app.zaforge.com</a>.</p></body>`);
}

const server = http.createServer((creq, cres) => {
  // Token: from ?__zf=... (first hop) else the cookie.
  const u = new URL(creq.url, 'http://x');
  const urlTok = u.searchParams.get('__zf');
  let claims = urlTok ? verifyToken(urlTok) : null;

  if (urlTok) {
    if (!claims) return deny(cres, 401, 'Lien expiré ou invalide.');
    // Stash the token in an httpOnly cookie, then redirect to the clean URL so the
    // token never lingers in the address bar / Referer / history.
    u.searchParams.delete('__zf');
    const clean = u.pathname + (u.search === '?' ? '' : u.search);
    const maxAge = Math.max(60, claims.e - Math.floor(Date.now() / 1000));
    cres.writeHead(302, {
      'Set-Cookie': `${COOKIE}=${urlTok}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAge}`,
      'Location': clean || '/',
      'Cache-Control': 'no-store'
    });
    cres.end();
    return;
  }

  if (!claims) {
    const ctok = readCookie(creq, COOKIE);
    claims = ctok ? verifyToken(ctok) : null;
  }
  if (!claims) return deny(cres, 401, 'Session du mode complet expirée.');

  // ---- proxy to the Pi over the tunnel ----
  // Build forwarded headers: copy client headers, but STRIP anything that could
  // spoof the Pi's trust (the proxy is the SOLE injector of X-Zaforge-Proxy).
  const headers = {};
  for (const [k, v] of Object.entries(creq.headers)) {
    const lk = k.toLowerCase();
    if (lk === 'x-zaforge-proxy' || lk.startsWith('x-forwarded-') || lk === 'x-real-ip') continue;
    headers[k] = v;
  }
  headers['x-zaforge-proxy'] = RELAY_PROXY_SECRET;
  let path = creq.url;
  // Drop __zf if it somehow remained in the path (defense in depth).
  if (path.indexOf('__zf=') >= 0) {
    const tu = new URL(creq.url, 'http://x');
    tu.searchParams.delete('__zf');
    path = tu.pathname + (tu.search === '?' ? '' : tu.search);
  }
  // headers MUST be passed to http.request (else the bridge secret never reaches
  // the Pi and authenticated pages 302 to login).
  const target = { host: claims.ip, port: 80, method: creq.method, path, headers };

  const preq = http.request(target, (pres) => {
    // Pass status + headers straight back (incl. the Pi's Set-Cookie session).
    cres.writeHead(pres.statusCode || 502, pres.headers);
    pres.pipe(cres);
  });
  preq.on('error', (e) => {
    if (!cres.headersSent) deny(cres, 502, 'Écran injoignable via le tunnel (' + (e.code || 'error') + ').');
    else cres.destroy();
  });
  preq.setTimeout(30000, () => { preq.destroy(new Error('timeout')); });

  // Stream the request body (uploads) with a hard cap.
  let size = 0;
  creq.on('data', (c) => { size += c.length; if (size > MAX_BODY) { creq.destroy(); preq.destroy(); } });
  creq.pipe(preq);
});

server.listen(PORT, HOST, () => console.log(`[uiproxy] listening on ${HOST}:${PORT}`));
process.on('unhandledRejection', (e) => console.error('[uiproxy] unhandledRejection:', e && e.message));
