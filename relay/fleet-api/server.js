'use strict';

const http = require('http');
const cfg = require('./config');
const db = require('./db');
const mqttClient = require('./mqtt');
const dynsec = require('./dynsec');
const reconcile = require('./reconcile');
const stripe = require('./stripe');
const billing = require('./routes/billing');
const enrollRoute = require('./routes/enroll');
const adminRoute = require('./routes/admin');
const consoleRoute = require('./routes/console');
const { readJson, send, makeRateLimiter, clientIp } = require('./http');
const staticSrv = require('./static');

const enrollLimiter = makeRateLimiter(cfg.enroll.rateMaxPerMin);
const consoleLoginLimiter = makeRateLimiter(cfg.consoleLoginRatePerMin);

// Read the RAW request body (Buffer) up to maxBytes. The Stripe webhook signature
// is computed over the EXACT bytes, so we must NOT route it through readJson (which
// JSON.parses and discards the original bytes). (MUST-FIX 9.)
function readRaw(req, maxBytes) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > maxBytes) { reject(new Error('body_too_large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function main() {
  db.init();

  // Control-plane connections (best-effort: HTTP still serves /enroll if MQTT is
  // briefly down; the wg+dynsec side-effects log and a later reconcile fixes them).
  try { await dynsec.connect(); } catch (e) { console.error('[boot] dynsec connect:', e.message); }
  try { await mqttClient.connect(); } catch (e) { console.error('[boot] mqtt connect:', e.message); }
  try { await reconcile.run(); } catch (e) { console.error('[boot] reconcile:', e.message); }

  // Billing self-heal on boot (MUST-FIX 4): move every subscribed tenant's
  // managed_state TOWARD Stripe truth. No-op when Stripe is unconfigured.
  if (cfg.stripe.apiReady()) {
    try { await billing.reconcileBilling(); } catch (e) { console.error('[boot] billing reconcile:', e.message); }
  }

  // Periodic liveness sweep: flip online=0 for devices whose heartbeat is older
  // than offlineAfterS even if no LWT arrived (two signals converge per contract).
  setInterval(() => {
    const cutoff = Math.floor(Date.now() / 1000) - cfg.offlineAfterS;
    try {
      db.get().prepare(
        'UPDATE devices SET online=0 WHERE online=1 AND COALESCE(last_heartbeat_at,0) < ? AND state != \'retired\''
      ).run(cutoff);
    } catch (e) { console.error('[sweep]', e.message); }
  }, 30000).unref();

  // Retention prune (bounds the append-only growth tables a busy/abusive device
  // would otherwise fill). processed_events holds short-lived idempotency latches
  // (heartbeat-ts dedup + 'stripe:'+id) — none are redelivered after days; events
  // is a forensic stream. Hourly, jittered-free (interval only). device_telemetry
  // is one row per device (UPSERT) so it needs no pruning.
  setInterval(() => {
    const now = Math.floor(Date.now() / 1000);
    try {
      db.get().prepare('DELETE FROM processed_events WHERE processed_at < ?').run(now - 7 * 24 * 3600);
      db.get().prepare('DELETE FROM events WHERE ts < ?').run(now - 30 * 24 * 3600);
    } catch (e) { console.error('[retention]', e.message); }
  }, 3600000).unref();

  // Nightly billing reconcile (MUST-FIX 4): ~24h, jittered, only when configured.
  // Heals a tenant stuck managed-off after a missed invoice.paid by moving TOWARD
  // Stripe truth. Never removePeer/disableClient/stop.
  if (cfg.stripe.apiReady()) {
    const dayMs = 24 * 60 * 60 * 1000;
    const jitter = Math.floor(Math.random() * 60 * 60 * 1000); // up to 1h
    setInterval(() => {
      billing.reconcileBilling().catch((e) => console.error('[nightly] billing reconcile:', e.message));
    }, dayMs + jitter).unref();
  }

  const server = http.createServer(async (req, res) => {
    try {
      const path = req.url.split('?')[0];

      // Health (public, no secret).
      if (req.method === 'GET' && path === '/health') {
        return send(res, 200, { v: 1, status: 'ok' });
      }

      // STRIPE WEBHOOK — RAW body, verified BEFORE any JSON.parse (MUST-FIX 9 + 3).
      // Idempotency via processed_events (msg_key 'stripe:'+id): INSERT OR IGNORE;
      // changes===0 => already processed => early 200 BEFORE any re-fetch/mutate.
      if (req.method === 'POST' && path === '/webhook/stripe') {
        if (!cfg.stripe.configured()) return send(res, 503, { v: 1, error: 'billing_not_configured' });
        let raw;
        try { raw = await readRaw(req, 1024 * 1024); } // ~1MB cap
        catch (_) { return send(res, 400, { v: 1, error: 'bad_request' }); }

        let evt;
        try {
          // Verify the signature over the EXACT raw bytes, BEFORE JSON.parse.
          evt = stripe.verifyWebhook(raw, req.headers['stripe-signature'], cfg.stripe.webhookSecret);
        } catch (_) {
          return send(res, 400, { v: 1, error: 'invalid_signature' });
        }

        // Idempotency latch: reuse processed_events (no new table). The latch row is
        // bucketed under the seeded 'system' tenant (migration 007) — NOT a tenant
        // derived from attacker-controllable event metadata, which could name a
        // non-existent tenant and FK-fail the INSERT, silently dropping a legit
        // webhook. The REAL tenant is resolved inside applyWebhookEvent by Stripe
        // customer/subscription id. msg_key ('stripe:'+id) is the true idempotency key.
        let first;
        try {
          first = db.get().prepare(
            'INSERT OR IGNORE INTO processed_events(msg_key, tenant_id, processed_at) VALUES (?,?,?)'
          ).run('stripe:' + evt.id, 'system', Math.floor(Date.now() / 1000));
        } catch (e) {
          // A DB failure here means we did NOT record (and will NOT process) the
          // event — return 5xx so Stripe REDELIVERS rather than silently dropping it.
          console.error('[webhook] latch:', e.message);
          return send(res, 500, { v: 1, error: 'latch_failed' });
        }
        if (first.changes === 0) {
          // Already processed — early 200 BEFORE any re-fetch/mutate.
          return send(res, 200, { v: 1, received: true, idempotent: true });
        }

        try { await billing.applyWebhookEvent(evt); }
        catch (e) { console.error('[webhook] apply:', e.message); }
        // ALWAYS 200 on accepted (incl. irrelevant) so Stripe stops retrying.
        return send(res, 200, { v: 1, received: true });
      }

      // PUBLIC enrollment surface.
      if (req.method === 'POST' && path === '/enroll') {
        let body;
        try { body = await readJson(req, cfg.enroll.maxBodyBytes); }
        catch (_) { return send(res, 400, { v: 1, error: 'bad_request' }); }
        return await enrollRoute.handle(req, res, { body, ip: clientIp(req), enrollLimiter });
      }

      // Onboarding : la box provisionne un code sous le tenant du proprio (login console, sans cookie).
      if (req.method === 'POST' && path === '/enroll/provision') {
        let body;
        try { body = await readJson(req, cfg.enroll.maxBodyBytes); }
        catch (_) { return send(res, 400, { v: 1, error: 'bad_request' }); }
        return await enrollRoute.provision(req, res, { body, ip: clientIp(req), loginLimiter: consoleLoginLimiter });
      }

      // CONSOLE BFF surface (same-origin; cookie session + CSRF inside the handler).
      if (path === '/console' || path.startsWith('/console/')) {
        let body = null;
        if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
          try { body = await readJson(req, 64 * 1024); }
          catch (_) { return send(res, 400, { v: 1, error: 'bad_request' }); }
        }
        return await consoleRoute.handle(req, res, { body, ip: clientIp(req), loginLimiter: consoleLoginLimiter });
      }

      // Authenticated console/admin surface.
      if (path.startsWith('/admin/') || path.startsWith('/api/')) {
        let body = null;
        if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
          try { body = await readJson(req, 64 * 1024); }
          catch (_) { return send(res, 400, { v: 1, error: 'bad_request' }); }
        }
        return await adminRoute.handle(req, res, { body });
      }

      // CONSOLE SPA static assets (same-origin). Whitelist-only; serves the
      // login/console UI for app.zaforge.com. Checked AFTER every API route so it
      // can never shadow /console, /admin, /enroll, /webhook, /health.
      if (staticSrv.tryServe(req, res, cfg.consoleStaticDir)) return;

      return send(res, 404, { v: 1, error: 'not_found' });
    } catch (e) {
      console.error('[http] unhandled:', e.message);
      try { send(res, 500, { v: 1, error: 'internal' }); } catch (_) {}
    }
  });

  server.listen(cfg.httpPort, cfg.httpHost, () => {
    console.log(`[fleet-api] listening on ${cfg.httpHost}:${cfg.httpPort}`);
  });
}

// Last-resort backstop: a stray rejection ANYWHERE must never take down the fleet
// plane that manages live screens. Per-request throws are already caught in the
// dispatcher (return await -> 500); this only catches truly detached promises.
process.on('unhandledRejection', (reason) => {
  console.error('[process] unhandledRejection:', reason && reason.message ? reason.message : reason);
});

main().catch((e) => { console.error('[boot] fatal:', e); process.exit(1); });
