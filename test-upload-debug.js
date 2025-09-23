const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('🧪 DEBUG UPLOAD - PiSignage v0.8.0\n');

  try {
    // Create a small test file
    const testContent = 'Test file for upload debugging';
    fs.writeFileSync('/tmp/test-upload.txt', testContent);
    console.log('📄 Test file created: /tmp/test-upload.txt');

    // Load main page
    console.log('📱 Chargement interface...');
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0', timeout: 10000 });

    // Wait for functions.js to load
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Click upload button to open modal
    console.log('\n🖱️ Ouverture modal upload...');
    await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const uploadBtn = buttons.find(btn => btn.textContent.includes('Upload'));
      if (uploadBtn) {
        uploadBtn.click();
      }
    });

    await new Promise(resolve => setTimeout(resolve, 1000));

    // Create a file to upload via JavaScript
    console.log('📁 Création fichier test pour upload...');

    // Upload file via file input simulation
    const uploadResult = await page.evaluate(() => {
      return new Promise((resolve) => {
        // Create a mock file
        const fileContent = 'Hello, this is a test file content!';
        const blob = new Blob([fileContent], { type: 'text/plain' });
        const file = new File([blob], 'test-upload.txt', { type: 'text/plain' });

        console.log('File created:', file.name, file.size, 'bytes');

        // Test our upload function directly
        const formData = new FormData();
        formData.append('files[]', file);

        console.log('FormData entries:');
        for (let [key, value] of formData.entries()) {
          console.log(key, value);
        }

        // Send to debug endpoint first
        fetch('/debug-upload.php', {
          method: 'POST',
          body: formData
        })
        .then(response => response.text())
        .then(debugData => {
          console.log('Debug response:', debugData);

          // Now send to real upload endpoint
          return fetch('/api/upload.php', {
            method: 'POST',
            body: formData
          });
        })
        .then(response => response.text())
        .then(uploadData => {
          console.log('Upload response:', uploadData);
          resolve({
            success: true,
            debugData: 'Check console for debug info',
            uploadData: uploadData
          });
        })
        .catch(error => {
          console.error('Upload error:', error);
          resolve({
            success: false,
            error: error.message
          });
        });
      });
    });

    console.log('\n📤 Résultat test upload:');
    console.log('   Success:', uploadResult.success);
    if (uploadResult.error) {
      console.log('   Error:', uploadResult.error);
    }
    if (uploadResult.uploadData) {
      console.log('   Response:', uploadResult.uploadData.substring(0, 200));
    }

    // Wait a bit to see console output
    await new Promise(resolve => setTimeout(resolve, 2000));

    console.log('\n📸 Screenshot: /tmp/upload-debug.png');
    await page.screenshot({ path: '/tmp/upload-debug.png' });

  } catch (error) {
    console.error('❌ Erreur durant le debug:', error.message);
  } finally {
    await browser.close();
  }
})();