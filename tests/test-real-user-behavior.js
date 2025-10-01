const puppeteer = require('puppeteer');

(async () => {
    console.log('🔍 TEST: Simulation utilisateur RÉEL (avec GUI visible)\n');
    console.log('Ce test ouvre le modal et attend que tu interagisses...\n');

    const browser = await puppeteer.launch({
        headless: false,  // Mode visible
        slowMo: 500,      // Ralenti pour voir
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--start-maximized']
    });

    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });

    page.on('console', msg => {
        console.log('📋 CONSOLE:', msg.text());
    });

    try {
        console.log('1️⃣ Chargement page...');
        await page.goto('http://192.168.1.105/schedule.php', { waitUntil: 'networkidle2' });
        
        await page.waitForTimeout(3000);
        
        console.log('2️⃣ Ouverture modal...');
        await page.waitForFunction(() => window.PiSignage?.Schedule?.openAddModal);
        await page.evaluate(() => window.PiSignage.Schedule.openAddModal());
        
        await page.waitForTimeout(2000);
        
        console.log('\n📊 ÉTAT INITIAL DU FORMULAIRE:');
        const initialState = await page.evaluate(() => {
            return {
                playlistValue: document.getElementById('schedule-playlist').value,
                playlistOptions: Array.from(document.querySelectorAll('#schedule-playlist option'))
                    .map(o => ({ value: o.value, text: o.textContent })),
                modalVisible: document.getElementById('schedule-modal')?.classList.contains('show')
            };
        });
        
        console.log('   Modal visible:', initialState.modalVisible);
        console.log('   Playlist sélectionnée:', initialState.playlistValue || '(aucune)');
        console.log('   Options disponibles:', initialState.playlistOptions.length);
        
        console.log('\n⏸️ NAVIGATEUR OUVERT - Le modal est affiché');
        console.log('   Tu peux maintenant interagir avec le formulaire');
        console.log('   Appuie sur Entrée ici quand tu as fini...\n');
        
        // Attendre input utilisateur
        await new Promise(resolve => {
            const readline = require('readline');
            const rl = readline.createInterface({
                input: process.stdin,
                output: process.stdout
            });
            rl.question('Appuie sur Entrée pour continuer...', () => {
                rl.close();
                resolve();
            });
        });
        
        console.log('\n📊 ÉTAT FINAL DU FORMULAIRE:');
        const finalState = await page.evaluate(() => {
            return {
                name: document.getElementById('schedule-name').value,
                playlist: document.getElementById('schedule-playlist').value,
                startTime: document.getElementById('schedule-start-time').value,
                endTime: document.getElementById('schedule-end-time').value,
                conflictModalVisible: document.getElementById('conflict-modal')?.classList.contains('show'),
                scheduleModalVisible: document.getElementById('schedule-modal')?.classList.contains('show')
            };
        });
        
        console.log(JSON.stringify(finalState, null, 2));
        
        if (finalState.conflictModalVisible) {
            console.log('\n⚠️ MODAL CONFLIT EST VISIBLE!');
            
            const conflictInfo = await page.evaluate(() => {
                return {
                    message: document.getElementById('conflict-message')?.textContent,
                    list: document.getElementById('conflict-list')?.innerHTML
                };
            });
            
            console.log('Message:', conflictInfo.message);
            console.log('Liste:', conflictInfo.list?.substring(0, 300));
        }
        
    } catch (error) {
        console.error('❌ Erreur:', error.message);
    }
    
    console.log('\nAppuie sur Entrée pour fermer le navigateur...');
    await new Promise(resolve => {
        const readline = require('readline');
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });
        rl.question('', () => {
            rl.close();
            resolve();
        });
    });
    
    await browser.close();
})();
