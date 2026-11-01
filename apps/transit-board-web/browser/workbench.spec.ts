import { expect, test, type Response } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("installed catalog, exact preview, profiles and session workbook", async ({ page }) => {
  const errors: string[] = [];
  const externalRequests: string[] = [];
  const scripts = new Map<string, Response>();
  let runs = 0;
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("response", (response) => {
    if (response.request().resourceType() === "script" && response.url().includes("/assets/"))
      scripts.set(response.url(), response);
  });
  page.on("request", (request) => {
    if (new URL(request.url()).origin !== new URL(process.env.BOARD_TEST_URL!).origin)
      externalRequests.push(request.url());
    if (request.url().endsWith("/api/v1/sql-read") && request.postDataJSON()?.action.run) runs++;
  });
  const inspector = page.getByRole("complementary", { name: "Inspector", exact: true });
  await page.goto("/");
  await expect(page.getByRole("navigation", { name: "Activities" })).toContainText("Workbooks");
  await expect(page.getByRole("heading", { name: "Catalog", exact: true })).toBeVisible();
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  await Promise.all([
    page.waitForResponse(
      (response) =>
        response.url().endsWith("/api/v1/catalog") &&
        Boolean(response.request().postDataJSON()?.action.tables?.cursor) &&
        response.status() === 200,
    ),
    page.getByRole("button", { name: "Next page", exact: true }).click(),
  ]);
  await expect(page.getByRole("table").getByRole("row")).toHaveCount(4);
  await expect(page.getByRole("button", { name: "First page", exact: true })).toBeEnabled();
  expect(runs).toBe(0);
  await page.getByRole("button", { name: "First page", exact: true }).click();
  await expect(page.getByRole("table").getByRole("row")).toHaveCount(9);
  // Catalog pages follow object identity; a named Table can be on either page.
  if (!(await page.getByRole("link", { name: "metrics", exact: true }).count())) {
    await page.getByRole("button", { name: "Next page", exact: true }).click();
    await expect(page.getByRole("table").getByRole("row")).toHaveCount(4);
  }
  await page.getByRole("link", { name: "metrics", exact: true }).click();
  await expect(page.getByRole("heading", { name: "metrics", exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByRole("heading", { name: "metrics", exact: true })).toBeVisible();
  expect(runs).toBe(0);
  await page.getByRole("button", { name: "Dataset details", exact: true }).click();
  await expect(inspector).toContainText("Definition digest");
  await expect(inspector).toHaveCount(1);
  await page.getByRole("button", { name: "Close inspector", exact: true }).click();
  await expect(page.getByRole("button", { name: "Dataset details", exact: true })).toBeFocused();
  await page.getByRole("tab", { name: "Schema", exact: true }).click();
  await expect(
    page.getByRole("table", { name: "Declared logical types, codecs and collations" }),
  ).toContainText("INT64");
  const schemaColumn = page
    .getByRole("table", { name: "Declared logical types, codecs and collations" })
    .getByRole("button")
    .first();
  await schemaColumn.focus();
  await schemaColumn.press("Enter");
  await expect(inspector).toContainText("Physical codec");
  await page.keyboard.press("Escape");
  await expect(schemaColumn).toBeFocused();
  expect(runs).toBe(0);
  await page.getByRole("tab", { name: "Preview", exact: true }).click();
  await page.getByRole("button", { name: "Preview rows", exact: true }).click();
  await expect(
    page.getByRole("table", { name: "Rows 1–100 of this result", exact: true }),
  ).toBeVisible();
  await expect(page.getByText(/Dataset coverage unknown/)).toBeVisible();
  await page.getByRole("button", { name: "Column profile", exact: true }).click();
  await expect(page.getByRole("complementary", { name: "Inspector" })).toContainText(
    "Population: 100 received rows",
  );
  await page.getByRole("button", { name: "Next window", exact: true }).click();
  await expect(
    page.getByRole("table", { name: "Rows 101–145 of this result", exact: true }),
  ).toBeVisible();
  await expect(inspector).toContainText("Population: 45 received rows");
  await page.getByRole("button", { name: "Dataset details", exact: true }).click();
  await expect(inspector).toContainText("Definition digest");
  await expect(inspector).not.toContainText("Population:");
  await page.getByRole("button", { name: "Column profile", exact: true }).click();
  await inspector.getByRole("button", { name: "Evidence", exact: true }).click();
  await expect(inspector).toContainText("145 result rows verified");
  await expect(inspector).toContainText("Source data · independent cuts remain independent");
  const resultIdentity = await inspector.locator("code").innerText();
  await inspector.getByRole("button", { name: "Open detail in workspace", exact: true }).click();
  await expect(page.getByRole("button", { name: "Preview rows", exact: true })).toBeHidden();
  await expect(inspector.locator("code")).toHaveText(resultIdentity);
  await inspector.getByRole("button", { name: "Return to workspace", exact: true }).click();
  await expect(page.getByRole("table")).toBeVisible();
  await inspector.getByRole("button", { name: "Open detail in workspace", exact: true }).click();
  await page.getByRole("button", { name: "Dataset navigation", exact: true }).click();
  await expect(page.getByRole("navigation", { name: "Object navigator" })).toBeVisible();
  await expect(page.getByRole("table")).toBeVisible();
  await page.getByRole("button", { name: "Dataset navigation", exact: true }).click();
  await inspector.getByRole("button", { name: "Profile", exact: true }).click();
  expect(runs).toBe(1);
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  await page.screenshot({ path: process.env.BOARD_SCREENSHOT, fullPage: true });
  await page.setViewportSize({ width: 1280, height: 800 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(inspector).toContainText("145 result rows verified");
  await expect(page.getByRole("table")).toBeHidden();
  await expect(page.getByText("Branch 1", { exact: true })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await expect(inspector.getByRole("button", { name: "Close inspector" })).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("button", { name: "Column profile", exact: true })).toBeFocused();
  await page.setViewportSize({ width: 1440, height: 1050 });
  await page.getByRole("link", { name: "Open workbook", exact: true }).click();
  const sql = page.getByRole("textbox", { name: "SQL", exact: true });
  await sql.fill("SELECT * FROM empty_metrics");
  expect(runs).toBe(1);
  await sql.press("Control+Enter");
  await expect(page.getByText("No rows · verified empty result", { exact: true })).toBeVisible();
  await sql.fill("SHOW TABLES");
  await expect(page.getByText(/Earlier result ·/)).toBeVisible();
  expect(runs).toBe(2);
  await page.getByRole("button", { name: "Run cell 1", exact: true }).click();
  await expect(page.getByRole("region", { name: "Statement result" })).toContainText("metrics");
  await expect(page.getByRole("heading", { name: "Workbook", exact: true })).toBeVisible();
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  const firstCell = page.getByRole("region", { name: "SQL cell 1", exact: true });
  await firstCell.getByRole("button", { name: "Result evidence", exact: true }).click();
  const firstResult = await inspector.locator("code").innerText();
  await page.getByRole("button", { name: "Add SQL cell", exact: true }).click();
  const secondCell = page.getByRole("region", { name: "SQL cell 2", exact: true });
  await secondCell
    .getByRole("textbox", { name: "SQL", exact: true })
    .fill("SELECT * FROM empty_metrics");
  await secondCell.getByRole("button", { name: "Run cell 2", exact: true }).click();
  await expect(secondCell).toContainText("No rows · verified empty result");
  await secondCell.getByRole("button", { name: "Result evidence", exact: true }).click();
  await expect(inspector).toHaveCount(1);
  await expect(inspector).toContainText("0 result rows verified");
  expect(await inspector.locator("code").innerText()).not.toBe(firstResult);
  await secondCell.getByRole("textbox", { name: "SQL", exact: true }).fill("SHOW TABLES");
  await expect(inspector).toContainText("Earlier result");
  await inspector.getByRole("button", { name: "Open detail in workspace", exact: true }).click();
  await inspector.getByRole("button", { name: "Return to workspace", exact: true }).click();
  await expect(secondCell.getByRole("textbox", { name: "SQL", exact: true })).toHaveValue(
    "SHOW TABLES",
  );
  await secondCell.getByRole("button", { name: "Remove cell", exact: true }).click();
  await expect(inspector).toBeHidden();
  await firstCell.getByRole("button", { name: "Result evidence", exact: true }).click();
  await expect(inspector.locator("code")).toHaveText(firstResult);
  await firstCell.getByRole("button", { name: "Close result", exact: true }).click();
  await expect(inspector).toBeHidden();
  await page.setViewportSize({ width: 720, height: 900 });
  await page.getByRole("button", { name: "Cells", exact: true }).click();
  await page
    .getByRole("navigation", { name: "Object navigator" })
    .getByRole("button", { name: "Cell 1" })
    .click();
  await expect(firstCell.getByRole("textbox", { name: "Investigation notes" })).toBeFocused();
  expect(runs).toBe(4);
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
  expect(errors).toEqual([]);
  expect(externalRequests).toEqual([]);
  expect(scripts.size).toBeLessThanOrEqual(5);
  for (const response of scripts.values()) {
    expect(response.status()).toBe(200);
    expect((await response.body()).length).toBeLessThan(900_000);
  }
});

test("lost reply keeps one statement and failed observation clears its presentation", async ({
  page,
}) => {
  let runs = 0,
    lost = false,
    deny = false;
  await page.route("**/api/v1/sql-read", async (route) => {
    const action = route.request().postDataJSON().action;
    if (action.run) runs++;
    if (deny && action.observe) {
      await route.fulfill({ status: 403, json: { err: "Forbidden", diagnostic: null } });
      return;
    }
    if (action.run && !lost) {
      const response = await route.fetch();
      if (response.status() === 200) {
        lost = true;
        await route.fulfill({ status: 503, json: { err: "Unavailable", diagnostic: null } });
        return;
      }
      await route.fulfill({ response });
      return;
    }
    await route.continue();
  });
  await page.goto("/workbook");
  await page.getByRole("textbox", { name: "SQL", exact: true }).fill("SELECT * FROM metrics");
  await page.getByRole("button", { name: "Run cell 1", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("Unavailable");
  await page.getByRole("button", { name: "Check original result", exact: true }).click();
  await expect(
    page.getByRole("table", { name: "Rows 1–100 of this result", exact: true }),
  ).toBeVisible();
  expect(runs).toBe(1);
  await page.getByRole("button", { name: "Column profile", exact: true }).click();
  await expect(page.getByRole("complementary", { name: "Inspector" })).toContainText(
    "Population: 100",
  );
  deny = true;
  await expect(page.getByRole("alert")).toContainText("Forbidden", { timeout: 12000 });
  await expect(page.getByRole("table")).toHaveCount(0);
  await expect(page.getByRole("complementary", { name: "Inspector" })).toBeHidden();
  await expect(page.getByText(/Population:/)).toHaveCount(0);
  await expect(page.getByRole("textbox", { name: "SQL", exact: true })).toHaveValue("");
  expect(runs).toBe(1);
});

test("unavailable workbook metadata removes inspector disclosure without rerunning SQL", async ({
  page,
}) => {
  let unavailable = false,
    throttleRetry = false,
    throttles = 0,
    runs = 0;
  await page.route("**/api/v1/sql-read", async (route) => {
    const action = route.request().postDataJSON().action;
    if (action.run) runs++;
    if (unavailable && action.describe) {
      await route.fulfill({ status: 503, json: { err: "Unavailable", diagnostic: null } });
      return;
    }
    if (throttleRetry && action.describe) {
      throttleRetry = false;
      throttles++;
      await route.fulfill({ status: 429, json: { err: "RateLimited", diagnostic: null } });
      return;
    }
    await route.continue();
  });
  await page.goto("/workbook");
  await page.getByRole("button", { name: "Run cell 1", exact: true }).click();
  await expect(page.getByRole("table")).toBeVisible();
  await page.getByRole("button", { name: "Column profile", exact: true }).click();
  const inspector = page.getByRole("complementary", { name: "Inspector" });
  await expect(inspector).toContainText("Population:");
  unavailable = true;
  await expect(page.getByRole("heading", { name: "Data connection unavailable" })).toBeVisible({
    timeout: 12000,
  });
  await expect(inspector).toBeHidden();
  await expect(page.getByText(/Population:/)).toHaveCount(0);
  unavailable = false;
  throttleRetry = true;
  await page.getByRole("button", { name: "Retry read", exact: true }).click();
  await expect(page.getByRole("table")).toBeVisible();
  await expect(inspector).toBeHidden();
  expect(runs).toBe(1);
  expect(throttles).toBe(1);
});

test("retained catalog inspection is bounded and clears revoked coverage", async ({ page }) => {
  const selector = process.env.BOARD_HISTORY_SELECTOR;
  expect(selector).toMatch(/^[0-9a-f]{594}$/);
  let runs = 0,
    denied = false;
  const actions: string[] = [];
  page.on("request", (request) => {
    if (request.url().endsWith("/api/v1/sql-read") && request.postDataJSON()?.action.run) runs++;
  });
  await page.route("**/api/v1/catalog", async (route) => {
    const history = route.request().postDataJSON().action.history;
    if (history) {
      actions.push(Object.keys(history)[0]!);
      if (denied) {
        await route.fulfill({ status: 403, json: { err: "Forbidden", diagnostic: null } });
        return;
      }
    }
    await route.continue();
  });
  await page.goto("/");
  await page.getByText("Inspect a retained catalog", { exact: true }).click();
  await page.getByLabel("Snapshot selector", { exact: true }).fill(selector!);
  await page.getByRole("button", { name: "Inspect snapshot", exact: true }).click();
  const catalog = page.getByRole("region", { name: "Retained catalog", exact: true });
  await expect(catalog).toContainText("single_partition");
  await catalog.getByRole("button", { name: "metrics", exact: true }).click();
  const interpretation = page.getByRole("region", { name: "Retained interpretation", exact: true });
  await expect(interpretation).toContainText("145 retained rows");
  await expect(interpretation).toContainText("physical column");
  await interpretation.getByLabel("Coverage", { exact: true }).selectOption("locations");
  await expect(interpretation).toContainText("Partial directory coverage");
  await expect(interpretation).toContainText(
    "Payload verification and query completion are separate",
  );
  const rows = () => interpretation.locator("p").filter({ hasText: /^Row / });
  await expect(rows()).toHaveCount(8);
  const before = await rows().allTextContents();
  await interpretation.getByRole("button", { name: "Next coverage page", exact: true }).click();
  await expect
    .poll(async () => (await rows().allTextContents()).filter((row) => before.includes(row)).length)
    .toBe(0);
  await expect(rows()).toHaveCount(8);
  denied = true;
  await expect(page.getByRole("heading", { name: "Data connection unavailable" })).toBeVisible({
    timeout: 12000,
  });
  await expect(page.getByText(/145 retained rows/)).toHaveCount(0);
  expect(runs).toBe(0);
  expect(actions.length).toBeGreaterThan(5);
  expect(
    actions.every((action) =>
      ["namespace", "list", "source", "definitions", "locations"].includes(action),
    ),
  ).toBe(true);
});
