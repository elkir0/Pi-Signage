const puppeteer = require('puppeteer');

(async () => {
    console.log('🧪 TEST RÉEL DE SUPPRESSION');
    console.log('=' .repeat(50));

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Accept dialogs
    page.on('dialog', async dialog => {
        console.log('📝 Dialog: ' + dialog.message());
        await dialog.accept();
    });

    // Monitor network requests
    page.on('request', request => {
        if (request.url().includes('/api/media.php') && request.method() === 'DELETE') {
            const postData = request.postData();
            console.log('🔍 DELETE Request Body: ' + postData);

            if (postData) {
                try {
                    const data = JSON.parse(postData);
                    console.log('   - Has "filename": ' + ('filename' in data ? '✅' : '❌'));
                    console.log('   - Has "action": ' + ('action' in data ? '✅' : '❌'));
                    console.log('   - Old "file" param: ' + ('file' in data ? '⚠️ PRÉSENT' : '✅ ABSENT'));
                } catch (e) {
                    console.log('   ❌ Invalid JSON');
                }
            }
        }
    });

    // Monitor responses
    page.on('response', response => {
        if (response.url().includes('/api/media.php') && response.request().method() === 'DELETE') {
            response.text().then(text => {
                console.log('📨 API Response: ' + text);
            });
        }
    });

    // Navigation
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });

    // Go to media section
    await page.evaluate(() => showSection('media'));
    await new Promise(r => setTimeout(r, 2000));

    // Get first file to delete
    const hasFiles = await page.evaluate(() => {
        const deleteButtons = document.querySelectorAll('button[onclick*="deleteFile"]');
        if (deleteButtons.length > 0) {
            // Get filename from first delete button
            const onclick = deleteButtons[0].getAttribute('onclick');
            const match = onclick.match(/deleteFile\('(.+?)'\)/);
            return match ? match[1] : null;
        }
        return null;
    });

    if (hasFiles) {
        console.log('\n📁 Tentative de suppression du fichier: ' + hasFiles);

        // Click delete button
        await page.evaluate(() => {
            const deleteButtons = document.querySelectorAll('button[onclick*="deleteFile"]');
            if (deleteButtons.length > 0) {
                deleteButtons[0].click();
            }
        });

        // Wait for request to complete
        await new Promise(r => setTimeout(r, 2000));

    } else {
        console.log('\n⚠️ Aucun fichier à supprimer trouvé');
        console.log('Création d\'un test sans fichier réel...');

        // Test direct function call
        const testResult = await page.evaluate(() => {
            // Override confirm to return false (cancel)
            window.confirm = () => true;

            // Capture fetch call
            let capturedBody = null;
            const originalFetch = window.fetch;
            window.fetch = function(...args) {
                if (args[0].includes('/api/media.php')) {
                    capturedBody = args[1].body;
                    // Don't actually send the request
                    return Promise.resolve(new Response(JSON.stringify({success: false, message: 'Test mode'})));
                }
                return originalFetch.apply(this, args);
            };

            // Call deleteFile
            if (typeof deleteFile === 'function') {
                deleteFile('test-file.mp4');
                return capturedBody;
            }
            return null;
        });

        if (testResult) {
            console.log('📝 Body capturé: ' + testResult);
            const data = JSON.parse(testResult);
            console.log('   - Has "filename": ' + ('filename' in data ? '✅' : '❌'));
            console.log('   - Has "action": ' + ('action' in data ? '✅' : '❌'));
        }
    }

    console.log('\n' + '='.repeat(50));
    console.log('✅ Test terminé');

    await browser.close();
})();