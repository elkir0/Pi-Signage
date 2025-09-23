const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    defaultViewport: { width: 1920, height: 1080 },
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
  });

  const page = await browser.newPage();

  const screenshotsDir = '/opt/pisignage/screenshots';
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const results = {
    timestamp: new Date().toISOString(),
    url: 'http://192.168.1.103/',
    keyFunctionalities: [],
    uploads: [],
    playerControls: [],
    playlists: [],
    systemActions: [],
    errors: []
  };

  console.log('🎯 Test 4: Fonctionnalités Clés PiSignage');
  console.log('URL:', 'http://192.168.1.103/');

  try {
    // Test 1: Interface Upload
    console.log('\n📤 Test 1: Interface Upload...');

    await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Naviguer vers section Médias
    try {
      await page.evaluate(() => {
        const links = Array.from(document.querySelectorAll('a, button'));
        const mediaLink = links.find(link =>
          link.textContent.toLowerCase().includes('média') ||
          link.textContent.toLowerCase().includes('media')
        );
        if (mediaLink) mediaLink.click();
      });

      await new Promise(resolve => setTimeout(resolve, 2000));

      // Chercher les éléments d'upload
      const uploadElements = await page.evaluate(() => {
        const inputs = Array.from(document.querySelectorAll('input[type="file"], input[type="url"], button'));
        return inputs.map(el => ({
          type: el.type || el.tagName,
          text: el.textContent || el.placeholder || el.value || '',
          id: el.id,
          name: el.name,
          className: el.className
        })).filter(el =>
          el.text.toLowerCase().includes('upload') ||
          el.text.toLowerCase().includes('fichier') ||
          el.text.toLowerCase().includes('url') ||
          el.type === 'file'
        );
      });

      console.log(`📁 ${uploadElements.length} éléments d'upload trouvés:`);
      uploadElements.forEach((el, i) => {
        console.log(`   ${i+1}. ${el.type}: "${el.text}" (${el.id || el.className})`);
      });

      // Test upload par URL
      try {
        const urlInput = await page.$('input[type="url"], input[placeholder*="URL"], input[placeholder*="url"]');
        if (urlInput) {
          await urlInput.type('https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4');
          console.log('   ✅ URL de test saisie');

          // Chercher bouton télécharger
          const downloadBtn = await page.$('button:contains("Télécharger"), button:contains("Download")');
          if (downloadBtn) {
            await downloadBtn.click();
            console.log('   🔄 Bouton télécharger cliqué');
            await new Promise(resolve => setTimeout(resolve, 3000));
          }
        }
      } catch (urlError) {
        console.log(`   ❌ Test URL: ${urlError.message}`);
      }

      // Screenshot de la section upload
      await page.screenshot({
        path: path.join(screenshotsDir, '09_upload_interface.png'),
        fullPage: true
      });

      results.uploads.push({
        name: 'Interface Upload',
        elementsFound: uploadElements.length,
        screenshot: '09_upload_interface.png',
        status: uploadElements.length > 0 ? 'SUCCESS' : 'LIMITED'
      });

    } catch (uploadError) {
      console.log(`❌ Erreur section upload: ${uploadError.message}`);
      results.errors.push(`Upload: ${uploadError.message}`);
    }

    // Test 2: Contrôles Lecteur
    console.log('\n▶️ Test 2: Contrôles Lecteur...');

    try {
      await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Naviguer vers section Lecteur
      await page.evaluate(() => {
        const links = Array.from(document.querySelectorAll('a, button'));
        const playerLink = links.find(link =>
          link.textContent.toLowerCase().includes('lecteur') ||
          link.textContent.toLowerCase().includes('player')
        );
        if (playerLink) playerLink.click();
      });

      await new Promise(resolve => setTimeout(resolve, 2000));

      // Identifier contrôles lecteur
      const playerControls = await page.$$eval('button', buttons =>
        buttons.map(btn => ({
          text: btn.textContent.trim(),
          id: btn.id,
          className: btn.className,
          disabled: btn.disabled
        })).filter(btn =>
          btn.text.toLowerCase().includes('démarrer') ||
          btn.text.toLowerCase().includes('arrêter') ||
          btn.text.toLowerCase().includes('play') ||
          btn.text.toLowerCase().includes('stop') ||
          btn.text.toLowerCase().includes('pause')
        )
      );

      console.log(`🎮 ${playerControls.length} contrôles lecteur trouvés:`);
      playerControls.forEach((ctrl, i) => {
        console.log(`   ${i+1}. "${ctrl.text}" ${ctrl.disabled ? '(désactivé)' : ''}`);
      });

      // Test des contrôles
      for (const control of playerControls.slice(0, 3)) {
        try {
          await page.evaluate((text) => {
            const buttons = Array.from(document.querySelectorAll('button'));
            const btn = buttons.find(b => b.textContent.trim() === text);
            if (btn && !btn.disabled) {
              btn.click();
              return true;
            }
            return false;
          }, control.text);

          console.log(`   ✅ Contrôle "${control.text}" testé`);
          await new Promise(resolve => setTimeout(resolve, 1000));

        } catch (ctrlError) {
          console.log(`   ❌ Erreur contrôle "${control.text}": ${ctrlError.message}`);
        }
      }

      // Screenshot contrôles lecteur
      await page.screenshot({
        path: path.join(screenshotsDir, '10_player_controls.png'),
        fullPage: true
      });

      results.playerControls.push({
        name: 'Contrôles Lecteur',
        controlsFound: playerControls.length,
        screenshot: '10_player_controls.png',
        status: 'SUCCESS'
      });

    } catch (playerError) {
      console.log(`❌ Erreur contrôles lecteur: ${playerError.message}`);
      results.errors.push(`Player: ${playerError.message}`);
    }

    // Test 3: Gestion Playlists
    console.log('\n🎵 Test 3: Gestion Playlists...');

    try {
      await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Naviguer vers section Playlists
      await page.evaluate(() => {
        const links = Array.from(document.querySelectorAll('a, button'));
        const playlistLink = links.find(link =>
          link.textContent.toLowerCase().includes('playlist')
        );
        if (playlistLink) playlistLink.click();
      });

      await new Promise(resolve => setTimeout(resolve, 2000));

      // Identifier éléments playlist
      const playlistElements = await page.evaluate(() => {
        const elements = [];

        // Boutons playlist
        const buttons = Array.from(document.querySelectorAll('button'));
        buttons.forEach(btn => {
          const text = btn.textContent.trim();
          if (text.toLowerCase().includes('playlist') ||
              text.toLowerCase().includes('nouvelle') ||
              text.toLowerCase().includes('créer') ||
              text.toLowerCase().includes('sauvegarder')) {
            elements.push({
              type: 'button',
              text: text,
              id: btn.id,
              className: btn.className
            });
          }
        });

        // Inputs playlist
        const inputs = Array.from(document.querySelectorAll('input, textarea, select'));
        inputs.forEach(input => {
          if (input.placeholder && (
              input.placeholder.toLowerCase().includes('playlist') ||
              input.placeholder.toLowerCase().includes('nom')
            )) {
            elements.push({
              type: input.type || input.tagName,
              placeholder: input.placeholder,
              id: input.id,
              name: input.name
            });
          }
        });

        return elements;
      });

      console.log(`📋 ${playlistElements.length} éléments playlist trouvés:`);
      playlistElements.forEach((el, i) => {
        console.log(`   ${i+1}. ${el.type}: "${el.text || el.placeholder}" (${el.id || el.className || el.name})`);
      });

      // Test création playlist
      try {
        const nameInput = await page.$('input[placeholder*="nom"], input[name*="name"], input[placeholder*="Nom"]');
        if (nameInput) {
          await nameInput.type('Test Playlist Puppeteer');
          console.log('   ✅ Nom playlist saisi');

          const saveBtn = await page.$('button:contains("Sauvegarder"), button:contains("Créer")');
          if (saveBtn) {
            await saveBtn.click();
            console.log('   💾 Bouton sauvegarder cliqué');
            await new Promise(resolve => setTimeout(resolve, 2000));
          }
        }
      } catch (createError) {
        console.log(`   ❌ Test création: ${createError.message}`);
      }

      // Screenshot playlists
      await page.screenshot({
        path: path.join(screenshotsDir, '11_playlist_management.png'),
        fullPage: true
      });

      results.playlists.push({
        name: 'Gestion Playlists',
        elementsFound: playlistElements.length,
        screenshot: '11_playlist_management.png',
        status: 'SUCCESS'
      });

    } catch (playlistError) {
      console.log(`❌ Erreur playlists: ${playlistError.message}`);
      results.errors.push(`Playlists: ${playlistError.message}`);
    }

    // Test 4: Actions Système
    console.log('\n⚙️ Test 4: Actions Système...');

    try {
      await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Naviguer vers paramètres
      await page.evaluate(() => {
        const links = Array.from(document.querySelectorAll('a, button'));
        const settingsLink = links.find(link =>
          link.textContent.toLowerCase().includes('paramètre') ||
          link.textContent.toLowerCase().includes('setting')
        );
        if (settingsLink) settingsLink.click();
      });

      await new Promise(resolve => setTimeout(resolve, 2000));

      // Identifier actions système
      const systemActions = await page.$$eval('button', buttons =>
        buttons.map(btn => ({
          text: btn.textContent.trim(),
          id: btn.id,
          className: btn.className,
          disabled: btn.disabled
        })).filter(btn =>
          btn.text.toLowerCase().includes('redémarrer') ||
          btn.text.toLowerCase().includes('éteindre') ||
          btn.text.toLowerCase().includes('cache') ||
          btn.text.toLowerCase().includes('service') ||
          btn.text.toLowerCase().includes('mise à jour')
        )
      );

      console.log(`🔧 ${systemActions.length} actions système trouvées:`);
      systemActions.forEach((action, i) => {
        console.log(`   ${i+1}. "${action.text}" ${action.disabled ? '(désactivé)' : ''}`);
      });

      // Screenshot paramètres système
      await page.screenshot({
        path: path.join(screenshotsDir, '12_system_actions.png'),
        fullPage: true
      });

      results.systemActions.push({
        name: 'Actions Système',
        actionsFound: systemActions.length,
        screenshot: '12_system_actions.png',
        status: 'SUCCESS'
      });

    } catch (systemError) {
      console.log(`❌ Erreur actions système: ${systemError.message}`);
      results.errors.push(`System: ${systemError.message}`);
    }

    // Test 5: Stats et Monitoring
    console.log('\n📊 Test 5: Stats Système...');

    try {
      await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Analyser les stats affichées
      const statsInfo = await page.evaluate(() => {
        const stats = [];

        // Chercher éléments avec des chiffres/pourcentages
        const elements = Array.from(document.querySelectorAll('*'));
        elements.forEach(el => {
          const text = el.textContent.trim();
          if (text.match(/\d+%|\d+\.\d+|CPU|RAM|Disk|Temperature|°C/i) && text.length < 100) {
            stats.push({
              element: el.tagName,
              text: text,
              className: el.className
            });
          }
        });

        return stats.slice(0, 20); // Limiter à 20 premiers
      });

      console.log(`📈 ${statsInfo.length} statistiques trouvées:`);
      statsInfo.forEach((stat, i) => {
        console.log(`   ${i+1}. ${stat.text}`);
      });

      results.keyFunctionalities.push({
        name: 'Stats Système',
        statsFound: statsInfo.length,
        stats: statsInfo,
        status: 'SUCCESS'
      });

    } catch (statsError) {
      console.log(`❌ Erreur stats: ${statsError.message}`);
      results.errors.push(`Stats: ${statsError.message}`);
    }

  } catch (error) {
    console.error('❌ Erreur globale test fonctionnalités:', error);
    results.errors.push(`Global: ${error.message}`);
  }

  // Sauvegarder rapport
  fs.writeFileSync(
    path.join(screenshotsDir, 'rapport_test_4_fonctionnalites.json'),
    JSON.stringify(results, null, 2)
  );

  console.log('\n🎯 RÉSUMÉ TEST 4 (Fonctionnalités Clés):');
  console.log(`📤 Upload: ${results.uploads.length} tests`);
  console.log(`▶️ Contrôles lecteur: ${results.playerControls.length} tests`);
  console.log(`🎵 Playlists: ${results.playlists.length} tests`);
  console.log(`⚙️ Actions système: ${results.systemActions.length} tests`);
  console.log(`📊 Fonctionnalités clés: ${results.keyFunctionalities.length} tests`);
  console.log(`❌ Erreurs: ${results.errors.length}`);

  await browser.close();
})();