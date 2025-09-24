const puppeteer = require('puppeteer');

(async () => {
    console.log('🔍 Analyse complète des erreurs PiSignage');
    console.log('🎯 URL: http://192.168.1.103/\n');

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    const errors = [];
    const resources404 = [];

    // Capture tous les messages console
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();

        if (type === 'error') {
            errors.push(text);
            console.log('❌ Console Error: ' + text);
        }
    });

    // Capture les réponses 404
    page.on('response', response => {
        if (response.status() === 404) {
            const url = response.url();
            resources404.push(url);
            const filename = url.substring(url.lastIndexOf('/') + 1);
            console.log('🔴 404: ' + filename);
        }
    });

    // Navigation
    console.log('📍 Navigation vers la page...');
    await page.goto('http://192.168.1.103/', {
        waitUntil: 'networkidle2',
        timeout: 30000
    });

    // Attendre pour capturer tous les messages
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Tester les fonctions JavaScript
    console.log('\n🔧 Test des fonctions JavaScript:');

    const functions = await page.evaluate(() => {
        const funcs = {};

        // Vérifier les fonctions principales
        const toCheck = ['showSection', 'vlcControl', 'uploadFile',
                        'createPlaylist', 'downloadYouTube', 'captureManual',
                        'refreshStats', 'refreshLogs', 'applyPlayerSettings'];

        toCheck.forEach(func => {
            funcs[func] = typeof window[func] === 'function';
        });

        return funcs;
    });

    Object.entries(functions).forEach(([name, exists]) => {
        console.log('   ' + name + ': ' + (exists ? '✅' : '❌'));
    });

    // Test de navigation
    console.log('\n📱 Test navigation:');

    const navTest = await page.evaluate(() => {
        const navItems = document.querySelectorAll('.nav-item');
        const results = [];

        navItems.forEach(item => {
            const onclick = item.getAttribute('onclick');
            results.push({
                text: item.textContent.trim(),
                hasOnclick: !!onclick,
                onclick: onclick
            });
        });

        return results;
    });

    navTest.forEach(item => {
        console.log('   ' + item.text + ': ' + (item.hasOnclick ? '✅' : '❌') + ' ' + (item.onclick || ''));
    });

    // Screenshot
    await page.screenshot({
        path: '/tmp/pisignage-debug.png',
        fullPage: true
    });

    console.log('\n📊 RÉSUMÉ:');
    console.log('   Erreurs console: ' + errors.length);
    console.log('   404 (hors favicon): ' + resources404.filter(u => !u.includes('favicon')).length);

    if (errors.length === 0 && resources404.filter(u => !u.includes('favicon')).length === 0) {
        console.log('\n✅ AUCUNE ERREUR CRITIQUE DÉTECTÉE!');
    } else {
        console.log('\n⚠️ Des erreurs ont été détectées');
    }

    await browser.close();
})();
