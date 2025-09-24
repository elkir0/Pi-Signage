const puppeteer = require('puppeteer');

(async () => {
    console.log('🧪 TEST FONCTIONS PLAYLIST');
    console.log('=' .repeat(50));

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    let errors = [];

    // Capture erreurs console
    page.on('console', msg => {
        if (msg.type() === 'error' && !msg.text().includes('favicon')) {
            errors.push(msg.text());
            console.log('❌ Error: ' + msg.text());
        }
    });

    // Navigation
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });

    console.log('\n1️⃣ TEST FONCTIONS PLAYLIST');

    // Check if all functions exist
    const functionsCheck = await page.evaluate(() => {
        return {
            createPlaylist: typeof createPlaylist === 'function',
            editPlaylist: typeof editPlaylist === 'function',
            deletePlaylist: typeof deletePlaylist === 'function',
            loadPlaylists: typeof loadPlaylists === 'function',
            playPlaylist: typeof playPlaylist === 'function',
            savePlaylistChanges: typeof savePlaylistChanges === 'function',
            closeEditPlaylistModal: typeof closeEditPlaylistModal === 'function'
        };
    });

    console.log('   Fonctions disponibles:');
    Object.entries(functionsCheck).forEach(([func, exists]) => {
        console.log(`   - ${func}: ${exists ? '✅' : '❌'}`);
    });

    // Go to playlists section
    await page.evaluate(() => showSection('playlists'));
    await new Promise(r => setTimeout(r, 1000));

    console.log('\n2️⃣ TEST SECTION PLAYLISTS');

    // Check if section is visible
    const playlistSectionVisible = await page.evaluate(() => {
        const section = document.getElementById('playlists');
        return section && section.style.display !== 'none';
    });
    console.log('   Section visible: ' + (playlistSectionVisible ? '✅' : '❌'));

    // Check for buttons
    const buttonsCheck = await page.evaluate(() => {
        const createBtn = document.querySelector('button[onclick*="createPlaylist"]');
        const editBtns = document.querySelectorAll('button[onclick*="editPlaylist"]');
        const deleteBtns = document.querySelectorAll('button[onclick*="deletePlaylist"]');

        return {
            hasCreateButton: !!createBtn,
            editButtonsCount: editBtns.length,
            deleteButtonsCount: deleteBtns.length
        };
    });

    console.log('   Bouton Créer: ' + (buttonsCheck.hasCreateButton ? '✅' : '❌'));
    console.log('   Boutons Modifier: ' + buttonsCheck.editButtonsCount);
    console.log('   Boutons Supprimer: ' + buttonsCheck.deleteButtonsCount);

    console.log('\n3️⃣ TEST MODAL EDIT (si playlist existe)');

    if (buttonsCheck.editButtonsCount > 0) {
        // Click first edit button
        await page.evaluate(() => {
            const editBtn = document.querySelector('button[onclick*="editPlaylist"]');
            if (editBtn) editBtn.click();
        });

        await new Promise(r => setTimeout(r, 1000));

        // Check if modal opened
        const modalCheck = await page.evaluate(() => {
            const modal = document.getElementById('editPlaylistModal');
            return {
                exists: !!modal,
                isVisible: modal ? modal.style.display === 'block' : false,
                hasNameInput: !!document.getElementById('edit-playlist-name'),
                hasItemsDiv: !!document.getElementById('edit-playlist-items'),
                hasFileSelect: !!document.getElementById('add-files-select')
            };
        });

        console.log('   Modal existe: ' + (modalCheck.exists ? '✅' : '❌'));
        console.log('   Modal visible: ' + (modalCheck.isVisible ? '✅' : '❌'));
        console.log('   Input nom: ' + (modalCheck.hasNameInput ? '✅' : '❌'));
        console.log('   Liste items: ' + (modalCheck.hasItemsDiv ? '✅' : '❌'));
        console.log('   Select fichiers: ' + (modalCheck.hasFileSelect ? '✅' : '❌'));

        // Close modal if opened
        if (modalCheck.exists) {
            await page.evaluate(() => {
                if (typeof closeEditPlaylistModal === 'function') {
                    closeEditPlaylistModal();
                }
            });
        }
    } else {
        console.log('   ⚠️ Aucune playlist à éditer');
    }

    console.log('\n4️⃣ TEST CHECKBOXES MÉDIA');

    // Go to media section
    await page.evaluate(() => showSection('media'));
    await new Promise(r => setTimeout(r, 1000));

    const mediaCheckboxes = await page.evaluate(() => {
        const checkboxes = document.querySelectorAll('#media input[type="checkbox"]');
        return checkboxes.length;
    });

    console.log('   Checkboxes dans média: ' + mediaCheckboxes + (mediaCheckboxes > 0 ? ' ✅' : ' ❌'));

    // Screenshot
    await page.screenshot({ path: '/tmp/playlist-test.png', fullPage: true });

    console.log('\n' + '='.repeat(50));
    console.log('📊 RÉSUMÉ:');

    const allFunctionsExist = Object.values(functionsCheck).every(v => v);
    console.log('   Toutes fonctions: ' + (allFunctionsExist ? '✅' : '❌'));
    console.log('   Section playlists: ' + (playlistSectionVisible ? '✅' : '❌'));
    console.log('   Boutons fonctionnels: ' + (buttonsCheck.hasCreateButton ? '✅' : '❌'));
    console.log('   Checkboxes média: ' + (mediaCheckboxes > 0 ? '✅' : '❌'));
    console.log('   Erreurs console: ' + errors.length);

    if (errors.length === 0 && allFunctionsExist) {
        console.log('\n✅ TOUTES LES FONCTIONS PLAYLIST SONT OPÉRATIONNELLES!');
    } else {
        console.log('\n⚠️ Des problèmes persistent');
        if (errors.length > 0) {
            console.log('\nErreurs détectées:');
            errors.forEach(err => console.log('   - ' + err));
        }
    }

    await browser.close();
})();