'use strict';

// =============================================================================
// fleet-api/static.js — minimal, whitelist-only static server for the console
// SPA. Serves the SAME origin as the /console API so app.zaforge.com is a dumb
// CT101 proxy and the BFF cookie model holds (no CORS, no separate host).
//
// HARDENING: there is NO path join from user input. Each request path maps via a
// fixed allowlist to ONE known file. Anything not in the map is a 404. This makes
// directory traversal structurally impossible — we never concatenate req.url onto
// a base dir. Cache-Control is conservative (HTML no-store; assets are versioned
// via ?v= query so they may be cached).
// =============================================================================

const fs = require('fs');
const path = require('path');

// path (sans query) -> { file, type, cache }
const ROUTES = {
  '/':            { file: 'index.html', type: 'text/html; charset=utf-8',       cache: 'no-store' },
  '/index.html':  { file: 'index.html', type: 'text/html; charset=utf-8',       cache: 'no-store' },
  '/app.js':      { file: 'app.js',     type: 'application/javascript; charset=utf-8', cache: 'public, max-age=300' },
  '/styles.css':  { file: 'styles.css', type: 'text/css; charset=utf-8',        cache: 'public, max-age=300' }
};

// Try to serve a GET request from the console static dir. Returns true if it
// handled the response, false if the path is not a console asset (caller 404s).
function tryServe(req, res, dir) {
  if (!dir) return false;
  if (req.method !== 'GET' && req.method !== 'HEAD') return false;
  const pathname = req.url.split('?')[0];
  const route = ROUTES[pathname];
  if (!route) return false;

  // dir + fixed filename only — no user-controlled path component.
  const full = path.join(dir, route.file);
  let data;
  try { data = fs.readFileSync(full); }
  catch (_) { res.writeHead(404, { 'Content-Type': 'application/json' }); res.end('{"v":1,"error":"not_found"}'); return true; }

  res.writeHead(200, {
    'Content-Type': route.type,
    'Content-Length': Buffer.byteLength(data),
    'Cache-Control': route.cache,
    'X-Content-Type-Options': 'nosniff'
  });
  res.end(req.method === 'HEAD' ? undefined : data);
  return true;
}

module.exports = { tryServe };
