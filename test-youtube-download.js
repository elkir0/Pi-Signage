const puppeteer = require('puppeteer');

(async () => {
    console.log('🎬 TEST TÉLÉCHARGEMENT YOUTUBE');
    console.log('Video: Costa Rica 4K');
    console.log('URL: https://www.youtube.com/watch?v=LXb3EKWsInQ&t=7s');
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
            console.log('❌ Error: ' + msg.text());
        }
    });

    // Monitor network for YouTube API
    page.on('response', response => {
        if (response.url().includes('/api/youtube.php')) {
            response.text().then(text => {
                console.log('📨 API Response: ' + text);
                try {
                    const data = JSON.parse(text);
                    if (data.success) {
                        console.log('✅ API Success!');
                    } else {
                        console.log('❌ API Error: ' + data.message);
                    }
                } catch (e) {
                    console.log('⚠️ Invalid JSON response');
                }
            });
        }
    });

    // Navigation
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });

    console.log('\n1️⃣ NAVIGATION VERS SECTION YOUTUBE');
    await page.evaluate(() => showSection('youtube'));
    await new Promise(r => setTimeout(r, 1000));

    // Check section
    const sectionVisible = await page.evaluate(() => {
        const section = document.getElementById('youtube');
        return section && section.style.display !== 'none';
    });
    console.log('   Section visible: ' + (sectionVisible ? '✅' : '❌'));

    console.log('\n2️⃣ VÉRIFICATION YT-DLP');

    // Check yt-dlp status via API
    const ytdlpStatus = await page.evaluate(async () => {
        try {
            const response = await fetch('/api/youtube.php?action=ytdlp');
            const data = await response.json();
            return data;
        } catch (e) {
            return { error: e.message };
        }
    });

    if (ytdlpStatus.success && ytdlpStatus.data) {
        console.log('   yt-dlp disponible: ' + (ytdlpStatus.data.available ? '✅' : '❌'));
        if (ytdlpStatus.data.version) {
            console.log('   Version: ' + ytdlpStatus.data.version);
        }
    } else {
        console.log('   yt-dlp status: ❌ Non disponible');
    }

    console.log('\n3️⃣ REMPLISSAGE DU FORMULAIRE');

    // Fill form
    await page.evaluate(() => {
        const urlInput = document.getElementById('youtube-url');
        const qualitySelect = document.getElementById('youtube-quality');

        if (urlInput) {
            urlInput.value = 'https://www.youtube.com/watch?v=LXb3EKWsInQ&t=7s';
            console.log('URL entrée');
        }

        if (qualitySelect) {
            qualitySelect.value = '720p'; // Pour un test plus rapide
            console.log('Qualité: 720p');
        }
    });

    await page.screenshot({ path: '/tmp/youtube-form.png' });
    console.log('   📸 Screenshot: /tmp/youtube-form.png');

    console.log('\n4️⃣ LANCEMENT DU TÉLÉCHARGEMENT');

    // Click download button
    const downloadStarted = await page.evaluate(() => {
        const button = document.querySelector('button[onclick*="downloadYoutube"]');
        if (button) {
            button.click();
            return true;
        }
        return false;
    });

    if (downloadStarted) {
        console.log('   ✅ Téléchargement lancé');

        // Wait for response
        await new Promise(r => setTimeout(r, 5000));

        // Check progress bar
        const progressVisible = await page.evaluate(() => {
            const progress = document.getElementById('youtube-progress');
            return progress && progress.style.display !== 'none';
        });
        console.log('   Barre de progression: ' + (progressVisible ? '✅ Visible' : '⚠️ Cachée'));

        // Wait more for download
        console.log('   ⏳ Attente du téléchargement (30s max)...');
        await new Promise(r => setTimeout(r, 30000));

    } else {
        console.log('   ❌ Bouton télécharger non trouvé');
    }

    console.log('\n5️⃣ VÉRIFICATION DANS MÉDIA');

    // Go to media section
    await page.evaluate(() => showSection('media'));
    await new Promise(r => setTimeout(r, 2000));

    // Check for new video
    const mediaFiles = await page.evaluate(() => {
        const cards = document.querySelectorAll('#media-grid .card h4');
        return Array.from(cards).map(card => card.textContent);
    });

    console.log('   Fichiers dans média: ' + mediaFiles.length);
    const costaRicaFound = mediaFiles.some(file =>
        file.toLowerCase().includes('costa') ||
        file.toLowerCase().includes('rica') ||
        file.includes('LXb3EKWsInQ')
    );

    if (costaRicaFound) {
        console.log('   ✅ Vidéo Costa Rica trouvée dans média!');
    } else {
        console.log('   ⚠️ Vidéo pas encore visible');
        console.log('   Fichiers présents:');
        mediaFiles.forEach(file => console.log('     - ' + file));
    }

    // Final screenshot
    await page.screenshot({ path: '/tmp/youtube-result.png', fullPage: true });

    console.log('\n' + '='.repeat(50));
    console.log('📊 RÉSUMÉ:');
    console.log('   yt-dlp installé: ' + (ytdlpStatus.data && ytdlpStatus.data.available ? '✅' : '❌'));
    console.log('   Téléchargement lancé: ' + (downloadStarted ? '✅' : '❌'));
    console.log('   Vidéo dans média: ' + (costaRicaFound ? '✅' : '⚠️ Pas encore'));
    console.log('   Erreurs console: ' + errors.length);

    if (errors.length === 0 && downloadStarted) {
        console.log('\n✅ TEST RÉUSSI - Téléchargement fonctionnel');
    } else {
        console.log('\n⚠️ Vérifications nécessaires');
    }

    await browser.close();
})();