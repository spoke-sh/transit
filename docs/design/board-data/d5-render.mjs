// Exercise the synthetic design, then capture figures. No Transit calls.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import './d5-model.js';

const require = createRequire(new URL('../../handbook/package.json', import.meta.url));
const { chromium } = require('@playwright/test');
const model = globalThis.BOARD_D5_MODEL;
let state = model.initial();
const step = event => {
  const next = model.reduce(state, event); state = next.state; return next.effects;
};
const edit = value => step({ type: 'EDIT', sql: model.initial().cells.a.sql.replace('15', String(value)) });
const ready = () => step({ type: 'READY', generation: state.generation });
const complete = run => step({ type: 'COMPLETE', run, rows: model.evaluate(run) });
const drain = () => { while (state.running) complete(state.running); };

// Layout transitions cannot change execution counts, output, or budget.
for (const event of [{ type: 'LEFT' }, { type: 'TAB', tab: 'assistant' }, { type: 'RIGHT' }]) {
  assert.deepEqual(step(event), []);
  assert.deepEqual(state.counts, { a: 1, b: 1, c: 1 });
}
step({ type: 'LIVE' }); edit(30); ready();
const obsolete = structuredClone(state.running);
edit(45); ready();
const effects = complete(obsolete);
assert.ok(effects.some(effect => effect.type === 'discard'));
assert.equal(state.cells.a.output.revision, 1, 'Obsolete result cannot attach to current draft');
assert.notEqual(state.running.id, obsolete.id);
drain();
assert.deepEqual(state.cells.a.output.rows, [['North', 48]]);
assert.deepEqual(state.cells.b.output.rows, [['North', 1]]);
assert.deepEqual(state.counts, { a: 2, b: 2, c: 1 });
assert.equal(state.remaining, 5, 'Superseded accepted work still consumes budget');
edit(99); ready(); drain();
assert.equal(state.cells.a.output.terminal, 0);
assert.equal(state.cells.b.output.terminal, 0, 'Complete empty upstream is a valid relation');
step({ type: 'EDIT', sql: 'SELECT broken' });
assert.deepEqual(ready(), []);
assert.equal(state.cells.b.status, 'blocked');
assert.equal(state.cells.a.output.terminal, 0, 'Invalid draft retains original attributed output');
edit(15); ready();
const admitted = state.sequence;
ready(); ready();
assert.equal(state.sequence, admitted, 'Debounce and blur cannot duplicate admission');
step({ type: 'LIVE' }); // Pause with accepted A in progress.
complete(state.running);
assert.equal(state.running, null);
assert.equal(state.cells.b.status, 'dirty', 'Pause must not launch a dependent');
const budgetBeforeResume = state.remaining;
step({ type: 'LIVE' }); drain();
assert.equal(state.remaining, budgetBeforeResume - 1, 'Resume uses original budget');
edit(30); ready(); drain();
assert.equal(state.mode, 'exhausted');
const exhaustedSequence = state.sequence;
edit(45); ready();
assert.equal(state.sequence, exhaustedSequence, 'Editing cannot renew exhausted budget');
console.log('D5 fixture transitions: obsolete replies, dependency inputs, empty relations, coalescing, pause and budget checks passed.');

