#!/usr/bin/env node

/**
 * PiSignage Web Interface Test Suite
 * Tests l'interface web et l'API avec Playwright
 */

let chromium;
try {
    chromium = require('playwright').chromium;
} catch (error) {
    // Playwright n'est pas installé, on continuera avec le test simple
}
const fs = require('fs');
const path = require('path');

class PiSignageWebTester {
    constructor() {
        this.browser = null;
        this.page = null;
        this.testResults = [];
        this.testBaseUrl = process.env.PISIGNAGE_URL || 'http://localhost:8080';
    }

    async init() {
        try {
            if (!chromium) {
                throw new Error('Playwright not available');
            }
            this.browser = await chromium.launch({ headless: true });
            this.page = await this.browser.newPage();
            console.log('✅ Playwright initialized successfully');
            return true;
        } catch (error) {
            console.log('❌ Failed to initialize Playwright:', error.message);
            return false;
        }
    }

    async cleanup() {
        if (this.browser) {
            await this.browser.close();
        }
    }

    logResult(testName, success, message = '') {
        const result = {
            test: testName,
            success,
            message,
            timestamp: new Date().toISOString()
        };
        this.testResults.push(result);
        
        const status = success ? '✅ PASS' : '❌ FAIL';
        console.log(`${status} ${testName}: ${message}`);
    }

    async testWebsiteAccessibility() {
        try {
            const response = await this.page.goto(this.testBaseUrl, { 
                waitUntil: 'networkidle',
                timeout: 10000 
            });
            
            if (response && response.ok()) {
                this.logResult('Website Accessibility', true, `Site accessible at ${this.testBaseUrl}`);
                return true;
            } else {
                this.logResult('Website Accessibility', false, `Site returned status: ${response?.status()}`);
                return false;
            }
        } catch (error) {
            this.logResult('Website Accessibility', false, `Connection failed: ${error.message}`);
            return false;
        }
    }

    async testPageStructure() {
        try {
            // Vérifier le titre de la page
            const title = await this.page.title();
            if (title.toLowerCase().includes('pisignage')) {
                this.logResult('Page Title', true, `Title contains PiSignage: "${title}"`);
            } else {
                this.logResult('Page Title', false, `Title doesn't contain PiSignage: "${title}"`);
            }

            // Vérifier les éléments de base
            const bodyExists = await this.page.$('body') !== null;
            this.logResult('Body Element', bodyExists, bodyExists ? 'Body element found' : 'Body element missing');

            // Vérifier si c'est une interface PiSignage
            const hasApiControls = await this.page.$('[data-action], .player-control, #media-list') !== null;
            this.logResult('PiSignage Interface Elements', hasApiControls, 
                hasApiControls ? 'Interface elements detected' : 'Interface elements missing');

            return true;
        } catch (error) {
            this.logResult('Page Structure', false, `Failed to analyze page: ${error.message}`);
            return false;
        }
    }

    async testApiEndpoints() {
        const endpoints = [
            { path: '/api/control.php?action=status', name: 'Status API' },
            { path: '/api/control.php?action=media', name: 'Media List API' }
        ];

        for (const endpoint of endpoints) {
            try {
                const response = await this.page.request.get(`${this.testBaseUrl}${endpoint.path}`);
                
                if (response.ok()) {
                    const contentType = response.headers()['content-type'];
                    if (contentType && contentType.includes('application/json')) {
                        const data = await response.json();
                        this.logResult(endpoint.name, true, 
                            `API responded with valid JSON (status: ${response.status()})`);
                    } else {
                        this.logResult(endpoint.name, false, 
                            `API responded but not with JSON (content-type: ${contentType})`);
                    }
                } else {
                    this.logResult(endpoint.name, false, 
                        `API returned error status: ${response.status()}`);
                }
            } catch (error) {
                this.logResult(endpoint.name, false, 
                    `API request failed: ${error.message}`);
            }
        }
    }

    async testFormInteractions() {
        try {
            // Rechercher des formulaires
            const forms = await this.page.$$('form');
            this.logResult('Form Detection', forms.length > 0, 
                `Found ${forms.length} form(s) on the page`);

            // Rechercher des boutons de contrôle
            const buttons = await this.page.$$('button, input[type="button"], .btn');
            this.logResult('Control Buttons', buttons.length > 0, 
                `Found ${buttons.length} interactive button(s)`);

            // Test de base de l'interface (sans clics réels pour éviter les effets de bord)
            const hasFileInput = await this.page.$('input[type="file"]') !== null;
            this.logResult('File Upload Interface', hasFileInput, 
                hasFileInput ? 'File upload interface detected' : 'No file upload detected');

            return true;
        } catch (error) {
            this.logResult('Form Interactions', false, `Failed to test forms: ${error.message}`);
            return false;
        }
    }

