import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
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
let liveFault = false;
let liveStep = false;
let liveLost = null;
let liveRetried = false;
const liveNamespaces = new Set();
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
  if ("next_draft" in operation) {
    liveStep = true;
    liveNamespaces.add(operation.next_draft.namespace);
  }
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
    if (liveFault && liveStep && liveLost === null) {
      const response = await route.fetch();
      if (response.status() === 429) {
        await route.fulfill({ response });
        return;
      }
      assert.equal(response.status(), 200);
      liveLost = body;
      await route.fulfill({
        status: 503,
        contentType: "application/json",
        body: '{"err":"Unavailable"}',
      });
      return;
    }
    if (liveLost !== null && !liveRetried) {
      assert.equal(body, liveLost, "restored draft must retry the original signed bytes");
      liveRetried = true;
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
  const completion = page.getByRole("group", { name: "SQL completions", exact: true });
  await draft.fill("SE");
  const coldCompletion = performance.now();
  await draft.press("Control+Space");
  await expect(
    completion.getByRole("button", { name: "SELECT · SQL grammar", exact: true }),
  ).toBeVisible();
  const coldCompletionMs = performance.now() - coldCompletion;
  await draft.press("Tab");
  await expect(draft).toHaveValue("SELECT");
  await draft.press("Control+z");
  await expect(draft).toHaveValue("SE");
  await draft.fill("SELECT * FROM itxx");
  await draft.evaluate((input) => input.setSelectionRange(16, 16));
  const warmCompletion = performance.now();
  await draft.press("Control+Space");
  await expect(
    completion.getByRole("button", { name: '"items" · Authorized source', exact: true }),
  ).toBeVisible();
  const warmCompletionMs = performance.now() - warmCompletion;
  await draft.press("Tab");
  await expect(draft).toHaveValue('SELECT * FROM "items"');
  await draft.fill("SELECT hidden_column");
  await draft.press("Control+Space");
  await expect(completion).toContainText("No supported completion");
  await draft.press("Escape");
  await expect(completion).toHaveCount(0);
  assert.equal(submissions, 0, "cursor assistance and acceptance must not submit");
  console.log("Cursor assistance latency (ms, including debounce and authorization):", {
    cold: coldCompletionMs,
    warm: warmCompletionMs,
  });
  await page.getByText("Complete a draft from the authorized source", { exact: true }).click();
  await page.getByLabel("SQL candidate search").fill("COUNT");
  await page.getByRole("button", { name: "Find SQL candidates", exact: true }).click();
  await page
    .getByRole("button", { name: "Count: SELECT COUNT(*) FROM items", exact: true })
    .click();
  await expect(draft).toHaveValue("SELECT COUNT(*) FROM items");
  assert.equal(submissions, 0, "completion must only edit SQL");
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
  await page.getByText("Visible page profile and chart", { exact: true }).click();
  await expect(page.getByRole("table", { name: "Visible page cell-state profile" })).toBeVisible();
  await expect(page.getByText(/Exact counts for 2 visible rows/)).toBeVisible();
  let completed = submissions;
  await draft.fill("SELECT * FROM items LIMIT 1");
  await page.getByRole("button", { name: "Browse", exact: true }).click();
  await expect(
    page.getByText("Draft changed. The displayed result belongs to the earlier submitted SQL."),
  ).toBeVisible();
  assert.equal(submissions, completed);
  if (kind === "table") {
    liveFault = true;
    await page.getByRole("button", { name: "Enable Live draft", exact: true }).click();
    const controls = page.getByRole("group", { name: "Live draft controls" });
    await expect(controls).toContainText("uncertain", { timeout: 60000 });
    const download = page.waitForEvent("download");
    await page.getByRole("button", { name: "Save draft recovery", exact: true }).click();
    const saved = readFileSync(await (await download).path());
    assert.equal(liveNamespaces.size, 1);
    const original = [...liveNamespaces][0];
    await page.reload();
    // Route restoration is explicit. Neither loading the shell nor selecting
    // the resource can recover or replace a signed operation automatically.
    await page.getByRole("button", { name: `Select resource ${resource}`, exact: true }).click();
    await page.getByRole("button", { name: "Enter resource", exact: true }).click();
    await page.getByLabel("Restore draft recovery", { exact: true }).setInputFiles({
      name: "recovery.json",
      mimeType: "application/json",
      buffer: saved,
    });
    await expect(controls).toContainText("Original native identity and bundle restored");
    assert.equal(liveRetried, false);
    await page.getByRole("button", { name: "Recover original draft work", exact: true }).click();
    await expect(page.getByLabel("Verified query result")).toBeVisible({ timeout: 180000 });
    assert(liveRetried);
    assert.deepEqual([...liveNamespaces], [original]);
    await expect(controls).toContainText("1 / 2 native intents used");
    await expect(controls).toContainText("unavailable after recovery");
    await draft.fill("SELECT * FROM items LIMIT 3");
    await page.getByRole("button", { name: "Enable Live draft", exact: true }).click();
    await draft.fill("SELECT * FROM items LIMIT 2");
    await expect(controls).toContainText("exhausted", { timeout: 180000 });
    await expect(controls).toContainText("2 / 2 native intents used");
    assert.equal(
      liveNamespaces.size,
      2,
      "recovery and rapid edits must not replace or multiply intents",
    );
    await draft.fill("SELECT * FROM items LIMIT 1");
    completed = submissions;
    // Observe beyond the debounce; exhausted generations cannot silently reopen.
    await page.waitForTimeout(2000);
    assert.equal(submissions, completed);
    await expect(
      page.getByText("Draft changed. The displayed result belongs to the earlier submitted SQL."),
    ).toBeVisible();
  }
  await draft.fill("SELECT * FROM it");
  await draft.press("Control+Space");
  await expect(completion).toContainText('"items"');
  writeFileSync(marker, "verified\n");
  await expect(
    page.getByText("Query access denied. Protected workspace data cleared."),
  ).toBeVisible({ timeout: 20000 });
  await expect(page.getByLabel("Verified query result")).toHaveCount(0);
  await expect(draft).toHaveCount(0);
  await expect(completion).toHaveCount(0);
  assert.equal(submissions, completed);
  assert.deepEqual(await context.cookies(), []);
  assert.deepEqual(await page.evaluate(() => [localStorage.length, sessionStorage.length]), [0, 0]);
  assert.deepEqual(errors, []);
  console.log(
    `Unified ${kind} browser: explicit SQL, identical uncertain retry, truthful provenance, view/draft separation${kind === "table" ? ", finite Live drafts and saved exact recovery" : ""} and current denial passed.`,
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
