import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { chromium, expect as baseExpect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
const expect = baseExpect.configure({ timeout: 60000 });
const [origin, marker] = process.argv.slice(2);
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ reducedMotion: "reduce" });
const page = await context.newPage();
page.setDefaultTimeout(60000);
const errors = [],
  observations = [];
page.on("pageerror", (e) => errors.push(e.message));
page.on("response", async (r) => {
  if (!r.url().endsWith("/api/v1/query-v2")) return;
  const body = await r.json().catch(() => ({}));
  observations.push([
    Object.keys(r.request().postDataJSON())[0],
    r.status(),
    body.err ?? Object.keys(body)[0],
  ]);
  if (observations.length > 20) observations.shift();
});
let fault = false,
  step = false,
  lost = null,
  retried = false;
const namespaces = new Set();
await page.route("**/api/v1/query-v2", async (route) => {
  const op = route.request().postDataJSON();
  if ("next_draft" in op) {
    step = true;
    namespaces.add(op.next_draft.namespace);
  }
  if ("submit" in op && fault && step) {
    const body = route.request().postData();
    if (lost === null) {
      const response = await route.fetch();
      if (response.status() === 429) {
        await route.fulfill({ response });
        return;
      }
      assert.equal(response.status(), 200);
      lost = body;
      await route.fulfill({
        status: 503,
        contentType: "application/json",
        body: '{"err":"Unavailable"}',
      });
      return;
    }
    if (!retried) {
      assert.equal(body, lost);
      retried = true;
    }
  }
  await route.continue();
});
async function waitPhase(value) {
  await expect.poll(() => readFileSync(marker, "utf8"), { timeout: 180000 }).toBe(value);
}
try {
  await page.goto(origin + "/items");
  await expect(page.locator("#interface-status")).toContainText("revision 1");
  await page.locator("#run").click();
  await expect(page.locator("#coverage")).toContainText("19 rows");
  await expect(page.locator("#rows tr")).toHaveCount(8);
  console.log("Original query verified");
  await expect(page.locator("#basis")).toContainText("status schema");
  assert.deepEqual(await page.locator("#rows td:nth-child(2)").allTextContents(), [
    "Open",
    "Done",
    "Open",
    "Done",
    "Open",
    "Done",
    "Open",
    "Done",
  ]);
  await page.locator("#next").click();
  await expect(page.locator("#coverage")).toContainText("page 2");
  await page.waitForTimeout(2300);
  await expect(page.locator("#coverage")).toContainText("page 2");
  await page.locator("#next").click();
  await expect(page.locator("#rows tr")).toHaveCount(3);
  await expect(page.locator("#next")).toBeHidden();
  await page.getByRole("button", { name: "Definition", exact: true }).click();
  await expect(page.locator("#definition")).toContainText('CREATE INTERFACE "work_items"');
  await page.getByRole("button", { name: "Work items", exact: true }).click();
  fault = true;
  step = false;
  namespaces.clear();
  await page.locator("#run").click();
  await expect(page.locator("#query-status")).toContainText("uncertain");
  assert(lost !== null);
  assert.equal(namespaces.size, 1);
  const download = page.waitForEvent("download");
  await page.locator("#save").click();
  const file = await (await download).path();
  assert(file);
  const saved = readFileSync(file, "utf8");
  assert(!saved.includes("private_key"));
  console.log("Pagination verified; original uncertain upload saved");
  writeFileSync(marker, "migrate");
  await waitPhase("migrated");
  await page.reload();
  await expect(page.locator("#interface-status")).toContainText("revision 2");
  await expect(page.locator("body")).toHaveAttribute("data-density", "compact");
  await page.locator("#restore").setInputFiles({
    name: "recovery.json",
    mimeType: "application/json",
    buffer: Buffer.from(saved),
  });
  await page.locator("#recover").click();
  await expect.poll(() => retried).toBe(true);
  await expect(page.locator("#query-status")).toContainText("failed");
  assert.equal(namespaces.size, 1, "Recovery must not invent a replacement query");
  console.log("Original proposal recovered under new interface");
  await page.locator("#cancel").click();
  await expect(page.locator("#run")).toBeEnabled();
  fault = false;
  await page.locator("#run").click();
  await expect(page.locator("#basis")).toContainText("state schema");
  await expect(page.locator("#coverage")).toContainText("19 rows");
  assert.equal(namespaces.size, 2, "Only the explicit new Run may allocate a query");
  await page.locator("#density").selectOption("comfortable");
  for (const width of [1440, 320]) {
    await page.setViewportSize({ width, height: 1050 });
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    const axe = await new AxeBuilder({ page }).analyze();
    assert.deepEqual(
      axe.violations.map((v) => [v.id, v.nodes.map((n) => n.target)]),
      [],
    );
  }
  await page.locator("#sql").focus();
  await page.keyboard.press("Tab");
  await expect(page.locator("#run")).toBeFocused();
  writeFileSync(marker, "deny");
  await waitPhase("denied");
  await expect(page.locator("#result")).toBeHidden();
  await expect(page.locator("#workspace")).toBeHidden();
  assert.deepEqual(await context.cookies(), []);
  assert.deepEqual(await page.evaluate(() => [localStorage.length, sessionStorage.length]), [0, 0]);
  assert.deepEqual(errors, []);
  console.log(
    "Generated browser recovery, business decoding, page coverage, schema transition, responsive/keyboard/axe and current denial passed.",
  );
} catch (error) {
  console.error(observations, await page.locator("body").innerText());
  throw error;
} finally {
  await browser.close();
}
