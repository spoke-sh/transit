import { test, expect, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

async function moveToDepth(page: Page, progress: number): Promise<void> {
  await page.locator(".refraction-track").evaluate((track, p) => {
    const visual = track.querySelector<HTMLElement>(".radiograph-visual")!;
    const top = Number.parseFloat(getComputedStyle(visual).top);
    window.scrollTo(
      0,
      track.getBoundingClientRect().top +
        scrollY -
        top +
        (track.clientHeight - visual.offsetHeight) * p,
    );
  }, progress);
  await page.evaluate(
    () =>
      new Promise<void>((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
      ),
  );
}

async function expectStaticDark(page: Page): Promise<void> {
  await expect(page.locator(".refraction-track")).not.toHaveAttribute("data-depth-motion");
  await expect(page.locator(".radiograph-visual")).toHaveCSS("position", "static");
  await expect(page.locator(".radiograph-camera")).toHaveCSS("display", "none");
  await expect(page.locator(".radiograph-poster")).toHaveCSS("visibility", "visible");
  await expect(page.locator(".radiograph-plane")).toHaveCount(0);
  await expect(page.getByRole("button", { name: /depth motion/ })).toHaveCount(0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
}

test("dark artwork travels into z-depth and precisely retraces on reverse scroll", async ({
  page,
  baseURL,
}, testInfo) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("response", (response) => {
    if (response.status() >= 400) errors.push(response.url());
  });
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "no-preference" });
  await page.goto(baseURL!);
  const track = page.locator(".refraction-track");
  await expect(track).toHaveAttribute("data-depth-motion", "enabled");
  await expect(page.locator("html")).toHaveCSS("--ifm-background-color", "#14191e");
  await expect(page.locator(".transit-hero-dark")).toBeVisible();
  await expect(page.locator(".transit-hero-light")).toBeHidden();
  await expect(page.locator(".refraction-visual")).toBeHidden();
  await expect(page.locator(".context-visual")).toBeHidden();
  await page.screenshot({ path: testInfo.outputPath("dark-opening.png") });
  const layers = page.locator(".radiograph-plane");
  const widths = () =>
    layers.evaluateAll((images) => images.map((image) => image.getBoundingClientRect().width));
  const font = await page.locator("#activity-title").evaluate((e) => getComputedStyle(e).fontSize);
  await moveToDepth(page, 0.12);
  const original = await page.locator(".radiograph-volume").screenshot();
  const initial = await widths();
  await page.screenshot({ path: testInfo.outputPath("dark-outer.png") });
  await moveToDepth(page, 0.5);
  const zoomed = await widths();
  const growth = zoomed.map((width, i) => width / initial[i]!);
  expect(growth[2]).toBeGreaterThan(growth[1]!);
  expect(growth[1]).toBeGreaterThan(growth[0]!);
  expect(growth[0]).toBeGreaterThan(1);
  expect(await page.locator("#activity-title").evaluate((e) => getComputedStyle(e).fontSize)).toBe(
    font,
  );
  expect(original.equals(await page.locator(".radiograph-volume").screenshot())).toBe(false);
  await page.screenshot({ path: testInfo.outputPath("dark-middle.png") });
  await moveToDepth(page, 0.88);
  await page.screenshot({ path: testInfo.outputPath("dark-inner.png") });
  await moveToDepth(page, 0.12);
  expect(original.equals(await page.locator(".radiograph-volume").screenshot())).toBe(true);

  await page.getByRole("button", { name: "Pause depth motion" }).click();
  const paused = await page.locator(".radiograph-camera").getAttribute("style");
  await moveToDepth(page, 0.5);
  expect(await page.locator(".radiograph-camera").getAttribute("style")).toBe(paused);
  await expect(page.getByRole("button", { name: "Resume depth motion" })).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  await page.getByRole("button", { name: "Resume depth motion" }).click();
  await expect
    .poll(() => page.locator(".radiograph-camera").getAttribute("style"))
    .not.toBe(paused);
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.getByRole("link", { name: "Skip to the handbook" }).click();
  await expect(page.locator("#handbook-title")).toBeInViewport();
  expect(errors).toEqual([]);
});

