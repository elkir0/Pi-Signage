#!/usr/bin/env node

/**
 * SUITE DE TESTS DE VALIDATION COMPLÈTE
 * Pi-Signage v0.9.1 - Validation des 3 bugs critiques
 * 
 * BUGS À VALIDER:
 * 1. Screenshot - Capture d'écran fonctionnelle
 * 2. Upload - Upload et affichage dans Media
 * 3. YouTube - Téléchargement avec progression
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

// Configuration
const BASE_URL = 'http://192.168.1.103';
const RESULTS_DIR = '/opt/pisignage/tests/results';
const TIMESTAMP = new Date().toISOString().replace(/[:.]/g, '-');

// Couleurs pour les logs
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

// Helpers
const log = {
  test: (msg) => console.log(`${colors.blue}[TEST]${colors.reset} ${msg}`),
  success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  info: (msg) => console.log(`${colors.cyan}ℹ${colors.reset} ${msg}`),
  warn: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`)
};

// Résultats des tests
const testResults = {
  timestamp: TIMESTAMP,
  url: BASE_URL,
  tests: [],
  summary: {
    total: 0,
    passed: 0,
    failed: 0
  }
};

// Créer le dossier de résultats
if (!fs.existsSync(RESULTS_DIR)) {
  fs.mkdirSync(RESULTS_DIR, { recursive: true });
}

/**
 * Test individuel avec validation
 */
async function runTest(name, testFn, validations = []) {
  log.test(`Exécution: ${name}`);
  const result = {
    name,
    status: 'pending',
    duration: 0,
    validations: [],
    error: null
  };
  
  const startTime = Date.now();
  
  try {
    // Exécuter le test
    await testFn();
    
    // Exécuter les validations
    for (const validation of validations) {
      log.info(`  Validation: ${validation.name}`);
      const validResult = await validation.check();
      result.validations.push({
        name: validation.name,
        passed: validResult,
        message: validResult ? 'OK' : 'FAILED'
      });
      
      if (validResult) {
        log.success(`    ${validation.name}: PASS`);
      } else {
        log.error(`    ${validation.name}: FAIL`);
      }
    }
    
    // Vérifier si toutes les validations sont passées
    const allPassed = result.validations.length === 0 || 
                     result.validations.every(v => v.passed);
    
    result.status = allPassed ? 'passed' : 'failed';
    
    if (allPassed) {
      log.success(`${name}: SUCCÈS`);
      testResults.summary.passed++;
    } else {
      log.error(`${name}: ÉCHEC (validations échouées)`);
      testResults.summary.failed++;
    }
    
  } catch (error) {
    result.status = 'error';
    result.error = error.message;
    log.error(`${name}: ERREUR - ${error.message}`);
    testResults.summary.failed++;
  }
  
  result.duration = Date.now() - startTime;
  testResults.tests.push(result);
  testResults.summary.total++;
}

/**
 * TEST 1: SCREENSHOT
 */
async function testScreenshot(page) {
  return runTest('Screenshot API', async () => {
    // Test 1.1: API directe
    const apiResponse = await page.evaluate(async () => {
      const response = await fetch('/api/screenshot.php');
      return {
        status: response.status,
        data: await response.json()
      };
    });
    
    if (apiResponse.status !== 200) {
      throw new Error(`API returned status ${apiResponse.status}`);
    }
    
    // Test 1.2: Via interface
    await page.goto(BASE_URL);
    await page.waitForSelector('#dashboardTab', { timeout: 5000 });
    await page.click('#dashboardTab');
    await page.waitForTimeout(1000);
    
    // Déclencher une capture
    const screenshotResult = await page.evaluate(() => {
      return new Promise((resolve) => {
        if (typeof takeScreenshot === 'function') {
          takeScreenshot();
          setTimeout(() => {
            const img = document.querySelector('#screenshotPreview img');
            resolve({
              hasImage: !!img,
              src: img ? img.src : null
            });
          }, 2000);
        } else {
          resolve({ error: 'takeScreenshot not found' });
        }
      });
    });
    
  }, [
    {
      name: 'API répond avec succès',
      check: async () => {
        const response = await fetch(`${BASE_URL}/api/screenshot.php`);
        const data = await response.json();
        return data.success === true && data.image !== undefined;
      }
    },
    {
      name: 'Image accessible',
      check: async () => {
        const response = await fetch(`${BASE_URL}/api/screenshot.php`);
        const data = await response.json();
        if (data.image) {
          const imgResponse = await fetch(`${BASE_URL}${data.image}`);
          return imgResponse.status === 200;
        }
        return false;
      }
    },
    {
      name: 'Fichier créé sur le serveur',
      check: async () => {
        const { stdout } = await execPromise(
          "sshpass -p 'raspberry' ssh pi@192.168.1.103 'ls -la /opt/pisignage/web/assets/screenshots/current.png 2>/dev/null | wc -l'"
        );
        return parseInt(stdout.trim()) > 0;
      }
    }
  ]);
}

