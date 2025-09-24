const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0' });

  console.log('🧪 Test APIs et fonctionnalités PiSignage v0.8.0\n');

  // Test all APIs directly
  console.log('📊 APIs Tests:');
  const apis = [
    { url: '/api/system.php', name: 'System Stats' },
    { url: '/api/media.php?action=list', name: 'Media List' },
    { url: '/api/playlist.php?action=list', name: 'Playlists' },
    { url: '/api/logs.php?action=recent', name: 'Logs Recent' },
    { url: '/api/logs.php?action=sources', name: 'Log Sources' },
    { url: '/api/logs.php?action=stats', name: 'Log Stats' }
  ];

  for (const api of apis) {
    try {
      const response = await page.evaluate(async (url) => {
        const res = await fetch(url);
        const data = await res.json();
        return {
          status: res.status,
          success: data.success,
          hasData: !!data.data,
          message: data.message
        };
      }, api.url);

      const icon = response.status === 200 && response.success ? '✅' : '❌';
      console.log(`   ${icon} ${api.name}: ${response.status} - ${response.success ? 'OK' : response.message || 'Failed'}`);
    } catch (e) {
      console.log(`   ❌ ${api.name}: Error - ${e.message}`);
    }
  }

  // Test interface elements
  console.log('\n🎨 Interface Elements:');
  const elements = await page.evaluate(() => {
    return {
      sidebar: !!document.querySelector('.sidebar'),
      navItems: document.querySelectorAll('.nav-item').length,
      dashboard: !!document.getElementById('dashboard'),
      uploadZone: !!document.getElementById('upload-zone'),
      playerMode: !!document.getElementById('player-mode'),
      youtubeUrl: !!document.getElementById('youtube-url'),
      scheduleForm: !!document.getElementById('schedule-form'),
      logsDisplay: !!document.getElementById('logs-display')
    };
  });

  console.log('   Sidebar:', elements.sidebar ? '✅ Présente' : '❌ Absente');
  console.log('   Navigation items:', elements.navItems > 0 ? `✅ ${elements.navItems} items` : '❌ Aucun');
  console.log('   Dashboard:', elements.dashboard ? '✅ Présent' : '❌ Absent');
  console.log('   Upload zone:', elements.uploadZone ? '✅ Présente' : '❌ Absente');
  console.log('   Player mode:', elements.playerMode ? '✅ Présent' : '❌ Absent');
  console.log('   YouTube URL:', elements.youtubeUrl ? '✅ Présent' : '❌ Absent');
  console.log('   Schedule form:', elements.scheduleForm ? '✅ Présent' : '❌ Absent');
  console.log('   Logs display:', elements.logsDisplay ? '✅ Présent' : '❌ Absent');

  // Test JavaScript functions
  console.log('\n🔧 JavaScript Functions:');
  const functions = await page.evaluate(() => {
    return {
      showSection: typeof showSection === 'function',
      vlcControl: typeof vlcControl === 'function',
      uploadFile: typeof uploadFile === 'function',
      createPlaylist: typeof createPlaylist === 'function',
      downloadYouTube: typeof downloadYouTube === 'function',
      captureManual: typeof captureManual === 'function',
      refreshLogs: typeof refreshLogs === 'function'
    };
  });

  for (const [name, exists] of Object.entries(functions)) {
    console.log(`   ${name}:`, exists ? '✅ Définie' : '❌ Non définie');
  }

  // Test current stats display
  console.log('\n📈 Stats Display:');
  const stats = await page.evaluate(() => {
    const cpuEl = document.querySelector('[id*="cpu"]');
    const ramEl = document.querySelector('[id*="ram"]');
    const tempEl = document.querySelector('[id*="temp"]');

    return {
      cpu: cpuEl ? cpuEl.textContent : 'Not found',
      ram: ramEl ? ramEl.textContent : 'Not found',
      temp: tempEl ? tempEl.textContent : 'Not found'
    };
  });

  console.log('   CPU:', stats.cpu);
  console.log('   RAM:', stats.ram);
  console.log('   Température:', stats.temp);

  // Test media upload capability
  console.log('\n📤 Upload Test:');
  const uploadTest = await page.evaluate(async () => {
    const formData = new FormData();
    const blob = new Blob(['test'], { type: 'text/plain' });
    formData.append('file', blob, 'test.txt');

    try {
      const response = await fetch('/api/upload.php', {
        method: 'POST',
        body: formData
      });
      return { status: response.status, ok: response.ok };
    } catch (e) {
      return { error: e.message };
    }
  });

  if (uploadTest.error) {
    console.log(`   Upload API: ❌ ${uploadTest.error}`);
  } else {
    console.log(`   Upload API: ${uploadTest.ok ? '✅' : '❌'} Status ${uploadTest.status}`);
  }

  // Screenshot
  await page.screenshot({ path: '/tmp/api-test.png' });
  console.log('\n📸 Screenshot: /tmp/api-test.png');

  console.log('\n✅ Tests terminés!');

  await browser.close();
})();