test("dark motion responds to preferences, native theme switching and route lifecycle", async ({
  page,
  baseURL,
}, testInfo) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "no-preference" });
  await page.goto(baseURL!);
  const track = page.locator(".refraction-track");
  await expect(track).toHaveAttribute("data-depth-motion", "enabled");
  await moveToDepth(page, 0.5);
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expectStaticDark(page);
  await page.locator(".radiograph-heading").scrollIntoViewIfNeeded();
  await page.screenshot({ path: testInfo.outputPath("dark-reduced-motion.png") });
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await expect(track).toHaveAttribute("data-depth-motion", "enabled");
  for (const viewport of [
    { width: 320, height: 844 },
    { width: 1440, height: 650 },
  ]) {
    await page.setViewportSize(viewport);
    await expectStaticDark(page);
    await page.locator(".radiograph-visual").scrollIntoViewIfNeeded();
    expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
    await page.screenshot({ path: testInfo.outputPath(`dark-static-${viewport.width}.png`) });
  }
  await page.setViewportSize({ width: 1440, height: 1000 });
  await expect(track).toHaveAttribute("data-depth-motion", "enabled");
  await moveToDepth(page, 0.5);
  // Docusaurus cycles system -> light -> dark; its control remains the sole theme owner.
  const theme = page.getByRole("button", { name: /Switch between dark and light mode/ });
  await theme.click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
  await expect(track).not.toHaveAttribute("data-depth-motion");
  await expect(page.locator(".radiograph-camera")).not.toHaveAttribute("style", /--camera-z/);
  await expect(page.locator(".radiograph-plane")).toHaveCount(0);
  await expect(page.locator(".radiograph-visual")).toBeHidden();
  await expect(page.locator(".refraction-story")).toHaveAttribute("data-motion", "enabled");
  await expect(page.locator(".transit-hero-light")).toBeVisible();
  await theme.click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await expect(track).toHaveAttribute("data-depth-motion", "enabled");
  // A stored dark choice overrides the system's light preference on reload.
  await page.emulateMedia({ colorScheme: "light" });
  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await expect(track).toHaveAttribute("data-depth-motion", "enabled");
  await page.getByRole("link", { name: "Explore the data model", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Data, computation and policies", exact: true }),
  ).toBeVisible();
  await expect(page.locator("html")).toHaveCSS("--ifm-background-color", "#14191e");
  await page.goBack();
  await expect(track).toHaveAttribute("data-depth-motion", "enabled");
  await moveToDepth(page, 0.5);
  await expect(page.locator(".radiograph-camera")).toHaveAttribute("style", /--camera-z/);
  expect(errors).toEqual([]);
});

test("dark server-rendered composition works before hydration", async ({ page, baseURL }) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.emulateMedia({ colorScheme: "dark" });
  // Keep the native inline theme bootstrap, but withhold the application scripts.
  await page.route(/\.js(?:\?|$)/, (route) => route.abort());
  await page.goto(baseURL!);
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await expectStaticDark(page);
  await expect(page.locator(".transit-hero-dark")).toBeVisible();
  await page.locator(".radiograph-poster").scrollIntoViewIfNeeded();
  await expect
    .poll(() =>
      page.locator(".radiograph-poster").evaluate((image: HTMLImageElement) => image.naturalWidth),
    )
    .toBe(1774);
  await page.getByRole("link", { name: "Skip to the handbook" }).focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#handbook-title")).toBeInViewport();
  await page.getByRole("link", { name: "Follow the quickstart", exact: true }).click();
  await expect(page.getByRole("heading", { name: /^Define your data/ })).toBeVisible();
});

test("an unavailable depth layer preserves the static composition and links", async ({
  page,
  baseURL,
}) => {
  let refused = 0;
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "no-preference" });
  await page.route(/d6-middle.*\.webp$/, (route) => {
    refused++;
    return route.abort();
  });
  await page.goto(baseURL!);
  await expect.poll(() => refused).toBeGreaterThan(0);
  await expect(page.locator(".refraction-track")).not.toHaveAttribute("data-depth-motion");
  await expect(page.locator(".radiograph-visual")).toHaveCSS("position", "static");
  await expect(page.locator(".radiograph-poster")).toHaveCSS("visibility", "visible");
  await expect(page.getByRole("button", { name: /depth motion/ })).toHaveCount(0);
  await page.getByRole("link", { name: "Skip to the handbook" }).click();
  await expect(page.locator("#handbook-title")).toBeInViewport();
});