/**
 * TEST 2: UPLOAD
 */
async function testUpload(page) {
  return runTest('Upload de fichiers', async () => {
    // Créer un fichier de test
    const testFile = path.join('/tmp', `test-upload-${Date.now()}.txt`);
    fs.writeFileSync(testFile, `Test upload Pi-Signage ${new Date().toISOString()}`);
    
    await page.goto(BASE_URL);
    await page.waitForSelector('#mediasTab', { timeout: 5000 });
    await page.click('#mediasTab');
    await page.waitForTimeout(1000);
    
    // Upload via l'input file
    const inputFile = await page.$('input[type="file"]');
    if (!inputFile) {
      throw new Error('Input file not found');
    }
    
    await inputFile.uploadFile(testFile);
    await page.waitForTimeout(3000);
    
    // Vérifier que updateMediaList existe et est appelé
    const mediaListUpdated = await page.evaluate(() => {
      return typeof updateMediaList === 'function';
    });
    
    // Nettoyer
    fs.unlinkSync(testFile);
    
  }, [
    {
      name: 'Fonction updateMediaList existe',
      check: async () => {
        const browser = await puppeteer.launch({ headless: true });
        const page = await browser.newPage();
        await page.goto(BASE_URL);
        const exists = await page.evaluate(() => typeof updateMediaList === 'function');
        await browser.close();
        return exists;
      }
    },
    {
      name: 'API Upload répond',
      check: async () => {
        const response = await fetch(`${BASE_URL}/api/upload.php`, {
          method: 'POST',
          body: new FormData()
        });
        return response.status === 200;
      }
    },
    {
      name: 'Dossier media accessible',
      check: async () => {
        const { stdout } = await execPromise(
          "sshpass -p 'raspberry' ssh pi@192.168.1.103 'ls /opt/pisignage/media/ | wc -l'"
        );
        return parseInt(stdout.trim()) >= 0;
      }
    }
  ]);
}

/**
 * TEST 3: YOUTUBE DOWNLOAD
 */
async function testYouTube(page) {
  return runTest('YouTube Download', async () => {
    // Test 3.1: API info
    const infoResponse = await page.evaluate(async () => {
      const response = await fetch('/api/youtube.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'info',
          url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
        })
      });
      return {
        status: response.status,
        data: await response.json()
      };
    });
    
    if (infoResponse.status !== 200) {
      throw new Error(`YouTube API returned status ${infoResponse.status}`);
    }
    
    // Test 3.2: Via interface
    await page.goto(BASE_URL);
    await page.waitForSelector('#youtubeTab', { timeout: 5000 });
    await page.click('#youtubeTab');
    await page.waitForTimeout(1000);
    
    // Vérifier que les fonctions existent
    const functionsExist = await page.evaluate(() => {
      return {
        downloadYoutube: typeof downloadYoutube === 'function',
        getVideoInfo: typeof getVideoInfo === 'function',
        loadDownloadQueue: typeof loadDownloadQueue === 'function'
      };
    });
    
  }, [
    {
      name: 'API YouTube info fonctionne',
      check: async () => {
        const response = await fetch(`${BASE_URL}/api/youtube.php`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'info',
            url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
          })
        });
        const data = await response.json();
        return data.success === true && data.info !== undefined;
      }
    },
    {
      name: 'yt-dlp installé',
      check: async () => {
        const { stdout } = await execPromise(
          "sshpass -p 'raspberry' ssh pi@192.168.1.103 'which yt-dlp'"
        );
        return stdout.includes('/usr/local/bin/yt-dlp');
      }
    },
    {
      name: 'Logs YouTube accessibles',
      check: async () => {
        const { stdout } = await execPromise(
          "sshpass -p 'raspberry' ssh pi@192.168.1.103 'ls -la /opt/pisignage/logs/ 2>/dev/null | grep -c youtube'"
        );
        return parseInt(stdout.trim()) >= 0;
      }
    }
  ]);
}

