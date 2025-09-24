const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  console.log('📸 Capture finale PiSignage v0.8.0\n');

  await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0' });

  // Take dashboard screenshot
  await page.screenshot({ path: '/tmp/final-dashboard.png' });
  console.log('✅ Dashboard: /tmp/final-dashboard.png');

  // Navigate to each section and take screenshots
  const sections = ['media', 'playlists', 'youtube', 'player'];

  for (const section of sections) {
    await page.evaluate((s) => {
      if (typeof showSection === 'function') {
        showSection(s);
      }
    }, section);
    await page.waitForTimeout(500);

    await page.screenshot({ path: `/tmp/final-${section}.png` });
    console.log(`✅ ${section}: /tmp/final-${section}.png`);
  }

  console.log('\n✅ Toutes les captures sont prêtes!');
  await browser.close();
})();