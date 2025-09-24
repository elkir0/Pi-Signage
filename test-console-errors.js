const puppeteer = require('puppeteer');

(async () => {
    console.log('🔍 Analyse des erreurs console PiSignage');
    console.log('🎯 URL: http://192.168.1.103/\n');

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    
    const errors = [];
    const warnings = [];
    const logs = [];
    const resources404 = [];

    // Capture tous les messages console
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        
        if (type === 'error') {
            errors.push(text);
            console.log(`❌ Console Error: ${text}`);
        } else if (type === 'warning') {
            warnings.push(text);
            console.log(`⚠️ Console Warning: ${text}`);
        } else {
            logs.push(text);
        }
    });

    // Capture les erreurs de chargement de ressources
    page.on('requestfailed', request => {
        const url = request.url();
        const failure = request.failure();
        if (failure) {
            console.log(`❌ Request Failed: ${url} - ${failure.errorText}`);
        }
    });

    // Capture les réponses 404
    page.on('response', response => {
        if (response.status() === 404) {
            const url = response.url();
            resources404.push(url);
            console.log(`🔴 404 Not Found: ${url}`);
        }
    });

    // Navigation
    console.log('📍 Navigation vers la page...');
    await page.goto('http://192.168.1.103/', { 
        waitUntil: 'networkidle2',
        timeout: 30000 
    });

    // Attendre un peu pour capturer tous les messages
    await page.waitForTimeout(2000);

    // Analyser le DOM pour les scripts/liens cassés
    const brokenLinks = await page.evaluate(() => {
        const broken = [];
        
        // Vérifier les scripts
        document.querySelectorAll('script[src]').forEach(script => {
            if (!script.src) return;
            // On ne peut pas vérifier directement, mais on peut logger
            broken.push({ type: 'script', url: script.src });
        });
        
        // Vérifier les liens CSS
        document.querySelectorAll('link[rel="stylesheet"]').forEach(link => {
            if (!link.href) return;
            broken.push({ type: 'css', url: link.href });
        });
        
        return broken;
    });

    console.log('\n📊 RÉSUMÉ DES PROBLÈMES:');
    console.log('========================');
    console.log(`Erreurs console: ${errors.length}`);
    console.log(`Warnings: ${warnings.length}`);
    console.log(`404 Not Found: ${resources404.length}`);
    
    if (resources404.length > 0) {
        console.log('\n🔴 Ressources 404:');
        resources404.forEach(url => {
            console.log(`   - ${url}`);
        });
    }

    if (errors.length > 0) {
        console.log('\n❌ Erreurs détaillées:');
        errors.forEach((err, i) => {
            console.log(`   ${i+1}. ${err}`);
        });
    }

    await browser.close();
    console.log('\n✅ Analyse terminée');
})();
