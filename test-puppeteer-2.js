const puppeteer = require('puppeteer');

(async () => {
  console.log('🧪 TEST PUPPETEER 2: Navigation → Console Debug → Erreurs');

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

  console.log('📍 Navigation vers http://localhost:8000...');
  await page.goto('http://localhost:8000', {
    waitUntil: 'networkidle2',
    timeout: 30000
  });

  // Performance metrics
  const metrics = await page.metrics();
  console.log('⚡ Performance:');
  console.log(`  - JS Heap: ${Math.round(metrics.JSHeapUsedSize / 1024 / 1024)}MB`);
  console.log(`  - DOM Nodes: ${metrics.Nodes}`);
  console.log(`  - Layout Duration: ${Math.round(metrics.LayoutDuration * 1000)}ms`);

  // Vérifier fonctionnalités JS
  const jsChecks = await page.evaluate(() => {
    return {
      tabSwitching: typeof switchTab === 'function',
      apiCalls: typeof refreshDashboard === 'function',
      mediaManagement: document.querySelector('#media-content') !== null,
      version: document.querySelector('h1')?.textContent || 'Unknown'
    };
  });

  console.log('\n🔧 Fonctionnalités JavaScript:');
  console.log(`  - Tab switching: ${jsChecks.tabSwitching ? '✅' : '❌'}`);
  console.log(`  - API calls: ${jsChecks.apiCalls ? '✅' : '❌'}`);
  console.log(`  - Media management: ${jsChecks.mediaManagement ? '✅' : '❌'}`);
  console.log(`  - Version affichée: ${jsChecks.version}`);

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

  console.log('\n📊 RÉSULTAT TEST 2:',
    !hasErrors && jsChecks.tabSwitching ? '✅ SUCCÈS' : '❌ ÉCHEC'
  );
})();