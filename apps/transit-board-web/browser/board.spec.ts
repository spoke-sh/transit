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
  await expect(page.getByRole("heading", { name: "Relief atlas" })).toBeVisible();
  const selection = page.getByRole("button", { name: `Select process ${pid}`, exact: true });
  await expect(selection).toBeVisible();
  await selection.focus();
  await page.waitForTimeout(5500);
  await expect(selection).toBeFocused();
  await selection.press("Enter");
  await expect(page.getByRole("heading", { name: `PID ${pid}`, exact: true })).toBeVisible();
  await expect(page.getByText("Consumed inputs", { exact: true })).toBeVisible();
  await page.goto(`/processes/${pid}`);
  await expect(page.getByText(/Blocked on input/)).toBeVisible();
  await expect(page.getByText("State revision", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Arrivals", exact: true }).click();
  await expect(page.getByRole("cell", { name: "consumed", exact: true })).toBeVisible();
  await expect(page.getByRole("cell", { name: "pending", exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Departures", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: `Output ${process.env.BOARD_TEST_OUTPUT} → PID ${sink}` }),
  ).toBeVisible();
  await expect(page.getByText("output to admission", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Effects", exact: true }).click();
  await expect(page.getByRole("heading", { name: /closed unknown/ })).toBeVisible();
  await expect(page.getByText(/Closure reason: abandoned/)).toBeVisible();
  const effectDetail = page.getByRole("alert", { name: "Effect diagnostic" });
  await expect(effectDetail).toContainText("explicitly closed reconciliation without a result");
  await expect(effectDetail).toContainText("effect.reconciliation_abandoned");
  await expect(effectDetail).not.toContainText("resume_exact");
  await page.getByRole("link", { name: "Journey", exact: true }).click();
  await expect(page.getByRole("heading", { name: `PID ${pid} · journey` })).toBeVisible();
  await expect(page.getByText("input to turn", { exact: true }).first()).toBeVisible();
  await page.reload(); // Nested routes and lazy assets open directly, too.
  await expect(page.getByRole("heading", { name: `PID ${pid} · journey` })).toBeVisible();
  await expect(page.getByText("input to turn", { exact: true }).first()).toBeVisible();
  expect(
    (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze())
      .violations,
  ).toEqual([]);
  await page.screenshot({ path: process.env.BOARD_SCREENSHOT, fullPage: true });
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
  expect(await page.context().cookies()).toEqual([]);
  await expect(page.getByLabel("Board access key")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Sign out" })).toHaveCount(0);
  expect(errors).toEqual([]);
});

test("state associations disclose resources without interpreting application data", async ({
  page,
}) => {
  await page.goto(`/processes/${sink}?tab=associations`);
  await expect(page.getByRole("heading", { name: "State associations" })).toBeVisible();
  const resource = process.env.BOARD_TEST_RESOURCE!;
  await page.getByRole("link", { name: `Resource ${resource}`, exact: true }).click();
  await expect(page.getByRole("heading", { name: "Relief atlas" })).toBeVisible();
  await page.getByRole("button", { name: `Select resource ${resource}`, exact: true }).click();
  await expect(
    page.getByRole("heading", { name: `Resource ${resource}`, exact: true }),
  ).toBeVisible();
  await expect(page.getByText("Application interpretation")).toHaveCount(0);
  await page.getByRole("button", { name: "Inspect records", exact: true }).click();
  const records = page.getByRole("region", { name: `Resource ${resource} records`, exact: true });
  await expect(
    records.getByText(`Source: writer PID ${sink}, entry revision`, { exact: false }),
  ).toHaveCount(3);
  // The API proof checks recognized framework declarations. The current atlas
  // exposes record identities and source revisions without application values.
  for (const key of await records.getByText("Source key", { exact: true }).all()) await key.click();
  for (const key of ["0073746174696f6e", "007401000000", "6170706c69636174696f6e"])
    await expect(records.getByText(key, { exact: true })).toBeVisible();
  await expect(records.getByText("station.genserver.v1", { exact: true })).toHaveCount(0);
});

test("opaque hostile payloads remain text, denial clears observations", async ({ page }) => {
  await page.goto(`/processes/${sink}`);
  await expect(page.getByRole("heading", { name: `PID ${sink}`, exact: true })).toBeVisible();
  await page.goto(`/processes/${process.env.BOARD_TEST_MALFORMED!}?tab=mailbox`);
  await expect(page.getByText(/Application interpretation/)).toHaveCount(0);
  await page.getByRole("group").filter({ hasText: "bytes" }).locator("summary").click();
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
  await expect(page.getByText(/Transit denied inspection/)).toBeVisible();
  await expect(page.getByText("<script>window.pwned=true</script>", { exact: true })).toHaveCount(
    0,
  );
  await expect(page.getByRole("table")).toHaveCount(0);
  await page.unroute("**/api/v1/processes/**");
  await page.getByRole("button", { name: "Retry connection" }).click();
  await expect(
    page.getByRole("table", { name: "Retained events in durable sequence order" }),
  ).toBeVisible();
  await expect(page.getByText(/Application interpretation/)).toHaveCount(0);
});

test("disconnection preserves an explicitly stale observation instead of an empty view", async ({
  page,
}) => {
  await page.goto(`/processes/${pid}`);
  const revision = page
    .locator(".facts > div")
    .filter({ hasText: "State revision" })
    .locator("strong");
  await expect(revision).toBeVisible();
  const observedRevision = await revision.innerText();
  await page.route("**/api/v1/processes/**", (route) =>
    route.fulfill({ status: 503, contentType: "application/json", body: '{"err":"Unavailable"}' }),
  );
  await expect(page.getByText(/Last observation remains below; it is stale/)).toBeVisible({
    timeout: 10000,
  });
  await expect(revision).toHaveText(observedRevision);
  await expect(page.getByText("Stale", { exact: true })).toBeVisible();
});

test("an unavailable initial connection can be retried without signing in", async ({ page }) => {
  await page.route("**/api/v1/capabilities", (route) =>
    route.fulfill({ status: 503, contentType: "application/json", body: '{"err":"Unavailable"}' }),
  );
  await page.goto("/");
  await expect(page.getByText("Observation unavailable (Unavailable).")).toBeVisible();
  await expect(page.getByLabel("Board access key")).toHaveCount(0);
  await page.unroute("**/api/v1/capabilities");
  await page.getByRole("button", { name: "Retry connection" }).click();
  await expect(page.getByRole("heading", { name: "Relief atlas" })).toBeVisible();
  await expect(
    page.getByRole("button", { name: `Select process ${pid}`, exact: true }),
  ).toBeVisible();
});
