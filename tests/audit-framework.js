/**
 * PiSignage Audit Framework
 * Automated testing suite using Puppeteer
 */

const puppeteer = require('puppeteer');
const fs = require('fs').promises;
const path = require('path');

class PiSignageAuditor {
    constructor(baseUrl = 'http://192.168.1.103') {
        this.baseUrl = baseUrl;
        this.browser = null;
        this.page = null;
        this.results = {
            timestamp: new Date().toISOString(),
            modules: {},
            errors: [],
            warnings: [],
            screenshots: []
        };
    }

    async initialize() {
        console.log('🚀 Initializing PiSignage Auditor...');
        this.browser = await puppeteer.launch({
            headless: true, // Running in headless mode for server environment
            defaultViewport: { width: 1920, height: 1080 },
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
        });
        this.page = await this.browser.newPage();

        // Capture console messages
        this.page.on('console', msg => {
            const type = msg.type();
            const text = msg.text();

            if (type === 'error') {
                this.results.errors.push({
                    timestamp: new Date().toISOString(),
                    url: this.page.url(),
                    message: text
                });
            } else if (type === 'warning') {
                this.results.warnings.push({
                    timestamp: new Date().toISOString(),
                    url: this.page.url(),
                    message: text
                });
            }

            console.log(`[${type.toUpperCase()}] ${text}`);
        });

        // Capture page errors
        this.page.on('pageerror', error => {
            this.results.errors.push({
                timestamp: new Date().toISOString(),
                url: this.page.url(),
                message: error.message,
                stack: error.stack
            });
        });

        // Capture failed requests
        this.page.on('requestfailed', request => {
            this.results.errors.push({
                timestamp: new Date().toISOString(),
                url: request.url(),
                method: request.method(),
                failure: request.failure().errorText
            });
        });

        console.log('✅ Auditor initialized');
    }

    async navigateTo(path) {
        const url = `${this.baseUrl}${path}`;
        console.log(`📍 Navigating to: ${url}`);

        try {
            await this.page.goto(url, {
                waitUntil: 'networkidle2',
                timeout: 30000
            });
            await this.wait(2000); // Wait for any dynamic content
            return true;
        } catch (error) {
            console.error(`❌ Navigation failed: ${error.message}`);
            this.results.errors.push({
                timestamp: new Date().toISOString(),
                action: 'navigation',
                url: url,
                error: error.message
            });
            return false;
        }
    }

    async screenshot(name) {
        const screenshotPath = path.join(__dirname, 'screenshots', `${name}.png`);
        await fs.mkdir(path.dirname(screenshotPath), { recursive: true });
        await this.page.screenshot({ path: screenshotPath, fullPage: true });
        this.results.screenshots.push(screenshotPath);
        console.log(`📸 Screenshot saved: ${name}`);
        return screenshotPath;
    }

    async checkElement(selector, description) {
        try {
            const element = await this.page.$(selector);
            const exists = element !== null;

            if (exists) {
                const isVisible = await element.isIntersectingViewport();
                console.log(`✅ ${description}: Found and ${isVisible ? 'visible' : 'hidden'}`);
                return { exists: true, visible: isVisible };
            } else {
                console.log(`❌ ${description}: Not found`);
                return { exists: false, visible: false };
            }
        } catch (error) {
            console.error(`❌ ${description}: Error checking - ${error.message}`);
            return { exists: false, visible: false, error: error.message };
        }
    }

    async clickElement(selector, description) {
        try {
            await this.page.waitForSelector(selector, { timeout: 5000 });
            await this.page.click(selector);
            console.log(`✅ Clicked: ${description}`);
            await this.wait(1000);
            return true;
        } catch (error) {
            console.error(`❌ Failed to click ${description}: ${error.message}`);
            this.results.errors.push({
                timestamp: new Date().toISOString(),
                action: 'click',
                selector: selector,
                description: description,
                error: error.message
            });
            return false;
        }
    }

    async typeText(selector, text, description) {
        try {
            await this.page.waitForSelector(selector, { timeout: 5000 });
            await this.page.type(selector, text);
            console.log(`✅ Typed in ${description}: "${text}"`);
            return true;
        } catch (error) {
            console.error(`❌ Failed to type in ${description}: ${error.message}`);
            return false;
        }
    }

