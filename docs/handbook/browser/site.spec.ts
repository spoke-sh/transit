import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { readFileSync } from "node:fs";
import path from "node:path";
import { downloads } from "../lib/downloads";
import { pages } from "../catalog";

test("static publication exposes canonical routes, search and crawl metadata", async ({
  page,
  request,
  baseURL,
}) => {
  const origin = process.env.TRANSIT_DOCS_URL ?? "https://spoke-sh.github.io";
  const base = process.env.TRANSIT_DOCS_BASE_URL ?? "/transit/";
  for (const route of [
    "reference/data-model",
    "reference/interfaces",
    "reference/sql-sessions",
    "reference/database-protocols",
  ]) {
    const response = await page.goto(new URL(route, baseURL).href);
    expect(response?.status()).toBe(200);
    await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
      "href",
      new URL(`${base}${route}`, origin).href,
    );
  }
  const sitemap = await request.get(new URL("sitemap.xml", baseURL).href);
  expect(sitemap.ok()).toBe(true);
  const sitemapText = await sitemap.text();
  expect(sitemapText).toContain(new URL(`${base}reference/sql-sessions`, origin).href);
  expect(sitemapText).not.toMatch(/localhost|\/roadmap\/|\/history\/|\/design\//);
  const robots = await request.get(new URL("robots.txt", baseURL).href);
  expect(robots.ok()).toBe(true);
  expect(await robots.text()).toContain(new URL(`${base}sitemap.xml`, origin).href);
  const search = await request.get(new URL("search-index.json", baseURL).href);
  expect(search.ok()).toBe(true);
  const index = (await search.json()) as { route: string }[];
  for (const route of [
    "reference/data-model",
    "reference/interfaces",
    "reference/sql-sessions",
    "reference/database-protocols",
    "reference/contracts",
    "internals",
  ])
    expect(index.some((entry) => entry.route === route)).toBe(true);
  const site =
    process.env.TRANSIT_DOCS_TEST_ARCHIVE === "1"
      ? "../../../.cache/release-handbook/site"
      : "../dist";
  expect(readFileSync(path.resolve(__dirname, site, "404.html"), "utf8")).toContain(
    "Page Not Found",
  );
});

