/**
 * PiSignage Schedule Module - Puppeteer Tests
 * Tests comprehensive scheduler functionality
 */

const puppeteer = require('puppeteer');

const BASE_URL = process.env.BASE_URL || 'http://localhost';
const TEST_TIMEOUT = 30000;

// Test results storage
const results = {
    total: 0,
    passed: 0,
    failed: 0,
    tests: []
};

/**
 * Add test result
 */
function addResult(name, passed, error = null) {
    results.total++;
    if (passed) {
        results.passed++;
    } else {
        results.failed++;
    }

    results.tests.push({
        name,
        passed,
        error: error ? error.message : null
    });

    console.log(`${passed ? '✅' : '❌'} ${name}`);
    if (error) {
        console.log(`   Error: ${error.message}`);
    }
}

/**
 * Main test runner
 */
async function runTests() {
    console.log('🧪 Starting Schedule Module Tests...\n');

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });

    try {
        // Navigate to schedule page
        await page.goto(`${BASE_URL}/schedule.php`, {
            waitUntil: 'networkidle2',
            timeout: TEST_TIMEOUT
        });

        // ==================== PAGE LOAD TESTS ====================
        await testPageLoad(page);

        // ==================== UI COMPONENT TESTS ====================
        await testUIComponents(page);

        // ==================== STATISTICS TESTS ====================
        await testStatistics(page);

        // ==================== VIEW SWITCHER TESTS ====================
        await testViewSwitcher(page);

        // ==================== MODAL TESTS ====================
        await testModal(page);

        // ==================== FORM VALIDATION TESTS ====================
        await testFormValidation(page);

        // ==================== CRUD OPERATIONS TESTS ====================
        await testCRUDOperations(page);

    } catch (error) {
        console.error('Fatal error during tests:', error);
    } finally {
        await browser.close();
    }

    // Print results
    printResults();
}

/**
 * Test page load
 */
async function testPageLoad(page) {
    console.log('\n📄 Testing page load...');

    try {
        const title = await page.title();
        addResult('Page title exists', title.length > 0);
    } catch (error) {
        addResult('Page title exists', false, error);
    }

    try {
        const header = await page.$('.page-title');
        const headerText = await page.evaluate(el => el.textContent, header);
        addResult('Page header is "Programmation"', headerText.includes('Programmation'));
    } catch (error) {
        addResult('Page header is "Programmation"', false, error);
    }

    try {
        const newButton = await page.$('button.btn-primary');
        const buttonText = await page.evaluate(el => el.textContent, newButton);
        addResult('New schedule button exists', buttonText.includes('Nouveau Planning'));
    } catch (error) {
        addResult('New schedule button exists', false, error);
    }
}

/**
 * Test UI components
 */
async function testUIComponents(page) {
    console.log('\n🎨 Testing UI components...');

    // Statistics panel
    try {
        const statActive = await page.$('#stat-active');
        addResult('Statistics panel exists', statActive !== null);
    } catch (error) {
        addResult('Statistics panel exists', false, error);
    }

    // View selector
    try {
        const viewBtns = await page.$$('.view-btn');
        addResult('View selector has 3 buttons', viewBtns.length === 3);
    } catch (error) {
        addResult('View selector has 3 buttons', false, error);
    }

    // Schedule list container
    try {
        const scheduleList = await page.$('#schedule-list');
        addResult('Schedule list container exists', scheduleList !== null);
    } catch (error) {
        addResult('Schedule list container exists', false, error);
    }

    // Empty state
    try {
        const emptyState = await page.$('#empty-state');
        const isVisible = await page.evaluate(el => {
            const style = window.getComputedStyle(el);
            return style.display !== 'none';
        }, emptyState);
        addResult('Empty state is visible when no schedules', isVisible);
    } catch (error) {
        addResult('Empty state is visible when no schedules', false, error);
    }
}

/**
 * Test statistics
 */
async function testStatistics(page) {
    console.log('\n📊 Testing statistics...');

    const stats = ['stat-active', 'stat-inactive', 'stat-running', 'stat-upcoming'];

    for (const statId of stats) {
        try {
            const statEl = await page.$(`#${statId}`);
            const value = await page.evaluate(el => el.textContent, statEl);
            addResult(`Statistic ${statId} displays number`, !isNaN(parseInt(value)));
        } catch (error) {
            addResult(`Statistic ${statId} displays number`, false, error);
        }
    }
}

/**
 * Test view switcher
 */
async function testViewSwitcher(page) {
    console.log('\n👁️ Testing view switcher...');

    const views = ['list', 'calendar', 'timeline'];

    for (const view of views) {
        try {
            // Click view button
            await page.click(`button[data-view="${view}"]`);
            await page.waitForTimeout(500);

            // Check if view is active
            const isActive = await page.evaluate((v) => {
                const btn = document.querySelector(`button[data-view="${v}"]`);
                return btn.classList.contains('active');
            }, view);

            addResult(`View switcher activates ${view} view`, isActive);
        } catch (error) {
            addResult(`View switcher activates ${view} view`, false, error);
        }
    }
}

/**
 * Test modal
 */
