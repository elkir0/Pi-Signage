const puppeteer = require('puppeteer');

(async () => {
    console.log('🧪 BUG-005 Test v2: Empty end_time conflict detection\n');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    
    page.on('console', msg => {
        const text = msg.text();
        if (text.includes('Alert') || text.includes('error') || text.includes('Error')) {
            console.log('  📋', text);
        }
    });

    try {
        await page.goto('http://192.168.1.105/schedule.php', { waitUntil: 'networkidle2' });
        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));
        await page.waitForFunction(() => window.PiSignage?.Schedule?.openAddModal, { timeout: 10000 });

        // Create Schedule A: 10:00-11:00
        console.log('1️⃣ Creating Schedule A (10:00-11:00)...');
        await page.evaluate(() => {
            window.PiSignage.Schedule.openAddModal();
        });
        await page.evaluate(() => new Promise(r => setTimeout(r, 1000)));

        await page.evaluate(() => {
            const playlist = document.querySelector('#schedule-playlist option[value]').value;
            document.getElementById('schedule-name').value = 'Schedule A';
            document.getElementById('schedule-playlist').value = playlist;
            document.getElementById('schedule-start-time').value = '10:00';
            document.getElementById('schedule-end-time').value = '11:00';
        });

        await page.evaluate(() => document.querySelector('.modal-footer button.btn-primary').click());
        await page.evaluate(() => new Promise(r => setTimeout(r, 2000)));

        const schedA = await page.evaluate(() => fetch('/api/schedule.php').then(r => r.json()));
        console.log(`✅ Created ${schedA.count} schedule(s)\n`);

        // Create Schedule B: 10:30-(empty, should default to 23:59)
        console.log('2️⃣ Creating Schedule B (10:30-empty, should conflict)...');
        await page.evaluate(() => {
            window.PiSignage.Schedule.openAddModal();
        });
        await page.evaluate(() => new Promise(r => setTimeout(r, 1000)));

        await page.evaluate(() => {
            const playlist = document.querySelector('#schedule-playlist option[value]').value;
            document.getElementById('schedule-name').value = 'Schedule B Empty End';
            document.getElementById('schedule-playlist').value = playlist;
            document.getElementById('schedule-start-time').value = '10:30';
            // Leave end_time empty
            const endField = document.getElementById('schedule-end-time');
            endField.value = '';
        });

        // Check what will be sent
        const dataToSend = await page.evaluate(() => {
            const endVal = document.getElementById('schedule-end-time').value;
            return {
                end_value: endVal,
                end_or_undefined: endVal || undefined,
                is_empty: endVal === ''
            };
        });
        console.log('   Data check:', dataToSend);

        await page.evaluate(() => document.querySelector('.modal-footer button.btn-primary').click());
        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));

        const conflictShown = await page.evaluate(() => {
            return document.getElementById('conflict-modal')?.classList.contains('show');
        });

        console.log(`\n${conflictShown ? '✅✅✅ SUCCESS' : '❌❌❌ FAILURE'}: Conflict ${conflictShown ? 'WAS' : 'NOT'} detected`);

        if (conflictShown) {
            const msg = await page.evaluate(() => document.getElementById('conflict-message')?.textContent);
            console.log('   Message:', msg);
        }

        // Clean up
        const finalSchedules = await page.evaluate(() => fetch('/api/schedule.php').then(r => r.json()));
        for (const s of finalSchedules.data || []) {
            await page.evaluate((id) => fetch(`/api/schedule.php?id=${id}`, { method: 'DELETE' }), s.id);
        }

    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        await browser.close();
    }
})();
