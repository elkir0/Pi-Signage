const puppeteer = require('puppeteer');

async function testRealContent() {
    const browser = await puppeteer.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    try {
        const page = await browser.newPage();
        console.log('🔍 VÉRIFICATION DU CONTENU RÉEL\n');
        console.log('===================================\n');
        
        // Capturer les erreurs console
        page.on('console', msg => {
            if (msg.type() === 'error' || msg.type() === 'warning') {
                console.log(`${msg.type().toUpperCase()}: ${msg.text()}`);
            }
        });
        
        await page.goto('http://192.168.1.103', { waitUntil: 'networkidle2' });
        
        // Vérifier le contenu visible
        const content = await page.evaluate(() => {
            const dashboard = document.querySelector('#dashboard');
            const tabContent = document.querySelector('.tab-content');
            
            return {
                // Structure
                hasTabContent: tabContent !== null,
                tabContentHTML: tabContent ? tabContent.innerHTML.substring(0, 200) : 'VIDE',
                dashboardExists: dashboard !== null,
                dashboardVisible: dashboard ? window.getComputedStyle(dashboard).display !== 'none' : false,
                dashboardContent: dashboard ? dashboard.innerText.substring(0, 200) : 'VIDE',
                
                // Cards dans dashboard
                cards: document.querySelectorAll('.card').length,
                cardsContent: Array.from(document.querySelectorAll('.card')).map(card => ({
                    text: card.innerText.substring(0, 50),
                    classes: card.className
                })),
                
                // Boutons
                buttons: Array.from(document.querySelectorAll('button')).map(btn => btn.innerText),
                
                // Problèmes CSS
                bodyBg: window.getComputedStyle(document.body).backgroundColor,
                tabContentBg: tabContent ? window.getComputedStyle(tabContent).backgroundColor : 'N/A'
            };
        });
        
        console.log('📊 CONTENU TROUVÉ:');
        console.log('Tab Content existe:', content.hasTabContent ? '✅' : '❌');
        console.log('Dashboard existe:', content.dashboardExists ? '✅' : '❌');
        console.log('Dashboard visible:', content.dashboardVisible ? '✅' : '❌');
        console.log('Nombre de cards:', content.cards);
        console.log('\nContenu dashboard (200 chars):', content.dashboardContent);
        console.log('\nCards trouvées:');
        content.cardsContent.forEach((card, i) => {
            console.log(`  ${i+1}. ${card.text}`);
        });
        console.log('\nBoutons:', content.buttons.join(', '));
        console.log('\nCouleurs:');
        console.log('  Body bg:', content.bodyBg);
        console.log('  Tab content bg:', content.tabContentBg);
        
        // Cliquer sur chaque onglet et vérifier
        console.log('\n🔄 TEST DES ONGLETS:');
        const tabs = ['#dashboard', '#playlist', '#media', '#youtube', '#settings'];
        
        for (const tab of tabs) {
            const tabName = tab.substring(1);
            await page.click(`a[href="${tab}"]`);
            await page.waitForTimeout(500);
            
            const tabContent = await page.evaluate((tabId) => {
                const element = document.querySelector(tabId);
                return {
                    visible: element && element.classList.contains('show'),
                    content: element ? element.innerText.substring(0, 100) : 'VIDE'
                };
            }, tab);
            
            console.log(`  ${tabName}: ${tabContent.visible ? '✅ Visible' : '❌ Caché'}`);
            console.log(`    Contenu: ${tabContent.content}`);
        }
        
        await page.screenshot({ path: 'real-content-check.png', fullPage: true });
        console.log('\n📸 Screenshot: real-content-check.png');
        
    } catch (error) {
        console.error('❌ ERREUR:', error.message);
    } finally {
        await browser.close();
    }
}

testRealContent();