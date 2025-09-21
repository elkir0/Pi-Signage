const puppeteer = require('puppeteer');

async function testInterfaceDetails() {
    const browser = await puppeteer.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    try {
        const page = await browser.newPage();
        console.log('🔍 ANALYSE DÉTAILLÉE DE L\'INTERFACE\n');
        console.log('=====================================\n');
        
        // Aller sur la page principale
        await page.goto('http://192.168.1.103', { waitUntil: 'networkidle2' });
        
        // 1. Vérifier les erreurs JavaScript
        page.on('console', msg => {
            if (msg.type() === 'error') {
                console.log('❌ Erreur JS:', msg.text());
            }
        });
        
        // 2. Analyser la structure HTML
        const structure = await page.evaluate(() => {
            return {
                hasNavbar: document.querySelector('.navbar') !== null,
                hasNavTabs: document.querySelector('.nav-tabs') !== null,
                hasTabContent: document.querySelector('.tab-content') !== null,
                navLinks: Array.from(document.querySelectorAll('.nav-link')).map(el => el.textContent.trim()),
                tabPanes: Array.from(document.querySelectorAll('.tab-pane')).map(el => el.id),
                scripts: Array.from(document.querySelectorAll('script[src]')).map(el => el.src.split('/').pop()),
                styles: Array.from(document.querySelectorAll('link[rel="stylesheet"]')).map(el => el.href.split('/').pop())
            };
        });
        
        console.log('📊 Structure HTML:');
        console.log('   Navbar présente:', structure.hasNavbar ? '✅' : '❌');
        console.log('   Nav-tabs présents:', structure.hasNavTabs ? '✅' : '❌');
        console.log('   Tab-content présent:', structure.hasTabContent ? '✅' : '❌');
        console.log('   Nav links trouvés:', structure.navLinks.length || 'AUCUN');
        console.log('   Tab panes trouvés:', structure.tabPanes.join(', ') || 'AUCUN');
        console.log('   Scripts chargés:', structure.scripts.join(', ') || 'AUCUN');
        console.log('   Styles chargés:', structure.styles.join(', ') || 'AUCUN');
        
        // 3. Vérifier Bootstrap et jQuery
        const jsLibraries = await page.evaluate(() => {
            return {
                jQuery: typeof jQuery !== 'undefined',
                jQueryVersion: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : null,
                bootstrap: typeof bootstrap !== 'undefined',
                bootstrapTooltip: typeof jQuery !== 'undefined' && typeof jQuery.fn.tooltip !== 'undefined'
            };
        });
        
        console.log('\n📚 Librairies JavaScript:');
        console.log('   jQuery:', jsLibraries.jQuery ? `✅ (v${jsLibraries.jQueryVersion})` : '❌');
        console.log('   Bootstrap JS:', jsLibraries.bootstrap ? '✅' : '❌');
        console.log('   Bootstrap Tooltip:', jsLibraries.bootstrapTooltip ? '✅' : '❌');
        
        // 4. Prendre un screenshot
        await page.screenshot({ path: 'interface-analysis.png', fullPage: true });
        console.log('\n📸 Screenshot: interface-analysis.png');
        
        // 5. Test direct du playlist-manager
        console.log('\n🎯 Test Playlist Manager:');
        await page.goto('http://192.168.1.103/playlist-manager.html', { waitUntil: 'networkidle2' });
        const pmTitle = await page.title();
        console.log('   Titre:', pmTitle);
        
        const pmStructure = await page.evaluate(() => {
            return {
                hasDragDrop: document.querySelector('.drag-drop-area') !== null,
                hasMediaList: document.querySelector('.media-list') !== null,
                hasPlaylistArea: document.querySelector('.playlist-items') !== null
            };
        });
        console.log('   Zone drag-drop:', pmStructure.hasDragDrop ? '✅' : '❌');
        console.log('   Liste médias:', pmStructure.hasMediaList ? '✅' : '❌');
        console.log('   Zone playlist:', pmStructure.hasPlaylistArea ? '✅' : '❌');
        
        console.log('\n=====================================');
        console.log('✅ ANALYSE TERMINÉE');
        
    } catch (error) {
        console.error('❌ ERREUR:', error.message);
    } finally {
        await browser.close();
    }
}

testInterfaceDetails();