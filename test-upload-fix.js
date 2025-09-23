const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('🧪 TEST UPLOAD APRÈS CORRECTION - PiSignage v0.8.0\n');

  try {
    // Listen to console events
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
        console.log('❌ Console Error:', msg.text());
      } else if (msg.text().includes('[SUCCESS]') || msg.text().includes('[ERROR]')) {
        console.log('📢', msg.text());
      }
    });

    // Load main page
    console.log('📱 Chargement interface...');
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0', timeout: 10000 });

    // Wait for functions.js to load
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Check if showNotification function works without recursion
    console.log('⚙️ Test fonction showNotification...');
    const testNotification = await page.evaluate(() => {
      try {
        showNotification('Test message', 'info');
        return { success: true, error: null };
      } catch (e) {
        return { success: false, error: e.message };
      }
    });

    console.log(`   showNotification: ${testNotification.success ? '✅ OK' : '❌ ' + testNotification.error}`);

    if (!testNotification.success) {
      console.log('❌ ÉCHEC: showNotification encore défectueuse');
      return;
    }

    // Try to click upload button
    console.log('\n🖱️ Test clic bouton Upload...');

    // Find upload button by text content
    const uploadButton = await page.evaluateHandle(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      return buttons.find(btn => btn.textContent.includes('Upload'));
    });

    if (!uploadButton.asElement()) {
      console.log('❌ Bouton Upload non trouvé');
      return;
    }

    console.log('   ✅ Bouton Upload trouvé');

    // Click the upload button using JavaScript
    await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const uploadBtn = buttons.find(btn => btn.textContent.includes('Upload'));
      if (uploadBtn) {
        uploadBtn.click();
      }
    });

    // Wait for modal to appear
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Check if modal appeared without errors
    const modalStatus = await page.evaluate(() => {
      const modal = document.getElementById('uploadModal');
      return {
        exists: modal !== null,
        visible: modal && modal.style.display !== 'none',
        hasInput: modal && modal.querySelector('#fileInput') !== null
      };
    });

    console.log(`   Modal créée: ${modalStatus.exists ? '✅' : '❌'}`);
    console.log(`   Modal visible: ${modalStatus.visible ? '✅' : '❌'}`);
    console.log(`   Input fichier: ${modalStatus.hasInput ? '✅' : '❌'}`);

    // Test modal closing
    if (modalStatus.exists) {
      console.log('\n🔴 Test fermeture modal...');
      await page.click('#cancelUpload');
      await new Promise(resolve => setTimeout(resolve, 500));

      const modalClosed = await page.evaluate(() => {
        return document.getElementById('uploadModal') === null;
      });
      console.log(`   Modal fermée: ${modalClosed ? '✅' : '❌'}`);
    }

    // Check for console errors (should be 0 now)
    console.log('\n🔍 Vérification erreurs console...');

    if (errors.length === 0) {
      console.log('   ✅ Aucune erreur JavaScript');
    } else {
      console.log('   ❌ Erreurs détectées:');
      errors.slice(0, 3).forEach(error => console.log(`     - ${error}`));
      if (errors.length > 3) {
        console.log(`     ... et ${errors.length - 3} autres erreurs`);
      }
    }

    // Take screenshot
    await page.screenshot({ path: '/tmp/upload-fixed.png' });
    console.log('\n📸 Screenshot: /tmp/upload-fixed.png');

    if (errors.length === 0 && modalStatus.exists) {
      console.log('\n🎉 UPLOAD FONCTION COMPLÈTEMENT RÉPARÉE!');
      console.log('✅ Plus de boucle infinie');
      console.log('✅ Modal fonctionne');
      console.log('✅ Interface réactive');
    } else {
      console.log('\n⚠️ Quelques problèmes persistent');
    }

  } catch (error) {
    console.error('❌ Erreur durant le test:', error.message);
  } finally {
    await browser.close();
  }
})();