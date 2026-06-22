'use strict';

const { get } = require('./db');
const wg = require('./wg');
const dynsec = require('./dynsec');

async function run() {
  const devices = get().prepare("SELECT * FROM devices WHERE state != 'retired'").all();
  console.log(`[reconcile] converging ${devices.length} device(s) to wg + dynsec`);
  await wg.reconcile(devices);
  await dynsec.reconcile(devices);
  console.log('[reconcile] done');
}

module.exports = { run };
