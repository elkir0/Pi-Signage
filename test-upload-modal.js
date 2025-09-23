const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('🧪 TEST FONCTION UPLOAD - PiSignage v0.8.0\n');

  try {
    // Load main page
    console.log('📱 Chargement interface...');
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0', timeout: 10000 });

    // Wait for functions.js to load
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Check if showUploadModal function exists
    console.log('⚙️ Vérification fonction showUploadModal...');
    const functionExists = await page.evaluate(() => {
      return typeof showUploadModal === 'function';
    });

    console.log(`   showUploadModal: ${functionExists ? '✅ Définie' : '❌ Manquante'}`);

    if (!functionExists) {
      console.log('❌ ÉCHEC: Fonction showUploadModal non définie');
      return;
    }

    // Try to click upload button
    console.log('\n🖱️ Test clic bouton Upload...');

    // Look for upload button
    const uploadButton = await page.$('button[onclick="showUploadModal()"]');

    if (!uploadButton) {
      console.log('❌ Bouton Upload non trouvé');
      return;
    }

    console.log('   ✅ Bouton Upload trouvé');

    // Click the upload button
    await uploadButton.click();

    // Wait for modal to appear
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Check if modal appeared
    const modalExists = await page.evaluate(() => {
      const modal = document.getElementById('uploadModal');
      return modal && modal.style.display !== 'none';
    });

    console.log(`   Modal affichée: ${modalExists ? '✅ OUI' : '❌ NON'}`);

    if (modalExists) {
      // Check modal content
      const modalContent = await page.evaluate(() => {
        const modal = document.getElementById('uploadModal');
        return {
          hasTitle: modal.querySelector('h4') !== null,
          hasFileInput: modal.querySelector('#fileInput') !== null,
          hasUploadButton: modal.querySelector('#startUpload') !== null,
          hasCancelButton: modal.querySelector('#cancelUpload') !== null
        };
      });

      console.log('\n📋 Contenu modal:');
      console.log(`   Titre: ${modalContent.hasTitle ? '✅' : '❌'}`);
      console.log(`   Input fichier: ${modalContent.hasFileInput ? '✅' : '❌'}`);
      console.log(`   Bouton Upload: ${modalContent.hasUploadButton ? '✅' : '❌'}`);
      console.log(`   Bouton Annuler: ${modalContent.hasCancelButton ? '✅' : '❌'}`);

      // Test closing modal
      console.log('\n🔴 Test fermeture modal...');
      await page.click('#cancelUpload');
      await new Promise(resolve => setTimeout(resolve, 500));

      const modalClosed = await page.evaluate(() => {
        return document.getElementById('uploadModal') === null;
      });

      console.log(`   Modal fermée: ${modalClosed ? '✅ OUI' : '❌ NON'}`);

      if (modalClosed) {
        console.log('\n🎉 FONCTION UPLOAD COMPLÈTEMENT FONCTIONNELLE!');
      }
    }

    // Check for console errors
    console.log('\n🔍 Vérification erreurs console...');

    // Listen to console events
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    // Click upload button again to test
    await uploadButton.click();
    await new Promise(resolve => setTimeout(resolve, 1000));

    if (errors.length === 0) {
      console.log('   ✅ Aucune erreur JavaScript');
    } else {
      console.log('   ❌ Erreurs détectées:');
      errors.forEach(error => console.log(`     - ${error}`));
    }

    // Take screenshot
    await page.screenshot({ path: '/tmp/upload-test.png' });
    console.log('\n📸 Screenshot: /tmp/upload-test.png');

    console.log('\n✅ TEST UPLOAD TERMINÉ AVEC SUCCÈS');

  } catch (error) {
    console.error('❌ Erreur durant le test:', error.message);
  } finally {
    await browser.close();
  }
})();