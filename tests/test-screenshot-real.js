#!/usr/bin/env node

/**
 * TEST SCREENSHOT COMPLET AVEC PUPPETEER
 * Teste le screenshot via l'interface réelle et prend des captures
 */

const puppeteer = require('puppeteer'));
const fs = require('fs'));
const path = require('path'));

const BASE_URL = 'http://192.168.1.103';
const SCREENSHOTS_DIR = '/opt/pisignage/tests/screenshots';

// Créer le dossier screenshots si nécessaire
if (!fs.existsSync(SCREENSHOTS_DIR)) {
    fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true }));
}

async function testScreenshot() {
    console.log('📸 TEST SCREENSHOT PI-SIGNAGE'));
    console.log('================================\n'));
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    }));
    
    const page = await browser.newPage());
    await page.setViewport({ width: 1920, height: 1080 }));
    
    // Capturer les erreurs console
    page.on('console', msg => {
        if (msg.type() === 'error') {
            console.log('❌ Console Error:', msg.text()));
        } else if (msg.type() === 'log') {
            console.log('📝 Console Log:', msg.text()));
        }
    }));
    
    // Intercepter les requêtes
    page.on('requestfailed', request => {
        console.log('❌ Request failed:', request.url()));
    }));
    
    page.on('response', response => {
        const url = response.url());
        if (url.includes('screenshot') || url.includes('action=screenshot')) {
            console.log(`🔍 Screenshot Request: ${url} - Status: ${response.status()}`));
        }
    }));
    
    try {
        // 1. Charger la page principale
        console.log('1️⃣ Chargement de la page...'));
        await page.goto(BASE_URL, { waitUntil: 'networkidle2', timeout: 30000 }));
        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '1-homepage.png') }));
        console.log('✅ Page chargée - Screenshot: 1-homepage.png\n'));
        
        // 2. Aller sur Dashboard
        console.log('2️⃣ Navigation vers Dashboard...'));
        const dashboardButton = await page.$('button[onclick*="dashboard"]'));
        if (dashboardButton) {
            await dashboardButton.click());
            await new Promise(r => setTimeout(r, 1000));
            console.log('✅ Dashboard ouvert'));
        } else {
            console.log('❌ Bouton Dashboard non trouvé'));
        }
        
        // 3. Vérifier si la fonction takeScreenshot existe
        console.log('\n3️⃣ Vérification de la fonction takeScreenshot...'));
        const hasTakeScreenshot = await page.evaluate(() => {
            return typeof takeScreenshot === 'function';
        }));
        console.log(hasTakeScreenshot ? '✅ Fonction takeScreenshot trouvée' : '❌ Fonction takeScreenshot MANQUANTE'));
        
        // 4. Vérifier si le bouton screenshot existe
        console.log('\n4️⃣ Recherche du bouton screenshot...'));
        const screenshotButton = await page.evaluate(() => {
            const buttons = Array.from(document.querySelectorAll('button')));
            const btn = buttons.find(b => 
                b.textContent.includes('Screenshot') || 
                b.textContent.includes('Capture') ||
                b.onclick && b.onclick.toString().includes('screenshot')
            ));
            return btn ? {
                exists: true,
                text: btn.textContent.trim(),
                onclick: btn.onclick ? btn.onclick.toString().substring(0, 100) : null
            } : { exists: false };
        }));
        
        if (screenshotButton.exists) {
            console.log(`✅ Bouton trouvé: "${screenshotButton.text}"`));
            console.log(`   onclick: ${screenshotButton.onclick}`));
        } else {
            console.log('❌ Bouton screenshot NON trouvé'));
        }
        
        // 5. Essayer d'appeler takeScreenshot directement
        console.log('\n5️⃣ Appel direct de takeScreenshot()...'));
        const screenshotResult = await page.evaluate(async () => {
            if (typeof takeScreenshot === 'function') {
                try {
                    // Appeler takeScreenshot
                    takeScreenshot());
                    
                    // Attendre un peu
                    await new Promise(resolve => setTimeout(resolve, 2000)));
                    
                    // Chercher l'image affichée
                    const img = document.querySelector('#screenshotPreview img') ||
                               document.querySelector('img[src*="screenshot"]') ||
                               document.querySelector('.screenshot-preview img'));
                    
                    return {
                        functionCalled: true,
                        imageFound: !!img,
                        imageSrc: img ? img.src : null,
                        imageVisible: img ? (img.offsetWidth > 0 && img.offsetHeight > 0) : false
                    };
                } catch (error) {
                    return { error: error.message };
                }
            } else {
                return { error: 'takeScreenshot not defined' };
            }
        }));
        
        console.log('Résultat:', JSON.stringify(screenshotResult, null, 2)));
        
        // 6. Prendre une capture après 3 secondes
        console.log('\n6️⃣ Attente de 3 secondes pour le chargement...'));
        await new Promise(r => setTimeout(r, 3000));
        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '2-after-screenshot.png') }));
        console.log('✅ Screenshot pris: 2-after-screenshot.png'));
        
        // 7. Vérifier si une image est visible
        console.log('\n7️⃣ Vérification de l\'affichage du screenshot...'));
        const screenshotDisplay = await page.evaluate(() => {
            const images = Array.from(document.querySelectorAll('img')));
            const screenshotImages = images.filter(img => 
                img.src.includes('screenshot') || 
                img.src.includes('current.png') ||
                img.src.includes('assets/screenshots')
            ));
            
            return screenshotImages.map(img => ({
                src: img.src,
                width: img.width,
                height: img.height,
                visible: img.offsetWidth > 0 && img.offsetHeight > 0,
                alt: img.alt,
                id: img.id,
                parent: img.parentElement ? img.parentElement.id || img.parentElement.className : null
            })));
        }));
        
        if (screenshotDisplay.length > 0) {
            console.log(`✅ ${screenshotDisplay.length} image(s) screenshot trouvée(s):`));
            screenshotDisplay.forEach(img => {
                console.log(`   - ${img.src}`));
                console.log(`     Taille: ${img.width}x${img.height}, Visible: ${img.visible}`));
                console.log(`     Parent: ${img.parent}`));
            }));
        } else {
            console.log('❌ AUCUNE image screenshot trouvée dans le DOM'));
        }
        
        // 8. Tester l'API directement
        console.log('\n8️⃣ Test direct de l\'API screenshot...'));
        const apiTest = await page.evaluate(async () => {
            try {
                const response = await fetch('/?action=screenshot'));
                const data = await response.json());
                return {
                    status: response.status,
                    success: data.success,
                    screenshot: data.screenshot,
                    error: data.error
                };
            } catch (e) {
                return { error: e.message };
            }
        }));
        
        console.log('API Response:', JSON.stringify(apiTest, null, 2)));
        
        // 9. Si l'API retourne une image, vérifier qu'elle est accessible
        if (apiTest.success && apiTest.screenshot) {
            console.log('\n9️⃣ Vérification de l\'accessibilité de l\'image...'));
            const imageUrl = `${BASE_URL}/${apiTest.screenshot}`;
            const imageAccessible = await page.evaluate(async (url) => {
                try {
                    const response = await fetch(url));
                    return {
                        accessible: response.ok,
                        status: response.status,
                        contentType: response.headers.get('content-type')
                    };
                } catch (e) {
                    return { accessible: false, error: e.message };
                }
            }, imageUrl));
            
            if (imageAccessible.accessible) {
                console.log(`✅ Image accessible: ${imageUrl}`));
                console.log(`   Content-Type: ${imageAccessible.contentType}`));
            } else {
                console.log(`❌ Image NON accessible: ${imageUrl}`));
                console.log(`   Erreur: ${imageAccessible.error || `HTTP ${imageAccessible.status}`}`));
            }
        }
        
        // 10. Capture finale
        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '3-final-state.png'), fullPage: true }));
        console.log('\n✅ Capture finale: 3-final-state.png'));
        
        // DIAGNOSTIC
        console.log('\n================================'));
        console.log('📊 DIAGNOSTIC:'));
        
        if (!hasTakeScreenshot) {
            console.log('❌ PROBLÈME: Fonction takeScreenshot non définie'));
            console.log('   → Solution: Ajouter la fonction dans index.php'));
        }
        
        if (!screenshotButton.exists) {
            console.log('❌ PROBLÈME: Bouton screenshot non trouvé'));
            console.log('   → Solution: Vérifier le HTML du Dashboard'));
        }
        
        if (screenshotDisplay.length === 0) {
            console.log('❌ PROBLÈME: Aucune image affichée'));
            console.log('   → Solution: Vérifier que l\'image est ajoutée au DOM après l\'appel API'));
        }
        
        if (!apiTest.success) {
            console.log('❌ PROBLÈME: API screenshot échoue'));
            console.log(`   → Erreur: ${apiTest.error}`));
        }
        
    } catch (error) {
        console.error('❌ Erreur fatale:', error.message));
        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, 'error-state.png'), fullPage: true }));
    } finally {
        await browser.close());
        console.log('\n📁 Screenshots sauvés dans:', SCREENSHOTS_DIR));
    }
}

// Lancer le test
testScreenshot().catch(console.error));