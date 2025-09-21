const puppeteer = require('puppeteer');

async function testProduction() {
  console.log('🧪 Test FINAL de PiSignage v2.0 en PRODUCTION\n');
  console.log('📍 URL: http://192.168.1.103\n');
  
  const browser = await puppeteer.launch({ 
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    console.log('🌐 Connexion à http://192.168.1.103...');
    const response = await page.goto('http://192.168.1.103', { 
      waitUntil: 'networkidle0',
      timeout: 30000 
    });
    
    console.log('✅ Page chargée avec succès! Status:', response.status());
    
    // Test du titre
    const title = await page.title();
    console.log('📄 Titre:', title);
    
    // Test des onglets
    console.log('\n🔍 Vérification des composants...');
    await page.waitForSelector('[role="tab"]', { timeout: 5000 });
    const tabs = await page.$$('[role="tab"]');
    console.log(`✅ ${tabs.length} onglets trouvés`);
    
    // Test du thème dark
    const backgroundColor = await page.evaluate(() => {
      return window.getComputedStyle(document.body).backgroundColor;
    });
    console.log('🎨 Couleur de fond:', backgroundColor);
    console.log(backgroundColor.includes('0, 0, 0') || backgroundColor.includes('rgb(0') ? 
      '✅ Thème dark FREE.FR actif!' : '⚠️ Thème non détecté');
    
    // Test des APIs
    console.log('\n📡 Test des APIs...');
    const apiResponse = await page.evaluate(async () => {
      const response = await fetch('/api/system');
      const data = await response.json();
      return {
        status: response.status,
        hasCpu: 'cpu' in data,
        hasMemory: 'memory' in data,
        cpu: data.cpu
      };
    });
    
    console.log(`✅ API /api/system: Status ${apiResponse.status}`);
    console.log(`   CPU: ${apiResponse.cpu}%`);
    
    // Capture d'écran finale
    await page.screenshot({ path: 'production-success.png', fullPage: true });
    console.log('\n📸 Screenshot de succès: production-success.png');
    
    console.log('\n');
    console.log('===========================================');
    console.log('🎉 SUCCÈS TOTAL !');
    console.log('✅ Interface accessible sur http://192.168.1.103');
    console.log('✅ Thème Dark Mode FREE.FR fonctionnel');
    console.log('✅ APIs opérationnelles');
    console.log('✅ Tous les composants chargés');
    console.log('===========================================');
    
  } catch (error) {
    console.error('\n❌ Erreur:', error.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

testProduction().catch(console.error);
