#!/usr/bin/env node
/**
 * Debug détaillé du click sur "Nouvelle Playlist"
 */

const puppeteer = require('puppeteer');

async function debugPlaylistClick() {
    console.log('🔍 Debugging playlist button click...\n');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture ALL console messages
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        console.log(`[BROWSER ${type}] ${text}`);
    });

    // Capture errors
    page.on('pageerror', error => {
        console.error(`[PAGE ERROR] ${error.message}`);
        console.error(error.stack);
    });

    page.on('requestfailed', request => {
        console.error(`[FAILED] ${request.url()}`);
    });

    try {
        console.log('📄 Loading page...\n');
        await page.goto('http://192.168.1.149/playlists.php', {
            waitUntil: 'networkidle2',
            timeout: 30000
        });

        // Wait for initialization
        await new Promise(resolve => setTimeout(resolve, 3000));

        console.log('\n🔍 Checking window object...\n');
        const windowCheck = await page.evaluate(() => {
            const result = {
                createNewPlaylist: typeof window.createNewPlaylist,
                PiSignage: typeof window.PiSignage,
                PiSignagePlaylists: typeof window.PiSignage?.playlists,
                resetPlaylistEditor: typeof window.PiSignage?.playlists?.resetPlaylistEditor
            };

            console.log('Window check:', JSON.stringify(result, null, 2));

            return result;
        });

        console.log('Window check result:', JSON.stringify(windowCheck, null, 2));

        console.log('\n🔍 Checking button...\n');
        const buttonInfo = await page.evaluate(() => {
            const btn = document.querySelector('button[onclick*="createNewPlaylist"]');
            if (!btn) return { found: false };

            return {
                found: true,
                onclick: btn.getAttribute('onclick'),
                textContent: btn.textContent.trim(),
                disabled: btn.disabled,
                style: btn.style.cssText,
                computedDisplay: window.getComputedStyle(btn).display
            };
        });

        console.log('Button info:', JSON.stringify(buttonInfo, null, 2));

        console.log('\n🖱️  Attempting manual function call...\n');
        const manualCallResult = await page.evaluate(() => {
            try {
                console.log('Calling window.createNewPlaylist()...');
                if (typeof window.createNewPlaylist === 'function') {
                    window.createNewPlaylist();
                    console.log('Function called successfully');
                    return { success: true, error: null };
                } else {
                    return { success: false, error: 'Function not found' };
                }
            } catch (error) {
                console.error('Error calling function:', error);
                return { success: false, error: error.message };
            }
        });

        console.log('Manual call result:', JSON.stringify(manualCallResult, null, 2));

        // Wait a bit
        await new Promise(resolve => setTimeout(resolve, 1000));

        console.log('\n🔍 Checking editor state after manual call...\n');
        const editorState = await page.evaluate(() => {
            const nameInput = document.getElementById('playlist-name-input');
            const dropZone = document.getElementById('playlist-drop-zone');
            const playlistItems = document.getElementById('playlist-items');
            const nameDisplay = document.getElementById('playlist-name-display');

            return {
                nameInputValue: nameInput?.value,
                nameDisplayText: nameDisplay?.textContent,
                dropZoneHidden: dropZone?.classList.contains('hidden'),
                playlistItemsHTML: playlistItems?.innerHTML.substring(0, 200),
                PiSignageCurrentPlaylist: window.PiSignage?.playlists?.currentPlaylist
            };
        });

        console.log('Editor state:', JSON.stringify(editorState, null, 2));

        console.log('\n🖱️  Now trying actual button click...\n');
        try {
            await page.click('button[onclick*="createNewPlaylist"]');
            console.log('Button clicked!\n');

            await new Promise(resolve => setTimeout(resolve, 1000));

            const afterClickState = await page.evaluate(() => {
                return {
                    nameInput: document.getElementById('playlist-name-input')?.value,
                    nameDisplay: document.getElementById('playlist-name-display')?.textContent
                };
            });

            console.log('After click state:', JSON.stringify(afterClickState, null, 2));

        } catch (error) {
            console.error('Click failed:', error.message);
        }

        // Take screenshot
        await page.screenshot({
            path: '/opt/pisignage/debug-click-screenshot.png',
            fullPage: true
        });
        console.log('\n📸 Screenshot saved to debug-click-screenshot.png');

    } catch (error) {
        console.error('❌ Error:', error.message);
        console.error(error.stack);
    } finally {
        await browser.close();
    }
}

debugPlaylistClick().catch(console.error);
