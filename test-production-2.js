const puppeteer = require('puppeteer');

(async () => {
  console.log('🧪 TEST PRODUCTION 2: Console Debug + Performance');
  console.log('🎯 Target: http://192.168.1.103');

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();

  // Capturer console logs
  const consoleLogs = [];
  page.on('console', msg => {
    consoleLogs.push({
      type: msg.type(),
      text: msg.text()
    });
  });

  // Capturer erreurs page
  const pageErrors = [];
  page.on('pageerror', error => {
    pageErrors.push(error.message);
  });

  // Capturer erreurs réseau
  const networkErrors = [];
  page.on('requestfailed', request => {
    networkErrors.push({
      url: request.url(),
      error: request.failure().errorText
    });
  });

  console.log('📍 Navigation vers production...');
  const startTime = Date.now();
  await page.goto('http://192.168.1.103', {
    waitUntil: 'networkidle2',
    timeout: 30000
  });
  const loadTime = Date.now() - startTime;

  console.log(`⚡ Temps de chargement: ${loadTime}ms`);

  // Performance metrics
  const metrics = await page.metrics();
  console.log('📈 Métriques production:');
  console.log(`  - JS Heap: ${Math.round(metrics.JSHeapUsedSize / 1024 / 1024)}MB`);
  console.log(`  - DOM Nodes: ${metrics.Nodes}`);
  console.log(`  - Layout Duration: ${Math.round(metrics.LayoutDuration * 1000)}ms`);
  console.log(`  - Script Duration: ${Math.round(metrics.ScriptDuration * 1000)}ms`);

  // Vérifier fonctionnalités JS sur production
  const jsChecks = await page.evaluate(() => {
    return {
      tabSwitching: typeof switchTab === 'function',
      apiCalls: typeof refreshDashboard === 'function',
      mediaManagement: document.querySelector('#media-content') !== null,
      playerControls: document.querySelector('#player-content') !== null,
      youtubeDownload: document.querySelector('#youtube-content') !== null,
      version: document.querySelector('h1')?.textContent || 'Unknown',
      hostname: window.location.hostname,
      timestamp: new Date().toISOString()
    };
  });

  console.log('\n🔧 Fonctionnalités JavaScript production:');
  console.log(`  - Tab switching: ${jsChecks.tabSwitching ? '✅' : '❌'}`);
  console.log(`  - API calls: ${jsChecks.apiCalls ? '✅' : '❌'}`);
  console.log(`  - Media management: ${jsChecks.mediaManagement ? '✅' : '❌'}`);
  console.log(`  - Player controls: ${jsChecks.playerControls ? '✅' : '❌'}`);
  console.log(`  - YouTube download: ${jsChecks.youtubeDownload ? '✅' : '❌'}`);
  console.log(`  - Version: ${jsChecks.version}`);
  console.log(`  - Hostname: ${jsChecks.hostname}`);

  // Test APIs multiples
  const apiTests = await page.evaluate(async () => {
    const apis = [
      '/api/system.php',
      '/api/media.php?action=list',
      '/api/playlist.php?action=list'
    ];

    const results = {};
    for (const api of apis) {
      try {
        const res = await fetch(api);
        const data = await res.json();
        results[api] = { success: data.success, status: res.status };
      } catch (e) {
        results[api] = { error: e.message };
      }
    }
    return results;
  });

  console.log('\n🌐 Tests APIs production:');
  for (const [api, result] of Object.entries(apiTests)) {
    const status = result.success ? '✅' : '❌';
    console.log(`  - ${api}: ${status} (${result.status || 'Error'})`);
  }

  console.log('\n📝 Console Logs:', consoleLogs.length);
  consoleLogs.forEach(log => {
    if (log.type === 'error') {
      console.log(`  ❌ ERROR: ${log.text}`);
    } else if (log.type === 'warning') {
      console.log(`  ⚠️ WARNING: ${log.text}`);
    }
  });

  console.log('\n🚨 Erreurs Page:', pageErrors.length);
  pageErrors.forEach(err => console.log(`  ❌ ${err}`));

  console.log('\n🌐 Erreurs Réseau:', networkErrors.length);
  networkErrors.forEach(err => console.log(`  ❌ ${err.url}: ${err.error}`));

  await browser.close();

  const hasErrors = pageErrors.length > 0 || networkErrors.length > 0 ||
    consoleLogs.filter(l => l.type === 'error').length > 0;

  const performance = loadTime < 5000 && metrics.JSHeapUsedSize < 50000000;

  const success = !hasErrors &&
                  jsChecks.tabSwitching &&
                  performance &&
                  Object.values(apiTests).every(r => r.success);

  console.log('\n📊 RÉSULTAT TEST PRODUCTION 2:',
    success ? '✅ SUCCÈS' : '❌ ÉCHEC'
  );

  console.log(`\n🏆 Production PiSignage v0.8.0 sur ${jsChecks.hostname} validée !`);
})();