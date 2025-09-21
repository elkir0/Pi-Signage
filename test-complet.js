const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function testComplete() {
  console.log('🔍 === DÉBUT DU TEST COMPLET PISIGNAGE ===\n');
  
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();
    
    // Capture des erreurs console
    const consoleErrors = [];
    const consoleWarnings = [];
    const consoleLogs = [];
    
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      
      if (type === 'error') {
        consoleErrors.push(text);
        console.log(`❌ ERREUR Console: ${text}`);
      } else if (type === 'warning') {
        consoleWarnings.push(text);
        console.log(`⚠️  WARNING Console: ${text}`);
      } else {
        consoleLogs.push(text);
      }
    });

    page.on('pageerror', error => {
      consoleErrors.push(error.toString());
      console.log(`💥 ERREUR Page: ${error}`);
    });

    // Test de la page principale
    console.log('\n📡 Chargement de http://192.168.1.103...');
    const response = await page.goto('http://192.168.1.103', {
      waitUntil: 'networkidle2',
      timeout: 30000
    });

    console.log(`✅ Page chargée: Status ${response.status()}\n`);

    // Attendre que le contenu soit chargé
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Prendre un screenshot
    const screenshotPath = path.join(__dirname, 'test-screenshot.png');
    await page.screenshot({ 
      path: screenshotPath,
      fullPage: true 
    });
    console.log(`📸 Screenshot sauvegardé: ${screenshotPath}\n`);

    // Analyser le style
    console.log('🎨 === ANALYSE DU STYLE ===');
    
    const styleAnalysis = await page.evaluate(() => {
      const body = document.body;
      const bodyStyle = window.getComputedStyle(body);
      
      // Chercher les éléments avec bordure rouge
      const redBorderElements = document.querySelectorAll('[class*="border-red"]');
      
      // Chercher le logo
      const logos = document.querySelectorAll('img[src*="logo"], img[src*="Pi"], img[alt*="Pi"]');
      
      // Analyser le fond
      const bgColor = bodyStyle.backgroundColor;
      const textColor = bodyStyle.color;
      
      // Chercher les tabs
      const tabs = document.querySelectorAll('[role="tablist"]');
      
      return {
        backgroundColor: bgColor,
        textColor: textColor,
        hasBlackBg: bgColor === 'rgb(0, 0, 0)' || bgColor === 'black',
        hasWhiteText: textColor === 'rgb(255, 255, 255)' || textColor === 'white',
        redBorderCount: redBorderElements.length,
        logoCount: logos.length,
        tabsCount: tabs.length,
        title: document.title,
        // Analyse plus détaillée
        mainContent: document.querySelector('main') ? 'présent' : 'absent',
        darkModeApplied: document.body.classList.contains('dark') || 
                         document.documentElement.classList.contains('dark')
      };
    });

    console.log(`🖤 Fond noir: ${styleAnalysis.hasBlackBg ? '✅' : '❌'} (${styleAnalysis.backgroundColor})`);
    console.log(`⚪ Texte blanc: ${styleAnalysis.hasWhiteText ? '✅' : '❌'} (${styleAnalysis.textColor})`);
    console.log(`🔴 Éléments avec bordure rouge: ${styleAnalysis.redBorderCount}`);
    console.log(`🖼️  Logos trouvés: ${styleAnalysis.logoCount}`);
    console.log(`📑 Tabs trouvés: ${styleAnalysis.tabsCount}`);
    console.log(`🌙 Dark mode actif: ${styleAnalysis.darkModeApplied ? '✅' : '❌'}`);
    console.log(`📄 Titre: ${styleAnalysis.title}`);
    console.log(`📦 Main content: ${styleAnalysis.mainContent}`);

    // Test des APIs
    console.log('\n🔌 === TEST DES APIs ===');
    
    const apis = [
      '/api/system',
      '/api/system/screenshot',
      '/api/media',
      '/api/playlist',
      '/api/settings'
    ];

    for (const api of apis) {
      try {
        const apiResponse = await page.evaluate(async (apiPath) => {
          const res = await fetch(apiPath, {
            method: apiPath.includes('screenshot') ? 'POST' : 'GET',
            headers: { 'Content-Type': 'application/json' },
            body: apiPath.includes('screenshot') ? JSON.stringify({}) : undefined
          });
          return {
            status: res.status,
            ok: res.ok,
            statusText: res.statusText
          };
        }, api);
        
        console.log(`${apiResponse.ok ? '✅' : '❌'} ${api}: ${apiResponse.status} ${apiResponse.statusText}`);
      } catch (error) {
        console.log(`❌ ${api}: Erreur - ${error.message}`);
      }
    }

    // Résumé final
    console.log('\n📊 === RÉSUMÉ DU TEST ===');
    console.log(`Erreurs console: ${consoleErrors.length}`);
    console.log(`Warnings console: ${consoleWarnings.length}`);
    
    const problems = [];
    
    if (!styleAnalysis.hasBlackBg) problems.push('Fond pas noir');
    if (!styleAnalysis.hasWhiteText) problems.push('Texte pas blanc');
    if (styleAnalysis.redBorderCount === 0) problems.push('Aucune bordure rouge');
    if (styleAnalysis.logoCount === 0) problems.push('Logo manquant');
    if (consoleErrors.length > 0) problems.push(`${consoleErrors.length} erreurs console`);
    if (consoleWarnings.length > 0) problems.push(`${consoleWarnings.length} warnings`);

    if (problems.length === 0) {
      console.log('\n✅ TOUS LES TESTS PASSENT!');
    } else {
      console.log('\n❌ PROBLÈMES DÉTECTÉS:');
      problems.forEach(p => console.log(`  - ${p}`));
    }

    // Afficher les erreurs console détaillées
    if (consoleErrors.length > 0) {
      console.log('\n🔴 DÉTAIL DES ERREURS:');
      consoleErrors.forEach(e => console.log(`  ${e}`));
    }

    if (consoleWarnings.length > 0) {
      console.log('\n⚠️  DÉTAIL DES WARNINGS:');
      consoleWarnings.forEach(w => console.log(`  ${w}`));
    }

  } catch (error) {
    console.error('💥 Erreur pendant le test:', error);
  } finally {
    await browser.close();
  }

  console.log('\n🏁 === FIN DU TEST ===');
}

// Lancer le test
testComplete().catch(console.error);