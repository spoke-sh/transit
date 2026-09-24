import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
const pid = process.env.BOARD_TEST_PID!;
const sink = process.env.BOARD_TEST_SINK!;
test("real embedded UI explains kernel evidence and retains focus while polling", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto("/");
  await page.getByLabel("Board access key").fill(process.env.BOARD_TEST_ACCESS!);
  await page.getByRole("button", { name: "Open board" }).click();
  await expect(page.getByRole("heading", { name: "Departure board" })).toBeVisible();
  const link = page.getByRole("link", { name: `PID ${pid}`, exact: true });
  await expect(link).toBeVisible();
  await link.focus();
  await page.waitForTimeout(5500);
  await expect(link).toBeFocused();
  await expect(page.getByText(/Blocked on input/)).toBeVisible();
  await link.press("Enter");
  await expect(page.getByRole("heading", { name: `PID ${pid}`, exact: true })).toBeVisible();
  await expect(page.getByText("Counter value:")).toContainText("7");
  await page.getByRole("button", { name: "Arrivals", exact: true }).click();
  await expect(page.getByRole("cell", { name: "consumed", exact: true })).toBeVisible();
  await expect(page.getByRole("cell", { name: "pending", exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Departures", exact: true }).click();
  await expect(page.getByRole("heading", { name: `Output 1 → PID ${sink}` })).toBeVisible();
  await expect(page.getByText("output to admission", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Effects", exact: true }).click();
  await expect(page.getByRole("heading", { name: /closed unknown/ })).toBeVisible();
  await page.getByRole("link", { name: "Journey", exact: true }).click();
  await expect(page.getByRole("heading", { name: `PID ${pid} · journey` })).toBeVisible();
  await expect(page.getByText("input to turn", { exact: true }).first()).toBeVisible();
  await page.reload(); // Nested route, lazy assets, and HttpOnly session survive.
  await expect(page.getByRole("heading", { name: `PID ${pid} · journey` })).toBeVisible();
  await expect(page.getByText("input to turn", { exact: true }).first()).toBeVisible();
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  await page.screenshot({ path: process.env.BOARD_SCREENSHOT, fullPage: true });
  expect(page.url()).not.toContain(process.env.BOARD_TEST_ACCESS!);
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
  expect(await page.evaluate(() => document.cookie)).not.toContain("board_session");
  await page.getByRole("button", { name: "Sign out" }).click();
  await expect(page.getByLabel("Board access key")).toBeVisible();
  await expect(page.getByRole("table")).toHaveCount(0);
  expect(errors).toEqual([]);
});

test("unknown lenses and hostile payloads remain text, denial clears observations", async ({
  page,
}) => {
  await page.goto(`/processes/${sink}`);
  await page.getByLabel("Board access key").fill(process.env.BOARD_TEST_ACCESS!);
  await page.getByRole("button", { name: "Open board" }).click();
  await expect(page.getByText(/Unsupported or malformed interpretation/)).toBeVisible();
  await page.goto(`/processes/${process.env.BOARD_TEST_MALFORMED!}`);
  await expect(page.getByText(/malformed · operator mapping/)).toBeVisible();
  await page.getByText(/Committed state ·/).click();
  await expect(page.getByText("<script>window.pwned=true</script>", { exact: true })).toBeVisible();
  expect(await page.evaluate(() => "pwned" in window)).toBe(false);
  // The real service proof separately revokes Transit grants. Here the browser
  // exercises its error/clearing path without granting a test-only mutation API.
  await page.route("**/api/v1/processes/**", async (route) => {
    await route.fulfill({
      status: 403,
      contentType: "application/json",
      body: '{"err":"Forbidden"}',
    });
  });
  await page.getByRole("button", { name: "Refresh from start" }).click();
  await expect(page.getByLabel("Board access key")).toBeVisible();
  await expect(page.getByText(/Source: PID/)).toHaveCount(0);
});
