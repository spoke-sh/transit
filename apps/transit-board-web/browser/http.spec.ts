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
  // Equal observation timers can repeatedly collide at the shared read throttle.
  // Keep the original five-second assertions and require bounded read recovery.
  const throttled = new Map([
    [`/api/v1/resources/${resource}/records`, 0],
    [`/api/v1/resources/${resource}/http/1`, 0],
  ]);
  for (const path of throttled.keys()) {
    await page.route(`**${path}`, async (route) => {
      const count = throttled.get(path)!;
      if (count < 2) {
        throttled.set(path, count + 1);
        await route.fulfill({
          status: 429,
          contentType: "application/json",
          body: JSON.stringify({ err: "RateLimited" }),
        });
      } else await route.continue();
    });
  }
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
  await records.getByRole("button", { name: "Inspect HTTP metadata", exact: true }).click();
  const metadata = page.getByRole("region", { name: "HTTP metadata for exchange 1", exact: true });
  await expect(metadata.getByText("Endpoint policy revision", { exact: true })).toBeVisible();
  await expect(metadata.getByText("Omitted request secrets", { exact: true })).toBeVisible();
  await expect(metadata.getByText("Elapsed time (ns)", { exact: true })).toBeVisible();
  await page.screenshot({ path: "../../.cache/verification/m15-board-http.png", fullPage: true });
  admin("board-revoke");
  await expect(
    records.getByRole("heading", { name: "Exchange 1 · complete", exact: true }),
  ).toHaveCount(0);
  await expect(metadata).toHaveCount(0);
  await expect(records.getByRole("status")).toContainText("denied");
  admin("board-restore");
  await records.getByRole("button", { name: "Refresh records", exact: true }).click();
  await expect(
    records.getByRole("heading", { name: "Exchange 1 · complete", exact: true }),
  ).toBeVisible();
  expect(writes).toEqual([]);
  expect([...throttled.values()]).toEqual([2, 2]);
  expect(errors).toEqual([]);
  expect(await context.cookies()).toEqual([]);
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
});
