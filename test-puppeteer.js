const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const RASPI_IP = '192.168.1.103';
const BASE_URL = `http://${RASPI_IP}`;

// Couleurs pour la console
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m'
};

function log(message, type = 'info') {
  const timestamp = new Date().toISOString().split('T')[1].slice(0, 8);
  const color = type === 'error' ? colors.red :
                 type === 'success' ? colors.green :
                 type === 'warning' ? colors.yellow :
                 colors.blue;
  console.log(`${color}[${timestamp}] ${message}${colors.reset}`);
}

async function testPiSignage() {
  log('Démarrage des tests PiSignage...', 'info');

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    timeout: 60000
  });

  try {
    const page = await browser.newPage();

    // Capturer les logs de la console
    page.on('console', msg => {
      if (msg.type() === 'error') {
        log(`Console Error: ${msg.text()}`, 'error');
      }
    });

    // Capturer les erreurs de requêtes
    page.on('requestfailed', request => {
      log(`Request failed: ${request.url()} - ${request.failure().errorText}`, 'error');
    });

    // Intercepter les réponses pour voir les erreurs 500
    page.on('response', response => {
      if (response.status() >= 400) {
        log(`HTTP ${response.status()} - ${response.url()}`, 'error');
      }
    });

    // Test 1: Accès à la page principale
    log('Test 1: Accès à l\'interface web...', 'info');
    try {
      await page.goto(BASE_URL, {
        waitUntil: 'networkidle2',
        timeout: 30000
      });
      log('✓ Page principale chargée', 'success');
    } catch (error) {
      log(`✗ Erreur chargement page: ${error.message}`, 'error');
      throw error;
    }

    // Capture d'écran initiale
    await page.screenshot({ path: '/tmp/pisignage-home.png' });
    log('Screenshot sauvegardé: /tmp/pisignage-home.png', 'info');

    // Test 2: Vérifier les APIs
    log('Test 2: Vérification des APIs...', 'info');

    const apis = [
      '/api/system.php?action=stats',
      '/api/media.php',
      '/api/playlist.php?action=list',
      '/api/system.php?action=get_player'
    ];

    for (const api of apis) {
      try {
        const response = await page.evaluate(async (url) => {
          const res = await fetch(url);
          const text = await res.text();
          return {
            status: res.status,
            ok: res.ok,
            text: text.substring(0, 200) // Premiers 200 caractères
          };
        }, BASE_URL + api);

        if (response.ok) {
          log(`✓ API ${api}: OK (${response.status})`, 'success');
        } else {
          log(`✗ API ${api}: Erreur ${response.status}`, 'error');
          log(`  Réponse: ${response.text}`, 'warning');
        }
      } catch (error) {
        log(`✗ API ${api}: ${error.message}`, 'error');
      }
    }

    // Test 3: Test d'upload de fichier
    log('Test 3: Test d\'upload de fichier...', 'info');

    // Créer un fichier de test
    const testFileSize = 50 * 1024 * 1024; // 50MB
    const testFilePath = '/tmp/test-upload-50mb.bin';

    if (!fs.existsSync(testFilePath)) {
      log('Création du fichier de test 50MB...', 'info');
      const buffer = Buffer.alloc(testFileSize);
      fs.writeFileSync(testFilePath, buffer);
    }

    // Naviguer vers la gestion des médias
    try {
      // Cliquer sur le bouton de gestion des médias
      await page.evaluate(() => {
        const mediaTab = document.querySelector('a[href="#media"]') ||
                         document.querySelector('[onclick*="showMediaManagement"]') ||
                         document.querySelector('#media-tab');
        if (mediaTab) mediaTab.click();
      });

      await page.waitForTimeout(2000);

      // Trouver l'input file
      const fileInput = await page.$('input[type="file"]');
      if (fileInput) {
        log('Upload du fichier de test...', 'info');

        // Capturer les requêtes XHR
        const uploadPromise = page.waitForResponse(
          response => response.url().includes('upload.php'),
          { timeout: 60000 }
        );

        await fileInput.uploadFile(testFilePath);

        try {
          const response = await uploadPromise;
          const responseBody = await response.text();

          if (response.status() === 200) {
            log(`✓ Upload réussi: ${response.status()}`, 'success');
          } else if (response.status() === 413) {
            log(`✗ Upload échoué: Fichier trop gros (413)`, 'error');
          } else {
            log(`✗ Upload échoué: ${response.status()}`, 'error');
            log(`  Réponse: ${responseBody.substring(0, 200)}`, 'warning');
          }
        } catch (error) {
          log(`✗ Timeout upload: ${error.message}`, 'error');
        }
      } else {
        log('✗ Input file non trouvé', 'error');
      }
    } catch (error) {
      log(`✗ Erreur navigation médias: ${error.message}`, 'error');
    }

    // Capture finale
    await page.screenshot({ path: '/tmp/pisignage-final.png' });
    log('Screenshot final: /tmp/pisignage-final.png', 'info');

    // Collecter les erreurs JavaScript
    const jsErrors = await page.evaluate(() => {
      return window.errors || [];
    });

    if (jsErrors.length > 0) {
      log('Erreurs JavaScript détectées:', 'error');
      jsErrors.forEach(err => log(`  - ${err}`, 'error'));
    }

  } catch (error) {
    log(`Erreur critique: ${error.message}`, 'error');
    console.error(error);
  } finally {
    await browser.close();
  }

  log('Tests terminés', 'info');
}

// Vérifier les logs d'erreur directement via curl
async function checkServerErrors() {
  log('\n=== Vérification des erreurs serveur ===', 'info');

  const { exec } = require('child_process');
  const util = require('util');
  const execPromise = util.promisify(exec);

  try {
    // Test simple avec curl
    const { stdout, stderr } = await execPromise(`curl -s -I http://${RASPI_IP}/api/system.php?action=stats`);
    log('Headers de réponse:', 'info');
    console.log(stdout);

    // Récupérer le contenu de l'erreur
    const { stdout: body } = await execPromise(`curl -s http://${RASPI_IP}/api/system.php?action=stats`);
    log('Corps de la réponse (100 premiers chars):', 'info');
    console.log(body.substring(0, 100));

    // Analyser si c'est une erreur PHP
    if (body.includes('Fatal error') || body.includes('Warning') || body.includes('Parse error')) {
      log('Erreur PHP détectée dans la réponse!', 'error');
      const lines = body.split('\n').slice(0, 5);
      lines.forEach(line => log(`  ${line}`, 'error'));
    }
  } catch (error) {
    log(`Erreur curl: ${error.message}`, 'error');
  }
}

// Lancer les tests
(async () => {
  await checkServerErrors();
  await testPiSignage();
})();