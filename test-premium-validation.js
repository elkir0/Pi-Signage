const puppeteer = require('puppeteer');
const fs = require('fs').promises;
const path = require('path');

const TARGET_URL = 'http://192.168.1.103';

async function validatePremiumInterface() {
  console.log('🚀 Validation de l\'interface Premium PiSignage 2.0');
  console.log('=' . repeat(60));
  
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  const consoleErrors = [];
  const networkErrors = [];
  const premiumFeatures = {
    glassmorphism: false,
    animations: false,
    gradients: false,
    darkTheme: false,
    logo: false
  };

  // Capture console messages
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    if (type === 'error' || type === 'warning') {
      consoleErrors.push({ type, text });
    }
  });

  // Capture network errors
  page.on('requestfailed', request => {
    networkErrors.push({
      url: request.url(),
      failure: request.failure().errorText
    });
  });

  try {
    console.log(`\n📡 Connexion à ${TARGET_URL}...`);
    const response = await page.goto(TARGET_URL, { 
      waitUntil: 'networkidle2',
      timeout: 30000 
    });

    console.log(`✅ Page chargée - Status: ${response.status()}`);

    // Take screenshot of premium interface
    const screenshotsDir = 'screenshots-premium';
    await fs.mkdir(screenshotsDir, { recursive: true });
    
    const screenshotPath = path.join(screenshotsDir, 'home-premium.png');
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`📸 Screenshot sauvegardé: ${screenshotPath}`);

    // Validate Premium Design Elements
    console.log('\n🎨 Validation des éléments Premium:');
    
    // Check for glassmorphism effect
    const hasGlassmorphism = await page.evaluate(() => {
      const elements = document.querySelectorAll('.glass-card, .glass-morphism');
      return elements.length > 0;
    });
    premiumFeatures.glassmorphism = hasGlassmorphism;
    console.log(`  ${hasGlassmorphism ? '✅' : '❌'} Glassmorphism: ${hasGlassmorphism ? 'Présent' : 'Absent'}`);

    // Check for animations
    const hasAnimations = await page.evaluate(() => {
      const animated = document.querySelectorAll('[class*="animate-"]');
      return animated.length > 0;
    });
    premiumFeatures.animations = hasAnimations;
    console.log(`  ${hasAnimations ? '✅' : '❌'} Animations: ${hasAnimations ? 'Actives' : 'Inactives'}`);

    // Check for gradient backgrounds
    const hasGradients = await page.evaluate(() => {
      const meshBg = document.querySelector('.mesh-background');
      const gradientElements = document.querySelectorAll('[class*="gradient"]');
      return meshBg !== null || gradientElements.length > 0;
    });
    premiumFeatures.gradients = hasGradients;
    console.log(`  ${hasGradients ? '✅' : '❌'} Gradients: ${hasGradients ? 'Présents' : 'Absents'}`);

    // Check dark theme
    const bgColor = await page.evaluate(() => {
      const body = document.body;
      const style = window.getComputedStyle(body);
      return style.backgroundColor;
    });
    const isDark = bgColor.includes('0, 0, 0') || bgColor.includes('10, 10, 15');
    premiumFeatures.darkTheme = isDark;
    console.log(`  ${isDark ? '✅' : '❌'} Thème Dark: ${bgColor}`);

    // Check for logo
    const hasLogo = await page.evaluate(() => {
      const logos = document.querySelectorAll('img[alt*="Pi"], img[src*="logo"], .logo');
      return logos.length > 0;
    });
    premiumFeatures.logo = hasLogo;
    console.log(`  ${hasLogo ? '✅' : '❌'} Logo: ${hasLogo ? 'Présent' : 'Absent'}`);

    // Test all tabs
    console.log('\n📑 Test de navigation des onglets:');
    const tabs = [
      { name: 'Dashboard', selector: 'button:has-text("Dashboard"), [data-value="dashboard"]' },
      { name: 'Playlists', selector: 'button:has-text("Playlists"), [data-value="playlist"]' },
      { name: 'Médias', selector: 'button:has-text("Médias"), [data-value="media"]' },
      { name: 'YouTube', selector: 'button:has-text("YouTube"), [data-value="youtube"]' },
      { name: 'Programmation', selector: 'button:has-text("Programmation"), [data-value="schedule"]' },
      { name: 'Monitoring', selector: 'button:has-text("Monitoring"), [data-value="monitor"]' },
      { name: 'Paramètres', selector: 'button:has-text("Paramètres"), [data-value="settings"]' }
    ];

    for (let i = 0; i < tabs.length; i++) {
      const tab = tabs[i];
      try {
        // Try multiple selectors
        const selectors = [
          `button:has-text("${tab.name}")`,
          `[data-value="${tab.name.toLowerCase()}"]`,
          `.tab-premium:has-text("${tab.name}")`,
          `button:nth-child(${i + 1})`
        ];
        
        let clicked = false;
        for (const selector of selectors) {
          try {
            await page.click(selector, { timeout: 2000 });
            clicked = true;
            break;
          } catch (e) {
            // Try next selector
          }
        }
        
        if (clicked) {
          await page.waitForTimeout(1000);
          const screenshotPath = path.join(screenshotsDir, `${i + 1}-${tab.name.toLowerCase()}.png`);
          await page.screenshot({ path: screenshotPath });
          console.log(`  ✅ ${tab.name}: Navigation OK`);
        } else {
          console.log(`  ⚠️ ${tab.name}: Impossible de cliquer`);
        }
      } catch (error) {
        console.log(`  ❌ ${tab.name}: Erreur - ${error.message}`);
      }
    }

    // Summary Report
    console.log('\n' + '=' . repeat(60));
    console.log('📊 RAPPORT FINAL');
    console.log('=' . repeat(60));
    
    const allPremiumFeatures = Object.values(premiumFeatures).every(v => v);
    if (allPremiumFeatures) {
      console.log('✅ Interface Premium complètement fonctionnelle!');
    } else {
      console.log('⚠️ Certains éléments Premium manquants');
    }

    if (consoleErrors.length > 0) {
      console.log(`\n⚠️ ${consoleErrors.length} erreur(s) console détectée(s):`);
      consoleErrors.forEach(err => {
        console.log(`  - ${err.type}: ${err.text}`);
      });
    } else {
      console.log('\n✅ Aucune erreur console');
    }

    if (networkErrors.length > 0) {
      console.log(`\n⚠️ ${networkErrors.length} erreur(s) réseau:`);
      networkErrors.forEach(err => {
        console.log(`  - ${err.url}: ${err.failure}`);
      });
    } else {
      console.log('✅ Aucune erreur réseau');
    }

    // Generate JSON report
    const report = {
      timestamp: new Date().toISOString(),
      url: TARGET_URL,
      premiumFeatures,
      consoleErrors,
      networkErrors,
      success: allPremiumFeatures && consoleErrors.length === 0
    };

    await fs.writeFile('test-premium-report.json', JSON.stringify(report, null, 2));
    console.log('\n📄 Rapport JSON généré: test-premium-report.json');

  } catch (error) {
    console.error('\n❌ Erreur fatale:', error.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

validatePremiumInterface().catch(console.error);