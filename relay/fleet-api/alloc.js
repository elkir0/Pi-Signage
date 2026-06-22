'use strict';

const cfg = require('./config');

// =============================================================================
// WireGuard device-IP allocator (MUST-FIX F).
//
// Pool:           10.70.0.0/16
// Server block:   10.70.0.0/28  is RESERVED (it contains the relay 10.70.0.1).
//                 No tenant /28 may overlap it; no device /32 may equal 10.70.0.1.
// Tenant blocks:  start at 10.70.0.16/28 and step in /28 increments across the
//                 whole 10.70.0.0/16 pool (16 addresses per block).
//
// Invariants enforced here (and asserted by the self-test at the bottom):
//   - The server /28 (10.70.0.0 .. 10.70.0.15) is never handed to a tenant.
//   - No allocated device /32 == the relay IP (10.70.0.1).
//   - No two tenants share a /28 (UNIQUE(cidr) in tenant_subnets + the used-set
//     check below guarantee this; the test re-proves it).
// =============================================================================

// Parse "10.70.4.16/28" -> { octets:[10,70,4,16], prefix:28 }.
function parseCidr(cidr) {
  const [ip, p] = cidr.split('/');
  return { octets: ip.split('.').map(Number), prefix: parseInt(p, 10) };
}

function ipToInt(octets) {
  return ((octets[0] << 24) >>> 0) + (octets[1] << 16) + (octets[2] << 8) + octets[3];
}
function intToIp(n) {
  return [(n >>> 24) & 255, (n >>> 16) & 255, (n >>> 8) & 255, n & 255].join('.');
}

// Integer forms of the pool, the reserved server block, and the relay IP.
const POOL = parseCidr(cfg.wg.poolCidr);                 // 10.70.0.0/16
const POOL_BASE = ipToInt(POOL.octets) & (0xffffffff << (32 - POOL.prefix)) >>> 0;
const POOL_SIZE = 2 ** (32 - POOL.prefix);               // 65536 for /16
const POOL_END = (POOL_BASE + POOL_SIZE - 1) >>> 0;      // last addr in the pool

const RESERVED = parseCidr(cfg.wg.reservedCidr);         // 10.70.0.0/28
const RESERVED_BASE = ipToInt(RESERVED.octets) >>> 0;
const RESERVED_SIZE = 2 ** (32 - RESERVED.prefix);       // 16 for /28
const RESERVED_END = (RESERVED_BASE + RESERVED_SIZE - 1) >>> 0;

const RELAY_INT = ipToInt(cfg.wg.relayIp.split('.').map(Number)) >>> 0;

// First tenant /28 starts immediately after the reserved server block.
const FIRST_TENANT_BASE = (RESERVED_BASE + RESERVED_SIZE) >>> 0; // 10.70.0.16
const BLOCK_SIZE = 16; // /28

// True if a /28 whose network address is `base` would overlap the server block.
function overlapsReserved(base) {
  const end = (base + BLOCK_SIZE - 1) >>> 0;
  return base <= RESERVED_END && end >= RESERVED_BASE;
}

// Hosts usable in a /28 (skip network .0 and broadcast .15 of the block).
function blockHosts(cidr) {
  const { octets } = parseCidr(cidr);
  const netInt = ipToInt(octets) >>> 0;
  const hosts = [];
  for (let h = 1; h <= 14; h++) {
    const ip = (netInt + h) >>> 0;
    // HARD ASSERTION: never, ever, hand out the relay IP.
    if (ip === RELAY_INT) continue;
    hosts.push(intToIp(ip));
  }
  return hosts;
}

// Allocate the next /28 from the pool that is not yet recorded in tenant_subnets.
// Walks /28 boundaries from FIRST_TENANT_BASE (10.70.0.16) to the end of the /16,
// skipping any block overlapping the reserved server /28.
function allocateNewBlock(db, tenantId, now) {
  const used = new Set(db.prepare('SELECT cidr FROM tenant_subnets').all().map((r) => r.cidr));
  for (let base = FIRST_TENANT_BASE; base <= POOL_END; base = (base + BLOCK_SIZE) >>> 0) {
    if (overlapsReserved(base)) continue; // never reuse the server block
    const cidr = `${intToIp(base)}/28`;
    if (used.has(cidr)) continue;
    // UNIQUE(cidr) in tenant_subnets is the real cross-tenant guard; the used-set
    // is just a fast path. If a race inserts the same cidr, the UNIQUE constraint
    // throws and the enclosing tx rolls back — no two tenants can share a /28.
    db.prepare('INSERT INTO tenant_subnets(tenant_id, cidr, created_at) VALUES (?,?,?)')
      .run(tenantId, cidr, now);
    return cidr;
  }
  throw new Error('wg_pool_exhausted');
}

