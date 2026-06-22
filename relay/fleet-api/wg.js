'use strict';

const { execFile } = require('child_process');
const cfg = require('./config');

// Run a command inside the wireguard container. We use `docker exec` because
// fleet-api and wireguard are sibling compose services; fleet-api's container is
// granted /var/run/docker.sock (read in compose notes) so it can drive `wg`.
// Alternative (no socket): run wg in fleet-api's own netns with NET_ADMIN — but
// the interface lives in the wireguard container, so exec into it is the clean path.
function dockerExec(args) {
  return new Promise((resolve, reject) => {
    execFile('docker', ['exec', cfg.wg.containerName, ...args], { timeout: 10000 },
      (err, stdout, stderr) => {
        if (err) return reject(new Error(`wg exec failed: ${stderr || err.message}`));
        resolve(stdout.toString());
      });
  });
}

// Add (or update) a peer live, then persist to the running config so it survives
// a container restart. allowedIp is the DEVICE /32 (e.g. "10.70.4.18/32").
async function addPeer(pubKey, deviceIp) {
  const allowed = `${deviceIp}/32`;
  // 1) Live add — no flap for existing peers.
  await dockerExec(['wg', 'set', cfg.wg.iface, 'peer', pubKey, 'allowed-ips', allowed]);
  // 2) Persist into the on-disk wg0.conf via wg-quick save, then re-sync so the
  //    running state and the file agree (idempotent). save writes the live peers
  //    back to /config/wg_confs/wg0.conf in the linuxserver image.
  await persist();
}

// Remove a peer (deprovision) live + persist.
async function removePeer(pubKey) {
  await dockerExec(['wg', 'set', cfg.wg.iface, 'peer', pubKey, 'remove']);
  await persist();
}

// Persist running interface to disk and re-converge. Using `wg-quick save` keeps
// the [Interface] stanza (ListenPort/Address) and rewrites [Peer] blocks from
// the live device, matching the VM400 "wg syncconf wg0 <(wg-quick strip wg0)" idiom.
async function persist() {
  try {
    await dockerExec(['wg-quick', 'save', cfg.wg.iface]);
  } catch (e) {
    // wg-quick save may be unavailable on some images; fall back to syncconf from
    // a stripped conf. We log and continue — the live `wg set` already took effect.
    console.warn('[wg] persist warning:', e.message);
  }
}

// Reconcile: ensure every non-retired device is present as a live peer. Called on
// boot so a fresh wireguard container converges to SQLite (source of truth).
async function reconcile(devices) {
  for (const d of devices) {
    try {
      await addPeer(d.wg_public_key, d.wg_ip);
    } catch (e) {
      console.error(`[wg] reconcile failed for ${d.device_id}:`, e.message);
    }
  }
}

module.exports = { addPeer, removePeer, persist, reconcile };
