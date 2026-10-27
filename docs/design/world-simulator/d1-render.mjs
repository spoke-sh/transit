// Capture the world-simulator D1 spatial workbench at 2560x1600 @ 2x (5120x3200 PNGs).
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';

const require = createRequire(new URL('../../handbook/package.json', import.meta.url));
const { chromium } = require('@playwright/test');
const root = fileURLToPath(new URL('.', import.meta.url));

const captures = [
  ['macro-map', 'd1-01-macro-world-map'],
  ['faction-archeology', 'd1-02-faction-archeology'],
  ['simready-dock', 'd1-03-isometric-simready-dock'],
  ['agent-pov', 'd1-04-agent-pov-control'],
  ['modernization-loop', 'd1-05-modernization-loop'],
  ['mmo-mainnet', 'd1-06-mmo-mainnet-epochs'],
];

const browser = await chromium.launch({ headless: true });
const report = [];

try {
  await mkdir(join(root, 'images'), { recursive: true });
  const page = await browser.newPage({
    viewport: { width: 2560, height: 1600 },
    deviceScaleFactor: 2,
  });
  const errors = [];
  page.on('pageerror', err => errors.push(String(err)));

  for (const [screen, filename] of captures) {
    await page.goto(new URL(`d1.html#${screen}`, import.meta.url).href);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForFunction(key => window.WORLD_SIM_D1_SCREEN === key, screen);
    await page.evaluate(async () => {
      const imgs = [...document.querySelectorAll('.screen.active img')];
      await Promise.all(
        imgs.map(img =>
          img.complete
            ? Promise.resolve()
            : new Promise((resolve, reject) => {
                img.addEventListener('load', resolve, { once: true });
                img.addEventListener('error', reject, { once: true });
              })
        )
      );
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    });

    const audit = await page.evaluate(() => {
      const main = document.querySelector('main');
      const active = document.querySelector('.screen.active');
      const overflowing = [...active.querySelectorAll('.panel, .dock-col, .bottom-strip')]
        .filter(el => el.scrollHeight > el.clientHeight + 2 || el.scrollWidth > el.clientWidth + 2)
        .map(el => el.className);
      const totalCells = Object.values(window.WORLD_SIM_D1.counts).reduce((a, b) => a + b, 0);
      return {
        horizontalOverflow: main.scrollWidth > main.clientWidth + 2,
        verticalOverflow: main.scrollHeight > main.clientHeight + 2,
        overflowing,
        totalCells,
      };
    });

    if (errors.length || audit.horizontalOverflow || audit.verticalOverflow || audit.overflowing.length || audit.totalCells !== 1000) {
      throw new Error(JSON.stringify({ screen, errors, ...audit }));
    }

    await page.screenshot({
      path: join(root, 'images', `${filename}.png`),
      fullPage: false,
    });
    report.push({ screen, filename: `${filename}.png`, resolution: '5120x3200', ...audit });
  }

  await page.close();
  console.log(JSON.stringify({ browser: browser.version(), captures: report }, null, 2));
} finally {
  await browser.close();
}
