import { expect, test, type Response } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("deferred view loading and failed downloads preserve shell navigation", async ({ page }) => {
  let release!: () => void;
  const blocked = new Promise<void>((resolve) => {
    release = resolve;
  });
  let requested!: () => void;
  const entered = new Promise<void>((resolve) => {
    requested = resolve;
  });
  let storageReads = 0;
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("request", (request) => {
    if (request.url().endsWith("/api/v1/storage")) storageReads++;
  });
  await page.route("**/assets/operations-*.js", async (route) => {
    requested();
    await blocked;
    await route.abort("failed");
  });
  await page.goto("/catalog");
  await expect(page.getByRole("heading", { name: "Catalog", exact: true })).toBeVisible();
  const navigation = page.getByRole("navigation", { name: "Activities" });
  await navigation.getByRole("link", { name: "Operations", exact: true }).click();
  await entered;
  await expect(page.getByRole("status")).toHaveText("Loading view…");
  await expect(navigation).toBeVisible();
  expect(storageReads).toBe(0);
  release();
  await expect(page.getByRole("heading", { name: "View unavailable", exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Reload Board", exact: true })).toBeVisible();
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  await navigation.getByRole("link", { name: "Data", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Catalog", exact: true })).toBeVisible();
  await navigation.getByRole("link", { name: "Operations", exact: true }).click();
  await expect(page.getByRole("heading", { name: "View unavailable", exact: true })).toBeVisible();
  await page.unroute("**/assets/operations-*.js");
  await page.getByRole("button", { name: "Reload Board", exact: true }).click();
  await expect(
    page.getByRole("region", { name: "Capacity and allocation", exact: true }),
  ).toBeVisible();
  expect(storageReads).toBeGreaterThan(0);
  expect(errors).toEqual([]);
});

test("home and feature access follow catalog and SQL configuration independently", async ({
  page,
}) => {
  let catalog = false,
    sql = true;
  await page.route("**/api/v1/deployment", async (route) => {
    const response = await route.fetch();
    const value = await response.json();
    await route.fulfill({
      response,
      json: { ...value, features: { ...value.features, catalog, sql } },
    });
  });
  // Injection isolates the browser's discovery behavior; real read permissions
  // remain enforced by the installed service and its separate API proof.
  await page.route("**/api/v1/capabilities", (route) =>
    route.fulfill({ status: 403, json: { err: "Forbidden" } }),
  );
  await page.goto("/");
  await expect(page).toHaveURL(/\/workbook$/);
  await expect(page.getByRole("button", { name: "Run cell 1" })).toBeEnabled();
  await page.goto("/catalog");
  await expect(
    page.getByRole("heading", { name: "Catalog connection is not configured" }),
  ).toBeVisible();
  catalog = true;
  sql = false;
  let sqlRequests = 0;
  page.on("request", (request) => {
    if (request.url().endsWith("/api/v1/sql-read")) sqlRequests++;
  });
  await page.goto("/");
  await expect(page).toHaveURL(/\/catalog$/);
  await expect(page.getByRole("link", { name: "items", exact: true })).toBeVisible();
  await page.getByRole("link", { name: "items", exact: true }).click();
  await expect(page.getByRole("button", { name: "Preview rows", exact: true })).toBeDisabled();
  await expect(page.getByText(/SQL connection is not configured\. Open Workbook/)).toBeVisible();
  await page.getByRole("tab", { name: "Schema", exact: true }).click();
  await expect(
    page.getByRole("table", { name: "Declared logical types, codecs and collations", exact: true }),
  ).toBeVisible();
  expect(sqlRequests).toBe(0);
  await page.goto("/workbook");
  await expect(
    page.getByRole("heading", { name: "Workbook SQL connection is not configured" }),
  ).toBeVisible();
});

test("Table storage links visual, grid and inspector without executing SQL", async ({
  page,
  context,
}) => {
  let runs = 0;
  page.on("request", (request) => {
    if (request.url().endsWith("/api/v1/sql-read") && request.postDataJSON()?.action.run) runs++;
  });
  const storageRead = page.waitForResponse(
    (response) => response.url().endsWith("/api/v1/storage") && response.ok(),
  );
  await page.goto("/operations");
  const observed = await (await storageRead).json();
  const capacity = page.getByRole("region", { name: "Capacity and allocation", exact: true });
  const limitRow = capacity
    .getByRole("row")
    .filter({ has: page.getByRole("button", { name: "Ordinary storage limit", exact: true }) });
  await expect(limitRow).toContainText(/(?:KiB|MiB|GiB|TiB)/);
  // Exact detail is operable by keyboard and copies the original public count.
  await limitRow.getByRole("button", { name: /exact size/ }).focus();
  await page.keyboard.press("Enter");
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  await limitRow.getByRole("button", { name: "Copy exact bytes" }).click();
  await expect(limitRow.getByRole("status")).toHaveText("Exact bytes copied.");
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(
    String(observed.limits.bytes),
  );
  await page.evaluate(() => {
    Object.defineProperty(navigator.clipboard, "writeText", {
      value: () => Promise.reject(new Error("Clipboard disabled by test")),
      configurable: true,
    });
  });
  await limitRow.getByRole("button", { name: "Copy exact bytes" }).click();
  await expect(limitRow.getByRole("status")).toHaveText(
    "Copy unavailable. Select the exact value to copy.",
  );
  const maintenance = page.getByRole("region", { name: "Maintenance", exact: true });
  await expect(maintenance.getByRole("table")).toContainText("Flush work bound");
  await expect(maintenance.getByRole("table")).toContainText(
    `${observed.settings.flush.work_rows} rows per step`,
  );
  await maintenance
    .getByRole("table")
    .getByRole("button", { name: "Worker interval", exact: true })
    .click();
  await expect(page.getByRole("complementary", { name: "Inspector" })).toContainText(
    `${observed.maintenance.interval_ms.toLocaleString()} milliseconds`,
  );
  await page.keyboard.press("Escape");
  const explorer = page.getByRole("region", { name: "Table storage explorer", exact: true });
  await expect(explorer.getByRole("table")).toBeVisible();
  if (!(await explorer.getByRole("button", { name: "metrics", exact: true }).count()))
    await explorer.getByRole("button", { name: "More Tables" }).click();
  await explorer.getByRole("button", { name: "metrics", exact: true }).click();
  const table = page.getByRole("region", { name: "Table storage · metrics", exact: true });
  await expect(table).toContainText("145");
  const grid = table.getByRole("table");
  const visual = table.getByLabel("Table storage · metrics visualization");
  await visual.getByRole("button", { name: /^Accepted next position/ }).click();
  await expect(
    grid.getByRole("button", { name: "Accepted next position", exact: true }),
  ).toHaveAttribute("aria-pressed", "true");
  const inspector = page.getByRole("complementary", { name: "Inspector" });
  await expect(inspector).toContainText("partition-local coordinate");
  await grid.getByRole("button", { name: "Pending rows", exact: true }).click();
  await expect(inspector).toContainText("1,024");
  await page.keyboard.press("Escape");
  await expect(grid.getByRole("button", { name: "Pending rows", exact: true })).toBeFocused();
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  if (process.env.BOARD_SCREENSHOT)
    await page.screenshot({
      path: process.env.BOARD_SCREENSHOT.replace(/\.png$/, "-operations.png"),
      fullPage: true,
    });
  await page.route("**/api/v1/catalog", (route) =>
    route.fulfill({ status: 403, json: { err: "Forbidden", diagnostic: null } }),
  );
  await expect(page.getByRole("heading", { name: "Access to Catalog denied" })).toBeVisible({
    timeout: 10000,
  });
  await expect(table).toHaveCount(0);
  await expect(inspector).toBeHidden();
  await expect(
    page.getByRole("region", { name: "Capacity and allocation", exact: true }),
  ).toBeVisible();
  expect(runs).toBe(0);
});

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
  await expect(page.getByRole("link", { name: "items", exact: true })).toBeVisible();
  const loaded = (group: string) =>
    [...scripts.keys()].some((url) => url.includes(`/assets/${group}-`));
  expect(loaded("catalog")).toBe(true);
  for (const group of [
    "operations",
    "dataset",
    "workbook",
    "statements",
    "inspection",
    "query-workspace",
    "live",
    "recovery",
  ])
    expect(loaded(group), `${group} should remain deferred on Catalog`).toBe(false);
  expect(scripts.size).toBeLessThanOrEqual(5);
  const firstNames = await page.getByRole("table").getByRole("link").allTextContents();
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  // The object directory also contains five foreign definitions. Its bounded
  // scan may return fewer Tables on a page without completing the traversal.
  // Check rendered coverage without retaining network response bodies across
  // metadata refreshes.
  await page.getByRole("button", { name: "Next page", exact: true }).click();
  await expect(page.getByRole("table").getByRole("link")).toHaveCount(11 - firstNames.length);
  const secondNames = await page.getByRole("table").getByRole("link").allTextContents();
  expect(firstNames.length).toBeLessThanOrEqual(8);
  expect(secondNames.length).toBeLessThanOrEqual(8);
  expect(firstNames.length + secondNames.length).toBe(11);
  expect(new Set([...firstNames, ...secondNames]).size).toBe(11);
  await expect(page.getByRole("table").getByRole("row")).toHaveCount(secondNames.length + 1);
  await expect(page.getByRole("button", { name: "First page", exact: true })).toBeEnabled();
  expect(runs).toBe(0);
  await page.getByRole("button", { name: "First page", exact: true }).click();
  await expect(page.getByRole("table").getByRole("row")).toHaveCount(firstNames.length + 1);
  // Catalog pages follow object identity; a named Table can be on either page.
  if (!(await page.getByRole("link", { name: "metrics", exact: true }).count())) {
    await page.getByRole("button", { name: "Next page", exact: true }).click();
    await expect(page.getByRole("table").getByRole("row")).toHaveCount(secondNames.length + 1);
  }
  await page.getByRole("link", { name: "metrics", exact: true }).click();
  await expect(page.getByRole("heading", { name: "metrics", exact: true })).toBeVisible();
  expect(loaded("statements")).toBe(true);
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
  expect(scripts.size).toBeLessThanOrEqual(8);
  for (const group of ["operations", "inspection", "query-workspace", "live", "recovery"])
    expect(loaded(group), `${group} should remain deferred after Dataset and Workbook`).toBe(false);
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
  await expect(page.getByRole("table", { includeHidden: true })).toHaveCount(0);
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
    const action = route.request().postDataJSON().action;
    const history = action.history;
    if (history) {
      actions.push(Object.keys(history)[0]!);
      if (denied) {
        await route.fulfill({ status: 403, json: { err: "Forbidden", diagnostic: null } });
        return;
      }
    }
    if (action.definitions) {
      actions.push(`interpretation.${Object.keys(action.definitions)[0]!}`);
      if (denied) {
        await route.fulfill({ status: 403, json: { err: "Forbidden", diagnostic: null } });
        return;
      }
    }
    await route.continue();
  });
  await page.goto("/operations");
  await page.getByText("Inspect a retained catalog", { exact: true }).click();
  await page.getByLabel("Snapshot selector", { exact: true }).fill(selector!);
  await page.getByRole("button", { name: "Inspect snapshot", exact: true }).click();
  const catalog = page.getByRole("region", { name: "Retained catalog", exact: true });
  await expect(catalog).toContainText("single_partition");
  await catalog.getByRole("button", { name: "metrics", exact: true }).click();
  const interpretation = page.getByRole("region", { name: "Retained interpretation", exact: true });
  await expect(interpretation).toContainText("145 retained rows");
  await expect(interpretation).toContainText("physical column");
  await interpretation
    .getByRole("combobox", { name: "Coverage", exact: true })
    .selectOption("locations");
  await expect(interpretation).toContainText("Partial directory coverage");
  await expect(interpretation).toContainText(
    "Payload verification and query completion are separate",
  );
  const placement = interpretation.getByRole("region", {
    name: "Row placement evidence",
    exact: true,
  });
  const placementGrid = placement.getByRole("table");
  const rows = () => placementGrid.locator("tbody tr");
  await expect(rows()).toHaveCount(8);
  const before = await rows().allTextContents();
  const firstRow = placementGrid.getByRole("button").first();
  const rowName = await firstRow.innerText();
  await firstRow.focus();
  await page.keyboard.press("Enter");
  const inspector = page.getByRole("complementary", { name: "Inspector" });
  await expect(inspector).toContainText(rowName);
  await expect(inspector).toContainText(selector!);
  await expect(
    placement
      .getByRole("group", { name: "Row placement visualization" })
      .getByRole("button")
      .first(),
  ).toHaveAttribute("aria-pressed", "true");
  await page.keyboard.press("Escape");
  await expect(firstRow).toBeFocused();
  await firstRow.click();
  await interpretation.getByRole("button", { name: "Next coverage page", exact: true }).click();
  await expect
    .poll(async () => (await rows().allTextContents()).filter((row) => before.includes(row)).length)
    .toBe(0);
  await expect(rows()).toHaveCount(8);
  await expect(inspector).toBeHidden();
  await page.setViewportSize({ width: 780, height: 900 });
  await placementGrid.getByRole("button").first().click();
  await expect(inspector.getByRole("button", { name: "Close inspector" })).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(placementGrid.getByRole("button").first()).toBeFocused();
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.emulateMedia({ reducedMotion: "reduce" });
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  if (process.env.BOARD_SCREENSHOT)
    await placement.screenshot({
      path: process.env.BOARD_SCREENSHOT.replace(/\.png$/, "-placement.png"),
    });
  await catalog.getByText("Inspect retained definitions", { exact: true }).click();
  const definitions = page.getByRole("region", { name: "Retained definitions", exact: true });
  await expect(definitions).toContainText("More definitions are available.");
  await definitions.getByRole("button", { name: "decoder_0", exact: true }).click();
  const accepted = page.getByRole("region", { name: "Accepted interpretation", exact: true });
  await expect(accepted).toContainText("foreign · Definition 1");
  await accepted.getByText("Output schema and interpretation", { exact: true }).click();
  await expect(accepted).toContainText("comp_3");
  await definitions.getByRole("button", { name: "Next definitions", exact: true }).click();
  await expect(definitions).toContainText("decoder_4");
  await expect(definitions).toContainText("End of the selected definition directory.");
  await expect(
    page.getByRole("region", { name: "Accepted interpretation", exact: true }),
  ).toHaveCount(0);
  await page.route("**/api/v1/catalog", async (route) => {
    if (route.request().postDataJSON().action.history?.locations)
      await route.fulfill({ status: 403, json: { err: "Forbidden", diagnostic: null } });
    else await route.fallback();
  });
  await expect(interpretation.getByRole("heading", { name: "Access to Data denied" })).toBeVisible({
    timeout: 12000,
  });
  await expect(placement).toHaveCount(0);
  await interpretation
    .getByRole("combobox", { name: "Coverage", exact: true })
    .selectOption("definitions");
  const physical = interpretation.getByRole("region", {
    name: "Physical definitions evidence",
    exact: true,
  });
  await expect(physical).toContainText("physical column");
  await physical.getByRole("table").getByRole("button").first().click();
  await expect(inspector).toContainText("Exact mapping and physical interpretation");
  await page.keyboard.press("Escape");
  // Collapsing removes disclosure and reads; reopening revalidates the supplied selector.
  await page.getByText("Inspect a retained catalog", { exact: true }).click();
  await expect(interpretation).toHaveCount(0);
  const readsBefore = actions.length;
  await page.waitForTimeout(5500);
  expect(actions.length).toBe(readsBefore);
  await page.getByText("Inspect a retained catalog", { exact: true }).click();
  await expect(catalog).toContainText("single_partition");
  await catalog.getByRole("button", { name: "metrics", exact: true }).click();
  await expect(physical).toBeVisible();
  denied = true;
  await expect(page.getByRole("heading", { name: "Access to Data denied" }).first()).toBeVisible({
    timeout: 12000,
  });
  await expect(page.getByText(/145 retained rows/)).toHaveCount(0);
  expect(runs).toBe(0);
  expect(actions.length).toBeGreaterThan(5);
  expect(
    actions.every((action) =>
      [
        "namespace",
        "list",
        "source",
        "definitions",
        "locations",
        "interpretation.list",
        "interpretation.historical",
      ].includes(action),
    ),
  ).toBe(true);
});
