const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('🧪 Test complet PiSignage v0.8.0 - Toutes fonctionnalités\n');

  // Go to main page
  await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0' });
  console.log('✅ Page principale chargée');

  // Inject console output
  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.log('❌ Console Error:', msg.text());
    }
  });

  // Test 1: Dashboard
  console.log('\n📊 Test Dashboard:');
  const dashboardStats = await page.evaluate(() => {
    const stats = {
      cpu: document.querySelector('[id*="cpu"]')?.textContent,
      ram: document.querySelector('[id*="ram"]')?.textContent,
      temp: document.querySelector('[id*="temp"]')?.textContent
    };
    return stats;
  });
  console.log('   CPU:', dashboardStats.cpu || '❌ Non trouvé');
  console.log('   RAM:', dashboardStats.ram || '❌ Non trouvé');
  console.log('   Temp:', dashboardStats.temp || '❌ Non trouvé');

  // Test 2: Media section
  console.log('\n📁 Test Médias:');
  try {
    await page.click('[data-section="media"]');
    await page.waitForTimeout(1000);

    // Test upload zone
    const uploadZone = await page.$('#upload-zone');
    console.log('   Zone upload:', uploadZone ? '✅ Présente' : '❌ Absente');

    // Test media list API
    const mediaResponse = await page.evaluate(async () => {
      const response = await fetch('/api/media.php?action=list');
      return {
        status: response.status,
        ok: response.ok,
        data: await response.json()
      };
    });
    console.log('   API Media:', mediaResponse.ok ? `✅ ${mediaResponse.status}` : `❌ ${mediaResponse.status}`);
    if (mediaResponse.data && mediaResponse.data.data) {
      console.log('   Fichiers trouvés:', mediaResponse.data.data.length);
    }
  } catch (e) {
    console.log('   ❌ Erreur:', e.message);
  }

  // Test 3: Playlist section
  console.log('\n🎵 Test Playlists:');
  try {
    await page.click('[data-section="playlists"]');
    await page.waitForTimeout(1000);

    // Test playlist API
    const playlistResponse = await page.evaluate(async () => {
      const response = await fetch('/api/playlist.php?action=list');
      return {
        status: response.status,
        ok: response.ok,
        data: await response.json()
      };
    });
    console.log('   API Playlist:', playlistResponse.ok ? `✅ ${playlistResponse.status}` : `❌ ${playlistResponse.status}`);
    if (playlistResponse.data && playlistResponse.data.success) {
      console.log('   Playlists trouvées:', playlistResponse.data.data ? playlistResponse.data.data.length : 0);
    }

    // Check create playlist button
    const createBtn = await page.$('button[onclick*="createPlaylist"]');
    console.log('   Bouton création:', createBtn ? '✅ Présent' : '❌ Absent');
  } catch (e) {
    console.log('   ❌ Erreur:', e.message);
  }

  // Test 4: YouTube section
  console.log('\n📺 Test YouTube:');
  try {
    await page.click('[data-section="youtube"]');
    await page.waitForTimeout(1000);

    const youtubeInput = await page.$('#youtube-url');
    const downloadBtn = await page.$('button[onclick*="downloadYouTube"]');

    console.log('   Champ URL:', youtubeInput ? '✅ Présent' : '❌ Absent');
    console.log('   Bouton download:', downloadBtn ? '✅ Présent' : '❌ Absent');
  } catch (e) {
    console.log('   ❌ Erreur:', e.message);
  }

  // Test 5: Player section
  console.log('\n▶️ Test Lecteur:');
  try {
    await page.click('[data-section="player"]');
    await page.waitForTimeout(1000);

    const modeSelector = await page.$('#player-mode');
    const playBtn = await page.$('button[onclick*="vlcControl(\'play\')"]');
    const captureBtn = await page.$('button[onclick*="captureScreen"]');

    console.log('   Sélecteur mode:', modeSelector ? '✅ Présent' : '❌ Absent');

    if (modeSelector) {
      const modes = await page.$$eval('#player-mode option', options => options.map(o => o.textContent));
      console.log('   Modes disponibles:', modes.join(', '));
    }

    console.log('   Bouton Play:', playBtn ? '✅ Présent' : '❌ Absent');
    console.log('   Bouton Capture:', captureBtn ? '✅ Présent' : '❌ Absent');
  } catch (e) {
    console.log('   ❌ Erreur:', e.message);
  }

  // Test 6: Schedule section
  console.log('\n📅 Test Programmation:');
  try {
    await page.click('[data-section="schedule"]');
    await page.waitForTimeout(1000);

    const scheduleForm = await page.$('#schedule-form');
    console.log('   Formulaire:', scheduleForm ? '✅ Présent' : '❌ Absent');
  } catch (e) {
    console.log('   ❌ Erreur:', e.message);
  }

  // Test 7: Screenshot section
  console.log('\n📸 Test Capture:');
  try {
    await page.click('[data-section="screenshot"]');
    await page.waitForTimeout(1000);

    const captureManualBtn = await page.$('button[onclick*="captureManual"]');
    const autoToggle = await page.$('#auto-capture-toggle');

    console.log('   Bouton capture manuelle:', captureManualBtn ? '✅ Présent' : '❌ Absent');
    console.log('   Toggle auto-capture:', autoToggle ? '✅ Présent' : '❌ Absent');
  } catch (e) {
    console.log('   ❌ Erreur:', e.message);
  }

  // Test 8: Settings section
  console.log('\n⚙️ Test Paramètres:');
  try {
    await page.click('[data-section="settings"]');
    await page.waitForTimeout(1000);

    const settingsContent = await page.$eval('.section-content', el => el.children.length > 0);
    console.log('   Section paramètres:', settingsContent ? '✅ Contenu présent' : '❌ Vide');
  } catch (e) {
    console.log('   ❌ Erreur:', e.message);
  }

  // Test 9: Logs section
  console.log('\n📋 Test Logs:');
  try {
    await page.click('[data-section="logs"]');
    await page.waitForTimeout(1000);

    // Test logs API
    const logsResponse = await page.evaluate(async () => {
      const response = await fetch('/api/logs.php?action=list');
      return {
        status: response.status,
        ok: response.ok
      };
    });
    console.log('   API Logs:', logsResponse.ok ? `✅ ${logsResponse.status}` : `❌ ${logsResponse.status}`);
  } catch (e) {
    console.log('   ❌ Erreur:', e.message);
  }

  // Final screenshot
  await page.screenshot({ path: '/tmp/pisignage-test-final.png' });
  console.log('\n📸 Screenshot final: /tmp/pisignage-test-final.png');

  // Test all APIs
  console.log('\n🔌 Test APIs:');
  const apis = [
    '/api/system.php',
    '/api/media.php?action=list',
    '/api/playlist.php?action=list',
    '/api/logs.php?action=list'
  ];

  for (const api of apis) {
    const response = await page.evaluate(async (url) => {
      try {
        const res = await fetch(url);
        return { url, status: res.status, ok: res.ok };
      } catch (e) {
        return { url, error: e.message };
      }
    }, api);

    if (response.error) {
      console.log(`   ${api}: ❌ ${response.error}`);
    } else {
      console.log(`   ${api}: ${response.ok ? '✅' : '❌'} ${response.status}`);
    }
  }

  await browser.close();
  console.log('\n✅ Tests terminés!');
})();