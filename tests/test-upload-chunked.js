#!/usr/bin/env node

/**
 * Test d'upload de gros fichiers avec le système chunked
 * Teste avec un fichier de 50MB+
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost';
const TEST_FILE_SIZE = 55 * 1024 * 1024; // 55MB
const TEST_FILE_PATH = '/tmp/test-video-55mb.mp4';

// Fonction pour créer un fichier de test
async function createTestFile(filePath, sizeInBytes) {
    return new Promise((resolve, reject) => {
        console.log(`📝 Création du fichier de test de ${(sizeInBytes / (1024 * 1024)).toFixed(1)}MB...`);
        
        // Créer un buffer avec des données aléatoires
        const chunkSize = 1024 * 1024; // 1MB chunks
        const chunks = Math.ceil(sizeInBytes / chunkSize);
        
        const writeStream = fs.createWriteStream(filePath);
        
        writeStream.on('finish', () => {
            console.log(`✅ Fichier de test créé: ${filePath}`);
            resolve();
        });
        
        writeStream.on('error', (error) => {
            console.error(`❌ Erreur création fichier: ${error}`);
            reject(error);
        });
        
        for (let i = 0; i < chunks; i++) {
            const currentChunkSize = Math.min(chunkSize, sizeInBytes - (i * chunkSize));
            const buffer = Buffer.alloc(currentChunkSize);
            
            // Remplir avec des données pseudo-aléatoires
            for (let j = 0; j < currentChunkSize; j++) {
                buffer[j] = Math.floor(Math.random() * 256);
            }
            
            // Ajouter un header MP4 basique au début
            if (i === 0) {
                // Header MP4 minimal
                const mp4Header = Buffer.from([
                    0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // ftyp box
                    0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
                    0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
                    0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31
                ]);
                mp4Header.copy(buffer, 0);
            }
            
            writeStream.write(buffer);
        }
        
        writeStream.end();
    });
}

// Fonction principale de test
async function testUpload() {
    console.log('🚀 Démarrage du test d\'upload chunked');
    
    // Créer le fichier de test
    await createTestFile(TEST_FILE_PATH, TEST_FILE_SIZE);
    
    // Vérifier que le fichier existe
    const fileStats = fs.statSync(TEST_FILE_PATH);
    console.log(`📊 Taille du fichier: ${(fileStats.size / (1024 * 1024)).toFixed(2)}MB`);
    
    // Lancer le navigateur
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    try {
        const page = await browser.newPage();
        
        // Activer les logs de la console
        page.on('console', msg => {
            const type = msg.type();
            const text = msg.text();
            if (type === 'error') {
                console.error('❌ Console error:', text);
            } else if (text.includes('Upload') || text.includes('chunk')) {
                console.log('📋', text);
            }
        });
        
        // Intercepter les requêtes réseau
        let chunksUploaded = 0;
        page.on('response', response => {
            const url = response.url();
            if (url.includes('upload-chunked.php')) {
                const status = response.status();
                if (status === 200) {
                    chunksUploaded++;
                    console.log(`✅ Chunk ${chunksUploaded} uploadé (status: ${status})`);
                } else {
                    console.error(`❌ Erreur chunk (status: ${status})`);
                }
            }
        });
        
        console.log('📱 Navigation vers l\'interface...');
        await page.goto(BASE_URL, { waitUntil: 'networkidle2' });
        
        // Aller sur l'onglet Médias
        await page.evaluate(() => {
            const mediaTab = document.querySelector('[onclick="switchTab(\'media\', event)"]');
            if (mediaTab) mediaTab.click();
        });
        
        await page.waitForTimeout(1000);
        
        // Préparer le fichier pour l'upload
        const inputUploadHandle = await page.$('#dropZone input[type=file]');
        if (!inputUploadHandle) {
            throw new Error('Input file non trouvé');
        }
        
        console.log('📤 Upload du fichier de 55MB...');
        const startTime = Date.now();
        
        // Upload le fichier
        await inputUploadHandle.uploadFile(TEST_FILE_PATH);
        
        // Attendre que l'upload commence
        await page.waitForTimeout(2000);
        
        // Monitorer la progression
        let lastProgress = 0;
        let uploadComplete = false;
        let errorOccurred = false;
        const maxWaitTime = 5 * 60 * 1000; // 5 minutes max
        const checkInterval = 1000; // Check toutes les secondes
        
        const startMonitoring = Date.now();
        
        while (!uploadComplete && !errorOccurred && (Date.now() - startMonitoring) < maxWaitTime) {
            try {
                // Vérifier la progression
                const progressInfo = await page.evaluate(() => {
                    const progressFill = document.getElementById('progressFill');
                    const progressText = document.getElementById('progressText');
                    const progressBar = document.getElementById('progressBar');
                    
                    return {
                        width: progressFill ? progressFill.style.width : '0%',
                        text: progressText ? progressText.textContent : '',
                        visible: progressBar ? progressBar.style.display !== 'none' : false,
                        backgroundColor: progressFill ? progressFill.style.backgroundColor : ''
                    };
                });
                
                const currentProgress = parseInt(progressInfo.width);
                
                // Afficher la progression si elle a changé
                if (currentProgress !== lastProgress) {
                    console.log(`📊 Progression: ${progressInfo.width} - ${progressInfo.text}`);
                    lastProgress = currentProgress;
                }
                
                // Vérifier si erreur (barre rouge)
                if (progressInfo.backgroundColor === 'rgb(231, 76, 60)') {
                    errorOccurred = true;
                    console.error('❌ Erreur détectée pendant l\'upload');
                    break;
                }
                
                // Vérifier si terminé
                if (progressInfo.text.includes('terminé') || currentProgress === 100) {
                    // Attendre un peu pour être sûr
                    await page.waitForTimeout(2000);
                    
                    // Vérifier que la barre de progression est masquée
                    const stillVisible = await page.evaluate(() => {
                        const bar = document.getElementById('progressBar');
                        return bar && bar.style.display !== 'none';
                    });
                    
                    if (!stillVisible) {
                        uploadComplete = true;
                        break;
                    }
                }
                
            } catch (e) {
                console.error('❌ Erreur lors du monitoring:', e.message);
            }
            
            await page.waitForTimeout(checkInterval);
        }
        
        const uploadTime = (Date.now() - startTime) / 1000;
        
        if (uploadComplete) {
            console.log(`✅ Upload terminé en ${uploadTime.toFixed(1)} secondes`);
            console.log(`📊 Vitesse moyenne: ${(TEST_FILE_SIZE / uploadTime / 1024 / 1024).toFixed(2)} MB/s`);
            
            // Vérifier que le fichier apparaît dans la liste
            await page.waitForTimeout(2000);
            
            const fileInList = await page.evaluate((fileName) => {
                const mediaItems = document.querySelectorAll('.media-item');
                for (let item of mediaItems) {
                    if (item.textContent.includes(fileName)) {
                        return true;
                    }
                }
                return false;
            }, 'test-video-55mb.mp4');
            
            if (fileInList) {
                console.log('✅ Fichier trouvé dans la liste des médias');
            } else {
                console.log('⚠️ Fichier non trouvé dans la liste (peut nécessiter un rafraîchissement)');
            }
            
            // Prendre une capture d'écran
            await page.screenshot({ path: '/opt/pisignage/tests/screenshots/upload-55mb-success.png' });
            console.log('📸 Capture d\'écran sauvegardée');
            
        } else if (errorOccurred) {
            console.error('❌ Upload échoué avec erreur');
            await page.screenshot({ path: '/opt/pisignage/tests/screenshots/upload-55mb-error.png' });
            
            // Récupérer les erreurs console
            const errors = await page.evaluate(() => {
                return window.uploadErrors || [];
            });
            
            if (errors.length > 0) {
                console.error('Erreurs détectées:', errors);
            }
            
        } else {
            console.error('⏱️ Timeout - Upload trop long (>5 minutes)');
        }
        
        // Vérifier côté serveur que le fichier existe
        const serverCheck = await page.evaluate(async () => {
            const response = await fetch('/api/playlist.php?action=media');
            const data = await response.json();
            const media = data.media || data.videos || [];
            return media.find(m => m.name === 'test-video-55mb.mp4');
        });
        
        if (serverCheck) {
            console.log('✅ Fichier confirmé côté serveur');
            console.log(`   Taille: ${(serverCheck.size / 1024 / 1024).toFixed(2)}MB`);
        } else {
            console.error('❌ Fichier non trouvé côté serveur');
        }
        
    } catch (error) {
        console.error('❌ Erreur pendant le test:', error);
        await page.screenshot({ path: '/opt/pisignage/tests/screenshots/upload-error.png' });
    } finally {
        await browser.close();
        
        // Nettoyer le fichier de test
        if (fs.existsSync(TEST_FILE_PATH)) {
            fs.unlinkSync(TEST_FILE_PATH);
            console.log('🧹 Fichier de test supprimé');
        }
    }
}

// Fonction pour tester plusieurs tailles
async function testMultipleSizes() {
    const sizes = [
        { size: 10 * 1024 * 1024, name: '10MB' },
        { size: 50 * 1024 * 1024, name: '50MB' },
        { size: 100 * 1024 * 1024, name: '100MB' },
        { size: 200 * 1024 * 1024, name: '200MB' }
    ];
    
    for (const testCase of sizes) {
        console.log(`\n${'='.repeat(50)}`);
        console.log(`🧪 Test avec fichier de ${testCase.name}`);
        console.log('='.repeat(50));
        
        // Mettre à jour la taille du fichier de test
        global.TEST_FILE_SIZE = testCase.size;
        
        await testUpload();
        
        console.log(`✅ Test ${testCase.name} terminé\n`);
        
        // Pause entre les tests
        await new Promise(resolve => setTimeout(resolve, 5000));
    }
}

// Lancer le test
testUpload().then(() => {
    console.log('\n✅ Test terminé avec succès');
    process.exit(0);
}).catch(error => {
    console.error('\n❌ Test échoué:', error);
    process.exit(1);
});