#!/usr/bin/env node
const puppeteer = require('puppeteer');

async function testButtonBlocking() {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });

    await page.goto('http://192.168.1.149/playlists.php', {
        waitUntil: 'networkidle2'
    });

    await new Promise(resolve => setTimeout(resolve, 3000));

    // Check what element is actually at the button's position
    const info = await page.evaluate(() => {
        const btn = document.querySelector('button[onclick*="createNewPlaylist"]');
        if (!btn) return { error: 'Button not found' };

        const rect = btn.getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        const centerY = rect.top + rect.height / 2;

        // Get element at button center
        const elementAtPoint = document.elementFromPoint(centerX, centerY);

        return {
            buttonRect: {
                top: rect.top,
                left: rect.left,
                width: rect.width,
                height: rect.height
            },
            buttonZIndex: window.getComputedStyle(btn).zIndex,
            buttonPointerEvents: window.getComputedStyle(btn).pointerEvents,
            buttonDisplay: window.getComputedStyle(btn).display,
            buttonVisibility: window.getComputedStyle(btn).visibility,
            elementAtCenter: {
                tag: elementAtPoint?.tagName,
                class: elementAtPoint?.className,
                id: elementAtPoint?.id,
                onclick: elementAtPoint?.getAttribute('onclick'),
                isButton: elementAtPoint === btn
            },
            parentZIndex: window.getComputedStyle(btn.parentElement).zIndex,
            parentPointerEvents: window.getComputedStyle(btn.parentElement).pointerEvents
        };
    });

    console.log('Button blocking analysis:');
    console.log(JSON.stringify(info, null, 2));

    await browser.close();
}

testButtonBlocking().catch(console.error);
