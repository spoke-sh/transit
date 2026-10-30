// Capture the integrated D6 homepage from a locally served production build.
// Interaction and fallback assertions live in handbook/browser/dark-depth.spec.ts.
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { mkdir } from "node:fs/promises";
import { join } from "node:path";

const require = createRequire(new URL("../../handbook/package.json", import.meta.url));
const { chromium } = require("@playwright/test");
const root = fileURLToPath(new URL(".", import.meta.url));
const videoDir = fileURLToPath(
  new URL("../../../.cache/design/d6-implementation/", import.meta.url),
);
const url = process.env.TRANSIT_DOCS_CAPTURE_URL ?? "http://127.0.0.1:4188/transit/";
const browser = await chromium.launch({ headless: true });
const errors = [];
const options = {
  viewport: { width: 1440, height: 1000 },
  colorScheme: "dark",
  reducedMotion: "no-preference",
};
async function open(context) {
  const page = await context.newPage();
  page.on("pageerror", (error) => errors.push(String(error)));
  page.on("requestfailed", (request) => errors.push(request.url()));
  await page.goto(url);
  await page.locator('.refraction-track[data-depth-motion="enabled"]').waitFor();
  await page.locator(".transit-hero-dark").evaluate((image) => image.decode());
  await page.evaluate(() => document.fonts.ready);
  return page;
}
async function move(page, from, to = from, duration = 0) {
  await page.locator(".refraction-track").evaluate(
    async (track, [start, end, milliseconds]) => {
      const visual = track.querySelector(".radiograph-visual");
      const origin =
        track.getBoundingClientRect().top + scrollY - parseFloat(getComputedStyle(visual).top);
      const distance = track.offsetHeight - visual.offsetHeight;
      await new Promise((resolve) => {
        const begin = performance.now();
        const frame = (now) => {
          const p = milliseconds ? Math.min(1, (now - begin) / milliseconds) : 1;
          scrollTo(0, origin + distance * (start + (end - start) * p));
          if (p < 1) requestAnimationFrame(frame);
          else requestAnimationFrame(() => requestAnimationFrame(resolve));
        };
        requestAnimationFrame(frame);
      });
    },
    [from, to, duration],
  );
}
try {
  const context = await browser.newContext(options);
  const page = await open(context);
  await page.screenshot({ path: join(root, "images/d6-implemented-opening.jpg"), quality: 90 });
  await move(page, 0.5);
  await page.screenshot({ path: join(root, "images/d6-implemented-middle.jpg"), quality: 90 });
  await context.close();

  await mkdir(videoDir, { recursive: true });
  const recording = await browser.newContext({
    ...options,
    recordVideo: { dir: videoDir, size: options.viewport },
  });
  const videoPage = await open(recording);
  await move(videoPage, 0.06);
  await videoPage.waitForTimeout(400);
  await move(videoPage, 0.06, 0.94, 7000);
  await move(videoPage, 0.94, 0.06, 7000);
  await videoPage.waitForTimeout(400);
  const video = videoPage.video();
  await recording.close();
  await video.saveAs(join(root, "previews/d6-implemented-depth.webm"));
  assert.deepEqual(errors, [], "browser errors / failed requests");
  console.log(JSON.stringify({ browser: browser.version(), url, errors }));
} finally {
  await browser.close();
}
