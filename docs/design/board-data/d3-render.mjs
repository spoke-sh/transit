// Reproduce design figures and exercise local presentation. No Transit calls.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const require = createRequire(new URL('../../handbook/package.json', import.meta.url));
const { chromium } = require('@playwright/test');
const root = fileURLToPath(new URL('.', import.meta.url));
const browser = await chromium.launch({ headless: true });
const report = [];
const pageErrors = [];
const remoteRequests = [];
const entry = screen => new URL('d3.html#' + screen, import.meta.url).href;
async function audit(page, label) {
  const measurements = await page.evaluate(() => ({
    width: innerWidth,
    overflow: document.documentElement.scrollWidth > innerWidth + 1,
    inspectors: document.querySelectorAll('.inspector').length,
    canvas: document.querySelector('.canvas').getBoundingClientRect().width,
    inspector: document.querySelector('.inspector')?.getBoundingClientRect().width ?? 0,
    state: window.BOARD_D3_STATE,
  }));
  assert.equal(measurements.overflow, false, label + ' must not overflow the viewport');
  assert.ok(measurements.inspectors <= 1, label + ' must have at most one inspector');
  report.push({ label, ...measurements });
}
async function open(page, screen) {
  await page.goto(entry(screen));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForFunction(value => window.BOARD_D3_STATE?.screen === value, screen);
  await page.evaluate(() => window.scrollTo(0, 0));
}
const action = (page, name) => page.locator('[data-action="' + name + '"]');
try {
  await mkdir(join(root, 'images'), { recursive: true });
  for (const [width, height] of [[1920, 1200], [1440, 1000], [1280, 900], [720, 900], [390, 844]]) {
    const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 2 });
    page.on('pageerror', error => pageErrors.push(String(error)));
    page.on('request', request => { if (/^https?:/.test(request.url())) remoteRequests.push(request.url()); });
    for (const screen of ['dataset', 'workbook', 'changes']) {
      await open(page, screen);
      await audit(page, screen + ' initial');
      if (width === 1440) {
        const name = { dataset: '01-dataset', workbook: '03-workbook', changes: '04-changes' }[screen];
        await page.screenshot({ path: join(root, 'images', 'd3-' + name + '.png') });
      }
      if (width <= 1000) {
        await action(page, 'inspect').click();
        assert.equal(await page.locator('.canvas').isVisible(), false, 'Narrow inspector replaces the canvas');
        assert.equal(await page.locator(':focus').getAttribute('data-action'), 'close-inspector');
        assert.equal(await page.locator(screen === 'changes' ? '.comparison-basis' : '.narrow-evidence').isVisible(), true);
      }
      await audit(page, screen + ' inspector open');
      if (width === 1280 && screen === 'dataset') {
        await page.screenshot({ path: join(root, 'images', 'd3-05-dataset-laptop.png') });
        assert.ok(await page.locator('.canvas').evaluate(node => node.clientWidth) >= 900);
        assert.ok(await page.locator('.result-status').evaluate(node => node.getBoundingClientRect().bottom <= innerHeight), 'Laptop preview coverage remains in the initial viewport');
      }
      if (width === 1920 && screen === 'dataset') {
        await action(page, 'navigator').click();
        await audit(page, 'wide navigator and inspector');
        await page.screenshot({ path: join(root, 'images', 'd3-06-dataset-wide.png') });
        await action(page, 'navigator').click();
      }
      // Close and reopen through keyboard while preserving the selected subject.
      const selection = await page.evaluate(() => window.BOARD_D3_STATE.selected);
      await page.keyboard.press('Escape');
      assert.equal(await page.locator('.inspector').count(), 0);
      assert.equal(await page.locator(':focus').getAttribute('data-action'), 'inspect');
      await page.keyboard.press('Enter');
      assert.equal(await page.evaluate(() => window.BOARD_D3_STATE.selected), selection);
      assert.equal(await page.locator('.inspector').count(), 1);
      await action(page, 'full-detail').click();
      assert.equal(await page.locator('.inspector').count(), 0);
      assert.equal(await page.locator('.full-detail').count(), 1);
      await audit(page, screen + ' expanded detail');
      await action(page, 'back-detail').click();
      assert.equal(await page.locator('.inspector').count(), 1);
    }
    await open(page, 'dataset');
    const totals = await page.evaluate(() => {
      const p = window.BOARD_D3_FIXTURE.profile;
      const s = window.BOARD_D3_FIXTURE.storage;
      return [p.values + p.nulls, p.bins.reduce((n, b) => n + b.count, 0), s.sharedMiB + s.exclusiveMiB];
    });
    assert.deepEqual(totals, [24, 22, 64]);
    // Column and object details share the same dock; no nested inspector.
    if (width <= 1000) await action(page, 'inspect').click();
    await action(page, 'select-table').click();
    await page.getByRole('button', { name: 'Storage', exact: true }).click();
    await audit(page, 'storage dimension');
    assert.match(await page.locator('#inspector-detail').innerText(), /Reclaimable bytes\s+Unavailable/);
    if (width === 1440) await page.screenshot({ path: join(root, 'images', 'd3-02-storage.png') });
    await action(page, 'close-inspector').click();
    await page.locator('.table-scroll').evaluate(node => { node.scrollTop = 90; });
    const scrollBefore = await page.locator('.table-scroll').evaluate(node => node.scrollTop);
    await action(page, 'select-row').nth(2).click();
    assert.equal(await page.locator('.inspector h2').innerText(), 'S-403');
    await action(page, 'close-inspector').click();
    assert.equal(await page.locator(':focus').getAttribute('data-index'), '2');
    assert.equal(await page.locator('.table-scroll').evaluate(node => node.scrollTop), scrollBefore);
    // Draft edits leave fixture SQL, completion and observation intact.
    await open(page, 'workbook');
    await page.locator('#sql-draft').fill('SELECT region FROM public.shipments;');
    assert.match(await page.locator('#draft-state').innerText(), /Earlier result/);
    await action(page, 'run').click();
    assert.match(await page.locator('#announcement').innerText(), /No SQL was submitted/);
    assert.match(await page.locator('.result-status').first().innerText(), /3 result rows verified/);
    assert.match(await page.locator('.result-status').first().innerText(), /main@c104/);
    await action(page, 'select-operator').click();
    assert.equal(await page.locator('.inspector h2').innerText(), 'Scan shipments');
    await action(page, 'close-inspector').click();
    // Selection must follow the row, with fixed base/source/target inputs.
    await open(page, 'changes');
    await action(page, 'select-change').nth(1).click();
    assert.match(await page.locator('.inspector h2').innerText(), /S-409/);
    await action(page, 'close-inspector').click();
    assert.equal(await page.locator(':focus').getAttribute('data-index'), '1');
    assert.match(await page.locator('.comparison-basis').innerText(), /c100/);
    assert.match(await page.locator('.comparison-basis').innerText(), /c108/);
    assert.match(await page.locator('.comparison-basis').innerText(), /c104/);
    await page.close();
  }
  assert.deepEqual(pageErrors, [], 'No browser script errors');
  assert.deepEqual(remoteRequests, [], 'No network service or external asset requests');
  console.log(JSON.stringify({ browser: browser.version(), checks: report, pageErrors, remoteRequests }, null, 2));
} finally {
  await browser.close();
}
