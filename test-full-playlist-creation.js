#!/usr/bin/env node
const puppeteer = require('puppeteer');

async function testFullPlaylistCreation() {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });

    page.on('console', msg => console.log(`[BROWSER] ${msg.text()}`));
    page.on('pageerror', error => console.error(`[ERROR] ${error.message}`));

    console.log('📄 Loading playlists page...\n');
    await page.goto('http://192.168.1.149/playlists.php', {
        waitUntil: 'networkidle2'
    });

    await new Promise(resolve => setTimeout(resolve, 3000));

    console.log('🖱️  Step 1: Click "Nouvelle Playlist" button...\n');
    await page.click('button[onclick*="createNewPlaylist"]');
    await new Promise(resolve => setTimeout(resolve, 500));

    console.log('✏️  Step 2: Enter playlist name...\n');
    const nameInput = await page.$('#playlist-name-input');
    if (nameInput) {
        console.log('   ✅ Name input found');
        const isVisible = await page.evaluate(el => {
            const style = window.getComputedStyle(el);
            return {
                display: style.display,
                visibility: style.visibility,
                opacity: style.opacity,
                disabled: el.disabled,
                readOnly: el.readOnly
            };
        }, nameInput);
        console.log('   Input state:', JSON.stringify(isVisible, null, 2));

        await nameInput.click();
        await nameInput.type('Ma Première Playlist', { delay: 50 });

        const typedValue = await page.evaluate(() =>
            document.getElementById('playlist-name-input').value
        );
        console.log('   Typed value:', typedValue);
    } else {
        console.log('   ❌ Name input NOT found');
    }

    console.log('\n📋 Step 3: Check playlist workspace...\n');
    const workspaceInfo = await page.evaluate(() => {
        const dropZone = document.getElementById('playlist-drop-zone');
        const playlistItems = document.getElementById('playlist-items');
        const mediaLibrary = document.getElementById('media-library-list');

        return {
            dropZoneExists: !!dropZone,
            dropZoneHidden: dropZone?.classList.contains('hidden'),
            playlistItemsExists: !!playlistItems,
            itemCount: playlistItems?.children.length || 0,
            mediaLibraryExists: !!mediaLibrary,
            mediaCount: mediaLibrary?.children.length || 0
        };
    });
    console.log('   Workspace:', JSON.stringify(workspaceInfo, null, 2));

    console.log('\n📁 Step 4: Try to add media to playlist...\n');
    const mediaAdded = await page.evaluate(() => {
        const firstMedia = document.querySelector('.media-item');
        if (!firstMedia) return { success: false, reason: 'No media items found' };

        const fileName = firstMedia.dataset.file;
        if (!fileName) return { success: false, reason: 'No filename in media item' };

        // Try to add via button
        const addBtn = firstMedia.querySelector('.btn-add');
        if (addBtn) {
            addBtn.click();
            return { success: true, method: 'button', file: fileName };
        }

        // Try to add via global function
        if (typeof window.PiSignage?.playlists?.addMediaToPlaylist === 'function') {
            window.PiSignage.playlists.addMediaToPlaylist(fileName);
            return { success: true, method: 'function', file: fileName };
        }

        return { success: false, reason: 'No add method available' };
    });
    console.log('   Add media result:', JSON.stringify(mediaAdded, null, 2));

    await new Promise(resolve => setTimeout(resolve, 1000));

    console.log('\n💾 Step 5: Check save button state...\n');
    const saveButtonInfo = await page.evaluate(() => {
        const saveBtn = document.getElementById('save-playlist-btn');
        if (!saveBtn) return { found: false };

        return {
            found: true,
            disabled: saveBtn.disabled,
            textContent: saveBtn.textContent.trim(),
            onclick: saveBtn.getAttribute('onclick'),
            computedStyle: {
                display: window.getComputedStyle(saveBtn).display,
                opacity: window.getComputedStyle(saveBtn).opacity
            }
        };
    });
    console.log('   Save button:', JSON.stringify(saveButtonInfo, null, 2));

    console.log('\n📊 Final state check...\n');
    const finalState = await page.evaluate(() => ({
        playlistName: document.getElementById('playlist-name-input')?.value,
        playlistDisplay: document.getElementById('playlist-name-display')?.textContent,
        itemCount: document.getElementById('item-count')?.textContent,
        currentPlaylistItems: window.PiSignage?.playlists?.currentPlaylist?.items?.length || 0
    }));
    console.log('   Final state:', JSON.stringify(finalState, null, 2));

    // Take screenshot
    await page.screenshot({
        path: '/opt/pisignage/test-playlist-workflow.png',
        fullPage: true
    });
    console.log('\n📸 Screenshot saved: test-playlist-workflow.png');

    await browser.close();
}

testFullPlaylistCreation().catch(console.error);