    async testResponsiveDesign() {
        try {
            // Test desktop
            await this.page.setViewportSize({ width: 1920, height: 1080 });
            await this.page.waitForTimeout(500);
            const desktopElements = await this.page.$$('*:visible');
            
            // Test mobile
            await this.page.setViewportSize({ width: 375, height: 667 });
            await this.page.waitForTimeout(500);
            const mobileElements = await this.page.$$('*:visible');
            
            this.logResult('Responsive Design', true, 
                `Desktop: ${desktopElements.length} elements, Mobile: ${mobileElements.length} elements`);
            
            return true;
        } catch (error) {
            this.logResult('Responsive Design', false, `Failed to test responsiveness: ${error.message}`);
            return false;
        }
    }

    async runAllTests() {
        console.log('🚀 Starting PiSignage Web Test Suite...\n');

        // Initialisation
        const initialized = await this.init();
        if (!initialized) {
            console.log('❌ Cannot proceed without Playwright. Install with: npm install playwright');
            return false;
        }

        // Tests principaux
        const tests = [
            () => this.testWebsiteAccessibility(),
            () => this.testPageStructure(),
            () => this.testApiEndpoints(),
            () => this.testFormInteractions(),
            () => this.testResponsiveDesign()
        ];

        for (const test of tests) {
            try {
                await test();
            } catch (error) {
                console.log(`❌ Test failed with error: ${error.message}`);
            }
        }

        // Nettoyage
        await this.cleanup();

        // Rapport final
        console.log('\n📊 Test Results Summary:');
        console.log('========================');
        
        const passed = this.testResults.filter(r => r.success).length;
        const total = this.testResults.length;
        
        console.log(`Total tests: ${total}`);
        console.log(`Passed: ${passed}`);
        console.log(`Failed: ${total - passed}`);
        console.log(`Success rate: ${Math.round((passed / total) * 100)}%`);

        // Sauvegarde des résultats
        const reportPath = path.join(__dirname, '..', 'logs', 'web-test-results.json');
        try {
            const reportDir = path.dirname(reportPath);
            if (!fs.existsSync(reportDir)) {
                fs.mkdirSync(reportDir, { recursive: true });
            }
            fs.writeFileSync(reportPath, JSON.stringify(this.testResults, null, 2));
            console.log(`\n📄 Detailed results saved to: ${reportPath}`);
        } catch (error) {
            console.log(`⚠️  Could not save report: ${error.message}`);
        }

        return passed === total;
    }
}

// Test simple sans Playwright si pas disponible
async function simpleTest() {
    console.log('🔧 Running simplified tests without Playwright...\n');
    
    const testUrl = process.env.PISIGNAGE_URL || 'http://localhost:8080';
    
    // Test HTTP basique avec curl si disponible
    const { spawn } = require('child_process');
    
    return new Promise((resolve) => {
        const curl = spawn('curl', ['-s', '-o', '/dev/null', '-w', '%{http_code}', testUrl]);
        
        curl.stdout.on('data', (data) => {
            const statusCode = data.toString().trim();
            if (statusCode === '200') {
                console.log('✅ HTTP Connectivity: Website is accessible');
                resolve(true);
            } else {
                console.log(`❌ HTTP Connectivity: Website returned status ${statusCode}`);
                resolve(false);
            }
        });
        
        curl.on('error', () => {
            console.log('❌ HTTP Connectivity: Cannot reach website');
            resolve(false);
        });
    });
}

// Exécution principale
async function main() {
    if (!chromium) {
        // Fallback vers test simple
        console.log('ℹ️  Playwright not available, running basic tests...\n');
        const success = await simpleTest();
        process.exit(success ? 0 : 1);
    } else {
        try {
            // Essayer avec Playwright
            const tester = new PiSignageWebTester();
            const success = await tester.runAllTests();
            process.exit(success ? 0 : 1);
        } catch (error) {
            console.error('❌ Test suite failed:', error.message);
            process.exit(1);
        }
    }
}

if (require.main === module) {
    main();
}

module.exports = { PiSignageWebTester };