const puppeteer = require('puppeteer');
const fs = require('fs');

async function auditModule(moduleName, url) {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    const results = {
        module: moduleName,
        url: url,
        pageExists: false,
        pageLoads: false,
        consoleErrors: [],
        visibleElements: [],
        screenshot: null,
        timestamp: new Date().toISOString()
    };

    // Capture console errors
    page.on('console', msg => {
        if (msg.type() === 'error') {
            results.consoleErrors.push(msg.text());
        }
    });

    try {
        // Try to load page
        const response = await page.goto(url, {
            waitUntil: 'networkidle2',
            timeout: 10000
        });

        results.pageExists = response.status() === 200;
        results.pageLoads = response.ok();

        if (results.pageLoads) {
            // Wait a bit for dynamic content
            await page.waitForTimeout(2000);

            // Get page title
            results.title = await page.title();

            // Check for common UI elements
            results.visibleElements = await page.evaluate(() => {
                const elements = [];
                const buttons = document.querySelectorAll('button');
                const forms = document.querySelectorAll('form');
                const inputs = document.querySelectorAll('input');
                const headers = document.querySelectorAll('h1, h2, h3');

                return {
                    buttons: buttons.length,
                    forms: forms.length,
                    inputs: inputs.length,
                    headers: headers.length,
                    hasContent: document.body.innerText.length > 100
                };
            });

            // Take screenshot
            const screenshotPath = `/opt/pisignage/tests/screenshots/${moduleName}.png`;
            await page.screenshot({ path: screenshotPath, fullPage: true });
            results.screenshot = screenshotPath;
        }

    } catch (error) {
        results.error = error.message;
    }

    await browser.close();
    return results;
}

async function runQuickAudit() {
    const modules = [
        { name: 'settings', url: 'http://192.168.1.103/settings.php' },
        { name: 'schedule', url: 'http://192.168.1.103/schedule.php' },
        { name: 'screenshot', url: 'http://192.168.1.103/screenshot.php' },
        { name: 'logs', url: 'http://192.168.1.103/logs.php' },
        { name: 'youtube', url: 'http://192.168.1.103/youtube.php' }
    ];

    const allResults = [];

    for (const module of modules) {
        console.log(`\n🔍 Auditing ${module.name}...`);
        const result = await auditModule(module.name, module.url);
        allResults.push(result);
        console.log(`   ${result.pageLoads ? '✅' : '❌'} ${module.name}: ${result.pageLoads ? 'OK' : 'FAILED'}`);
    }

    // Save results
    fs.writeFileSync(
        '/opt/pisignage/tests/quick-audit-results.json',
        JSON.stringify(allResults, null, 2)
    );

    console.log('\n✅ Quick audit completed!');
    console.log('📄 Results: /opt/pisignage/tests/quick-audit-results.json');
}

runQuickAudit().catch(console.error);