const browser = await chromium.launch({ headless: true });
const errors = [], remote = [], geometry = [];
const images = fileURLToPath(new URL('images/', import.meta.url));
const entry = new URL('d5.html', import.meta.url).href;
await mkdir(images, { recursive: true });
const stateOf = page => page.evaluate(() => window.BOARD_D5_STATE);
async function audit(page, label) {
  const measurement = await page.evaluate(() => ({
    width: innerWidth,
    overflow: document.documentElement.scrollWidth > innerWidth + 1,
    center: document.querySelector('.work-area').getBoundingClientRect().width,
    right: document.querySelector('.right').getBoundingClientRect().width,
    active: document.querySelector('#plane').dataset.active,
  }));
  assert.equal(measurement.overflow, false, label + ' has no document overflow');
  assert.equal(await page.locator('[aria-label="Context pane"]').count(), 1);
  geometry.push({ label, ...measurement });
}
try {
  for (const [width, height] of [[1920, 1200], [1440, 1100], [1280, 1000], [1024, 900], [720, 900], [390, 844]]) {
    const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
    page.on('pageerror', error => errors.push(String(error)));
    page.on('request', request => { if (/^https?:/.test(request.url())) remote.push(request.url()); });
    page.on('dialog', dialog => dialog.accept());
    await page.goto(entry);
    await audit(page, 'closed ' + width);
    if (width === 1440) await page.screenshot({ path: images + 'd5-01-closed.png' });
    await page.locator('#left-toggle').click();
    if (width < 800) {
      await page.locator('#back').click();
      assert.equal(await page.locator('#left-toggle').getAttribute('aria-expanded'), 'false');
    }
    await page.locator('.right-rail [data-tab="inspector"]').click();
    await audit(page, 'open ' + width);
    if (width === 1440) await page.screenshot({ path: images + 'd5-02-open.png' });
    if (width === 390) await page.screenshot({ path: images + 'd5-04-narrow.png' });
    await page.locator('#tab-assistant').click();
    assert.equal(await page.locator('#assistant-panel').isVisible(), true);
    if (width === 1440) await page.screenshot({ path: images + 'd5-05-assistant.png' });
    await page.locator('#tab-assistant').press('ArrowLeft');
    assert.equal(await page.locator('#inspector-panel').isVisible(), true);
    assert.deepEqual((await stateOf(page)).counts, { a: 1, b: 1, c: 1 });
    await page.locator('#close-right').click();
    if (width < 800) assert.equal(await page.locator('#workspace').evaluate(el => el.inert), false);
    // Manual edit invalidates only its dependency closure.
    const sql = page.locator('#sql-a');
    await sql.fill(model.initial().cells.a.sql.replace('15', '30'));
    assert.equal((await stateOf(page)).cells.a.status, 'dirty');
    assert.equal((await stateOf(page)).cells.b.status, 'waiting');
    assert.equal((await stateOf(page)).cells.c.status, 'current');
    if (width === 1440) await page.screenshot({ path: images + 'd5-03-invalidated.png' });
    await page.locator('#live').click();
    await page.waitForFunction(() => window.BOARD_D5_STATE.cells.b.status === 'current');
    assert.deepEqual((await stateOf(page)).counts, { a: 2, b: 2, c: 1 });
    assert.equal((await stateOf(page)).remaining, 6);
    assert.deepEqual((await stateOf(page)).cells.a.output.rows, [['West', 32], ['North', 48], ['West', 42]]);
    // Blur flushes; delayed debounce must not start the graph a second time.
    await sql.fill(model.initial().cells.a.sql.replace('15', '45'));
    await page.locator('#unsaved').focus();
    await page.waitForFunction(() => window.BOARD_D5_STATE.cells.b.status === 'current');
    assert.deepEqual((await stateOf(page)).counts, { a: 3, b: 3, c: 1 });
    assert.equal((await stateOf(page)).remaining, 4);
    await page.locator('#cell-c .cell-name').click();
    assert.ok((await page.locator('#inspector-panel .path').textContent()).includes('total_shipments'));
    assert.ok(!(await page.locator('#inspector-panel .path').textContent()).includes('by_region'));
    await page.keyboard.press('Escape');
    assert.equal(await page.locator(':focus').textContent(), 'total_shipments');
    for (const route of ['catalog', 'operations', 'workbook']) {
      await page.locator(`[data-route="${route}"]`).click();
      await audit(page, route + ' ' + width);
    }
    assert.equal(await page.locator('#sql-a').inputValue(), model.initial().cells.a.sql.replace('15', '45'));
    assert.equal((await stateOf(page)).mode, 'paused', 'Returning does not resume execution');
    assert.equal((await stateOf(page)).selected, 'c', 'Activity navigation retains cell selection');
    assert.deepEqual((await stateOf(page)).counts, { a: 3, b: 3, c: 1 });
    await page.close();
  }
  assert.deepEqual(errors, []);
  assert.deepEqual(remote, []);
  console.log(JSON.stringify({ chromium: browser.version(), geometry, errors, remoteRequests: remote.length }, null, 2));
} finally {
  await browser.close();
}
