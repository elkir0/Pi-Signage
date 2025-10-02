#!/usr/bin/env node
const puppeteer = require('puppeteer');

async function testScheduleButton() {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    page.on('console', msg => console.log(`[BROWSER] ${msg.text()}`));
    page.on('pageerror', error => console.error(`[PAGE ERROR] ${error.message}`));

    console.log('📄 Loading schedule.php...\n');
    await page.goto('http://192.168.1.149/schedule.php', {
        waitUntil: 'networkidle2',
        timeout: 30000
    });

    await new Promise(resolve => setTimeout(resolve, 3000));

    console.log('🔍 Checking PiSignage.Schedule availability...\n');
    const scheduleCheck = await page.evaluate(() => {
        return {
            PiSignage: typeof window.PiSignage,
            Schedule: typeof window.PiSignage?.Schedule,
            openAddModal: typeof window.PiSignage?.Schedule?.openAddModal,
            scheduleInitialized: window.PiSignage?.Schedule?._initialized || false
        };
    });

    console.log('Schedule check:', JSON.stringify(scheduleCheck, null, 2));

    console.log('\n🔍 Checking button...\n');
    const buttonCheck = await page.evaluate(() => {
        const btn = document.querySelector('button[onclick*="openAddModal"]');
        if (!btn) return { found: false };

        return {
            found: true,
            onclick: btn.getAttribute('onclick'),
            text: btn.textContent.trim(),
            disabled: btn.disabled
        };
    });

    console.log('Button check:', JSON.stringify(buttonCheck, null, 2));

    if (scheduleCheck.openAddModal === 'function') {
        console.log('\n🖱️  Attempting to call openAddModal()...\n');
        const result = await page.evaluate(() => {
            try {
                window.PiSignage.Schedule.openAddModal();
                return { success: true, error: null };
            } catch (error) {
                return { success: false, error: error.message };
            }
        });

        console.log('Call result:', JSON.stringify(result, null, 2));

        if (result.success) {
            await new Promise(resolve => setTimeout(resolve, 1000));

            const modalCheck = await page.evaluate(() => {
                const modal = document.getElementById('schedule-modal');
                return {
                    modalExists: !!modal,
                    modalVisible: modal ? !modal.classList.contains('hidden') : false,
                    modalDisplay: modal ? window.getComputedStyle(modal).display : null
                };
            });

            console.log('\nModal state:', JSON.stringify(modalCheck, null, 2));
        }
    } else {
        console.log('\n❌ openAddModal function not available');
    }

    await page.screenshot({ path: '/opt/pisignage/test-schedule-page.png', fullPage: true });
    console.log('\n📸 Screenshot saved');

    await browser.close();
}

testScheduleButton().catch(console.error);
