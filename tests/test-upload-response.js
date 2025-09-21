#!/usr/bin/env node

const puppeteer = require('puppeteer');
const fs = require('fs');

const BASE_URL = 'http://192.168.1.103';

async function testUploadResponse() {
    console.log('🔍 TEST RÉPONSE UPLOAD PI-SIGNAGE');
    console.log('=====================================\n');
    
    // Créer un petit fichier MP4
    const testFile = '/tmp/test-response.mp4';
    const mp4Header = Buffer.from([
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31
    ]);
    const padding = Buffer.alloc(100000 - mp4Header.length); // 100KB seulement
    fs.writeFileSync(testFile, Buffer.concat([mp4Header, padding]));
    console.log(`✅ Fichier créé: ${testFile} (100KB)\n`);
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Capturer TOUS les console logs
    page.on('console', msg => {
        const text = msg.text();
        if (text.includes('Upload') || text.includes('XHR') || text.includes('📤')) {
            console.log(`📝 Console: ${text}`);
        }
    });
    
    // Capturer les réponses avec plus de détails
    let responseReceived = false;
    page.on('response', async response => {
        const url = response.url();
        if (url.includes('upload')) {
            const status = response.status();
            console.log(`\n📥 RESPONSE RECEIVED!`);
            console.log(`   URL: ${url}`);
            console.log(`   Status: ${status}`);
            console.log(`   Headers: ${JSON.stringify(response.headers())}`);
            
            try {
                const body = await response.text();
                console.log(`   Body (first 500 chars): ${body.substring(0, 500)}`);
                
                // Parser le JSON si possible
                try {
                    const json = JSON.parse(body);
                    console.log(`   Parsed JSON:`, JSON.stringify(json, null, 2));
                } catch (e) {}
            } catch (e) {
                console.log(`   Body: Could not read`);
            }
            
            responseReceived = true;
        }
    });
    
    // Intercepter les requêtes
    page.on('request', request => {
        if (request.url().includes('upload')) {
            console.log(`\n📤 REQUEST SENT:`);
            console.log(`   Method: ${request.method()}`);
            console.log(`   URL: ${request.url()}`);
            console.log(`   Headers:`, request.headers());
        }
    });
    
    try {
        console.log('1️⃣ Chargement de la page...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        
        // Forcer le rechargement du JavaScript
        await page.evaluate(() => {
            location.reload(true);
        });
        await page.waitForNavigation({ waitUntil: 'networkidle2' });
        console.log('✅ Page rechargée (cache vidé)\n');
        
        // Aller directement aux médias
        console.log('2️⃣ Navigation vers Médias...');
        await page.click('button[onclick*="media"]');
        await new Promise(r => setTimeout(r, 1000));
        
        // Test 1: Upload via Puppeteer
        console.log('\n3️⃣ Upload via Puppeteer...');
        const inputFile = await page.$('#fileInput');
        if (inputFile) {
            await inputFile.uploadFile(testFile);
            console.log('✅ Fichier sélectionné');
            
            // Attendre 10 secondes pour la réponse
            console.log('⏳ Attente de la réponse (10s max)...');
            await new Promise(r => setTimeout(r, 10000));
            
            if (!responseReceived) {
                console.log('❌ Aucune réponse reçue après 10 secondes');
            }
        }
        
        // Test 2: Upload direct via fetch
        console.log('\n4️⃣ Test direct via fetch dans la page...');
        const fetchResult = await page.evaluate(async () => {
            const formData = new FormData();
            const blob = new Blob(['test content'], { type: 'video/mp4' });
            formData.append('video', blob, 'test-fetch.mp4');
            
            console.log('📤 Sending fetch request...');
            
            try {
                const startTime = Date.now();
                const response = await fetch('/api/upload.php', {
                    method: 'POST',
                    body: formData
                });
                const elapsed = Date.now() - startTime;
                
                console.log(`Response received in ${elapsed}ms`);
                
                const text = await response.text();
                return {
                    success: true,
                    status: response.status,
                    elapsed: elapsed,
                    body: text
                };
            } catch (error) {
                return {
                    success: false,
                    error: error.message
                };
            }
        });
        
        console.log('📊 Résultat fetch:');
        console.log(JSON.stringify(fetchResult, null, 2));
        
        // Vérifier la liste des médias
        console.log('\n5️⃣ Vérification de la liste des médias...');
        const mediaCount = await page.evaluate(() => {
            const mediaList = document.getElementById('mediaList');
            if (mediaList) {
                return mediaList.children.length;
            }
            return -1;
        });
        console.log(`Nombre de médias visibles: ${mediaCount}`);
        
    } catch (error) {
        console.error('🔴 Erreur:', error.message);
    } finally {
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/upload-response.png',
            fullPage: true 
        });
        
        await browser.close();
        fs.unlinkSync(testFile);
        
        console.log('\n=====================================');
        console.log('📊 RÉSUMÉ:');
        console.log(`- Réponse reçue: ${responseReceived ? '✅ OUI' : '❌ NON'}`);
        console.log('=====================================');
    }
}

testUploadResponse().catch(console.error);