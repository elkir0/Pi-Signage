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
// The window Map is bounded: lazily swept of expired entries and hard-capped, so an
// attacker churning the key cannot grow it without bound (memory-exhaustion DoS).
// When genuinely full it sheds load by denying.
function makeRateLimiter(maxPerMin) {
  const windows = new Map(); // key -> { windowStart, count }
  const MAX_KEYS = 50000;
  let opsSinceSweep = 0;
  function sweep(nowMs) {
    for (const [k, w] of windows) {
      if (nowMs - w.windowStart >= 60000) windows.delete(k);
    }
  }
  return function allow(key) {
    const nowMs = Date.now();
    if (++opsSinceSweep >= 1000) { opsSinceSweep = 0; sweep(nowMs); }
    if (windows.size >= MAX_KEYS) { sweep(nowMs); if (windows.size >= MAX_KEYS) return false; }
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

// Trusted client IP for the rate-limit key. CT101 (the SINGLE trusted edge) sets
// X-Real-IP to the real TCP peer it observes, OVERWRITING any client value — so it
// is trustworthy. We deliberately do NOT read X-Forwarded-For: its leftmost element
// is attacker-controlled and CT101 only APPENDS to it, so trusting it would let an
// attacker rotate the key and bypass the brute-force throttle. Identity is never
// derived from this — only the rate-limit bucket.
function clientIp(req) {
  const real = req.headers['x-real-ip'];
  if (real) return String(real).split(',')[0].trim();
  return req.socket.remoteAddress || 'unknown';
}

module.exports = { readJson, send, makeRateLimiter, clientIp };
