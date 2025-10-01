const puppeteer = require('puppeteer');

(async () => {
    console.log('🧪 Testing Modal Open Issue\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    page.on('console', msg => console.log('  📋', msg.text()));
    page.on('pageerror', error => console.log('  ❌ Page error:', error.message));
    
    try {
        console.log('Loading page...');
        await page.goto('http://192.168.1.105/schedule.php', {
            waitUntil: 'networkidle2',
            timeout: 30000
        });
        
        await page.evaluate(() => new Promise(resolve => setTimeout(resolve, 3000)));
        
        console.log('\n1️⃣ Checking if openAddModal function exists...');
        const funcCheck = await page.evaluate(() => {
            return {
                hasPiSignage: typeof window.PiSignage !== 'undefined',
                hasSchedule: typeof window.PiSignage?.Schedule !== 'undefined',
                hasOpenAddModal: typeof window.PiSignage?.Schedule?.openAddModal === 'function'
            };
        });
        
        console.log('   PiSignage:', funcCheck.hasPiSignage ? '✅' : '❌');
        console.log('   Schedule:', funcCheck.hasSchedule ? '✅' : '❌');
        console.log('   openAddModal:', funcCheck.hasOpenAddModal ? '✅' : '❌');
        
        if (!funcCheck.hasOpenAddModal) {
            console.log('\n❌ openAddModal function NOT FOUND!');
            console.log('   Available Schedule functions:');
            const funcs = await page.evaluate(() => {
                return Object.keys(window.PiSignage?.Schedule || {});
            });
            funcs.forEach(f => console.log('     -', f));
            
            await browser.close();
            return;
        }
        
        console.log('\n2️⃣ Calling openAddModal() via evaluate...');
        const result = await page.evaluate(() => {
            try {
                window.PiSignage.Schedule.openAddModal();
                return { success: true };
            } catch (error) {
                return { success: false, error: error.message };
            }
        });
        
        console.log('   Function called:', result.success ? '✅' : '❌');
        if (!result.success) {
            console.log('   Error:', result.error);
        }
        
        await page.evaluate(() => new Promise(resolve => setTimeout(resolve, 1000)));
        
        console.log('\n3️⃣ Checking modal state...');
        const modalState = await page.evaluate(() => {
            const modal = document.getElementById('schedule-modal');
            return {
                exists: !!modal,
                classes: modal?.className || '',
                display: modal ? window.getComputedStyle(modal).display : '',
                visible: modal?.classList.contains('show')
            };
        });
        
        console.log('   Modal exists:', modalState.exists ? '✅' : '❌');
        console.log('   Classes:', modalState.classes);
        console.log('   Display:', modalState.display);
        console.log('   Has "show" class:', modalState.visible ? '✅' : '❌');
        
        console.log('\n4️⃣ Trying to click button directly...');
        const btnExists = await page.$('button.btn-primary');
        console.log('   Button exists:', btnExists ? '✅' : '❌');
        
        if (btnExists) {
            await btnExists.click();
            await page.evaluate(() => new Promise(resolve => setTimeout(resolve, 1500)));
            
            const modalAfterClick = await page.evaluate(() => {
                const modal = document.getElementById('schedule-modal');
                return modal?.classList.contains('show');
            });
            
            console.log('   Modal visible after click:', modalAfterClick ? '✅' : '❌');
        }
        
    } catch (error) {
        console.error('\n❌ Error:', error.message);
    } finally {
        await browser.close();
    }
})();
