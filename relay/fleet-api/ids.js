'use strict';

const crypto = require('crypto');

// Lowercase base32 alphabet (RFC4648 without padding, lowercased) for opaque ids.
const B32 = 'abcdefghijklmnopqrstuvwxyz234567';
// Crockford base32 (uppercase) for human-typed enrollment codes (no I L O U).
const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

function randomFrom(alphabet, n) {
  const bytes = crypto.randomBytes(n);
  let out = '';
  for (let i = 0; i < n; i++) out += alphabet[bytes[i] % alphabet.length];
  return out;
}

// tenant_id: "t_" + 12 lowercase base32 chars
function newTenantId() {
  return 't_' + randomFrom(B32, 12);
}

// device_id: "d_" + 16 lowercase base32 chars
function newDeviceId() {
  return 'd_' + randomFrom(B32, 16);
}

// enrollment code: "ZF-" + 4-4-4 uppercase Crockford groups
function newEnrollmentCode() {
  const g = () => randomFrom(CROCKFORD, 4);
  return `ZF-${g()}-${g()}-${g()}`;
}

// api_key: "zfk_live_" + 40 url-safe chars
function newApiKey() {
  return 'zfk_live_' + crypto.randomBytes(30).toString('base64url').slice(0, 40);
}

// mqtt password: 32-byte random base64url, shown once.
function newMqttPassword() {
  return crypto.randomBytes(32).toString('base64url');
}

// command id
function newCmdId() {
  return 'c_' + randomFrom(B32, 10);
}

// sha256 hex of an input (used for code_hash, key_hash, mqtt_pw_fp).
function sha256hex(s) {
  return crypto.createHash('sha256').update(s, 'utf8').digest('hex');
}

// WG pubkey fingerprint: sha256 of the raw 32-byte key, hex colon-separated.
// The Pi prints the same via `zaforge-agent --show-fingerprint`; the operator
// visually matches it in the console before promoting pending -> active.
function wgFingerprint(b64PubKey) {
  const raw = Buffer.from(b64PubKey, 'base64');
  const hex = crypto.createHash('sha256').update(raw).digest('hex');
  return 'SHA256:' + hex.match(/.{2}/g).join(':');
}

// Validate a WG public key string is exactly a 32-byte base64 value (no oracle —
// just structural). Rejects anything that does not decode to 32 bytes.
function isValidWgPubKey(s) {
  if (typeof s !== 'string' || s.length < 42 || s.length > 48) return false;
  let raw;
  try { raw = Buffer.from(s, 'base64'); } catch (_) { return false; }
  return raw.length === 32 && raw.toString('base64') === s;
}

// Timing-safe equality on two strings (constant-time, length-safe).
function constantTimeEqual(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  // Compare same-length digests to avoid leaking length; hash both first.
  const ha = crypto.createHash('sha256').update(ba).digest();
  const hb = crypto.createHash('sha256').update(bb).digest();
  return crypto.timingSafeEqual(ha, hb) && ba.length === bb.length;
}

module.exports = {
  newTenantId, newDeviceId, newEnrollmentCode, newApiKey, newMqttPassword,
  newCmdId, sha256hex, wgFingerprint, isValidWgPubKey, constantTimeEqual
};
