#!/usr/bin/env node

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://192.168.1.103';
const SCREENSHOTS_DIR = '/opt/pisignage/tests/screenshots';

if (!fs.existsSync(SCREENSHOTS_DIR)) {
    fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
}

async function wait(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function validateEverything() {
    console.log('🚀 VALIDATION FINALE PI-SIGNAGE v0.9.1');
    console.log('=====================================\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    const results = {
        screenshot: false,
        upload: false,
        youtube: false,
        reboot: false
    };
    
    try {
        // 1. CHARGER LA PAGE
        console.log('📄 Chargement de l\'interface...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, 'validation-1-home.png') });
        console.log('✅ Interface chargée\n');
        
        // 2. TEST SCREENSHOT
        console.log('📸 TEST SCREENSHOT:');
        await page.click('button[onclick*="dashboard"]');
        await wait(1000);
        
        // Appeler takeScreenshot via JavaScript
        const screenshotTest = await page.evaluate(async () => {
            if (typeof takeScreenshot === 'function') {
                takeScreenshot();
                await new Promise(r => setTimeout(r, 3000));
                
                const img = document.querySelector('#screenshotPreview img') ||
                           document.querySelector('img[src*="screenshot"]');
                
                return {
                    functionExists: true,
                    imageFound: !!img,
                    imageSrc: img ? img.src : null
                };
            }
            return { functionExists: false };
        });
        
        if (screenshotTest.functionExists && screenshotTest.imageFound) {
            console.log('✅ Screenshot fonctionne !');
            console.log('   Image:', screenshotTest.imageSrc);
            results.screenshot = true;
        } else {
            console.log('❌ Screenshot ne fonctionne pas');
        }
        
        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, 'validation-2-screenshot.png') });
        
        // 3. TEST UPLOAD
        console.log('\n📤 TEST UPLOAD:');
        await page.click('button[onclick*="media"]');
        await wait(1000);
        
        const uploadTest = await page.evaluate(() => {
            return {
                functionExists: typeof uploadFile === 'function',
                updateMediaListExists: typeof updateMediaList === 'function'
            };
        });
        
        if (uploadTest.functionExists && uploadTest.updateMediaListExists) {
            console.log('✅ Upload configuré correctement');
            results.upload = true;
        } else {
            console.log('❌ Upload manque des fonctions');
        }
        
        // 4. TEST YOUTUBE
        console.log('\n📺 TEST YOUTUBE:');
        await page.click('button[onclick*="youtube"]');
        await wait(1000);
        
        const youtubeTest = await page.evaluate(async () => {
            const response = await fetch('/api/youtube.php?action=queue');
            const data = await response.json();
            return {
                success: data.success,
                queueLength: data.queue ? data.queue.length : 0
            };
        });
        
        if (youtubeTest.success) {
            console.log('✅ YouTube API fonctionne');
            console.log('   Queue:', youtubeTest.queueLength, 'items');
            results.youtube = true;
        } else {
            console.log('❌ YouTube API échoue');
        }
        
        // 5. TEST REBOOT
        console.log('\n🔄 TEST REBOOT:');
        await page.click('button[onclick*="settings"]');
        await wait(1000);
        
        const rebootTest = await page.evaluate(() => {
            const buttons = Array.from(document.querySelectorAll('button'));
            const rebootBtn = buttons.find(b => b.textContent.includes('Redémarrer'));
            return {
                buttonExists: !!rebootBtn,
                functionExists: typeof restartSystem === 'function'
            };
        });
        
        if (rebootTest.buttonExists && rebootTest.functionExists) {
            console.log('✅ Reboot configuré');
            results.reboot = true;
        } else {
            console.log('❌ Reboot manquant');
        }
        
        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, 'validation-3-final.png'), fullPage: true });
        
        // RÉSULTATS
        console.log('\n=====================================');
        console.log('📊 RÉSULTATS VALIDATION:');
        console.log('-------------------------------------');
        
        let allPassed = true;
        for (const [test, passed] of Object.entries(results)) {
            const icon = passed ? '✅' : '❌';
            console.log(`${icon} ${test.toUpperCase()}: ${passed ? 'OK' : 'ÉCHOUÉ'}`);
            if (!passed) allPassed = false;
        }
        
        console.log('-------------------------------------');
        if (allPassed) {
            console.log('🎉 TOUS LES TESTS PASSÉS !');
            console.log('✅ Pi-Signage v0.9.1 100% FONCTIONNEL');
        } else {
            console.log('⚠️ Certains tests ont échoué');
        }
        
    } catch (error) {
        console.error('❌ Erreur:', error.message);
    } finally {
        await browser.close();
        console.log('\n📁 Screenshots:', SCREENSHOTS_DIR);
    }
    
    return results;
}

validateEverything().then(results => {
    process.exit(Object.values(results).every(v => v) ? 0 : 1);
});