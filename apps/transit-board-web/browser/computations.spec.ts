import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import type { ComputationResponse } from "@transit/board-client/computations";
test("deferred computation diagram, grid and inspector share verified metadata", async ({
  page,
}) => {
  const expected = JSON.parse(
    readFileSync(process.env.BOARD_COMPUTATION_EVIDENCE!, "utf8"),
  ) as ComputationResponse;
  const scripts: string[] = [];
  const actions: string[] = [];
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("request", (request) => {
    if (request.resourceType() === "script") scripts.push(request.url());
    if (request.method() === "POST") actions.push(request.url().split("/").at(-1)!);
  });
  await page.goto("/operations");
  await expect(page.getByRole("heading", { name: "Operations", exact: true })).toBeVisible();
  expect(scripts.some((url) => /\/computations-/.test(url))).toBe(false);
  await page.getByRole("button", { name: "Inspect a computation", exact: true }).click();
  await page.getByLabel("Computation name", { exact: true }).fill("managed_projection");
  await page.getByRole("button", { name: "Inspect", exact: true }).click();
  const computation = page.getByRole("region", {
    name: "Computation managed_projection",
    exact: true,
  });
  await expect(computation).toBeVisible();
  expect(scripts.some((url) => /\/computations-/.test(url))).toBe(true);
  const graph = computation.getByRole("group", { name: "Declared computation flow" });
  const grid = computation.getByRole("table", { name: "Declared source, computation and output" });
  for (const binding of [expected.source, expected.binding, expected.output]) {
    await expect(graph).toContainText(binding.name);
    await expect(grid).toContainText(binding.name);
    await expect(grid).toContainText(binding.interpretation.object.object);
  }
  await graph.getByRole("button", { name: "Computation managed_projection", exact: true }).focus();
  await page.keyboard.press("Enter");
  const inspector = page.getByRole("complementary", { name: "Inspector" });
  await expect(inspector).toContainText(expected.sql);
  await page.keyboard.press("Escape");
  await expect(
    graph.getByRole("button", { name: "Computation managed_projection", exact: true }),
  ).toBeFocused();
  await grid.getByRole("button", { name: "Source Table", exact: true }).click();
  await expect(inspector.getByRole("link", { name: "Open current Table metadata" })).toBeVisible();
  await expect(inspector).toContainText(expected.source.interpretation.digest);
  await page.keyboard.press("Escape");
  await expect(
    computation.getByRole("region", { name: "Last completed result", exact: true }),
  ).toContainText("Revision 5 · Completed · 4 rows");
  await expect(
    computation.getByRole("region", { name: "Current computation", exact: true }),
  ).toContainText("retired");
  await computation.getByLabel("Retained revision", { exact: true }).fill("1");
  await computation.getByRole("button", { name: "Inspect revision", exact: true }).click();
  const selected = computation.getByRole("region", { name: "Selected result", exact: true });
  await expect(selected).toContainText("Completed · 3 rows");
  await computation.getByRole("button", { name: "Refresh computation", exact: true }).click();
  await expect(selected).toContainText("Selected revision 1");
  await expect(selected).toContainText("Completed · 3 rows");
  await computation.getByRole("button", { name: "Latest completed", exact: true }).click();
  await expect(selected).toContainText("Completed · 4 rows");
  await computation.getByLabel("Retained revision", { exact: true }).fill("4");
  await computation.getByRole("button", { name: "Inspect revision", exact: true }).click();
  await expect(selected).toContainText("Completed · 0 rows");
  await computation.getByLabel("Retained revision", { exact: true }).fill("6");
  await computation.getByRole("button", { name: "Inspect revision", exact: true }).click();
  await expect(selected).toContainText("NotFound");
  await expect(selected).not.toContainText("Completed ·");
  await expect(
    computation.getByRole("region", { name: "Last completed result", exact: true }),
  ).toContainText("Completed · 4 rows");
  await computation.getByRole("button", { name: "Latest completed", exact: true }).click();
  await page.setViewportSize({ width: 750, height: 1000 });
  await graph.getByRole("button", { name: "Computation managed_projection", exact: true }).click();
  await expect(
    inspector.getByRole("button", { name: "Close inspector", exact: true }),
  ).toBeFocused();
  await inspector.getByRole("button", { name: "Evidence", exact: true }).click();
  await expect(inspector).toContainText(expected.completed!.decision.attempt.cut.sha256);
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  expect(actions.every((action) => action === "catalog" || action === "computations")).toBe(true);
  await page.keyboard.press("Escape");
  await page.getByLabel("Computation name", { exact: true }).fill("managed_budget");
  await page.getByRole("button", { name: "Inspect", exact: true }).click();
  const blocked = page.getByRole("region", { name: "Computation managed_budget", exact: true });
  await expect(
    blocked.getByRole("region", { name: "Last completed result", exact: true }),
  ).toContainText("No completed result");
  await expect(
    blocked.getByRole("region", { name: "Current computation", exact: true }),
  ).toContainText("budget");
  expect(errors).toEqual([]);
});

test("a denied read clears both observations and the shared inspector", async ({ page }) => {
  let denied = false;
  await page.route("**/api/v1/computations", async (route) => {
    if (denied)
      await route.fulfill({
        status: 403,
        contentType: "application/json",
        body: JSON.stringify({ err: "Forbidden", diagnostic: null }),
      });
    else await route.continue();
  });
  await page.goto("/operations");
  await page.getByRole("button", { name: "Inspect a computation", exact: true }).click();
  await page.getByLabel("Computation name", { exact: true }).fill("managed_projection");
  await page.getByRole("button", { name: "Inspect", exact: true }).click();
  const computation = page.getByRole("region", {
    name: "Computation managed_projection",
    exact: true,
  });
  await expect(computation).toBeVisible();
  await computation.getByLabel("Retained revision", { exact: true }).fill("1");
  await computation.getByRole("button", { name: "Inspect revision", exact: true }).click();
  await expect(
    computation.getByRole("region", { name: "Selected result", exact: true }),
  ).toContainText("Completed · 3 rows");
  await computation
    .getByRole("table")
    .getByRole("button", { name: "Computation", exact: true })
    .click();
  await expect(page.getByRole("complementary", { name: "Inspector" })).toBeVisible();
  denied = true;
  await computation.getByRole("button", { name: "Refresh computation", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Access to Computation denied", exact: true }),
  ).toBeVisible();
  await expect(page.getByRole("complementary", { name: "Inspector" })).toBeHidden();
  await expect(computation).toHaveCount(0);
  denied = false;
  await page.getByRole("button", { name: "Recheck access", exact: true }).click();
  await expect(
    computation.getByRole("region", { name: "Selected result", exact: true }),
  ).toContainText("Selected revision 1");
  await expect(
    computation.getByRole("region", { name: "Selected result", exact: true }),
  ).toContainText("Completed · 3 rows");
});
