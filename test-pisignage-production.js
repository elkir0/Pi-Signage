const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function testPiSignageProduction() {
    console.log('🔍 DÉBUT DES TESTS PUPPETEER CRITIQUES - PiSignage Production');
    console.log('🎯 URL: http://192.168.1.103/');
    console.log('📋 Tests requis: Navigation, Screenshots, Lecteur, Boutons, Console');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });

    // Créer dossier pour screenshots
    const screenshotDir = '/tmp/pisignage-screenshots';
    if (!fs.existsSync(screenshotDir)) {
        fs.mkdirSync(screenshotDir, { recursive: true });
    }

    let testResults = {
        navigation: false,
        dashboardScreenshot: false,
        lecteurTab: false,
        lecteurScreenshot: false,
        screenshotButtons: false,
        playerModeSelector: false,
        consoleErrors: [],
        screenshots: []
    };

    try {
        console.log('\n📍 TEST 1: Navigation vers http://192.168.1.103/');

        // Capturer les erreurs console
        page.on('console', msg => {
            if (msg.type() === 'error') {
                console.log('❌ Erreur Console:', msg.text());
                testResults.consoleErrors.push(msg.text());
            } else if (msg.type() === 'warn') {
                console.log('⚠️ Avertissement Console:', msg.text());
            } else {
                console.log('ℹ️ Console:', msg.text());
            }
        });

        page.on('pageerror', error => {
            console.log('💥 Erreur Page:', error.message);
            testResults.consoleErrors.push(`Page Error: ${error.message}`);
        });

        // Navigation initiale
        const response = await page.goto('http://192.168.1.103/', {
            waitUntil: 'networkidle2',
            timeout: 10000
        });

        if (response && response.status() === 200) {
            console.log('✅ Navigation réussie - Status 200');
            testResults.navigation = true;
        } else {
            console.log('❌ Navigation échouée - Status:', response ? response.status() : 'timeout');
        }

        // Attendre que la page soit complètement chargée
        await new Promise(resolve => setTimeout(resolve, 3000));

        console.log('\n📸 TEST 2: Screenshot du dashboard avec bouton screenshot');

        // Screenshot du dashboard initial
        const dashboardPath = path.join(screenshotDir, 'dashboard-initial.png');
        await page.screenshot({ path: dashboardPath, fullPage: true });
        console.log('✅ Screenshot dashboard sauvé:', dashboardPath);
        testResults.dashboardScreenshot = true;
        testResults.screenshots.push('dashboard-initial.png');

        // Vérifier la présence du bouton screenshot dans le dashboard
        console.log('\n🔍 Recherche du bouton screenshot dans le dashboard...');
        const dashboardScreenshotButton = await page.$('#screenshotBtn, .screenshot-btn, button[onclick*="screenshot"], button:contains("Screenshot")');
        if (dashboardScreenshotButton) {
            console.log('✅ Bouton screenshot trouvé dans le dashboard');
        } else {
            console.log('⚠️ Bouton screenshot non trouvé dans le dashboard - recherche alternative...');
            // Recherche alternative
            const allButtons = await page.$$eval('button', buttons =>
                buttons.map(btn => ({ text: btn.textContent, onclick: btn.onclick?.toString() || '' }))
            );
            console.log('📋 Boutons trouvés:', allButtons);
        }

        console.log('\n📍 TEST 3: Navigation vers l\'onglet Lecteur');

        // Rechercher et cliquer sur l'onglet Lecteur
        const lecteurTab = await page.$('a[href="#lecteur"], .nav-link[href="#lecteur"], [data-tab="lecteur"]');
        if (lecteurTab) {
            console.log('✅ Onglet Lecteur trouvé, clic...');
            await lecteurTab.click();
            await new Promise(resolve => setTimeout(resolve, 2000));
            testResults.lecteurTab = true;
        } else {
            console.log('⚠️ Onglet Lecteur non trouvé - recherche alternative...');
            // Recherche alternative par texte
            const lecteurLink = await page.$x("//a[contains(text(), 'Lecteur')]");
            if (lecteurLink.length > 0) {
                console.log('✅ Lien Lecteur trouvé par texte, clic...');
                await lecteurLink[0].click();
                await new Promise(resolve => setTimeout(resolve, 2000));
                testResults.lecteurTab = true;
            } else {
                console.log('❌ Onglet Lecteur non trouvé');
            }
        }

        console.log('\n📸 TEST 4: Screenshot du mode Lecteur');

        // Screenshot du mode lecteur
        const lecteurPath = path.join(screenshotDir, 'lecteur-mode.png');
        await page.screenshot({ path: lecteurPath, fullPage: true });
        console.log('✅ Screenshot lecteur sauvé:', lecteurPath);
        testResults.lecteurScreenshot = true;
        testResults.screenshots.push('lecteur-mode.png');

        console.log('\n🔍 TEST 5: Vérification des boutons screenshot');

        // Rechercher tous les boutons screenshot
        const screenshotButtons = await page.$$('button[onclick*="screenshot"], #screenshotBtn, .screenshot-btn');
        console.log(`📋 ${screenshotButtons.length} bouton(s) screenshot trouvé(s)`);

        if (screenshotButtons.length > 0) {
            testResults.screenshotButtons = true;

            // Tester le premier bouton screenshot
            try {
                console.log('🖱️ Test du bouton screenshot...');
                await screenshotButtons[0].click();
                await new Promise(resolve => setTimeout(resolve, 3000));
                console.log('✅ Bouton screenshot cliqué sans erreur');
            } catch (error) {
                console.log('❌ Erreur lors du clic sur bouton screenshot:', error.message);
                testResults.consoleErrors.push(`Screenshot button error: ${error.message}`);
            }
        } else {
            console.log('❌ Aucun bouton screenshot trouvé');
        }

        console.log('\n🔍 TEST 6: Vérification du sélecteur de mode lecteur');

        // Rechercher le sélecteur de mode lecteur
        const playerModeSelector = await page.$('#playerMode, select[name="playerMode"], .player-mode-selector');
        if (playerModeSelector) {
            console.log('✅ Sélecteur de mode lecteur trouvé');
            testResults.playerModeSelector = true;

            // Vérifier les options
            const options = await page.$$eval('#playerMode option, select[name="playerMode"] option',
                options => options.map(opt => ({ value: opt.value, text: opt.textContent }))
            );
            console.log('📋 Options du sélecteur:', options);

            if (options.length >= 3) {
                console.log('✅ Au moins 3 options trouvées dans le sélecteur');
            } else {
                console.log('⚠️ Moins de 3 options dans le sélecteur');
            }
        } else {
            console.log('❌ Sélecteur de mode lecteur non trouvé');
        }

        console.log('\n🔍 TEST 7: Vérification de la fonction applyPlayerSettings');

        // Vérifier si la fonction applyPlayerSettings existe
        const applyPlayerSettingsExists = await page.evaluate(() => {
            return typeof window.applyPlayerSettings === 'function';
        });

        if (applyPlayerSettingsExists) {
            console.log('✅ Fonction applyPlayerSettings trouvée');
        } else {
            console.log('❌ Fonction applyPlayerSettings non trouvée');
        }

        console.log('\n📸 TEST 8: Screenshot final avec détails');

        // Screenshot final détaillé
        const finalPath = path.join(screenshotDir, 'final-state.png');
        await page.screenshot({ path: finalPath, fullPage: true });
        console.log('✅ Screenshot final sauvé:', finalPath);
        testResults.screenshots.push('final-state.png');

        console.log('\n📋 TEST 9: Analyse du DOM pour éléments manqués');

        // Analyser le DOM pour trouver tous les éléments pertinents
        const domAnalysis = await page.evaluate(() => {
            const analysis = {
                title: document.title,
                buttons: Array.from(document.querySelectorAll('button')).map(btn => ({
                    text: btn.textContent.trim(),
                    id: btn.id,
                    className: btn.className,
                    onclick: btn.onclick ? btn.onclick.toString() : null
                })),
                links: Array.from(document.querySelectorAll('a')).map(link => ({
                    text: link.textContent.trim(),
                    href: link.href,
                    id: link.id,
                    className: link.className
                })),
                selects: Array.from(document.querySelectorAll('select')).map(select => ({
                    id: select.id,
                    name: select.name,
                    options: Array.from(select.options).map(opt => ({ value: opt.value, text: opt.textContent }))
                }))
            };
            return analysis;
        });

        console.log('📊 Analyse DOM complète:');
        console.log('- Titre:', domAnalysis.title);
        console.log('- Boutons:', domAnalysis.buttons.length);
        console.log('- Liens:', domAnalysis.links.length);
        console.log('- Sélecteurs:', domAnalysis.selects.length);

    } catch (error) {
        console.log('💥 Erreur durant les tests:', error.message);
        testResults.consoleErrors.push(`Test Error: ${error.message}`);
    } finally {
        await browser.close();
    }

    console.log('\n📊 RÉSUMÉ DES TESTS:');
    console.log('✅ Navigation:', testResults.navigation ? 'OK' : 'ÉCHEC');
    console.log('✅ Screenshot Dashboard:', testResults.dashboardScreenshot ? 'OK' : 'ÉCHEC');
    console.log('✅ Onglet Lecteur:', testResults.lecteurTab ? 'OK' : 'ÉCHEC');
    console.log('✅ Screenshot Lecteur:', testResults.lecteurScreenshot ? 'OK' : 'ÉCHEC');
    console.log('✅ Boutons Screenshot:', testResults.screenshotButtons ? 'OK' : 'ÉCHEC');
    console.log('✅ Sélecteur Mode:', testResults.playerModeSelector ? 'OK' : 'ÉCHEC');
    console.log('❌ Erreurs Console:', testResults.consoleErrors.length);
    console.log('📸 Screenshots:', testResults.screenshots.length);

    if (testResults.consoleErrors.length > 0) {
        console.log('\n🔍 DÉTAIL DES ERREURS:');
        testResults.consoleErrors.forEach((error, index) => {
            console.log(`${index + 1}. ${error}`);
        });
    }

    console.log('\n📁 Screenshots sauvés dans:', screenshotDir);
    testResults.screenshots.forEach(screenshot => {
        console.log(`- ${screenshot}`);
    });

    return testResults;
}

// Exécution des tests
testPiSignageProduction().then(results => {
    console.log('\n🎯 TESTS PUPPETEER TERMINÉS');
    console.log('📊 Résultats disponibles pour analyse');
}).catch(error => {
    console.error('💥 ÉCHEC CRITIQUE DES TESTS:', error);
    process.exit(1);
});