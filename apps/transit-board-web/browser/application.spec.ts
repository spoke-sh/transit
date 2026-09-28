import { test, expect } from "@playwright/test";
test("complete definition editing and exact operator recovery", async ({ page }) => {
  test.setTimeout(180000);
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto("/definition");
  await expect(page.getByRole("heading", { name: "Definition", exact: true })).toBeVisible();
  await expect(page.getByText("Operator endpoint enabled", { exact: false })).toBeVisible();
  await page.getByRole("button", { name: "Load current definition" }).click();
  await expect(page.getByLabel("Interface SQL")).toHaveValue(/CREATE INTERFACE "board"/);
  const original = await page.getByLabel("Interface SQL").inputValue();
  await page.getByLabel("Interface SQL").fill(original + "\nDROP INTERFACE board;");
  await page.getByRole("button", { name: "Validate program" }).click();
  await expect(page.getByRole("status")).toHaveText("UnsupportedQuery");
  await page.getByLabel("Interface SQL").fill(original);
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
  const submitted: string[] = [];
  await page.route("**/api/v1/application", async (route) => {
    const value = route.request().postDataJSON();
    if (value.submit) {
      submitted.push(JSON.stringify(value.submit));
      if (!dropped) {
        dropped = true;
        await route.fetch();
        await route.abort("failed");
        return;
      }
    }
    await route.continue();
  });
  await page.getByRole("button", { name: "Publish reviewed definition" }).click();
  await expect(page.getByRole("button", { name: "Retry exact submission" })).toBeVisible();
  const changedDraft = (await page.getByLabel("Interface SQL").inputValue()).replace(
    "My atlas",
    "Unreviewed atlas",
  );
  await page.getByLabel("Interface SQL").fill(changedDraft);
  await expect(page.getByLabel("Publication review")).toContainText("Base 0 → revision 1");
  await page.getByRole("link", { name: "Back to atlas" }).click();
  await page.getByRole("link", { name: "Definition", exact: true }).click();
  await expect(page.getByRole("button", { name: "Retry exact submission" })).toBeVisible();
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
  await page.getByRole("button", { name: "Load current definition" }).click();
  await expect(page.getByLabel("Interface SQL")).toHaveValue(/My atlas/);
  await page.screenshot({ path: "../../.cache/verification/m23-definition.png", fullPage: true });
  expect(errors).toEqual([]);
});
