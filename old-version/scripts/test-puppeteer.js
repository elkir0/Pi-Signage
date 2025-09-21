/**
 * PiSignage - Test automatisé avec Puppeteer
 * Version: 1.0.0
 * Date: 2025-09-19
 * 
 * Suite de tests automatisés pour valider toutes les fonctionnalités
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// Configuration
const config = {
    baseUrl: 'http://192.168.1.103',
    screenshotDir: '/opt/pisignage/tests/screenshots',
    reportFile: '/opt/pisignage/tests/test-report.json',
    viewport: { width: 1920, height: 1080 },
    headless: true,
    timeout: 30000
};

// Créer le dossier de screenshots si nécessaire
if (!fs.existsSync(config.screenshotDir)) {
    fs.mkdirSync(config.screenshotDir, { recursive: true });
}

// Test results
const testResults = {
    timestamp: new Date().toISOString(),
    passed: 0,
    failed: 0,
    tests: []
};

// Helper functions
async function takeScreenshot(page, name) {
    const filename = `${name}-${Date.now()}.png`;
    const filepath = path.join(config.screenshotDir, filename);
    await page.screenshot({ path: filepath, fullPage: true });
    console.log(`📸 Screenshot saved: ${filename}`);
    return filepath;
}

async function logConsoleErrors(page) {
    const errors = [];
    page.on('console', msg => {
        if (msg.type() === 'error') {
            errors.push({
                text: msg.text(),
                location: msg.location()
            });
        }
    });
    page.on('pageerror', error => {
        errors.push({
            message: error.message,
            stack: error.stack
        });
    });
    return errors;
}

async function testPage(page, testName, testFn) {
    console.log(`\n🧪 Testing: ${testName}`);
    const test = {
        name: testName,
        status: 'running',
        startTime: Date.now(),
        errors: []
    };

    try {
        const errors = await logConsoleErrors(page);
        await testFn(page);
        
        test.status = errors.length > 0 ? 'warning' : 'passed';
        test.errors = errors;
        test.duration = Date.now() - test.startTime;
        
        if (test.status === 'passed') {
            testResults.passed++;
            console.log(`✅ ${testName} - PASSED (${test.duration}ms)`);
        } else {
            console.log(`⚠️ ${testName} - PASSED WITH WARNINGS (${test.duration}ms)`);
            console.log(`   Console errors detected: ${errors.length}`);
        }
    } catch (error) {
        test.status = 'failed';
        test.error = error.message;
        test.duration = Date.now() - test.startTime;
        test.screenshot = await takeScreenshot(page, `${testName}-error`);
        testResults.failed++;
        console.error(`❌ ${testName} - FAILED: ${error.message}`);
    }

    testResults.tests.push(test);
    return test;
}

// Main test suite
async function runTests() {
    console.log('🚀 Starting PiSignage Test Suite\n');
    console.log(`📍 Target: ${config.baseUrl}`);
    console.log(`📁 Screenshots: ${config.screenshotDir}\n`);

    const browser = await puppeteer.launch({
        headless: config.headless,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu'
        ]
    });

    const page = await browser.newPage();
    await page.setViewport(config.viewport);

    try {
        // Test 1: Page loads successfully
        await testPage(page, 'Page Load', async (p) => {
            const response = await p.goto(config.baseUrl, { waitUntil: 'networkidle2' });
            if (response.status() !== 200) {
                throw new Error(`Page returned status ${response.status()}`);
            }
            await takeScreenshot(p, 'homepage');
        });

        // Test 2: Dashboard tab functionality
        await testPage(page, 'Dashboard Tab', async (p) => {
            // Dashboard should already be active by default
            const dashboardTab = await p.$('#dashboard-tab.active');
            if (!dashboardTab) {
                // Click on dashboard tab if not active
                await p.evaluate(() => {
                    if (typeof switchTab === 'function') {
                        switchTab('dashboard');
                    }
                });
                await p.waitForTimeout(1000);
            }
            
            // Check if stats are loaded
            const cpuTemp = await p.$eval('#cpu-temp', el => el.textContent);
            if (!cpuTemp) throw new Error('CPU temperature not loaded');
            
            // Check if screenshot button exists
            const screenshotBtn = await p.$('#dashboard-tab button');
            if (!screenshotBtn) throw new Error('Screenshot button not found');
            
            await takeScreenshot(p, 'dashboard-tab');
        });

        // Test 3: Media tab functionality
        await testPage(page, 'Media Tab', async (p) => {
            await p.evaluate(() => {
                if (typeof switchTab === 'function') {
                    switchTab('media');
                }
            });
            await p.waitForTimeout(1000);
            
            // Check if media list is loaded
            const mediaCount = await p.$eval('#media-count', el => el.textContent);
            console.log(`   Media files found: ${mediaCount}`);
            
            await takeScreenshot(p, 'media-tab');
        });

        // Test 4: Playlists tab and API
        await testPage(page, 'Playlists Tab', async (p) => {
            await p.evaluate(() => {
                if (typeof switchTab === 'function') {
                    switchTab('playlists');
                }
            });
            await p.waitForTimeout(1000);
            
            // Check if playlist API responds
            const playlistResponse = await p.evaluate(async () => {
                try {
                    const response = await fetch('/api/playlist.php?action=list');
                    return {
                        status: response.status,
                        ok: response.ok,
                        data: await response.text()
                    };
                } catch (error) {
                    return { error: error.message };
                }
            });
            
            if (playlistResponse.error) {
                throw new Error(`Playlist API error: ${playlistResponse.error}`);
            }
            if (!playlistResponse.ok) {
                throw new Error(`Playlist API returned status ${playlistResponse.status}`);
            }
            
            console.log(`   Playlist API status: ${playlistResponse.status}`);
            await takeScreenshot(p, 'playlists-tab');
        });

        // Test 5: YouTube tab functionality
        await testPage(page, 'YouTube Tab', async (p) => {
            await p.evaluate(() => {
                if (typeof switchTab === 'function') {
                    switchTab('youtube');
                }
            });
            await p.waitForTimeout(1000);
            
            // Check if YouTube API responds
            const youtubeResponse = await p.evaluate(async () => {
                try {
                    const response = await fetch('/api/youtube.php?action=queue');
                    return {
                        status: response.status,
                        ok: response.ok,
                        data: await response.text()
                    };
                } catch (error) {
                    return { error: error.message };
                }
            });
            
            if (youtubeResponse.error) {
                throw new Error(`YouTube API error: ${youtubeResponse.error}`);
            }
            if (!youtubeResponse.ok) {
                throw new Error(`YouTube API returned status ${youtubeResponse.status}`);
            }
            
            console.log(`   YouTube API status: ${youtubeResponse.status}`);
            await takeScreenshot(p, 'youtube-tab');
        });

        // Test 6: Schedule tab
        await testPage(page, 'Schedule Tab', async (p) => {
            await p.evaluate(() => {
                if (typeof switchTab === 'function') {
                    switchTab('scheduling');
                }
            });
            await p.waitForTimeout(1000);
            
            // Check if schedule tab is loaded
            const scheduleTab = await p.$('#scheduling-tab');
            if (!scheduleTab) throw new Error('Schedule tab not found');
            
            await takeScreenshot(p, 'schedule-tab');
        });

        // Test 7: Display tab
        await testPage(page, 'Display Tab', async (p) => {
            await p.evaluate(() => {
                if (typeof switchTab === 'function') {
                    switchTab('display');
                }
            });
            await p.waitForTimeout(1000);
            
            // Check display tab is loaded
            const displayTab = await p.$('#display-tab');
            if (!displayTab) throw new Error('Display tab not found');
            
            await takeScreenshot(p, 'display-tab');
        });

        // Test 8: Settings tab
        await testPage(page, 'Settings Tab', async (p) => {
            await p.evaluate(() => {
                if (typeof switchTab === 'function') {
                    switchTab('settings');
                }
            });
            await p.waitForTimeout(1000);
            
            // Check settings tab is loaded
            const settingsTab = await p.$('#settings-tab');
            if (!settingsTab) throw new Error('Settings tab not found');
            
            await takeScreenshot(p, 'settings-tab');
        });

        // Test 9: API endpoints availability
        await testPage(page, 'API Endpoints', async (p) => {
            const endpoints = [
                '/api/playlist.php?action=list',
                '/api/youtube.php?action=queue',
                '/?action=list',
                '/?action=status'
            ];

            for (const endpoint of endpoints) {
                const response = await p.evaluate(async (url) => {
                    try {
                        const res = await fetch(url);
                        return { url, status: res.status, ok: res.ok };
                    } catch (error) {
                        return { url, error: error.message };
                    }
                }, endpoint);

                if (response.error) {
                    throw new Error(`${endpoint} failed: ${response.error}`);
                }
                console.log(`   ${endpoint}: ${response.status} ${response.ok ? '✓' : '✗'}`);
            }
        });

        // Test 10: Console errors check
        await testPage(page, 'Console Errors', async (p) => {
            const errors = await p.evaluate(() => {
                return new Promise((resolve) => {
                    const errors = [];
                    const originalError = console.error;
                    console.error = (...args) => {
                        errors.push(args.join(' '));
                        originalError.apply(console, args);
                    };
                    setTimeout(() => resolve(errors), 2000);
                });
            });

            if (errors.length > 0) {
                console.log(`   Found ${errors.length} console errors`);
                errors.forEach(err => console.log(`     - ${err.substring(0, 100)}`));
            } else {
                console.log(`   No console errors detected`);
            }
        });

    } finally {
        await browser.close();
    }

    // Generate test report
    generateReport();
}

function generateReport() {
    console.log('\n📊 Test Report Summary\n');
    console.log(`✅ Passed: ${testResults.passed}`);
    console.log(`❌ Failed: ${testResults.failed}`);
    console.log(`⏱️ Total time: ${testResults.tests.reduce((acc, t) => acc + (t.duration || 0), 0)}ms`);
    
    // Save detailed report
    fs.writeFileSync(config.reportFile, JSON.stringify(testResults, null, 2));
    console.log(`\n📄 Detailed report saved to: ${config.reportFile}`);
    
    // Generate HTML report
    const htmlReport = generateHTMLReport();
    const htmlFile = config.reportFile.replace('.json', '.html');
    fs.writeFileSync(htmlFile, htmlReport);
    console.log(`📄 HTML report saved to: ${htmlFile}`);
    
    // Exit with appropriate code
    process.exit(testResults.failed > 0 ? 1 : 0);
}

function generateHTMLReport() {
    const status = testResults.failed === 0 ? 'PASSED' : 'FAILED';
    const statusColor = testResults.failed === 0 ? '#4CAF50' : '#F44336';
    
    return `<!DOCTYPE html>
<html>
<head>
    <title>PiSignage Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        h1 { color: #333; }
        .summary { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .status { font-size: 24px; font-weight: bold; color: ${statusColor}; }
        .test { background: white; padding: 15px; margin-bottom: 10px; border-radius: 8px; }
        .test.passed { border-left: 4px solid #4CAF50; }
        .test.failed { border-left: 4px solid #F44336; }
        .test.warning { border-left: 4px solid #FF9800; }
        .duration { color: #666; font-size: 12px; }
        .error { background: #FFEBEE; padding: 10px; margin-top: 10px; border-radius: 4px; }
        .screenshot { margin-top: 10px; }
        .screenshot img { max-width: 200px; cursor: pointer; }
    </style>
</head>
<body>
    <h1>PiSignage Test Report</h1>
    <div class="summary">
        <div class="status">Status: ${status}</div>
        <p>Generated: ${testResults.timestamp}</p>
        <p>Passed: ${testResults.passed} | Failed: ${testResults.failed}</p>
        <p>Total Duration: ${testResults.tests.reduce((acc, t) => acc + (t.duration || 0), 0)}ms</p>
    </div>
    ${testResults.tests.map(test => `
        <div class="test ${test.status}">
            <h3>${test.name}</h3>
            <span class="duration">${test.duration}ms</span>
            ${test.error ? `<div class="error">Error: ${test.error}</div>` : ''}
            ${test.errors && test.errors.length > 0 ? 
                `<div class="error">Console Errors: ${test.errors.length}</div>` : ''}
            ${test.screenshot ? 
                `<div class="screenshot">
                    <img src="${test.screenshot}" onclick="window.open(this.src)">
                </div>` : ''}
        </div>
    `).join('')}
</body>
</html>`;
}

// Run tests
runTests().catch(error => {
    console.error('Test suite failed:', error);
    process.exit(1);
});