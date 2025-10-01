const puppeteer = require('puppeteer');

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function runTests() {
    console.log('🔍 COMPLETE SCHEDULER DEBUG - Running from debiandev\n');
    console.log('Target: http://192.168.1.105/schedule.php\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // Capture console messages
    const consoleLogs = [];
    page.on('console', msg => {
        const text = msg.text();
        consoleLogs.push(text);
        if (text.includes('Error') || text.includes('error') || text.includes('Loaded')) {
            console.log(`  📋 ${text}`);
        }
    });
    
    // Capture network errors
    page.on('requestfailed', request => {
        console.log(`  ❌ Network fail: ${request.url()}`);
    });
    
    try {
        console.log('STEP 1: Load page and wait for initialization');
        console.log('=========================================');
        await page.goto('http://192.168.1.105/schedule.php', {
            waitUntil: 'networkidle2',
            timeout: 30000
        });
        await sleep(3000);
        
        // Check page loaded
        const title = await page.title();
        console.log(`✅ Page title: ${title}`);
        
        // Check PiSignage namespace
        const namespaceCheck = await page.evaluate(() => {
            return {
                hasPiSignage: typeof window.PiSignage !== 'undefined',
                hasSchedule: typeof window.PiSignage?.Schedule !== 'undefined',
                playlists: window.PiSignage?.Schedule?.playlists?.length || 0
            };
        });
        
        console.log(`✅ PiSignage namespace: ${namespaceCheck.hasPiSignage}`);
        console.log(`✅ Schedule module: ${namespaceCheck.hasSchedule}`);
        console.log(`✅ Playlists loaded: ${namespaceCheck.playlists}`);
        
        console.log('\nSTEP 2: Check existing schedules via API');
        console.log('=========================================');
        const existingSchedules = await page.evaluate(async () => {
            const response = await fetch('/api/schedule.php');
            const data = await response.json();
            return data;
        });
        
        console.log(`✅ API response success: ${existingSchedules.success}`);
        console.log(`✅ Schedules count: ${existingSchedules.count}`);
        
        if (existingSchedules.data && existingSchedules.data.length > 0) {
            console.log('\n⚠️ Found existing schedules:');
            existingSchedules.data.forEach(s => {
                console.log(`  - ${s.name}: ${s.schedule.start_time}-${s.schedule.end_time} (${s.schedule.recurrence.type})`);
            });
        }
        
        console.log('\nSTEP 3: Open modal and check UI elements');
        console.log('=========================================');

        // Wait for Schedule module to be ready
        await page.waitForFunction(() => {
            return window.PiSignage?.Schedule?.openAddModal !== undefined;
        }, { timeout: 10000 });
        console.log('✅ Schedule module ready');

        // Call openAddModal via JavaScript instead of clicking
        await page.evaluate(() => {
            window.PiSignage.Schedule.openAddModal();
        });
        await sleep(1500);

        const modalState = await page.evaluate(() => {
            const modal = document.getElementById('schedule-modal');
            return {
                exists: !!modal,
                visible: modal?.classList.contains('show'),
                title: document.getElementById('modal-title')?.textContent
            };
        });
        
        console.log(`✅ Modal exists: ${modalState.exists}`);
        console.log(`✅ Modal visible: ${modalState.visible}`);
        console.log(`✅ Modal title: ${modalState.title}`);
        
        if (!modalState.visible) {
            throw new Error('Modal did not open!');
        }
        
        console.log('\nSTEP 4: Check form fields');
        console.log('=========================================');
        
        const formFields = await page.evaluate(() => {
            return {
                nameField: !!document.getElementById('schedule-name'),
                playlistField: !!document.getElementById('schedule-playlist'),
                startTimeField: !!document.getElementById('schedule-start-time'),
                endTimeField: !!document.getElementById('schedule-end-time'),
                playlistOptions: Array.from(document.querySelectorAll('#schedule-playlist option'))
                    .map(o => ({ value: o.value, text: o.textContent }))
            };
        });
        
        console.log(`✅ Name field: ${formFields.nameField}`);
        console.log(`✅ Playlist field: ${formFields.playlistField}`);
        console.log(`✅ Start time field: ${formFields.startTimeField}`);
        console.log(`✅ End time field: ${formFields.endTimeField}`);
        console.log(`✅ Playlist options: ${formFields.playlistOptions.length}`);
        
        if (formFields.playlistOptions.length > 0) {
            console.log('\n📋 Available playlists:');
            formFields.playlistOptions.forEach(opt => {
                if (opt.value) console.log(`  - ${opt.text} (${opt.value})`);
            });
        }
        
        console.log('\nSTEP 5: Fill form with test data');
        console.log('=========================================');

        // Use evaluate to set values directly for more reliability
        await page.evaluate(() => {
            document.getElementById('schedule-name').value = 'Puppeteer Complete Test';
        });
        console.log('✅ Filled name');

        if (formFields.playlistOptions.length > 1) {
            const firstPlaylist = formFields.playlistOptions.find(o => o.value);
            if (firstPlaylist) {
                await page.evaluate((value) => {
                    document.getElementById('schedule-playlist').value = value;
                }, firstPlaylist.value);
                console.log(`✅ Selected playlist: ${firstPlaylist.text}`);
            }
        }

        // Set time values directly
        await page.evaluate(() => {
            document.getElementById('schedule-start-time').value = '10:00';
            document.getElementById('schedule-end-time').value = '11:00';
        });
        console.log('✅ Filled start time: 10:00');
        console.log('✅ Filled end time: 11:00');

        // Verify values are set
        const verifyValues = await page.evaluate(() => {
            return {
                name: document.getElementById('schedule-name').value,
                playlist: document.getElementById('schedule-playlist').value,
                startTime: document.getElementById('schedule-start-time').value,
                endTime: document.getElementById('schedule-end-time').value
            };
        });
        console.log('\n📋 Verification:');
        console.log('   Name:', verifyValues.name);
        console.log('   Playlist:', verifyValues.playlist);
        console.log('   Start:', verifyValues.startTime);
        console.log('   End:', verifyValues.endTime);
        
        console.log('\nSTEP 6: Attempt to save');
        console.log('=========================================');
        
        // Take screenshot before save
        await page.screenshot({ path: '/opt/pisignage/tests/screenshots/scheduler-before-save.png' });
        console.log('✅ Screenshot saved: scheduler-before-save.png');
        
        // Click save button (primary, not glass)
        const saveButtons = await page.$$('button.btn-primary');
        console.log(`Found ${saveButtons.length} primary buttons`);
        
        // Click the save button inside modal footer
        await page.evaluate(() => {
            const saveBtn = document.querySelector('.modal-footer button.btn-primary');
            if (saveBtn) saveBtn.click();
        });
        
        console.log('✅ Clicked save button');
        await sleep(3000);
        
        // Check if conflict modal appeared
        const conflictCheck = await page.evaluate(() => {
            const conflictModal = document.getElementById('conflict-modal');
            const scheduleModal = document.getElementById('schedule-modal');
            return {
                conflictVisible: conflictModal?.classList.contains('show'),
                scheduleVisible: scheduleModal?.classList.contains('show'),
                conflictMessage: document.getElementById('conflict-message')?.textContent,
                conflictItems: Array.from(document.querySelectorAll('.conflict-item'))
                    .map(item => item.textContent.trim())
            };
        });
        
        console.log(`\n${conflictCheck.conflictVisible ? '⚠️' : '✅'} Conflict modal: ${conflictCheck.conflictVisible ? 'SHOWN' : 'NOT SHOWN'}`);
        console.log(`${conflictCheck.scheduleVisible ? '⚠️' : '✅'} Schedule modal: ${conflictCheck.scheduleVisible ? 'STILL OPEN' : 'CLOSED'}`);
        
        if (conflictCheck.conflictVisible) {
            console.log(`⚠️ Conflict message: ${conflictCheck.conflictMessage}`);
            if (conflictCheck.conflictItems.length > 0) {
                console.log('⚠️ Conflicting schedules:');
                conflictCheck.conflictItems.forEach(item => console.log(`  ${item}`));
            }
        }
        
        // Take screenshot after save attempt
        await page.screenshot({ path: '/opt/pisignage/tests/screenshots/scheduler-after-save.png' });
        console.log('✅ Screenshot saved: scheduler-after-save.png');
        
        // Check if schedule was created
        console.log('\nSTEP 7: Verify schedule creation');
        console.log('=========================================');
        
        const newSchedules = await page.evaluate(async () => {
            const response = await fetch('/api/schedule.php');
            const data = await response.json();
            return data;
        });
        
        console.log(`✅ New schedule count: ${newSchedules.count}`);
        
        if (newSchedules.data && newSchedules.data.length > 0) {
            console.log('\n📊 Current schedules:');
            newSchedules.data.forEach(s => {
                console.log(`  - ${s.name}: ${s.schedule.start_time}-${s.schedule.end_time}`);
            });
        }
        
        console.log('\nSTEP 8: Summary');
        console.log('=========================================');
        
        if (!conflictCheck.conflictVisible && newSchedules.count > 0) {
            console.log('✅✅✅ SUCCESS: Schedule created without conflicts!');
        } else if (conflictCheck.conflictVisible) {
            console.log('⚠️⚠️⚠️ ISSUE: Conflict modal appeared - needs investigation');
        } else {
            console.log('❌❌❌ FAILURE: Schedule not created and no conflict shown');
        }
        
        console.log('\n📋 Console logs captured:');
        const errorLogs = consoleLogs.filter(log => 
            log.includes('Error') || log.includes('error') || log.includes('failed')
        );
        if (errorLogs.length > 0) {
            errorLogs.forEach(log => console.log(`  ⚠️ ${log}`));
        } else {
            console.log('  ✅ No errors in console');
        }
        
    } catch (error) {
        console.error('\n❌ TEST FAILED:', error.message);
        console.error(error.stack);
        
        await page.screenshot({ path: '/opt/pisignage/tests/screenshots/scheduler-error.png' });
        console.log('📸 Error screenshot saved');
    } finally {
        await browser.close();
    }
}

runTests();
