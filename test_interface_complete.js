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

  // Créer dossier screenshots s'il n'existe pas
  const screenshotsDir = '/opt/pisignage/screenshots';
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const results = {
    timestamp: new Date().toISOString(),
    url: 'http://192.168.1.103/',
    tests: [],
    errors: [],
    apis: []
  };

  console.log('🚀 Test complet PiSignage v0.8.0 - Interface complète');
  console.log('URL:', 'http://192.168.1.103/');

  try {
    // Test 1: Page d'accueil (Dashboard)
    console.log('📊 Test 1: Dashboard...');
    const startTime = Date.now();

    await page.goto('http://192.168.1.103/', {
      waitUntil: 'networkidle2',
      timeout: 10000
    });

    const loadTime = Date.now() - startTime;

    // Attendre que la page soit complètement chargée
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Screenshot dashboard
    await page.screenshot({
      path: path.join(screenshotsDir, '01_dashboard.png'),
      fullPage: true
    });

    // Vérifier titre et éléments
    const title = await page.title();
    const pageContent = await page.content();

    results.tests.push({
      name: 'Dashboard',
      url: 'http://192.168.1.103/',
      loadTime: loadTime,
      title: title,
      screenshot: '01_dashboard.png',
      status: title.includes('PiSignage') ? 'SUCCESS' : 'ERROR'
    });

    console.log(`✅ Dashboard chargé en ${loadTime}ms - Titre: ${title}`);

    // Test 2: Section Médias
    console.log('📁 Test 2: Section Médias...');
    try {
      // Chercher le lien vers médias
      const mediaLinks = await page.$$eval('a, button, [onclick]', elements =>
        elements.filter(el => {
          const text = el.textContent.toLowerCase();
          const href = el.href || el.getAttribute('onclick') || '';
          return text.includes('média') || text.includes('media') ||
                 href.includes('media') || text.includes('fichier');
        }).map(el => ({
          text: el.textContent.trim(),
          href: el.href || el.getAttribute('onclick') || el.getAttribute('data-target'),
          tag: el.tagName
        }))
      );

      console.log('Liens médias trouvés:', mediaLinks);

      if (mediaLinks.length > 0) {
        // Cliquer sur le premier lien média trouvé
        await page.click(mediaLinks[0].href ? `[href="${mediaLinks[0].href}"]` : `[onclick*="media"]`);
        await new Promise(resolve => setTimeout(resolve, 1500));

        await page.screenshot({
          path: path.join(screenshotsDir, '02_medias.png'),
          fullPage: true
        });

        results.tests.push({
          name: 'Médias',
          loadTime: 'Navigation',
          screenshot: '02_medias.png',
          status: 'SUCCESS'
        });

        console.log('✅ Section Médias capturée');
      } else {
        console.log('⚠️ Aucun lien médias trouvé');
        results.tests.push({
          name: 'Médias',
          status: 'NOT_FOUND'
        });
      }
    } catch (error) {
      console.log('❌ Erreur section Médias:', error.message);
      results.errors.push(`Médias: ${error.message}`);
    }

    // Test 3: Section Playlists
    console.log('🎵 Test 3: Section Playlists...');
    try {
      await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 1000));

      const playlistLinks = await page.$$eval('a, button, [onclick]', elements =>
        elements.filter(el => {
          const text = el.textContent.toLowerCase();
          return text.includes('playlist') || text.includes('liste');
        }).map(el => ({
          text: el.textContent.trim(),
          href: el.href || el.getAttribute('onclick')
        }))
      );

      if (playlistLinks.length > 0) {
        await page.evaluate((selector) => {
          const element = document.querySelector(selector);
          if (element) element.click();
        }, playlistLinks[0].href ? `[href="${playlistLinks[0].href}"]` : `[onclick*="playlist"]`);

        await new Promise(resolve => setTimeout(resolve, 1500));

        await page.screenshot({
          path: path.join(screenshotsDir, '03_playlists.png'),
          fullPage: true
        });

        results.tests.push({
          name: 'Playlists',
          screenshot: '03_playlists.png',
          status: 'SUCCESS'
        });

        console.log('✅ Section Playlists capturée');
      } else {
        console.log('⚠️ Section Playlists non trouvée');
      }
    } catch (error) {
      console.log('❌ Erreur Playlists:', error.message);
      results.errors.push(`Playlists: ${error.message}`);
    }

    // Test 4: Section YouTube
    console.log('📺 Test 4: Section YouTube...');
    try {
      await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 1000));

      const youtubeLinks = await page.$$eval('a, button, [onclick]', elements =>
        elements.filter(el => {
          const text = el.textContent.toLowerCase();
          return text.includes('youtube') || text.includes('video');
        })
      );

      if (youtubeLinks.length > 0) {
        await youtubeLinks[0].click();
        await new Promise(resolve => setTimeout(resolve, 1500));

        await page.screenshot({
          path: path.join(screenshotsDir, '04_youtube.png'),
          fullPage: true
        });

        results.tests.push({
          name: 'YouTube',
          screenshot: '04_youtube.png',
          status: 'SUCCESS'
        });

        console.log('✅ Section YouTube capturée');
      }
    } catch (error) {
      console.log('❌ Erreur YouTube:', error.message);
      results.errors.push(`YouTube: ${error.message}`);
    }

    // Test 5: Section Lecteur
    console.log('▶️ Test 5: Section Lecteur...');
    try {
      await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 1000));

      const playerLinks = await page.$$eval('a, button, [onclick]', elements =>
        elements.filter(el => {
          const text = el.textContent.toLowerCase();
          return text.includes('lecteur') || text.includes('player') || text.includes('lecture');
        })
      );

      if (playerLinks.length > 0) {
        await playerLinks[0].click();
        await new Promise(resolve => setTimeout(resolve, 1500));

        await page.screenshot({
          path: path.join(screenshotsDir, '05_lecteur.png'),
          fullPage: true
        });

        results.tests.push({
          name: 'Lecteur',
          screenshot: '05_lecteur.png',
          status: 'SUCCESS'
        });

        console.log('✅ Section Lecteur capturée');
      }
    } catch (error) {
      console.log('❌ Erreur Lecteur:', error.message);
      results.errors.push(`Lecteur: ${error.message}`);
    }

    // Test 6: Section Paramètres
    console.log('⚙️ Test 6: Section Paramètres...');
    try {
      await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 1000));

      const settingsLinks = await page.$$eval('a, button, [onclick]', elements =>
        elements.filter(el => {
          const text = el.textContent.toLowerCase();
          return text.includes('paramètre') || text.includes('setting') || text.includes('config');
        })
      );

      if (settingsLinks.length > 0) {
        await settingsLinks[0].click();
        await new Promise(resolve => setTimeout(resolve, 1500));

        await page.screenshot({
          path: path.join(screenshotsDir, '06_parametres.png'),
          fullPage: true
        });

        results.tests.push({
          name: 'Paramètres',
          screenshot: '06_parametres.png',
          status: 'SUCCESS'
        });

        console.log('✅ Section Paramètres capturée');
      }
    } catch (error) {
      console.log('❌ Erreur Paramètres:', error.message);
      results.errors.push(`Paramètres: ${error.message}`);
    }

    // Test des APIs
    console.log('🔗 Test des APIs...');
    const apis = [
      '/api/system.php',
      '/api/player.php',
      '/api/playlist.php',
      '/api/media.php'
    ];

    for (const api of apis) {
      try {
        const response = await page.goto(`http://192.168.1.103${api}`, {
          waitUntil: 'networkidle2',
          timeout: 5000
        });

        const status = response.status();
        const content = await page.content();

        results.apis.push({
          endpoint: api,
          status: status,
          working: status === 200,
          contentLength: content.length
        });

        console.log(`📡 ${api}: ${status === 200 ? '✅' : '❌'} (${status})`);
      } catch (error) {
        results.apis.push({
          endpoint: api,
          status: 'ERROR',
          working: false,
          error: error.message
        });
        console.log(`📡 ${api}: ❌ ${error.message}`);
      }
    }

  } catch (error) {
    console.error('❌ Erreur globale:', error);
    results.errors.push(`Global: ${error.message}`);
  }

  // Sauvegarder rapport
  fs.writeFileSync(
    path.join(screenshotsDir, 'rapport_test_1.json'),
    JSON.stringify(results, null, 2)
  );

  console.log('\n📊 RÉSUMÉ TEST 1:');
  console.log(`✅ Tests réussis: ${results.tests.filter(t => t.status === 'SUCCESS').length}`);
  console.log(`❌ Erreurs: ${results.errors.length}`);
  console.log(`📡 APIs fonctionnelles: ${results.apis.filter(a => a.working).length}/${results.apis.length}`);
  console.log(`📸 Screenshots sauvés dans: ${screenshotsDir}`);

  await browser.close();
})();