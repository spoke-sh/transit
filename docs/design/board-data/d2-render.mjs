// Capture the repository design prototype with the handbook's locked Playwright.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';

const require = createRequire(new URL('../../handbook/package.json', import.meta.url));
const { chromium } = require('@playwright/test');
const root = fileURLToPath(new URL('.', import.meta.url));
const browser = await chromium.launch({ headless: true });
const captures = [
  ['catalog', 'd2-01-catalog'], ['dataset', 'd2-02-dataset'],
  ['relationships', 'd2-03-relationships'], ['workbook', 'd2-04-workbook'],
  ['lineage', 'd2-05-lineage'], ['branch-review', 'd2-06-branch-review'],
  ['ddl-preview', 'd2-07-ddl-preview'],
];
const report = [];
try {
  await mkdir(join(root, 'images'), { recursive: true });
  for (const [width, height, scale, suffix] of [[2560,1600,2,''],[1440,1000,2,'-laptop']]) {
    const page = await browser.newPage({ viewport:{width,height}, deviceScaleFactor:scale });
    const errors=[];
    page.on('pageerror', error => errors.push(String(error)));
    for (const [screen, filename] of captures) {
      await page.goto(new URL(`d2.html#${screen}`, import.meta.url).href);
      await page.evaluate(() => document.fonts.ready);
      await page.waitForFunction(key => window.BOARD_D2_SCREEN === key, screen);
      await page.evaluate(() => new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
      const audit = await page.evaluate(() => {
        const main=document.querySelector('main');
        const active=document.querySelector('.screen.active');
        const overflowing=[...active.querySelectorAll('table,.panel,.entity,.flow-node')]
          .filter(el=>el.scrollWidth>el.clientWidth+2).map(el=>el.className);
        const counts=window.BOARD_D2.counts;
        return {
          horizontalOverflow:main.scrollWidth>main.clientWidth+2,
          contentHeight:active.scrollHeight,
          viewportContentHeight:main.clientHeight,
          overflowing,
          profileCount:Object.values(counts).reduce((a,b)=>a+b,0),
          distributionCount:window.BOARD_D2.distribution.reduce((n,b)=>n+b.count,0),
        };
      });
      if(errors.length || audit.horizontalOverflow || audit.overflowing.length || audit.profileCount!==100 || audit.distributionCount!==82) {
        throw new Error(JSON.stringify({screen,width,errors,...audit}));
      }
      if(!suffix || screen==='dataset') {
        await page.screenshot({ path:join(root,'images',`${filename}${suffix}.png`), fullPage:false });
      }
      report.push({screen,width,height,scale,...audit});
    }
    // Verify the local prototype's useful interactions without claiming runtime behavior.
    await page.goto(new URL('d2.html#catalog', import.meta.url).href);
    await page.locator('#catalog-filter').fill('delivery_notes');
    if(await page.locator('#catalog-rows tr:visible').count()!==1) throw new Error('Catalog filter failed');
    await page.locator('#catalog-rows tr:visible a').click();
    await page.waitForFunction(()=>window.BOARD_D2_SCREEN==='dataset');
    if(suffix) {
      await page.locator('#profile-toggle').click();
      if(!await page.locator('.screen.active .profile').isVisible()) throw new Error('Profile toggle failed');
      const overflow = await page.evaluate(() => {
        const table=document.querySelector('.screen.active .data-grid');
        return table.getBoundingClientRect().width>table.parentElement.clientWidth+2;
      });
      if(overflow) throw new Error('Laptop profile clips the data grid');
      await page.locator('#profile-toggle').click();
    }
    await page.close();
  }
  const output={browser:browser.version(),captures:report};
  // Evidence goes to stdout; do not create a changing generated report in Git.
  console.log(JSON.stringify(output,null,2));
} finally {
  await browser.close();
}
