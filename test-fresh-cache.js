#!/usr/bin/env node
/**
 * Test avec cache vidé
 */

const puppeteer = require('puppeteer');

async function testFreshCache() {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Clear cache
    const client = await page.target().createCDPSession();
    await client.send('Network.clearBrowserCache');
    await client.send('Network.clearBrowserCookies');

    console.log('🧹 Cache cleared\n');

    page.on('console', msg => console.log(`[BROWSER] ${msg.text()}`));
    page.on('pageerror', error => console.error(`[ERROR] ${error.message}`));

    try {
        console.log('📄 Loading page with fresh cache...\n');
        await page.goto('http://192.168.1.149/playlists.php', {
            waitUntil: 'networkidle2'
        });

        await new Promise(resolve => setTimeout(resolve, 3000));

        console.log('🔍 Testing button click...\n');

        const beforeClick = await page.evaluate(() => ({
            playlistName: document.getElementById('playlist-name-display')?.textContent,
            itemCount: document.getElementById('item-count')?.textContent
        }));
        console.log('Before click:', beforeClick);

        await page.click('button[onclick*="createNewPlaylist"]');
        console.log('✅ Button clicked');

        await new Promise(resolve => setTimeout(resolve, 500));

        const afterClick = await page.evaluate(() => ({
            playlistName: document.getElementById('playlist-name-display')?.textContent,
            itemCount: document.getElementById('item-count')?.textContent,
            nameInputValue: document.getElementById('playlist-name-input')?.value,
            dropZoneVisible: !document.getElementById('playlist-drop-zone')?.classList.contains('hidden')
        }));
        console.log('After click:', afterClick);

        if (afterClick.playlistName === 'Nouvelle Playlist' && afterClick.dropZoneVisible) {
            console.log('\n✅ SUCCESS: Button works correctly!');
        } else {
            console.log('\n❌ FAILURE: Button did not reset playlist');
        }

    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await browser.close();
    }
}

testFreshCache().catch(console.error);
