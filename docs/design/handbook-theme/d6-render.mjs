// Reproduce the D6 figures and exercise the built study, using locked handbook tools.
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { mkdir } from "node:fs/promises";
import { join } from "node:path";
const require = createRequire(new URL("../../handbook/package.json", import.meta.url));
const { chromium } = require("@playwright/test");
const { default: AxeBuilder } = require("@axe-core/playwright");
const root = fileURLToPath(new URL(".", import.meta.url));
const url = "http://127.0.0.1:4187/previews/d6-depth/";
const browser = await chromium.launch({ headless: true });
const errors = [];
const report = { browser: browser.version(), checks: [] };
async function open(options = {}) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, ...options });
  const page = await context.newPage();
  page.setDefaultTimeout(15000);
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("requestfailed", (r) => errors.push(r.url()));
  await page.goto(url);
  assert(
    await page.evaluate(() => [...document.images].every((i) => i.complete && i.naturalWidth > 0)),
    "images must load before the document load event",
  );
  if (options.javaScriptEnabled !== false) await page.evaluate(() => document.fonts.ready);
  return page;
}
async function settle(page) {
  await page.evaluate(
    () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
  );
}
async function move(page, progress) {
  await page.locator(".depth-track").evaluate((track, p) => {
    const sticky = document.querySelector(".depth-sticky");
    scrollTo(
      0,
      track.getBoundingClientRect().top +
        scrollY -
        parseFloat(getComputedStyle(sticky).top) +
        (track.offsetHeight - sticky.offsetHeight) * p,
    );
  }, progress);
  await settle(page);
}
async function widths(page) {
  return page
    .locator(".plane")
    .evaluateAll((planes) => planes.map((p) => p.getBoundingClientRect().width));
}
async function capture(page, name) {
  await page.screenshot({
    path: join(root, "images", `d6-${name}.jpg`),
    type: "jpeg",
    quality: 90,
  });
}
async function audit(page, label) {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);
  assert.equal(overflow, false, `${label}: horizontal overflow`);
  if (label === "No JavaScript") {
    report.checks.push(`${label}: images loaded, no horizontal overflow; axe requires scripting`);
    return;
  }
  const result = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
    .analyze();
  assert.deepEqual(
    result.violations.map((v) => v.id),
    [],
    `${label}: accessibility`,
  );
  report.checks.push(`${label}: images loaded, no horizontal overflow, axe WCAG A/AA`);
}
try {
  const page = await open();
  await capture(page, "opening");
  await move(page, 0.12);
  await capture(page, "outer");
  const initial = await page.locator(".volume").screenshot();
  const initialWidths = await widths(page);
  await move(page, 0.5);
  await capture(page, "middle");
  const middleWidths = await widths(page);
  const growth = middleWidths.map((w, i) => w / initialWidths[i]);
  assert(
    growth[2] > growth[1] && growth[1] > growth[0] && growth[0] > 1,
    "near planes must enlarge faster",
  );
  assert(
    !initial.equals(await page.locator(".volume").screenshot()),
    "camera must visibly advance",
  );
  await move(page, 0.88);
  await capture(page, "inner");
  await audit(page, "Desktop");
  await move(page, 0.12);
  assert(
    initial.equals(await page.locator(".volume").screenshot()),
    "reverse scroll must restore identical pixels",
  );
  report.checks.push(
    "Forward z travel enlarges near/middle/far by distinct factors; reverse scroll restores exact volume pixels",
  );
  await page.locator("#motion-toggle").click();
  const paused = await page.locator(".camera").getAttribute("style");
  await move(page, 0.5);
  assert.equal(await page.locator(".camera").getAttribute("style"), paused);
  await page.locator("#motion-toggle").click();
  await settle(page);
  assert.notEqual(await page.locator(".camera").getAttribute("style"), paused);
  report.checks.push("Pause freezes camera; resume adopts current scroll");
  await page.emulateMedia({ reducedMotion: "reduce" });
  await settle(page);
  assert.equal(await page.locator(".depth").getAttribute("data-enhanced"), null);
  assert.equal(await page.locator(".camera").evaluate((e) => getComputedStyle(e).display), "none");
  assert.equal(
    await page.locator(".depth-sticky").evaluate((e) => getComputedStyle(e).position),
    "static",
  );
  await page.locator("#depth").evaluate((e) => e.scrollIntoView({ block: "start" }));
  await capture(page, "reduced-motion");
  await audit(page, "Reduced motion");
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await move(page, 0.5);
  assert(await page.locator(".depth").evaluate((e) => e.hasAttribute("data-enhanced")));
  await page.locator(".study-controls a").click();
  assert(
    await page
      .locator("#handbook")
      .evaluate(
        (e) =>
          e.getBoundingClientRect().top >= 0 && e.getBoundingClientRect().top < innerHeight - 200,
      ),
  );
  report.checks.push(
    "Runtime reduced-motion changes remove/reinstate depth layout; handbook skip exits the passage",
  );
  await page.context().close();
  for (const [label, options] of [
    ["Mobile", { viewport: { width: 390, height: 844 } }],
    ["Short screen", { viewport: { width: 1440, height: 650 } }],
    ["No JavaScript", { javaScriptEnabled: false }],
  ]) {
    const fallback = await open(options);
    assert.equal(await fallback.locator(".depth").getAttribute("data-enhanced"), null);
    assert.equal(
      await fallback.locator(".depth-sticky").evaluate((e) => getComputedStyle(e).position),
      "static",
    );
    await audit(fallback, label);
    if (label === "Mobile") await capture(fallback, "mobile");
    await fallback.locator(".skip").focus();
    await fallback.keyboard.press("Enter");
    assert(
      await fallback
        .locator("#handbook")
        .evaluate(
          (e) =>
            e.getBoundingClientRect().top >= 0 && e.getBoundingClientRect().top < innerHeight - 200,
        ),
    );
    report.checks.push(`${label}: static composition, ordinary flow and keyboard skip`);
    await fallback.context().close();
  }
  // A separate, short recording shows the requested camera motion in both directions.
  const videoDir = fileURLToPath(new URL("../../../.cache/design/d6-video/", import.meta.url));
  await mkdir(videoDir, { recursive: true });
  const videoPage = await open({
    recordVideo: { dir: videoDir, size: { width: 1440, height: 1000 } },
  });
  await move(videoPage, 0.06);
  await videoPage.waitForTimeout(400);
  await videoPage.evaluate(async () => {
    const track = document.querySelector(".depth-track");
    const sticky = document.querySelector(".depth-sticky");
    const start =
      track.getBoundingClientRect().top + scrollY - parseFloat(getComputedStyle(sticky).top);
    const distance = track.offsetHeight - sticky.offsetHeight;
    const sweep = (from, to, duration) =>
      new Promise((resolve) => {
        const begin = performance.now();
        const frame = (now) => {
          const p = Math.min(1, (now - begin) / duration);
          scrollTo(0, start + distance * (from + (to - from) * p));
          if (p < 1) requestAnimationFrame(frame);
          else resolve();
        };
        requestAnimationFrame(frame);
      });
    await sweep(0.06, 0.94, 7000);
    await sweep(0.94, 0.06, 7000);
  });
  await videoPage.waitForTimeout(400);
  const video = videoPage.video();
  await videoPage.context().close();
  await video.saveAs(join(root, "previews", "d6-depth.webm"));
  assert.deepEqual(errors, [], "browser errors / failed requests");
  console.log(JSON.stringify(report, null, 2));
} finally {
  await browser.close();
}
