#!/usr/bin/env node

const puppeteer = require('puppeteer');
const fs = require('fs');

const BASE_URL = 'http://192.168.1.103';

async function testInterface() {
    console.log('🔍 TEST DEBUG INTERFACE PI-SIGNAGE');
    console.log('=====================================\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // Capturer les erreurs console
    const consoleErrors = [];
    page.on('console', msg => {
        if (msg.type() === 'error') {
            consoleErrors.push(msg.text());
            console.log('❌ Console Error:', msg.text());
        }
    });
    
    // Capturer les requêtes réseau
    page.on('response', response => {
        if (response.status() >= 400) {
            console.log(`❌ HTTP ${response.status()}: ${response.url()}`);
        }
    });
    
    try {
        // 1. CHARGER LA PAGE
        console.log('1️⃣ Chargement de la page...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        console.log('✅ Page chargée\n');
        
        // 2. VÉRIFIER LES FONCTIONS JAVASCRIPT
        console.log('2️⃣ Vérification des fonctions JavaScript...');
        const functions = await page.evaluate(() => {
            return {
                updateMediaList: typeof updateMediaList,
                uploadFile: typeof uploadFile,
                takeScreenshot: typeof takeScreenshot,
                downloadYoutube: typeof downloadYoutube,
                rebootSystem: typeof rebootSystem,
                refreshMediaList: typeof refreshMediaList,
                loadDownloadQueue: typeof loadDownloadQueue
            };
        });
        
        for (const [func, type] of Object.entries(functions)) {
            if (type === 'function') {
                console.log(`✅ ${func}: ${type}`);
            } else {
                console.log(`❌ ${func}: ${type} (MANQUANT!)`);
            }
        }
        console.log('');
        
        // 3. TEST SCREENSHOT
        console.log('3️⃣ Test Screenshot...');
        await page.click('#dashboardTab');
        await page.waitForTimeout(1000);
        
        const screenshotResult = await page.evaluate(async () => {
            try {
                const response = await fetch('/api/screenshot.php');
                const data = await response.json();
                return { 
                    status: response.status,
                    success: data.success,
                    method: data.method,
                    error: data.error
                };
            } catch (e) {
                return { error: e.message };
            }
        });
        
        if (screenshotResult.success) {
            console.log(`✅ Screenshot: ${screenshotResult.method}`);
        } else {
            console.log(`❌ Screenshot échoué:`, screenshotResult);
        }
        console.log('');
        
        // 4. TEST UPLOAD
        console.log('4️⃣ Test Upload...');
        await page.click('#mediasTab');
        await page.waitForTimeout(1000);
        
        // Vérifier si l'input file existe
        const inputExists = await page.evaluate(() => {
            const input = document.querySelector('input[type="file"]');
            return input !== null;
        });
        
        if (inputExists) {
            console.log('✅ Input file trouvé');
            
            // Créer un fichier test
            const testFile = '/tmp/test-debug.png';
            fs.writeFileSync(testFile, Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64'));
            
            const inputFile = await page.$('input[type="file"]');
            await inputFile.uploadFile(testFile);
            await page.waitForTimeout(2000);
            
            // Vérifier si updateMediaList a été appelé
            const mediaListCalled = await page.evaluate(() => {
                return window.updateMediaListCalled || false;
            });
            
            console.log(mediaListCalled ? '✅ updateMediaList appelé' : '❌ updateMediaList NON appelé');
        } else {
            console.log('❌ Input file NON trouvé');
        }
        console.log('');
        
        // 5. TEST YOUTUBE
        console.log('5️⃣ Test YouTube...');
        await page.click('#youtubeTab');
        await page.waitForTimeout(1000);
        
        const youtubeTest = await page.evaluate(async () => {
            try {
                const response = await fetch('/api/youtube.php?action=queue');
                const data = await response.json();
                return {
                    status: response.status,
                    success: data.success,
                    queue: data.queue || []
                };
            } catch (e) {
                return { error: e.message };
            }
        });
        
        if (youtubeTest.success) {
            console.log(`✅ YouTube API: Queue = ${youtubeTest.queue.length} items`);
        } else {
            console.log(`❌ YouTube API:`, youtubeTest);
        }
        console.log('');
        
        // 6. TEST REBOOT
        console.log('6️⃣ Test Reboot (Settings)...');
        await page.click('#settingsTab');
        await page.waitForTimeout(1000);
        
        const rebootExists = await page.evaluate(() => {
            const buttons = Array.from(document.querySelectorAll('button'));
            return buttons.some(btn => btn.textContent.includes('Reboot'));
        });
        
        console.log(rebootExists ? '✅ Bouton Reboot trouvé' : '❌ Bouton Reboot NON trouvé');
        
        if (rebootExists) {
            // Tester l'API sans vraiment rebooter
            const rebootTest = await page.evaluate(async () => {
                try {
                    const response = await fetch('/api/system.php?action=status');
                    return { status: response.status };
                } catch (e) {
                    return { error: e.message };
                }
            });
            
            console.log(rebootTest.status === 200 ? '✅ API System accessible' : `❌ API System: ${rebootTest.error || rebootTest.status}`);
        }
        console.log('');
        
        // RÉSUMÉ
        console.log('=====================================');
        console.log('📊 RÉSUMÉ:');
        console.log(`Erreurs console: ${consoleErrors.length}`);
        if (consoleErrors.length > 0) {
            consoleErrors.forEach(err => console.log(`  - ${err}`));
        }
        
    } catch (error) {
        console.error('❌ Erreur fatale:', error.message);
    } finally {
        await browser.close();
    }
}

testInterface().catch(console.error);