/**
 * PiSignage v0.8.5 - Responsive Design Audit
 * Tests complets sur 3 viewports (Mobile, Tablet, Desktop)
 * 4 modules à auditer : Dashboard, Media, Playlists, Player
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// Configuration
const BASE_URL = 'http://localhost';
const SCREENSHOT_DIR = '/opt/pisignage/tests/screenshots/responsive';
const REPORT_PATH = '/opt/pisignage/tests/responsive-report.json';

// Définition des viewports à tester
const viewports = {
  mobile: {
    width: 375,
    height: 667,
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true
  },
  tablet: {
    width: 768,
    height: 1024,
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true
  },
  desktop: {
    width: 1920,
    height: 1080,
    deviceScaleFactor: 1,
    isMobile: false,
    hasTouch: false
  }
};

// Modules à tester
const modules = [
  { name: 'dashboard', path: '/dashboard.php', title: 'Dashboard' },
  { name: 'media', path: '/media.php', title: 'Media' },
  { name: 'playlists', path: '/playlists.php', title: 'Playlists' },
  { name: 'player', path: '/player.php', title: 'Player' }
];

// Résultats globaux
const results = {
  date: new Date().toISOString(),
  viewports_tested: Object.keys(viewports).length,
  modules_tested: modules.length,
  total_tests: 0,
  passed: 0,
  failed: 0,
  issues: [],
  screenshots: [],
  tests_by_viewport: {},
  tests_by_module: {}
};

/**
 * Test si un élément est visible dans le viewport
 */
async function isElementVisible(page, selector) {
  try {
    const element = await page.$(selector);
    if (!element) return false;

    const boundingBox = await element.boundingBox();
    if (!boundingBox) return false;

    const viewport = page.viewport();
    return boundingBox.x >= 0 &&
           boundingBox.y >= 0 &&
           boundingBox.x + boundingBox.width <= viewport.width &&
           boundingBox.y + boundingBox.height <= viewport.height;
  } catch (error) {
    return false;
  }
}

/**
 * Test si un élément déborde horizontalement
 */
async function hasHorizontalOverflow(page) {
  return await page.evaluate(() => {
    return document.documentElement.scrollWidth > document.documentElement.clientWidth;
  });
}

/**
 * Vérifie la taille minimale des touch targets (44x44px)
 */
async function checkTouchTargets(page, viewportName) {
  return await page.evaluate((isMobile) => {
    const MIN_SIZE = 44; // 44px recommandé WCAG
    const issues = [];

    if (!isMobile) return issues; // Seulement sur mobile/tablet

    const interactiveElements = document.querySelectorAll('button, a, input[type="button"], input[type="submit"], .btn, .control-btn, .nav-item');

    interactiveElements.forEach((el, index) => {
      const rect = el.getBoundingClientRect();
      if (rect.width < MIN_SIZE || rect.height < MIN_SIZE) {
        issues.push({
          selector: el.className || el.tagName,
          width: Math.round(rect.width),
          height: Math.round(rect.height),
          text: el.textContent?.trim().substring(0, 30) || ''
        });
      }
    });

    return issues;
  }, viewportName !== 'desktop');
}

/**
 * Vérifie la taille minimale du texte
 */
async function checkTextSize(page) {
  return await page.evaluate(() => {
    const MIN_FONT_SIZE = 14; // 14px minimum
    const issues = [];

    const textElements = document.querySelectorAll('p, span, div, a, button, label, li');

    textElements.forEach((el) => {
      const style = window.getComputedStyle(el);
      const fontSize = parseFloat(style.fontSize);

      if (fontSize < MIN_FONT_SIZE && el.textContent.trim().length > 0) {
        issues.push({
          selector: el.className || el.tagName,
          fontSize: Math.round(fontSize),
          text: el.textContent.trim().substring(0, 30)
        });
      }
    });

    return issues;
  });
}

