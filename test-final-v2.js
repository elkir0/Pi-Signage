const puppeteer = require('puppeteer');
const fs = require('fs').promises;

async function finalTest() {
  console.log('🔍 === TEST FINAL APRÈS CORRECTIONS ===\n');
  
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    const errors = [];
    const warnings = [];
    
    // Capture des erreurs console
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      
      if (type === 'error') {
        errors.push(text);
        console.log(`❌ Error: ${text.substring(0, 80)}`);
      } else if (type === 'warning') {
        warnings.push(text);
        console.log(`⚠️  Warning: ${text.substring(0, 80)}`);
      }
    });
    
    page.on('pageerror', error => {
      errors.push(error.toString());
      console.log(`💥 Page Error: ${error}`);
    });
    
    // Capturer les réponses HTTP
    const httpErrors = [];
    page.on('response', response => {
      if (response.status() >= 400) {
        const url = response.url();
        httpErrors.push({status: response.status(), url});
        console.log(`⚠️  HTTP ${response.status()}: ${url.substring(url.lastIndexOf('/'))}`);
      }
    });

    // Charger la page avec timeout étendu
    console.log('\n📡 Chargement de http://192.168.1.103 (timeout: 60s)...\n');
    const start = Date.now();
    
    try {
      const response = await page.goto('http://192.168.1.103', {
        waitUntil: 'networkidle2',
        timeout: 60000
      });
      
      const loadTime = ((Date.now() - start) / 1000).toFixed(1);
      console.log(`✅ Page chargée en ${loadTime}s - Status: ${response.status()}\n`);
    } catch (error) {
      console.log(`❌ Erreur de chargement: ${error.message}\n`);
      return;
    }
    
    // Attendre le chargement complet
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Prendre un screenshot
    await fs.mkdir('screenshots-final', { recursive: true });
    await page.screenshot({ 
      path: 'screenshots-final/home.png',
      fullPage: true 
    });
    console.log(`📸 Screenshot: screenshots-final/home.png\n`);
    
    // Analyser la page
    console.log('📊 === ANALYSE DE LA PAGE ===\n');
    
    const analysis = await page.evaluate(() => {
      const body = document.body;
      const style = window.getComputedStyle(body);
      const favicon = document.querySelector('link[rel="icon"]');
      const logo = document.querySelector('img[alt*="PiSignage"], img[src*="logo"]');
      const tabs = document.querySelectorAll('button').length;
      
      return {
        theme: {
          bgColor: style.backgroundColor,
          textColor: style.color,
          isDark: style.backgroundColor === 'rgb(0, 0, 0)'
        },
        favicon: !!favicon,
        logo: !!logo,
        tabCount: tabs,
        title: document.title
      };
    });
    
    console.log(`🎨 Thème Dark: ${analysis.theme.isDark ? '✅' : '❌'} (${analysis.theme.bgColor})`);
    console.log(`📝 Texte: ${analysis.theme.textColor}`);
    console.log(`🎯 Favicon: ${analysis.favicon ? '✅' : '❌'}`);
    console.log(`🖼️  Logo: ${analysis.logo ? '✅' : '❌'}`);
    console.log(`📑 Onglets: ${analysis.tabCount}`);
    console.log(`📄 Titre: ${analysis.title}\n`);
    
    // Test de l'onglet Settings
    console.log('📌 === TEST ONGLET SETTINGS ===\n');
    
    const settingsClicked = await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const settingsBtn = buttons.find(btn => btn.textContent.includes('Paramètres'));
      if (settingsBtn) {
        settingsBtn.click();
        return true;
      }
      return false;
    });
    
    if (settingsClicked) {
      console.log('✅ Clic sur Paramètres effectué');
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      // Vérifier si Settings fonctionne sans crash
      const settingsOK = await page.evaluate(() => {
        const content = document.querySelector('main');
        const hasError = document.body.textContent.includes('Cannot read properties of undefined');
        return {
          hasContent: !!content && content.textContent.length > 100,
          hasError
        };
      });
      
      if (settingsOK.hasError) {
        console.log('❌ ERREUR: Settings crash (undefined resolution)');
      } else if (settingsOK.hasContent) {
        console.log('✅ Settings fonctionne sans erreur');
      }
      
      await page.screenshot({ 
        path: 'screenshots-final/settings.png',
        fullPage: true 
      });
      console.log('📸 Screenshot: screenshots-final/settings.png\n');
    }
    
    // Test de l'onglet Monitoring  
    console.log('📌 === TEST ONGLET MONITORING ===\n');
    
    const monitoringClicked = await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const monBtn = buttons.find(btn => btn.textContent.includes('Monitoring'));
      if (monBtn) {
        monBtn.click();
        return true;
      }
      return false;
    });
    
    if (monitoringClicked) {
      console.log('✅ Clic sur Monitoring effectué');
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      await page.screenshot({ 
        path: 'screenshots-final/monitoring.png',
        fullPage: true 
      });
      console.log('📸 Screenshot: screenshots-final/monitoring.png\n');
    }
    
    // RÉSUMÉ FINAL
    console.log('\n📊 === RÉSUMÉ FINAL ===\n');
    
    const uniqueHttpErrors = {};
    httpErrors.forEach(e => {
      const key = `${e.status} ${e.url.substring(e.url.lastIndexOf('/'))}`;
      uniqueHttpErrors[key] = (uniqueHttpErrors[key] || 0) + 1;
    });
    
    console.log(`Total erreurs console: ${errors.length}`);
    console.log(`Total warnings: ${warnings.length}`);
    console.log(`Total erreurs HTTP: ${httpErrors.length}`);
    
    if (Object.keys(uniqueHttpErrors).length > 0) {
      console.log('\n🔴 Erreurs HTTP:');
      Object.entries(uniqueHttpErrors).forEach(([err, count]) => {
        console.log(`  - ${err} (${count}x)`);
      });
    }
    
    // Erreurs uniques console
    const uniqueErrors = [...new Set(errors)];
    if (uniqueErrors.length > 0) {
      console.log('\n🔴 Erreurs console:');
      uniqueErrors.forEach(err => {
        console.log(`  - ${err.substring(0, 100)}`);
      });
    }
    
    // VERDICT
    console.log('\n🏁 === VERDICT ===\n');
    
    const issues = [];
    if (!analysis.theme.isDark) issues.push('Thème dark non appliqué');
    if (!analysis.favicon) issues.push('Favicon manquant');
    if (!analysis.logo) issues.push('Logo manquant');
    if (errors.length > 5) issues.push(`Trop d'erreurs console (${errors.length})`);
    if (httpErrors.length > 5) issues.push(`Trop d'erreurs HTTP (${httpErrors.length})`);
    
    if (issues.length === 0) {
      console.log('✅ INTERFACE FONCTIONNELLE - Toutes les corrections appliquées!');
    } else {
      console.log('⚠️  PROBLÈMES RESTANTS:');
      issues.forEach(issue => console.log(`  - ${issue}`));
    }
    
  } catch (error) {
    console.error('💥 Erreur fatale:', error);
  } finally {
    await browser.close();
  }
  
  console.log('\n✅ Test terminé\n');
}

// Lancer le test
finalTest().catch(console.error);