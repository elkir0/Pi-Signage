const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.goto('http://192.168.1.103/', { waitUntil: 'networkidle0' });

  // Check navigation items
  const navItems = await page.$$eval('.nav-item', items =>
    items.map(i => ({
      text: i.textContent.trim(),
      onclick: i.getAttribute('onclick')
    }))
  );

  console.log('Navigation items found:', navItems);

  // Check if showSection function exists
  const hasFn = await page.evaluate(() => typeof showSection === 'function');
  console.log('showSection function exists:', hasFn);

  await browser.close();
})();