    async evaluateFunction(fn, description) {
        try {
            const result = await this.page.evaluate(fn);
            console.log(`✅ Evaluated ${description}`);
            return result;
        } catch (error) {
            console.error(`❌ Failed to evaluate ${description}: ${error.message}`);
            return null;
        }
    }

    async wait(ms) {
        await new Promise(resolve => setTimeout(resolve, ms));
    }

    async getApiResponse(endpoint) {
        try {
            const response = await this.page.evaluate(async (url) => {
                const res = await fetch(url);
                const data = await res.json();
                return { status: res.status, data };
            }, `${this.baseUrl}/api/${endpoint}`);

            console.log(`✅ API ${endpoint}: Status ${response.status}`);
            return response;
        } catch (error) {
            console.error(`❌ API ${endpoint} failed: ${error.message}`);
            return null;
        }
    }

    async auditModule(moduleName, tests) {
        console.log(`\n${'='.repeat(50)}`);
        console.log(`📋 Auditing Module: ${moduleName}`);
        console.log(`${'='.repeat(50)}\n`);

        this.results.modules[moduleName] = {
            timestamp: new Date().toISOString(),
            tests: [],
            passed: 0,
            failed: 0
        };

        for (const test of tests) {
            console.log(`\n🧪 Test: ${test.name}`);

            const testResult = {
                name: test.name,
                description: test.description,
                timestamp: new Date().toISOString()
            };

            try {
                const result = await test.fn(this);
                testResult.passed = result;
                testResult.details = test.details || {};

                if (result) {
                    this.results.modules[moduleName].passed++;
                    console.log(`✅ Test passed: ${test.name}`);
                } else {
                    this.results.modules[moduleName].failed++;
                    console.log(`❌ Test failed: ${test.name}`);
                }
            } catch (error) {
                testResult.passed = false;
                testResult.error = error.message;
                this.results.modules[moduleName].failed++;
                console.error(`❌ Test crashed: ${test.name} - ${error.message}`);
            }

            this.results.modules[moduleName].tests.push(testResult);
        }

        console.log(`\n📊 Module Results: ${this.results.modules[moduleName].passed} passed, ${this.results.modules[moduleName].failed} failed`);
    }

    async saveResults() {
        const resultsPath = path.join(__dirname, `audit-results-${Date.now()}.json`);
        await fs.writeFile(resultsPath, JSON.stringify(this.results, null, 2));
        console.log(`\n💾 Results saved to: ${resultsPath}`);
        return resultsPath;
    }

    async cleanup() {
        if (this.browser) {
            await this.browser.close();
            console.log('🧹 Browser closed');
        }
    }

    async generateReport() {
        let report = '# PiSignage Audit Report\n\n';
        report += `**Date**: ${new Date().toISOString()}\n\n`;
        report += `## Summary\n\n`;

        let totalPassed = 0;
        let totalFailed = 0;

        for (const [module, results] of Object.entries(this.results.modules)) {
            totalPassed += results.passed;
            totalFailed += results.failed;

            report += `### ${module}\n`;
            report += `- ✅ Passed: ${results.passed}\n`;
            report += `- ❌ Failed: ${results.failed}\n\n`;
        }

        report += `## Total Results\n`;
        report += `- Total Tests: ${totalPassed + totalFailed}\n`;
        report += `- Passed: ${totalPassed}\n`;
        report += `- Failed: ${totalFailed}\n`;
        report += `- Success Rate: ${((totalPassed / (totalPassed + totalFailed)) * 100).toFixed(2)}%\n\n`;

        report += `## Errors (${this.results.errors.length})\n\n`;
        this.results.errors.forEach(error => {
            report += `- ${error.timestamp}: ${error.message}\n`;
        });

        const reportPath = path.join(__dirname, `audit-report-${Date.now()}.md`);
        await fs.writeFile(reportPath, report);
        console.log(`📄 Report generated: ${reportPath}`);

        return report;
    }
}

module.exports = PiSignageAuditor;