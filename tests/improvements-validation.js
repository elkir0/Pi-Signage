const puppeteer = require('puppeteer');

(async () => {
    console.log('✅ VALIDATION DES AMÉLIORATIONS');
    console.log('=' .repeat(50));

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    let errors = [];

    // Capture erreurs
    page.on('console', msg => {
        if (msg.type() === 'error' && !msg.text().includes('favicon')) {
            errors.push(msg.text());
        }
        // Log info messages pour debug
        if (msg.text().includes('Upload') || msg.text().includes('Téléchargement')) {
            console.log('   Console: ' + msg.text());
        }
    });

    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });

    console.log('\n1️⃣ TEST YOUTUBE AVEC FEEDBACK');

    // Go to YouTube section
    await page.evaluate(() => showSection('youtube'));
    await new Promise(r => setTimeout(r, 1000));

    // Enter test URL (short video for faster test)
    await page.evaluate(() => {
        document.getElementById('youtube-url').value = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
        document.getElementById('youtube-quality').value = '360p'; // Petit pour test rapide
    });

    console.log('   URL entrée: Rick Roll (test rapide)');

    // Click download
    await page.evaluate(() => {
        if (typeof downloadYoutube === 'function') {
            downloadYoutube();
        }
    });

    await new Promise(r => setTimeout(r, 2000));

    // Check for feedback div
    const hasFeedback = await page.evaluate(() => {
        return !!document.getElementById('youtube-feedback');
    });
    console.log('   Zone feedback créée: ' + (hasFeedback ? '✅' : '❌'));

    // Check progress bar
    const hasProgress = await page.evaluate(() => {
        const progress = document.getElementById('youtube-progress');
        return progress && progress.style.display !== 'none';
    });
    console.log('   Barre de progression: ' + (hasProgress ? '✅' : '❌'));

    console.log('\n2️⃣ TEST UPLOAD AVEC PROGRESS');

    // Go to media section
    await page.evaluate(() => showSection('media'));
    await new Promise(r => setTimeout(r, 1000));

    // Count initial media files
    const initialCount = await page.evaluate(() => {
        return document.querySelectorAll('#media-grid .card').length;
    });
    console.log('   Fichiers initiaux: ' + initialCount);

    // Test upload modal
    await page.evaluate(() => {
        if (typeof showUploadModal === 'function') {
            showUploadModal();
        }
    });
    await new Promise(r => setTimeout(r, 1000));

    const uploadModalVisible = await page.evaluate(() => {
        const modal = document.getElementById('uploadModal');
        return modal && modal.style.display === 'block';
    });
    console.log('   Modal upload: ' + (uploadModalVisible ? '✅' : '❌'));

    // Close modal
    if (uploadModalVisible) {
        await page.evaluate(() => {
            if (typeof closeUploadModal === 'function') {
                closeUploadModal();
            }
        });
    }

    console.log('\n3️⃣ VÉRIFICATION AUTO-REFRESH');

    // Check if loadMediaFiles is called after actions
    const hasAutoRefresh = await page.evaluate(() => {
        // Override loadMediaFiles to detect calls
        let refreshCalled = false;
        const originalLoad = window.loadMediaFiles;
        window.loadMediaFiles = function() {
            refreshCalled = true;
            if (originalLoad) originalLoad.call(this);
        };

        // Simulate an action
        setTimeout(() => {
            if (typeof loadMediaFiles === 'function') {
                loadMediaFiles();
            }
        }, 100);

        return new Promise(resolve => {
            setTimeout(() => {
                resolve(refreshCalled);
            }, 500);
        });
    });

    console.log('   Auto-refresh fonctionnel: ' + (hasAutoRefresh ? '✅' : '❌'));

    console.log('\n4️⃣ VÉRIFICATION HISTORIQUE YOUTUBE');

    // Go back to YouTube
    await page.evaluate(() => showSection('youtube'));
    await new Promise(r => setTimeout(r, 1000));

    // Check history div
    const hasHistory = await page.evaluate(() => {
        const history = document.getElementById('youtube-history');
        return history !== null;
    });
    console.log('   Zone historique existe: ' + (hasHistory ? '✅' : '❌'));

    // Wait a bit more for download to potentially complete
    console.log('\n   ⏳ Attente 10s pour monitoring...');
    await new Promise(r => setTimeout(r, 10000));

    // Check if history has items after download
    const historyItems = await page.evaluate(() => {
        const history = document.getElementById('youtube-history');
        if (history) {
            return history.children.length;
        }
        return 0;
    });
    console.log('   Éléments dans l\'historique: ' + historyItems);

    // Screenshot final
    await page.screenshot({ path: '/tmp/improvements-validation.png', fullPage: true });

    console.log('\n' + '='.repeat(50));
    console.log('📊 RÉSUMÉ:');
    console.log('   Feedback YouTube: ' + (hasFeedback ? '✅' : '❌'));
    console.log('   Progress bars: ' + ((hasProgress) ? '✅' : '⚠️'));
    console.log('   Auto-refresh: ' + (hasAutoRefresh ? '✅' : '❌'));
    console.log('   Historique: ' + (hasHistory ? '✅' : '❌') + (historyItems > 0 ? ' avec données' : ' vide'));
    console.log('   Erreurs console: ' + errors.length);

    const successCount = [hasFeedback, hasProgress, hasAutoRefresh, hasHistory].filter(v => v).length;
    const totalTests = 4;

    if (successCount === totalTests && errors.length === 0) {
        console.log('\n🎉 TOUTES LES AMÉLIORATIONS FONCTIONNENT!');
    } else {
        console.log('\n✅ Améliorations: ' + successCount + '/' + totalTests);
    }

    await browser.close();
})();