const puppeteer = require('puppeteer');

(async () => {
    console.log('🧪 Testing Scheduler Module...\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // Enable console logging
    page.on('console', msg => {
        const text = msg.text();
        if (text.includes('error') || text.includes('Error') || text.includes('Loaded')) {
            console.log('📋 Console:', text);
        }
    });
    
    try {
        console.log('1️⃣ Loading schedule page...');
        await page.goto('http://192.168.1.105/schedule.php', {
            waitUntil: 'networkidle2',
            timeout: 30000
        });
        
        await page.waitForTimeout(2000);
        
        console.log('2️⃣ Checking if playlists loaded...');
        const playlistsLoaded = await page.evaluate(() => {
            return window.PiSignage && 
                   window.PiSignage.Schedule && 
                   window.PiSignage.Schedule.playlists && 
                   window.PiSignage.Schedule.playlists.length > 0;
        });
        
        console.log('   Playlists loaded:', playlistsLoaded ? '✅' : '❌');
        
        if (playlistsLoaded) {
            const count = await page.evaluate(() => window.PiSignage.Schedule.playlists.length);
            console.log('   Playlist count:', count);
        }
        
        console.log('3️⃣ Opening modal...');
        await page.click('button.btn-primary');
        await page.waitForTimeout(1000);
        
        const modalVisible = await page.evaluate(() => {
            const modal = document.getElementById('schedule-modal');
            return modal && modal.classList.contains('show');
        });
        
        console.log('   Modal visible:', modalVisible ? '✅' : '❌');
        
        if (modalVisible) {
            console.log('4️⃣ Checking playlist dropdown...');
            const options = await page.$$eval('#schedule-playlist option', opts => 
                opts.map(o => ({ value: o.value, text: o.textContent }))
            );
            
            console.log('   Dropdown options:', options.length);
            options.forEach(opt => console.log('     -', opt.text));
            
            console.log('5️⃣ Filling form...');
            await page.type('#schedule-name', 'Test Puppeteer');
            
            if (options.length > 1) {
                await page.select('#schedule-playlist', options[1].value);
                console.log('   Selected playlist:', options[1].text);
            }
            
            await page.type('#schedule-start-time', '09:00');
            await page.type('#schedule-end-time', '10:00');
            
            console.log('6️⃣ Attempting to save...');
            
            // Check for existing schedules
            const existingSchedules = await page.evaluate(() => {
                return fetch('/api/schedule.php')
                    .then(r => r.json())
                    .then(d => d.data || []);
            });
            
            console.log('   Existing schedules:', existingSchedules.length);
            
            if (existingSchedules.length > 0) {
                console.log('   ⚠️ Found existing schedules - potential conflict:');
                existingSchedules.forEach(s => {
                    console.log(`     - ${s.name}: ${s.schedule.start_time}-${s.schedule.end_time}`);
                });
            }
            
            // Try to save
            await page.click('button.btn-primary:not(.btn-glass)');
            await page.waitForTimeout(2000);
            
            // Check if conflict modal appeared
            const conflictModal = await page.evaluate(() => {
                const modal = document.getElementById('conflict-modal');
                return modal && modal.classList.contains('show');
            });
            
            console.log('   Conflict modal shown:', conflictModal ? '⚠️ YES' : '✅ NO');
            
            if (conflictModal) {
                const conflictMsg = await page.$eval('#conflict-message', el => el.textContent);
                console.log('   Conflict message:', conflictMsg);
            }
        }
        
    } catch (error) {
        console.error('❌ Test error:', error.message);
    } finally {
        await browser.close();
    }
})();
