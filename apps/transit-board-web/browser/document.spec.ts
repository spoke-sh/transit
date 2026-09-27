import { test, expect } from "@playwright/test";
import { execFileSync } from "node:child_process";

test("accepted Document metadata clears on current read revocation", async ({ page, context }) => {
  page.setDefaultTimeout(15000);
  const errors: string[] = [],
    writes: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("request", (request) => {
    if (request.method() !== "GET") writes.push(request.url());
  });
  const resource = process.env.BOARD_DOCUMENT_RESOURCE!;
  const admin = (path: string) =>
    execFileSync(process.env.BOARD_DOCUMENT_CLI!, [
      "growing-submit",
      process.env.BOARD_DOCUMENT_SEED!,
      path,
      process.env.BOARD_DOCUMENT_AUTHORITY!,
    ]);
  await page.goto("/");
  await page.getByRole("button", { name: `Select resource ${resource}`, exact: true }).click();
  await page.getByRole("button", { name: "Inspect records", exact: true }).click();
  const records = page.getByRole("region", { name: `Resource ${resource} records`, exact: true });
  await records.getByRole("button", { name: "Inspect Document metadata", exact: true }).click();
  const metadata = page.getByRole("region", { name: "Document 17 metadata", exact: true });
  await expect(
    metadata.getByText("Register page: 5 registers · 1 conflicts · 6 assignments.", {
      exact: true,
    }),
  ).toBeVisible();
  await expect(metadata.getByText("Retained history floor", { exact: true })).toBeVisible();
  await expect(metadata.getByText("Type / change format", { exact: true })).toBeVisible();
  await page.screenshot({
    path: "../../.cache/verification/m17-board-document.png",
    fullPage: true,
  });
  admin(process.env.BOARD_DOCUMENT_REVOKE!);
  await expect(metadata).toHaveCount(0);
  await expect(
    page.getByRole("heading", { name: "Document 17 · revision 3", exact: true }),
  ).toHaveCount(0);
  admin(process.env.BOARD_DOCUMENT_RESTORE!);
  await page.reload();
  await page.getByRole("button", { name: `Select resource ${resource}`, exact: true }).click();
  await page.getByRole("button", { name: "Inspect records", exact: true }).click();
  await expect(
    records.getByRole("heading", { name: "Document 17 · revision 3", exact: true }),
  ).toBeVisible();
  expect(errors).toEqual([]);
  expect(writes).toEqual([]);
  expect(await context.cookies()).toEqual([]);
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
});
