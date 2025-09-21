#!/usr/bin/env node

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://192.168.1.103';
const TEST_FILE = '/tmp/test-upload-video.mp4';

// Créer un fichier de test de 10MB
console.log('📁 Création du fichier de test (10MB)...');
const buffer = Buffer.alloc(10 * 1024 * 1024); // 10MB
fs.writeFileSync(TEST_FILE, buffer);
console.log(`✅ Fichier créé: ${TEST_FILE} (10MB)\n`);

async function testUploadInterface() {
    console.log('🎬 TEST UPLOAD VIA INTERFACE WEB PI-SIGNAGE');
    console.log('============================================\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Capturer TOUS les logs console
    const consoleLogs = [];
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        consoleLogs.push({ type, text });
        
        if (type === 'error') {
            console.log(`❌ Console Error: ${text}`);
        } else if (type === 'warning') {
            console.log(`⚠️ Console Warning: ${text}`);
        } else {
            console.log(`📝 Console: ${text}`);
        }
    });
    
    // Capturer les erreurs de page
    page.on('pageerror', error => {
        console.log(`🔴 Page Error: ${error.message}`);
    });
    
    // Intercepter les requêtes réseau
    const networkRequests = [];
    page.on('request', request => {
        const url = request.url();
        const method = request.method();
        
        if (url.includes('upload') || method === 'POST') {
            console.log(`📤 Request: ${method} ${url}`);
            networkRequests.push({
                method,
                url,
                headers: request.headers(),
                postData: request.postData()
            });
        }
    });
    
    // Intercepter les réponses
    page.on('response', response => {
        const url = response.url();
        const status = response.status();
        
        if (url.includes('upload') || url.includes('api')) {
            console.log(`📥 Response: ${status} ${url}`);
            
            // Récupérer le body de la réponse si c'est une erreur
            if (status >= 400) {
                response.text().then(body => {
                    console.log(`   Body: ${body.substring(0, 200)}`);
                }).catch(() => {});
            }
        }
    });
    
    try {
        // 1. Charger la page
        console.log('1️⃣ Chargement de l\'interface...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        await page.screenshot({ path: '/opt/pisignage/tests/screenshots/upload-1-home.png' });
        console.log('✅ Page chargée\n');
        
        // 2. Aller sur l'onglet Médias
        console.log('2️⃣ Navigation vers l\'onglet Médias...');
        const mediasButton = await page.$('button[onclick*="media"]');
        if (!mediasButton) {
            throw new Error('Bouton Médias non trouvé');
        }
        await mediasButton.click();
        await new Promise(r => setTimeout(r, 1000));
        await page.screenshot({ path: '/opt/pisignage/tests/screenshots/upload-2-medias.png' });
        console.log('✅ Onglet Médias ouvert\n');
        
        // 3. Chercher l'input file
        console.log('3️⃣ Recherche de l\'input file...');
        const inputFile = await page.$('input[type="file"]');
        if (!inputFile) {
            // Si pas visible, chercher dans tout le DOM
            const hasInput = await page.evaluate(() => {
                const inputs = document.querySelectorAll('input[type="file"]');
                return {
                    count: inputs.length,
                    details: Array.from(inputs).map(input => ({
                        id: input.id,
                        name: input.name,
                        accept: input.accept,
                        multiple: input.multiple,
                        display: window.getComputedStyle(input).display,
                        visible: input.offsetWidth > 0 && input.offsetHeight > 0
                    }))
                };
            });
            console.log('📊 Input files trouvés:', JSON.stringify(hasInput, null, 2));
            
            if (hasInput.count === 0) {
                throw new Error('Aucun input[type="file"] trouvé dans le DOM');
            }
        }
        console.log('✅ Input file trouvé\n');
        
        // 4. Vérifier les fonctions JavaScript
        console.log('4️⃣ Vérification des fonctions JavaScript...');
        const functions = await page.evaluate(() => {
            return {
                uploadFile: typeof uploadFile,
                handleFiles: typeof handleFiles,
                updateMediaList: typeof updateMediaList,
                refreshMediaList: typeof refreshMediaList
            };
        });
        console.log('📊 Fonctions disponibles:');
        for (const [func, type] of Object.entries(functions)) {
            console.log(`   ${func}: ${type}`);
        }
        console.log('');
        
        // 5. Upload du fichier
        console.log('5️⃣ Upload du fichier de test...');
        console.log(`   Fichier: ${TEST_FILE}`);
        
        // Méthode 1: Upload direct via input
        await inputFile.uploadFile(TEST_FILE);
        console.log('✅ Fichier sélectionné\n');
        
        // Attendre que l'upload se déclenche
        console.log('⏳ Attente de l\'upload (10 secondes)...');
        await new Promise(r => setTimeout(r, 10000));
        
        // 6. Vérifier le résultat
        console.log('\n6️⃣ Vérification du résultat...');
        await page.screenshot({ path: '/opt/pisignage/tests/screenshots/upload-3-after.png' });
        
        // Vérifier si le fichier apparaît dans la liste
        const mediaFiles = await page.evaluate(() => {
            const mediaList = document.getElementById('mediaList') || 
                              document.querySelector('.media-list') ||
                              document.querySelector('[id*="media"]');
            
            if (mediaList) {
                const files = Array.from(mediaList.querySelectorAll('.media-item, .file-item, li, tr'));
                return {
                    found: true,
                    count: files.length,
                    files: files.slice(0, 5).map(f => f.textContent.trim().substring(0, 50))
                };
            }
            return { found: false };
        });
        
        console.log('📊 Liste des médias:', JSON.stringify(mediaFiles, null, 2));
        
        // 7. Analyser les erreurs
        console.log('\n7️⃣ Analyse des erreurs...');
        const errors = consoleLogs.filter(log => log.type === 'error');
        if (errors.length > 0) {
            console.log('❌ Erreurs détectées:');
            errors.forEach(err => console.log(`   - ${err.text}`));
        }
        
        // 8. Analyser les requêtes réseau
        console.log('\n8️⃣ Requêtes réseau d\'upload:');
        const uploadRequests = networkRequests.filter(r => r.url.includes('upload'));
        if (uploadRequests.length > 0) {
            uploadRequests.forEach(req => {
                console.log(`   ${req.method} ${req.url}`);
                if (req.postData) {
                    console.log(`   Data: ${req.postData.substring(0, 100)}...`);
                }
            });
        } else {
            console.log('   ❌ AUCUNE requête d\'upload détectée !');
        }
        
        // DIAGNOSTIC FINAL
        console.log('\n============================================');
        console.log('📋 DIAGNOSTIC:');
        
        if (uploadRequests.length === 0) {
            console.log('❌ PROBLÈME: L\'upload ne se déclenche pas');
            console.log('   → L\'input file ne déclenche pas handleFiles()');
            console.log('   → Ou handleFiles() n\'appelle pas uploadFile()');
        }
        
        if (errors.some(e => e.text.includes('updateMediaList'))) {
            console.log('❌ PROBLÈME: updateMediaList non définie ou erreur');
        }
        
        if (!mediaFiles.found) {
            console.log('❌ PROBLÈME: Liste des médias non trouvée dans le DOM');
        }
        
    } catch (error) {
        console.error('🔴 Erreur fatale:', error.message);
        await page.screenshot({ path: '/opt/pisignage/tests/screenshots/upload-error.png' });
    } finally {
        // Sauvegarder les logs
        fs.writeFileSync(
            '/opt/pisignage/tests/upload-debug.json',
            JSON.stringify({
                consoleLogs,
                networkRequests,
                timestamp: new Date().toISOString()
            }, null, 2)
        );
        
        console.log('\n📁 Debug sauvegardé: /opt/pisignage/tests/upload-debug.json');
        console.log('📸 Screenshots: /opt/pisignage/tests/screenshots/');
        
        await browser.close();
    }
}

testUploadInterface().catch(console.error);