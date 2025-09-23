const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new', // Headless mode for server
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('🧪 TEST UPLOAD UTILISATEUR RÉEL - PiSignage v0.8.0\n');

  try {
    // Listen to all console events
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();

      if (type === 'error') {
        console.log('❌ Console Error:', text);
      } else if (text.includes('[ERROR]') || text.includes('[SUCCESS]')) {
        console.log('📢', text);
      }
    });

    // Load main page
    console.log('📱 Chargement interface...');
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0', timeout: 10000 });
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Navigate to Media section if not already there
    console.log('📁 Navigation vers section Media...');
    await page.evaluate(() => {
      const mediaTab = document.querySelector('[onclick="showSection(\'media\')"]');
      if (mediaTab) mediaTab.click();
    });
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Click upload button
    console.log('🖱️ Clic bouton Upload...');
    await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const uploadBtn = buttons.find(btn => btn.textContent.includes('Upload'));
      if (uploadBtn) {
        console.log('Upload button found and clicked');
        uploadBtn.click();
      }
    });
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Check if modal appeared
    const modalExists = await page.evaluate(() => {
      const modal = document.getElementById('uploadModal');
      return modal !== null && modal.style.display !== 'none';
    });

    console.log(`   Modal ouverte: ${modalExists ? '✅' : '❌'}`);

    if (!modalExists) {
      console.log('❌ Modal ne s\'ouvre pas - arrêt du test');
      return;
    }

    // Test file selection simulation
    console.log('\n📂 Test sélection fichier...');

    // Debug the file input
    const fileInputDebug = await page.evaluate(() => {
      const fileInput = document.getElementById('fileInput');
      if (fileInput) {
        return {
          exists: true,
          multiple: fileInput.multiple,
          accept: fileInput.accept,
          value: fileInput.value,
          filesLength: fileInput.files ? fileInput.files.length : 0
        };
      }
      return { exists: false };
    });

    console.log('   File input info:', fileInputDebug);

    // Simulate file selection using JavaScript
    const uploadWithFiles = await page.evaluate(() => {
      return new Promise((resolve) => {
        const fileInput = document.getElementById('fileInput');
        const uploadBtn = document.getElementById('startUpload');

        if (!fileInput || !uploadBtn) {
          resolve({ error: 'File input or upload button not found' });
          return;
        }

        // Create a test PNG file
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
        const file = new File([blob], 'user-test.png', { type: 'image/png' });

        // Create FileList-like object
        const dt = new DataTransfer();
        dt.items.add(file);
        fileInput.files = dt.files;

        console.log('File added to input:', fileInput.files.length, 'files');
        console.log('File name:', fileInput.files[0]?.name);

        // Trigger change event
        const changeEvent = new Event('change', { bubbles: true });
        fileInput.dispatchEvent(changeEvent);

        // Now click upload button
        uploadBtn.click();

        // Wait for upload to complete
        setTimeout(() => {
          resolve({
            success: true,
            filesSelected: fileInput.files.length,
            fileName: fileInput.files[0]?.name
          });
        }, 3000);
      });
    });

    console.log('\n📤 Résultat upload utilisateur:');
    if (uploadWithFiles.error) {
      console.log('   ❌ Error:', uploadWithFiles.error);
    } else {
      console.log(`   Files sélectionnés: ${uploadWithFiles.filesSelected}`);
      console.log(`   Nom fichier: ${uploadWithFiles.fileName}`);
      console.log(`   Success: ${uploadWithFiles.success ? '✅' : '❌'}`);
    }

    // Check if files were actually uploaded
    await new Promise(resolve => setTimeout(resolve, 2000));

    const mediaFiles = await page.evaluate(async () => {
      try {
        const response = await fetch('/api/media.php?action=list');
        const data = await response.json();
        return data.data || [];
      } catch (e) {
        return [];
      }
    });

    console.log('\n📋 Fichiers dans media après upload:');
    mediaFiles.forEach(file => {
      console.log(`   - ${file.name} (${file.size} bytes)`);
    });

    // Test file deletion
    console.log('\n🗑️ Test suppression fichier...');
    if (mediaFiles.length > 0) {
      const deleteResult = await page.evaluate(async (fileName) => {
        try {
          const response = await fetch('/api/media.php', {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ filename: fileName })
          });
          const data = await response.json();
          return data;
        } catch (e) {
          return { success: false, error: e.message };
        }
      }, mediaFiles[0].name);

      console.log(`   Suppression: ${deleteResult.success ? '✅' : '❌'}`);
      if (!deleteResult.success) {
        console.log(`   Error: ${deleteResult.message || deleteResult.error}`);
      }
    }

    await page.screenshot({ path: '/tmp/user-upload-test.png' });
    console.log('\n📸 Screenshot: /tmp/user-upload-test.png');

  } catch (error) {
    console.error('❌ Erreur durant le test:', error.message);
  } finally {
    await browser.close();
  }
})();