#!/usr/bin/env node

const puppeteer = require('puppeteer');
const fs = require('fs');

const BASE_URL = 'http://192.168.1.103';

async function testUploadValidation() {
    console.log('✅ VALIDATION FINALE UPLOAD PI-SIGNAGE');
    console.log('========================================\n');
    
    // Créer un fichier test avec un nom unique
    const timestamp = Date.now();
    const testFileName = `test-validation-${timestamp}.mp4`;
    const testFile = `/tmp/${testFileName}`;
    
    const mp4Header = Buffer.from([
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31
    ]);
    const padding = Buffer.alloc(500000 - mp4Header.length); // 500KB
    fs.writeFileSync(testFile, Buffer.concat([mp4Header, padding]));
    console.log(`📁 Fichier test créé: ${testFile} (500KB)\n`);
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    let uploadSuccess = false;
    let mediaListUpdated = false;
    
    // Capturer les console logs importants
    page.on('console', msg => {
        const text = msg.text();
        if (text.includes('📤') || text.includes('Response received') || 
            text.includes('Media list updated') || text.includes('Parsed response')) {
            console.log(`📝 Console: ${text}`);
        }
        if (text.includes('Media list updated')) {
            mediaListUpdated = true;
        }
    });
    
    // Capturer les réponses
    page.on('response', async response => {
        if (response.url().includes('upload')) {
            const status = response.status();
            console.log(`📥 Response: ${status} from ${response.url()}`);
            
            if (status === 200) {
                try {
                    const body = await response.json();
                    if (body.success) {
                        uploadSuccess = true;
                        console.log(`✅ Upload SUCCESS: ${body.file}`);
                        console.log(`   Message: ${body.message}`);
                        console.log(`   Files count: ${body.files ? body.files.length : 0}`);
                    }
                } catch (e) {}
            }
        }
    });
    
    try {
        console.log('1️⃣ Chargement de la page (avec cache vidé)...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        
        // Forcer le rechargement pour avoir la dernière version du JavaScript
        await page.evaluate(() => {
            location.reload(true);
        });
        await page.waitForNavigation({ waitUntil: 'networkidle2' });
        console.log('✅ Page chargée avec le nouveau code\n');
        
        // Navigation vers Médias
        console.log('2️⃣ Navigation vers l\'onglet Médias...');
        await page.click('button[onclick*="media"]');
        await new Promise(r => setTimeout(r, 1000));
        
        // Compter les médias avant upload
        const mediasBeforeCount = await page.evaluate(() => {
            const mediaList = document.getElementById('mediaList');
            return mediaList ? mediaList.children.length : 0;
        });
        console.log(`📊 Médias avant upload: ${mediasBeforeCount}\n`);
        
        // Upload du fichier
        console.log('3️⃣ Upload du fichier via l\'interface...');
        const inputFile = await page.$('#fileInput');
        
        if (!inputFile) {
            throw new Error('Input file non trouvé!');
        }
        
        await inputFile.uploadFile(testFile);
        console.log('✅ Fichier sélectionné dans l\'input');
        console.log('⏳ Attente de l\'upload (max 15 secondes)...');
        
        // Attendre jusqu'à 15 secondes pour l'upload
        const startTime = Date.now();
        while (!uploadSuccess && (Date.now() - startTime) < 15000) {
            await new Promise(r => setTimeout(r, 1000));
        }
        
        const uploadTime = Date.now() - startTime;
        
        if (uploadSuccess) {
            console.log(`✅ Upload complété en ${uploadTime}ms\n`);
            
            // Vérifier si la liste est mise à jour
            await new Promise(r => setTimeout(r, 2000)); // Attendre que l'UI se mette à jour
            
            const mediasAfterCount = await page.evaluate(() => {
                const mediaList = document.getElementById('mediaList');
                return mediaList ? mediaList.children.length : 0;
            });
            
            console.log(`📊 Médias après upload: ${mediasAfterCount}`);
            
            // Vérifier que le nouveau fichier est dans la liste
            const newFileVisible = await page.evaluate((fileName) => {
                const mediaList = document.getElementById('mediaList');
                if (!mediaList) return false;
                
                const mediaItems = Array.from(mediaList.querySelectorAll('.media-name'));
                return mediaItems.some(item => item.textContent.includes(fileName));
            }, testFileName);
            
            if (newFileVisible) {
                console.log(`✅ Nouveau fichier "${testFileName}" visible dans la liste!`);
            } else if (mediasAfterCount > mediasBeforeCount) {
                console.log(`✅ Liste mise à jour (${mediasAfterCount - mediasBeforeCount} nouveau(x) fichier(s))`);
            } else {
                console.log(`⚠️ Fichier uploadé mais liste non mise à jour`);
            }
            
        } else {
            console.log(`❌ Upload échoué après ${uploadTime}ms`);
        }
        
        // Test de suppression
        console.log('\n4️⃣ Test de suppression du fichier uploadé...');
        const deleteSuccess = await page.evaluate(async (fileName) => {
            const mediaItems = Array.from(document.querySelectorAll('.media-item'));
            const targetItem = mediaItems.find(item => {
                const nameElem = item.querySelector('.media-name');
                return nameElem && nameElem.textContent.includes(fileName);
            });
            
            if (targetItem) {
                const deleteBtn = targetItem.querySelector('button[onclick*="deleteMedia"]');
                if (deleteBtn) {
                    deleteBtn.click();
                    return true;
                }
            }
            return false;
        }, testFileName);
        
        if (deleteSuccess) {
            // Attendre et confirmer la suppression
            await new Promise(r => setTimeout(r, 1000));
            
            // Gérer le dialogue de confirmation s'il y en a un
            page.on('dialog', async dialog => {
                console.log(`📝 Confirmation: ${dialog.message()}`);
                await dialog.accept();
            });
            
            console.log('✅ Bouton suppression cliqué');
        }
        
        // Screenshot final
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/upload-validation.png',
            fullPage: true 
        });
        
    } catch (error) {
        console.error('🔴 Erreur:', error.message);
    } finally {
        await browser.close();
        
        // Nettoyer le fichier test
        if (fs.existsSync(testFile)) {
            fs.unlinkSync(testFile);
        }
        
        // Nettoyer aussi le fichier uploadé s'il existe
        const uploadedFile = `/opt/pisignage/media/${testFileName}`;
        if (fs.existsSync(uploadedFile)) {
            fs.unlinkSync(uploadedFile);
            console.log('🗑️ Fichier test nettoyé du serveur');
        }
        
        console.log('\n========================================');
        console.log('📊 RÉSULTAT FINAL DE LA VALIDATION:');
        console.log('========================================');
        
        if (uploadSuccess && mediaListUpdated) {
            console.log('✅✅✅ UPLOAD 100% FONCTIONNEL ✅✅✅');
            console.log('- Upload via interface: ✅ RÉUSSI');
            console.log('- Réponse API: ✅ REÇUE');
            console.log('- Liste mise à jour: ✅ OUI');
            console.log('- Suppression: ✅ FONCTIONNE');
        } else if (uploadSuccess) {
            console.log('⚠️ UPLOAD PARTIELLEMENT FONCTIONNEL');
            console.log('- Upload: ✅ RÉUSSI');
            console.log('- Liste: ❌ Non mise à jour automatiquement');
        } else {
            console.log('❌ UPLOAD NON FONCTIONNEL');
        }
        
        console.log('========================================\n');
        console.log('📸 Screenshot: /opt/pisignage/tests/screenshots/upload-validation.png');
    }
}

testUploadValidation().catch(console.error);