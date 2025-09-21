const puppeteer = require('puppeteer');

async function testConsole() {
    console.log('🔍 Test des erreurs console sur PiSignage\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    
    // Capture toutes les erreurs console
    const consoleErrors = [];
    const networkErrors = [];
    
    page.on('console', msg => {
        if (msg.type() === 'error') {
            consoleErrors.push({
                text: msg.text(),
                location: msg.location()
            });
        }
    });
    
    page.on('pageerror', error => {
        consoleErrors.push({
            message: error.message,
            stack: error.stack
        });
    });
    
    page.on('requestfailed', request => {
        networkErrors.push({
            url: request.url(),
            failure: request.failure().errorText
        });
    });

    // Charger la page
    console.log('📡 Chargement de http://192.168.1.103/');
    await page.goto('http://192.168.1.103/', { 
        waitUntil: 'networkidle2',
        timeout: 30000 
    });
    
    // Attendre un peu pour que toutes les requêtes se terminent
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Test screenshot
    console.log('\n📸 Test de la fonction screenshot...');
    try {
        const screenshotResult = await page.evaluate(() => {
            return new Promise((resolve) => {
                fetch('/?action=screenshot', { method: 'POST' })
                    .then(r => r.json())
                    .then(data => resolve(data))
                    .catch(err => resolve({ error: err.message }));
            });
        });
        console.log('Screenshot result:', screenshotResult);
    } catch (err) {
        console.log('Screenshot error:', err.message);
    }
    
    // Afficher les erreurs console
    console.log('\n❌ Erreurs Console détectées:', consoleErrors.length);
    consoleErrors.forEach((err, i) => {
        console.log(`\n${i + 1}. ${err.text || err.message}`);
        if (err.location) {
            console.log('   Location:', err.location.url);
        }
    });
    
    // Afficher les erreurs réseau
    console.log('\n🌐 Erreurs Réseau détectées:', networkErrors.length);
    networkErrors.forEach((err, i) => {
        console.log(`\n${i + 1}. ${err.url}`);
        console.log('   Error:', err.failure);
    });
    
    // Vérifier les URLs problématiques
    console.log('\n🔗 Vérification des URLs d\'API...');
    const apiTests = [
        '/api/playlist.php?action=list',
        '/api/youtube.php?action=queue',
        '/api/youtube.php?action=status'
    ];
    
    for (const url of apiTests) {
        const response = await page.evaluate(async (apiUrl) => {
            try {
                const res = await fetch(apiUrl);
                const text = await res.text();
                return { 
                    url: apiUrl,
                    status: res.status, 
                    ok: res.ok,
                    isJson: text.startsWith('{') || text.startsWith('['),
                    preview: text.substring(0, 100)
                };
            } catch (error) {
                return { url: apiUrl, error: error.message };
            }
        }, url);
        
        console.log(`\n${url}:`);
        console.log(`  Status: ${response.status || 'ERROR'}`);
        console.log(`  JSON: ${response.isJson ? '✅' : '❌'}`);
        if (!response.isJson && response.preview) {
            console.log(`  Preview: ${response.preview.replace(/\n/g, ' ')}`);
        }
    }
    
    await browser.close();
    
    // Résumé
    console.log('\n📊 Résumé:');
    console.log(`  - Erreurs console: ${consoleErrors.length}`);
    console.log(`  - Erreurs réseau: ${networkErrors.length}`);
    
    process.exit(consoleErrors.length > 0 || networkErrors.length > 0 ? 1 : 0);
}

testConsole().catch(console.error);