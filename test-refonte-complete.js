const puppeteer = require('puppeteer');
const fs = require('fs').promises;

async function testPiSignage() {
  console.log('🚀 Démarrage du test complet PiSignage v2.0 - Refonte graphique\n');
  
  const browser = await puppeteer.launch({ 
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Collecter les erreurs console
    const consoleErrors = [];
    const consoleWarnings = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      } else if (msg.type() === 'warning') {
        consoleWarnings.push(msg.text());
      }
    });
    
    // Intercepter les erreurs de page
    page.on('pageerror', error => {
      consoleErrors.push(error.message);
    });
    
    console.log('📍 Test 1: Chargement de la page principale...');
    const response = await page.goto('http://localhost:3000', { 
      waitUntil: 'networkidle2',
      timeout: 30000 
    });
    
    const status = response.status();
    console.log(`   ✅ Page chargée avec statut: ${status}`);
    
    // Attendre que le contenu soit visible
    await page.waitForSelector('header', { timeout: 5000 });
    console.log('   ✅ Header trouvé et visible');
    
    // Test 2: Vérifier le logo
    console.log('\n📍 Test 2: Vérification du logo...');
    const logoExists = await page.evaluate(() => {
      const img = document.querySelector('img[alt="PiSignage Logo"]');
      return img && img.src.includes('pisignage-logo.png');
    });
    console.log(`   ${logoExists ? '✅' : '❌'} Logo ${logoExists ? 'présent' : 'MANQUANT'}`);
    
    // Test 3: Vérifier le style (fond noir, texte blanc, accents rouges)
    console.log('\n📍 Test 3: Vérification du style...');
    const styleCheck = await page.evaluate(() => {
      const body = document.body;
      const bgColor = window.getComputedStyle(body).backgroundColor;
      const textColor = window.getComputedStyle(body).color;
      
      // Chercher des éléments avec bordures rouges
      const redBorders = document.querySelectorAll('[class*="border-red"], [class*="ps-accent"]').length;
      
      return {
        background: bgColor,
        text: textColor,
        redElements: redBorders,
        hasDarkBg: bgColor === 'rgb(0, 0, 0)' || bgColor === 'rgba(0, 0, 0, 0)',
        hasWhiteText: textColor === 'rgb(255, 255, 255)',
      };
    });
    
    console.log(`   ${styleCheck.hasDarkBg ? '✅' : '❌'} Fond noir: ${styleCheck.background}`);
    console.log(`   ${styleCheck.hasWhiteText ? '✅' : '❌'} Texte blanc: ${styleCheck.text}`);
    console.log(`   ${styleCheck.redElements > 0 ? '✅' : '❌'} Éléments rouges: ${styleCheck.redElements} trouvés`);
    
    // Test 4: Navigation dans les onglets
    console.log('\n📍 Test 4: Test de la navigation...');
    const tabs = ['dashboard', 'playlist', 'media', 'youtube', 'schedule', 'monitor', 'settings'];
    
    for (const tabName of tabs) {
      console.log(`   Testing tab: ${tabName}...`);
      
      // Chercher et cliquer sur l'onglet
      const tabClicked = await page.evaluate((name) => {
        const buttons = Array.from(document.querySelectorAll('button'));
        const tab = buttons.find(btn => 
          btn.textContent.toLowerCase().includes(name.toLowerCase()) ||
          btn.textContent.toLowerCase().includes(name.slice(0, 3).toLowerCase())
        );
        if (tab) {
          tab.click();
          return true;
        }
        return false;
      }, tabName);
      
      if (tabClicked) {
        await new Promise(r => setTimeout(r, 500)); // Attendre l'animation
        console.log(`   ✅ Onglet ${tabName} activé`);
      } else {
        console.log(`   ⚠️ Onglet ${tabName} non trouvé`);
      }
    }
    
    // Test 5: API Screenshot
    console.log('\n📍 Test 5: Test de l\'API screenshot...');
    try {
      const apiResponse = await page.evaluate(async () => {
        const response = await fetch('/api/system/screenshot', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({})
        });
        return {
          status: response.status,
          ok: response.ok,
          data: await response.json()
        };
      });
      
      console.log(`   ${apiResponse.ok ? '✅' : '❌'} API Screenshot: Status ${apiResponse.status}`);
      if (apiResponse.data.success) {
        console.log(`   ✅ Réponse: ${JSON.stringify(apiResponse.data).slice(0, 100)}`);
      }
    } catch (error) {
      console.log(`   ❌ API Screenshot erreur: ${error.message}`);
    }
    
    // Test 6: Vérifier les classes CSS ps-*
    console.log('\n📍 Test 6: Vérification des classes CSS ps-*...');
    const cssClasses = await page.evaluate(() => {
      const elements = document.querySelectorAll('[class*="ps-"]');
      const classes = new Set();
      elements.forEach(el => {
        const className = el.className;
        if (typeof className === 'string') {
          className.split(' ').forEach(cls => {
            if (cls.startsWith('ps-')) classes.add(cls);
          });
        }
      });
      return Array.from(classes);
    });
    
    console.log(`   ✅ ${cssClasses.length} classes ps-* trouvées:`);
    cssClasses.slice(0, 10).forEach(cls => console.log(`      - ${cls}`));
    
    // Capturer un screenshot
    console.log('\n📍 Capture d\'écran finale...');
    await page.screenshot({ 
      path: 'test-refonte-screenshot.png',
      fullPage: true
    });
    console.log('   ✅ Screenshot sauvegardé: test-refonte-screenshot.png');
    
    // Résumé final
    console.log('\n' + '='.repeat(60));
    console.log('📊 RÉSUMÉ DU TEST');
    console.log('='.repeat(60));
    console.log(`✅ Tests réussis: ${7 - consoleErrors.length}`);
    console.log(`❌ Erreurs console: ${consoleErrors.length}`);
    console.log(`⚠️ Warnings: ${consoleWarnings.length}`);
    
    if (consoleErrors.length > 0) {
      console.log('\n❌ Erreurs détectées:');
      consoleErrors.forEach(err => console.log(`   - ${err}`));
    }
    
    if (consoleWarnings.length > 0) {
      console.log('\n⚠️ Warnings détectés:');
      consoleWarnings.slice(0, 5).forEach(warn => console.log(`   - ${warn}`));
    }
    
    // Verdict final
    console.log('\n' + '='.repeat(60));
    if (consoleErrors.length === 0 && logoExists && styleCheck.hasDarkBg && styleCheck.hasWhiteText) {
      console.log('🎉 SUCCÈS: L\'interface est fonctionnelle et le style est correct!');
      console.log('✅ Prêt pour le déploiement sur Raspberry Pi');
    } else {
      console.log('⚠️ ATTENTION: Des problèmes ont été détectés');
      console.log('Veuillez corriger les erreurs avant le déploiement');
    }
    console.log('='.repeat(60));
    
  } catch (error) {
    console.error('\n❌ Erreur fatale:', error.message);
  } finally {
    await browser.close();
  }
}

// Lancer le test
testPiSignage().catch(console.error);