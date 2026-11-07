import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

for (const javaScriptEnabled of [true, false]) {
  test.describe(`tables with JavaScript ${javaScriptEnabled ? "enabled" : "disabled"}`, () => {
    test.use({ javaScriptEnabled, viewport: { width: 320, height: 844 }, colorScheme: "dark" });

    test("overflowing tables support keyboard scrolling", async ({ page, baseURL }) => {
      await page.goto(new URL("reference/cli", baseURL).href);
      const table = page.getByRole("table").filter({ hasText: ".help [--all] [TOPIC]" });
      await expect(table).toHaveCount(1);
      // This table has no links that could accidentally provide a focus target.
      await expect(table.getByRole("link")).toHaveCount(0);
      await expect(table).toHaveAttribute("tabindex", "0");
      await expect
        .poll(() => table.evaluate((node) => node.scrollWidth > node.clientWidth))
        .toBe(true);

      await table.focus();
      await page.keyboard.press("Shift+Tab");
      await expect(table).not.toBeFocused();
      await page.keyboard.press("Tab");
      await expect(table).toBeFocused();
      await expect(table).toHaveCSS("outline-style", "solid");
      await expect(table).toHaveCSS("outline-width", "2px");
      await page.keyboard.press("ArrowRight");
      await expect.poll(() => table.evaluate((node) => node.scrollLeft)).toBeGreaterThan(0);
      await page.keyboard.press("ArrowLeft");
      await expect.poll(() => table.evaluate((node) => node.scrollLeft)).toBe(0);
      expect(
        await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth),
      ).toBe(true);
      // Axe's asynchronous browser scripts require JavaScript; the native
      // focus and scrolling assertions above also exercise the static page.
      if (javaScriptEnabled)
        expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
    });
  });
}