test("production navigation, search, generated references and exact downloads", async ({
  page,
  request,
  baseURL,
}, testInfo) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("response", (response) => {
    if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`);
  });
  await page.goto(baseURL!);
  await expect(
    page.getByRole("heading", {
      name: "Give structure to change.",
    }),
  ).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath("desktop.png"), fullPage: true });
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.getByRole("link", { name: "Explore the data model", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Data, computation and policies", exact: true }),
  ).toBeVisible();
  await expect(page.locator("#choose-a-computation-lifetime")).toBeVisible();
  await expect(page.locator("#inspect-whether-a-declaration-is-being-fulfilled")).toBeVisible();
  await page.getByRole("link", { name: "local quickstart", exact: true }).click();
  await expect(page.getByRole("heading", { name: /^Define your data/ })).toBeVisible();
  await expect(
    page.getByRole("heading", { name: /^Observe a change from another session/ }),
  ).toBeVisible();
  await page.locator(".navbar").getByRole("link", { name: "Search", exact: true }).click();
  await page.getByLabel("Words or an interface name").fill("Data, computation and policies");
  await page
    .locator(".search-results")
    .getByRole("link", { name: "Data, computation and policies", exact: true })
    .click();
  await expect(page.locator("#declarations-and-current-interfaces")).toBeVisible();
  await page.goto(baseURL!);
  await page
    .getByRole("link", {
      name: "Query engine & SQL Compute answers and understand their source basis.",
    })
    .click();
  await expect(page.getByRole("heading", { name: "SQL reference", exact: true })).toBeVisible();
  await expect(page.getByRole("cell", { name: "Grammar only", exact: true }).first()).toBeVisible();
  const sidebar = page.locator(".theme-doc-sidebar-menu");
  const categories = sidebar.locator(":scope > .menu__list-item > .menu__list-item-collapsible");
  for (const name of [
    "Overview and quickstart",
    "Data model and type system",
    "Query engine (Fuze) and SQL",
    "Durable execution (Station) and apps",
    "Client protocols, CLI and gateways",
    "Security, governance and operations",
    "Verification, contracts and contributing",
  ])
    await expect(categories.getByText(name, { exact: true })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath("sql-navigation.png") });
  await sidebar.getByRole("link", { name: "SELECT", exact: true }).click();
  await expect(page.getByRole("heading", { name: "SELECT", exact: true })).toBeVisible();
  await sidebar.getByRole("link", { name: "CREATE TABLE", exact: true }).click();
  await expect(
    page.getByText(/CREATE TABLE publishes a general typed Table in the console/),
  ).toBeVisible();
  await sidebar.getByRole("link", { name: "CREATE CONNECTION", exact: true }).click();
  await expect(page.getByText("Grammar only.", { exact: true })).toBeVisible();
  await sidebar
    .getByRole("link", { name: "Grammar surface: implemented and planned", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Grammar surface: implemented and planned", exact: true }),
  ).toBeVisible();
  await expect(
    page
      .getByRole("row", { name: /CREATE KV, CREATE DOCUMENT publication/ })
      .getByRole("cell", { name: "Planned — checked grammar", exact: true }),
  ).toBeVisible();
  await expect(
    page
      .getByRole("row")
      .filter({ has: page.getByRole("cell", { name: "CREATE TABLE", exact: true }) })
      .getByRole("cell", { name: "Implemented — execution", exact: true }),
  ).toBeVisible();
  await sidebar.getByRole("link", { name: "Application declarations", exact: true }).click();
  await expect(page.locator("#create-interface")).toBeVisible();
  await page.getByRole("link", { name: "Search", exact: true }).click();
  await page.getByLabel("Words or an interface name").fill("Grammar surface");
  await page
    .locator(".search-results")
    .getByRole("link", { name: "Grammar surface: implemented and planned", exact: true })
    .click();
  await expect(page.locator("#planned-historical-schemas-and-branches")).toBeVisible();
  await page.getByRole("link", { name: "Search", exact: true }).click();
  await page.getByLabel("Words or an interface name").fill("CREATE SINK");
  await page
    .locator(".search-results")
    .getByRole("link", { name: "CREATE SINK", exact: true })
    .click();
  await expect(page.getByRole("heading", { name: "CREATE SINK", exact: true })).toBeVisible();
  await page.getByRole("link", { name: "Search", exact: true }).click();
  await page.getByLabel("Words or an interface name").fill("Flight");
  await page
    .locator(".search-results")
    .getByRole("link", { name: "Flight SQL and ADBC", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Flight SQL and ADBC", exact: true }),
  ).toBeVisible();
  await page.locator(".navbar").getByRole("link", { name: "SDKs", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Language SDKs", exact: true })).toBeVisible();
  await expect(sidebar.getByText("SDK foundations", { exact: true })).toBeVisible();
  await sidebar.getByText("Languages", { exact: true }).click();
  await sidebar.getByRole("link", { name: "Zig", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Zig SDK", exact: true })).toBeVisible();
  await expect(page.getByText("transit_sdk", { exact: true }).first()).toBeVisible();
  await sidebar.getByRole("link", { name: "Python", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Python SDK", exact: true })).toBeVisible();
  await page.getByRole("link", { name: "Search", exact: true }).click();
  await page.getByLabel("Words or an interface name").fill("Python SDK");
  await page.locator(".search-results").getByRole("link", { name: "Python", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Python SDK", exact: true })).toBeVisible();
  await page.locator(".navbar").getByRole("link", { name: "Internals", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Internals", exact: true })).toBeVisible();
  await page
    .locator("main")
    .getByRole("link", { name: "scientific standard", exact: true })
    .first()
    .click();
  await expect(
    page.getByRole("heading", { name: "Scientific standard for Internals", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Search", exact: true }).click();
  await page.getByLabel("Words or an interface name").fill("Scientific standard for Internals");
  const internalsResult = page.locator(".search-results li").filter({
    has: page.getByRole("link", { name: "Scientific standard for Internals", exact: true }),
  });
  await expect(internalsResult.getByText("Internals", { exact: true })).toBeVisible();
  await internalsResult.getByRole("link").click();
  await page
    .locator("main")
    .getByRole("link", { name: "technical account template", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Technical account template", exact: true }),
  ).toBeVisible();
  await page.goto(new URL("internals/system-model", baseURL).href);
  await expect(
    page.getByRole("heading", { name: "System model and authority boundaries", exact: true }),
  ).toBeVisible();
  await expect(page.locator(".docusaurus-mermaid-container svg")).toBeVisible();
  await page.locator("main").getByRole("link", { name: "execution account", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Execution, authorization and recovery", exact: true }),
  ).toBeVisible();
  await page.goto(new URL("internals", baseURL).href);
  const storage = page.getByRole("img", { name: /^Target storage and activation architecture:/ });
  await expect(storage).toBeVisible();
  await expect
    .poll(() => storage.evaluate((image: HTMLImageElement) => image.naturalWidth))
    .toBe(1280);
  const diagramLink = page.getByRole("link", {
    name: /^Target storage and activation architecture:/,
  });
  const diagramResponse = await request.get((await diagramLink.getAttribute("href"))!);
  expect(diagramResponse.ok()).toBe(true);
  expect(diagramResponse.headers()["content-type"]).toContain("image/svg+xml");
  await expect(
    page.locator("main").getByRole("link", { name: "Roadmap", exact: true }),
  ).toHaveAttribute(
    "href",
    `https://github.com/spoke-sh/transit/blob/${process.env.TRANSIT_DOCS_REVISION ?? "main"}/docs/roadmap/README.md`,
  );
  await expect(
    page.locator("main").getByRole("link", { name: "Design", exact: true }),
  ).toHaveAttribute(
    "href",
    `https://github.com/spoke-sh/transit/blob/${process.env.TRANSIT_DOCS_REVISION ?? "main"}/docs/design/README.md`,
  );
  await page.getByRole("link", { name: "Search", exact: true }).click();
  await page.getByLabel("Words or an interface name").fill("System model and authority boundaries");
  await expect(
    page
      .locator(".search-results")
      .getByRole("link", { name: "System model and authority boundaries", exact: true }),
  ).toBeVisible();
  for (const entry of downloads) {
    const route = pages.find((entryPage) => entryPage.source === entry.page)!.route;
    await page.goto(new URL(route, baseURL).href);
    const download = page.locator(`a[href$="/specs/${entry.name}"]`);
    await expect(download).toHaveAttribute("target", "_blank");
    const response = await request.get(
      new URL((await download.getAttribute("href"))!, baseURL).href,
    );
    expect(response.ok()).toBe(true);
    expect(await response.body()).toEqual(
      readFileSync(path.resolve(__dirname, "../../..", entry.source)),
    );
  }
  await page.goto(new URL("reference/openapi", baseURL).href);
  await expect(page.locator("#post-servingv1command")).toHaveText(/POST \/serving\/v1\/command/);
  await page.getByRole("link", { name: "SignedCommand", exact: true }).first().click();
  await expect(page.locator("#signedcommand")).toBeInViewport();
  await page.goto(new URL("reference/asyncapi", baseURL).href);
  await expect(page.locator("#channel-reactive")).toHaveText(/Channel reactive/);
  await page.goto(new URL("reference/architecture", baseURL).href);
  const archImg = page.getByRole("img", {
    name: /^Transit responsibilities and authority boundaries:/,
  });
  await expect(archImg).toBeVisible();
  await expect
    .poll(() => archImg.evaluate((image: HTMLImageElement) => image.naturalWidth))
    .toBe(1280);
  const responsibilityLink = page.getByRole("link", {
    name: /^Transit responsibilities and authority boundaries:/,
  });
  const opened = page.waitForEvent("popup");
  await responsibilityLink.click();
  const diagram = await opened;
  await expect(diagram).toHaveURL(/\/img\/architecture\/system-responsibilities\.svg$/);
  await expect(diagram.locator("svg")).toBeVisible();
  await diagram.close();
  expect(errors).toEqual([]);
});

