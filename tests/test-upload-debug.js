#!/usr/bin/env node

const puppeteer = require('puppeteer');
const fs = require('fs');

const BASE_URL = 'http://192.168.1.103';

async function testUploadDebug() {
    console.log('🔍 DEBUG COMPLET UPLOAD PI-SIGNAGE');
    console.log('=====================================\n');
    
    // Créer un fichier MP4 de test
    const testFile = '/tmp/test-debug.mp4';
    const mp4Header = Buffer.from([
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31
    ]);
    const padding = Buffer.alloc(1024 * 1024 - mp4Header.length); // 1MB
    fs.writeFileSync(testFile, Buffer.concat([mp4Header, padding]));
    console.log(`✅ Fichier créé: ${testFile}\n`);
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Capturer les logs console
    page.on('console', msg => {
        console.log(`📝 Console [${msg.type()}]: ${msg.text()}`);
    });
    
    // Capturer les erreurs
    page.on('pageerror', error => {
        console.log(`❌ Page Error: ${error.message}`);
    });
    
    // Intercepter les requêtes
    page.on('request', request => {
        if (request.url().includes('upload')) {
            console.log(`📤 Upload Request: ${request.method()} ${request.url()}`);
        }
    });
    
    // Intercepter les réponses
    page.on('response', async response => {
        if (response.url().includes('upload')) {
            console.log(`📥 Upload Response: ${response.status()} ${response.url()}`);
            try {
                const body = await response.text();
                console.log(`   Body: ${body.substring(0, 200)}`);
            } catch (e) {}
        }
    });
    
    try {
        console.log('1️⃣ Chargement de l\'interface...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        
        // Vérifier que DOMContentLoaded et setupUpload sont appelés
        const initCheck = await page.evaluate(() => {
            const results = {
                hasSetupUpload: typeof setupUpload === 'function',
                hasHandleFiles: typeof handleFiles === 'function',
                hasUploadFile: typeof uploadFile === 'function',
                inputFound: !!document.getElementById('fileInput'),
                zoneFound: !!document.getElementById('uploadZone')
            };
            
            // Vérifier si les event listeners sont attachés
            const input = document.getElementById('fileInput');
            if (input) {
                // Créer un flag pour vérifier
                window.uploadTestFlag = false;
                
                // Override temporaire de handleFiles
                const originalHandleFiles = window.handleFiles;
                window.handleFiles = function(files) {
                    console.log('✅ handleFiles APPELÉ avec', files.length, 'fichier(s)');
                    window.uploadTestFlag = true;
                    if (originalHandleFiles) {
                        return originalHandleFiles.call(this, files);
                    }
                };
            }
            
            return results;
        });
        
        console.log('\n📊 Vérification des fonctions:');
        console.log(JSON.stringify(initCheck, null, 2));
        
        // Aller sur l'onglet Médias
        console.log('\n2️⃣ Navigation vers Médias...');
        await page.evaluate(() => {
            const buttons = Array.from(document.querySelectorAll('button'));
            const mediaBtn = buttons.find(b => b.textContent.includes('Médias'));
            if (mediaBtn) {
                mediaBtn.click();
                console.log('Clic sur bouton Médias');
            }
        });
        await new Promise(r => setTimeout(r, 1000));
        
        // Vérifier à nouveau après navigation
        const postNavCheck = await page.evaluate(() => {
            return {
                inputVisible: document.getElementById('fileInput')?.offsetParent !== null,
                zoneVisible: document.getElementById('uploadZone')?.offsetParent !== null
            };
        });
        console.log('\n📊 Visibilité après navigation:');
        console.log(JSON.stringify(postNavCheck, null, 2));
        
        // Test 1: Upload direct via puppeteer
        console.log('\n3️⃣ Test upload via Puppeteer...');
        const inputFile = await page.$('#fileInput');
        if (inputFile) {
            await inputFile.uploadFile(testFile);
            console.log('✅ Fichier sélectionné via Puppeteer');
            
            // Vérifier si handleFiles a été appelé
            await new Promise(r => setTimeout(r, 1000));
            const wasHandleFilesCalled = await page.evaluate(() => window.uploadTestFlag);
            console.log(`📊 handleFiles appelé: ${wasHandleFilesCalled ? '✅ OUI' : '❌ NON'}`);
        } else {
            console.log('❌ Input file non trouvé');
        }
        
        // Test 2: Simuler un clic et sélection manuelle
        console.log('\n4️⃣ Test trigger manuel de handleFiles...');
        const manualResult = await page.evaluate(() => {
            try {
                // Créer un faux fichier
                const file = new File(['test content'], 'manual-test.mp4', { type: 'video/mp4' });
                
                // Appeler directement handleFiles
                if (typeof handleFiles === 'function') {
                    console.log('Appel direct de handleFiles...');
                    handleFiles([file]);
                    return 'handleFiles appelé directement';
                } else {
                    return 'handleFiles non défini';
                }
            } catch (error) {
                return `Erreur: ${error.message}`;
            }
        });
        console.log(`   Résultat: ${manualResult}`);
        
        // Attendre pour voir si des requêtes sont envoyées
        await new Promise(r => setTimeout(r, 3000));
        
        // Test 3: Vérifier si uploadFile fonctionne
        console.log('\n5️⃣ Test direct de uploadFile...');
        const uploadResult = await page.evaluate(async () => {
            try {
                const file = new File(['test direct'], 'direct-test.mp4', { type: 'video/mp4' });
                
                if (typeof uploadFile === 'function') {
                    console.log('Appel direct de uploadFile...');
                    
                    // Override XMLHttpRequest pour debug
                    const originalXHR = window.XMLHttpRequest;
                    window.XMLHttpRequest = function() {
                        const xhr = new originalXHR();
                        const originalOpen = xhr.open;
                        const originalSend = xhr.send;
                        
                        xhr.open = function(method, url) {
                            console.log(`XHR Open: ${method} ${url}`);
                            return originalOpen.apply(this, arguments);
                        };
                        
                        xhr.send = function(data) {
                            console.log('XHR Send appelé');
                            return originalSend.apply(this, arguments);
                        };
                        
                        return xhr;
                    };
                    
                    uploadFile(file);
                    return 'uploadFile appelé';
                } else {
                    return 'uploadFile non défini';
                }
            } catch (error) {
                return `Erreur: ${error.message}`;
            }
        });
        console.log(`   Résultat: ${uploadResult}`);
        
        await new Promise(r => setTimeout(r, 2000));
        
        // Screenshot final
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/upload-debug.png',
            fullPage: true 
        });
        
        console.log('\n=====================================');
        console.log('📊 ANALYSE FINALE:');
        console.log('- Fonctions présentes: ✅');
        console.log('- Input trouvé: ✅');
        console.log('- Event handler: ' + (wasHandleFilesCalled ? '✅ Fonctionne' : '❌ Pas déclenché'));
        console.log('=====================================');
        
    } catch (error) {
        console.error('🔴 Erreur:', error.message);
    } finally {
        await browser.close();
        fs.unlinkSync(testFile);
    }
}

testUploadDebug().catch(console.error);