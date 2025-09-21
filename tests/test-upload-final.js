#!/usr/bin/env node

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://192.168.1.103';

async function wait(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function testUploadFinal() {
    console.log('✅ TEST FINAL UPLOAD PI-SIGNAGE');
    console.log('=================================\n');
    
    // Créer un fichier MP4 de test (2MB)
    const testFile = '/tmp/test-final-upload.mp4';
    console.log('📁 Création du fichier de test (2MB)...');
    const mp4Header = Buffer.from([
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31
    ]);
    const padding = Buffer.alloc(2 * 1024 * 1024 - mp4Header.length);
    fs.writeFileSync(testFile, Buffer.concat([mp4Header, padding]));
    console.log(`✅ Fichier créé: ${testFile}\n`);
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    let uploadSuccess = false;
    let uploadedFileName = null;
    
    // Intercepter les réponses de l'API upload
    page.on('response', async response => {
        const url = response.url();
        if (url.includes('api/upload.php')) {
            const status = response.status();
            console.log(`📥 Upload Response: ${status}`);
            
            if (status === 200) {
                try {
                    const body = await response.json();
                    if (body.success) {
                        uploadSuccess = true;
                        uploadedFileName = body.file;
                        console.log(`✅ Upload réussi: ${body.file}`);
                        console.log(`   Taille: ${body.size} bytes`);
                        console.log(`   Message: ${body.message}`);
                    } else {
                        console.log(`❌ Upload échoué: ${body.error || 'Erreur inconnue'}`);
                    }
                } catch (e) {
                    console.log(`⚠️ Impossible de parser la réponse`);
                }
            }
        }
    });
    
    try {
        // 1. Charger l'interface
        console.log('1️⃣ Chargement de l\'interface...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        console.log('✅ Interface chargée\n');
        
        // 2. Compter les médias avant upload
        console.log('2️⃣ Comptage des médias existants...');
        await page.click('button[onclick*="media"]');
        await wait(1000);
        
        const mediasBeforeCount = await page.evaluate(() => {
            const mediaList = document.getElementById('mediaList');
            if (mediaList) {
                const items = mediaList.querySelectorAll('.media-item, .video-item, li');
                return items.length;
            }
            return 0;
        });
        console.log(`📊 Médias avant upload: ${mediasBeforeCount}\n`);
        
        // 3. Upload du fichier
        console.log('3️⃣ Upload du fichier...');
        const inputFile = await page.$('#fileInput');
        await inputFile.uploadFile(testFile);
        
        // Attendre la réponse de l'upload
        console.log('⏳ Attente de la réponse...');
        await wait(5000);
        
        // 4. Vérifier le résultat
        console.log('\n4️⃣ Vérification du résultat...');
        
        if (uploadSuccess) {
            // Vérifier que le fichier apparaît dans la liste
            const mediasAfterCount = await page.evaluate(() => {
                const mediaList = document.getElementById('mediaList');
                if (mediaList) {
                    const items = mediaList.querySelectorAll('.media-item, .video-item, li');
                    return items.length;
                }
                return 0;
            });
            
            console.log(`📊 Médias après upload: ${mediasAfterCount}`);
            
            if (mediasAfterCount > mediasBeforeCount) {
                console.log('✅ Nouveau fichier visible dans la liste!');
            } else {
                console.log('⚠️ Fichier uploadé mais pas encore visible');
                console.log('🔄 Rafraîchissement...');
                
                await page.evaluate(() => {
                    if (typeof refreshMediaList === 'function') {
                        refreshMediaList();
                    }
                });
                await wait(2000);
                
                const mediasAfterRefresh = await page.evaluate(() => {
                    const mediaList = document.getElementById('mediaList');
                    if (mediaList) {
                        const items = mediaList.querySelectorAll('.media-item, .video-item, li');
                        return items.length;
                    }
                    return 0;
                });
                
                console.log(`📊 Médias après refresh: ${mediasAfterRefresh}`);
                
                if (mediasAfterRefresh > mediasBeforeCount) {
                    console.log('✅ Fichier maintenant visible après refresh!');
                }
            }
        } else {
            console.log('❌ Upload a échoué - aucune réponse positive de l\'API');
        }
        
        // Screenshot final
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/upload-final.png',
            fullPage: true 
        });
        
        // RÉSULTAT FINAL
        console.log('\n=================================');
        console.log('📊 RÉSULTAT FINAL:');
        if (uploadSuccess) {
            console.log('✅ UPLOAD FONCTIONNE !');
            console.log(`   - Fichier: ${uploadedFileName}`);
            console.log('   - Event listener OK');
            console.log('   - API répond avec succès');
        } else {
            console.log('❌ PROBLÈME DÉTECTÉ');
        }
        console.log('=================================');
        
    } catch (error) {
        console.error('🔴 Erreur:', error.message);
    } finally {
        await browser.close();
        fs.unlinkSync(testFile);
        console.log('\n📸 Screenshot sauvé');
    }
}

testUploadFinal().catch(console.error);
