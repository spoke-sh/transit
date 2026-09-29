import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { readFileSync } from "node:fs";
import path from "node:path";
import { specifications } from "../lib/specs";
import { pages } from "../catalog";

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
  await expect(page.getByRole("heading", { name: "Build on durable state." })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath("desktop.png"), fullPage: true });
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.getByRole("link", { name: "SQL Syntax, types and query profiles" }).click();
  await expect(page.getByRole("heading", { name: "SQL reference", exact: true })).toBeVisible();
  await expect(page.getByText("grammar-only", { exact: true })).toBeVisible();
  await page.getByRole("link", { name: "Search", exact: true }).click();
  await page.getByLabel("Words or an interface name").fill("Flight");
  await page
    .locator(".search-results")
    .getByRole("link", { name: "Flight SQL and ADBC", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Flight SQL and ADBC", exact: true }),
  ).toBeVisible();
  for (const entry of specifications) {
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
  await page.goto(new URL("concepts/architecture", baseURL).href);
  await expect(page.locator(".docusaurus-mermaid-container svg").first()).toBeVisible();
  expect(errors).toEqual([]);
});

test("mobile menu, readable content and dark-mode accessibility", async ({
  page,
  baseURL,
}, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ colorScheme: "dark" });
  await page.goto(baseURL!);
  await expect(page.getByRole("heading", { name: "Build on durable state." })).toBeVisible();
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
  await page.goto(new URL("reference/cli", baseURL).href);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
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
