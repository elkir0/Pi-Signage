const puppeteer = require('puppeteer');
const fs = require('fs');
const { execSync } = require('child_process');

async function completeValidation() {
    console.log('🎯 VALIDATION COMPLÈTE DU SYSTÈME PISIGNAGE');
    console.log('=' . repeat(60) + '\n');
    
    const results = {
        timestamp: new Date().toISOString(),
        tests: []
    };

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // 1. Charger l'interface
    console.log('1️⃣ Chargement de l\'interface web...');
    await page.goto('http://192.168.1.103/', { 
        waitUntil: 'networkidle2',
        timeout: 30000 
    });
    
    // 2. Vérifier le statut du lecteur
    console.log('2️⃣ Vérification du statut du lecteur vidéo...');
    const playerStatus = await page.evaluate(async () => {
        // Statut affiché
        const statusElement = document.querySelector('#player-status');
        const displayedStatus = statusElement ? statusElement.textContent : 'Not found';
        
        // Statut API
        const response = await fetch('/?action=status');
        const data = await response.json();
        
        return {
            displayed: displayedStatus,
            api: data.data.vlc_running,
            hostname: data.data.hostname,
            cpu_temp: data.data.cpu_temp
        };
    });
    
    console.log(`   Interface: ${playerStatus.displayed}`);
    console.log(`   API: ${playerStatus.api ? 'En cours' : 'Arrêté'}`);
    console.log(`   Hostname: ${playerStatus.hostname}`);
    console.log(`   CPU Temp: ${playerStatus.cpu_temp}°C`);
    
    results.tests.push({
        name: 'Player Status',
        passed: playerStatus.api,
        details: playerStatus
    });
    
    // 3. Attendre que le screenshot automatique se charge
    console.log('\n3️⃣ Test du screenshot automatique...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    const screenshotTest = await page.evaluate(() => {
        const img = document.querySelector('#screenshot-preview');
        if (!img) return { error: 'Image element not found' };
        
        return {
            src: img.src,
            displayed: window.getComputedStyle(img).display !== 'none',
            width: img.naturalWidth,
            height: img.naturalHeight,
            loaded: img.complete && img.naturalHeight > 0
        };
    });
    
    console.log(`   Source: ${screenshotTest.src ? '✓' : '✗'}`);
    console.log(`   Affiché: ${screenshotTest.displayed ? '✓' : '✗'}`);
    console.log(`   Dimensions: ${screenshotTest.width}x${screenshotTest.height}`);
    console.log(`   Chargé: ${screenshotTest.loaded ? '✓' : '✗'}`);
    
    results.tests.push({
        name: 'Screenshot Display',
        passed: screenshotTest.loaded && screenshotTest.displayed,
        details: screenshotTest
    });
    
    // 4. Télécharger et analyser le screenshot
    console.log('\n4️⃣ Analyse du contenu du screenshot...');
    
    if (screenshotTest.src) {
        try {
            // Télécharger le screenshot
            execSync(`curl -s http://192.168.1.103/assets/screenshots/current_display.png -o /tmp/validate_screenshot.png`);
            
            // Analyser avec ImageMagick
            const meanBrightness = execSync(`convert /tmp/validate_screenshot.png -format "%[fx:mean*255]" info:`).toString().trim();
            const stdDev = execSync(`convert /tmp/validate_screenshot.png -crop 500x500+1700+800 -format "%[fx:standard_deviation*255]" info:`).toString().trim();
            
            const brightness = parseFloat(meanBrightness);
            const deviation = parseFloat(stdDev);
            
            console.log(`   Luminosité moyenne: ${brightness.toFixed(1)}/255`);
            console.log(`   Déviation standard: ${deviation.toFixed(1)}`);
            
            let videoStatus;
            if (brightness < 10) {
                videoStatus = '❌ Écran noir (pas de vidéo)';
            } else if (deviation < 5) {
                videoStatus = '⚠️ Image statique (logo ou écran uniforme)';
            } else {
                videoStatus = '✅ Vidéo en cours de lecture';
            }
            
            console.log(`   État: ${videoStatus}`);
            
            results.tests.push({
                name: 'Video Display',
                passed: brightness > 10 && deviation > 5,
                details: { brightness, deviation, status: videoStatus }
            });
            
        } catch (error) {
            console.log(`   ❌ Erreur d'analyse: ${error.message}`);
            results.tests.push({
                name: 'Video Display',
                passed: false,
                error: error.message
            });
        }
    }
    
    // 5. Test des APIs
    console.log('\n5️⃣ Test des APIs REST...');
    const apiTests = await page.evaluate(async () => {
        const apis = [
            '/api/playlist.php?action=list',
            '/api/youtube.php?action=queue',
            '/?action=status',
            '/?action=list'
        ];
        
        const results = [];
        for (const api of apis) {
            try {
                const response = await fetch(api);
                const data = await response.json();
                results.push({
                    url: api,
                    status: response.status,
                    ok: response.ok && data
                });
            } catch (error) {
                results.push({
                    url: api,
                    status: 'error',
                    ok: false
                });
            }
        }
        return results;
    });
    
    apiTests.forEach(test => {
        console.log(`   ${test.url}: ${test.ok ? '✅' : '❌'} (${test.status})`);
    });
    
    results.tests.push({
        name: 'APIs',
        passed: apiTests.every(t => t.ok),
        details: apiTests
    });
    
    // 6. Vérifier les erreurs console
    console.log('\n6️⃣ Vérification des erreurs console...');
    const consoleErrors = await page.evaluate(() => {
        return new Promise((resolve) => {
            const errors = [];
            const originalError = console.error;
            console.error = (...args) => {
                errors.push(args.join(' '));
                originalError.apply(console, args);
            };
            setTimeout(() => resolve(errors), 2000);
        });
    });
    
    console.log(`   Erreurs détectées: ${consoleErrors.length}`);
    if (consoleErrors.length > 0) {
        consoleErrors.slice(0, 3).forEach(err => {
            console.log(`     - ${err.substring(0, 80)}...`);
        });
    }
    
    results.tests.push({
        name: 'Console Errors',
        passed: consoleErrors.length === 0,
        details: { count: consoleErrors.length, errors: consoleErrors }
    });
    
    // Screenshot final de l'interface
    await page.screenshot({ 
        path: '/opt/pisignage/tests/screenshots/validation-finale.png',
        fullPage: false
    });
    
    await browser.close();
    
    // 7. Vérifier le processus vidéo
    console.log('\n7️⃣ Vérification du processus vidéo...');
    try {
        const processes = execSync('ssh pi@192.168.1.103 "ps aux | grep -E \\"mplayer|vlc|mpv\\" | grep -v grep"', {
            env: { ...process.env, SSHPASS: 'raspberry' }
        }).toString();
        
        const hasVideoProcess = processes.length > 0;
        console.log(`   Processus vidéo: ${hasVideoProcess ? '✅ Actif' : '❌ Aucun'}`);
        
        results.tests.push({
            name: 'Video Process',
            passed: hasVideoProcess,
            details: processes.substring(0, 200)
        });
    } catch {
        console.log(`   Processus vidéo: ❌ Erreur de vérification`);
        results.tests.push({
            name: 'Video Process',
            passed: false,
            error: 'Could not check'
        });
    }
    
    // Résumé final
    console.log('\n' + '=' . repeat(60));
    console.log('📊 RÉSUMÉ DE VALIDATION\n');
    
    const allPassed = results.tests.every(t => t.passed);
    const passedCount = results.tests.filter(t => t.passed).length;
    const totalCount = results.tests.length;
    
    results.tests.forEach(test => {
        console.log(`${test.passed ? '✅' : '❌'} ${test.name}`);
    });
    
    console.log(`\nScore: ${passedCount}/${totalCount}`);
    console.log('\n🏆 RÉSULTAT FINAL: ' + (allPassed ? 
        '✅ SYSTÈME 100% FONCTIONNEL' : 
        `⚠️ ${passedCount}/${totalCount} tests passés`));
    
    // Sauvegarder le rapport
    fs.writeFileSync('/opt/pisignage/tests/validation-report.json', JSON.stringify(results, null, 2));
    console.log('\n📄 Rapport sauvegardé: /opt/pisignage/tests/validation-report.json');
    
    process.exit(allPassed ? 0 : 1);
}

completeValidation().catch(error => {
    console.error('❌ Erreur de validation:', error);
    process.exit(1);
});