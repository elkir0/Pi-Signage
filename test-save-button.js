#!/usr/bin/env node
const puppeteer = require('puppeteer');

async function testSaveButton() {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    page.on('console', msg => console.log(`[BROWSER] ${msg.text()}`));

    await page.goto('http://192.168.1.149/playlists.php', { waitUntil: 'networkidle2' });
    await new Promise(resolve => setTimeout(resolve, 3000));

    console.log('\n1️⃣ Click "Nouvelle Playlist"...');
    await page.click('button[onclick*="createNewPlaylist"]');
    await new Promise(resolve => setTimeout(resolve, 500));

    console.log('\n2️⃣ Type playlist name...');
    const nameInput = await page.$('#playlist-name-input');
    await nameInput.click();
    await nameInput.type('Test Playlist', { delay: 50 });

    // Trigger blur to ensure onchange fires
    await page.evaluate(() => {
        const input = document.getElementById('playlist-name-input');
        input.blur();
        // Also manually call the function
        if (typeof window.updatePlaylistName === 'function') {
            window.updatePlaylistName();
        }
    });

    await new Promise(resolve => setTimeout(resolve, 500));

    console.log('\n3️⃣ Add media file...');
    await page.evaluate(() => {
        const addBtn = document.querySelector('.btn-add');
        if (addBtn) addBtn.click();
    });

    await new Promise(resolve => setTimeout(resolve, 1000));

    console.log('\n4️⃣ Check save button state...');
    const state = await page.evaluate(() => ({
        playlistName: window.PiSignage?.playlists?.currentPlaylist?.name,
        itemCount: window.PiSignage?.playlists?.currentPlaylist?.items?.length,
        modified: window.PiSignage?.playlists?.playlistModified,
        saveButtonDisabled: document.getElementById('save-playlist-btn')?.disabled
    }));

    console.log('\nPlaylist state:', JSON.stringify(state, null, 2));

    if (!state.saveButtonDisabled) {
        console.log('\n✅ SUCCESS! Save button is enabled, attempting to save...');

        await page.click('#save-playlist-btn');
        await new Promise(resolve => setTimeout(resolve, 2000));

        const saved = await page.evaluate(() => ({
            alertShown: document.querySelector('.alert') !== null
        }));

        console.log('Save result:', saved);
    } else {
        console.log('\n❌ Save button still disabled');
        console.log('Reasons:');
        console.log('  - Has name:', !!state.playlistName);
        console.log('  - Has items:', state.itemCount > 0);
        console.log('  - Is modified:', state.modified);
    }

    await browser.close();
}

testSaveButton().catch(console.error);
