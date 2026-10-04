#!/usr/bin/env node
/**
 * Re-renders docs/screenshots/*.png (the README images) from the retro
 * prototype in design/prototype, at iPhone size (390x844 @2x).
 *
 * The native app is the product and the prototype is its design spec, so these
 * images are the prototype with the few things the native app doesn't have
 * left out:
 *   - the Duit Terminal window (removed from the app),
 *   - the "Demo: jump to payday" link (a prototype-only shortcut).
 * The prototype loads its fonts from Google Fonts; here the same three
 * families are served from the copies the app bundles
 * (ios/Duit/Resources/Fonts), so this works offline and matches the app.
 *
 * Usage (Playwright must be installed; use its default headless Chromium):
 *   node design/render-readme-screenshots.cjs
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'docs/screenshots');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.ttf': 'font/ttf', '.webmanifest': 'application/manifest+json' };

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const file = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
      if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        res.writeHead(404).end();
        return;
      }
      res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
      fs.createReadStream(file).pipe(res);
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

const fontCss = (base) => {
  const f = (family, weight, file) =>
    `@font-face{font-family:'${family}';font-weight:${weight};src:url(${base}/ios/Duit/Resources/Fonts/${file});font-display:block}`;
  return [
    f('IBM Plex Mono', 400, 'IBMPlexMono-Regular.ttf'),
    f('IBM Plex Mono', 500, 'IBMPlexMono-Medium.ttf'),
    f('IBM Plex Mono', 600, 'IBMPlexMono-SemiBold.ttf'),
    f('IBM Plex Mono', 700, 'IBMPlexMono-Bold.ttf'),
    f('Silkscreen', 400, 'Silkscreen-Regular.ttf'),
    f('Silkscreen', 700, 'Silkscreen-Bold.ttf'),
    f('VT323', 400, 'VT323-Regular.ttf'),
  ].join('\n');
};

async function main() {
  const server = await serve();
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({ args: ['--no-sandbox'] });

  async function open() {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, colorScheme: 'light' });
    const page = await context.newPage();
    await page.route('https://fonts.googleapis.com/**', (r) => r.fulfill({ contentType: 'text/css', body: fontCss(base) }));
    await page.route('https://fonts.gstatic.com/**', (r) => r.abort());
    page.on('pageerror', (e) => console.error('page error:', String(e)));
    await page.goto(`${base}/design/prototype/index.html`);
    await page.waitForTimeout(1200);
    await page.evaluate(() => document.fonts.ready);
    return page;
  }

  async function tab(page, name) {
    await page.locator('.taskbar button', { hasText: name }).click();
    await page.waitForTimeout(450);
  }

  async function snap(page, file) {
    await page.evaluate(() => {
      for (const h of document.querySelectorAll('h2.wtitle')) {
        if (h.textContent.trim() === 'Duit Terminal') h.closest('.win').style.display = 'none';
      }
      for (const b of document.querySelectorAll('button.linkbtn')) {
        if (b.textContent.includes('Demo')) b.parentElement.style.display = 'none';
      }
    });
    await page.waitForTimeout(150);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(OUT, file) });
    console.log('wrote docs/screenshots/' + file);
  }

  let page = await open();
  await snap(page, 'retro-today.png');
  await tab(page, 'Add');
  await snap(page, 'retro-add-expense.png');
  await page.close();

  page = await open();
  await tab(page, 'Activity');
  await snap(page, 'retro-activity.png');
  await tab(page, 'Insights');
  await snap(page, 'retro-insights.png');
  await tab(page, 'Settings');
  await snap(page, 'retro-settings.png');
  await page.getByRole('radio', { name: /^Night/ }).click();
  await page.waitForTimeout(300);
  await tab(page, 'Today');
  await snap(page, 'retro-today-night.png');
  await page.close();

  page = await open();
  await tab(page, 'Settings');
  await page.getByRole('radio', { name: /^Arcade/ }).click();
  await page.waitForTimeout(300);
  await tab(page, 'Today');
  await snap(page, 'retro-today-arcade.png');

  await browser.close();
  server.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
