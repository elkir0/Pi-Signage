const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function testPiSignageComplete() {
    console.log('🔍 TESTS PUPPETEER CRITIQUES COMPLETS - PiSignage v0.8.0');
    console.log('🎯 URL: http://192.168.1.103/');

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
        dashboardVisible: false,
        lecteurTabFound: false,
        lecteurTabClicked: false,
        captureButtonFound: false,
        captureButtonClicked: false,
        playerModeSelector: false,
        applyPlayerSettingsFunction: false,
        consoleErrors: [],
        screenshots: []
    };

    try {
        // Capturer erreurs console
        page.on('console', msg => {
            if (msg.type() === 'error') {
                console.log('❌ Console Error:', msg.text());
                testResults.consoleErrors.push(msg.text());
            }
        });

        // Navigation
        console.log('\n📍 TEST 1: Navigation vers http://192.168.1.103/');
        const response = await page.goto('http://192.168.1.103/', {
            waitUntil: 'networkidle2',
            timeout: 15000
        });

        if (response && response.status() === 200) {
            console.log('✅ Navigation réussie - Status 200');
            testResults.navigation = true;
        }

        await new Promise(resolve => setTimeout(resolve, 3000));

        // Screenshot dashboard
        console.log('\n📸 TEST 2: Screenshot Dashboard');
        const dashboardPath = path.join(screenshotDir, 'dashboard-complete.png');
        await page.screenshot({ path: dashboardPath, fullPage: true });
        testResults.screenshots.push('dashboard-complete.png');
        console.log('✅ Screenshot dashboard:', dashboardPath);

        // Vérifier titre PiSignage
        const title = await page.title();
        console.log('📋 Titre page:', title);
        if (title.includes('PiSignage')) {
            testResults.dashboardVisible = true;
            console.log('✅ Dashboard PiSignage visible');
        }

        // TEST 3: Rechercher onglet Lecteur
        console.log('\n📍 TEST 3: Recherche onglet Lecteur');

        // Méthode 1: Recherche par sélecteur href
        let lecteurTab = await page.$('a[href="#lecteur"]');
        if (!lecteurTab) {
            // Méthode 2: Recherche par texte via XPath
            const lecteurXPath = await page.$x("//a[contains(text(), 'Lecteur')]");
            if (lecteurXPath.length > 0) {
                lecteurTab = lecteurXPath[0];
            }
        }

        if (!lecteurTab) {
            // Méthode 3: Recherche par classe ou ID
            lecteurTab = await page.$('.nav-lecteur, #tab-lecteur, [data-tab="lecteur"]');
        }

        if (lecteurTab) {
            console.log('✅ Onglet Lecteur trouvé');
            testResults.lecteurTabFound = true;

            try {
                await lecteurTab.click();
                await new Promise(resolve => setTimeout(resolve, 2000));
                console.log('✅ Clic sur onglet Lecteur réussi');
                testResults.lecteurTabClicked = true;
            } catch (error) {
                console.log('⚠️ Erreur clic Lecteur:', error.message);
            }
        } else {
            console.log('❌ Onglet Lecteur non trouvé');
        }

        // Screenshot après clic Lecteur
        console.log('\n📸 TEST 4: Screenshot mode Lecteur');
        const lecteurPath = path.join(screenshotDir, 'lecteur-mode.png');
        await page.screenshot({ path: lecteurPath, fullPage: true });
        testResults.screenshots.push('lecteur-mode.png');
        console.log('✅ Screenshot lecteur:', lecteurPath);

        // TEST 5: Rechercher bouton Capture
        console.log('\n📍 TEST 5: Recherche bouton Capture');

        // Recherche multiple pour bouton capture
        const captureSelectors = [
            'button:contains("Capture")',
            '#captureBtn',
            '.capture-btn',
            'button[onclick*="capture"]',
            'button[onclick*="screenshot"]'
        ];

        let captureButton = null;

        // Méthode XPath pour texte exact
        const captureXPath = await page.$x("//button[contains(text(), 'Capture')]");
        if (captureXPath.length > 0) {
            captureButton = captureXPath[0];
        }

        if (captureButton) {
            console.log('✅ Bouton Capture trouvé');
            testResults.captureButtonFound = true;

            try {
                await captureButton.click();
                await new Promise(resolve => setTimeout(resolve, 3000));
                console.log('✅ Clic sur bouton Capture réussi');
                testResults.captureButtonClicked = true;
            } catch (error) {
                console.log('⚠️ Erreur clic Capture:', error.message);
            }
        } else {
            console.log('❌ Bouton Capture non trouvé - analyse des boutons...');

            // Analyser tous les boutons
            const allButtons = await page.$$eval('button', buttons =>
                buttons.map(btn => ({
                    text: btn.textContent.trim(),
                    id: btn.id,
                    className: btn.className,
                    onclick: btn.onclick ? btn.onclick.toString() : null
                }))
            );
            console.log('📋 Boutons trouvés:', allButtons);
        }

        // TEST 6: Rechercher sélecteur mode lecteur
        console.log('\n📍 TEST 6: Recherche sélecteur mode lecteur');

        const playerModeSelectors = [
            '#playerMode',
            'select[name="playerMode"]',
            '.player-mode-selector',
            'select[id*="mode"]',
            'select[name*="mode"]'
        ];

        let playerSelector = null;
        for (const selector of playerModeSelectors) {
            try {
                playerSelector = await page.$(selector);
                if (playerSelector) break;
            } catch (e) {
                // Ignorer erreurs sélecteur
            }
        }

        if (playerSelector) {
            console.log('✅ Sélecteur mode lecteur trouvé');
            testResults.playerModeSelector = true;

            // Vérifier options
            const options = await page.$$eval('#playerMode option, select[name="playerMode"] option',
                options => options.map(opt => ({ value: opt.value, text: opt.textContent.trim() }))
            );
            console.log('📋 Options mode lecteur:', options);
        } else {
            console.log('❌ Sélecteur mode lecteur non trouvé');
        }

        // TEST 7: Vérifier fonction applyPlayerSettings
        console.log('\n📍 TEST 7: Vérification fonction applyPlayerSettings');

        const hasApplyFunction = await page.evaluate(() => {
            return typeof window.applyPlayerSettings === 'function';
        });

        if (hasApplyFunction) {
            console.log('✅ Fonction applyPlayerSettings trouvée');
            testResults.applyPlayerSettingsFunction = true;
        } else {
            console.log('❌ Fonction applyPlayerSettings non trouvée');

            // Analyser toutes les fonctions disponibles
            const allFunctions = await page.evaluate(() => {
                const functions = [];
                for (let prop in window) {
                    if (typeof window[prop] === 'function' && prop.includes('player') || prop.includes('apply')) {
                        functions.push(prop);
                    }
                }
                return functions;
            });
            console.log('📋 Fonctions liées au lecteur:', allFunctions);
        }

        // Screenshot final
        console.log('\n📸 TEST 8: Screenshot final');
        const finalPath = path.join(screenshotDir, 'final-state.png');
        await page.screenshot({ path: finalPath, fullPage: true });
        testResults.screenshots.push('final-state.png');
        console.log('✅ Screenshot final:', finalPath);

        // TEST 9: Analyse DOM complète
        console.log('\n📍 TEST 9: Analyse DOM complète');

        const domAnalysis = await page.evaluate(() => {
            return {
                title: document.title,
                totalButtons: document.querySelectorAll('button').length,
                totalLinks: document.querySelectorAll('a').length,
                totalSelects: document.querySelectorAll('select').length,
                buttonTexts: Array.from(document.querySelectorAll('button')).map(btn => btn.textContent.trim()).filter(text => text.length > 0),
                linkTexts: Array.from(document.querySelectorAll('a')).map(link => link.textContent.trim()).filter(text => text.length > 0),
                selectNames: Array.from(document.querySelectorAll('select')).map(select => select.name || select.id).filter(name => name),
                hasJavaScript: document.querySelectorAll('script').length > 0
            };
        });

        console.log('📊 Analyse DOM:');
        console.log('- Titre:', domAnalysis.title);
        console.log('- Boutons total:', domAnalysis.totalButtons);
        console.log('- Liens total:', domAnalysis.totalLinks);
        console.log('- Sélecteurs total:', domAnalysis.totalSelects);
        console.log('- Textes boutons:', domAnalysis.buttonTexts);
        console.log('- JavaScript présent:', domAnalysis.hasJavaScript);

    } catch (error) {
        console.log('💥 Erreur durant les tests:', error.message);
        testResults.consoleErrors.push(`Test Error: ${error.message}`);
    } finally {
        await browser.close();
    }

    // RÉSUMÉ FINAL
    console.log('\n' + '='.repeat(60));
    console.log('📊 RÉSUMÉ COMPLET DES TESTS PUPPETEER');
    console.log('='.repeat(60));
    console.log('✅ Navigation HTTP:', testResults.navigation ? 'OK' : 'ÉCHEC');
    console.log('✅ Dashboard visible:', testResults.dashboardVisible ? 'OK' : 'ÉCHEC');
    console.log('✅ Onglet Lecteur trouvé:', testResults.lecteurTabFound ? 'OK' : 'ÉCHEC');
    console.log('✅ Onglet Lecteur cliqué:', testResults.lecteurTabClicked ? 'OK' : 'ÉCHEC');
    console.log('✅ Bouton Capture trouvé:', testResults.captureButtonFound ? 'OK' : 'ÉCHEC');
    console.log('✅ Bouton Capture cliqué:', testResults.captureButtonClicked ? 'OK' : 'ÉCHEC');
    console.log('✅ Sélecteur mode lecteur:', testResults.playerModeSelector ? 'OK' : 'ÉCHEC');
    console.log('✅ Fonction applyPlayerSettings:', testResults.applyPlayerSettingsFunction ? 'OK' : 'ÉCHEC');

    console.log('\n📸 SCREENSHOTS GÉNÉRÉS:');
    testResults.screenshots.forEach(screenshot => {
        console.log(`- ${screenshot}`);
    });

    if (testResults.consoleErrors.length > 0) {
        console.log('\n❌ ERREURS CONSOLE:');
        testResults.consoleErrors.forEach((error, index) => {
            console.log(`${index + 1}. ${error}`);
        });
    } else {
        console.log('\n✅ AUCUNE ERREUR CRITIQUE DÉTECTÉE');
    }

    const successRate = Object.values(testResults).filter(result => result === true).length;
    const totalTests = Object.keys(testResults).filter(key => typeof testResults[key] === 'boolean').length;
    console.log(`\n🎯 TAUX DE RÉUSSITE: ${successRate}/${totalTests} (${Math.round(successRate/totalTests*100)}%)`);

    return testResults;
}

// Exécution des tests
testPiSignageComplete().then(results => {
    console.log('\n🏁 TESTS PUPPETEER TERMINÉS AVEC SUCCÈS');
}).catch(error => {
    console.error('💥 ÉCHEC CRITIQUE:', error);
    process.exit(1);
});