/**
 * Vérifie l'état de la navigation/sidebar
 */
async function checkNavigation(page, viewportName) {
  const issues = [];

  // Vérifier si la sidebar existe
  const sidebar = await page.$('.sidebar');
  if (!sidebar) {
    issues.push({
      type: 'missing-element',
      message: 'Sidebar not found',
      severity: 'high'
    });
    return issues;
  }

  // Sur mobile/tablet, vérifier que le menu toggle est visible
  if (viewportName !== 'desktop') {
    const menuToggle = await page.$('.menu-toggle');
    if (!menuToggle) {
      issues.push({
        type: 'missing-toggle',
        message: 'Menu toggle button not found on mobile/tablet',
        severity: 'high'
      });
    } else {
      const isVisible = await isElementVisible(page, '.menu-toggle');
      if (!isVisible) {
        issues.push({
          type: 'hidden-toggle',
          message: 'Menu toggle button not visible on mobile/tablet',
          severity: 'high'
        });
      }
    }

    // Vérifier que la sidebar est cachée par défaut sur mobile
    const sidebarTransform = await page.evaluate(() => {
      const sidebar = document.querySelector('.sidebar');
      return window.getComputedStyle(sidebar).transform;
    });

    if (!sidebarTransform.includes('matrix')) {
      issues.push({
        type: 'sidebar-visible',
        message: 'Sidebar should be hidden by default on mobile/tablet',
        severity: 'medium'
      });
    }
  }

  return issues;
}

/**
 * Test un module sur un viewport spécifique
 */
