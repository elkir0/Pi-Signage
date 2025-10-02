#!/usr/bin/env node
const puppeteer = require('puppeteer');

async function testRebootButton() {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture console logs
    page.on('console', msg => console.log(`[BROWSER] ${msg.text()}`));
    page.on('pageerror', error => console.error(`[ERROR] ${error.message}`));

    // Intercept network requests
    await page.setRequestInterception(true);
    page.on('request', request => {
        if (request.method() === 'POST') {
            console.log('\n📤 POST to:', request.url());
            console.log('Data:', request.postData());
        }
        request.continue();
    });

    page.on('response', async response => {
        if (response.request().method() === 'POST') {
            const status = response.status();
            console.log(`\n📥 Response: ${status}`);
            try {
                const body = await response.text();
                console.log('Body:', body);
            } catch (e) {
                console.log('Could not read body');
            }
        }
    });

    console.log('📄 Loading settings page...\n');
    await page.goto('http://192.168.1.149/settings.php', {
        waitUntil: 'networkidle2'
    });

    await new Promise(resolve => setTimeout(resolve, 2000));

    console.log('🔍 Checking if reboot button exists...\n');
    const buttonExists = await page.evaluate(() => {
        const btn = Array.from(document.querySelectorAll('button')).find(b =>
            b.textContent.includes('Redémarrer') && b.textContent.includes('🔄')
        );
        return {
            exists: !!btn,
            onclick: btn?.getAttribute('onclick'),
            text: btn?.textContent.trim()
        };
    });

    console.log('Button check:', JSON.stringify(buttonExists, null, 2));

    if (buttonExists.exists) {
        console.log('\n🖱️  Clicking reboot button...\n');

        // Handle the confirm dialog
        page.on('dialog', async dialog => {
            console.log('📝 Dialog message:', dialog.message());
            await dialog.accept();
        });

        await page.evaluate(() => {
            const btn = Array.from(document.querySelectorAll('button')).find(b =>
                b.textContent.includes('Redémarrer') && b.textContent.includes('🔄')
            );
            if (btn) btn.click();
        });

        await new Promise(resolve => setTimeout(resolve, 3000));
    }

    await browser.close();
}

testRebootButton().catch(console.error);
