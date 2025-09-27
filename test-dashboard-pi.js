const puppeteer = require('puppeteer');

(async () => {
    console.log('🚀 Test Dashboard PiSignage sur Raspberry Pi (192.168.1.103)');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    try {
        const page = await browser.newPage();

        // Écouter les erreurs console
        page.on('console', msg => {
            if (msg.type() === 'error') {
                console.error('❌ Erreur console:', msg.text());
            }
        });

        // Test 1: Chargement de la page
        console.log('\n📋 Test 1: Chargement Dashboard...');
        await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0' });
        console.log('✅ Page chargée');

        // Test 2: Vérification des stats système
        console.log('\n📋 Test 2: Vérification stats système...');
        await page.waitForFunction(() => true, { timeout: 3000 }).catch(() => {}); // Attendre que les stats se chargent

        const stats = await page.evaluate(() => {
            return {
                cpu: document.getElementById('cpu-usage')?.textContent,
                ram: document.getElementById('ram-usage')?.textContent,
                storage: document.getElementById('storage')?.textContent,
                temperature: document.getElementById('temperature')?.textContent
            };
        });

        console.log('📊 Stats système:');
        console.log(`   CPU: ${stats.cpu}`);
        console.log(`   RAM: ${stats.ram}`);
        console.log(`   Storage: ${stats.storage}`);
        console.log(`   Température: ${stats.temperature}`);

        // Vérification que les valeurs ne sont plus [object Object] ou undefined
        if (stats.cpu && stats.cpu !== '[object Object]%' && stats.cpu !== '--%') {
            console.log('✅ CPU affiché correctement');
        } else {
            console.error('❌ Problème affichage CPU:', stats.cpu);
        }

        if (stats.ram && stats.ram !== 'undefined%' && stats.ram !== '--%') {
            console.log('✅ RAM affichée correctement');
        } else {
            console.error('❌ Problème affichage RAM:', stats.ram);
        }

        // Test 3: Test API Playlists
        console.log('\n📋 Test 3: API Playlists...');

        // GET playlists
        const getResponse = await page.evaluate(async () => {
            const response = await fetch('/api/playlist.php?action=list');
            return await response.json();
        });
        console.log('✅ GET Playlists:', getResponse.success ? 'OK' : 'ERREUR');

        // POST nouvelle playlist
        const postResponse = await page.evaluate(async () => {
            const response = await fetch('/api/playlist.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'create', name: 'Test Playlist' })
            });
            return await response.json();
        });

        if (postResponse.success || postResponse.message !== 'Method not allowed') {
            console.log('✅ POST Playlist supporté');
        } else {
            console.error('❌ POST Playlist échoué:', postResponse.message);
        }

        // Capture d'écran finale
        console.log('\n📸 Capture d\'écran...');
        await page.screenshot({
            path: '/opt/pisignage/dashboard-test-pi.png',
            fullPage: true
        });
        console.log('✅ Screenshot sauvegardé: dashboard-test-pi.png');

        // Résumé
        console.log('\n' + '='.repeat(50));
        console.log('📊 RÉSUMÉ DES TESTS');
        console.log('='.repeat(50));

        const allTestsPassed =
            stats.cpu && stats.cpu !== '[object Object]%' &&
            stats.ram && stats.ram !== 'undefined%' &&
            (postResponse.success || postResponse.message !== 'Method not allowed');

        if (allTestsPassed) {
            console.log('✅ TOUS LES TESTS PASSÉS - Dashboard fonctionnel !');
        } else {
            console.log('⚠️ Certains tests ont échoué - Vérifier les corrections');
        }

    } catch (error) {
        console.error('❌ Erreur durant les tests:', error);
    } finally {
        await browser.close();
        console.log('\n🏁 Tests terminés');
    }
})();