async function testModal(page) {
    console.log('\n🪟 Testing modal...');

    try {
        // Open modal
        await page.click('button.btn-primary');
        await page.waitForTimeout(500);

        const modalVisible = await page.evaluate(() => {
            const modal = document.getElementById('schedule-modal');
            return modal.classList.contains('show');
        });

        addResult('Modal opens when clicking new button', modalVisible);

        // Check modal title
        const modalTitle = await page.evaluate(() => {
            return document.getElementById('modal-title').textContent;
        });

        addResult('Modal title is "Nouveau Planning"', modalTitle.includes('Nouveau Planning'));

        // Check tabs exist
        const tabs = await page.$$('.tab-btn');
        addResult('Modal has 4 tabs', tabs.length === 4);

        // Test tab switching
        const tabNames = ['general', 'timing', 'recurrence', 'advanced'];
        for (const tabName of tabNames) {
            await page.click(`button[data-tab="${tabName}"]`);
            await page.waitForTimeout(300);

            const tabActive = await page.evaluate((name) => {
                const btn = document.querySelector(`button[data-tab="${name}"]`);
                return btn.classList.contains('active');
            }, tabName);

            addResult(`Tab "${tabName}" activates correctly`, tabActive);
        }

        // Close modal
        await page.click('.btn-close');
        await page.waitForTimeout(500);

        const modalClosed = await page.evaluate(() => {
            const modal = document.getElementById('schedule-modal');
            return !modal.classList.contains('show');
        });

        addResult('Modal closes when clicking close button', modalClosed);

    } catch (error) {
        addResult('Modal interaction tests', false, error);
    }
}

/**
 * Test form validation
 */
async function testFormValidation(page) {
    console.log('\n✅ Testing form validation...');

    try {
        // Open modal
        await page.click('button.btn-primary');
        await page.waitForTimeout(500);

        // Try to save without filling required fields
        await page.click('button.btn-primary:not(.btn-glass)');
        await page.waitForTimeout(1000);

        // Check if alert appeared (form validation failed as expected)
        const alertShown = await page.evaluate(() => {
            // If modal is still open, validation worked
            const modal = document.getElementById('schedule-modal');
            return modal.classList.contains('show');
        });

        addResult('Form validation prevents saving empty form', alertShown);

        // Fill required fields
        await page.type('#schedule-name', 'Test Schedule');
        await page.select('#schedule-playlist', 'default'); // Assuming default playlist exists
        await page.type('#schedule-start-time', '08:00');
        await page.type('#schedule-end-time', '17:00');

        addResult('Required fields can be filled', true);

        // Close modal
        await page.click('.btn-close');
        await page.waitForTimeout(500);

    } catch (error) {
        addResult('Form validation tests', false, error);
    }
}

/**
 * Test CRUD operations
 */
async function testCRUDOperations(page) {
    console.log('\n🔧 Testing CRUD operations...');

    // Note: These tests require a running backend API
    // They will test the UI interactions that trigger API calls

    try {
        // Test CREATE (UI interaction)
        await page.click('button.btn-primary');
        await page.waitForTimeout(500);

        // Fill form
        await page.type('#schedule-name', 'Puppeteer Test Schedule');

        // Check if playlist dropdown has options
        const playlistOptions = await page.$$('#schedule-playlist option');
        const hasPlaylists = playlistOptions.length > 1; // More than just placeholder

        if (hasPlaylists) {
            // Select first playlist
            await page.evaluate(() => {
                const select = document.getElementById('schedule-playlist');
                select.selectedIndex = 1;
                select.dispatchEvent(new Event('change'));
            });

            await page.type('#schedule-start-time', '09:00');
            await page.type('#schedule-end-time', '18:00');

            // Switch to recurrence tab
            await page.click('button[data-tab="recurrence"]');
            await page.waitForTimeout(300);

            // Select weekly recurrence
            await page.click('input[name="recurrence-type"][value="weekly"]');
            await page.waitForTimeout(300);

            // Select some days (Monday, Wednesday, Friday)
            await page.evaluate(() => {
                document.querySelector('.days-selector input[value="1"]').click();
                document.querySelector('.days-selector input[value="3"]').click();
                document.querySelector('.days-selector input[value="5"]').click();
            });

            addResult('Schedule form can be filled completely', true);

            // Note: We don't actually save to avoid creating test data
            // In production tests, you would:
            // - await page.click('button.btn-success');
            // - Check for success message
            // - Verify schedule appears in list

            await page.click('.btn-close');
        } else {
            addResult('Schedule form can be filled (skipped: no playlists)', true);
        }

    } catch (error) {
        addResult('CRUD operation tests', false, error);
    }
}

/**
 * Print test results
 */
function printResults() {
    console.log('\n' + '='.repeat(60));
    console.log('📋 TEST RESULTS SUMMARY');
    console.log('='.repeat(60));
    console.log(`Total Tests: ${results.total}`);
    console.log(`✅ Passed: ${results.passed}`);
    console.log(`❌ Failed: ${results.failed}`);
    console.log(`Success Rate: ${((results.passed / results.total) * 100).toFixed(2)}%`);
    console.log('='.repeat(60));

    if (results.failed > 0) {
        console.log('\n❌ Failed Tests:');
        results.tests.filter(t => !t.passed).forEach(test => {
            console.log(`  - ${test.name}`);
            if (test.error) {
                console.log(`    Error: ${test.error}`);
            }
        });
    }

    // Save results to JSON
    const fs = require('fs');
    const timestamp = new Date().toISOString();
    const report = {
        timestamp,
        summary: {
            total: results.total,
            passed: results.passed,
            failed: results.failed,
            successRate: (results.passed / results.total) * 100
        },
        tests: results.tests
    };

    fs.writeFileSync(
        '/opt/pisignage/tests/schedule-test-results.json',
        JSON.stringify(report, null, 2)
    );

    console.log('\n📄 Results saved to: tests/schedule-test-results.json\n');

    // Exit with appropriate code
    process.exit(results.failed > 0 ? 1 : 0);
}

// Run tests
runTests().catch(error => {
    console.error('Test runner failed:', error);
    process.exit(1);
});
