const puppeteer = require('puppeteer');

(async () => {
    console.log('🔍 TEST: Pourquoi la validation échoue\n');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    const alerts = [];
    page.on('console', msg => {
        const text = msg.text();
        if (text.includes('Alert') || text.includes('error')) {
            alerts.push(text);
            console.log('  📢', text);
        }
    });

    try {
        await page.goto('http://192.168.1.105/schedule.php', { waitUntil: 'networkidle2' });
        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));
        await page.waitForFunction(() => window.PiSignage?.Schedule?.openAddModal, { timeout: 10000 });

        await page.evaluate(() => window.PiSignage.Schedule.openAddModal());
        await page.evaluate(() => new Promise(r => setTimeout(r, 1500)));

        const playlist = await page.evaluate(() => {
            return document.querySelector('#schedule-playlist option[value]')?.value;
        });

        await page.evaluate((pl) => {
            document.getElementById('schedule-name').value = 'Test Validation';
            document.getElementById('schedule-playlist').value = pl;
            document.getElementById('schedule-start-time').value = '08:00';
            document.getElementById('schedule-end-time').value = '09:00';
        }, playlist);

        console.log('Valeurs formulaire remplies\n');

        // Appeler getFormData et validateFormData manuellement
        const validationResult = await page.evaluate(() => {
            const schedule = window.PiSignage.Schedule;
            const formData = schedule.getFormData();
            
            console.log('[DEBUG] Form data:', JSON.stringify(formData, null, 2));
            
            const isValid = schedule.validateFormData(formData);
            
            return {
                formData: formData,
                isValid: isValid
            };
        });

        console.log('📊 RÉSULTAT VALIDATION:');
        console.log('   Valid:', validationResult.isValid);
        console.log('\n📦 FORM DATA:');
        console.log(JSON.stringify(validationResult.formData, null, 2));

        if (!validationResult.isValid) {
            console.log('\n❌ VALIDATION ÉCHOUÉE');
            console.log('Alertes capturées:');
            alerts.forEach(a => console.log('  -', a));
        }

        console.log('\nMaintenant click sur sauvegarder...');
        await page.evaluate(() => {
            document.querySelector('.modal-footer button.btn-primary').click();
        });

        await page.evaluate(() => new Promise(r => setTimeout(r, 2000)));

        console.log('\nAlertes finales capturées:');
        alerts.forEach(a => console.log('  -', a));

    } catch (error) {
        console.error('❌ Erreur:', error.message);
    } finally {
        await browser.close();
    }
})();
