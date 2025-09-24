const puppeteer = require('puppeteer');

(async () => {
    console.log('🔍 Debug Upload Modal\n');

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture console
    page.on('console', msg => {
        if (msg.type() === 'error') {
            console.log('❌ Error: ' + msg.text());
        }
    });

    await page.goto('http://192.168.1.103/', {
        waitUntil: 'networkidle2'
    });

    // Go to media section
    await page.evaluate(() => showSection('media'));
    await new Promise(r => setTimeout(r, 1000));

    // Check for showUploadModal function
    const hasFunction = await page.evaluate(() => {
        return typeof showUploadModal === 'function';
    });
    console.log('showUploadModal function exists: ' + (hasFunction ? '✅' : '❌'));

    // Check for modal element
    const modalExists = await page.evaluate(() => {
        return !!document.getElementById('uploadModal');
    });
    console.log('uploadModal element exists: ' + (modalExists ? '✅' : '❌'));

    // Check for upload button
    const uploadButtonExists = await page.evaluate(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.some(btn => btn.textContent.includes('Upload') || btn.onclick && btn.onclick.toString().includes('showUploadModal'));
    });
    console.log('Upload button exists: ' + (uploadButtonExists ? '✅' : '❌'));

    // Try to find and click upload button
    if (uploadButtonExists) {
        try {
            await page.evaluate(() => {
                const buttons = Array.from(document.querySelectorAll('button'));
                const uploadBtn = buttons.find(btn => btn.textContent.includes('Upload') || btn.onclick && btn.onclick.toString().includes('showUploadModal'));
                if (uploadBtn) uploadBtn.click();
            });
            await new Promise(r => setTimeout(r, 500));
            
            const modalVisible = await page.evaluate(() => {
                const modal = document.getElementById('uploadModal');
                return modal && (modal.style.display !== 'none' || modal.classList.contains('show'));
            });
            console.log('Modal visible after click: ' + (modalVisible ? '✅' : '❌'));
        } catch (e) {
            console.log('Error clicking button: ' + e.message);
        }
    }

    // Screenshot
    await page.screenshot({ path: '/tmp/upload-modal-debug.png' });
    
    await browser.close();
})();
