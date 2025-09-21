#!/usr/bin/env node

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://192.168.1.103';

async function testUploadDeep() {
    console.log('🔍 DIAGNOSTIC APPROFONDI UPLOAD PI-SIGNAGE');
    console.log('===========================================\n');
    
    // Créer un vrai fichier MP4
    const testFile = '/tmp/test-real.mp4';
    console.log('📁 Création d\'un vrai fichier MP4...');
    // Créer un fichier MP4 minimal mais valide
    const mp4Header = Buffer.from([
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // ftyp box
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31
    ]);
    const padding = Buffer.alloc(1024 * 1024 - mp4Header.length); // 1MB total
    fs.writeFileSync(testFile, Buffer.concat([mp4Header, padding]));
    console.log(`✅ Fichier créé: ${testFile}\n`);
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Intercepter les réponses pour voir ce que retourne l'API
    page.on('response', async response => {
        const url = response.url();
        if (url.includes('upload')) {
            const status = response.status();
            console.log(`📥 Upload Response: ${status} ${url}`);
            try {
                const body = await response.text();
                console.log(`   Body: ${body}`);
            } catch (e) {
                console.log(`   Body: (unable to read)`);
            }
        }
    });
    
    try {
        // 1. Charger la page
        console.log('1️⃣ Chargement de l\'interface...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        console.log('✅ Page chargée\n');
        
        // 2. Aller sur Médias
        console.log('2️⃣ Navigation vers Médias...');
        await page.evaluate(() => {
            const buttons = Array.from(document.querySelectorAll('button'));
            const mediaBtn = buttons.find(b => b.textContent.includes('Médias'));
            if (mediaBtn) mediaBtn.click();
        });
        await new Promise(r => setTimeout(r, 1000));
        console.log('✅ Onglet Médias ouvert\n');
        
        // 3. Analyser l'input file
        console.log('3️⃣ Analyse de l\'input file...');
        const inputAnalysis = await page.evaluate(() => {
            const input = document.querySelector('input[type="file"]');
            if (!input) return { found: false };
            
            // Analyser les event listeners
            const listeners = [];
            if (input.onchange) listeners.push('onchange');
            if (input.oninput) listeners.push('oninput');
            
            return {
                found: true,
                id: input.id,
                name: input.name,
                accept: input.accept,
                multiple: input.multiple,
                listeners: listeners,
                onchangeCode: input.onchange ? input.onchange.toString().substring(0, 200) : null
            };
        });
        console.log('📊 Input analysis:', JSON.stringify(inputAnalysis, null, 2));
        console.log('');
        
        // 4. Simuler l'upload de différentes façons
        console.log('4️⃣ Test upload méthode 1: uploadFile standard...');
        const inputFile = await page.$('input[type="file"]');
        await inputFile.uploadFile(testFile);
        await new Promise(r => setTimeout(r, 3000));
        
        // Vérifier si handleFiles est appelé
        const handled = await page.evaluate(() => {
            return window.lastUploadedFile || 'none';
        });
        console.log(`   Résultat: ${handled}\n`);
        
        // 5. Test méthode 2: Trigger manuel
        console.log('5️⃣ Test upload méthode 2: Trigger manuel...');
        await page.evaluate((filePath) => {
            // Créer un faux fichier
            const file = new File(['test'], 'test-manual.mp4', { type: 'video/mp4' });
            
            // Si handleFiles existe, l'appeler directement
            if (typeof handleFiles === 'function') {
                console.log('Calling handleFiles directly');
                handleFiles([file]);
                return 'handleFiles called';
            }
            
            // Sinon essayer via l'input
            const input = document.querySelector('input[type="file"]');
            if (input && input.onchange) {
                const event = { target: { files: [file] } };
                input.onchange(event);
                return 'onchange triggered';
            }
            
            return 'no handler found';
        });
        
        await new Promise(r => setTimeout(r, 3000));
        console.log('✅ Test terminé\n');
        
        // 6. Vérifier le résultat final
        console.log('6️⃣ Vérification du résultat...');
        const mediaCount = await page.evaluate(() => {
            const mediaList = document.getElementById('mediaList');
            if (mediaList) {
                const items = mediaList.querySelectorAll('.media-item, li, tr, div[class*="video"]');
                return items.length;
            }
            return 0;
        });
        console.log(`   Nombre de médias: ${mediaCount}\n`);
        
        // 7. Debug: Injecter un upload direct
        console.log('7️⃣ Test direct via fetch...');
        const directResult = await page.evaluate(async () => {
            const formData = new FormData();
            const blob = new Blob(['test content'], { type: 'video/mp4' });
            formData.append('video', blob, 'test-fetch.mp4');
            
            try {
                const response = await fetch('/api/upload.php', {
                    method: 'POST',
                    body: formData
                });
                const data = await response.json();
                return { success: true, data };
            } catch (error) {
                return { success: false, error: error.message };
            }
        });
        console.log('📊 Résultat fetch direct:', JSON.stringify(directResult, null, 2));
        
        if (directResult.success && directResult.data.success) {
            console.log('✅ L\'API fonctionne avec fetch direct');
            
            // Appeler updateMediaList si elle existe
            await page.evaluate(() => {
                if (typeof updateMediaList === 'function') {
                    updateMediaList(directResult.data.files);
                }
            });
        }
        
    } catch (error) {
        console.error('🔴 Erreur:', error.message);
    } finally {
        await page.screenshot({ path: '/opt/pisignage/tests/screenshots/upload-final.png', fullPage: true });
        await browser.close();
        
        // Nettoyer
        fs.unlinkSync(testFile);
        
        console.log('\n📸 Screenshot final: /opt/pisignage/tests/screenshots/upload-final.png');
    }
}

testUploadDeep().catch(console.error);