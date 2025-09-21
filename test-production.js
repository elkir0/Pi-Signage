const puppeteer = require('puppeteer');

async function testProduction() {
    const browser = await puppeteer.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    try {
        const page = await browser.newPage();
        console.log('🔍 Test de http://192.168.1.103 ...\n');
        
        // Test page principale
        console.log('1️⃣ Test page principale:');
        const response = await page.goto('http://192.168.1.103', { 
            waitUntil: 'networkidle2',
            timeout: 10000 
        });
        
        console.log(`   Status: ${response.status()}`);
        console.log(`   URL finale: ${page.url()}`);
        
        // Capture du contenu
        const title = await page.title();
        console.log(`   Titre: ${title}`);
        
        const bodyText = await page.evaluate(() => document.body.innerText);
        console.log(`   Contenu (100 premiers chars): ${bodyText.substring(0, 100)}...`);
        
        // Screenshot
        await page.screenshot({ path: 'test-production-main.png' });
        console.log('   Screenshot: test-production-main.png\n');
        
        // Test API playlist
        console.log('2️⃣ Test API Playlist:');
        const apiResponse = await page.goto('http://192.168.1.103/api/playlist.php?action=list', {
            waitUntil: 'networkidle2',
            timeout: 10000
        });
        
        console.log(`   Status: ${apiResponse.status()}`);
        const apiContent = await page.content();
        console.log(`   Réponse: ${apiContent.includes('error') ? '❌ ERREUR' : '✅ OK'}`);
        
    } catch (error) {
        console.error('❌ ERREUR:', error.message);
    } finally {
        await browser.close();
    }
}

testProduction();