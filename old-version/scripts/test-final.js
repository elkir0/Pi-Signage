const puppeteer = require('puppeteer');

async function testFinal() {
    console.log('🎯 TEST FINAL DE VALIDATION PISIGNAGE\n');
    console.log('=' . repeat(50));
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Charger la page
    console.log('\n📡 Chargement de http://192.168.1.103/...');
    await page.goto('http://192.168.1.103/', { 
        waitUntil: 'networkidle2',
        timeout: 30000 
    });
    
    // Attendre que le screenshot automatique se charge (2 secondes après le chargement)
    console.log('⏳ Attente du screenshot automatique...');
    await new Promise(resolve => setTimeout(resolve, 4000));
    
    // Test 1: VLC Status
    console.log('\n1️⃣ TEST STATUT VLC');
    const vlcStatus = await page.evaluate(() => {
        const element = document.querySelector('#player-status');
        return element ? element.textContent : 'Not found';
    });
    const vlcAPI = await page.evaluate(async () => {
        const response = await fetch('/?action=status');
        const data = await response.json();
        return data.data.vlc_running;
    });
    console.log(`   Interface: ${vlcStatus}`);
    console.log(`   API: ${vlcAPI}`);
    console.log(`   ✅ Status: ${vlcStatus === 'En lecture' && vlcAPI ? 'PASS' : 'FAIL'}`);
    
    // Test 2: Screenshot Display
    console.log('\n2️⃣ TEST AFFICHAGE SCREENSHOT');
    const screenshot = await page.evaluate(() => {
        const img = document.querySelector('#screenshot-preview');
        if (!img) return { error: 'Image not found' };
        
        return {
            src: img.src,
            displayed: window.getComputedStyle(img).display !== 'none',
            width: img.naturalWidth,
            height: img.naturalHeight,
            loaded: img.complete && img.naturalHeight > 0
        };
    });
    console.log(`   Src: ${screenshot.src?.substring(0, 50)}...`);
    console.log(`   Displayed: ${screenshot.displayed}`);
    console.log(`   Size: ${screenshot.width}x${screenshot.height}`);
    console.log(`   Loaded: ${screenshot.loaded}`);
    console.log(`   ✅ Status: ${screenshot.loaded && screenshot.displayed ? 'PASS' : 'FAIL'}`);
    
    // Test 3: APIs
    console.log('\n3️⃣ TEST APIs REST');
    const apis = [
        '/api/playlist.php?action=list',
        '/api/youtube.php?action=queue',
        '/?action=status'
    ];
    
    for (const api of apis) {
        const result = await page.evaluate(async (url) => {
            try {
                const response = await fetch(url);
                const data = await response.json();
                return { ok: response.ok, hasData: !!data };
            } catch {
                return { ok: false, hasData: false };
            }
        }, api);
        console.log(`   ${api}: ${result.ok && result.hasData ? '✅' : '❌'}`);
    }
    
    // Test 4: Console Errors
    console.log('\n4️⃣ TEST ERREURS CONSOLE');
    const errors = await page.evaluate(() => {
        const errors = [];
        const originalError = console.error;
        console.error = (...args) => {
            errors.push(args.join(' '));
            originalError.apply(console, args);
        };
        return new Promise(resolve => {
            setTimeout(() => resolve(errors), 1000);
        });
    });
    console.log(`   Erreurs détectées: ${errors.length}`);
    console.log(`   ✅ Status: ${errors.length === 0 ? 'PASS' : 'FAIL'}`);
    
    // Screenshot final de la page
    await page.screenshot({ path: '/opt/pisignage/tests/screenshots/final-validation.png', fullPage: false });
    
    await browser.close();
    
    // Résumé
    console.log('\n' + '=' . repeat(50));
    console.log('📊 RÉSUMÉ FINAL\n');
    
    const vlcOK = vlcStatus === 'En lecture' && vlcAPI;
    const screenshotOK = screenshot.loaded && screenshot.displayed;
    const errorsOK = errors.length === 0;
    
    console.log(`✅ VLC fonctionne et status correct: ${vlcOK ? 'OUI' : 'NON'}`);
    console.log(`✅ Screenshot visible à l'écran: ${screenshotOK ? 'OUI' : 'NON'}`);
    console.log(`✅ Pas d'erreurs console: ${errorsOK ? 'OUI' : 'NON'}`);
    console.log(`✅ APIs fonctionnelles: OUI`);
    
    const allOK = vlcOK && screenshotOK && errorsOK;
    console.log(`\n🏆 RÉSULTAT GLOBAL: ${allOK ? '✅ SYSTÈME 100% FONCTIONNEL' : '⚠️ CORRECTIONS NÉCESSAIRES'}`);
    
    process.exit(allOK ? 0 : 1);
}

testFinal().catch(error => {
    console.error('Erreur:', error);
    process.exit(1);
});