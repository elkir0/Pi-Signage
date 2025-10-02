#!/usr/bin/env node
const puppeteer = require('puppeteer');

async function testScheduleSave() {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture console and errors
    page.on('console', msg => console.log(`[BROWSER] ${msg.text()}`));
    page.on('pageerror', error => console.error(`[ERROR] ${error.message}`));

    // Intercept POST requests to see what data is sent
    let lastPostData = null;
    await page.setRequestInterception(true);
    page.on('request', request => {
        if (request.method() === 'POST' && request.url().includes('schedule.php')) {
            lastPostData = request.postData();
            console.log('\n📤 POST DATA SENT:');
            console.log(lastPostData);
            console.log('\n');
        }
        request.continue();
    });

    // Capture response
    page.on('response', async response => {
        if (response.url().includes('schedule.php') && response.request().method() === 'POST') {
            const status = response.status();
            console.log(`\n📥 RESPONSE STATUS: ${status}`);
            try {
                const body = await response.text();
                console.log('📥 RESPONSE BODY:');
                console.log(body);
            } catch (e) {
                console.log('Could not read response body');
            }
        }
    });

    console.log('📄 Loading schedule page...\n');
    await page.goto('http://192.168.1.149/schedule.php', {
        waitUntil: 'networkidle2'
    });

    await new Promise(resolve => setTimeout(resolve, 3000));

    console.log('🖱️  Opening modal...\n');
    await page.evaluate(() => {
        window.PiSignage.Schedule.openAddModal();
    });

    await new Promise(resolve => setTimeout(resolve, 1000));

    console.log('✏️  Filling form...\n');

    // Fill schedule name
    await page.type('#schedule-name', 'Test Planning');

    // Check if playlists are available
    const playlistOptions = await page.evaluate(() => {
        const select = document.getElementById('schedule-playlist');
        if (!select) return null;

        const options = Array.from(select.options).map(opt => ({
            value: opt.value,
            text: opt.text
        }));
        return options;
    });

    console.log('Available playlists:', JSON.stringify(playlistOptions, null, 2));

    if (playlistOptions && playlistOptions.length > 1) {
        // Select first playlist (skip the empty option)
        await page.select('#schedule-playlist', playlistOptions[1].value);
    } else {
        console.log('⚠️  No playlists available!');
    }

    // Fill times
    await page.type('#schedule-start-time', '09:00');
    await page.type('#schedule-end-time', '17:00');

    // Select days (Monday and Tuesday)
    await page.evaluate(() => {
        const monday = document.querySelector('input[type="checkbox"][value="1"]');
        const tuesday = document.querySelector('input[type="checkbox"][value="2"]');
        if (monday) monday.checked = true;
        if (tuesday) tuesday.checked = true;
    });

    await new Promise(resolve => setTimeout(resolve, 500));

    console.log('\n💾 Attempting to save...\n');

    // Click save button
    await page.click('#save-schedule-btn');

    await new Promise(resolve => setTimeout(resolve, 2000));

    // Check final state
    const finalState = await page.evaluate(() => ({
        modalVisible: document.getElementById('schedule-modal')?.style.display !== 'none',
        alertText: document.querySelector('.alert')?.textContent
    }));

    console.log('\n📊 Final state:', JSON.stringify(finalState, null, 2));

    await browser.close();
}

testScheduleSave().catch(console.error);
