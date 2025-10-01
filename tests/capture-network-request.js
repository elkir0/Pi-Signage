const puppeteer = require('puppeteer');

(async () => {
    console.log('🔍 CAPTURE: Requête réseau exacte du navigateur\n');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture TOUTES les requêtes POST vers schedule.php
    let capturedRequest = null;
    
    page.on('request', request => {
        if (request.url().includes('/api/schedule.php') && request.method() === 'POST') {
            capturedRequest = {
                url: request.url(),
                method: request.method(),
                headers: request.headers(),
                postData: request.postData()
            };
            console.log('📤 REQUÊTE POST CAPTURÉE:');
            console.log('URL:', request.url());
            console.log('Method:', request.method());
            console.log('\n📦 POST DATA (raw):');
            console.log(request.postData());
            console.log('\n📦 POST DATA (parsed):');
            try {
                const parsed = JSON.parse(request.postData());
                console.log(JSON.stringify(parsed, null, 2));
                console.log('\n🔍 CRITICAL FIELDS:');
                console.log('   conflict_behavior:', parsed.conflict_behavior);
                console.log('   enabled:', parsed.enabled);
                console.log('   start_time:', parsed.schedule?.start_time);
                console.log('   end_time:', parsed.schedule?.end_time);
            } catch (e) {
                console.log('Unable to parse JSON:', e.message);
            }
        }
    });

    // Capture TOUTES les réponses
    page.on('response', async response => {
        if (response.url().includes('/api/schedule.php') && response.request().method() === 'POST') {
            console.log('\n📥 RÉPONSE API:');
            console.log('Status:', response.status(), response.statusText());
            
            try {
                const responseData = await response.json();
                console.log('Response body:');
                console.log(JSON.stringify(responseData, null, 2));
            } catch (e) {
                console.log('Response:', await response.text());
            }
        }
    });

    try {
        await page.goto('http://192.168.1.105/schedule.php', { waitUntil: 'networkidle2' });
        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));
        
        await page.waitForFunction(() => window.PiSignage?.Schedule?.openAddModal, { timeout: 10000 });
        
        console.log('1️⃣ Ouverture modal...\n');
        await page.evaluate(() => window.PiSignage.Schedule.openAddModal());
        await page.evaluate(() => new Promise(r => setTimeout(r, 1500)));

        console.log('2️⃣ Remplissage formulaire...\n');
        
        const playlist = await page.evaluate(() => {
            return document.querySelector('#schedule-playlist option[value]')?.value;
        });

        await page.evaluate((pl) => {
            document.getElementById('schedule-name').value = 'Network Capture Test';
            document.getElementById('schedule-playlist').value = pl;
            document.getElementById('schedule-start-time').value = '08:00';
            document.getElementById('schedule-end-time').value = '09:00';
        }, playlist);

        console.log('3️⃣ Vérification état radio buttons AVANT submit...\n');
        const radioState = await page.evaluate(() => {
            const radios = document.querySelectorAll('input[name="conflict-behavior"]');
            const checked = document.querySelector('input[name="conflict-behavior"]:checked');
            return {
                total: radios.length,
                values: Array.from(radios).map(r => ({ value: r.value, checked: r.checked })),
                checkedValue: checked?.value,
                checkedExists: !!checked
            };
        });

        console.log('   Radio buttons état:', JSON.stringify(radioState, null, 2));

        console.log('\n4️⃣ Click SAUVEGARDER...\n');
        await page.evaluate(() => {
            document.querySelector('.modal-footer button.btn-primary').click();
        });

        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));

        if (!capturedRequest) {
            console.log('\n❌ AUCUNE REQUÊTE CAPTURÉE!');
        }

    } catch (error) {
        console.error('\n❌ Erreur:', error.message);
    } finally {
        await browser.close();
    }
})();
