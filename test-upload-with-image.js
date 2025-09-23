const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();

  console.log('🧪 TEST UPLOAD AVEC IMAGE - PiSignage v0.8.0\n');

  try {
    // Load main page
    console.log('📱 Chargement interface...');
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0', timeout: 10000 });
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Click upload button
    console.log('🖱️ Ouverture modal upload...');
    await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const uploadBtn = buttons.find(btn => btn.textContent.includes('Upload'));
      if (uploadBtn) uploadBtn.click();
    });
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Create a PNG image file
    console.log('🖼️ Création fichier PNG test...');

    const uploadResult = await page.evaluate(() => {
      return new Promise((resolve) => {
        // Create a 1x1 PNG image (smallest valid PNG)
        const pngData = new Uint8Array([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
          0x00, 0x00, 0x00, 0x0D, // IHDR chunk size
          0x49, 0x48, 0x44, 0x52, // IHDR
          0x00, 0x00, 0x00, 0x01, // width: 1
          0x00, 0x00, 0x00, 0x01, // height: 1
          0x08, 0x02, 0x00, 0x00, 0x00, // bit depth, color type, compression, filter, interlace
          0x90, 0x77, 0x53, 0xDE, // CRC
          0x00, 0x00, 0x00, 0x0C, // IDAT chunk size
          0x49, 0x44, 0x41, 0x54, // IDAT
          0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, // image data
          0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33, // CRC
          0x00, 0x00, 0x00, 0x00, // IEND chunk size
          0x49, 0x45, 0x4E, 0x44, // IEND
          0xAE, 0x42, 0x60, 0x82  // CRC
        ]);

        const blob = new Blob([pngData], { type: 'image/png' });
        const file = new File([blob], 'test-image.png', { type: 'image/png' });

        console.log('PNG file created:', file.name, file.size, 'bytes, type:', file.type);

        const formData = new FormData();
        formData.append('files[]', file);

        fetch('/api/upload.php', {
          method: 'POST',
          body: formData
        })
        .then(response => response.json())
        .then(data => {
          console.log('Upload response:', data);
          resolve({
            success: data.success,
            message: data.message,
            uploadedCount: data.data?.uploaded_count || 0,
            errors: data.data?.errors || [],
            uploaded: data.data?.uploaded_files || []
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

    console.log('\n📤 Résultat upload PNG:');
    console.log(`   Success: ${uploadResult.success ? '✅' : '❌'}`);
    console.log(`   Message: ${uploadResult.message || 'N/A'}`);
    console.log(`   Files uploaded: ${uploadResult.uploadedCount || 0}`);

    if (uploadResult.errors && uploadResult.errors.length > 0) {
      console.log('   Errors:');
      uploadResult.errors.forEach(err => console.log(`     - ${err}`));
    }

    if (uploadResult.uploaded && uploadResult.uploaded.length > 0) {
      console.log('   Uploaded files:');
      uploadResult.uploaded.forEach(file => console.log(`     + ${file.name}`));
    }

    // Test with JPG as well
    console.log('\n🖼️ Test avec fichier JPG...');

    const jpgResult = await page.evaluate(() => {
      return new Promise((resolve) => {
        // Create minimal JPEG (fake but valid header)
        const jpegData = new Uint8Array([
          0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
          0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xD9
        ]);

        const blob = new Blob([jpegData], { type: 'image/jpeg' });
        const file = new File([blob], 'test-photo.jpg', { type: 'image/jpeg' });

        const formData = new FormData();
        formData.append('files[]', file);

        fetch('/api/upload.php', {
          method: 'POST',
          body: formData
        })
        .then(response => response.json())
        .then(data => {
          resolve({
            success: data.success,
            uploadedCount: data.data?.uploaded_count || 0
          });
        })
        .catch(error => {
          resolve({ success: false, error: error.message });
        });
      });
    });

    console.log(`   JPG Success: ${jpgResult.success ? '✅' : '❌'}`);
    console.log(`   JPG Files uploaded: ${jpgResult.uploadedCount || 0}`);

    await page.screenshot({ path: '/tmp/upload-image-test.png' });
    console.log('\n📸 Screenshot: /tmp/upload-image-test.png');

    if (uploadResult.success || jpgResult.success) {
      console.log('\n🎉 UPLOAD FONCTIONNE AVEC FICHIERS MÉDIAS!');
    } else {
      console.log('\n❌ Upload ne fonctionne toujours pas');
    }

  } catch (error) {
    console.error('❌ Erreur:', error.message);
  } finally {
    await browser.close();
  }
})();