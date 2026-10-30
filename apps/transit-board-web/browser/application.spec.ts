import AxeBuilder from "@axe-core/playwright";
import { test, expect } from "@playwright/test";
test("complete definition editing and exact operator recovery", async ({ page, context }) => {
  test.setTimeout(180000);
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto("/definition");
  await expect(page.getByRole("heading", { name: "Definition", exact: true })).toBeVisible();
  await expect(page.getByText("Operator endpoint enabled", { exact: false })).toBeVisible();
  const oldClient = await context.newPage();
  await oldClient.goto("/atlas");
  await expect(oldClient.locator(".transit-shell")).toHaveAttribute(
    "data-interface-generation",
    /^builtin\//,
  );
  await page.bringToFront();
  await page.getByRole("button", { name: "Load current definition" }).click();
  await expect(page.getByLabel("Interface SQL")).toHaveValue(/CREATE INTERFACE "board"/);
  const original = await page.getByLabel("Interface SQL").inputValue();
  await page.getByLabel("Interface SQL").fill(original + "\nDROP INTERFACE board;");
  await page.getByRole("button", { name: "Validate program" }).click();
  await expect(page.getByRole("status")).toHaveText("UnsupportedQuery");
  await expect(page.getByLabel("Application diagnostic")).toContainText(
    "application.unsupported_interface_statement",
  );
  await expect(page.getByLabel("Application diagnostic")).toContainText("not submitted");
  await page.getByLabel("Interface SQL").fill(original);
  await expect(page.getByLabel("Application diagnostic")).toHaveCount(0);
  await page.getByRole("button", { name: "Validate program" }).click();
  await expect(page.getByRole("status")).toContainText("Complete program validated");
  await page.getByRole("button", { name: "Form", exact: true }).click();
  await page.getByLabel("Interface theme").selectOption("dense");
  await expect(page.getByRole("status")).toContainText("Visual edit validated");
  await page.getByRole("button", { name: "Canvas", exact: true }).click();
  await page.getByRole("button", { name: "screen: Atlas", exact: true }).click();
  await page.getByLabel("Selected screen label").fill("My atlas");
  await page.getByLabel("Selected screen label").press("Tab");
  await expect(page.getByRole("button", { name: "screen: My atlas", exact: true })).toBeVisible();
  await page.getByRole("button", { name: "SQL", exact: true }).click();
  await expect(page.getByLabel("Interface SQL")).toHaveValue(/My atlas/);
  const routed = (await page.getByLabel("Interface SQL").inputValue()).replace(
    "'/atlas'",
    "'/neighborhood'",
  );
  await page.getByLabel("Interface SQL").fill(routed);
  await page.getByRole("button", { name: "Validate program" }).click();
  await expect(page.getByRole("status")).toContainText("Complete program validated");
  await page.getByLabel("Operator principal").fill("65537");
  // Fixed disposable fixture key, never a repository or deployment credential.
  await expect(page.getByLabel("Operator key", { exact: true })).toBeEnabled();
  await page.getByLabel("Operator key", { exact: true }).setInputFiles({
    name: "operator.pk8",
    mimeType: "application/octet-stream",
    buffer: Buffer.from("302e020100300506032b657004220420" + "09".repeat(32), "hex"),
  });
  await expect(page.getByRole("status")).toHaveText("Operator identity verified.");
  await page.getByRole("button", { name: "Review publication" }).click();
  await expect(page.getByLabel("Publication review")).toContainText("Base 0 → revision 1");
  let dropped = false;
  let dropPart = false;
  let dropCollect = false;
  const submitted: string[] = [];
  await page.route("**/api/v1/application", async (route) => {
    const value = route.request().postDataJSON();
    if (value.submit) {
      submitted.push(JSON.stringify(value.submit));
      if (
        !dropped ||
        (dropPart && value.submit.prepared.command.part?.second) ||
        (dropCollect && value.submit.prepared.command.collect)
      ) {
        dropped = true;
        dropPart = false;
        dropCollect = false;
        await route.fetch();
        await route.abort("failed");
        return;
      }
    }
    await route.continue();
  });
  await page.getByRole("button", { name: "Publish reviewed definition" }).click();
  await expect(page.getByRole("button", { name: "Retry exact submission" })).toBeVisible({
    timeout: 30000,
  });
  const changedDraft = (await page.getByLabel("Interface SQL").inputValue()).replace(
    "My atlas",
    "Unreviewed atlas",
  );
  await page.getByLabel("Interface SQL").fill(changedDraft);
  await expect(page.getByLabel("Publication review")).toContainText("Base 0 → revision 1");
  await page.getByRole("link", { name: "Back to atlas" }).click();
  await page.getByRole("link", { name: "Definition recovery", exact: true }).click();
  await expect(page.getByRole("button", { name: "Retry exact submission" })).toBeVisible({
    timeout: 30000,
  });
  await page.getByRole("button", { name: "Retry exact submission" }).click();
  await expect(page.getByRole("status")).toContainText("Native admission recovered");
  expect(submitted[0]).toEqual(submitted[1]);
  const planDownload = page.waitForEvent("download");
  await page.getByRole("button", { name: "Save reviewed plan" }).click();
  const planPath = await (await planDownload).path();
  await page.reload();
  await page.getByLabel("Operator principal").fill("65537");
  await expect(page.getByLabel("Operator key", { exact: true })).toBeEnabled();
  await page.getByLabel("Operator key", { exact: true }).setInputFiles({
    name: "operator.pk8",
    mimeType: "application/octet-stream",
    buffer: Buffer.from("302e020100300506032b657004220420" + "09".repeat(32), "hex"),
  });
  await expect(page.getByRole("status")).toHaveText("Operator identity verified.");
  await page.getByLabel("Restore reviewed plan", { exact: true }).setInputFiles(planPath!);
  await expect(page.getByRole("status")).toContainText("original base remains frozen");
  await page.getByRole("button", { name: "Publish reviewed definition" }).click();
  await expect(page.getByRole("status")).toHaveText("Published revision 1", { timeout: 120000 });
  await page.getByRole("button", { name: "Abandon upload and release staging" }).click();
  await expect(page.getByRole("status")).toHaveText("ApplicationAlreadyApplied");
  await expect(page.getByLabel("Application diagnostic")).toContainText("publication.applied");
  await expect(page.getByLabel("Application diagnostic")).toContainText("cannot roll back");
  await page.getByRole("button", { name: "Load current definition" }).click();
  await expect(page.getByLabel("Interface SQL")).toHaveValue(/My atlas/);
  await page.getByRole("button", { name: "Review publication" }).click();
  await expect(page.getByLabel("Publication review")).toContainText("Base 1 → revision 2");
  dropPart = true;
  await page.getByRole("button", { name: "Publish reviewed definition" }).click();
  await expect(page.getByRole("button", { name: "Retry exact submission" })).toBeVisible({
    timeout: 30000,
  });
  await page.getByRole("button", { name: "Retry exact submission" }).click();
  await expect(page.getByRole("status")).toContainText("Native admission recovered");
  dropCollect = true;
  await page.getByRole("button", { name: "Abandon upload and release staging" }).click();
  await expect(page.getByRole("button", { name: "Retry exact submission" })).toBeVisible({
    timeout: 30000,
  });
  const cleanupSubmission = submitted.at(-1);
  await page.getByRole("button", { name: "Retry exact submission" }).click();
  await expect(page.getByRole("status")).toContainText("Native admission recovered");
  expect(submitted.at(-1)).toEqual(cleanupSubmission);
  await page.getByRole("button", { name: "Abandon upload and release staging" }).click();
  await expect(page.getByRole("status")).toHaveText(
    "Upload abandoned; staging reservation released. History retained.",
  );
  await oldClient.bringToFront();
  await expect(oldClient.locator(".transit-shell")).toHaveAttribute(
    "data-interface-generation",
    /^49\/board\/1\//,
    { timeout: 15000 },
  );
  await expect(oldClient.locator(".transit-shell")).toHaveAttribute("data-density", "compact");
  await expect(oldClient.getByRole("link", { name: "My atlas", exact: true })).toBeVisible();
  await expect(oldClient.getByRole("heading", { name: "Screen unavailable" })).toBeVisible();
  await oldClient.getByRole("link", { name: "My atlas", exact: true }).click();
  await expect(oldClient).toHaveURL(/\/neighborhood$/);
  await oldClient.reload();
  await expect(oldClient.getByRole("heading", { name: "Relief atlas", exact: true })).toBeVisible();
  await oldClient.emulateMedia({ reducedMotion: "reduce" });
  await oldClient.getByRole("button", { name: "Flat view", exact: true }).focus();
  await oldClient.keyboard.press("Enter");
  await expect(oldClient.getByLabel("Authorized neighborhood", { exact: true })).toHaveClass(
    /flat/,
  );
  await oldClient.getByRole("button", { name: "Browse", exact: true }).focus();
  await oldClient.keyboard.press("Enter");
  await expect(oldClient.getByRole("heading", { name: "Processes", exact: true })).toBeVisible();
  await oldClient.getByRole("link", { name: "Activity", exact: true }).click();
  await expect(oldClient.getByRole("heading", { name: "Activity", exact: true })).toBeVisible();
  await oldClient
    .getByRole("navigation", { name: "Activities" })
    .getByRole("link", { name: "Operations", exact: true })
    .click();
  await expect(
    oldClient.getByRole("heading", { name: "Declared dependencies", exact: true }),
  ).toBeVisible();
  await oldClient.close();
  await page.bringToFront();
  await expect(page.locator(".transit-shell")).toHaveAttribute("data-density", "compact", {
    timeout: 15000,
  });
  const header = await page.locator(".shell-header").boundingBox();
  const sidebar = await page.locator(".shell-navigation").boundingBox();
  expect(header?.height).toBe(56);
  expect(sidebar?.width).toBe(208);
  for (const density of ["comfortable", "compact"]) {
    if (!(await page.getByLabel("Preview density").isVisible()))
      await page.getByRole("button", { name: "Navigation", exact: true }).click();
    await page.getByLabel("Preview density").selectOption(density);
    expect(
      (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze()).violations,
    ).toEqual([]);
    await page.setViewportSize({ width: 320, height: 900 });
    if (!(await page.getByLabel("Preview density").isVisible()))
      await page.getByRole("button", { name: "Navigation", exact: true }).click();
    await expect(page.getByLabel("Preview density")).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
      true,
    );
    await page.getByRole("button", { name: "Navigation", exact: true }).click();
    await page.setViewportSize({ width: 1440, height: 1050 });
    await page.evaluate(() => {
      document.documentElement.style.zoom = "2";
    });
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= document.documentElement.clientWidth,
      ),
    ).toBe(true);
    await expect(page.getByRole("button", { name: "Validate program", exact: true })).toBeVisible();
    await page.evaluate(() => {
      document.documentElement.style.zoom = "1";
    });
  }
  await page.screenshot({ path: "../../.cache/verification/m23-definition.png", fullPage: true });
  expect(errors).toEqual([]);
});
