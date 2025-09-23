const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('🧪 TEST INTERFACE UPLOAD AMÉLIORÉE - PiSignage v0.8.0\n');

  try {
    // Load main page
    console.log('📱 Chargement interface...');
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0', timeout: 10000 });
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Click upload button to open modal
    console.log('🖱️ Ouverture modal upload...');
    await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const uploadBtn = buttons.find(btn => btn.textContent.includes('Upload'));
      if (uploadBtn) uploadBtn.click();
    });
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Check improved interface elements
    console.log('🎨 Vérification interface améliorée...');
    const interfaceCheck = await page.evaluate(() => {
      return {
        modal: document.getElementById('uploadModal') !== null,
        fileSelectArea: document.getElementById('fileSelectArea') !== null,
        selectedFilesDiv: document.getElementById('selectedFiles') !== null,
        filesList: document.getElementById('filesList') !== null,
        fileInput: document.getElementById('fileInput') !== null,
        hasClickText: document.getElementById('fileSelectArea')?.textContent.includes('Cliquez ici'),
        hasDragText: document.getElementById('fileSelectArea')?.textContent.includes('glissez-déposez'),
        hasFormatsText: document.getElementById('fileSelectArea')?.textContent.includes('MP4')
      };
    });

    console.log('   Interface elements:');
    console.log(`     Modal: ${interfaceCheck.modal ? '✅' : '❌'}`);
    console.log(`     Zone sélection: ${interfaceCheck.fileSelectArea ? '✅' : '❌'}`);
    console.log(`     Liste fichiers: ${interfaceCheck.selectedFilesDiv ? '✅' : '❌'}`);
    console.log(`     Texte "Cliquez ici": ${interfaceCheck.hasClickText ? '✅' : '❌'}`);
    console.log(`     Texte "glissez-déposez": ${interfaceCheck.hasDragText ? '✅' : '❌'}`);
    console.log(`     Formats supportés: ${interfaceCheck.hasFormatsText ? '✅' : '❌'}`);

    // Test clicking on file select area
    console.log('\n📁 Test clic sur zone de sélection...');

    // Simulate file selection by clicking area and then adding files
    const fileSelectionTest = await page.evaluate(() => {
      return new Promise((resolve) => {
        const fileSelectArea = document.getElementById('fileSelectArea');
        const fileInput = document.getElementById('fileInput');

        if (!fileSelectArea || !fileInput) {
          resolve({ success: false, error: 'Elements not found' });
          return;
        }

        // Test if clicking area triggers file input
        let inputClicked = false;
        const originalClick = fileInput.click;
        fileInput.click = function() {
          inputClicked = true;
          // Don't actually open file dialog in headless mode
        };

        // Click the area
        fileSelectArea.click();

        setTimeout(() => {
          // Now simulate file selection
          const pngData = new Uint8Array([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
            0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
            0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0xFF,
            0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0xE2,
            0x21, 0xBC, 0x33, 0x00, 0x00, 0x00, 0x00,
            0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
          ]);

          const blob = new Blob([pngData], { type: 'image/png' });
          const file = new File([blob], 'improved-test.png', { type: 'image/png' });

          const dt = new DataTransfer();
          dt.items.add(file);
          fileInput.files = dt.files;

          // Trigger change event
          const changeEvent = new Event('change', { bubbles: true });
          fileInput.dispatchEvent(changeEvent);

          setTimeout(() => {
            // Check if UI updated
            const selectedFilesDiv = document.getElementById('selectedFiles');
            const filesList = document.getElementById('filesList');

            resolve({
              success: true,
              inputClicked: inputClicked,
              filesCount: fileInput.files.length,
              fileName: fileInput.files[0]?.name,
              selectedFilesDivVisible: selectedFilesDiv && selectedFilesDiv.style.display !== 'none',
              filesListHasItems: filesList && filesList.children.length > 0,
              areaTextUpdated: fileSelectArea.textContent.includes('sélectionné')
            });
          }, 500);
        }, 200);
      });
    });

    console.log('   Résultat test clic:');
    console.log(`     Input click triggered: ${fileSelectionTest.inputClicked ? '✅' : '❌'}`);
    console.log(`     Files sélectionnés: ${fileSelectionTest.filesCount || 0}`);
    console.log(`     Nom fichier: ${fileSelectionTest.fileName || 'N/A'}`);
    console.log(`     Liste visible: ${fileSelectionTest.selectedFilesDivVisible ? '✅' : '❌'}`);
    console.log(`     Liste a items: ${fileSelectionTest.filesListHasItems ? '✅' : '❌'}`);
    console.log(`     Texte mis à jour: ${fileSelectionTest.areaTextUpdated ? '✅' : '❌'}`);

    // Test upload with selected file
    if (fileSelectionTest.filesCount > 0) {
      console.log('\n📤 Test upload avec fichier sélectionné...');

      const uploadResult = await page.evaluate(() => {
        return new Promise((resolve) => {
          const uploadBtn = document.getElementById('startUpload');
          if (uploadBtn) {
            uploadBtn.click();

            setTimeout(() => {
              resolve({ success: true, buttonClicked: true });
            }, 2000);
          } else {
            resolve({ success: false, error: 'Upload button not found' });
          }
        });
      });

      console.log(`     Upload déclenché: ${uploadResult.success ? '✅' : '❌'}`);
    }

    await page.screenshot({ path: '/tmp/improved-upload-test.png' });
    console.log('\n📸 Screenshot: /tmp/improved-upload-test.png');

    if (fileSelectionTest.inputClicked && fileSelectionTest.selectedFilesDivVisible) {
      console.log('\n🎉 INTERFACE UPLOAD AMÉLIORÉE FONCTIONNE!');
      console.log('✅ Zone de clic claire et fonctionnelle');
      console.log('✅ Affichage des fichiers sélectionnés');
      console.log('✅ Interface utilisateur intuitive');
    } else {
      console.log('\n⚠️ Interface nécessite encore des ajustements');
    }

  } catch (error) {
    console.error('❌ Erreur durant le test:', error.message);
  } finally {
    await browser.close();
  }
})();