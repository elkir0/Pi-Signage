const puppeteer = require('puppeteer');

(async () => {
    console.log('🔍 DEBUG: Pourquoi "Conflit détecté" apparaît immédiatement\n');
    
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // Capture TOUTES les erreurs console
    const consoleMessages = [];
    page.on('console', msg => {
        const text = msg.text();
        consoleMessages.push(text);
        console.log('  📋', text);
    });
    
    try {
        console.log('1️⃣ Chargement de la page...\n');
        await page.goto('http://192.168.1.105/schedule.php', {
            waitUntil: 'networkidle2',
            timeout: 30000
        });
        
        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));
        
        // Screenshot initial
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/01-page-loaded.png',
            fullPage: true 
        });
        console.log('\n📸 Screenshot 1: Page chargée\n');
        
        console.log('2️⃣ Vérification base de données schedules...\n');
        const existingSchedules = await page.evaluate(() => {
            return fetch('/api/schedule.php')
                .then(r => r.json())
                .catch(e => ({ error: e.message }));
        });
        
        console.log('   Schedules existants:', JSON.stringify(existingSchedules, null, 2));
        
        console.log('\n3️⃣ Attente du module Schedule...\n');
        await page.waitForFunction(() => {
            return window.PiSignage?.Schedule?.openAddModal !== undefined;
        }, { timeout: 10000 });
        
        console.log('   ✅ Module Schedule chargé');
        
        console.log('\n4️⃣ Ouverture du modal "Nouveau Planning"...\n');
        await page.evaluate(() => {
            window.PiSignage.Schedule.openAddModal();
        });
        
        await page.evaluate(() => new Promise(r => setTimeout(r, 1500)));
        
        // Screenshot modal ouvert
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/02-modal-opened.png',
            fullPage: true 
        });
        console.log('📸 Screenshot 2: Modal ouvert\n');
        
        // Vérifier si modal de conflit est déjà visible
        const conflictModalInitial = await page.evaluate(() => {
            const modal = document.getElementById('conflict-modal');
            return {
                exists: !!modal,
                visible: modal?.classList.contains('show'),
                html: modal?.outerHTML.substring(0, 500)
            };
        });
        
        console.log('   Modal conflit AVANT remplissage:', conflictModalInitial.visible ? '⚠️ VISIBLE' : '✅ Caché');
        
        if (conflictModalInitial.visible) {
            console.log('   ❌❌❌ PROBLÈME: Modal conflit déjà visible AVANT même de remplir le formulaire!\n');
            
            const conflictDetails = await page.evaluate(() => {
                return {
                    message: document.getElementById('conflict-message')?.textContent,
                    list: document.getElementById('conflict-list')?.innerHTML
                };
            });
            
            console.log('   Message conflit:', conflictDetails.message);
            console.log('   Liste conflits:', conflictDetails.list?.substring(0, 300));
            
            await page.screenshot({ 
                path: '/opt/pisignage/tests/screenshots/03-conflict-already-shown.png',
                fullPage: true 
            });
            console.log('📸 Screenshot 3: Conflit déjà affiché\n');
            
            await browser.close();
            return;
        }
        
        console.log('\n5️⃣ Remplissage du formulaire...\n');
        
        const formCheck = await page.evaluate(() => {
            return {
                nameExists: !!document.getElementById('schedule-name'),
                playlistExists: !!document.getElementById('schedule-playlist'),
                startExists: !!document.getElementById('schedule-start-time'),
                endExists: !!document.getElementById('schedule-end-time'),
                playlistOptions: Array.from(document.querySelectorAll('#schedule-playlist option'))
                    .filter(o => o.value)
                    .map(o => ({ value: o.value, text: o.textContent }))
            };
        });
        
        console.log('   Champs formulaire:', {
            name: formCheck.nameExists,
            playlist: formCheck.playlistExists,
            start: formCheck.startExists,
            end: formCheck.endExists
        });
        console.log('   Playlists disponibles:', formCheck.playlistOptions.length);
        
        if (formCheck.playlistOptions.length === 0) {
            console.log('   ❌ AUCUNE PLAYLIST DISPONIBLE!\n');
            await browser.close();
            return;
        }
        
        await page.evaluate((playlist) => {
            document.getElementById('schedule-name').value = 'Test Debug Conflit';
            document.getElementById('schedule-playlist').value = playlist;
            document.getElementById('schedule-start-time').value = '14:00';
            document.getElementById('schedule-end-time').value = '15:00';
        }, formCheck.playlistOptions[0].value);
        
        console.log('   ✅ Formulaire rempli');
        console.log('   Playlist:', formCheck.playlistOptions[0].text);
        console.log('   Horaire: 14:00 - 15:00\n');
        
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/04-form-filled.png',
            fullPage: true 
        });
        console.log('📸 Screenshot 4: Formulaire rempli\n');
        
        console.log('6️⃣ Click sur "Sauvegarder"...\n');
        await page.evaluate(() => {
            document.querySelector('.modal-footer button.btn-primary').click();
        });
        
        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));
        
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/05-after-save.png',
            fullPage: true 
        });
        console.log('📸 Screenshot 5: Après click sauvegarder\n');
        
        const finalCheck = await page.evaluate(() => {
            const conflictModal = document.getElementById('conflict-modal');
            const scheduleModal = document.getElementById('schedule-modal');
            
            return {
                conflictVisible: conflictModal?.classList.contains('show'),
                scheduleVisible: scheduleModal?.classList.contains('show'),
                conflictMessage: document.getElementById('conflict-message')?.textContent,
                conflictList: document.getElementById('conflict-list')?.innerHTML
            };
        });
        
        console.log('\n7️⃣ RÉSULTAT FINAL:\n');
        console.log('   Modal conflit:', finalCheck.conflictVisible ? '⚠️ VISIBLE' : '✅ Caché');
        console.log('   Modal planning:', finalCheck.scheduleVisible ? '⚠️ Encore ouvert' : '✅ Fermé');
        
        if (finalCheck.conflictVisible) {
            console.log('\n   ❌❌❌ CONFLIT DÉTECTÉ');
            console.log('   Message:', finalCheck.conflictMessage);
            console.log('   Détails:', finalCheck.conflictList?.replace(/<[^>]*>/g, ' ').trim().substring(0, 200));
        } else {
            console.log('\n   ✅✅✅ PAS DE CONFLIT - Schedule créé avec succès!');
        }
        
        console.log('\n8️⃣ Vérification API finale...\n');
        const finalSchedules = await page.evaluate(() => {
            return fetch('/api/schedule.php').then(r => r.json());
        });
        
        console.log('   Total schedules:', finalSchedules.count);
        if (finalSchedules.data) {
            finalSchedules.data.forEach(s => {
                console.log(`   - "${s.name}": ${s.schedule.start_time}-${s.schedule.end_time} (${s.enabled ? 'actif' : 'inactif'})`);
            });
        }
        
        console.log('\n📊 MESSAGES CONSOLE CAPTURÉS:\n');
        const errors = consoleMessages.filter(m => 
            m.includes('error') || m.includes('Error') || m.includes('conflit') || m.includes('Alert')
        );
        
        if (errors.length > 0) {
            console.log('   Erreurs trouvées:');
            errors.forEach(e => console.log('   ⚠️', e));
        } else {
            console.log('   ✅ Aucune erreur');
        }
        
        console.log('\n📸 Screenshots sauvegardés dans /opt/pisignage/tests/screenshots/\n');
        
    } catch (error) {
        console.error('\n❌ ERREUR TEST:', error.message);
        console.error(error.stack);
        
        await page.screenshot({ 
            path: '/opt/pisignage/tests/screenshots/error.png',
            fullPage: true 
        });
    } finally {
        await browser.close();
    }
})();
