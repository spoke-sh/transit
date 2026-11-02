import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

// Each invocation starts from a real, restarted Board configuration and distinct
// public SELECT-only subjects. No response interception changes discovery/access.
test("real independent connections remain usable through same-origin forwarding", async ({
  page,
  context,
}) => {
  const profile = process.env.BOARD_PROFILE;
  expect(["inspection", "catalog", "sql", "both"]).toContain(profile);
  const catalog = profile === "catalog" || profile === "both";
  const sql = profile === "sql" || profile === "both";
  const errors: string[] = [];
  let catalogReads = 0,
    sqlReads = 0,
    runs = 0;
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("request", (request) => {
    expect(new URL(request.url()).origin).toBe(process.env.BOARD_TEST_URL);
    if (request.url().endsWith("/api/v1/catalog")) catalogReads++;
    if (request.url().endsWith("/api/v1/sql-read")) {
      sqlReads++;
      if (request.postDataJSON()?.action?.run) runs++;
    }
  });
  await page.goto("/?status=all&sort=pid");
  await expect(
    page.getByRole("heading", {
      name: catalog ? "Catalog" : sql ? "Workbook" : "Operations",
      exact: true,
    }),
  ).toBeVisible();
  if (catalog) {
    for (let n = 0; n < 4; n++) {
      await expect(page.getByRole("table", { name: /Tables ·/ })).toBeVisible();
      if (await page.getByRole("link", { name: "metrics", exact: true }).count()) break;
      await Promise.all([
        page.waitForResponse(
          (response) =>
            response.url().endsWith("/api/v1/catalog") &&
            Boolean(response.request().postDataJSON()?.action.tables?.cursor) &&
            response.status() === 200,
        ),
        page.getByRole("button", { name: "Next page", exact: true }).click(),
      ]);
    }
    await page.getByRole("link", { name: "metrics", exact: true }).click();
    await expect(page.getByRole("button", { name: "Preview rows", exact: true })).toBeEnabled({
      enabled: sql,
    });
    await page.getByRole("tab", { name: "Schema", exact: true }).click();
    await expect(
      page.getByRole("table", {
        name: "Declared logical types, codecs and collations",
        exact: true,
      }),
    ).toBeVisible();
  } else {
    await page.goto("/catalog");
    await expect(
      page.getByRole("heading", { name: "Catalog connection is not configured" }),
    ).toBeVisible();
  }
  await page.goto("/workbook");
  if (sql) {
    await expect(page.getByRole("button", { name: "Run cell 1" })).toBeEnabled();
  } else {
    await expect(
      page.getByRole("heading", { name: "Workbook SQL connection is not configured" }),
    ).toBeVisible();
    expect(sqlReads).toBe(0);
  }
  if (!catalog) expect(catalogReads).toBe(0);
  expect(runs).toBe(0);
  expect(await context.cookies()).toEqual([]);
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  expect(errors).toEqual([]);
});