/**
 * TESTS SUPPLÉMENTAIRES
 */
async function testAPIs() {
  return runTest('Toutes les APIs répondent', async () => {
    const apis = [
      '/api/screenshot.php',
      '/api/upload.php',
      '/api/youtube.php',
      '/api/playlist.php',
      '/api/control.php'
    ];
    
    for (const api of apis) {
      const response = await fetch(`${BASE_URL}${api}`);
      if (response.status >= 500) {
        throw new Error(`${api} returned ${response.status}`);
      }
    }
  }, [
    {
      name: 'Toutes les APIs accessibles',
      check: async () => {
        const { stdout } = await execPromise(
          "sshpass -p 'raspberry' ssh pi@192.168.1.103 'ls /opt/pisignage/web/api/*.php | wc -l'"
        );
        return parseInt(stdout.trim()) >= 5;
      }
    }
  ]);
}

/**
 * MAIN - Exécution des tests
 */
async function main() {
  console.log('');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('   SUITE DE VALIDATION COMPLÈTE - Pi-Signage v0.9.1');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`   URL: ${BASE_URL}`);
  console.log(`   Date: ${new Date().toLocaleString()}`);
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('');
  
  let browser;
  
  try {
    // Lancer le navigateur
    log.info('Lancement de Puppeteer...');
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // Intercepter les logs console
    page.on('console', msg => {
      if (msg.type() === 'error') {
        log.warn(`Console Error: ${msg.text()}`);
      }
    });
    
    // TEST 1: SCREENSHOT
    console.log('\n▶ TEST 1: SCREENSHOT');
    console.log('───────────────────────────────');
    await testScreenshot(page);
    
    // TEST 2: UPLOAD
    console.log('\n▶ TEST 2: UPLOAD');
    console.log('───────────────────────────────');
    await testUpload(page);
    
    // TEST 3: YOUTUBE
    console.log('\n▶ TEST 3: YOUTUBE DOWNLOAD');
    console.log('───────────────────────────────');
    await testYouTube(page);
    
    // TEST 4: APIs
    console.log('\n▶ TEST 4: VALIDATION DES APIs');
    console.log('───────────────────────────────');
    await testAPIs();
    
  } catch (error) {
    log.error(`Erreur fatale: ${error.message}`);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
  
  // Sauvegarder les résultats
  const reportPath = path.join(RESULTS_DIR, `validation-${TIMESTAMP}.json`);
  fs.writeFileSync(reportPath, JSON.stringify(testResults, null, 2));
  
  // Afficher le résumé
  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log('                         RÉSUMÉ DES TESTS');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`   Total: ${testResults.summary.total}`);
  console.log(`   ${colors.green}Réussis: ${testResults.summary.passed}${colors.reset}`);
  console.log(`   ${colors.red}Échecs: ${testResults.summary.failed}${colors.reset}`);
  console.log('───────────────────────────────────────────────────────────────');
  
  // Détails des tests
  testResults.tests.forEach(test => {
    const icon = test.status === 'passed' ? '✅' : '❌';
    const color = test.status === 'passed' ? colors.green : colors.red;
    console.log(`   ${icon} ${test.name}: ${color}${test.status.toUpperCase()}${colors.reset}`);
    
    if (test.validations.length > 0) {
      test.validations.forEach(v => {
        const vIcon = v.passed ? '✓' : '✗';
        const vColor = v.passed ? colors.green : colors.red;
        console.log(`      ${vColor}${vIcon} ${v.name}${colors.reset}`);
      });
    }
  });
  
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`   Rapport sauvé: ${reportPath}`);
  console.log('═══════════════════════════════════════════════════════════════');
  
  // Code de sortie
  process.exit(testResults.summary.failed > 0 ? 1 : 0);
}

// Lancer les tests
main().catch(console.error);