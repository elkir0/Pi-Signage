const puppeteer = require('puppeteer');

(async () => {
    console.log('🔍 DEBUG MODAL EDIT PLAYLIST\n');

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture console logs
    page.on('console', msg => {
        console.log('Console: ' + msg.text());
    });

    // Monitor network
    page.on('response', response => {
        if (response.url().includes('/api/playlist.php')) {
            response.text().then(text => {
                console.log('API Response: ' + text);
            });
        }
    });

    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });

    // Go to playlists
    await page.evaluate(() => showSection('playlists'));
    await new Promise(r => setTimeout(r, 1000));

    // Get playlist name and try to edit
    const playlistName = await page.evaluate(() => {
        const editBtn = document.querySelector('button[onclick*="editPlaylist"]');
        if (editBtn) {
            const onclick = editBtn.getAttribute('onclick');
            const match = onclick.match(/editPlaylist\('(.+?)'\)/);
            return match ? match[1] : null;
        }
        return null;
    });

    if (playlistName) {
        console.log('Trying to edit playlist: ' + playlistName);

        // Call editPlaylist directly
        await page.evaluate((name) => {
            if (typeof editPlaylist === 'function') {
                editPlaylist(name);
            }
        }, playlistName);

        // Wait for modal
        await new Promise(r => setTimeout(r, 2000));

        // Check modal
        const modalStatus = await page.evaluate(() => {
            const modal = document.getElementById('editPlaylistModal');
            return modal ? 'Modal created' : 'No modal';
        });

        console.log('Modal status: ' + modalStatus);
    } else {
        console.log('No playlist found to edit');
    }

    await browser.close();
})();
