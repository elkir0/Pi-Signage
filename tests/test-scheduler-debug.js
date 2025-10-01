const puppeteer = require('puppeteer');

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

(async () => {
    console.log('🧪 Debugging Scheduler Conflict Issue...\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    try {
        console.log('1️⃣ Loading page and checking existing schedules...');
        await page.goto('http://192.168.1.105/schedule.php', { waitUntil: 'networkidle2' });
        await sleep(2000);
        
        // Get existing schedules from API
        const existingSchedules = await page.evaluate(async () => {
            const response = await fetch('/api/schedule.php');
            const data = await response.json();
            return data.data || [];
        });
        
        console.log('   📊 Existing schedules:', existingSchedules.length);
        existingSchedules.forEach(s => {
            console.log(`     - ID: ${s.id}`);
            console.log(`       Name: ${s.name}`);
            console.log(`       Time: ${s.schedule.start_time} - ${s.schedule.end_time}`);
            console.log(`       Enabled: ${s.enabled}`);
            console.log(`       Recurrence: ${s.schedule.recurrence.type}`);
            console.log('');
        });
        
        if (existingSchedules.length > 0) {
            console.log('2️⃣ Deleting test schedules to avoid conflicts...');
            
            for (const schedule of existingSchedules) {
                if (schedule.name.includes('Test') || schedule.name.includes('Puppeteer')) {
                    console.log(`   🗑️ Deleting: ${schedule.name}`);
                    
                    const deleted = await page.evaluate(async (id) => {
                        const response = await fetch(`/api/schedule.php/${id}`, {
                            method: 'DELETE'
                        });
                        const result = await response.json();
                        return result.success;
                    }, schedule.id);
                    
                    console.log(`     Result: ${deleted ? '✅' : '❌'}`);
                }
            }
            
            await sleep(1000);
        }
        
        console.log('\n3️⃣ Creating new schedule via API (no conflict expected)...');
        
        const newSchedule = await page.evaluate(async () => {
            const scheduleData = {
                name: "Puppeteer Test Clean",
                description: "Test without conflict",
                playlist: "TEST",
                enabled: false,
                priority: 1,
                schedule: {
                    type: "recurring",
                    start_time: "14:00",
                    end_time: "15:00",
                    continuous: false,
                    once_only: false,
                    recurrence: {
                        type: "weekly",
                        days: [1, 3, 5],
                        no_end_date: true
                    }
                },
                conflict_behavior: "ignore",
                post_actions: {
                    revert_default: true,
                    stop_playback: false,
                    take_screenshot: false
                }
            };
            
            const response = await fetch('/api/schedule.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(scheduleData)
            });
            
            const result = await response.json();
            return result;
        });
        
        console.log('   API Response:', newSchedule.success ? '✅' : '❌');
        if (!newSchedule.success) {
            console.log('   Error:', newSchedule.message);
            if (newSchedule.conflicts) {
                console.log('   Conflicts:', newSchedule.conflicts);
            }
        } else {
            console.log('   Schedule created:', newSchedule.data.id);
        }
        
        console.log('\n4️⃣ Reloading page to test UI...');
        await page.reload({ waitUntil: 'networkidle2' });
        await sleep(2000);
        
        console.log('5️⃣ Opening modal and testing form...');
        await page.click('button.btn-primary');
        await sleep(1000);
        
        const modalShown = await page.$eval('#schedule-modal', el => el.classList.contains('show'));
        console.log('   Modal visible:', modalShown ? '✅' : '❌');
        
        if (modalShown) {
            // Fill form with DIFFERENT time to avoid conflict
            await page.type('#schedule-name', 'Test UI No Conflict');
            
            const playlists = await page.$$eval('#schedule-playlist option', opts => 
                opts.filter(o => o.value).map(o => o.value)
            );
            
            if (playlists.length > 0) {
                await page.select('#schedule-playlist', playlists[0]);
            }
            
            await page.type('#schedule-start-time', '16:00');  // Different time
            await page.type('#schedule-end-time', '17:00');
            
            console.log('6️⃣ Clicking save button...');
            await page.click('button.btn-success');  // "Sauvegarder & Activer"
            await sleep(2000);
            
            // Check for conflict modal
            const conflictShown = await page.evaluate(() => {
                const modal = document.getElementById('conflict-modal');
                return modal && modal.classList.contains('show');
            });
            
            console.log('   Conflict modal:', conflictShown ? '⚠️ SHOWN' : '✅ NOT SHOWN');
            
            if (conflictShown) {
                const message = await page.$eval('#conflict-message', el => el.textContent);
                console.log('   Message:', message);
                
                const conflicts = await page.$$eval('.conflict-item', items => 
                    items.map(item => item.textContent.trim())
                );
                
                console.log('   Conflicts:');
                conflicts.forEach(c => console.log('     -', c));
            } else {
                console.log('   ✅ Schedule created successfully via UI!');
            }
        }
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        console.error(error.stack);
    } finally {
        await browser.close();
    }
})();