test("mobile menu, readable content and dark-mode accessibility", async ({
  page,
  baseURL,
}, testInfo) => {
  await page.setViewportSize({ width: 320, height: 844 });
  await page.emulateMedia({ colorScheme: "dark" });
  await page.goto(baseURL!);
  await expect(
    page.getByRole("heading", {
      name: "Give structure to change.",
    }),
  ).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath("mobile.png"), fullPage: true });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.getByRole("button", { name: "Toggle navigation bar" }).click();
  await page
    .locator(".navbar-sidebar")
    .getByRole("link", { name: "Documentation", exact: true })
    .click();
  await expect(page.getByRole("heading", { name: "What is Transit?", exact: true })).toBeVisible();
  const planes = page.getByRole("img", { name: /^Transit three-plane architecture:/ });
  await expect(planes).toBeVisible();
  expect(await planes.evaluate((image: HTMLImageElement) => image.naturalWidth)).toBe(1280);
  await page.getByRole("button", { name: "Toggle navigation bar" }).click();
  await page.getByRole("button", { name: "← Back to main menu", exact: true }).click();
  await page
    .locator(".navbar-sidebar")
    .getByRole("link", { name: "Data model", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Data, computation and policies", exact: true }),
  ).toBeVisible();
  await expect(page.locator(".navbar-sidebar")).not.toBeInViewport();
  await expect(page.locator(".navbar-sidebar__backdrop")).not.toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.goto(baseURL!);
  await page.getByRole("button", { name: "Toggle navigation bar" }).click();
  await page
    .locator(".navbar-sidebar")
    .getByRole("link", { name: "Internals", exact: true })
    .click();
  await expect(page.getByRole("heading", { name: "Internals", exact: true })).toBeVisible();
  const storage = page.getByRole("img", { name: /^Target storage and activation architecture:/ });
  await storage.scrollIntoViewIfNeeded();
  await expect(storage).toBeVisible();
  await expect
    .poll(() => storage.evaluate((image: HTMLImageElement) => image.naturalWidth))
    .toBe(1280);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.goto(new URL("reference/architecture", baseURL).href);
  const responsibilities = page.getByRole("img", {
    name: /^Transit responsibilities and authority boundaries:/,
  });
  await responsibilities.scrollIntoViewIfNeeded();
  await expect(responsibilities).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.goto(new URL("reference/cli", baseURL).href);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.getByRole("button", { name: "Toggle navigation bar" }).click();
  const mobileMenu = page.locator(".navbar-sidebar");
  await mobileMenu
    .getByRole("button", { name: "Query engine (Fuze) and SQL", exact: true })
    .click();
  await mobileMenu.getByRole("link", { name: "CREATE TABLE", exact: true }).click();
  await expect(mobileMenu).not.toBeInViewport();
  await expect(page.getByRole("heading", { name: "CREATE TABLE", exact: true })).toBeVisible();
  await expect(
    page.getByText(/CREATE TABLE publishes a general typed Table in the console/),
  ).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  await page.screenshot({ path: testInfo.outputPath("sql-mobile.png") });
});

