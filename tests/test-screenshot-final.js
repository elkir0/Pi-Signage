#!/usr/bin/env node

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://192.168.1.103';

async function testScreenshotFinal() {
    console.log('🎬 TEST FINAL SCREENSHOT PI-SIGNAGE');
    console.log('=====================================\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    try {
        // 1. Charger la page
        console.log('1️⃣ Chargement de l\'interface...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        console.log('✅ Page chargée\n');
        
        // 2. Aller sur Dashboard
        console.log('2️⃣ Navigation vers Dashboard...');
        await page.click('button[onclick*="dashboard"]');
        await new Promise(r => setTimeout(r, 1000));
        console.log('✅ Dashboard ouvert\n');
        
        // 3. Appeler takeScreenshot
        console.log('3️⃣ Appel de takeScreenshot()...');
        const result = await page.evaluate(async () => {
            if (typeof takeScreenshot === 'function') {
                takeScreenshot();
                
                // Attendre que l'image se charge
                await new Promise(r => setTimeout(r, 3000));
                
                // Chercher l'image
                const img = document.querySelector('#screenshotPreview img') ||
                           document.querySelector('img[src*="screenshot"]') ||
                           document.querySelector('img[src*="current.png"]');
                
                if (img) {
                    return {
                        success: true,
                        src: img.src,
                        width: img.naturalWidth,
                        height: img.naturalHeight,
                        visible: img.offsetWidth > 0 && img.offsetHeight > 0
                    };
                }
                
                return { success: false, error: 'Image non trouvée' };
            }
            return { success: false, error: 'takeScreenshot non définie' };
        });
        
        console.log('Résultat:', JSON.stringify(result, null, 2));
        
        // 4. Vérifier l'API directement
        console.log('\n4️⃣ Test direct de l\'API...');
        const apiTest = await page.evaluate(async () => {
            const response = await fetch('/api/screenshot.php');
            const data = await response.json();
            return data;
        });
        
        console.log('API Response:', JSON.stringify(apiTest, null, 2));
        
        // 5. Capturer la page finale
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/final-test.png',
            fullPage: true 
        });
        console.log('\n✅ Screenshot de la page sauvé: final-test.png');
        
        // RÉSUMÉ
        console.log('\n=====================================');
        console.log('📊 RÉSULTAT:');
        if (result.success && apiTest.success) {
            console.log('✅ SCREENSHOT FONCTIONNE !');
            console.log(`   - Image: ${result.src}`);
            console.log(`   - Taille: ${result.width}x${result.height}`);
            console.log(`   - Visible: ${result.visible}`);
            console.log(`   - Vidéo: ${apiTest.video || 'N/A'}`);
            console.log(`   - Position: ${apiTest.position || 'N/A'}`);
            console.log(`   - Méthode: ${apiTest.method}`);
            console.log(`   - Taille fichier: ${apiTest.size} bytes`);
        } else {
            console.log('❌ PROBLÈME DÉTECTÉ');
            if (!result.success) console.log(`   Interface: ${result.error}`);
            if (!apiTest.success) console.log(`   API: ${apiTest.error}`);
        }
        
    } catch (error) {
        console.error('❌ Erreur:', error.message);
    } finally {
        await browser.close();
    }
}

testScreenshotFinal().catch(console.error);