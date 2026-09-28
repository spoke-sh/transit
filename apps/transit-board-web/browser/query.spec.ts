import AxeBuilder from "@axe-core/playwright";
import { test, expect } from "@playwright/test";
import { execFileSync } from "node:child_process";

test("one explicit query survives Canvas/Browse changes and is cleared on revocation", async ({
  page,
  context,
}) => {
  test.setTimeout(180000);
  page.setDefaultTimeout(15000);
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  let submissions = 0;
  page.on("request", (request) => {
    if (request.url().endsWith("/api/v1/query") && request.method() === "POST") {
      const body = request.postDataJSON() as Record<string, unknown>;
      if ("submit" in body) submissions++;
    }
  });
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Relief atlas", exact: true })).toBeVisible();
  await page
    .getByRole("button", {
      name: `Select resource ${process.env.BOARD_QUERY_RESOURCE}`,
      exact: true,
    })
    .click();
  await expect(page.getByRole("button", { name: "Enter resource" })).toBeVisible();
  await page
    .getByLabel("Search this authorized page")
    .fill(`resource ${process.env.BOARD_QUERY_RESOURCE}`);
  await expect(page.locator(".atlas-evidence")).toContainText("0 processes and 1 resources match");
  await page.getByLabel("Search this authorized page").fill("");
  await page.getByRole("button", { name: "Inspect participation", exact: true }).click();
  await expect(
    page.getByRole("table", {
      name: `Authorized associations to resource ${process.env.BOARD_QUERY_RESOURCE}`,
    }),
  ).toBeVisible({ timeout: 15000 });
  await expect(page.getByRole("button", { name: /^Next associations for PID/ })).toBeVisible();
  await page.getByRole("button", { name: /^Next associations for PID/ }).click();
  await expect(page.getByLabel("Resource participation")).toContainText("One selected PID.");
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "revoke-inspector-resource",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  await expect(page.getByLabel("Resource participation")).toHaveCount(0, { timeout: 15000 });
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "restore-inspector-resource",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  await page.getByRole("button", { name: "Refresh observation", exact: true }).click();
  await expect(page.getByLabel("Resource participation")).toBeVisible({ timeout: 15000 });
  for (const density of ["comfortable", "compact"]) {
    await page.getByLabel("Preview density").selectOption(density);
    expect(
      (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze()).violations,
    ).toEqual([]);
  }
  await page.getByRole("button", { name: "Resources", exact: true }).click();
  await page.getByLabel("Detail zoom").focus();
  await page.getByLabel("Detail zoom").press("End");
  await expect(page.getByLabel("Detail zoom")).toHaveValue("3");
  await page.screenshot({
    path: process.env.BOARD_QUERY_SCREENSHOT?.replace(".png", "-atlas.png"),
    fullPage: true,
  });
  await page.getByRole("button", { name: "Enter resource" }).click();
  const draft = page.getByLabel("SQL draft", { exact: true });
  await expect(draft).toBeVisible();
  const sql = "SELECT value FROM items WHERE value = 9007199254740994 LIMIT 1";
  await draft.fill(sql);
  await page.getByRole("button", { name: "Browse", exact: true }).click();
  await expect(draft).toHaveValue(sql);
  await page.getByRole("button", { name: "Canvas", exact: true }).click();
  expect(submissions).toBe(0);
  let dropped = false;
  const frozen: string[] = [];
  await page.route("**/api/v1/query", async (route) => {
    const body = route.request().postDataJSON();
    if (body.submit) {
      frozen.push(JSON.stringify(body));
      if (!dropped) {
        dropped = true;
        await route.fetch();
        await route.abort("failed");
        return;
      }
    }
    await route.continue();
  });
  await page.getByRole("button", { name: "Run query", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Retry exact submission", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Activity", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Activity", exact: true })).toBeVisible();
  await page.getByRole("link", { name: "Atlas", exact: true }).click();
  await page
    .getByRole("button", {
      name: `Select resource ${process.env.BOARD_QUERY_RESOURCE}`,
      exact: true,
    })
    .click();
  await page.getByRole("button", { name: "Enter resource", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Retry exact submission", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Retry exact submission", exact: true }).click();
  expect(frozen[0]).toEqual(frozen[1]);
  await expect(page.getByLabel("Verified query result")).toBeVisible({ timeout: 120000 });
  await expect(
    page.getByLabel("Verified query result").getByText("9007199254740994", { exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Browse", exact: true }).click();
  await expect(draft).toHaveValue(sql);
  await expect(page.getByRole("cell", { name: "9007199254740994", exact: true })).toBeVisible();
  await draft.fill("SELECT id FROM items LIMIT 2");
  await page.getByRole("button", { name: "Canvas", exact: true }).click();
  await expect(draft).toHaveValue("SELECT id FROM items LIMIT 2");
  await expect(
    page.getByText("Draft changed. The result still belongs to the last submitted SQL."),
  ).toBeVisible();
  expect(submissions).toBe(2);
  await page.screenshot({ path: process.env.BOARD_QUERY_SCREENSHOT, fullPage: true });
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "revoke",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  await expect(
    page.getByText("Query access denied. Protected workspace data has been cleared."),
  ).toBeVisible({ timeout: 15000 });
  await expect(page.getByLabel("Verified query result")).toHaveCount(0);
  await expect(draft).toHaveCount(0);
  expect(submissions).toBe(2);
  expect(await context.cookies()).toEqual([]);
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "restore",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  await page.getByRole("button", { name: "Refresh query access" }).click();
  await expect(draft).toHaveValue("SELECT * FROM items");
  await expect(page.getByLabel("Verified query result")).toHaveCount(0);
  expect(submissions).toBe(2);
  expect(errors).toEqual([]);
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "retire-source",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  await expect(
    page.getByText(
      "The source or result is unavailable or expired. Workspace data has been cleared.",
    ),
  ).toBeVisible({ timeout: 15000 });
  await expect(draft).toHaveCount(0);
  await expect(page.getByLabel("Verified query result")).toHaveCount(0);
});
