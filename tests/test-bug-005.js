const puppeteer = require('puppeteer');

(async () => {
    console.log('🧪 Testing BUG-005: Empty end_time handling\n');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    
    try {
        console.log('1️⃣ Loading scheduler and creating first schedule (10:00-11:00)...');
        await page.goto('http://192.168.1.105/schedule.php', {
            waitUntil: 'networkidle2',
            timeout: 30000
        });

        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));

        // Wait for module
        await page.waitForFunction(() => window.PiSignage?.Schedule?.openAddModal, { timeout: 10000 });

        // Create first schedule
        await page.evaluate(() => window.PiSignage.Schedule.openAddModal());
        await page.evaluate(() => new Promise(r => setTimeout(r, 1000)));

        await page.evaluate(() => {
            document.getElementById('schedule-name').value = 'Schedule A (10:00-11:00)';
            document.getElementById('schedule-playlist').value = document.querySelector('#schedule-playlist option[value]').value;
            document.getElementById('schedule-start-time').value = '10:00';
            document.getElementById('schedule-end-time').value = '11:00';
        });

        await page.evaluate(() => {
            document.querySelector('.modal-footer button.btn-primary').click();
        });

        await page.evaluate(() => new Promise(r => setTimeout(r, 2000)));
        console.log('✅ Schedule A created\n');

        console.log('2️⃣ Creating second schedule (10:30-empty) - SHOULD conflict...');
        await page.evaluate(() => window.PiSignage.Schedule.openAddModal());
        await page.evaluate(() => new Promise(r => setTimeout(r, 1000)));

        await page.evaluate(() => {
            document.getElementById('schedule-name').value = 'Schedule B (10:30-empty)';
            document.getElementById('schedule-playlist').value = document.querySelector('#schedule-playlist option[value]').value;
            document.getElementById('schedule-start-time').value = '10:30';
            document.getElementById('schedule-end-time').value = ''; // EMPTY!
        });

        await page.evaluate(() => {
            document.querySelector('.modal-footer button.btn-primary').click();
        });

        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));

        const conflictShown = await page.evaluate(() => {
            const modal = document.getElementById('conflict-modal');
            return modal?.classList.contains('show');
        });

        if (conflictShown) {
            console.log('✅✅✅ SUCCESS: Conflict detected with empty end_time!');
            console.log('   BUG-005 is FIXED\n');

            const message = await page.evaluate(() => {
                return document.getElementById('conflict-message')?.textContent;
            });
            console.log('   Conflict message:', message);
        } else {
            console.log('❌❌❌ FAILURE: No conflict detected');
            console.log('   BUG-005 still present\n');
        }

        // Cleanup
        console.log('\n3️⃣ Cleaning up test schedules...');
        await page.evaluate(() => {
            if (document.getElementById('conflict-modal')?.classList.contains('show')) {
                document.getElementById('conflict-modal').classList.remove('show');
            }
            if (document.getElementById('schedule-modal')?.classList.contains('show')) {
                document.getElementById('schedule-modal').classList.remove('show');
            }
        });

        const schedules = await page.evaluate(() => 
            fetch('/api/schedule.php').then(r => r.json())
        );

        for (const schedule of schedules.data) {
            await page.evaluate((id) => 
                fetch(`/api/schedule.php?id=${id}`, { method: 'DELETE' })
            , schedule.id);
        }

        console.log('✅ Test schedules removed');

    } catch (error) {
        console.error('❌ Test error:', error.message);
    } finally {
        await browser.close();
    }
})();
