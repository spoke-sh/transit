import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("handbook connects application studies to working interfaces with keyboard access", async ({
  page,
  baseURL,
}) => {
  await page.goto(new URL("guides/introduction", baseURL).href);
  const atlas = page.locator(".possibility-atlas");
  await expect(atlas).toBeVisible();
  await expect(atlas.locator("details[open]")).toHaveCount(1);
  await expect(atlas.locator("details").first()).toHaveJSProperty("open", true);
  await atlas.locator("summary").nth(1).focus();
  await page.keyboard.press("Enter");
  await expect(atlas.locator("details[open]")).toHaveCount(1);
  await expect(atlas.locator("details").nth(1)).toHaveJSProperty("open", true);
  await expect(
    atlas.getByText(
      /writable branches and reviewed publication are a separate proposed experience/,
    ),
  ).toBeVisible();
  await atlas.getByRole("link", { name: "Choose a query lifetime" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Query execution and result recovery",
  );
  await page.goto(new URL("guides/introduction", baseURL).href);
  await expect(page.locator(".handbook-chapter")).toHaveText("A field guide");
  await page
    .getByRole("navigation", { name: "Continue exploring Transit" })
    .getByRole("link", { name: /Make the first change/ })
    .click();
  await expect(
    page.getByRole("heading", { name: "Run Transit locally", exact: true }),
  ).toBeVisible();
  await expect(page.locator("#before-you-begin")).toBeVisible();
});

test("handbook studies remain useful without JavaScript", async ({ browser, baseURL }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto(new URL("guides/introduction", baseURL).href);
  const studies = page.locator(".possibility-atlas details");
  await studies.nth(2).locator("summary").click();
  await expect(studies.nth(2)).toHaveAttribute("open", "");
  await expect(studies.nth(2).getByRole("link", { name: "Build a worker" })).toBeVisible();
  await studies.nth(2).getByRole("link", { name: "Build a worker" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Build your first application");
  await context.close();
});

test("reading layout stays accessible in light, dark and narrow views", async ({
  page,
  baseURL,
}) => {
  for (const colorScheme of ["light", "dark"] as const) {
    await page.emulateMedia({ colorScheme, reducedMotion: "reduce" });
    for (const route of ["guides/introduction", "reference/sql"]) {
      await page.goto(new URL(route, baseURL).href);
      await expect(page.locator("html")).toHaveAttribute("data-theme", colorScheme);
      expect(
        (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze()).violations,
      ).toEqual([]);
    }
  }
  await page.setViewportSize({ width: 390, height: 844 });
  for (const route of [
    "guides/introduction",
    "guides/quickstart",
    "reference/data-model",
    "reference/sql",
    "internals",
    "sdks/python",
  ]) {
    await page.goto(new URL(route, baseURL).href);
    await expect(page.locator(".handbook-page h1")).toBeVisible();
    expect(
      await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
      route,
    ).toBe(true);
  }
});