async function testModuleOnViewport(browser, module, viewportName, viewportConfig) {
  console.log(`\n📱 Testing ${module.name} on ${viewportName} (${viewportConfig.width}x${viewportConfig.height})`);

  const page = await browser.newPage();
  await page.setViewport(viewportConfig);

  const moduleResults = {
    module: module.name,
    viewport: viewportName,
    viewport_size: `${viewportConfig.width}x${viewportConfig.height}`,
    tests_run: 0,
    tests_passed: 0,
    tests_failed: 0,
    issues: [],
    screenshots: []
  };

  try {
    // Charger la page
    const url = `${BASE_URL}${module.path}`;
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 10000 });
    await new Promise(resolve => setTimeout(resolve, 1000)); // Attendre les animations

    // Screenshot initial
    const screenshotPath = path.join(SCREENSHOT_DIR, viewportName, `${module.name}-initial.png`);
    await page.screenshot({ path: screenshotPath, fullPage: true });
    moduleResults.screenshots.push(screenshotPath);
    results.screenshots.push(screenshotPath);
    console.log(`  ✓ Screenshot initial: ${screenshotPath}`);

    // TEST 1: Vérifier débordement horizontal
    moduleResults.tests_run++;
    results.total_tests++;
    const hasOverflow = await hasHorizontalOverflow(page);
    if (hasOverflow) {
      const issue = {
        module: module.name,
        viewport: viewportName,
        severity: 'high',
        type: 'horizontal-overflow',
        issue: 'Page has horizontal scrollbar (content overflows)',
        selector: 'body',
        recommendation: 'Add overflow-x: hidden or fix width constraints in responsive.css'
      };
      moduleResults.issues.push(issue);
      results.issues.push(issue);
      moduleResults.tests_failed++;
      results.failed++;
      console.log(`  ✗ Horizontal overflow detected`);
    } else {
      moduleResults.tests_passed++;
      results.passed++;
      console.log(`  ✓ No horizontal overflow`);
    }

    // TEST 2: Vérifier taille des touch targets
    moduleResults.tests_run++;
    results.total_tests++;
    const touchIssues = await checkTouchTargets(page, viewportName);
    if (touchIssues.length > 0) {
      touchIssues.forEach(touch => {
        const issue = {
          module: module.name,
          viewport: viewportName,
          severity: viewportName === 'mobile' ? 'high' : 'medium',
          type: 'touch-target-too-small',
          issue: `Touch target too small: ${touch.width}x${touch.height}px (min 44x44px)`,
          selector: touch.selector,
          element_text: touch.text,
          recommendation: `Increase padding or min-width/min-height to 44px in responsive.css @media (max-width: ${viewportConfig.width}px)`
        };
        moduleResults.issues.push(issue);
        results.issues.push(issue);
      });
      moduleResults.tests_failed++;
      results.failed++;
      console.log(`  ✗ Found ${touchIssues.length} touch targets too small`);
    } else {
      moduleResults.tests_passed++;
      results.passed++;
      console.log(`  ✓ All touch targets are adequate size`);
    }

    // TEST 3: Vérifier taille du texte
    moduleResults.tests_run++;
    results.total_tests++;
    const textIssues = await checkTextSize(page);
    if (textIssues.length > 5) { // Tolérance: max 5 petits textes
      const issue = {
        module: module.name,
        viewport: viewportName,
        severity: 'medium',
        type: 'text-too-small',
        issue: `Found ${textIssues.length} text elements smaller than 14px`,
        selector: 'various',
        recommendation: 'Increase base font-size in responsive.css or add specific rules for small text'
      };
      moduleResults.issues.push(issue);
      results.issues.push(issue);
      moduleResults.tests_failed++;
      results.failed++;
      console.log(`  ✗ ${textIssues.length} text elements too small`);
    } else {
      moduleResults.tests_passed++;
      results.passed++;
      console.log(`  ✓ Text sizes are readable`);
    }

    // TEST 4: Vérifier navigation
    moduleResults.tests_run++;
    results.total_tests++;
    const navIssues = await checkNavigation(page, viewportName);
    if (navIssues.length > 0) {
      navIssues.forEach(navIssue => {
        const issue = {
          module: module.name,
          viewport: viewportName,
          severity: navIssue.severity,
          type: navIssue.type,
          issue: navIssue.message,
          selector: '.sidebar, .menu-toggle',
          recommendation: 'Check responsive.css media queries for sidebar and menu-toggle display rules'
        };
        moduleResults.issues.push(issue);
        results.issues.push(issue);
      });
      moduleResults.tests_failed++;
      results.failed++;
      console.log(`  ✗ Navigation issues found`);
    } else {
      moduleResults.tests_passed++;
      results.passed++;
      console.log(`  ✓ Navigation is properly responsive`);
    }

    // TEST 5: Interaction - Cliquer sur premier bouton visible
    moduleResults.tests_run++;
    results.total_tests++;
    try {
      const firstButton = await page.$('button, .btn, .control-btn');
      if (firstButton) {
        await firstButton.click();
        await new Promise(resolve => setTimeout(resolve, 500));

        const screenshotInteraction = path.join(SCREENSHOT_DIR, viewportName, `${module.name}-interaction.png`);
        await page.screenshot({ path: screenshotInteraction, fullPage: true });
        moduleResults.screenshots.push(screenshotInteraction);
        results.screenshots.push(screenshotInteraction);

        moduleResults.tests_passed++;
        results.passed++;
        console.log(`  ✓ Interaction test passed (button clickable)`);
      } else {
        moduleResults.tests_passed++;
        results.passed++;
        console.log(`  ✓ No interactive buttons to test`);
      }
    } catch (error) {
      const issue = {
        module: module.name,
        viewport: viewportName,
        severity: 'low',
        type: 'interaction-failed',
        issue: `Button interaction failed: ${error.message}`,
        selector: 'button',
        recommendation: 'Check button z-index and click handlers'
      };
      moduleResults.issues.push(issue);
      results.issues.push(issue);
      moduleResults.tests_failed++;
      results.failed++;
      console.log(`  ✗ Interaction test failed`);
    }

    // TEST 6: Vérifier si les modals sont responsive (si présents)
    moduleResults.tests_run++;
    results.total_tests++;
    const modalCheck = await page.evaluate(() => {
      const modals = document.querySelectorAll('.modal, .modal-content');
      if (modals.length === 0) return { hasModals: false };

      const issues = [];
      modals.forEach(modal => {
        const rect = modal.getBoundingClientRect();
        if (rect.width > window.innerWidth) {
          issues.push({
            width: rect.width,
            viewportWidth: window.innerWidth
          });
        }
      });

      return { hasModals: true, issues };
    });

    if (modalCheck.hasModals && modalCheck.issues.length > 0) {
      const issue = {
        module: module.name,
        viewport: viewportName,
        severity: 'medium',
        type: 'modal-overflow',
        issue: `Modal wider than viewport: ${modalCheck.issues[0].width}px > ${modalCheck.issues[0].viewportWidth}px`,
        selector: '.modal, .modal-content',
        recommendation: 'Add max-width: 95% and proper margins in responsive.css modal rules'
      };
      moduleResults.issues.push(issue);
      results.issues.push(issue);
      moduleResults.tests_failed++;
      results.failed++;
      console.log(`  ✗ Modal overflow detected`);
    } else {
      moduleResults.tests_passed++;
      results.passed++;
      console.log(`  ✓ Modals are properly responsive`);
    }

    // TEST 7: Vérifier grids et layouts
    moduleResults.tests_run++;
    results.total_tests++;
    const gridCheck = await page.evaluate((viewportWidth) => {
      const grids = document.querySelectorAll('.grid, .system-stats-grid, .playlist-editor-container');
      const issues = [];

      grids.forEach(grid => {
        const style = window.getComputedStyle(grid);
        const gridCols = style.gridTemplateColumns;

        // Sur mobile, devrait être 1 colonne
        if (viewportWidth <= 768 && gridCols && !gridCols.includes('1fr') && gridCols.split(' ').length > 1) {
          issues.push({
            selector: grid.className,
            columns: gridCols.split(' ').length
          });
        }
      });

      return issues;
    }, viewportConfig.width);

    if (gridCheck.length > 0) {
      gridCheck.forEach(grid => {
        const issue = {
          module: module.name,
          viewport: viewportName,
          severity: 'medium',
          type: 'grid-not-responsive',
          issue: `Grid has ${grid.columns} columns on ${viewportName} (should be 1)`,
          selector: grid.selector,
          recommendation: `Add grid-template-columns: 1fr for .${grid.selector} in @media (max-width: ${viewportConfig.width}px)`
        };
        moduleResults.issues.push(issue);
        results.issues.push(issue);
      });
      moduleResults.tests_failed++;
      results.failed++;
      console.log(`  ✗ Grid layout issues found`);
    } else {
      moduleResults.tests_passed++;
      results.passed++;
      console.log(`  ✓ Grid layouts are properly responsive`);
    }

  } catch (error) {
    console.error(`  ✗ Error testing ${module.name} on ${viewportName}:`, error.message);
    const issue = {
      module: module.name,
      viewport: viewportName,
      severity: 'critical',
      type: 'page-load-error',
      issue: `Failed to load or test page: ${error.message}`,
      selector: 'N/A',
      recommendation: 'Check server availability and page integrity'
    };
    moduleResults.issues.push(issue);
    results.issues.push(issue);
    moduleResults.tests_failed += moduleResults.tests_run;
    results.failed += moduleResults.tests_run;
  } finally {
    await page.close();
  }

  // Statistiques par viewport/module
  if (!results.tests_by_viewport[viewportName]) {
    results.tests_by_viewport[viewportName] = { passed: 0, failed: 0, total: 0 };
  }
  if (!results.tests_by_module[module.name]) {
    results.tests_by_module[module.name] = { passed: 0, failed: 0, total: 0 };
  }

  results.tests_by_viewport[viewportName].passed += moduleResults.tests_passed;
  results.tests_by_viewport[viewportName].failed += moduleResults.tests_failed;
  results.tests_by_viewport[viewportName].total += moduleResults.tests_run;

  results.tests_by_module[module.name].passed += moduleResults.tests_passed;
  results.tests_by_module[module.name].failed += moduleResults.tests_failed;
  results.tests_by_module[module.name].total += moduleResults.tests_run;

  return moduleResults;
}

