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
    url: 'http://192.168.1.103/',
    consoleMessages: [],
    networkErrors: [],
    jsErrors: [],
    performance: {},
    pageAnalysis: {}
  };

  console.log('🔍 Test 2: Console Debug et Erreurs JavaScript');
  console.log('URL:', 'http://192.168.1.103/');

  // Capturer tous les messages de console
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    console.log(`📜 Console ${type.toUpperCase()}: ${text}`);
    results.consoleMessages.push({
      type: type,
      text: text,
      timestamp: new Date().toISOString()
    });
  });

  // Capturer les erreurs JavaScript
  page.on('pageerror', error => {
    console.log(`❌ JS Error: ${error.message}`);
    results.jsErrors.push({
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
  });

  // Capturer les erreurs réseau
  page.on('response', response => {
    if (response.status() >= 400) {
      console.log(`🌐 Network Error: ${response.status()} - ${response.url()}`);
      results.networkErrors.push({
        status: response.status(),
        url: response.url(),
        statusText: response.statusText(),
        timestamp: new Date().toISOString()
      });
    }
  });

  try {
    console.log('🚀 Chargement de la page avec monitoring console...');

    const startTime = Date.now();
    await page.goto('http://192.168.1.103/', {
      waitUntil: 'networkidle2',
      timeout: 15000
    });
    const loadTime = Date.now() - startTime;

    // Attendre le chargement complet
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Analyse des performances
    const metrics = await page.metrics();
    results.performance = {
      loadTime: loadTime,
      jsHeapUsedSize: metrics.JSHeapUsedSize,
      jsHeapTotalSize: metrics.JSHeapTotalSize,
      nodes: metrics.Nodes,
      documents: metrics.Documents,
      frames: metrics.Frames,
      eventListeners: metrics.JSEventListeners
    };

    console.log(`⏱️ Temps de chargement: ${loadTime}ms`);
    console.log(`🧠 Mémoire JS: ${Math.round(metrics.JSHeapUsedSize / 1024 / 1024 * 100) / 100}MB`);

    // Analyse de la page
    const pageAnalysis = await page.evaluate(() => {
      const analysis = {
        title: document.title,
        url: window.location.href,
        elementCounts: {
          totalElements: document.querySelectorAll('*').length,
          images: document.querySelectorAll('img').length,
          links: document.querySelectorAll('a').length,
          buttons: document.querySelectorAll('button').length,
          forms: document.querySelectorAll('form').length,
          scripts: document.querySelectorAll('script').length,
          divs: document.querySelectorAll('div').length
        },
        classes: [],
        ids: [],
        texts: []
      };

      // Récupérer les classes CSS utilisées
      const elements = document.querySelectorAll('[class]');
      const classSet = new Set();
      elements.forEach(el => {
        el.className.split(' ').forEach(cls => {
          if (cls.trim()) classSet.add(cls.trim());
        });
      });
      analysis.classes = Array.from(classSet).slice(0, 20); // Premiers 20

      // Récupérer les IDs
      const idElements = document.querySelectorAll('[id]');
      analysis.ids = Array.from(idElements).map(el => el.id).slice(0, 20);

      // Récupérer les textes visibles principales
      const visibleTexts = [];
      const textElements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, div, a, button');
      textElements.forEach(el => {
        const text = el.textContent.trim();
        if (text && text.length > 3 && text.length < 100) {
          visibleTexts.push(text);
        }
      });
      analysis.texts = visibleTexts.slice(0, 30);

      return analysis;
    });

    results.pageAnalysis = pageAnalysis;

    console.log(`📊 Éléments sur la page: ${pageAnalysis.elementCounts.totalElements}`);
    console.log(`🔗 Liens: ${pageAnalysis.elementCounts.links}`);
    console.log(`🖲️ Boutons: ${pageAnalysis.elementCounts.buttons}`);

    // Test interactif : cliquer sur des éléments et observer
    console.log('🖱️ Test des interactions...');

    try {
      // Tenter de cliquer sur les principaux liens/boutons
      const clickableElements = await page.$$eval('a, button, [onclick]', elements => {
        return elements.map((el, index) => ({
          index: index,
          tag: el.tagName,
          text: el.textContent.trim().substring(0, 50),
          href: el.href || null,
          onclick: el.getAttribute('onclick') || null,
          id: el.id || null,
          className: el.className || null
        })).slice(0, 10); // Premiers 10 éléments
      });

      console.log(`🎯 ${clickableElements.length} éléments cliquables trouvés`);
      clickableElements.forEach((el, i) => {
        console.log(`   ${i+1}. ${el.tag}: "${el.text}" ${el.href ? `(${el.href})` : ''}`);
      });

      // Tester quelques clics
      for (let i = 0; i < Math.min(3, clickableElements.length); i++) {
        try {
          const element = clickableElements[i];
          console.log(`🖱️ Test clic ${i+1}: ${element.text}`);

          if (element.id) {
            await page.click(`#${element.id}`);
          } else if (element.className) {
            await page.click(`.${element.className.split(' ')[0]}`);
          } else {
            await page.click(`${element.tag.toLowerCase()}:nth-child(${i+1})`);
          }

          await new Promise(resolve => setTimeout(resolve, 1000));

        } catch (clickError) {
          console.log(`❌ Erreur clic ${i+1}: ${clickError.message}`);
        }
      }

    } catch (interactError) {
      console.log(`❌ Erreur interactions: ${interactError.message}`);
    }

    // Screenshot final avec état après interactions
    await page.screenshot({
      path: path.join(screenshotsDir, '07_debug_final.png'),
      fullPage: true
    });

    console.log('📸 Screenshot debug sauvé: 07_debug_final.png');

  } catch (error) {
    console.error('❌ Erreur dans le test debug:', error);
    results.jsErrors.push({
      message: `Test Error: ${error.message}`,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
  }

  // Sauvegarder le rapport détaillé
  fs.writeFileSync(
    path.join(screenshotsDir, 'rapport_test_2_debug.json'),
    JSON.stringify(results, null, 2)
  );

  console.log('\n🔍 RÉSUMÉ TEST 2 (Console Debug):');
  console.log(`📜 Messages console: ${results.consoleMessages.length}`);
  console.log(`❌ Erreurs JS: ${results.jsErrors.length}`);
  console.log(`🌐 Erreurs réseau: ${results.networkErrors.length}`);
  console.log(`⏱️ Performance: ${results.performance.loadTime}ms`);
  console.log(`📊 Éléments analysés: ${results.pageAnalysis.elementCounts?.totalElements || 0}`);

  if (results.consoleMessages.length > 0) {
    console.log('\n📜 Messages console détaillés:');
    results.consoleMessages.forEach((msg, i) => {
      console.log(`   ${i+1}. [${msg.type}] ${msg.text}`);
    });
  }

  if (results.jsErrors.length > 0) {
    console.log('\n❌ Erreurs JavaScript:');
    results.jsErrors.forEach((err, i) => {
      console.log(`   ${i+1}. ${err.message}`);
    });
  }

  await browser.close();
})();