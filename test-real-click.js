#!/usr/bin/env node
const puppeteer = require('puppeteer');

async function testRealClick() {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });

    page.on('console', msg => console.log(`[BROWSER] ${msg.text()}`));
    page.on('pageerror', error => console.error(`[ERROR] ${error.message}`));

    console.log('📄 Loading page...\n');
    await page.goto('http://192.168.1.149/playlists.php', {
        waitUntil: 'networkidle2'
    });

    await new Promise(resolve => setTimeout(resolve, 3000));

    // Check if function exists
    const funcCheck = await page.evaluate(() => {
        return {
            createNewPlaylist: typeof window.createNewPlaylist,
            canCallIt: typeof window.createNewPlaylist === 'function'
        };
    });
    console.log('Function check:', funcCheck);

    // Find the button
    const buttonExists = await page.$('button[onclick*="createNewPlaylist"]');
    console.log('Button exists:', !!buttonExists);

    if (buttonExists) {
        // Get button position
        const box = await buttonExists.boundingBox();
        console.log('Button position:', box);

        // Highlight the button (for debugging)
        await page.evaluate(() => {
            const btn = document.querySelector('button[onclick*="createNewPlaylist"]');
            if (btn) {
                btn.style.border = '3px solid red';
                btn.style.backgroundColor = 'yellow';
            }
        });

        console.log('\n🖱️  Clicking button with real mouse movement...\n');

        // Move to button and click
        await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
        await new Promise(resolve => setTimeout(resolve, 500));
        await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);

        console.log('✅ Button clicked\n');

        await new Promise(resolve => setTimeout(resolve, 2000));

        // Check state after click
        const afterState = await page.evaluate(() => {
            return {
                nameInput: document.getElementById('playlist-name-input')?.value,
                nameDisplay: document.getElementById('playlist-name-display')?.textContent,
                dropZoneHidden: document.getElementById('playlist-drop-zone')?.classList.contains('hidden'),
                itemCount: document.getElementById('item-count')?.textContent
            };
        });

        console.log('After click state:', afterState);

        // Take screenshot
        await page.screenshot({ path: '/opt/pisignage/real-click-test.png', fullPage: true });
        console.log('\n📸 Screenshot saved');

        // Keep browser open for 10 seconds
        console.log('\n⏰ Keeping browser open for 10 seconds...');
        await new Promise(resolve => setTimeout(resolve, 10000));
    }

    await browser.close();
}

testRealClick().catch(console.error);
