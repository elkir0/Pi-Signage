const puppeteer = require('puppeteer');
const fs = require('fs').promises;
const path = require('path');

// Liste des onglets à tester - utiliser le texte du bouton
const TABS = [
  { id: 'dashboard', name: 'Dashboard', text: 'Dashboard' },
  { id: 'playlist', name: 'Playlists', text: 'Playlists' },
  { id: 'media', name: 'Médias', text: 'Médias' },
  { id: 'youtube', name: 'YouTube', text: 'YouTube' },
  { id: 'schedule', name: 'Programmation', text: 'Programmation' },
  { id: 'monitor', name: 'Monitoring', text: 'Monitoring' },
  { id: 'settings', name: 'Paramètres', text: 'Paramètres' }
];

async function testAllTabs() {
  console.log('🚀 === TEST COMPLET DE CHAQUE ONGLET PISIGNAGE ===\n');
  
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const allErrors = [];
  const allWarnings = [];

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Capture des erreurs console
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      
      if (type === 'error') {
        allErrors.push(text);
        console.log(`  ❌ Console Error: ${text.substring(0, 80)}...`);
      } else if (type === 'warning') {
        allWarnings.push(text);
        console.log(`  ⚠️  Console Warning: ${text.substring(0, 80)}...`);
      }
    });

    page.on('pageerror', error => {
      allErrors.push(error.toString());
      console.log(`  💥 Page Error: ${error}`);
    });

    // Charger la page principale
    console.log('📡 Chargement de http://192.168.1.103...\n');
    const response = await page.goto('http://192.168.1.103', {
      waitUntil: 'networkidle2',
      timeout: 30000
    });

    console.log(`✅ Page chargée: Status ${response.status()}\n`);
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Créer le dossier screenshots si nécessaire
    await fs.mkdir('screenshots', { recursive: true });

    // Analyser la page d'accueil
    console.log('📊 === ANALYSE PAGE D\'ACCUEIL ===\n');
    
    const homeAnalysis = await page.evaluate(() => {
      const body = document.body;
      const bodyStyle = window.getComputedStyle(body);
      
      // Chercher les onglets
      const tabButtons = Array.from(document.querySelectorAll('button')).filter(btn => 
        ['Dashboard', 'Playlists', 'Médias', 'YouTube', 'Programmation', 'Monitoring', 'Paramètres']
        .some(name => btn.textContent.includes(name))
      );
      
      // Chercher le logo
      const logo = document.querySelector('img[alt*="PiSignage"]');
      
      // Analyser le style
      return {
        fond: {
          couleur: bodyStyle.backgroundColor,
          estNoir: bodyStyle.backgroundColor === 'rgb(0, 0, 0)'
        },
        texte: {
          couleur: bodyStyle.color,
          estBlanc: bodyStyle.color === 'rgb(255, 255, 255)'
        },
        logo: {
          present: !!logo,
          src: logo ? logo.src : null
        },
        onglets: {
          nombre: tabButtons.length,
          textes: tabButtons.map(btn => btn.textContent.trim())
        },
        darkMode: document.documentElement.classList.contains('dark') || 
                 document.body.classList.contains('dark'),
        titre: document.title,
        conteneurPrincipal: !!document.querySelector('main')
      };
    });

    console.log(`🎨 Fond: ${homeAnalysis.fond.estNoir ? '✅ NOIR' : '❌ PAS NOIR'} (${homeAnalysis.fond.couleur})`);
    console.log(`📝 Texte: ${homeAnalysis.texte.estBlanc ? '✅ BLANC' : '❌ PAS BLANC'} (${homeAnalysis.texte.couleur})`);
    console.log(`🖼️  Logo: ${homeAnalysis.logo.present ? '✅ PRÉSENT' : '❌ ABSENT'}`);
    console.log(`📑 Onglets trouvés: ${homeAnalysis.onglets.nombre}`);
    if (homeAnalysis.onglets.nombre > 0) {
      console.log(`   Onglets: ${homeAnalysis.onglets.textes.join(', ')}`);
    }
    console.log(`🌙 Dark mode: ${homeAnalysis.darkMode ? '✅ ACTIF' : '❌ INACTIF'}`);
    console.log(`📄 Titre: ${homeAnalysis.titre}\n`);

    // Screenshot page d'accueil
    await page.screenshot({ 
      path: 'screenshots/00-accueil.png',
      fullPage: true 
    });
    console.log(`📸 Screenshot page d'accueil: screenshots/00-accueil.png\n`);

    // Tester chaque onglet
    for (let i = 0; i < TABS.length; i++) {
      const tab = TABS[i];
      console.log(`\n${'='.repeat(60)}`);
      console.log(`📌 TEST ONGLET ${i+1}/${TABS.length}: ${tab.name.toUpperCase()}`);
      console.log(`${'='.repeat(60)}\n`);
      
      try {
        // Chercher et cliquer sur l'onglet par son texte
        console.log(`🔍 Recherche du bouton "${tab.text}"...`);
        
        const buttonFound = await page.evaluate((tabText) => {
          const buttons = Array.from(document.querySelectorAll('button'));
          const button = buttons.find(btn => btn.textContent.trim() === tabText);
          if (button) {
            button.click();
            return true;
          }
          return false;
        }, tab.text);

        if (!buttonFound) {
          console.log(`❌ ERREUR: Bouton "${tab.text}" non trouvé!`);
          continue;
        }

        console.log(`✅ Clic effectué sur "${tab.text}"`);
        
        // Attendre le chargement du contenu
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Analyser le contenu de l'onglet
        const tabAnalysis = await page.evaluate((tabName) => {
          // Chercher le contenu principal
          const main = document.querySelector('main');
          const allElements = main ? main.querySelectorAll('*') : [];
          
          // Compter les différents types d'éléments
          const cards = document.querySelectorAll('[class*="card"]').length;
          const buttons = document.querySelectorAll('button').length;
          const inputs = document.querySelectorAll('input, select, textarea').length;
          const tables = document.querySelectorAll('table').length;
          const images = document.querySelectorAll('img').length;
          const sections = document.querySelectorAll('section, article, [class*="container"]').length;
          
          // Texte visible
          const visibleText = main ? main.innerText : '';
          
          // Chercher des éléments spécifiques selon l'onglet
          let specificElements = {};
          
          if (tabName.includes('Dashboard')) {
            specificElements = {
              vlcControl: !!document.querySelector('[class*="vlc"], [class*="VLC"]'),
              systemInfo: !!document.querySelector('[class*="system"], [class*="System"]'),
              networkInfo: !!document.querySelector('[class*="network"], [class*="réseau"]')
            };
          } else if (tabName.includes('Playlist')) {
            specificElements = {
              playlistItems: document.querySelectorAll('[class*="playlist"]').length,
              addButton: !!Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('Ajouter'))
            };
          } else if (tabName.includes('Media') || tabName.includes('Médias')) {
            specificElements = {
              uploadZone: !!document.querySelector('[class*="upload"], [type="file"]'),
              mediaGrid: !!document.querySelector('[class*="grid"]')
            };
          }
          
          return {
            totalElements: allElements.length,
            cards,
            buttons,
            inputs,
            tables,
            images,
            sections,
            textLength: visibleText.length,
            hasContent: visibleText.length > 50,
            specificElements,
            firstText: visibleText.substring(0, 200).replace(/\n+/g, ' ')
          };
        }, tab.name);
        
        // Afficher l'analyse
        console.log(`\n📊 Analyse du contenu:`);
        console.log(`   • Total éléments: ${tabAnalysis.totalElements}`);
        console.log(`   • Cards: ${tabAnalysis.cards}`);
        console.log(`   • Boutons: ${tabAnalysis.buttons}`);
        console.log(`   • Inputs: ${tabAnalysis.inputs}`);
        console.log(`   • Tables: ${tabAnalysis.tables}`);
        console.log(`   • Images: ${tabAnalysis.images}`);
        console.log(`   • Sections: ${tabAnalysis.sections}`);
        console.log(`   • Longueur texte: ${tabAnalysis.textLength} caractères`);
        
        if (Object.keys(tabAnalysis.specificElements).length > 0) {
          console.log(`\n   Éléments spécifiques:`);
          for (const [key, value] of Object.entries(tabAnalysis.specificElements)) {
            console.log(`   • ${key}: ${value}`);
          }
        }
        
        if (tabAnalysis.hasContent) {
          console.log(`\n   ✅ L'onglet contient du contenu`);
          console.log(`   Aperçu: "${tabAnalysis.firstText.substring(0, 100)}..."`);
        } else {
          console.log(`\n   ⚠️  ATTENTION: Très peu de contenu dans cet onglet!`);
        }
        
        // Prendre un screenshot
        const screenshotPath = `screenshots/${String(i + 1).padStart(2, '0')}-${tab.id}.png`;
        await page.screenshot({ 
          path: screenshotPath,
          fullPage: true 
        });
        console.log(`\n📸 Screenshot sauvegardé: ${screenshotPath}`);
        
      } catch (error) {
        console.log(`\n❌ ERREUR lors du test de l'onglet ${tab.name}:`);
        console.log(`   ${error.message}`);
      }
    }

    // Résumé final
    console.log(`\n${'='.repeat(60)}`);
    console.log('📊 RÉSUMÉ FINAL');
    console.log(`${'='.repeat(60)}\n`);
    
    console.log(`Total erreurs console: ${allErrors.length}`);
    console.log(`Total warnings console: ${allWarnings.length}`);
    
    if (allErrors.length > 0) {
      console.log(`\n🔴 Erreurs console uniques:`);
      const uniqueErrors = [...new Set(allErrors)];
      uniqueErrors.forEach((err, idx) => {
        console.log(`   ${idx + 1}. ${err.substring(0, 100)}`);
      });
    }
    
    // Lister les screenshots créés
    console.log('\n📸 Screenshots créés:');
    const files = await fs.readdir('screenshots');
    for (const file of files.sort()) {
      console.log(`   • ${file}`);
    }

  } catch (error) {
    console.error('\n💥 Erreur fatale:', error);
  } finally {
    await browser.close();
  }

  console.log('\n✅ TEST TERMINÉ\n');
}

// Lancer le test
testAllTabs().catch(console.error);