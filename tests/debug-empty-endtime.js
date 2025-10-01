const puppeteer = require('puppeteer');

(async () => {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture network requests
    page.on('request', request => {
        if (request.url().includes('/api/schedule.php') && request.method() === 'POST') {
            console.log('📤 POST to schedule API:');
            console.log(request.postData());
        }
    });

    try {
        await page.goto('http://192.168.1.105/schedule.php', { waitUntil: 'networkidle2' });
        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));
        await page.waitForFunction(() => window.PiSignage?.Schedule?.openAddModal, { timeout: 10000 });

        await page.evaluate(() => window.PiSignage.Schedule.openAddModal());
        await page.evaluate(() => new Promise(r => setTimeout(r, 1000)));

        console.log('\nFilling form with EMPTY end_time...');
        await page.evaluate(() => {
            document.getElementById('schedule-name').value = 'Test Empty End';
            document.getElementById('schedule-playlist').value = document.querySelector('#schedule-playlist option[value]').value;
            document.getElementById('schedule-start-time').value = '10:00';
            document.getElementById('schedule-end-time').value = '';
        });

        const formValues = await page.evaluate(() => {
            return {
                name: document.getElementById('schedule-name').value,
                start: document.getElementById('schedule-start-time').value,
                end: document.getElementById('schedule-end-time').value,
                endIsEmpty: document.getElementById('schedule-end-time').value === ''
            };
        });

        console.log('Form values:', formValues);

        console.log('\nClicking save...');
        await page.evaluate(() => {
            document.querySelector('.modal-footer button.btn-primary').click();
        });

        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));

        console.log('\nCheck what was created in API...');
        const schedules = await page.evaluate(() => fetch('/api/schedule.php').then(r => r.json()));

        if (schedules.data && schedules.data.length > 0) {
            const last = schedules.data[schedules.data.length - 1];
            console.log('\nLast schedule created:');
            console.log('  Name:', last.name);
            console.log('  Start:', last.schedule.start_time);
            console.log('  End:', last.schedule.end_time);
            console.log('  End is undefined:', last.schedule.end_time === undefined);
            console.log('  End is null:', last.schedule.end_time === null);
            console.log('  End is empty string:', last.schedule.end_time === '');
        }

    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await browser.close();
    }
})();
