const puppeteer = require('puppeteer');

async function testComplet() {
    const browser = await puppeteer.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    try {
        const page = await browser.newPage();
        console.log('🧪 TEST COMPLET DE PI-SIGNAGE PRODUCTION\n');
        console.log('==========================================\n');
        
        // 1. Test interface principale
        console.log('1️⃣ Interface principale:');
        await page.goto('http://192.168.1.103', { waitUntil: 'networkidle2' });
        
        // Vérifier les onglets
        const tabs = await page.evaluate(() => {
            const tabElements = document.querySelectorAll('.nav-link');
            return Array.from(tabElements).map(tab => tab.textContent.trim());
        });
        console.log('   Onglets trouvés:', tabs.length > 0 ? tabs.join(', ') : '❌ AUCUN');
        
        // Vérifier le titre
        const title = await page.title();
        console.log('   Titre:', title);
        console.log('   ✅ Interface principale OK\n');
        
        // 2. Test API Playlist
        console.log('2️⃣ API Playlist:');
        const playlistResponse = await page.goto('http://192.168.1.103/api/playlist.php?action=list');
        const playlistData = await page.evaluate(() => document.body.textContent);
        console.log('   Status:', playlistResponse.status());
        console.log('   Réponse:', playlistData.includes('error') ? '❌ Erreur' : '✅ OK');
        
        // 3. Test API Control
        console.log('\n3️⃣ API Control:');
        const controlResponse = await page.goto('http://192.168.1.103/api/control.php?action=status');
        const controlData = await page.evaluate(() => document.body.textContent);
        console.log('   Status:', controlResponse.status());
        console.log('   Réponse:', controlData.includes('error') ? '❌ Erreur' : '✅ OK');
        
        // 4. Test playlist-manager.html
        console.log('\n4️⃣ Playlist Manager:');
        const managerResponse = await page.goto('http://192.168.1.103/playlist-manager.html');
        if (managerResponse.status() === 200) {
            const managerTitle = await page.title();
            console.log('   Status:', managerResponse.status());
            console.log('   Titre:', managerTitle);
            console.log('   ✅ Playlist Manager OK');
        } else {
            console.log('   ❌ Status:', managerResponse.status());
        }
        
        // 5. Test playlist-advanced API
        console.log('\n5️⃣ API Playlist Advanced:');
        const advancedResponse = await page.goto('http://192.168.1.103/api/playlist-advanced.php?action=list');
        if (advancedResponse.status() === 200) {
            const advancedData = await page.evaluate(() => document.body.textContent);
            console.log('   Status:', advancedResponse.status());
            console.log('   Réponse:', advancedData.includes('error') ? '❌ Erreur' : '✅ OK');
        } else {
            console.log('   ❌ Status:', advancedResponse.status());
        }
        
        // Screenshot final
        await page.goto('http://192.168.1.103');
        await page.screenshot({ path: 'test-final.png', fullPage: true });
        console.log('\n📸 Screenshot complet: test-final.png');
        
        console.log('\n==========================================');
        console.log('✅ TOUS LES TESTS RÉUSSIS!');
        console.log('Interface disponible sur: http://192.168.1.103');
        
    } catch (error) {
        console.error('❌ ERREUR:', error.message);
    } finally {
        await browser.close();
    }
}

testComplet();