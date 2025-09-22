const puppeteer = require('puppeteer');

(async () => {
  console.log('🧪 Test PiSignage Production - 192.168.1.103');

  const browser = await puppeteer.launch({ headless: 'new' });
  const page = await browser.newPage();

  // Test 1: APIs JSON
  console.log('\n📊 Test 1: Validation APIs JSON');

  const apis = ['system', 'media', 'playlist'];
  for (const api of apis) {
    try {
      const response = await page.goto(`http://192.168.1.103/api/${api}.php`, {
        waitUntil: 'networkidle0'
      });
      const text = await page.content();
      const body = text.match(/<pre.*?>(.*?)<\/pre>/s)?.[1] || '';

      // Vérifier que c'est du JSON valide
      JSON.parse(body);
      console.log(`✅ API ${api}.php : JSON valide`);
    } catch (e) {
      console.log(`❌ API ${api}.php : ${e.message}`);
    }
  }

  // Test 2: Interface Web
  console.log('\n🌐 Test 2: Interface Web');

  await page.goto('http://192.168.1.103', { waitUntil: 'networkidle0' });

  // Collecter les erreurs console
  const errors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') errors.push(msg.text());
  });

  await page.reload({ waitUntil: 'networkidle0' });

  const title = await page.title();
  console.log(`📋 Titre: "${title}"`);

  if (errors.length === 0) {
    console.log('✅ Aucune erreur console');
  } else {
    console.log(`⚠️ ${errors.length} erreurs console:`, errors.slice(0, 3));
  }

  // Screenshot
  await page.screenshot({ path: 'test-final.png' });
  console.log('📸 Screenshot: test-final.png');

  // Test 3: Vérifier VLC
  console.log('\n🎬 Test 3: État VLC');
  const { execSync } = require('child_process');
  try {
    const vlcStatus = execSync("sshpass -p 'raspberry' ssh pi@192.168.1.103 'ps aux | grep vlc | grep -v grep | wc -l'").toString().trim();
    if (parseInt(vlcStatus) > 0) {
      console.log('✅ VLC en cours d\'exécution');
    } else {
      console.log('❌ VLC n\'est pas en cours d\'exécution');
    }
  } catch (e) {
    console.log('⚠️ Impossible de vérifier VLC');
  }

  console.log('\n✨ Tests terminés!');

  await browser.close();
})();