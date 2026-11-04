import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import type { HistoricalCoverage } from "@transit/board-client";

test("retained diagram and grid match the public caller across evolution, rename and reopen", async ({
  page,
}) => {
  // Produced by the installed signed caller after flush/evolution and checked
  // again after disk reopen. No credentials or row payloads enter this file.
  const expected = JSON.parse(readFileSync(process.env.BOARD_PLACEMENT_EVIDENCE!, "utf8")) as {
    selector: string;
    object: string;
    empty_selector: string;
    definitions: HistoricalCoverage[];
    locations: HistoricalCoverage["locations"];
  };
  const actions: string[] = [];
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("request", (request) => {
    if (request.method() === "POST") actions.push(request.url().split("/").at(-1)!);
  });
  await page.goto("/operations");
  await expect(page.getByRole("region", { name: "Maintenance", exact: true })).toBeVisible();
  if (process.env.BOARD_SCREENSHOT)
    await page.screenshot({
      path: process.env.BOARD_SCREENSHOT.replace(/\.png$/, "-operations.png"),
      fullPage: true,
    });
  await page.getByText("Inspect a retained catalog", { exact: true }).click();
  await page.getByLabel("Snapshot selector", { exact: true }).fill(expected.selector);
  await page.getByRole("button", { name: "Inspect snapshot", exact: true }).click();
  const catalog = page.getByRole("region", { name: "Retained catalog", exact: true });
  await catalog.getByRole("button", { name: "placement_probe", exact: true }).click();
  const interpretation = page.getByRole("region", { name: "Retained interpretation", exact: true });
  await expect(interpretation).toContainText(`Object ${expected.object}`);
  await expect(interpretation).toContainText("20 retained rows");
  await expect(catalog.getByRole("button", { name: "placement_renamed", exact: true })).toHaveCount(
    0,
  );
  const physical = interpretation.getByRole("region", {
    name: "Physical definitions evidence",
    exact: true,
  });
  const inspector = page.getByRole("complementary", { name: "Inspector", exact: true });
  for (const [index, coverage] of expected.definitions.entries()) {
    const definition = coverage.definitions!;
    await expect(physical.getByRole("table").locator("tbody tr")).toHaveCount(
      definition.columns.length,
    );
    for (const column of definition.columns) {
      const row = physical
        .getByRole("table")
        .getByRole("row")
        .filter({
          has: page.getByRole("button", { name: new RegExp(`^Column ${column.column} ·`) }),
        });
      const origin =
        "physical" in column.source
          ? `physical column ${column.source.physical}`
          : `ADD-time ${column.source.initial.state}, definition ${column.source.initial.definition.revision}`;
      await expect(row).toContainText(origin);
      await row.getByRole("button").click();
      await expect(inspector).toContainText(definition.physical.interpretation.digest);
      await expect(inspector).toContainText(expected.selector);
      await page.keyboard.press("Escape");
    }
    if (index === 0) {
      if (process.env.BOARD_SCREENSHOT)
        await physical.screenshot({
          path: process.env.BOARD_SCREENSHOT.replace(/\.png$/, "-definitions.png"),
        });
      await interpretation.getByRole("button", { name: "Next coverage page", exact: true }).click();
    }
  }
  await expect(
    interpretation.getByRole("button", { name: "Next coverage page", exact: true }),
  ).toBeDisabled();
  await interpretation
    .getByRole("combobox", { name: "Coverage", exact: true })
    .selectOption("locations");
  const placement = interpretation.getByRole("region", {
    name: "Row placement evidence",
    exact: true,
  });
  for (let start = 0; start < expected.locations.length; start += 8) {
    const rows = expected.locations.slice(start, start + 8);
    await expect(placement.getByRole("table").locator("tbody tr")).toHaveCount(rows.length);
    for (const location of rows) {
      const identity = location.identity;
      const name = `Row ${identity.origin}:${identity.operation}:${identity.ordinal}`;
      const row = placement
        .getByRole("table")
        .getByRole("row")
        .filter({ has: page.getByRole("button", { name, exact: true }) });
      const target =
        "wal" in location.location
          ? `WAL LSN ${location.location.wal.lsn}`
          : `Segment ${location.location.segment.id}`;
      await expect(row).toContainText(target);
    }
    await placement.getByRole("table").getByRole("button", { name: /^Row / }).first().click();
    const location = rows[0]!;
    await expect(inspector).toContainText(
      "wal" in location.location
        ? location.location.wal.row_digest
        : location.location.segment.content.sha256,
    );
    await page.keyboard.press("Escape");
    if (start + 8 < expected.locations.length)
      await interpretation.getByRole("button", { name: "Next coverage page", exact: true }).click();
  }
  await expect(interpretation).toContainText("Directory traversal ends here");
  await expect(
    interpretation.getByRole("button", { name: "Next coverage page", exact: true }),
  ).toBeDisabled();
  // Reflow at 200% CSS zoom and narrow viewport are checked independently.
  await page.evaluate(() => {
    document.documentElement.style.zoom = "2";
  });
  await placement.getByRole("table").getByRole("button", { name: /^Row / }).first().click();
  await expect(inspector).toBeVisible();
  await page.keyboard.press("Escape");
  await page.evaluate(() => {
    document.documentElement.style.zoom = "1";
  });
  await page.setViewportSize({ width: 390, height: 844 });
  await placement.getByRole("table").getByRole("button", { name: /^Row / }).first().click();
  await expect(page.getByRole("button", { name: "Back to workspace" })).toBeFocused();
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  if (process.env.BOARD_SCREENSHOT)
    await page.screenshot({
      path: process.env.BOARD_SCREENSHOT.replace(/\.png$/, "-narrow.png"),
      fullPage: true,
    });
  await page.keyboard.press("Escape");
  await page.setViewportSize({ width: 1440, height: 1050 });
  await page.getByLabel("Snapshot selector", { exact: true }).fill(expected.empty_selector);
  await page.getByRole("button", { name: "Inspect snapshot", exact: true }).click();
  await expect(placement).toHaveCount(0);
  await catalog.getByRole("button", { name: "empty_metrics", exact: true }).click();
  await expect(physical).toContainText("No physical definitions in this authorized page");
  await interpretation
    .getByRole("combobox", { name: "Coverage", exact: true })
    .selectOption("locations");
  await expect(placement).toContainText("No row locations in this authorized page");
  await expect(placement.getByRole("table")).toHaveCount(0);
  await expect(
    interpretation.getByRole("button", { name: "Next coverage page", exact: true }),
  ).toBeDisabled();
  await page.route("**/api/v1/catalog", async (route) => {
    if (route.request().postDataJSON().action.history)
      await route.fulfill({ status: 409, json: { err: "QueryExpired", diagnostic: null } });
    else await route.continue();
  });
  await expect(
    page.getByRole("heading", { name: /Data.*expired|Data.*changed|Data.*retained/i }).first(),
  ).toBeVisible({ timeout: 12000 });
  await expect(placement).toHaveCount(0);
  await expect(inspector.locator(".inspector-subject")).toHaveCount(0);
  await expect(
    page.getByRole("region", { name: "Capacity and allocation", exact: true }),
  ).toBeVisible();
  expect(actions.length).toBeGreaterThan(5);
  expect(actions.every((action) => action === "catalog")).toBe(true);
  expect(errors).toEqual([]);
});
