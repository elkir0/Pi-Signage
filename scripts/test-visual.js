const puppeteer = require('puppeteer');

async function testVisual() {
    console.log('🔍 Test visuel de PiSignage\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Charger la page
    console.log('📡 Chargement de http://192.168.1.103/');
    await page.goto('http://192.168.1.103/', { 
        waitUntil: 'networkidle2',
        timeout: 30000 
    });
    
    // Attendre que le dashboard soit chargé
    await page.waitForSelector('#dashboard-tab', { timeout: 5000 });
    
    // Vérifier le statut VLC
    console.log('\n📺 Vérification du statut VLC...');
    const vlcStatus = await page.evaluate(() => {
        const statusElement = document.querySelector('#player-status');
        return statusElement ? statusElement.textContent : 'Element not found';
    });
    console.log(`Statut VLC: ${vlcStatus}`);
    
    // Prendre un screenshot de la page
    await page.screenshot({ path: '/opt/pisignage/tests/screenshots/dashboard-view.png', fullPage: true });
    console.log('📸 Screenshot de la page sauvegardé');
    
    // Cliquer sur le bouton screenshot
    console.log('\n🖼️ Test du bouton screenshot...');
    await page.click('#dashboard-tab button');
    
    // Attendre que le screenshot soit pris
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Vérifier si le screenshot est affiché
    const screenshotVisible = await page.evaluate(() => {
        const img = document.querySelector('#screenshot-preview');
        if (!img) return { found: false, message: 'Image element not found' };
        
        const src = img.getAttribute('src');
        const displayed = window.getComputedStyle(img).display !== 'none';
        const hasSize = img.naturalWidth > 0 && img.naturalHeight > 0;
        
        return {
            found: true,
            src: src,
            displayed: displayed,
            hasSize: hasSize,
            width: img.naturalWidth,
            height: img.naturalHeight,
            style: window.getComputedStyle(img).display
        };
    });
    
    console.log('Screenshot visibility:', JSON.stringify(screenshotVisible, null, 2));
    
    // Si l'image existe, vérifier qu'elle se charge
    if (screenshotVisible.src) {
        const imageLoaded = await page.evaluate(async (src) => {
            return new Promise((resolve) => {
                const img = new Image();
                img.onload = () => resolve({ success: true, width: img.width, height: img.height });
                img.onerror = () => resolve({ success: false, error: 'Failed to load' });
                img.src = src.startsWith('http') ? src : window.location.origin + '/' + src;
                setTimeout(() => resolve({ success: false, error: 'Timeout' }), 5000);
            });
        }, screenshotVisible.src);
        
        console.log('Image load test:', imageLoaded);
    }
    
    // Tester l'API status
    console.log('\n📊 Test de l\'API status...');
    const statusData = await page.evaluate(async () => {
        const response = await fetch('/?action=status');
        return await response.json();
    });
    console.log('VLC Running:', statusData.data?.vlc_running);
    
    // Prendre un screenshot final
    await page.screenshot({ path: '/opt/pisignage/tests/screenshots/final-state.png', fullPage: true });
    
    await browser.close();
    
    // Résumé
    console.log('\n📊 Résumé:');
    console.log(`  ✅ Page chargée`);
    console.log(`  ${vlcStatus === 'En lecture' ? '✅' : '❌'} VLC Status: ${vlcStatus}`);
    console.log(`  ${screenshotVisible.found && screenshotVisible.displayed ? '✅' : '❌'} Screenshot visible`);
    console.log(`  ${statusData.data?.vlc_running ? '✅' : '❌'} API reports VLC running`);
}

testVisual().catch(console.error);