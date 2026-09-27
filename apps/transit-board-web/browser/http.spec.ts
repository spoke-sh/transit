import { test, expect } from "@playwright/test";
import { execFileSync } from "node:child_process";

test("captured HTTP evidence is inspection-only and clears after read revocation", async ({
  page,
  context,
}) => {
  page.setDefaultTimeout(15000);
  const errors: string[] = [];
  const writes: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("request", (request) => {
    if (request.method() !== "GET") writes.push(request.url());
  });
  const resource = process.env.BOARD_HTTP_RESOURCE!;
  const admin = (mode: string) =>
    execFileSync(process.env.BOARD_HTTP_PROOF!, [
      process.env.BOARD_HTTP_AUTHORITY!,
      mode,
      process.env.BOARD_HTTP_STATE!,
    ]);
  await page.goto("/");
  await page.getByRole("button", { name: `Select resource ${resource}`, exact: true }).click();
  await page.getByRole("button", { name: "Inspect records", exact: true }).click();
  const records = page.getByRole("region", { name: `Resource ${resource} records`, exact: true });
  await expect(
    records.getByRole("heading", { name: "Exchange 1 · complete", exact: true }),
  ).toBeVisible();
  await expect(
    records.getByText(
      "Capture completion is separate from kernel settlement and remote business success.",
    ),
  ).toBeVisible();
  await page.screenshot({ path: "../../.cache/verification/m15-board-http.png", fullPage: true });
  admin("board-revoke");
  await expect(
    records.getByRole("heading", { name: "Exchange 1 · complete", exact: true }),
  ).toHaveCount(0);
  await expect(records.getByRole("status")).toContainText("denied");
  admin("board-restore");
  await records.getByRole("button", { name: "Refresh records", exact: true }).click();
  await expect(
    records.getByRole("heading", { name: "Exchange 1 · complete", exact: true }),
  ).toBeVisible();
  expect(writes).toEqual([]);
  expect(errors).toEqual([]);
  expect(await context.cookies()).toEqual([]);
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
});
