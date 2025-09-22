const puppeteer = require('puppeteer');

(async () => {
  console.log('🧪 TEST PRODUCTION 1: Navigation → Screenshot → Analyse');
  console.log('🎯 Target: http://192.168.1.103');

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('📍 Navigation vers Raspberry Pi production...');
  await page.goto('http://192.168.1.103', {
    waitUntil: 'networkidle2',
    timeout: 30000
  });

  // Screenshot
  console.log('📸 Capture screenshot production...');
  await page.screenshot({ path: '/opt/pisignage/production-screenshot-1.png' });

  // Analyse visuelle
  const title = await page.title();
  console.log('✅ Titre page:', title);

  // Vérifier version
  const version = await page.evaluate(() => {
    const h1 = document.querySelector('h1');
    return h1 ? h1.textContent : 'Unknown';
  });
  console.log('🔖 Version affichée:', version);

  // Vérifier éléments clés
  const elements = {
    dashboard: await page.$('#dashboard-tab') !== null,
    media: await page.$('#media-tab') !== null,
    playlist: await page.$('#playlist-tab') !== null,
    player: await page.$('#player-tab') !== null,
    youtube: await page.$('#youtube-tab') !== null,
    screenshot: await page.$('#screenshot-tab') !== null
  };

  console.log('🔍 Éléments détectés sur production:');
  for (const [key, value] of Object.entries(elements)) {
    console.log(`  - ${key}: ${value ? '✅' : '❌'}`);
  }

  // Vérifier APIs production
  const apiResponse = await page.evaluate(async () => {
    try {
      const res = await fetch('/api/system.php');
      return await res.json();
    } catch (e) {
      return { error: e.message };
    }
  });

  console.log('🌐 API système production:');
  if (apiResponse.success) {
    console.log('  ✅ Status: Fonctionnelle');
    console.log(`  📊 CPU: ${apiResponse.data.cpu}%`);
    console.log(`  💾 RAM: ${apiResponse.data.memory}%`);
    console.log(`  🌡️ Temp: ${apiResponse.data.temperature}°C`);
    console.log(`  🏠 Host: ${apiResponse.data.hostname}`);
    console.log(`  🔧 Version: ${apiResponse.data.version}`);
  } else {
    console.log('  ❌ Status: Erreur', apiResponse.error || 'Unknown');
  }

  await browser.close();

  const success = title.includes('PiSignage') &&
                  version.includes('v0.8.0') &&
                  elements.dashboard &&
                  apiResponse.success;

  console.log('\n📊 RÉSULTAT TEST PRODUCTION 1:',
    success ? '✅ SUCCÈS' : '❌ ÉCHEC'
  );

  console.log('\n🎯 URL Production validée: http://192.168.1.103');
})();