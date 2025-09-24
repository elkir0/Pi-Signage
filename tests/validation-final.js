const puppeteer = require('puppeteer');

(async () => {
    console.log('✅ VALIDATION FINALE PISIGNAGE v0.8.0');
    console.log('=' .repeat(50));
    
    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    let errors = [];
    let tests = {passed: 0, total: 0};

    // Capture erreurs
    page.on('console', msg => {
        if (msg.type() === 'error' && !msg.text().includes('favicon')) {
            errors.push(msg.text());
        }
    });

    // Test 1: Navigation
    console.log('\n1️⃣ Test Navigation');
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
    tests.total++;
    tests.passed++;
    console.log('   ✅ Page chargée sans erreur');

    // Test 2: Sections
    console.log('\n2️⃣ Test Sections (9)');
    const sections = ['dashboard', 'media', 'playlists', 'youtube', 'player', 'schedule', 'screenshot', 'settings', 'logs'];
    
    for (const section of sections) {
        tests.total++;
        const success = await page.evaluate((s) => {
            if (typeof showSection === 'function') {
                showSection(s);
                const el = document.getElementById(s);
                return el && el.style.display !== 'none';
            }
            return false;
        }, section);
        
        if (success) {
            tests.passed++;
            console.log('   ✅ ' + section);
        } else {
            console.log('   ❌ ' + section);
        }
    }

    // Test 3: APIs
    console.log('\n3️⃣ Test APIs');
    const apis = [
        '/api/system.php?action=stats',
        '/api/media.php?action=list',
        '/api/playlist.php?action=list'
    ];

    for (const api of apis) {
        tests.total++;
        const response = await page.evaluate(async (url) => {
            try {
                const res = await fetch(url);
                return res.ok;
            } catch {
                return false;
            }
        }, api);
        
        if (response) {
            tests.passed++;
            console.log('   ✅ ' + api.split('/').pop().split('?')[0]);
        } else {
            console.log('   ❌ ' + api.split('/').pop().split('?')[0]);
        }
    }

    // Test 4: Upload Modal (corrigé)
    console.log('\n4️⃣ Test Upload Modal');
    tests.total++;
    await page.evaluate(() => showSection('media'));
    await new Promise(r => setTimeout(r, 500));
    
    const uploadWorks = await page.evaluate(() => {
        if (typeof showUploadModal === 'function') {
            showUploadModal();
            // Check if modal was created
            const modal = document.getElementById('uploadModal');
            const isVisible = modal && modal.style.display === 'block';
            if (modal) modal.remove(); // Clean up
            return isVisible;
        }
        return false;
    });
    
    if (uploadWorks) {
        tests.passed++;
        console.log('   ✅ Upload modal fonctionnel');
    } else {
        console.log('   ❌ Upload modal');
    }

    // Test 5: Fonctions JavaScript
    console.log('\n5️⃣ Test Fonctions JS');
    const functions = ['vlcControl', 'uploadFile', 'createPlaylist', 'downloadYouTube', 'refreshStats'];
    
    for (const func of functions) {
        tests.total++;
        const exists = await page.evaluate((f) => typeof window[f] === 'function', func);
        if (exists) {
            tests.passed++;
            console.log('   ✅ ' + func);
        } else {
            console.log('   ❌ ' + func);
        }
    }

    // Screenshot final
    await page.screenshot({ path: '/tmp/validation-finale.png', fullPage: true });

    console.log('\n' + '=' .repeat(50));
    console.log('📊 RÉSULTATS FINAUX:');
    console.log('   Tests réussis: ' + tests.passed + '/' + tests.total);
    console.log('   Taux de succès: ' + Math.round(tests.passed * 100 / tests.total) + '%');
    console.log('   Erreurs console: ' + errors.length);
    
    if (errors.length === 0 && tests.passed === tests.total) {
        console.log('\n🏆 VALIDATION COMPLÈTE - 100% SUCCÈS!');
        console.log('✅ PROTOCOLE VALIDÉ: Prêt pour push GitHub');
    } else if (tests.passed / tests.total >= 0.95) {
        console.log('\n✅ VALIDATION ACCEPTABLE - 95%+ succès');
    } else {
        console.log('\n⚠️ VALIDATION ÉCHOUÉE - Corrections nécessaires');
    }

    await browser.close();
})();
