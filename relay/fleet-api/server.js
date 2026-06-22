'use strict';

const http = require('http');
const cfg = require('./config');
const db = require('./db');
const mqttClient = require('./mqtt');
const dynsec = require('./dynsec');
const reconcile = require('./reconcile');
const enrollRoute = require('./routes/enroll');
const adminRoute = require('./routes/admin');
const { readJson, send, makeRateLimiter, clientIp } = require('./http');

const enrollLimiter = makeRateLimiter(cfg.enroll.rateMaxPerMin);

async function main() {
  db.init();

  // Control-plane connections (best-effort: HTTP still serves /enroll if MQTT is
  // briefly down; the wg+dynsec side-effects log and a later reconcile fixes them).
  try { await dynsec.connect(); } catch (e) { console.error('[boot] dynsec connect:', e.message); }
  try { await mqttClient.connect(); } catch (e) { console.error('[boot] mqtt connect:', e.message); }
  try { await reconcile.run(); } catch (e) { console.error('[boot] reconcile:', e.message); }

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

  const server = http.createServer(async (req, res) => {
    try {
      const path = req.url.split('?')[0];

      // Health (public, no secret).
      if (req.method === 'GET' && path === '/health') {
        return send(res, 200, { v: 1, status: 'ok' });
      }

      // PUBLIC enrollment surface.
      if (req.method === 'POST' && path === '/enroll') {
        let body;
        try { body = await readJson(req, cfg.enroll.maxBodyBytes); }
        catch (_) { return send(res, 400, { v: 1, error: 'bad_request' }); }
        return enrollRoute.handle(req, res, { body, ip: clientIp(req), enrollLimiter });
      }

      // Authenticated console/admin surface.
      if (path.startsWith('/admin/') || path.startsWith('/api/')) {
        let body = null;
        if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
          try { body = await readJson(req, 64 * 1024); }
          catch (_) { return send(res, 400, { v: 1, error: 'bad_request' }); }
        }
        return adminRoute.handle(req, res, { body });
      }

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

main().catch((e) => { console.error('[boot] fatal:', e); process.exit(1); });
