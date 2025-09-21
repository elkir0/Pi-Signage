const puppeteer = require('puppeteer');
const fs = require('fs').promises;
const path = require('path');

// Liste des onglets à tester
const TABS = [
  { id: 'dashboard', name: 'Dashboard', selector: '[value="dashboard"]' },
  { id: 'playlist', name: 'Playlists', selector: '[value="playlist"]' },
  { id: 'media', name: 'Médias', selector: '[value="media"]' },
  { id: 'youtube', name: 'YouTube', selector: '[value="youtube"]' },
  { id: 'schedule', name: 'Programmation', selector: '[value="schedule"]' },
  { id: 'monitor', name: 'Monitoring', selector: '[value="monitor"]' },
  { id: 'settings', name: 'Paramètres', selector: '[value="settings"]' }
];

async function testAllTabs() {
  console.log('🚀 === DÉBUT DU TEST COMPLET DE TOUS LES ONGLETS ===\n');
  
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const results = {
    global: {
      errors: [],
      warnings: [],
      logs: []
    },
    tabs: {}
  };

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Capture globale des erreurs console
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      
      if (type === 'error') {
        results.global.errors.push(text);
        console.log(`  ❌ Erreur: ${text.substring(0, 100)}...`);
      } else if (type === 'warning') {
        results.global.warnings.push(text);
        console.log(`  ⚠️  Warning: ${text.substring(0, 100)}...`);
      } else {
        results.global.logs.push(text);
      }
    });

    page.on('pageerror', error => {
      results.global.errors.push(error.toString());
      console.log(`  💥 Page Error: ${error}`);
    });

    // Charger la page principale
    console.log('📡 Chargement de http://192.168.1.103...\n');
    const response = await page.goto('http://192.168.1.103', {
      waitUntil: 'networkidle2',
      timeout: 30000
    });

    console.log(`✅ Page chargée: Status ${response.status()}\n`);
    
    // Attendre que le contenu soit chargé
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Analyser l'état initial
    console.log('📊 === ANALYSE DE L\'ÉTAT INITIAL ===\n');
    
    const initialAnalysis = await page.evaluate(() => {
      const body = document.body;
      const bodyStyle = window.getComputedStyle(body);
      const logo = document.querySelector('img[alt*="PiSignage"]');
      const tabs = document.querySelectorAll('[role="tablist"] button');
      
      return {
        backgroundColor: bodyStyle.backgroundColor,
        textColor: bodyStyle.color,
        logoPresent: !!logo,
        logoSrc: logo ? logo.src : null,
        tabCount: tabs.length,
        darkMode: document.documentElement.classList.contains('dark') || 
                 document.body.classList.contains('dark'),
        title: document.title
      };
    });

    console.log(`🎨 Fond: ${initialAnalysis.backgroundColor}`);
    console.log(`📝 Texte: ${initialAnalysis.textColor}`);
    console.log(`🖼️  Logo: ${initialAnalysis.logoPresent ? '✅ Présent' : '❌ Absent'}`);
    console.log(`📑 Nombre d'onglets: ${initialAnalysis.tabCount}`);
    console.log(`🌙 Dark mode: ${initialAnalysis.darkMode ? '✅' : '❌'}`);
    console.log(`📄 Titre: ${initialAnalysis.title}\n`);

    // Prendre un screenshot de la page d'accueil
    await page.screenshot({ 
      path: 'screenshots/00-accueil.png',
      fullPage: true 
    });
    console.log(`📸 Screenshot page d'accueil sauvegardé\n`);

    // Créer le dossier screenshots si nécessaire
    await fs.mkdir('screenshots', { recursive: true });

    // Tester chaque onglet
    for (const tab of TABS) {
      console.log(`\n📌 === TEST DE L'ONGLET: ${tab.name.toUpperCase()} ===\n`);
      
      // Réinitialiser les erreurs pour cet onglet
      results.tabs[tab.id] = {
        errors: [],
        warnings: [],
        logs: [],
        content: null,
        screenshot: null
      };

      try {
        // Cliquer sur l'onglet
        console.log(`  🖱️  Clic sur l'onglet ${tab.name}...`);
        
        // Attendre que le bouton soit visible et cliquable
        await page.waitForSelector(tab.selector, { visible: true, timeout: 5000 });
        await page.click(tab.selector);
        
        // Attendre le chargement du contenu
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Capturer les erreurs spécifiques à cet onglet
        const tabErrors = results.global.errors.slice(-5); // Les 5 dernières erreurs
        const tabWarnings = results.global.warnings.slice(-5);
        
        results.tabs[tab.id].errors = tabErrors;
        results.tabs[tab.id].warnings = tabWarnings;
        
        // Analyser le contenu de l'onglet
        const tabContent = await page.evaluate((tabId) => {
          const content = document.querySelector(`[value="${tabId}"]`)?.parentElement?.parentElement?.nextElementSibling;
          if (!content) return { found: false };
          
          const visibleElements = content.querySelectorAll('*:not(script):not(style)');
          const hasContent = visibleElements.length > 0;
          const textContent = content.innerText || '';
          
          // Analyser les éléments spécifiques
          const cards = content.querySelectorAll('[class*="card"]');
          const buttons = content.querySelectorAll('button');
          const inputs = content.querySelectorAll('input, select, textarea');
          const tables = content.querySelectorAll('table');
          
          return {
            found: true,
            hasContent,
            textLength: textContent.length,
            elementCount: visibleElements.length,
            cards: cards.length,
            buttons: buttons.length,
            inputs: inputs.length,
            tables: tables.length,
            firstText: textContent.substring(0, 200)
          };
        }, tab.id);
        
        results.tabs[tab.id].content = tabContent;
        
        // Prendre un screenshot
        const screenshotPath = `screenshots/${String(TABS.indexOf(tab) + 1).padStart(2, '0')}-${tab.id}.png`;
        await page.screenshot({ 
          path: screenshotPath,
          fullPage: true 
        });
        results.tabs[tab.id].screenshot = screenshotPath;
        
        console.log(`  📸 Screenshot sauvegardé: ${screenshotPath}`);
        
        // Afficher l'analyse
        if (tabContent.found) {
          console.log(`  ✅ Contenu trouvé:`);
          console.log(`     - Éléments: ${tabContent.elementCount}`);
          console.log(`     - Cards: ${tabContent.cards}`);
          console.log(`     - Boutons: ${tabContent.buttons}`);
          console.log(`     - Inputs: ${tabContent.inputs}`);
          console.log(`     - Tables: ${tabContent.tables}`);
          
          if (!tabContent.hasContent || tabContent.elementCount < 5) {
            console.log(`  ⚠️  ATTENTION: Très peu de contenu dans cet onglet!`);
          }
        } else {
          console.log(`  ❌ ERREUR: Impossible de trouver le contenu de l'onglet`);
        }
        
        // Afficher les erreurs spécifiques à cet onglet
        if (tabErrors.length > 0) {
          console.log(`  ❌ Erreurs dans cet onglet: ${tabErrors.length}`);
        }
        
      } catch (error) {
        console.log(`  ❌ ERREUR lors du test de l'onglet ${tab.name}: ${error.message}`);
        results.tabs[tab.id].error = error.message;
      }
    }

    // Résumé final
    console.log('\n\n📊 === RÉSUMÉ FINAL DU TEST ===\n');
    
    console.log(`Erreurs globales: ${results.global.errors.length}`);
    console.log(`Warnings globaux: ${results.global.warnings.length}`);
    
    let problemTabs = [];
    for (const [tabId, tabData] of Object.entries(results.tabs)) {
      const tabName = TABS.find(t => t.id === tabId)?.name || tabId;
      
      if (tabData.error) {
        console.log(`\n❌ ${tabName}: ERREUR DE TEST`);
        problemTabs.push(tabName);
      } else if (!tabData.content?.found) {
        console.log(`\n❌ ${tabName}: CONTENU NON TROUVÉ`);
        problemTabs.push(tabName);
      } else if (!tabData.content?.hasContent || tabData.content?.elementCount < 5) {
        console.log(`\n⚠️  ${tabName}: PEU DE CONTENU (${tabData.content?.elementCount} éléments)`);
        problemTabs.push(tabName);
      } else {
        console.log(`\n✅ ${tabName}: OK (${tabData.content?.elementCount} éléments)`);
      }
    }
    
    // Sauvegarder le rapport JSON
    await fs.writeFile('test-report.json', JSON.stringify(results, null, 2));
    console.log('\n📄 Rapport détaillé sauvegardé dans test-report.json');
    
    // Conclusion
    console.log('\n\n🏁 === CONCLUSION ===\n');
    
    if (problemTabs.length === 0) {
      console.log('✅ TOUS LES ONGLETS FONCTIONNENT CORRECTEMENT!');
    } else {
      console.log(`❌ PROBLÈMES DÉTECTÉS DANS ${problemTabs.length} ONGLETS:`);
      problemTabs.forEach(tab => console.log(`   - ${tab}`));
    }
    
    if (results.global.errors.length > 0) {
      console.log(`\n🔴 ${results.global.errors.length} ERREURS CONSOLE AU TOTAL`);
      
      // Afficher les erreurs uniques
      const uniqueErrors = [...new Set(results.global.errors)];
      console.log('\nErreurs uniques:');
      uniqueErrors.forEach(err => {
        console.log(`  - ${err.substring(0, 150)}`);
      });
    }

  } catch (error) {
    console.error('\n💥 Erreur fatale pendant le test:', error);
  } finally {
    await browser.close();
  }

  console.log('\n🏁 === FIN DU TEST COMPLET ===\n');
}

// Lancer le test
testAllTabs().catch(console.error);