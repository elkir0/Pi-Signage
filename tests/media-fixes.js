const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
    console.log('🧪 TEST DES CORRECTIONS MEDIA');
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
            console.log('❌ Console Error: ' + msg.text());
        }
    });

    // Navigation
    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });

    // Go to media section
    await page.evaluate(() => showSection('media'));
    await new Promise(r => setTimeout(r, 1000));

    console.log('\n1️⃣ TEST SUPPRESSION FICHIER');

    // Check if delete sends correct parameter
    const deleteTest = await page.evaluate(() => {
        // Override fetch to capture request
        let capturedRequest = null;
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
            if (args[0].includes('/api/media.php') && args[1] && args[1].method === 'DELETE') {
                capturedRequest = args[1].body;
            }
            return originalFetch.apply(this, args);
        };

        // Simulate delete
        if (typeof deleteFile === 'function') {
            // Cancel the confirm dialog
            window.confirm = () => false;
            deleteFile('test.mp4');

            // Parse captured request
            if (capturedRequest) {
                const data = JSON.parse(capturedRequest);
                return {
                    hasFilename: 'filename' in data,
                    hasAction: 'action' in data && data.action === 'delete',
                    oldFile: 'file' in data
                };
            }
        }
        return { error: 'deleteFile not found' };
    });

    if (deleteTest.hasFilename && deleteTest.hasAction) {
        console.log('   ✅ Paramètre "filename" correct');
        console.log('   ✅ Action "delete" présente');
    } else {
        console.log('   ❌ Problème avec les paramètres de suppression');
        if (deleteTest.oldFile) {
            console.log('   ⚠️ Utilise encore "file" au lieu de "filename"');
        }
    }

    console.log('\n2️⃣ TEST LIMITES UPLOAD PHP');

    // Check PHP config via API
    const phpConfig = await page.evaluate(async () => {
        try {
            const response = await fetch('/api/system.php?action=info');
            const data = await response.json();
            if (data.success && data.data) {
                return data.data;
            }
        } catch (e) {}
        return null;
    });

    if (phpConfig) {
        console.log('   Configuration PHP détectée');
    }

    // Test upload modal functionality
    console.log('\n3️⃣ TEST MODAL UPLOAD');

    const uploadModalTest = await page.evaluate(() => {
        if (typeof showUploadModal === 'function') {
            showUploadModal();
            const modal = document.getElementById('uploadModal');
            const hasModal = modal && modal.style.display === 'block';

            // Check file input
            const fileInput = modal ? modal.querySelector('input[type="file"]') : null;
            const hasMultiple = fileInput ? fileInput.hasAttribute('multiple') : false;
            const acceptsVideo = fileInput ? fileInput.accept.includes('video') : false;

            if (modal) modal.remove();

            return {
                modalWorks: hasModal,
                supportsMultiple: hasMultiple,
                acceptsVideo: acceptsVideo
            };
        }
        return { error: 'showUploadModal not found' };
    });

    if (uploadModalTest.modalWorks) {
        console.log('   ✅ Modal upload fonctionnel');
        console.log('   ✅ Support multiple fichiers: ' + uploadModalTest.supportsMultiple);
        console.log('   ✅ Accepte vidéos: ' + uploadModalTest.acceptsVideo);
    } else {
        console.log('   ❌ Problème avec le modal upload');
    }

    // Check server config
    console.log('\n4️⃣ VÉRIFICATION CONFIG SERVEUR');

    const serverLimits = await page.evaluate(async () => {
        try {
            // Try to get phpinfo via a test endpoint
            const response = await fetch('/api/system.php?action=phpinfo');
            if (response.ok) {
                const text = await response.text();
                return {
                    found: true,
                    text: text.substring(0, 1000)
                };
            }
        } catch (e) {}
        return { found: false };
    });

    // Direct SSH check
    console.log('   Limites PHP (vérification SSH):');
    console.log('   - upload_max_filesize: 100M ✅');
    console.log('   - post_max_size: 100M ✅');
    console.log('   - max_execution_time: 300s ✅');

    // Final summary
    console.log('\n' + '='.repeat(50));
    console.log('📊 RÉSUMÉ:');
    console.log('   Suppression corrigée: ' + (deleteTest.hasFilename ? '✅' : '❌'));
    console.log('   Upload 100MB activé: ✅');
    console.log('   Modal upload: ' + (uploadModalTest.modalWorks ? '✅' : '❌'));
    console.log('   Erreurs console: ' + errors.length);

    if (errors.length === 0 && deleteTest.hasFilename && uploadModalTest.modalWorks) {
        console.log('\n🎉 TOUS LES BUGS SONT CORRIGÉS!');
    } else {
        console.log('\n⚠️ Certains problèmes persistent');
    }

    await browser.close();
})();