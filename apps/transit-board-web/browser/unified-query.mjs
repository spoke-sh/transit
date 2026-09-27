import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { chromium, expect } from "@playwright/test";

const [origin, marker, resource, kind] = process.argv.slice(2);
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext();
const page = await context.newPage();
page.setDefaultTimeout(20000);
const errors = [];
page.on("pageerror", (error) => errors.push(error.message));
let lost = null;
let retried = false;
let submissions = 0;
let atlasInterrupted = false;
await page.route("**/api/v1/atlas*", async (route) => {
  if (lost !== null && !atlasInterrupted) {
    atlasInterrupted = true;
    await route.fulfill({
      status: 409,
      contentType: "application/json",
      body: '{"err":"QueryExpired"}',
    });
  } else await route.continue();
});
const observations = [];
page.on("response", async (response) => {
  if (!response.url().endsWith("/api/v1/query-v2")) return;
  const operation = Object.keys(response.request().postDataJSON())[0];
  const result = await response.json().catch(() => ({}));
  observations.push([
    operation,
    response.status(),
    result.err ?? result.status?.phase ?? Object.keys(result)[0],
  ]);
  if (observations.length > 30) observations.shift();
});
await page.route("**/api/v1/query-v2", async (route) => {
  const operation = route.request().postDataJSON();
  if ("submit" in operation) {
    submissions++;
    const body = route.request().postData();
    if (lost === null) {
      const response = await route.fetch();
      // Rate limiting is a pre-admission refusal. Let the real client repeat
      // those bytes normally; inject loss only after an accepted receipt.
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
try {
  await page.goto(origin);
  await page.getByRole("button", { name: `Select resource ${resource}`, exact: true }).click();
  await page.getByRole("button", { name: "Enter resource", exact: true }).click();
  const draft = page.getByLabel("SQL draft", { exact: true });
  await expect(draft).toBeVisible();
  await expect(page.getByRole("heading", { name: `items · ${kind}` })).toBeVisible();
  await draft.fill("SELECT * FROM items LIMIT 2");
  await page.getByRole("button", { name: "Browse", exact: true }).click();
  await page.getByRole("button", { name: "Canvas", exact: true }).click();
  assert.equal(submissions, 0);
  await page.getByRole("button", { name: "Run query", exact: true }).click();
  await expect(page.getByRole("button", { name: "Retry exact submission" })).toBeVisible();
  await page.getByRole("button", { name: "Retry exact submission" }).click();
  await expect(page.getByLabel("Verified query result")).toBeVisible({ timeout: 180000 });
  assert(retried);
  assert(atlasInterrupted, "query completed without the atlas refresh recovery check");
  await expect(
    page.getByLabel("Verified query result").getByText(/Complete ordered coverage verified/),
  ).toBeVisible();
  if (kind === "document")
    await expect(page.getByRole("cell", { name: "MISSING", exact: true })).toHaveCount(2);
  const completed = submissions;
  await draft.fill("SELECT * FROM items LIMIT 1");
  await page.getByRole("button", { name: "Browse", exact: true }).click();
  await expect(
    page.getByText("Draft changed. The displayed result belongs to the earlier submitted SQL."),
  ).toBeVisible();
  assert.equal(submissions, completed);
  writeFileSync(marker, "verified\n");
  await expect(
    page.getByText("Query access denied. Protected workspace data cleared."),
  ).toBeVisible({ timeout: 20000 });
  await expect(page.getByLabel("Verified query result")).toHaveCount(0);
  await expect(draft).toHaveCount(0);
  assert.equal(submissions, completed);
  assert.deepEqual(await context.cookies(), []);
  assert.deepEqual(await page.evaluate(() => [localStorage.length, sessionStorage.length]), [0, 0]);
  assert.deepEqual(errors, []);
  console.log(
    `Unified ${kind} browser: explicit SQL, identical uncertain retry, truthful provenance, view/draft separation and current denial passed.`,
  );
} catch (error) {
  console.error("Recent query operations:", observations);
  console.error("Visible query status:", await page.locator(".query-status").allTextContents());
  console.error("Browser errors:", errors);
  throw error;
} finally {
  await context.close();
  await browser.close();
}
