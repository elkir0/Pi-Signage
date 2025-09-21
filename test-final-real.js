const puppeteer = require('puppeteer');

async function testFinalReal() {
    const browser = await puppeteer.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    try {
        const page = await browser.newPage();
        console.log('🧪 TEST FINAL RÉEL PI-SIGNAGE\n');
        console.log('==============================\n');
        
        // Capturer les erreurs
        const errors = [];
        page.on('console', msg => {
            if (msg.type() === 'error') {
                errors.push(msg.text());
            }
        });
        
        page.on('pageerror', err => {
            errors.push(err.toString());
        });
        
        // 1. Page principale
        console.log('1️⃣ TEST PAGE PRINCIPALE:');
        const response = await page.goto('http://192.168.1.103', { 
            waitUntil: 'networkidle2',
            timeout: 30000 
        });
        
        console.log('   Status HTTP:', response.status());
        
        // Attendre un peu pour le chargement
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Analyser le contenu
        const analysis = await page.evaluate(() => {
            return {
                title: document.title,
                // Navigation
                navbar: document.querySelector('.navbar') !== null,
                navbarBrand: document.querySelector('.navbar-brand')?.textContent,
                
                // Tabs
                tabs: Array.from(document.querySelectorAll('.nav-link')).map(t => t.textContent.trim()),
                activeTab: document.querySelector('.nav-link.active')?.textContent.trim(),
                
                // Contenu dashboard
                dashboardVisible: document.querySelector('#dashboard')?.classList.contains('active'),
                cards: document.querySelectorAll('.card').length,
                cardTitles: Array.from(document.querySelectorAll('.card h5')).map(h => h.textContent),
                
                // Boutons
                buttons: Array.from(document.querySelectorAll('button')).map(b => b.textContent.trim()),
                
                // Contenu réel
                vlcStatus: document.querySelector('#vlc-status')?.textContent || 'N/A',
                mediaCount: document.querySelector('#media-count')?.textContent || 'N/A',
                playlistCount: document.querySelector('#playlist-count')?.textContent || 'N/A',
                
                // Scripts chargés
                jquery: typeof jQuery !== 'undefined',
                bootstrap: typeof bootstrap !== 'undefined'
            };
        });
        
        console.log('   Titre:', analysis.title);
        console.log('   Navbar:', analysis.navbar ? '✅' : '❌');
        console.log('   Brand:', analysis.navbarBrand);
        console.log('   Onglets:', analysis.tabs.join(', '));
        console.log('   Onglet actif:', analysis.activeTab);
        console.log('   Dashboard visible:', analysis.dashboardVisible ? '✅' : '❌');
        console.log('   Cards:', analysis.cards);
        console.log('   Titres cards:', analysis.cardTitles.join(', '));
        console.log('   VLC Status:', analysis.vlcStatus);
        console.log('   Media Count:', analysis.mediaCount);
        console.log('   Playlist Count:', analysis.playlistCount);
        console.log('   jQuery:', analysis.jquery ? '✅' : '❌');
        console.log('   Bootstrap:', analysis.bootstrap ? '✅' : '❌');
        
        // 2. Test des APIs
        console.log('\n2️⃣ TEST DES APIs:');
        const apis = [
            '/api/control.php?action=status',
            '/api/playlist.php?action=list',
            '/api/media.php?action=list',
            '/api/playlist-advanced.php?action=list'
        ];
        
        for (const api of apis) {
            const apiResp = await page.goto('http://192.168.1.103' + api);
            const content = await page.evaluate(() => document.body.textContent);
            let parsed;
            try {
                parsed = JSON.parse(content);
                console.log(`   ✅ ${api}: OK (${Object.keys(parsed).join(', ')})`);
            } catch {
                console.log(`   ❌ ${api}: Pas de JSON valide`);
            }
        }
        
        // 3. Test playlist-manager.html
        console.log('\n3️⃣ TEST PLAYLIST MANAGER:');
        await page.goto('http://192.168.1.103/playlist-manager.html', { waitUntil: 'networkidle2' });
        
        const pmAnalysis = await page.evaluate(() => {
            return {
                title: document.title,
                hasContainer: document.querySelector('.container') !== null,
                hasDragDrop: document.querySelector('.drag-drop-area') !== null,
                hasMediaList: document.querySelector('#media-list') !== null,
                hasPlaylistArea: document.querySelector('#playlist-items') !== null,
                buttons: Array.from(document.querySelectorAll('button')).map(b => b.textContent.trim())
            };
        });
        
        console.log('   Titre:', pmAnalysis.title);
        console.log('   Container:', pmAnalysis.hasContainer ? '✅' : '❌');
        console.log('   Drag-drop:', pmAnalysis.hasDragDrop ? '✅' : '❌');
        console.log('   Media list:', pmAnalysis.hasMediaList ? '✅' : '❌');
        console.log('   Playlist area:', pmAnalysis.hasPlaylistArea ? '✅' : '❌');
        console.log('   Boutons:', pmAnalysis.buttons.length);
        
        // Screenshot final
        await page.goto('http://192.168.1.103');
        await new Promise(resolve => setTimeout(resolve, 2000));
        await page.screenshot({ path: 'test-final-real.png', fullPage: true });
        console.log('\n📸 Screenshot final: test-final-real.png');
        
        // Erreurs
        if (errors.length > 0) {
            console.log('\n⚠️ ERREURS JAVASCRIPT:');
            errors.forEach(err => console.log('   -', err));
        }
        
        // Résumé
        console.log('\n==============================');
        if (analysis.cards > 0 && analysis.jquery && analysis.bootstrap && errors.length === 0) {
            console.log('✅ INTERFACE FONCTIONNELLE!');
        } else {
            console.log('⚠️ INTERFACE PARTIELLEMENT FONCTIONNELLE');
            console.log('   Problèmes détectés:');
            if (analysis.cards === 0) console.log('   - Pas de cards affichées');
            if (!analysis.jquery) console.log('   - jQuery non chargé');
            if (!analysis.bootstrap) console.log('   - Bootstrap non chargé');
            if (errors.length > 0) console.log('   - Erreurs JavaScript présentes');
        }
        
    } catch (error) {
        console.error('❌ ERREUR CRITIQUE:', error.message);
    } finally {
        await browser.close();
    }
}

testFinalReal();