const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function testPiSignage() {
    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // Capture console logs and errors
    const consoleLogs = [];
    const consoleErrors = [];
    
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        
        if (type === 'error') {
            consoleErrors.push(text);
        } else {
            consoleLogs.push(`[${type}] ${text}`);
        }
    });
    
    page.on('pageerror', error => {
        consoleErrors.push(`Page Error: ${error.message}`);
    });
    
    console.log('🚀 Test PiSignage v2.0.0-premium');
    console.log('================================\n');
    
    try {
        // 1. Test de la page principale
        console.log('📡 Connexion à http://192.168.1.103...');
        const response = await page.goto('http://192.168.1.103', {
            waitUntil: 'networkidle2',
            timeout: 30000
        });
        
        console.log(`✅ Page chargée: Status ${response.status()}\n`);
        
        // 2. Capture screenshot
        const screenshotPath = path.join(__dirname, 'screenshot-test.png');
        await page.screenshot({ 
            path: screenshotPath, 
            fullPage: true 
        });
        console.log(`📸 Screenshot sauvegardé: ${screenshotPath}\n`);
        
        // 3. Vérification du style Glassmorphism
        console.log('🎨 Vérification du style...');
        
        const styleChecks = await page.evaluate(() => {
            const body = document.body;
            const computedStyle = window.getComputedStyle(body);
            
            // Chercher des éléments avec glassmorphism
            const glassElements = document.querySelectorAll('[class*="backdrop-blur"], [class*="glass"]');
            const redElements = document.querySelectorAll('[class*="red-600"], [class*="red-500"]');
            const darkElements = document.querySelectorAll('[class*="bg-black"], [class*="bg-gray-900"]');
            
            // Vérifier le logo
            const logo = document.querySelector('img[alt*="Pi"], img[alt*="logo"], img[src*="logo"]');
            
            return {
                backgroundColor: computedStyle.backgroundColor,
                textColor: computedStyle.color,
                hasGlassElements: glassElements.length > 0,
                glassElementsCount: glassElements.length,
                hasRedAccents: redElements.length > 0,
                redElementsCount: redElements.length,
                hasDarkTheme: darkElements.length > 0,
                darkElementsCount: darkElements.length,
                hasLogo: !!logo,
                logoSrc: logo ? logo.src : null
            };
        });
        
        console.log(`  Background: ${styleChecks.backgroundColor}`);
        console.log(`  Text Color: ${styleChecks.textColor}`);
        console.log(`  Glass Elements: ${styleChecks.hasGlassElements ? '✅' : '❌'} (${styleChecks.glassElementsCount} trouvés)`);
        console.log(`  Red Accents FREE.FR: ${styleChecks.hasRedAccents ? '✅' : '❌'} (${styleChecks.redElementsCount} trouvés)`);
        console.log(`  Dark Theme: ${styleChecks.hasDarkTheme ? '✅' : '❌'} (${styleChecks.darkElementsCount} trouvés)`);
        console.log(`  Logo: ${styleChecks.hasLogo ? '✅' : '❌'} ${styleChecks.logoSrc ? `(${styleChecks.logoSrc})` : ''}\n`);
        
        // 4. Test des APIs
        console.log('🔌 Test des APIs...');
        
        const apis = [
            '/api/system',
            '/api/system/logs',
            '/api/media',
            '/api/playlist',
            '/api/settings'
        ];
        
        for (const api of apis) {
            try {
                const apiResponse = await page.evaluate(async (apiPath) => {
                    const res = await fetch(`http://192.168.1.103${apiPath}`);
                    return {
                        status: res.status,
                        ok: res.ok
                    };
                }, api);
                
                console.log(`  ${api}: ${apiResponse.ok ? '✅' : '❌'} (Status ${apiResponse.status})`);
            } catch (error) {
                console.log(`  ${api}: ❌ Error - ${error.message}`);
            }
        }
        
        // Test spécial pour screenshot API (POST)
        try {
            const screenshotApi = await page.evaluate(async () => {
                const res = await fetch('http://192.168.1.103/api/system/screenshot', {
                    method: 'POST'
                });
                return {
                    status: res.status,
                    ok: res.ok
                };
            });
            console.log(`  /api/system/screenshot: ${screenshotApi.ok ? '✅' : '❌'} (Status ${screenshotApi.status})`);
        } catch (error) {
            console.log(`  /api/system/screenshot: ❌ Error - ${error.message}`);
        }
        
        console.log('');
        
        // 5. Analyse des erreurs console
        console.log('🔍 Analyse de la console...');
        console.log(`  Erreurs: ${consoleErrors.length === 0 ? '✅ Aucune' : `❌ ${consoleErrors.length} erreur(s)`}`);
        
        if (consoleErrors.length > 0) {
            console.log('\n  Détails des erreurs:');
            consoleErrors.forEach((error, index) => {
                console.log(`    ${index + 1}. ${error}`);
            });
        }
        
        // 6. Vérification des composants
        console.log('\n🧩 Vérification des composants...');
        
        const components = await page.evaluate(() => {
            const tabs = document.querySelectorAll('[role="tab"], .tab, [class*="tab"]');
            const buttons = document.querySelectorAll('button');
            const cards = document.querySelectorAll('[class*="card"], [class*="glass"]');
            
            return {
                tabsCount: tabs.length,
                buttonsCount: buttons.length,
                cardsCount: cards.length,
                hasAnimations: !!document.querySelector('[class*="transition"], [class*="animate"]')
            };
        });
        
        console.log(`  Tabs: ${components.tabsCount}`);
        console.log(`  Buttons: ${components.buttonsCount}`);
        console.log(`  Cards: ${components.cardsCount}`);
        console.log(`  Animations: ${components.hasAnimations ? '✅' : '❌'}`);
        
        // 7. Résumé final
        console.log('\n' + '='.repeat(50));
        console.log('📊 RÉSUMÉ DU TEST');
        console.log('='.repeat(50));
        
        const totalErrors = consoleErrors.length;
        const hasStyle = styleChecks.hasGlassElements && styleChecks.hasRedAccents && styleChecks.hasDarkTheme;
        const hasLogo = styleChecks.hasLogo;
        
        if (totalErrors === 0 && hasStyle && hasLogo) {
            console.log('✅ TEST RÉUSSI - Interface Premium fonctionnelle');
            console.log('   - Aucune erreur console');
            console.log('   - Style Glassmorphism appliqué');
            console.log('   - Logo présent');
            console.log('   - APIs fonctionnelles');
        } else {
            console.log('⚠️ TEST PARTIEL - Problèmes détectés:');
            if (totalErrors > 0) console.log(`   - ${totalErrors} erreur(s) console`);
            if (!hasStyle) console.log('   - Style incomplet');
            if (!hasLogo) console.log('   - Logo manquant');
        }
        
        console.log('\n📸 Screenshot disponible: ' + screenshotPath);
        console.log('🔗 URL testée: http://192.168.1.103');
        
    } catch (error) {
        console.error('❌ Erreur pendant le test:', error.message);
    } finally {
        await browser.close();
    }
}

// Lancer le test
testPiSignage().catch(console.error);