#!/usr/bin/env node
/**
 * Test Puppeteer pour diagnostiquer les problèmes de playlists.php
 */

const puppeteer = require('puppeteer');

async function testPlaylistsPage() {
    console.log('🚀 Starting Puppeteer test for playlists.php...\n');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture console logs
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        console.log(`[BROWSER ${type.toUpperCase()}] ${text}`);
    });

    // Capture JavaScript errors
    page.on('pageerror', error => {
        console.error(`[PAGE ERROR] ${error.message}`);
    });

    // Capture failed requests
    page.on('requestfailed', request => {
        console.error(`[REQUEST FAILED] ${request.url()} - ${request.failure().errorText}`);
    });

    try {
        console.log('📄 Navigating to http://192.168.1.149/playlists.php...\n');
        await page.goto('http://192.168.1.149/playlists.php', {
            waitUntil: 'networkidle2',
            timeout: 30000
        });

        console.log('✅ Page loaded successfully\n');

        // Wait for scripts to load
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Check if global functions exist
        console.log('🔍 Checking global functions availability...\n');
        const globalFunctions = await page.evaluate(() => {
            return {
                createNewPlaylist: typeof window.createNewPlaylist,
                loadExistingPlaylist: typeof window.loadExistingPlaylist,
                saveCurrentPlaylist: typeof window.saveCurrentPlaylist,
                PiSignage: typeof window.PiSignage,
                PiSignagePlaylists: typeof window.PiSignage?.playlists
            };
        });

        console.log('Global functions check:', JSON.stringify(globalFunctions, null, 2));
        console.log();

        // Check for JavaScript errors in the page
        const hasErrors = await page.evaluate(() => {
            return window.hasOwnProperty('__pageErrors') || false;
        });

        // Check if buttons exist
        console.log('🔍 Checking button elements...\n');
        const buttons = await page.evaluate(() => {
            const newPlaylistBtn = document.querySelector('button[onclick*="createNewPlaylist"]');
            const loadBtn = document.querySelector('button[onclick*="loadExistingPlaylist"]');
            const saveBtn = document.querySelector('button[onclick*="saveCurrentPlaylist"]');

            return {
                newPlaylistBtn: newPlaylistBtn ? 'FOUND' : 'NOT FOUND',
                loadBtn: loadBtn ? 'FOUND' : 'NOT FOUND',
                saveBtn: saveBtn ? 'FOUND' : 'NOT FOUND'
            };
        });

        console.log('Button elements:', JSON.stringify(buttons, null, 2));
        console.log();

        // Try clicking "Nouvelle Playlist" button
        console.log('🖱️  Attempting to click "Nouvelle Playlist" button...\n');
        try {
            await page.click('button[onclick*="createNewPlaylist"]');
            console.log('✅ Button clicked successfully\n');

            // Wait to see if anything happens
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Check if playlist name input appeared or modal opened
            const afterClick = await page.evaluate(() => {
                const nameInput = document.getElementById('playlist-name-input');
                const dropZone = document.getElementById('playlist-drop-zone');
                const playlistItems = document.getElementById('playlist-items');

                return {
                    nameInputExists: !!nameInput,
                    nameInputValue: nameInput ? nameInput.value : null,
                    dropZoneVisible: dropZone ? !dropZone.classList.contains('hidden') : null,
                    playlistItemsCount: playlistItems ? playlistItems.children.length : null
                };
            });

            console.log('After click state:', JSON.stringify(afterClick, null, 2));
            console.log();

        } catch (error) {
            console.error('❌ Failed to click button:', error.message);
        }

        // Check page layout
        console.log('🔍 Checking page layout (width overflow)...\n');
        const layoutInfo = await page.evaluate(() => {
            const body = document.body;
            const playlistEditor = document.querySelector('.playlist-editor-container');

            return {
                bodyScrollWidth: body.scrollWidth,
                bodyClientWidth: body.clientWidth,
                hasHorizontalScroll: body.scrollWidth > body.clientWidth,
                playlistEditorWidth: playlistEditor ? playlistEditor.scrollWidth : null,
                playlistEditorClientWidth: playlistEditor ? playlistEditor.clientWidth : null
            };
        });

        console.log('Layout info:', JSON.stringify(layoutInfo, null, 2));
        console.log();

        if (layoutInfo.hasHorizontalScroll) {
            console.log('⚠️  WARNING: Horizontal scroll detected (width > 100%)\n');
        } else {
            console.log('✅ No horizontal scroll (layout OK)\n');
        }

        // Take screenshot
        console.log('📸 Taking screenshot...\n');
        await page.screenshot({
            path: '/opt/pisignage/test-playlists-screenshot.png',
            fullPage: true
        });
        console.log('✅ Screenshot saved to /opt/pisignage/test-playlists-screenshot.png\n');

    } catch (error) {
        console.error('❌ Test failed:', error.message);
        console.error(error.stack);
    } finally {
        await browser.close();
        console.log('🏁 Test completed\n');
    }
}

testPlaylistsPage().catch(console.error);