// Resolve a free /32 for a tenant: walk the tenant's existing blocks for a free
// host; if all full, allocate a new /28 and take its first host.
// Returns { ip: "10.70.0.18", cidr: "10.70.0.16/28" }. MUST be called inside a tx.
function allocateDeviceIp(db, tenantId, now) {
  const blocks = db.prepare('SELECT cidr FROM tenant_subnets WHERE tenant_id=? ORDER BY id')
    .all(tenantId).map((r) => r.cidr);

  // IPs already taken by non-retired devices in this tenant.
  const taken = new Set(
    db.prepare("SELECT wg_ip FROM devices WHERE tenant_id=? AND state != 'retired'")
      .all(tenantId).map((r) => r.wg_ip)
  );

  for (const cidr of blocks) {
    for (const host of blockHosts(cidr)) {
      if (!taken.has(host)) {
        assertSafe(host, cidr);
        return { ip: host, cidr };
      }
    }
  }
  // No free host in existing blocks -> grow the tenant by one /28.
  const newCidr = allocateNewBlock(db, tenantId, now);
  const ip = blockHosts(newCidr)[0];
  assertSafe(ip, newCidr);
  return { ip, cidr: newCidr };
}

// Runtime assertion: a device /32 must never equal the relay IP and must never
// fall inside the reserved server /28. Throwing here aborts the enroll tx.
function assertSafe(ip, cidr) {
  const ipInt = ipToInt(ip.split('.').map(Number)) >>> 0;
  if (ipInt === RELAY_INT) {
    throw new Error(`alloc_invariant: device /32 ${ip} collides with relay ${cfg.wg.relayIp}`);
  }
  if (ipInt >= RESERVED_BASE && ipInt <= RESERVED_END) {
    throw new Error(`alloc_invariant: device /32 ${ip} falls inside reserved ${cfg.wg.reservedCidr}`);
  }
  const { octets } = parseCidr(cidr);
  const blockBase = ipToInt(octets) >>> 0;
  if (overlapsReserved(blockBase)) {
    throw new Error(`alloc_invariant: block ${cidr} overlaps reserved ${cfg.wg.reservedCidr}`);
  }
}

// -----------------------------------------------------------------------------
// Self-test (MUST-FIX F: "Add an assertion/test that no allocated device /32 ==
// 10.70.0.1 and no two tenants share a /28"). Runs against an in-memory SQLite.
// Invoke with:  node alloc.js --selftest
// -----------------------------------------------------------------------------
function selftest() {
  const Database = require('better-sqlite3');
  const db = new Database(':memory:');
  db.exec(`
    CREATE TABLE tenant_subnets(id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id TEXT NOT NULL, cidr TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL);
    CREATE TABLE devices(device_id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL,
      state TEXT NOT NULL DEFAULT 'active', wg_ip TEXT NOT NULL);
  `);

  const now = 1;
  let dseq = 0;
  const allIps = new Set();
  const blockOwner = new Map(); // cidr -> tenant_id

  // 1) The very first allocation MUST land in 10.70.0.16/28, NOT the server block.
  const first = allocateDeviceIp(db, 't_a', now);
  if (first.cidr !== '10.70.0.16/28') {
    throw new Error(`FAIL: first tenant block is ${first.cidr}, expected 10.70.0.16/28`);
  }
  if (first.ip === cfg.wg.relayIp) throw new Error('FAIL: first ip is the relay ip');

  // 2) Allocate many devices across several tenants; assert invariants each time.
  const tenants = ['t_a', 't_b', 't_c', 't_d'];
  for (let i = 0; i < 200; i++) {
    const t = tenants[i % tenants.length];
    const { ip, cidr } = allocateDeviceIp(db, t, now);

    // (a) never the relay IP
    if (ip === cfg.wg.relayIp) throw new Error(`FAIL: allocated relay ip ${ip}`);
    // (b) never inside the reserved /28
    const ipInt = ipToInt(ip.split('.').map(Number)) >>> 0;
    if (ipInt >= RESERVED_BASE && ipInt <= RESERVED_END) {
      throw new Error(`FAIL: ${ip} is inside reserved ${cfg.wg.reservedCidr}`);
    }
    // (c) globally unique /32 across all tenants
    if (allIps.has(ip)) throw new Error(`FAIL: duplicate /32 ${ip}`);
    allIps.add(ip);
    // (d) no two tenants share a /28
    const prev = blockOwner.get(cidr);
    if (prev && prev !== t) throw new Error(`FAIL: /28 ${cidr} shared by ${prev} and ${t}`);
    blockOwner.set(cidr, t);

    db.prepare('INSERT INTO devices(device_id, tenant_id, state, wg_ip) VALUES (?,?,?,?)')
      .run('d_' + (++dseq), t, 'active', ip);
  }

  // 3) Explicit relay-collision probe: 10.70.0.1 must be unreachable by allocation.
  if (allIps.has(cfg.wg.relayIp)) throw new Error('FAIL: relay ip was allocated');

  console.log(`[alloc selftest] OK — ${allIps.size} unique /32s, ${blockOwner.size} /28 blocks, ` +
    `relay ${cfg.wg.relayIp} reserved, no cross-tenant /28 sharing.`);
}

if (require.main === module && process.argv.includes('--selftest')) {
  selftest();
}

module.exports = {
  allocateDeviceIp, allocateNewBlock, blockHosts, parseCidr,
  overlapsReserved, selftest,
  _internals: { RESERVED_BASE, RESERVED_END, RELAY_INT, FIRST_TENANT_BASE, POOL_END }
};
