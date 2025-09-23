const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('📱 Test de l\'interface moderne sur Raspberry Pi...');

  await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0' });

  // Prendre screenshot principal
  await page.screenshot({ path: '/tmp/modern-interface.png' });
  console.log('✅ Screenshot principal sauvegardé');

  // Vérifier la présence de la sidebar
  const sidebar = await page.$('.sidebar');
  if (sidebar) {
    console.log('✅ Sidebar présente avec style glassmorphisme');
  } else {
    console.log('❌ Sidebar non trouvée');
  }

  // Vérifier le style bleu nuit
  const bgColor = await page.evaluate(() => {
    return window.getComputedStyle(document.body).background;
  });
  console.log('🎨 Background détecté:', bgColor.substring(0, 60) + '...');

  // Vérifier les sections dans la sidebar
  try {
    const navItems = await page.$$eval('.nav-item', items => items.map(item => item.innerText));
    console.log('📋 Sections dans la sidebar:', navItems);
  } catch (e) {
    console.log('⚠️ Pas de nav-items trouvés');
  }

  // Essayer de cliquer sur Lecteur
  try {
    const playerNav = await page.$('text/Lecteur');
    if (playerNav) {
      await playerNav.click();
      await page.waitForTimeout(1000);
      await page.screenshot({ path: '/tmp/modern-player.png' });
      console.log('✅ Screenshot section Lecteur');
    }
  } catch (e) {
    console.log('⚠️ Section Lecteur non accessible');
  }

  // Vérifier le mode selector
  const modeSelector = await page.$('#player-mode');
  if (modeSelector) {
    console.log('✅ Sélecteur de mode présent');
    const modes = await page.$$eval('#player-mode option', options => options.map(o => o.textContent));
    console.log('   Modes disponibles:', modes);
  } else {
    console.log('❌ Sélecteur de mode non trouvé');
  }

  // Vérifier les boutons capture
  try {
    const captureButtons = await page.$$eval('button', buttons =>
      buttons.filter(b => b.textContent.includes('Capture')).map(b => b.textContent)
    );
    if (captureButtons.length > 0) {
      console.log('📸 Boutons capture trouvés:', captureButtons);
    } else {
      console.log('❌ Aucun bouton capture trouvé');
    }
  } catch (e) {
    console.log('⚠️ Erreur lors de la recherche des boutons');
  }

  // Vérifier le titre
  const title = await page.title();
  console.log('📝 Titre de la page:', title);

  await browser.close();
  console.log('\n🏁 Test terminé!');
})();