/**
 * Fonction principale
 */
async function runResponsiveAudit() {
  console.log('🚀 PiSignage v0.8.5 - Responsive Design Audit');
  console.log(`📅 Date: ${results.date}`);
  console.log(`🎯 Viewports: ${Object.keys(viewports).join(', ')}`);
  console.log(`📦 Modules: ${modules.map(m => m.name).join(', ')}`);
  console.log('═'.repeat(60));

  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu'
    ]
  });

  try {
    // Tester chaque combinaison viewport × module
    for (const [viewportName, viewportConfig] of Object.entries(viewports)) {
      for (const module of modules) {
        await testModuleOnViewport(browser, module, viewportName, viewportConfig);
      }
    }

    // Calculer taux de succès
    results.success_rate = results.total_tests > 0
      ? ((results.passed / results.total_tests) * 100).toFixed(2)
      : 0;

    // Trier les issues par sévérité
    const severityOrder = { critical: 0, high: 1, medium: 2, low: 3 };
    results.issues.sort((a, b) => severityOrder[a.severity] - severityOrder[b.severity]);

    // Sauvegarder rapport JSON
    fs.writeFileSync(REPORT_PATH, JSON.stringify(results, null, 2));

    // Afficher résumé
    console.log('\n' + '═'.repeat(60));
    console.log('📊 RÉSULTATS FINAUX');
    console.log('═'.repeat(60));
    console.log(`✅ Tests réussis: ${results.passed}/${results.total_tests} (${results.success_rate}%)`);
    console.log(`❌ Tests échoués: ${results.failed}/${results.total_tests}`);
    console.log(`🐛 Issues trouvées: ${results.issues.length}`);
    console.log(`📸 Screenshots: ${results.screenshots.length}`);

    console.log('\n📱 Résultats par Viewport:');
    Object.entries(results.tests_by_viewport).forEach(([viewport, stats]) => {
      const rate = ((stats.passed / stats.total) * 100).toFixed(1);
      console.log(`  ${viewport.padEnd(10)} ${stats.passed}/${stats.total} (${rate}%)`);
    });

    console.log('\n📦 Résultats par Module:');
    Object.entries(results.tests_by_module).forEach(([module, stats]) => {
      const rate = ((stats.passed / stats.total) * 100).toFixed(1);
      console.log(`  ${module.padEnd(12)} ${stats.passed}/${stats.total} (${rate}%)`);
    });

    console.log('\n🔥 Top 5 Issues Critiques:');
    const topIssues = results.issues
      .filter(i => i.severity === 'critical' || i.severity === 'high')
      .slice(0, 5);

    if (topIssues.length > 0) {
      topIssues.forEach((issue, index) => {
        console.log(`  ${index + 1}. [${issue.severity.toUpperCase()}] ${issue.module}/${issue.viewport}`);
        console.log(`     ${issue.issue}`);
        console.log(`     💡 ${issue.recommendation}`);
      });
    } else {
      console.log('  ✨ Aucune issue critique trouvée!');
    }

    console.log('\n📄 Rapport complet: ' + REPORT_PATH);
    console.log('📸 Screenshots: ' + SCREENSHOT_DIR);
    console.log('═'.repeat(60));

  } catch (error) {
    console.error('❌ Erreur fatale:', error);
    throw error;
  } finally {
    await browser.close();
  }
}

// Lancer l'audit
runResponsiveAudit()
  .then(() => {
    console.log('\n✅ Audit terminé avec succès!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Audit échoué:', error);
    process.exit(1);
  });
