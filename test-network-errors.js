const puppeteer = require('puppeteer');

async function captureNetworkErrors() {
  console.log('🔍 === CAPTURE DES ERREURS RÉSEAU ===\n');
  
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();
    
    const failedRequests = [];
    const consoleErrors = [];
    
    // Capturer toutes les requêtes réseau
    page.on('requestfailed', request => {
      const failure = {
        url: request.url(),
        method: request.method(),
        resourceType: request.resourceType(),
        errorText: request.failure()?.errorText || 'Unknown error'
      };
      failedRequests.push(failure);
      console.log(`❌ Failed: ${failure.url}`);
    });
    
    // Capturer les réponses avec erreur HTTP
    page.on('response', response => {
      if (response.status() >= 400) {
        console.log(`⚠️  HTTP ${response.status()}: ${response.url()}`);
      }
    });
    
    // Capturer les erreurs console
    page.on('console', msg => {
      if (msg.type() === 'error') {
        const text = msg.text();
        consoleErrors.push(text);
        console.log(`🔴 Console Error: ${text.substring(0, 100)}`);
      }
    });
    
    page.on('pageerror', error => {
      console.log(`💥 Page Error: ${error}`);
    });

    // Charger la page
    console.log('\n📡 Chargement de http://192.168.1.103...\n');
    await page.goto('http://192.168.1.103', {
      waitUntil: 'networkidle0',
      timeout: 30000
    });
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Tester chaque onglet pour capturer toutes les erreurs
    const tabs = ['Playlists', 'Médias', 'YouTube', 'Programmation', 'Monitoring', 'Paramètres'];
    
    for (const tabName of tabs) {
      console.log(`\n🔄 Test onglet ${tabName}...`);
      
      const clicked = await page.evaluate((name) => {
        const buttons = Array.from(document.querySelectorAll('button'));
        const button = buttons.find(btn => btn.textContent.trim() === name);
        if (button) {
          button.click();
          return true;
        }
        return false;
      }, tabName);
      
      if (clicked) {
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }
    
    // Résumé des erreurs
    console.log('\n\n📊 === RÉSUMÉ DES ERREURS ===\n');
    
    if (failedRequests.length > 0) {
      console.log('🔴 Requêtes échouées:');
      const uniqueUrls = [...new Set(failedRequests.map(r => r.url))];
      uniqueUrls.forEach(url => {
        console.log(`   - ${url}`);
      });
    }
    
    if (consoleErrors.length > 0) {
      console.log('\n🔴 Erreurs console uniques:');
      const uniqueErrors = [...new Set(consoleErrors)];
      uniqueErrors.forEach(err => {
        console.log(`   - ${err.substring(0, 150)}`);
      });
    }
    
  } catch (error) {
    console.error('💥 Erreur:', error);
  } finally {
    await browser.close();
  }
}

captureNetworkErrors().catch(console.error);