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
    acceptedLost = false,
    refuseClose = false;
  const closeAttempts: string[] = [];
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
  await expect(
    page.getByRole("button", { name: "Close interrupted query", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Run relational query", exact: true }),
  ).toBeDisabled();
  await page.getByRole("button", { name: "Close interrupted query", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Close interrupted query", exact: true }),
  ).toHaveCount(0);
  expect(opens).toBe(0);
  await page.getByRole("button", { name: "Inspect relational workspace", exact: true }).click();
  await expect(worksheet).toContainText("Catalog routes");
  await page.getByRole("button", { name: "Add JOIN route", exact: true }).click();
  await page.getByLabel("JOIN route", { exact: true }).selectOption("1");
  await page.getByRole("button", { name: "Explain relational query", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Proposed plan · not executed" })).toBeVisible();
  expect(opens).toBe(0);
  const storage = page.getByRole("region", { name: "Storage for l", exact: true });
  await storage.getByRole("button", { name: "Inspect storage for l", exact: true }).click();
  await expect(storage).toContainText("Current storage observation");
  await expect(storage).toContainText("Accepted position");
  await expect(storage).toContainText("History floor");
  expect(opens).toBe(0);
  await page.route("**/api/v1/relational", async (route) => {
    if (refuseClose && route.request().postDataJSON().query?.close) {
      closeAttempts.push(route.request().postData()!);
      if (closeAttempts.length === 1) {
        await route.fulfill({ status: 429, json: { err: "RateLimited", diagnostic: null } });
        return;
      }
    }
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
    execFileSync(process.env.BOARD_RELATIONAL_PROOF!, [
      process.env.BOARD_RELATIONAL_AUTHORITY!,
      allow ? "caller-allow" : "caller-deny",
      process.env.BOARD_RELATIONAL_PROFILE!,
    ]);
  };
  try {
    policy(false);
    await expect(worksheet).toContainText("Forbidden", { timeout: 15000 });
    await expect(page.getByRole("table", { name: "One current authorized row" })).toHaveCount(0);
    await expect(page.getByLabel("Relational SQL", { exact: true })).toHaveValue("");
  } finally {
    policy(true);
  }
  // A pre-dispatch refusal must retain the exact close request through the
  // client's bounded retry. Observe its final outcome, not the first attempt.
  refuseClose = true;
  const closed = page.waitForResponse(
    (response) =>
      response.url().endsWith("/api/v1/relational") &&
      response.request().method() === "POST" &&
      !!response.request().postDataJSON().query?.close &&
      response.status() !== 429,
  );
  await page.getByRole("button", { name: "Close relational query", exact: true }).click();
  expect((await closed).status()).toBe(200);
  await expect(
    page.getByRole("button", { name: "Inspect relational workspace", exact: true }),
  ).toBeEnabled();
  expect(closeAttempts.length).toBeGreaterThanOrEqual(2);
  expect(closeAttempts.length).toBeLessThanOrEqual(4);
  expect(new Set(closeAttempts).size).toBe(1);
  await expect(
    page.getByRole("button", { name: "Close relational query", exact: true }),
  ).toBeDisabled();
  await expect(
    page.getByRole("button", { name: "Close interrupted query", exact: true }),
  ).toHaveCount(0);
  expect(errors).toEqual([]);
});
