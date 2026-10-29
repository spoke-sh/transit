import { expect, test, type Response } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("installed catalog, exact preview, profiles and session workbook", async ({ page }) => {
  const errors: string[] = [];
  const scripts = new Map<string, Response>();
  let runs = 0;
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("response", (response) => {
    if (response.request().resourceType() === "script" && response.url().includes("/assets/"))
      scripts.set(response.url(), response);
  });
  page.on("request", (request) => {
    if (request.url().endsWith("/api/v1/sql-read") && request.postDataJSON()?.action.run) runs++;
  });
  await page.goto("/");
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
  await page.getByRole("tab", { name: "Schema", exact: true }).click();
  await expect(
    page.getByRole("table", { name: "Declared logical types, codecs and collations" }),
  ).toContainText("INT64");
  expect(runs).toBe(0);
  await page.getByRole("tab", { name: "Preview", exact: true }).click();
  await page.getByRole("button", { name: "Preview rows", exact: true }).click();
  await expect(
    page.getByRole("table", { name: "Rows 1–100 of this result", exact: true }),
  ).toBeVisible();
  await expect(page.getByText(/Dataset coverage unknown/)).toBeVisible();
  await page.getByRole("button", { name: "Column profile", exact: true }).click();
  await expect(page.getByRole("complementary", { name: "Column profile" })).toContainText(
    "Population: 100 received rows",
  );
  await page.getByRole("button", { name: "Next window", exact: true }).click();
  await expect(
    page.getByRole("table", { name: "Rows 101–145 of this result", exact: true }),
  ).toBeVisible();
  expect(runs).toBe(1);
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  await page.screenshot({ path: process.env.BOARD_SCREENSHOT, fullPage: true });
  await page.setViewportSize({ width: 1280, height: 800 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
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
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
  expect(errors).toEqual([]);
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
  deny = true;
  await expect(page.getByRole("alert")).toContainText("Forbidden", { timeout: 12000 });
  await expect(page.getByRole("table")).toHaveCount(0);
  await expect(page.getByRole("textbox", { name: "SQL", exact: true })).toHaveValue("");
  expect(runs).toBe(1);
});
