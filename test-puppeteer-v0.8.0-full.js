/**
 * Test Puppeteer COMPLET v0.8.0 - VALIDATION STRICTE
 * Ce test DOIT passer à 100% avant déploiement production
 */

const puppeteer = require('puppeteer');
const fs = require('fs');

async function fullValidationTest() {
    console.log('🔍 TEST DE VALIDATION COMPLET PiSignage v0.8.0 PHP');
    console.log('=' .repeat(60));

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    let allTestsPassed = true;
    const errors = [];
    const warnings = [];

    try {
        const page = await browser.newPage();

        // Configuration viewport
        await page.setViewport({ width: 1920, height: 1080 });

        // Capture TOUS les logs console
        const consoleLogs = [];
        page.on('console', msg => {
            const log = {
                type: msg.type(),
                text: msg.text(),
                location: msg.location()
            };
            consoleLogs.push(log);

            if (msg.type() === 'error') {
                errors.push(log);
            } else if (msg.type() === 'warning') {
                warnings.push(log);
            }
        });

        // Capture les erreurs de page
        page.on('pageerror', error => {
            errors.push({
                type: 'pageerror',
                text: error.message,
                stack: error.stack
            });
        });

        // TEST 1: ACCÈS INTERFACE
        console.log('\n📋 TEST 1: ACCÈS INTERFACE');
        const response = await page.goto('http://localhost:8080', {
            waitUntil: 'networkidle0',
            timeout: 30000
        });

        const status = response.status();
        if (status === 200) {
            console.log(`✅ Interface accessible (HTTP ${status})`);
        } else {
            console.log(`❌ Interface inaccessible (HTTP ${status})`);
            allTestsPassed = false;
        }

        // TEST 2: VERSION
        console.log('\n📋 TEST 2: VÉRIFICATION VERSION');
        const version = await page.evaluate(() => {
            const versionEl = document.querySelector('.ps-version');
            return versionEl ? versionEl.textContent : null;
        });

        if (version === 'v0.8.0') {
            console.log(`✅ Version correcte: ${version}`);
        } else {
            console.log(`❌ Version incorrecte: ${version} (attendu: v0.8.0)`);
            allTestsPassed = false;
        }

        // TEST 3: NAVIGATION
        console.log('\n📋 TEST 3: NAVIGATION');
        const tabs = await page.evaluate(() => {
            return Array.from(document.querySelectorAll('.ps-nav-item')).map(btn => ({
                text: btn.textContent.trim(),
                active: btn.classList.contains('ps-nav-item--active')
            }));
        });

        if (tabs.length === 4) {
            console.log(`✅ Navigation complète: ${tabs.map(t => t.text).join(', ')}`);
        } else {
            console.log(`❌ Navigation incomplète: ${tabs.length} tabs (attendu: 4)`);
            allTestsPassed = false;
        }

        // TEST 4: APIs CRITIQUES
        console.log('\n📋 TEST 4: APIs CRITIQUES');
        const apiTests = [
            { url: '/api/screenshot', name: 'Screenshot' },
            { url: '/api/media', name: 'Media' },
            { url: '/api/youtube?action=queue', name: 'YouTube' }
        ];

        for (const api of apiTests) {
            const apiResponse = await page.evaluate(async (apiUrl) => {
                try {
                    const res = await fetch(apiUrl);
                    const data = await res.json();
                    return {
                        status: res.status,
                        ok: res.ok,
                        hasData: !!data
                    };
                } catch (err) {
                    return { error: err.message };
                }
            }, api.url);

            if (apiResponse.ok && apiResponse.hasData) {
                console.log(`✅ ${api.name} API fonctionnelle`);
            } else {
                console.log(`❌ ${api.name} API cassée: ${apiResponse.error || `HTTP ${apiResponse.status}`}`);
                allTestsPassed = false;
            }
        }

        // TEST 5: DESIGN SYSTEM
        console.log('\n📋 TEST 5: DESIGN SYSTEM v0.8.0');
        const design = await page.evaluate(() => {
            const body = document.body;
            const computed = window.getComputedStyle(body);
            return {
                background: computed.backgroundColor,
                textColor: computed.color,
                hasCSSLoaded: !!document.querySelector('link[href*="design-system.css"]')
            };
        });

        // Vérifier fond clair (pas noir)
        if (design.background !== 'rgb(0, 0, 0)' && design.hasCSSLoaded) {
            console.log(`✅ Design système chargé (fond: ${design.background})`);
        } else {
            console.log(`❌ Design système non chargé`);
            allTestsPassed = false;
        }

        // TEST 6: ÉLÉMENTS UI
        console.log('\n📋 TEST 6: ÉLÉMENTS UI');
        const uiElements = await page.evaluate(() => {
            return {
                buttons: document.querySelectorAll('.ps-btn').length,
                cards: document.querySelectorAll('.ps-card').length,
                forms: document.querySelectorAll('.ps-form-group, .ps-input').length,
                hasContent: document.querySelector('#main-content') !== null
            };
        });

        if (uiElements.buttons > 0 && uiElements.cards > 0 && uiElements.hasContent) {
            console.log(`✅ UI complète: ${uiElements.buttons} boutons, ${uiElements.cards} cards`);
        } else {
            console.log(`❌ UI incomplète`);
            allTestsPassed = false;
        }

        // TEST 7: JAVASCRIPT FONCTIONNEL
        console.log('\n📋 TEST 7: JAVASCRIPT');
        const jsStatus = await page.evaluate(() => {
            return {
                piSignageLoaded: typeof PiSignage !== 'undefined',
                version: typeof PiSignage !== 'undefined' ? PiSignage.version : null,
                initialized: typeof PiSignage !== 'undefined' && PiSignage.currentTab !== null
            };
        });

        if (jsStatus.piSignageLoaded && jsStatus.version === '0.8.0') {
            console.log(`✅ JavaScript fonctionnel (PiSignage v${jsStatus.version})`);
        } else {
            console.log(`❌ JavaScript non fonctionnel`);
            allTestsPassed = false;
        }

        // TEST 8: ERREURS CONSOLE
        console.log('\n📋 TEST 8: ERREURS CONSOLE');
        const criticalErrors = errors.filter(e =>
            !e.text.includes('favicon.ico') &&
            !e.text.includes('404')
        );

        if (criticalErrors.length === 0) {
            console.log('✅ Aucune erreur critique');
        } else {
            console.log(`❌ ${criticalErrors.length} erreurs critiques:`);
            criticalErrors.forEach(err => {
                console.log(`   - ${err.text}`);
            });
            allTestsPassed = false;
        }

        // SCREENSHOT FINAL
        const screenshotPath = 'validation-v0.8.0-' + Date.now() + '.png';
        await page.screenshot({
            path: screenshotPath,
            fullPage: true
        });
        console.log(`\n📸 Screenshot sauvegardé: ${screenshotPath}`);

        // RÉSUMÉ FINAL
        console.log('\n' + '=' .repeat(60));
        console.log('📊 RÉSUMÉ VALIDATION v0.8.0 PHP');
        console.log('=' .repeat(60));

        if (allTestsPassed) {
            console.log('✅✅✅ VALIDATION RÉUSSIE - PRÊT POUR PRODUCTION ✅✅✅');
            console.log('\n🚀 AUTORISATION DE DÉPLOIEMENT ACCORDÉE');
            console.log('   Version: v0.8.0 PHP');
            console.log('   APIs: 100% fonctionnelles');
            console.log('   Interface: Claire et professionnelle');
            console.log('   Erreurs: 0 erreurs critiques');

            // Créer fichier de validation
            fs.writeFileSync('VALIDATION-v0.8.0-OK.txt', `
VALIDATION RÉUSSIE - ${new Date().toISOString()}
Version: v0.8.0 PHP
APIs: OK
UI: OK
JS: OK
Erreurs: 0
Screenshot: ${screenshotPath}
            `);

        } else {
            console.log('❌❌❌ VALIDATION ÉCHOUÉE - NE PAS DÉPLOYER ❌❌❌');
            console.log('\n⚠️  PROBLÈMES À CORRIGER:');
            if (status !== 200) console.log('   - Interface non accessible');
            if (version !== 'v0.8.0') console.log('   - Version incorrecte');
            if (criticalErrors.length > 0) console.log('   - Erreurs console critiques');
            console.log('\n🔧 CORRIGER ET RELANCER LES TESTS');
        }

        return allTestsPassed;

    } catch (error) {
        console.error('❌ ERREUR FATALE:', error);
        allTestsPassed = false;
    } finally {
        await browser.close();
    }

    return allTestsPassed;
}

// Lancer la validation
fullValidationTest().then(success => {
    if (success) {
        console.log('\n✅ Processus de validation terminé avec succès');
        process.exit(0);
    } else {
        console.log('\n❌ Validation échouée - Corrections nécessaires');
        process.exit(1);
    }
}).catch(err => {
    console.error('Erreur fatale:', err);
    process.exit(1);
});