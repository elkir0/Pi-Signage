'use strict';

const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');
const cfg = require('./config');

let db;

// --- Schema (contract dataModel, verbatim shapes) -----------------------------
// Each migration is idempotent at the statement level (CREATE TABLE IF NOT EXISTS,
// CREATE INDEX IF NOT EXISTS). The _migrations ledger records applied names so we
// can add future migrations append-only without re-running old ones.
//
// APPEND-ONLY CONTRACT: migrations 001/002 are FROZEN — never edit them. New work
// is added as 003+ below. ALTER TABLE ADD COLUMN is run only when the migration is
// first applied (guarded by the _migrations ledger), so re-runs never error.
const MIGRATIONS = [
  {
    name: '001_init',
    sql: `
    CREATE TABLE IF NOT EXISTS tenants (
      tenant_id   TEXT PRIMARY KEY,
      name        TEXT NOT NULL,
      status      TEXT NOT NULL DEFAULT 'active',
      created_at  INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS tenant_subnets (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id   TEXT NOT NULL REFERENCES tenants(tenant_id),
      cidr        TEXT NOT NULL,
      created_at  INTEGER NOT NULL,
      UNIQUE(cidr)
    );
    CREATE INDEX IF NOT EXISTS ix_subnets_tenant ON tenant_subnets(tenant_id);

    CREATE TABLE IF NOT EXISTS api_keys (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id   TEXT NOT NULL REFERENCES tenants(tenant_id),
      key_hash    TEXT NOT NULL,
      label       TEXT,
      created_at  INTEGER NOT NULL,
      revoked_at  INTEGER,
      UNIQUE(key_hash)
    );
    CREATE INDEX IF NOT EXISTS ix_apikeys_tenant ON api_keys(tenant_id);

    CREATE TABLE IF NOT EXISTS enrollment_codes (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      code_hash    TEXT NOT NULL,
      tenant_id    TEXT NOT NULL REFERENCES tenants(tenant_id),
      rebind       INTEGER NOT NULL DEFAULT 0,
      created_at   INTEGER NOT NULL,
      expires_at   INTEGER NOT NULL,
      consumed_at  INTEGER,
      consumed_by  TEXT REFERENCES devices(device_id),
      nonce        TEXT,
      UNIQUE(code_hash)
    );
    CREATE INDEX IF NOT EXISTS ix_codes_tenant ON enrollment_codes(tenant_id);

    CREATE TABLE IF NOT EXISTS devices (
      device_id         TEXT PRIMARY KEY,
      tenant_id         TEXT NOT NULL REFERENCES tenants(tenant_id),
      state             TEXT NOT NULL DEFAULT 'pending',
      hostname          TEXT,
      machine_id        TEXT,
      model             TEXT,
      player_version    TEXT,
      agent_version     TEXT,
      wg_public_key     TEXT NOT NULL,
      wg_ip             TEXT NOT NULL,
      fingerprint       TEXT NOT NULL,
      mqtt_username     TEXT NOT NULL,
      mqtt_pw_fp        TEXT NOT NULL,
      online            INTEGER NOT NULL DEFAULT 0,
      last_heartbeat_at INTEGER,
      last_status_at    INTEGER,
      last_seen_at      INTEGER,
      last_facts_json   TEXT,
      created_at        INTEGER NOT NULL,
      confirmed_at      INTEGER,
      retired_at        INTEGER,
      UNIQUE(tenant_id, wg_ip),
      UNIQUE(wg_public_key)
    );
    CREATE INDEX IF NOT EXISTS ix_devices_tenant ON devices(tenant_id);
    CREATE INDEX IF NOT EXISTS ix_devices_state  ON devices(tenant_id, state);

    CREATE TABLE IF NOT EXISTS device_telemetry (
      device_id    TEXT PRIMARY KEY REFERENCES devices(device_id),
      tenant_id    TEXT NOT NULL REFERENCES tenants(tenant_id),
      ts           INTEGER NOT NULL,
      player_json  TEXT,
      system_json  TEXT,
      seq          INTEGER
    );
    CREATE INDEX IF NOT EXISTS ix_telemetry_tenant ON device_telemetry(tenant_id);

    CREATE TABLE IF NOT EXISTS commands (
      cmd_id       TEXT PRIMARY KEY,
      tenant_id    TEXT NOT NULL REFERENCES tenants(tenant_id),
      device_id    TEXT NOT NULL REFERENCES devices(device_id),
      type         TEXT NOT NULL,
      args_json    TEXT,
      issued_by    TEXT,
      issued_at    INTEGER NOT NULL,
      result_code  TEXT,
      result_json  TEXT,
      result_at    INTEGER
    );
    CREATE INDEX IF NOT EXISTS ix_commands_device ON commands(tenant_id, device_id, issued_at);

    CREATE TABLE IF NOT EXISTS events (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id    TEXT NOT NULL REFERENCES tenants(tenant_id),
      device_id    TEXT NOT NULL REFERENCES devices(device_id),
      type         TEXT NOT NULL,
      payload_json TEXT,
      ts           INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS ix_events_tenant ON events(tenant_id, ts);

    CREATE TABLE IF NOT EXISTS processed_events (
      msg_key      TEXT PRIMARY KEY,
      tenant_id    TEXT NOT NULL REFERENCES tenants(tenant_id),
      processed_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS ix_processed_tenant ON processed_events(tenant_id, processed_at);
    `
  },
  {
    // Idempotency replay (MUST-FIX G): the issued mqtt password is persisted on the
    // consumed code row so a lost-response retry returns the byte-identical 200 body.
    name: '002_enroll_mqtt_pw',
    sql: `ALTER TABLE enrollment_codes ADD COLUMN issued_mqtt_password TEXT;`
  },

  // ===========================================================================
  // APPEND-ONLY (Zaforge console + Stripe billing). 003-006. Idempotent; applied
  // once via the _migrations ledger. DEFAULTS keep every EXISTING tenant fully
  // functional (community / managed-on / sub_status none) so the live enrolled
  // tenant keeps full function with zero behavior change.
  // ===========================================================================
  {
    // 003_billing: billing projection columns on tenants. Defaults are chosen so
    // billing is ADDITIVE and FAIL-OPEN — managed-on until a VERIFIED webhook
    // flips state. stripe_sub_item_id is stored because the per-screen quantity is
    // PATCHed on the SubscriptionItem, not the Subscription.
    name: '003_billing',
    sql: `
    ALTER TABLE tenants ADD COLUMN stripe_customer_id     TEXT;
    ALTER TABLE tenants ADD COLUMN stripe_subscription_id TEXT;
    ALTER TABLE tenants ADD COLUMN stripe_sub_item_id     TEXT;
    ALTER TABLE tenants ADD COLUMN plan          TEXT NOT NULL DEFAULT 'community';
    ALTER TABLE tenants ADD COLUMN sub_status    TEXT NOT NULL DEFAULT 'none';
    ALTER TABLE tenants ADD COLUMN managed_state TEXT NOT NULL DEFAULT 'managed-on';
    ALTER TABLE tenants ADD COLUMN billing_interval TEXT;
    ALTER TABLE tenants ADD COLUMN billing_currency TEXT;
    ALTER TABLE tenants ADD COLUMN qty_synced_at INTEGER;
    CREATE INDEX IF NOT EXISTS ix_tenants_customer ON tenants(stripe_customer_id);
    CREATE INDEX IF NOT EXISTS ix_tenants_subscription ON tenants(stripe_subscription_id);
    `
  },
  {
    // 004_device_cache: a screen is billable only when state='active' AND
    // content_cached=1 (set by the agent's content-synced event). Brick-proof:
    // never bill a screen before its content is locally cached.
    name: '004_device_cache',
    sql: `
    ALTER TABLE devices ADD COLUMN content_cached    INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE devices ADD COLUMN content_cached_at INTEGER;
    `
  },
  {
    // 005_console_auth: BFF console identity + opaque httpOnly sessions. The raw
    // cookie value NEVER lands in the DB — only sha256(raw) (session_id_hash).
    name: '005_console_auth',
    sql: `
    CREATE TABLE IF NOT EXISTS console_users (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id   TEXT NOT NULL REFERENCES tenants(tenant_id),
      email       TEXT NOT NULL,
      pw_hash     TEXT NOT NULL,
      role        TEXT NOT NULL DEFAULT 'owner',
      totp_secret TEXT,
      created_at  INTEGER NOT NULL,
      disabled_at INTEGER,
      UNIQUE(email)
    );
    CREATE INDEX IF NOT EXISTS ix_console_users_tenant ON console_users(tenant_id);

    CREATE TABLE IF NOT EXISTS console_sessions (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id_hash  TEXT NOT NULL UNIQUE,
      console_user_id  INTEGER NOT NULL REFERENCES console_users(id),
      tenant_id        TEXT NOT NULL REFERENCES tenants(tenant_id),
      created_at       INTEGER NOT NULL,
      expires_at       INTEGER NOT NULL,
      last_seen_at     INTEGER,
      revoked_at       INTEGER
    );
    CREATE INDEX IF NOT EXISTS ix_console_sessions_user ON console_sessions(console_user_id);
    `
  },
  {
    // 006_billing_events: human-readable forensic ledger of webhook events.
    // DISTINCT from processed_events (the idempotency latch keyed by msg_key PK).
    name: '006_billing_events',
    sql: `
    CREATE TABLE IF NOT EXISTS billing_events (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id       TEXT,
      stripe_event_id TEXT UNIQUE,
      type            TEXT NOT NULL,
      payload_json    TEXT,
      ts              INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS ix_billing_events_tenant ON billing_events(tenant_id, ts);
    `
  },
  {
    // 007_system_tenant: the Stripe webhook idempotency latch writes a
    // processed_events row keyed by the stripe event id, bucketed under the
    // 'system' tenant. processed_events.tenant_id is a FK to tenants, so without
    // this sentinel the latch INSERT would FK-fail and the webhook would be
    // silently dropped (breaking dunning + self-heal). Seed it once; no devices,
    // api_keys, or console_users ever attach to it.
    name: '007_system_tenant',
    sql: `INSERT OR IGNORE INTO tenants(tenant_id, name, status, created_at)
          VALUES ('system', 'system', 'active', CAST(strftime('%s','now') AS INTEGER));`
  }
];

function init() {
  const dir = path.dirname(cfg.dbPath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

  db = new Database(cfg.dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.pragma('busy_timeout = 5000');

  db.exec(`CREATE TABLE IF NOT EXISTS _migrations (
    name TEXT PRIMARY KEY,
    applied_at INTEGER NOT NULL
  );`);

  const applied = new Set(db.prepare('SELECT name FROM _migrations').all().map((r) => r.name));
  const mark = db.prepare('INSERT INTO _migrations(name, applied_at) VALUES (?, ?)');
  for (const m of MIGRATIONS) {
    if (applied.has(m.name)) continue;
    const tx = db.transaction(() => {
      db.exec(m.sql);
      mark.run(m.name, Math.floor(Date.now() / 1000));
    });
    tx();
    console.log(`[db] applied migration ${m.name}`);
  }
  return db;
}

function get() {
  if (!db) throw new Error('db not initialised');
  return db;
}

module.exports = { init, get };
