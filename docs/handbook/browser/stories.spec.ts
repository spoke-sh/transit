import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("statement stories connect examples, outcomes, references and search", async ({
  page,
  baseURL,
  request,
}, testInfo) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("response", (response) => {
    if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`);
  });
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto(baseURL!);
  await expect(page.locator(".transit-statement")).toHaveCount(3);
  await page.getByRole("link", { name: "Create your first dataset", exact: true }).click();
  await expect(page).toHaveURL(new URL("stories/first-dataset", baseURL!).href);
  await page
    .getByRole("navigation", { name: "Story chapters" })
    .getByRole("link", { name: "Ask", exact: true })
    .click();
  await expect(page.locator("#ask-title")).toBeInViewport();
  await expect(page.locator("#ask .transit-story-value")).toHaveText("2 unfinished tasks");
  await page.screenshot({ path: testInfo.outputPath("dataset-desktop.png") });
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.getByRole("link", { name: "Supported schema changes", exact: true }).click();
  await expect(page).toHaveURL(new URL("reference/sql/alter-table", baseURL!).href);
  await page.goto(new URL("stories/data-model", baseURL!).href);
  await expect(page.getByRole("heading", { level: 1 })).toContainText("Start with the data.");
  await page.getByRole("link", { name: "Follow a query to its result", exact: true }).click();
  await expect(page.locator("#read-again .transit-story-value")).toHaveText("2 → 1");
  await page.emulateMedia({ colorScheme: "dark" });
  await page.locator("#read-again").scrollIntoViewIfNeeded();
  await page.screenshot({ path: testInfo.outputPath("query-dark.png") });
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  const index = await (await request.get(new URL("search-index.json", baseURL!).href)).json();
  for (const route of ["stories/first-dataset", "stories/data-model", "stories/query-results"])
    expect(index.some((entry: { route: string }) => entry.route === route)).toBe(true);
  await page.goto(new URL("search", baseURL!).href);
  await page.getByLabel("Words or an interface name").fill("Create your first dataset");
  await page
    .locator(".search-results")
    .getByRole("link", { name: "Create your first dataset", exact: true })
    .click();
  await expect(page.getByRole("heading", { level: 1 })).toContainText("A few statements.");
  expect(errors).toEqual([]);
});

test("stories remain readable on mobile, with reduced motion and without JavaScript", async ({
  browser,
  baseURL,
}, testInfo) => {
  const context = await browser.newContext({
    javaScriptEnabled: false,
    viewport: { width: 390, height: 844 },
    reducedMotion: "reduce",
  });
  const page = await context.newPage();
  try {
    await page.goto(baseURL!);
    await page.getByRole("link", { name: "Create your first dataset", exact: true }).click();
    for (const route of ["stories/first-dataset", "stories/data-model", "stories/query-results"]) {
      await page.goto(new URL(route, baseURL!).href);
      await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
      await expect(page.locator(".transit-story-nav")).toHaveCSS("position", "static");
      await page.locator(".transit-story-nav li a").last().click();
      await expect(page.locator(".transit-story-step").last()).toBeInViewport();
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
        true,
      );
      await page.screenshot({ path: testInfo.outputPath(`${route.split("/")[1]}-mobile.png`) });
    }
    await page.getByRole("link", { name: "Query execution and recovery", exact: true }).click();
    await expect(page.getByRole("heading", { level: 1 })).toHaveText(
      "Query execution and result recovery",
    );
  } finally {
    await context.close();
  }
});
