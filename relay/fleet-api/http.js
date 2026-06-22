'use strict';

const cfg = require('./config');

// Read a JSON body up to maxBytes. Rejects oversize bodies (enrollment guard).
function readJson(req, maxBytes) {
  const limit = maxBytes || cfg.enroll.maxBodyBytes;
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) { reject(new Error('body_too_large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      if (chunks.length === 0) return resolve(null);
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
      catch (_) { reject(new Error('bad_json')); }
    });
    req.on('error', reject);
  });
}

function send(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

// Fixed-window per-key rate limiter. Returns true if the request is allowed.
function makeRateLimiter(maxPerMin) {
  const windows = new Map(); // key -> { windowStart, count }
  return function allow(key) {
    const nowMs = Date.now();
    const w = windows.get(key);
    if (!w || nowMs - w.windowStart >= 60000) {
      windows.set(key, { windowStart: nowMs, count: 1 });
      return true;
    }
    if (w.count >= maxPerMin) return false;
    w.count += 1;
    return true;
  };
}

// Best-effort client IP (CT101 terminates TLS; trust X-Forwarded-For ONLY for the
// rate-limit key, never for identity — identity is the enrollment code).
function clientIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (xff) return String(xff).split(',')[0].trim();
  return req.socket.remoteAddress || 'unknown';
}

module.exports = { readJson, send, makeRateLimiter, clientIp };
