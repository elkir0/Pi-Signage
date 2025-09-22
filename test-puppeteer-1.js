const puppeteer = require('puppeteer');

(async () => {
  console.log('🧪 TEST PUPPETEER 1: Navigation → Screenshot → Analyse');

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('📍 Navigation vers http://localhost:8000...');
  await page.goto('http://localhost:8000', {
    waitUntil: 'networkidle2',
    timeout: 30000
  });

  // Screenshot
  console.log('📸 Capture screenshot...');
  await page.screenshot({ path: '/opt/pisignage/test-screenshot-1.png' });

  // Analyse visuelle
  const title = await page.title();
  console.log('✅ Titre page:', title);

  // Vérifier présence éléments clés
  const elements = {
    dashboard: await page.$('#dashboard-tab') !== null,
    media: await page.$('#media-tab') !== null,
    playlist: await page.$('#playlist-tab') !== null,
    player: await page.$('#player-tab') !== null,
    youtube: await page.$('#youtube-tab') !== null
  };

  console.log('🔍 Éléments détectés:');
  for (const [key, value] of Object.entries(elements)) {
    console.log(`  - ${key}: ${value ? '✅' : '❌'}`);
  }

  // Vérifier APIs
  const apiResponse = await page.evaluate(async () => {
    try {
      const res = await fetch('/api/system.php');
      return await res.json();
    } catch (e) {
      return { error: e.message };
    }
  });

  console.log('🌐 API système:', apiResponse.success ? '✅ Fonctionnelle' : '❌ Erreur');

  await browser.close();

  console.log('\n📊 RÉSULTAT TEST 1:',
    title.includes('PiSignage') && elements.dashboard ? '✅ SUCCÈS' : '❌ ÉCHEC'
  );
})();