test("every published Mermaid diagram renders", async ({ page, baseURL }) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  for (const entry of pages) {
    const source = readFileSync(path.resolve(__dirname, "../../..", entry.source), "utf8");
    const count = source.match(/^```mermaid$/gm)?.length ?? 0;
    if (!count) continue;
    await page.goto(new URL(entry.route, baseURL).href);
    await expect(page.locator(".docusaurus-mermaid-container svg")).toHaveCount(count);
    await expect(page.locator(".error-icon")).toHaveCount(0);
  }
  expect(errors).toEqual([]);
});

test("workload examples link to measured performance and interactive sessions", async ({
  page,
  baseURL,
}) => {
  await page.goto(new URL("guides/introduction", baseURL).href);
  await page.getByRole("link", { name: "workload recipes across languages", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Workload examples across languages", exact: true }),
  ).toBeVisible();
  for (const language of ["python", "typescript", "rust", "zig"])
    await expect(page.locator(`pre.language-${language}`).first()).toBeVisible();
  await page.getByRole("link", { name: "performance reference", exact: true }).click();
  await expect(page.getByRole("heading", { name: /^Remaining improvements/ })).toBeVisible();
  await expect(page.getByRole("cell", { name: "1,120", exact: true })).toBeVisible();
  await page.getByRole("link", { name: "query sessions", exact: true }).click();
  await expect(page.locator("#interactive-sessions")).toHaveText(/Interactive sessions/);
  await expect(
    page.getByText("A new logical session does not resume a previous interactive SELECT.", {
      exact: false,
    }),
  ).toBeVisible();
  await page.goto(new URL("search", baseURL).href);
  await page.getByLabel("Words or an interface name").fill("telemetry");
  await expect(
    page.locator(".search-results").getByRole("link", {
      name: "Workload examples across languages",
      exact: true,
    }),
  ).toBeVisible();
});

test("homepage artwork follows scroll and respects reduced motion", async ({
  page,
  baseURL,
}, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.emulateMedia({ colorScheme: "light", reducedMotion: "no-preference" });
  await page.goto(baseURL!);
  const artwork = page.getByRole("img", { name: /^A measured score becomes waves/ });
  await expect(artwork).toBeVisible();
  expect(await artwork.evaluate((image: HTMLImageElement) => image.naturalWidth)).toBe(1774);
  const story = page.locator(".refraction-story");
  const scene = page.getByRole("img", { name: /^Vertical graphite waves widen sideways/ });
  await expect(story).toHaveAttribute("data-motion", "enabled");
  await expect(scene).toBeVisible();
  const initial = await scene.evaluate((element) => getComputedStyle(element).transform);
  await page.locator("#activity-title").scrollIntoViewIfNeeded();
  await expect
    .poll(() => scene.evaluate((image: HTMLImageElement) => image.naturalWidth))
    .toBe(1024);
  await expect
    .poll(() => scene.evaluate((element) => getComputedStyle(element).transform))
    .not.toBe(initial);
  await expect(page.locator(".refraction-visual")).toBeInViewport();
  await page.screenshot({ path: testInfo.outputPath("refraction-scroll.png") });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect(story).not.toHaveAttribute("data-motion");
  await expect(scene).toHaveCSS("transform", "none");
  await expect(page.locator(".refraction-visual")).toHaveCSS("position", "static");
  await page.getByRole("link", { name: "Go to the handbook" }).click();
  await expect(page.locator("#handbook-title")).toBeInViewport();
  await page.getByRole("link", { name: "Follow the quickstart", exact: true }).click();
  await expect(page.getByRole("heading", { name: /^Define your data/ })).toBeVisible();
});

test("context retains visible echoes through scroll, reduced motion and resize", async ({
  page,
  baseURL,
}, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.emulateMedia({ reducedMotion: "no-preference", colorScheme: "light" });
  await page.goto(baseURL!);
  const scene = page.getByRole("img", { name: /^A vermilion result trace/ });
  const layers = scene.locator("img");
  const transforms = () =>
    layers.evaluateAll((images) => images.map((image) => getComputedStyle(image).transform));
  await page.locator("#context-title").scrollIntoViewIfNeeded();
  await expect(scene).toBeInViewport();
  await expect(layers).toHaveCount(3);
  await expect
    .poll(() =>
      layers.evaluateAll((images: HTMLImageElement[]) =>
        images.every((image) => image.complete && image.naturalWidth === 1536),
      ),
    )
    .toBe(true);
  const initial = await transforms();
  expect(new Set(initial).size).toBe(3);
  await page.evaluate(() => window.scrollBy(0, 180));
  await expect.poll(transforms).not.toEqual(initial);
  const moving = await transforms();
  for (let index = 0; index < initial.length; index++)
    expect(moving[index]).not.toBe(initial[index]);
  await page.screenshot({ path: testInfo.outputPath("context-echoes.png") });

  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect(page.locator(".refraction-story")).not.toHaveAttribute("data-motion");
  await expect(page.locator(".context-visual")).toHaveCSS("position", "static");
  const still = await transforms();
  await page.evaluate(() => window.scrollBy(0, -180));
  await expect.poll(transforms).toEqual(still);

  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await scene.scrollIntoViewIfNeeded();
  await expect(page.locator(".refraction-story")).not.toHaveAttribute("data-motion");
  await expect(page.locator(".context-visual")).toHaveCSS("position", "static");
  expect(
    await scene.evaluate((element) => {
      const bounds = element.getBoundingClientRect();
      return (
        [...element.querySelectorAll("img")].every((image) => {
          const layer = image.getBoundingClientRect();
          return (
            layer.left >= bounds.left &&
            layer.right <= bounds.right &&
            layer.top >= bounds.top &&
            layer.bottom <= bounds.bottom
          );
        }) && document.documentElement.scrollWidth <= window.innerWidth
      );
    }),
  ).toBe(true);
  await page.screenshot({ path: testInfo.outputPath("context-mobile.png") });

  await page.setViewportSize({ width: 1440, height: 600 });
  await scene.scrollIntoViewIfNeeded();
  await expect(page.locator(".refraction-story")).toHaveAttribute("data-motion", "enabled");
  expect((await scene.boundingBox())!.height).toBeLessThanOrEqual(420.5);
});

test("homepage content and navigation work without JavaScript", async ({ browser, baseURL }) => {
  const context = await browser.newContext({
    javaScriptEnabled: false,
    viewport: { width: 1280, height: 800 },
  });
  const page = await context.newPage();
  try {
    await page.goto(baseURL!);
    await expect(page.getByRole("heading", { name: "Give structure to change." })).toBeVisible();
    await expect(page.locator(".refraction-visual")).toHaveCSS("position", "static");
    const contextScene = page.getByRole("img", { name: /^A vermilion result trace/ });
    await contextScene.scrollIntoViewIfNeeded();
    await expect(contextScene).toBeVisible();
    await expect(page.locator(".context-visual")).toHaveCSS("position", "static");
    await expect
      .poll(() =>
        contextScene
          .locator("img")
          .evaluateAll((images: HTMLImageElement[]) =>
            images.every((image) => image.complete && image.naturalWidth === 1536),
          ),
      )
      .toBe(true);
    await page.getByRole("link", { name: "Go to the handbook" }).click();
    await expect(page.locator("#handbook-title")).toBeInViewport();
    await page.getByRole("link", { name: "Follow the quickstart", exact: true }).click();
    await expect(page.getByRole("heading", { name: /^Define your data/ })).toBeVisible();
  } finally {
    await context.close();
  }
});
