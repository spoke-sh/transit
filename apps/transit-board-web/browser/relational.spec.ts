import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { execFileSync } from "node:child_process";

test("explicit relational pages recover the same host and clear on current denial", async ({
  page,
}) => {
  test.setTimeout(150000);
  page.setDefaultTimeout(15000);
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  let opens = 0,
    acceptedLost = false;
  page.on("request", (request) => {
    if (
      request.url().endsWith("/api/v1/relational") &&
      request.method() === "POST" &&
      request.postDataJSON().query?.open
    )
      opens++;
  });
  await page.goto("/operations");
  const worksheet = page.getByRole("region", { name: "Relational worksheet" });
  await expect(worksheet).toBeVisible();
  await page.getByLabel("Relational SQL", { exact: true }).fill(process.env.BOARD_RELATIONAL_SQL!);
  expect(opens).toBe(0);
  await page.getByRole("button", { name: "Inspect relational workspace", exact: true }).click();
  await expect(worksheet).toContainText("Catalog routes");
  await page.getByRole("button", { name: "Add JOIN route", exact: true }).click();
  await page.getByLabel("JOIN route", { exact: true }).selectOption("1");
  await page.getByRole("button", { name: "Explain relational query", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Proposed plan · not executed" })).toBeVisible();
  expect(opens).toBe(0);
  await page.route("**/api/v1/relational", async (route) => {
    if (!acceptedLost && route.request().postDataJSON().query?.open) {
      const response = await route.fetch();
      if (response.status() === 200) {
        acceptedLost = true;
        await route.fulfill({ status: 503, json: { err: "Unavailable", diagnostic: null } });
      } else await route.fulfill({ response });
    } else await route.continue();
  });
  await page.getByRole("button", { name: "Run relational query", exact: true }).click();
  await expect(worksheet).toContainText("Relational query unavailable");
  expect(acceptedLost).toBe(true);
  const originalOpens = opens;
  await page.getByRole("button", { name: "Inspect relational workspace", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Active query", exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Read current relational page", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Incomplete prefix · page 0" })).toBeVisible();
  await expect(page.getByRole("table", { name: "One current authorized row" })).toContainText(
    "NULL",
  );
  await page.getByRole("button", { name: "Next relational page", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Incomplete prefix · page 1" })).toBeVisible();
  await expect(page.getByRole("table", { name: "One current authorized row" })).toContainText("16");
  await page.reload();
  await page.getByRole("button", { name: "Inspect relational workspace", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Active query", exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Read current relational page", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Incomplete prefix · page 1" })).toBeVisible();
  expect(opens).toBe(originalOpens);
  await page.getByRole("button", { name: "Next relational page", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Incomplete prefix · page 2" })).toBeVisible();
  await page.getByRole("button", { name: "Next relational page", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Complete coverage · page 3" })).toBeVisible();
  await expect(page.getByRole("table", { name: "One current authorized row" })).toHaveCount(0);
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.getByRole("button", { name: "Close relational query", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Active query", exact: true })).toHaveCount(0);
  await page.getByLabel("Relational SQL", { exact: true }).fill(process.env.BOARD_RELATIONAL_SQL!);
  await page.getByRole("button", { name: "Add JOIN route", exact: true }).click();
  await page.getByLabel("JOIN route", { exact: true }).selectOption("1");
  await page.getByRole("button", { name: "Run relational query", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Active query", exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Read current relational page", exact: true }).click();
  await expect(page.getByRole("table", { name: "One current authorized row" })).toBeVisible();
  const policy = (allow: boolean) => {
    const root = `${process.env.BOARD_RELATIONAL_ROOT!}/secondary`;
    execFileSync(process.env.BOARD_RELATIONAL_PROOF!, [
      process.env.BOARD_RELATIONAL_AUTHORITY!,
      "policy",
      root,
      allow ? "allow" : "deny",
    ]);
    execFileSync(process.env.BOARD_RELATIONAL_PROOF!, [
      process.env.BOARD_RELATIONAL_AUTHORITY!,
      "pump",
      root,
    ]);
  };
  try {
    policy(false);
    await expect(worksheet).toContainText("Forbidden", { timeout: 15000 });
    await expect(page.getByRole("table", { name: "One current authorized row" })).toHaveCount(0);
    await expect(page.getByLabel("Relational SQL", { exact: true })).toHaveValue("");
    await page.getByRole("button", { name: "Close relational query", exact: true }).click();
    await expect(
      page.getByRole("button", { name: "Close relational query", exact: true }),
    ).toBeDisabled();
  } finally {
    policy(true);
  }
  expect(errors).toEqual([]);
});
