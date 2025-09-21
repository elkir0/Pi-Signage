const puppeteer = require('puppeteer');

async function testPiSignage() {
  console.log('🧪 Test de l\'interface PiSignage v2.0...\n');
  
  const browser = await puppeteer.launch({ 
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  try {
    const page = await browser.newPage();
    
    // Set viewport
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Enable console logs
    page.on('console', msg => {
      const type = msg.type();
      if (type === 'error') {
        console.log('❌ Console Error:', msg.text());
      }
    });
    
    // Catch page errors
    page.on('pageerror', error => {
      console.log('❌ Page Error:', error.message);
    });
    
    console.log('📡 Connexion à http://localhost:3001...');
    
    // Navigate to the page
    const response = await page.goto('http://localhost:3001', { 
      waitUntil: 'networkidle0',
      timeout: 30000 
    });
    
    console.log('✅ Page chargée, status:', response.status());
    
    // Check if page loads without errors
    const title = await page.title();
    console.log('📄 Titre de la page:', title);
    
    // Test 1: Check if tabs are present
    console.log('\n🔍 Test 1: Vérification des onglets...');
    const tabs = await page.$$('[role="tab"]');
    console.log(`  ✅ ${tabs.length} onglets trouvés`);
    
    // Get tab names
    const tabNames = await page.evaluate(() => {
      return Array.from(document.querySelectorAll('[role="tab"]')).map(tab => tab.textContent);
    });
    console.log('  📋 Onglets:', tabNames.join(', '));
    
    // Test 2: Check Dashboard is active by default
    console.log('\n🔍 Test 2: Vérification du Dashboard...');
    const dashboardActive = await page.evaluate(() => {
      const activeTab = document.querySelector('[role="tab"][data-state="active"]');
      return activeTab?.textContent?.includes('Dashboard');
    });
    console.log(`  ${dashboardActive ? '✅' : '❌'} Dashboard actif par défaut`);
    
    // Test 3: Check system info loads
    console.log('\n🔍 Test 3: Vérification des données système...');
    
    // Wait for system data to load
    await page.waitForTimeout(3000);
    
    // Check if CPU percentage is displayed correctly
    const cpuElement = await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll('*'));
      const cpuEl = elements.find(el => el.textContent?.includes('CPU'));
      const parent = cpuEl?.parentElement?.parentElement;
      return parent?.textContent;
    });
    console.log(`  📊 Info CPU: ${cpuElement || 'Non trouvé'}`);
    
    // Test 4: Click on Media tab
    console.log('\n🔍 Test 4: Navigation vers l\'onglet Médias...');
    const mediaTab = await page.$('[role="tab"]:nth-child(3)');
    if (mediaTab) {
      await mediaTab.click();
      await page.waitForTimeout(1000);
      console.log('  ✅ Onglet Médias cliqué');
      
      // Check if media content is displayed
      const hasDropzone = await page.evaluate(() => {
        return document.body.textContent?.includes('glisser') || 
               document.body.textContent?.includes('Drag') ||
               document.body.textContent?.includes('drop');
      });
      console.log(`  ${hasDropzone ? '✅' : '⚠️'} Zone de drag & drop détectée`);
    }
    
    // Test 5: Check dark theme
    console.log('\n🔍 Test 5: Vérification du thème dark...');
    const backgroundColor = await page.evaluate(() => {
      return window.getComputedStyle(document.body).backgroundColor;
    });
    const isDark = backgroundColor.includes('0, 0, 0') || backgroundColor.includes('rgb(0');
    console.log(`  ${isDark ? '✅' : '❌'} Thème dark activé (bg: ${backgroundColor})`);
    
    // Test 6: Check for red accents
    const hasRedAccents = await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll('*'));
      return elements.some(el => {
        const styles = window.getComputedStyle(el);
        return styles.borderColor?.includes('rgb(239') || // red-600
               styles.backgroundColor?.includes('rgb(239') ||
               styles.color?.includes('rgb(239');
      });
    });
    console.log(`  ${hasRedAccents ? '✅' : '⚠️'} Accents rouges détectés`);
    
    // Test 7: Test API endpoints
    console.log('\n🔍 Test 7: Test des API endpoints...');
    
    const apiTests = [
      '/api/system',
      '/api/media',
      '/api/playlist',
      '/api/settings'
    ];
    
    for (const endpoint of apiTests) {
      const apiResponse = await page.evaluate(async (url) => {
        try {
          const response = await fetch(url);
          return { status: response.status, ok: response.ok };
        } catch (error) {
          return { status: 0, ok: false, error: error.message };
        }
      }, endpoint);
      
      console.log(`  ${apiResponse.ok ? '✅' : '❌'} ${endpoint} - Status: ${apiResponse.status}`);
    }
    
    // Take a screenshot
    console.log('\n📸 Capture d\'écran...');
    await page.screenshot({ path: 'test-screenshot.png', fullPage: true });
    console.log('  ✅ Screenshot sauvegardé: test-screenshot.png');
    
    console.log('\n✨ Tests terminés avec succès!');
    
  } catch (error) {
    console.error('\n❌ Erreur pendant les tests:', error.message);
    
    // Take error screenshot
    try {
      const page = (await browser.pages())[0];
      if (page) {
        await page.screenshot({ path: 'error-screenshot.png', fullPage: true });
        console.log('📸 Screenshot d\'erreur sauvegardé: error-screenshot.png');
      }
    } catch (e) {}
    
    process.exit(1);
  } finally {
    await browser.close();
  }
}

// Run tests
testPiSignage().catch(console.error);