const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    defaultViewport: { width: 1920, height: 1080 },
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
  });

  const page = await browser.newPage();

  const screenshotsDir = '/opt/pisignage/screenshots';
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const results = {
    timestamp: new Date().toISOString(),
    baseUrl: 'http://192.168.1.103/',
    apis: [],
    functionalities: [],
    uploads: [],
    errors: []
  };

  console.log('🔗 Test 3: APIs Système et Fonctionnalités');
  console.log('Base URL:', 'http://192.168.1.103/');

  // Liste complète des APIs à tester
  const apisToTest = [
    '/api/system.php',
    '/api/player.php',
    '/api/playlist.php',
    '/api/media.php',
    '/api/screenshot.php',
    '/api/youtube.php',
    '/api/upload.php',
    '/api/config.php',
    '/api/status.php'
  ];

  // Test détaillé de chaque API
  for (const apiPath of apisToTest) {
    console.log(`\n📡 Test API: ${apiPath}`);

    try {
      const startTime = Date.now();

      // Test GET
      const response = await page.goto(`http://192.168.1.103${apiPath}`, {
        waitUntil: 'networkidle2',
        timeout: 5000
      });

      const loadTime = Date.now() - startTime;
      const status = response.status();
      const contentType = response.headers()['content-type'] || '';
      const content = await page.content();

      let parsedContent = null;
      let isJson = false;

      // Tenter de parser le JSON
      try {
        const bodyText = await page.evaluate(() => {
          const pre = document.querySelector('pre');
          return pre ? pre.textContent : document.body.textContent;
        });

        if (bodyText.trim().startsWith('{') || bodyText.trim().startsWith('[')) {
          parsedContent = JSON.parse(bodyText);
          isJson = true;
        }
      } catch (parseError) {
        // Pas du JSON valide
      }

      const apiResult = {
        endpoint: apiPath,
        status: status,
        loadTime: loadTime,
        contentType: contentType,
        contentLength: content.length,
        isJson: isJson,
        working: status === 200,
        data: isJson ? parsedContent : null,
        preview: content.substring(0, 200).replace(/\s+/g, ' ').trim()
      };

      results.apis.push(apiResult);

      console.log(`   Status: ${status === 200 ? '✅' : '❌'} ${status}`);
      console.log(`   Type: ${contentType}`);
      console.log(`   Taille: ${content.length} bytes`);
      console.log(`   Temps: ${loadTime}ms`);

      if (isJson && parsedContent) {
        console.log(`   JSON: ✅ ${Object.keys(parsedContent).length} clés`);
        if (typeof parsedContent === 'object') {
          const keys = Object.keys(parsedContent).slice(0, 5);
          console.log(`   Clés: [${keys.join(', ')}]`);
        }
      } else {
        console.log(`   Aperçu: ${apiResult.preview.substring(0, 80)}...`);
      }

    } catch (error) {
      console.log(`   ❌ Erreur: ${error.message}`);
      results.apis.push({
        endpoint: apiPath,
        status: 'ERROR',
        working: false,
        error: error.message,
        loadTime: 0
      });
      results.errors.push(`API ${apiPath}: ${error.message}`);
    }
  }

  // Test POST sur quelques APIs importantes
  console.log('\n📤 Test des requêtes POST...');

  const postTests = [
    {
      endpoint: '/api/player.php',
      data: { action: 'status' }
    },
    {
      endpoint: '/api/playlist.php',
      data: { action: 'list' }
    },
    {
      endpoint: '/api/system.php',
      data: { action: 'info' }
    }
  ];

  for (const postTest of postTests) {
    try {
      console.log(`📤 POST ${postTest.endpoint}...`);

      await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });

      const postResult = await page.evaluate(async (endpoint, data) => {
        try {
          const response = await fetch(endpoint, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(data)
          });

          const text = await response.text();

          return {
            status: response.status,
            statusText: response.statusText,
            text: text,
            success: response.ok
          };
        } catch (error) {
          return {
            error: error.message,
            success: false
          };
        }
      }, postTest.endpoint, postTest.data);

      console.log(`   POST ${postTest.endpoint}: ${postResult.success ? '✅' : '❌'} ${postResult.status || 'ERROR'}`);

      results.apis.find(api => api.endpoint === postTest.endpoint).postTest = postResult;

    } catch (error) {
      console.log(`   ❌ POST ${postTest.endpoint}: ${error.message}`);
    }
  }

  // Test des fonctionnalités interface
  console.log('\n🎛️ Test des fonctionnalités interface...');

  try {
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Test navigation entre sections
    const navigationTests = [
      { name: 'Dashboard', selector: 'a[href*="dashboard"], a:contains("Dashboard")' },
      { name: 'Médias', selector: 'a:contains("Médias"), a:contains("Media")' },
      { name: 'Playlists', selector: 'a:contains("Playlist")' },
      { name: 'Lecteur', selector: 'a:contains("Lecteur"), a:contains("Player")' }
    ];

    for (const navTest of navigationTests) {
      try {
        console.log(`🧭 Test navigation: ${navTest.name}...`);

        // Retourner à la page principale
        await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
        await new Promise(resolve => setTimeout(resolve, 1000));

        // Trouver le lien
        const linkExists = await page.evaluate((name) => {
          const links = Array.from(document.querySelectorAll('a, button'));
          return links.find(link =>
            link.textContent.toLowerCase().includes(name.toLowerCase())
          ) !== undefined;
        }, navTest.name);

        if (linkExists) {
          // Cliquer sur le lien
          await page.evaluate((name) => {
            const links = Array.from(document.querySelectorAll('a, button'));
            const link = links.find(link =>
              link.textContent.toLowerCase().includes(name.toLowerCase())
            );
            if (link) link.click();
          }, navTest.name);

          await new Promise(resolve => setTimeout(resolve, 1500));

          // Screenshot de la section
          await page.screenshot({
            path: path.join(screenshotsDir, `08_${navTest.name.toLowerCase()}_nav.png`),
            fullPage: true
          });

          results.functionalities.push({
            name: `Navigation ${navTest.name}`,
            status: 'SUCCESS',
            screenshot: `08_${navTest.name.toLowerCase()}_nav.png`
          });

          console.log(`   ✅ Navigation ${navTest.name} réussie`);
        } else {
          console.log(`   ❌ Lien ${navTest.name} non trouvé`);
          results.functionalities.push({
            name: `Navigation ${navTest.name}`,
            status: 'NOT_FOUND'
          });
        }

      } catch (navError) {
        console.log(`   ❌ Erreur navigation ${navTest.name}: ${navError.message}`);
        results.functionalities.push({
          name: `Navigation ${navTest.name}`,
          status: 'ERROR',
          error: navError.message
        });
      }
    }

    // Test des boutons de contrôle
    console.log('\n🎮 Test des contrôles...');

    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
    await new Promise(resolve => setTimeout(resolve, 2000));

    const buttons = await page.$$eval('button', buttons =>
      buttons.map(btn => ({
        text: btn.textContent.trim(),
        id: btn.id,
        className: btn.className,
        onclick: btn.getAttribute('onclick'),
        disabled: btn.disabled
      })).filter(btn => btn.text.length > 0)
    );

    console.log(`🔘 ${buttons.length} boutons trouvés:`);
    buttons.forEach((btn, i) => {
      console.log(`   ${i+1}. "${btn.text}" ${btn.disabled ? '(désactivé)' : ''}`);
    });

    results.functionalities.push({
      name: 'Boutons Interface',
      count: buttons.length,
      buttons: buttons,
      status: 'ANALYZED'
    });

  } catch (funcError) {
    console.log(`❌ Erreur test fonctionnalités: ${funcError.message}`);
    results.errors.push(`Fonctionnalités: ${funcError.message}`);
  }

  // Sauvegarder rapport détaillé
  fs.writeFileSync(
    path.join(screenshotsDir, 'rapport_test_3_apis.json'),
    JSON.stringify(results, null, 2)
  );

  console.log('\n🔗 RÉSUMÉ TEST 3 (APIs & Fonctionnalités):');
  console.log(`📡 APIs testées: ${results.apis.length}`);

  const workingApis = results.apis.filter(api => api.working);
  console.log(`✅ APIs fonctionnelles: ${workingApis.length}/${results.apis.length}`);

  if (workingApis.length > 0) {
    console.log('\n✅ APIs qui fonctionnent:');
    workingApis.forEach(api => {
      console.log(`   • ${api.endpoint} (${api.status}) - ${api.loadTime}ms`);
    });
  }

  const brokenApis = results.apis.filter(api => !api.working);
  if (brokenApis.length > 0) {
    console.log('\n❌ APIs défaillantes:');
    brokenApis.forEach(api => {
      console.log(`   • ${api.endpoint} (${api.status || api.error})`);
    });
  }

  console.log(`🎛️ Fonctionnalités testées: ${results.functionalities.length}`);
  console.log(`❌ Erreurs totales: ${results.errors.length}`);

  await browser.close();
})();