const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
    console.log('🧪 TEST COMPLET DES FONCTIONNALITÉS PISIGNAGE v0.8.0');
    console.log('=' .repeat(60));
    
    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    const results = {
        errors: [],
        successes: [],
        features: {}
    };

    // Capture des erreurs console
    page.on('console', msg => {
        if (msg.type() === 'error') {
            results.errors.push(msg.text());
        }
    });

    console.log('\n📍 1. NAVIGATION ET CHARGEMENT');
    await page.goto('http://192.168.1.103/', {
        waitUntil: 'networkidle2',
        timeout: 30000
    });
    console.log('✅ Page chargée');

    // Test favicon
    const favicon = await page.evaluate(() => {
        const link = document.querySelector('link[rel*="icon"]');
        return link ? link.href : null;
    });
    console.log('✅ Favicon: ' + (favicon ? 'présent' : 'absent'));

    // Screenshot initial
    await page.screenshot({ path: '/tmp/test-1-initial.png' });

    console.log('\n📍 2. TEST NAVIGATION SECTIONS');
    const sections = ['dashboard', 'media', 'playlists', 'youtube', 'player', 'schedule', 'screenshot', 'settings', 'logs'];
    
    for (const section of sections) {
        try {
            await page.evaluate((s) => {
                if (typeof showSection === 'function') {
                    showSection(s);
                }
            }, section);
            await new Promise(r => setTimeout(r, 500));
            
            const isVisible = await page.evaluate((s) => {
                const el = document.getElementById(s);
                return el && el.style.display !== 'none';
            }, section);
            
            console.log('   ' + section + ': ' + (isVisible ? '✅' : '❌'));
            results.features[section] = isVisible;
            
            if (isVisible) {
                await page.screenshot({ path: '/tmp/test-2-' + section + '.png' });
            }
        } catch (e) {
            console.log('   ' + section + ': ❌ Erreur');
            results.features[section] = false;
        }
    }

    console.log('\n📍 3. TEST APIS AJAX');
    
    // Test refreshStats
    const statsResult = await page.evaluate(async () => {
        try {
            await refreshStats();
            const cpu = document.querySelector('.stat-value');
            return cpu ? cpu.textContent : null;
        } catch (e) {
            return 'error: ' + e.message;
        }
    });
    console.log('   refreshStats: ' + (statsResult && !statsResult.startsWith('error') ? '✅' : '❌'));

    // Test API media list
    const mediaList = await page.evaluate(async () => {
        try {
            const response = await fetch('/api/media.php?action=list');
            return response.ok;
        } catch (e) {
            return false;
        }
    });
    console.log('   API media.php: ' + (mediaList ? '✅' : '❌'));

    // Test API system
    const systemApi = await page.evaluate(async () => {
        try {
            const response = await fetch('/api/system.php?action=stats');
            return response.ok;
        } catch (e) {
            return false;
        }
    });
    console.log('   API system.php: ' + (systemApi ? '✅' : '❌'));

    console.log('\n📍 4. TEST FONCTIONS INTERACTIVES');
    
    // Test upload modal
    await page.evaluate(() => showSection('media'));
    await new Promise(r => setTimeout(r, 500));
    
    const uploadModal = await page.evaluate(() => {
        const modal = document.getElementById('uploadModal');
        if (modal && typeof showUploadModal === 'function') {
            showUploadModal();
            return modal.style.display !== 'none';
        }
        return false;
    });
    console.log('   Upload modal: ' + (uploadModal ? '✅' : '❌'));
    
    if (uploadModal) {
        await page.screenshot({ path: '/tmp/test-3-upload-modal.png' });
        // Fermer le modal
        await page.evaluate(() => {
            const modal = document.getElementById('uploadModal');
            if (modal) modal.style.display = 'none';
        });
    }

    // Test player controls
    await page.evaluate(() => showSection('player'));
    await new Promise(r => setTimeout(r, 500));
    
    const playerControls = await page.evaluate(() => {
        const buttons = document.querySelectorAll('#player button');
        return buttons.length;
    });
    console.log('   Player controls: ' + (playerControls > 0 ? '✅ (' + playerControls + ' boutons)' : '❌'));

    console.log('\n📍 5. VÉRIFICATION FINALE');
    console.log('   Erreurs console: ' + results.errors.length);
    
    if (results.errors.length > 0) {
        console.log('\n❌ ERREURS DÉTECTÉES:');
        results.errors.forEach((err, i) => {
            console.log('   ' + (i+1) + '. ' + err);
        });
    }

    // Compte final
    const totalTests = Object.keys(results.features).length + 5; // sections + autres tests
    const successCount = Object.values(results.features).filter(v => v).length + 
                        (statsResult && !statsResult.startsWith('error') ? 1 : 0) +
                        (mediaList ? 1 : 0) +
                        (systemApi ? 1 : 0) +
                        (uploadModal ? 1 : 0) +
                        (playerControls > 0 ? 1 : 0);

    console.log('\n' + '='.repeat(60));
    console.log('📊 RÉSUMÉ FINAL:');
    console.log('   Tests réussis: ' + successCount + '/' + totalTests);
    console.log('   Taux de réussite: ' + Math.round(successCount * 100 / totalTests) + '%');
    console.log('   Erreurs console: ' + results.errors.length);
    
    if (results.errors.length === 0 && successCount === totalTests) {
        console.log('\n✅ TOUS LES TESTS SONT PASSÉS AVEC SUCCÈS!');
    } else {
        console.log('\n⚠️ Des problèmes ont été détectés');
    }

    await browser.close();
})();
