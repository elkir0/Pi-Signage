const puppeteer = require('puppeteer');

(async () => {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    try {
        await page.goto('http://192.168.1.105/schedule.php', { waitUntil: 'networkidle2' });
        await page.evaluate(() => new Promise(r => setTimeout(r, 3000)));

        const domCheck = await page.evaluate(() => {
            return {
                modalExists: !!document.getElementById('schedule-modal'),
                modalTitleExists: !!document.getElementById('modal-title'),
                scheduleNameExists: !!document.getElementById('schedule-name'),
                allModals: Array.from(document.querySelectorAll('[id*="modal"]')).map(el => el.id),
                bodyHTML: document.body.innerHTML.length
            };
        });

        console.log('✅ Modal dans le DOM:', domCheck.modalExists);
        console.log('✅ Modal title dans le DOM:', domCheck.modalTitleExists);
        console.log('✅ schedule-name dans le DOM:', domCheck.scheduleNameExists);
        console.log('Tous les modals trouvés:', domCheck.allModals);
        console.log('Taille body HTML:', domCheck.bodyHTML, 'caractères');

        if (!domCheck.modalExists) {
            console.log('\n❌ MODAL NON TROUVÉ !');
            console.log('Le HTML est peut-être cassé...');

            const htmlStructure = await page.evaluate(() => {
                const mainContent = document.querySelector('.main-content');
                return {
                    hasMainContent: !!mainContent,
                    mainContentHTML: mainContent ? mainContent.innerHTML.substring(0, 500) : 'N/A'
                };
            });

            console.log('Main content exists:', htmlStructure.hasMainContent);
            console.log('Main content HTML preview:', htmlStructure.mainContentHTML);
        }

    } catch (error) {
        console.error('Erreur:', error.message);
    } finally {
        await browser.close();
    }
})();
