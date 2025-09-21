const puppeteer = require('puppeteer');

async function testScreenshotDisplay() {
    console.log('🔍 Test d\'affichage du screenshot\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Activer les logs de la console
    page.on('console', msg => {
        if (msg.type() === 'log' || msg.type() === 'error') {
            console.log('Browser console:', msg.text());
        }
    });
    
    // Charger la page
    console.log('📡 Chargement de la page...');
    await page.goto('http://192.168.1.103/', { 
        waitUntil: 'networkidle2',
        timeout: 30000 
    });
    
    // Test manuel de l'affichage du screenshot
    console.log('\n🖼️ Test direct de l\'affichage du screenshot...');
    const testResult = await page.evaluate(() => {
        const preview = document.getElementById('screenshot-preview');
        const placeholder = document.getElementById('screenshot-placeholder');
        
        if (!preview) return { error: 'Preview element not found' };
        if (!placeholder) return { error: 'Placeholder element not found' };
        
        // Forcer l'affichage de l'image
        preview.src = 'assets/screenshots/current_display.png?t=' + Date.now();
        preview.style.display = 'block';
        placeholder.style.display = 'none';
        
        // Attendre le chargement
        return new Promise(resolve => {
            preview.onload = () => {
                resolve({
                    success: true,
                    src: preview.src,
                    displayed: window.getComputedStyle(preview).display,
                    width: preview.naturalWidth,
                    height: preview.naturalHeight,
                    offsetWidth: preview.offsetWidth,
                    offsetHeight: preview.offsetHeight,
                    parentDisplay: window.getComputedStyle(preview.parentElement).display
                });
            };
            
            preview.onerror = () => {
                resolve({
                    success: false,
                    error: 'Failed to load image',
                    src: preview.src
                });
            };
            
            setTimeout(() => {
                resolve({
                    success: false,
                    error: 'Timeout',
                    src: preview.src,
                    displayed: window.getComputedStyle(preview).display
                });
            }, 5000);
        });
    });
    
    console.log('Result:', JSON.stringify(testResult, null, 2));
    
    // Prendre un screenshot pour voir l'état
    await page.screenshot({ path: '/opt/pisignage/tests/screenshots/screenshot-display-test.png', fullPage: false });
    console.log('📸 Screenshot sauvegardé');
    
    // Maintenant tester le bouton
    console.log('\n🔘 Test du bouton screenshot...');
    await page.evaluate(() => {
        // Reset l'état
        const preview = document.getElementById('screenshot-preview');
        const placeholder = document.getElementById('screenshot-placeholder');
        preview.style.display = 'none';
        placeholder.style.display = 'block';
        placeholder.innerHTML = '<div>Cliquez sur le bouton pour capturer l\'écran</div>';
    });
    
    // Cliquer sur le bouton
    await page.click('#dashboard-tab button:first-child');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Vérifier l'état après le clic
    const afterClick = await page.evaluate(() => {
        const preview = document.getElementById('screenshot-preview');
        const placeholder = document.getElementById('screenshot-placeholder');
        
        return {
            previewSrc: preview.src,
            previewDisplay: window.getComputedStyle(preview).display,
            placeholderDisplay: window.getComputedStyle(placeholder).display,
            previewNaturalSize: {
                width: preview.naturalWidth,
                height: preview.naturalHeight
            }
        };
    });
    
    console.log('After click:', JSON.stringify(afterClick, null, 2));
    
    await browser.close();
}

testScreenshotDisplay().catch(console.error);