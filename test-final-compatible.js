const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function testPiSignageFinal() {
    console.log('🔍 TESTS PUPPETEER FINAUX - PiSignage v0.8.0 Production');
    console.log('🎯 URL: http://192.168.1.103/');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });

    const screenshotDir = '/tmp/pisignage-screenshots';
    if (!fs.existsSync(screenshotDir)) {
        fs.mkdirSync(screenshotDir, { recursive: true });
    }

    let results = {
        navigation: false,
        interface: false,
        lecteur: false,
        capture: false,
        screenshots: []
    };

    try {
        // Navigation
        console.log('\n📍 NAVIGATION vers http://192.168.1.103/');
        const response = await page.goto('http://192.168.1.103/', {
            waitUntil: 'networkidle2',
            timeout: 15000
        });

        if (response && response.status() === 200) {
            console.log('✅ Navigation OK - Status 200');
            results.navigation = true;
        }

        await new Promise(resolve => setTimeout(resolve, 3000));

        // Screenshot 1: Dashboard initial
        console.log('\n📸 SCREENSHOT 1: Dashboard');
        const dashboard = path.join(screenshotDir, 'test1-dashboard.png');
        await page.screenshot({ path: dashboard, fullPage: true });
        results.screenshots.push('test1-dashboard.png');
        console.log('✅ Screenshot dashboard sauvé');

        // Vérifier interface
        const title = await page.title();
        if (title.includes('PiSignage')) {
            console.log('✅ Interface PiSignage chargée - Titre:', title);
            results.interface = true;
        }

        // Rechercher onglet Lecteur par évaluation JavaScript
        console.log('\n📍 RECHERCHE ONGLET LECTEUR');
        const lecteurFound = await page.evaluate(() => {
            // Rechercher par texte dans tous les liens
            const links = Array.from(document.querySelectorAll('a'));
            const lecteurLink = links.find(link =>
                link.textContent.toLowerCase().includes('lecteur')
            );

            if (lecteurLink) {
                lecteurLink.click();
                return true;
            }
            return false;
        });

        if (lecteurFound) {
            console.log('✅ Onglet Lecteur trouvé et cliqué');
            results.lecteur = true;
            await new Promise(resolve => setTimeout(resolve, 2000));
        }

        // Screenshot 2: Mode Lecteur
        console.log('\n📸 SCREENSHOT 2: Mode Lecteur');
        const lecteur = path.join(screenshotDir, 'test2-lecteur.png');
        await page.screenshot({ path: lecteur, fullPage: true });
        results.screenshots.push('test2-lecteur.png');
        console.log('✅ Screenshot lecteur sauvé');

        // Rechercher bouton Capture
        console.log('\n📍 RECHERCHE BOUTON CAPTURE');
        const captureTest = await page.evaluate(() => {
            // Rechercher bouton avec texte "Capture"
            const buttons = Array.from(document.querySelectorAll('button'));
            const captureBtn = buttons.find(btn =>
                btn.textContent.toLowerCase().includes('capture')
            );

            if (captureBtn) {
                try {
                    captureBtn.click();
                    return { found: true, clicked: true };
                } catch (e) {
                    return { found: true, clicked: false, error: e.message };
                }
            }

            // Si pas trouvé, retourner tous les textes de boutons
            return {
                found: false,
                buttonTexts: buttons.map(btn => btn.textContent.trim()).filter(text => text.length > 0)
            };
        });

        if (captureTest.found) {
            console.log('✅ Bouton Capture trouvé');
            if (captureTest.clicked) {
                console.log('✅ Bouton Capture cliqué avec succès');
                results.capture = true;
                await new Promise(resolve => setTimeout(resolve, 3000));
            } else {
                console.log('⚠️ Bouton Capture trouvé mais erreur clic:', captureTest.error);
            }
        } else {
            console.log('❌ Bouton Capture non trouvé');
            console.log('📋 Boutons trouvés:', captureTest.buttonTexts);
        }

        // Screenshot 3: Après test capture
        console.log('\n📸 SCREENSHOT 3: Post-capture');
        const postcapture = path.join(screenshotDir, 'test3-postcapture.png');
        await page.screenshot({ path: postcapture, fullPage: true });
        results.screenshots.push('test3-postcapture.png');
        console.log('✅ Screenshot post-capture sauvé');

        // Analyser le DOM pour vérifier les fonctionnalités
        console.log('\n📍 ANALYSE FONCTIONNALITÉS');
        const analysis = await page.evaluate(() => {
            return {
                title: document.title,
                buttons: Array.from(document.querySelectorAll('button')).map(btn => ({
                    text: btn.textContent.trim(),
                    id: btn.id,
                    visible: btn.offsetParent !== null
                })).filter(btn => btn.text.length > 0),

                selects: Array.from(document.querySelectorAll('select')).map(select => ({
                    id: select.id,
                    name: select.name,
                    options: select.options.length
                })),

                functions: Object.getOwnPropertyNames(window).filter(name =>
                    typeof window[name] === 'function' &&
                    (name.includes('player') || name.includes('apply') || name.includes('capture'))
                ),

                errors: window.console ? [] : ['Console non accessible']
            };
        });

        console.log('📊 ANALYSE DOM:');
        console.log('- Titre:', analysis.title);
        console.log('- Boutons visibles:', analysis.buttons.length);
        console.log('- Sélecteurs:', analysis.selects.length);
        console.log('- Fonctions pertinentes:', analysis.functions);

        // Rechercher spécifiquement le sélecteur de mode lecteur
        const playerModeInfo = await page.evaluate(() => {
            const selects = Array.from(document.querySelectorAll('select'));
            const playerSelect = selects.find(select =>
                select.id.includes('mode') ||
                select.name.includes('mode') ||
                select.id.includes('player') ||
                select.name.includes('player')
            );

            if (playerSelect) {
                return {
                    found: true,
                    id: playerSelect.id,
                    name: playerSelect.name,
                    options: Array.from(playerSelect.options).map(opt => ({
                        value: opt.value,
                        text: opt.textContent
                    }))
                };
            }
            return { found: false };
        });

        if (playerModeInfo.found) {
            console.log('✅ Sélecteur mode lecteur trouvé:', playerModeInfo.id || playerModeInfo.name);
            console.log('📋 Options:', playerModeInfo.options);
        }

        // Screenshot final
        console.log('\n📸 SCREENSHOT 4: État final');
        const final = path.join(screenshotDir, 'test4-final.png');
        await page.screenshot({ path: final, fullPage: true });
        results.screenshots.push('test4-final.png');
        console.log('✅ Screenshot final sauvé');

    } catch (error) {
        console.log('💥 Erreur:', error.message);
    } finally {
        await browser.close();
    }

    // RÉSUMÉ FINAL
    console.log('\n' + '='.repeat(70));
    console.log('📊 RÉSULTATS TESTS PUPPETEER - PiSignage v0.8.0');
    console.log('='.repeat(70));
    console.log(`✅ Navigation (200): ${results.navigation ? 'SUCCÈS' : 'ÉCHEC'}`);
    console.log(`✅ Interface chargée: ${results.interface ? 'SUCCÈS' : 'ÉCHEC'}`);
    console.log(`✅ Onglet Lecteur: ${results.lecteur ? 'SUCCÈS' : 'ÉCHEC'}`);
    console.log(`✅ Bouton Capture: ${results.capture ? 'SUCCÈS' : 'ÉCHEC'}`);

    const successCount = Object.values(results).filter(v => v === true).length;
    const totalTests = Object.keys(results).filter(k => typeof results[k] === 'boolean').length;

    console.log(`\n🎯 SCORE FINAL: ${successCount}/${totalTests} (${Math.round(successCount/totalTests*100)}%)`);

    console.log('\n📸 SCREENSHOTS DISPONIBLES:');
    results.screenshots.forEach((screenshot, index) => {
        console.log(`${index + 1}. ${screenshot}`);
    });

    console.log('\n📁 Dossier:', screenshotDir);

    if (results.navigation && results.interface) {
        console.log('\n✅ TESTS MINIMUM VALIDÉS - Interface fonctionnelle');
    } else {
        console.log('\n❌ TESTS CRITIQUES ÉCHOUÉS - Vérifier déploiement');
    }

    return results;
}

// Exécution
testPiSignageFinal().then(results => {
    console.log('\n🏁 TESTS TERMINÉS');
}).catch(error => {
    console.error('💥 ERREUR FATALE:', error);
    process.exit(1);
});