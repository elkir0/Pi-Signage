const puppeteer = require('puppeteer');

(async () => {
  console.log('🧪 Test Final PiSignage Production - 192.168.1.103');
  console.log('=============================================\n');

  const browser = await puppeteer.launch({ headless: 'new' });
  const page = await browser.newPage();

  // Test 1: Interface principale
  console.log('📊 Test 1: Interface Web PiSignage');
  await page.goto('http://192.168.1.103', { waitUntil: 'networkidle0' });

  const title = await page.title();
  console.log(`✅ Titre: "${title}"`);

  // Test 2: API Screenshot
  console.log('\n📸 Test 2: API Screenshot');
  const screenshotResponse = await page.evaluate(async () => {
    const response = await fetch('/api/screenshot-simple.php?action=capture');
    return response.json();
  });

  if (screenshotResponse.success) {
    console.log(`✅ Capture réussie avec ${screenshotResponse.data.method}`);
    console.log(`   URL: ${screenshotResponse.data.url}`);
    console.log(`   Taille: ${screenshotResponse.data.size} bytes`);
  } else {
    console.log(`❌ Échec capture: ${screenshotResponse.message}`);
  }

  // Test 3: Vérifier VLC
  console.log('\n🎬 Test 3: VLC et Interface Graphique');
  const { execSync } = require('child_process');

  try {
    const vlcStatus = execSync("sshpass -p 'raspberry' ssh pi@192.168.1.103 'ps aux | grep vlc | grep -v grep'").toString();
    if (vlcStatus.includes('vlc')) {
      console.log('✅ VLC en cours d\'exécution');
    } else {
      console.log('❌ VLC n\'est pas en cours d\'exécution');
    }
  } catch (e) {
    console.log('⚠️ Impossible de vérifier VLC');
  }

  try {
    const x11Status = execSync("sshpass -p 'raspberry' ssh pi@192.168.1.103 'ps aux | grep -E \"(Xorg|lightdm)\" | grep -v grep'").toString();
    if (x11Status.includes('Xorg') || x11Status.includes('lightdm')) {
      console.log('✅ Interface graphique (X11/LightDM) active');
    } else {
      console.log('❌ Pas d\'interface graphique détectée');
    }
  } catch (e) {
    console.log('⚠️ Impossible de vérifier l\'interface graphique');
  }

  // Test 4: Test bouton capture dans l'interface
  console.log('\n🖱️ Test 4: Bouton Capture dans Interface');

  // Naviguer vers l'onglet screenshot
  await page.evaluate(() => {
    const screenshotTab = Array.from(document.querySelectorAll('.nav-tab')).find(tab => tab.textContent.includes('Capture'));
    if (screenshotTab) screenshotTab.click();
  });

  await page.waitForTimeout(1000);

  // Cliquer sur le bouton de capture
  const captureButton = await page.$('button[onclick="takeScreenshot()"]');
  if (captureButton) {
    await captureButton.click();
    console.log('✅ Bouton capture trouvé et cliqué');

    // Attendre la capture
    await page.waitForTimeout(3000);

    // Vérifier si l'image est affichée
    const screenshotDisplayed = await page.evaluate(() => {
      const img = document.getElementById('screenshot-display');
      return img && img.style.display !== 'none' && img.src !== '';
    });

    if (screenshotDisplayed) {
      console.log('✅ Capture affichée dans l\'interface');
    } else {
      console.log('❌ Capture non affichée');
    }
  } else {
    console.log('❌ Bouton capture non trouvé');
  }

  // Capture finale de l'interface
  await page.screenshot({ path: 'pisignage-final-test.png' });
  console.log('\n📸 Screenshot final: pisignage-final-test.png');

  console.log('\n✨ Tests terminés!');
  console.log('=====================================');

  await browser.close();
})();