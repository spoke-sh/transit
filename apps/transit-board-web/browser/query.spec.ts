import AxeBuilder from "@axe-core/playwright";
import { test, expect } from "@playwright/test";
import { execFileSync } from "node:child_process";

test("one explicit query survives Canvas/Browse changes and is cleared on revocation", async ({
  page,
  context,
}) => {
  test.setTimeout(180000);
  page.setDefaultTimeout(15000);
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  let submissions = 0;
  let pageReads = 0;
  page.on("request", (request) => {
    if (request.url().endsWith("/api/v1/query") && request.method() === "POST") {
      const body = request.postDataJSON() as Record<string, unknown>;
      if ("submit" in body) submissions++;
      if ("page" in body) pageReads++;
    }
  });
  await page.goto("/atlas");
  await expect(page.getByRole("heading", { name: "Relief atlas", exact: true })).toBeVisible();
  await page
    .getByRole("button", {
      name: `Select resource ${process.env.BOARD_QUERY_RESOURCE}`,
      exact: true,
    })
    .click();
  await expect(page.getByRole("button", { name: "Enter resource" })).toBeVisible();
  await page
    .getByLabel("Search this authorized page")
    .fill(`resource ${process.env.BOARD_QUERY_RESOURCE}`);
  await expect(page.locator(".atlas-evidence")).toContainText("0 processes and 1 resources match");
  await page.getByLabel("Search this authorized page").fill("");
  await page.getByRole("button", { name: "Inspect participation", exact: true }).click();
  await expect(
    page.getByRole("table", {
      name: `Authorized associations to resource ${process.env.BOARD_QUERY_RESOURCE}`,
    }),
  ).toBeVisible({ timeout: 15000 });
  const participation = page.getByLabel("Resource participation");
  const participationDeadline = Date.now() + 15000;
  for (;;) {
    expect(Date.now()).toBeLessThan(participationDeadline);
    const next = page.getByRole("button", { name: /^Next associations for PID/ });
    await expect(next).toBeVisible();
    const pending = page.waitForResponse((response) => {
      const url = new URL(response.url());
      return url.pathname.endsWith("/participation") && url.searchParams.has("pid");
    });
    await next.click();
    const response = await pending;
    if (response.status() === 200) break;
    expect(response.status()).toBe(409);
    expect((await response.json()).err).toBe("QueryExpired");
    // Worker progress can invalidate this read-only observation between pages.
    // Discard its rows and explicitly restart; never combine different cuts.
    await expect(participation.getByRole("table")).toHaveCount(0);
    await expect(participation).toContainText("inspection.observation_changed");
    console.log("Board participation: stale continuation cleared; refreshing its observation");
    await participation.getByRole("button", { name: "Refresh participation", exact: true }).click();
  }
  await expect(participation).toContainText("One selected PID.");
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "revoke-inspector-resource",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  await expect(page.getByLabel("Resource participation")).toHaveCount(0, { timeout: 15000 });
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "restore-inspector-resource",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  await page.getByRole("button", { name: "Refresh observation", exact: true }).click();
  await expect(page.getByLabel("Resource participation")).toBeVisible({ timeout: 15000 });
  for (const density of ["comfortable", "compact"]) {
    await page.getByLabel("Preview density").selectOption(density);
    expect(
      (await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze()).violations,
    ).toEqual([]);
  }
  await page.getByRole("button", { name: "Resources", exact: true }).click();
  await page.getByLabel("Detail zoom").focus();
  await page.getByLabel("Detail zoom").press("End");
  await expect(page.getByLabel("Detail zoom")).toHaveValue("3");
  await page.screenshot({
    path: process.env.BOARD_QUERY_SCREENSHOT?.replace(".png", "-atlas.png"),
    fullPage: true,
  });
  await page.getByRole("button", { name: "Enter resource" }).click();
  const draft = page.getByLabel("SQL draft", { exact: true });
  await expect(draft).toBeVisible();
  const sql = "SELECT value FROM items WHERE value = 9007199254740994 LIMIT 1";
  await draft.fill(sql);
  await page.getByRole("button", { name: "Browse", exact: true }).click();
  await expect(draft).toHaveValue(sql);
  await page.getByRole("button", { name: "Canvas", exact: true }).click();
  expect(submissions).toBe(0);
  const dropped = new Map<string, unknown>();
  const recovered = new Set<string>();
  let uncertain: string | null = null;
  await page.route("**/api/v1/query", async (route) => {
    const body = route.request().postDataJSON();
    if (body.submit) {
      const frozen = JSON.stringify(body);
      if (uncertain !== null) expect(frozen).toBe(uncertain);
      const response = await route.fetch();
      if (response.status() === 429) {
        // Preserve real pre-dispatch throttling; it is not an accepted reply.
        await route.fulfill({ response });
        return;
      }
      if (response.status() === 503) {
        expect(await response.json()).toMatchObject({
          err: "Unavailable",
          diagnostic: { code: "query.send_unknown", outcome: "unknown", evidence: "saved_intent" },
        });
        uncertain = frozen;
        await route.fulfill({ response });
        return;
      }
      expect(response.status()).toBe(200);
      const receipt: unknown = await response.json();
      if (dropped.has(frozen)) {
        expect(receipt).toEqual(dropped.get(frozen));
        recovered.add(frozen);
      } else if (dropped.size < 2) {
        // Lose two distinct accepted upload steps, including one after the
        // first explicit recovery. Each must retain its own exact request.
        dropped.set(frozen, receipt);
        uncertain = frozen;
        await route.abort("failed");
        return;
      }
      uncertain = null;
      await route.fulfill({ response });
      return;
    }
    await route.continue();
  });
  const retry = page.getByRole("button", { name: "Retry exact submission", exact: true });
  const submissionDeadline = Date.now() + 120000;
  const recoverUntil = async (complete: () => Promise<boolean>) => {
    while (!(await complete())) {
      const remaining = () => {
        const value = submissionDeadline - Date.now();
        expect(value).toBeGreaterThan(0);
        return value;
      };
      await expect
        .poll(
          async () =>
            (await complete()) ||
            (uncertain !== null && (await retry.isVisible()) && (await retry.isEnabled())),
          { timeout: remaining() },
        )
        .toBe(true);
      if (await complete()) return;
      const original = uncertain;
      expect(original).not.toBeNull();
      const sent = page.waitForRequest(
        (request) =>
          request.url().endsWith("/api/v1/query") &&
          request.method() === "POST" &&
          "submit" in request.postDataJSON(),
        { timeout: remaining() },
      );
      await retry.click({ timeout: remaining() });
      expect(JSON.stringify((await sent).postDataJSON())).toBe(original);
    }
  };
  await page.getByRole("button", { name: "Run query", exact: true }).click();
  await recoverUntil(async () => dropped.size > 0);
  await expect(
    page.getByRole("button", { name: "Retry exact submission", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Activity", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Activity", exact: true })).toBeVisible();
  await page.getByRole("link", { name: "Atlas", exact: true }).click();
  await page
    .getByRole("button", {
      name: `Select resource ${process.env.BOARD_QUERY_RESOURCE}`,
      exact: true,
    })
    .click();
  await page.getByRole("button", { name: "Enter resource", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Retry exact submission", exact: true }),
  ).toBeVisible();
  await recoverUntil(() => page.getByLabel("Verified query result").isVisible());
  expect(dropped.size).toBe(2);
  expect(recovered.size).toBe(2);
  await expect(
    page.getByLabel("Verified query result").getByText("9007199254740994", { exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Browse", exact: true }).click();
  await expect(draft).toHaveValue(sql);
  await expect(page.getByRole("cell", { name: "9007199254740994", exact: true })).toBeVisible();
  const completed = submissions;
  expect(completed).toBeGreaterThan(2); // finite upload has several committed steps
  await draft.fill("SELECT id FROM items LIMIT 2");
  await page.getByRole("button", { name: "Canvas", exact: true }).click();
  await expect(draft).toHaveValue("SELECT id FROM items LIMIT 2");
  await expect(
    page.getByText("Draft changed. The displayed result belongs to the earlier submitted SQL."),
  ).toBeVisible();
  expect(submissions).toBe(completed);
  const recovery = page.getByLabel("Retained query recovery", { exact: true });
  const reference = await recovery.innerText();
  const correlation = /Retained query (\d+)\./.exec(reference)?.[1];
  expect(correlation).toBeTruthy();
  const download = page.waitForEvent("download");
  await page.getByRole("button", { name: "Save reference and use current binding" }).click();
  expect((await download).suggestedFilename()).toBe("transit-query-reference.json");
  await expect(page.getByLabel("Verified query result")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Run query", exact: true })).toBeEnabled();
  await page.getByLabel("Existing query namespace", { exact: true }).fill(correlation!);
  await page.getByRole("button", { name: "Resume without rerunning", exact: true }).click();
  await expect(page.getByLabel("Verified query result")).toBeVisible();
  expect(submissions).toBe(completed);
  await page.screenshot({ path: process.env.BOARD_QUERY_SCREENSHOT, fullPage: true });
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "revoke",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  await expect(
    page.getByText("Query access denied. Protected workspace data cleared."),
  ).toBeVisible({ timeout: 15000 });
  await expect(page.getByLabel("Verified query result")).toHaveCount(0);
  await expect(draft).toHaveCount(0);
  expect(submissions).toBe(completed);
  expect(await context.cookies()).toEqual([]);
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0]);
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "restore",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  const clearedPageReads = pageReads;
  await page.getByRole("button", { name: "Refresh query access" }).click();
  await expect(draft).toHaveValue("SELECT * FROM items");
  // Wait for the complete access/status refresh, not just its early source update.
  await expect(page.getByRole("button", { name: "Run query", exact: true })).toBeEnabled();
  await expect(recovery).toContainText(`Retained query ${correlation}.`);
  await expect(page.getByLabel("Verified query result")).toHaveCount(0);
  expect(pageReads).toBe(clearedPageReads);
  await page.getByLabel("Existing query namespace", { exact: true }).fill(correlation!);
  await page.getByRole("button", { name: "Resume without rerunning", exact: true }).click();
  await expect(page.getByLabel("Verified query result")).toBeVisible();
  await expect(
    page.getByLabel("Verified query result").getByText("9007199254740994", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Draft changed. The displayed result belongs to the earlier submitted SQL."),
  ).toBeVisible();
  expect(pageReads).toBeGreaterThan(clearedPageReads);
  expect(submissions).toBe(completed);
  expect(errors).toEqual([]);
  execFileSync(process.env.BOARD_QUERY_PROOF!, [
    process.env.BOARD_QUERY_AUTHORITY!,
    "retire-source",
    process.env.BOARD_QUERY_CONFIG!,
  ]);
  await expect(
    page.getByText("Source or result unavailable. Protected workspace data cleared."),
  ).toBeVisible({ timeout: 15000 });
  await expect(draft).toHaveCount(0);
  await expect(page.getByLabel("Verified query result")).toHaveCount(0);
});
