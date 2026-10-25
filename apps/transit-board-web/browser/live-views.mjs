import assert from "node:assert/strict";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { chromium, expect as baseExpect } from "@playwright/test";
const expect = baseExpect.configure({ timeout: 30000 });
const config = JSON.parse(readFileSync(process.argv[2], "utf8"));
const browser = await chromium.launch({
  headless: true,
  args: [`--ignore-certificate-errors-spki-list=${config.spki}`],
});
const context = await browser.newContext();
for (const origin of [config.board, config.counter])
  await context.grantPermissions(["local-network-access"], { origin });
const errors = [],
  operations = [];
// Retain identity/reset evidence independently of the rolling request log:
// ordinary status polling must not overwrite the event that stopped Follow.
const resultIdentities = new Map(),
  reactiveObservations = new Map(),
  semanticFailures = [];
let queryStatus = null;
let refreshStatus = null;
const counter = await context.newPage();
const board = await context.newPage();
for (const page of [counter, board]) {
  page.setDefaultTimeout(30000);
  page.on("requestfailed", (request) =>
    console.error("Request failed:", new URL(request.url()).pathname, request.failure()?.errorText),
  );
  page.on("console", (message) => {
    if (message.type() === "error") console.error("Browser console:", message.text());
  });
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("response", async (response) => {
    if (!response.request().postData()) return;
    const result = await response.json().catch(() => ({}));
    const request = response.request().postDataJSON();
    const path = new URL(response.url()).pathname;
    if (path === "/api/v1/query" && "status" in request && "status" in result) {
      if (
        queryStatus?.namespace !== request.status ||
        queryStatus?.phase !== (result.status?.phase ?? null)
      )
        console.log("Query phase:", request.status, result.status?.phase ?? "unobserved");
      queryStatus = {
        namespace: request.status,
        phase: result.status?.phase ?? null,
        diagnostic: result.status?.diagnostic?.code ?? null,
      };
    }
    if ("refresh_status" in request && result.refresh_status?.view) {
      const { namespace, phase, starts, dirty, covered } = result.refresh_status.view;
      if (refreshStatus?.namespace !== namespace || refreshStatus?.phase !== phase)
        console.log("Refresh phase:", namespace, phase, starts);
      refreshStatus = { namespace, phase, starts, dirty, covered };
    }
    const retain = (map, key, value) => {
      map.set(key, value);
      if (map.size > 4) map.delete(map.keys().next().value);
    };
    if (request.page && result.page?.evidence?.manifest) {
      const { basis, plan, table_position } = result.page.evidence.manifest;
      retain(resultIdentities, request.page.namespace, { basis, plan, table_position });
    }
    if (
      path.startsWith("/reactive/") &&
      response.status() === 200 &&
      ["describe", "inspect", "refresh_status", "observe", "clock"].includes(
        Object.keys(request)[0],
      )
    )
      retain(reactiveObservations, Object.keys(request)[0], result);
    if (result.reason || (result.err && ![429, 503, 504].includes(response.status()))) {
      semanticFailures.push({
        path,
        operation: Object.keys(request)[0],
        status: response.status(),
        result,
      });
      if (semanticFailures.length > 8) semanticFailures.shift();
    }
    operations.push([
      response.url().split("/").slice(-2).join("/"),
      Object.keys(response.request().postDataJSON())[0],
      response.status(),
      result.err ??
        (result.observation ? Object.keys(result.observation)[0] : Object.keys(result)[0]),
      response.request().postDataJSON().observe ?? null,
    ]);
    if (operations.length > 40) operations.shift();
  });
}
async function stage(name) {
  writeFileSync(config.marker, name);
  const until = Date.now() + 120000;
  while (
    !existsSync(config.marker + "-ack") ||
    readFileSync(config.marker + "-ack", "utf8") !== name
  ) {
    assert(Date.now() < until, `stage ${name} timed out`);
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
}
async function settledPause(page, button, status) {
  await page.getByRole("button", { name: button, exact: true }).click();
  const until = Date.now() + 60000;
  while (!(await status.textContent()).includes("Follow paused.")) {
    assert(Date.now() < until, "logical pause did not settle");
    const recovery = page.getByRole("button", { name: "Recover exact control", exact: true });
    if (await recovery.isVisible()) {
      try {
        // Completion can remove the recovery button between observations.
        // Keep this attempt inside the enclosing logical-pause deadline.
        await recovery.click({ timeout: 500 });
      } catch (error) {
        if (error.name !== "TimeoutError") throw error;
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
}
let lost = null,
  exact = false;
let atlasUnavailable = false;
let displayedNamespace = null;
let denyCandidate = false;
let protectedNamespace = null;
let deniedBetweenReads = false;
const timings = {};
await board.route("**/api/v1/atlas", async (route) => {
  if (atlasUnavailable)
    return route.fulfill({
      status: 503,
      contentType: "application/json",
      body: '{"err":"Unavailable"}',
    });
  await route.continue();
});
await board.route("**/api/v1/query", async (route) => {
  const request = route.request().postDataJSON();
  if ("page" in request) displayedNamespace = request.page.namespace;
  if (denyCandidate && request.page && request.page.namespace !== protectedNamespace) {
    const response = await route.fetch();
    if (response.status() === 200) {
      const value = await response.json();
      if (value.page.evidence.next === null) {
        // The candidate's ordered verification has reached its last real page.
        // Revoke only entry-read permission before allowing the visible reread.
        await stage("deny");
        deniedBetweenReads = true;
        denyCandidate = false;
      }
    }
    await route.fulfill({ response });
    return;
  }
  if ("submit" in request) {
    const body = route.request().postData();
    if (lost === null) {
      const response = await route.fetch();
      if (response.status() === 429) {
        await route.fulfill({ response });
        return;
      }
      assert.equal(response.status(), 200);
      lost = body;
      await route.fulfill({
        status: 503,
        contentType: "application/json",
        body: '{"err":"Unavailable"}',
      });
      return;
    }
    if (!exact) {
      assert.equal(body, lost);
      exact = true;
    }
  }
  await route.continue();
});
try {
  await counter.goto(config.counter);
  await counter.getByRole("button", { name: "Follow counter", exact: true }).click();
  await expect(counter.locator("#status")).toHaveAttribute("data-phase", "current");
  await expect(counter.locator("#rows tr").first()).toHaveText("11");
  await board.goto(config.board);
  await board.getByRole("button", { name: "Follow metadata", exact: true }).click();
  await expect(board.getByLabel("Live Table metadata").getByRole("status")).toContainText(
    "current",
  );
  const oldBasis = await counter.locator("#basis").textContent();
  const counterStart = performance.now();
  await stage("mutate");
  await expect(counter.locator("#rows tr").first()).toHaveText("12");
  await expect(counter.locator("#basis")).not.toHaveText(oldBasis);
  timings.counterMutationToVisibleMs = Math.round(performance.now() - counterStart);
  await Promise.all([
    settledPause(
      board,
      "Pause metadata",
      board.getByLabel("Live Table metadata").getByRole("status"),
    ),
    settledPause(counter, "Pause counter", counter.locator("#status")),
  ]);
  await stage("rows");
  await board
    .getByRole("button", { name: `Select resource ${config.resource}`, exact: true })
    .click();
  await board.getByRole("button", { name: "Enter resource", exact: true }).click();
  await expect(board.getByLabel("SQL draft", { exact: true })).toBeVisible();
  await board.getByLabel("SQL draft", { exact: true }).fill("SELECT * FROM counter");
  await board.getByRole("button", { name: "Run query", exact: true }).click();
  await expect(
    board.getByRole("button", { name: "Retry exact submission", exact: true }),
  ).toBeVisible();
  atlasUnavailable = true;
  await expect(
    board.getByRole("button", { name: "Retry exact submission", exact: true }),
  ).toBeEnabled();
  // A real router transition unmounts the workspace while its accepted receipt
  // is still unknown. Metadata failure cannot discard the frozen upload command.
  await board.getByRole("link", { name: "Resource directory", exact: true }).click();
  await expect(board).toHaveURL(/\/resources/);
  await expect(
    board.getByRole("button", { name: "Retry exact submission", exact: true }),
  ).toHaveCount(0);
  atlasUnavailable = false;
  await board
    .getByRole("button", { name: `Select resource ${config.resource}`, exact: true })
    .click();
  await board.getByRole("button", { name: "Enter resource", exact: true }).click();
  await expect(
    board.getByRole("button", { name: "Retry exact submission", exact: true }),
  ).toBeVisible();
  assert(!exact, "navigation must not retry an uncertain mutation");
  await board.getByRole("button", { name: "Retry exact submission", exact: true }).click();
  await expect(board.getByLabel("Verified query result")).toBeVisible({ timeout: 180000 });
  assert(exact);
  await expect(board.getByLabel("Verified query result")).toContainText("20 total rows");
  const original = await board.getByLabel("Verified query result").textContent();
  const originalNamespace = displayedNamespace;
  const originalIdentity = resultIdentities.get(originalNamespace);
  assert(originalIdentity);
  if (config.recovery) {
    const namespace = displayedNamespace;
    assert(namespace);
    const recoveryStart = performance.now();
    await stage("restart");
    // A fresh actual page read must retrieve the old identity after all physical
    // services restart. Re-enter the retained workspace explicitly, with the
    // listener installed first; background polling may finish before stage ack.
    await board.getByRole("link", { name: "Resource directory", exact: true }).click();
    await expect(board.getByRole("heading", { name: "Relief atlas", exact: true })).toBeVisible();
    await board
      .getByRole("button", { name: `Select resource ${config.resource}`, exact: true })
      .click();
    const recoveredPage = board.waitForResponse(
      async (response) => {
        if (!response.url().endsWith("/api/v1/query") || response.status() !== 200) return false;
        const request = response.request().postDataJSON();
        return request?.page?.namespace === namespace;
      },
      { timeout: 60000 },
    );
    await board.getByRole("button", { name: "Enter resource", exact: true }).click();
    await recoveredPage;
    await expect(board.getByLabel("Verified query result")).toHaveText(original);
    assert.equal(displayedNamespace, namespace);
    timings.physicalRecoveryMs = Math.round(performance.now() - recoveryStart);
  }
  await board.getByRole("button", { name: "Follow changes", exact: true }).click();
  // Follow first prepares eight independently authorized finite captures. Allow
  // the same bounded execution deadline as a query, including exact recovery.
  await expect(board.getByLabel("Query follow controls").getByRole("status")).toContainText(
    "current",
    { timeout: 180000 },
  );
  await stage("ready");
  const queryStart = performance.now();
  // Another committed mutation while following admits a distinct finite query.
  writeFileSync(config.marker, "mutate");
  await expect(board.getByLabel("Verified query result")).not.toHaveText(original, {
    timeout: 180000,
  });
  await expect(board.getByLabel("Query follow controls").getByRole("status")).toContainText(
    "current",
    { timeout: 40000 },
  );
  timings.queryMutationToVerifiedVisibleMs = Math.round(performance.now() - queryStart);
  const refreshedIdentity = resultIdentities.get(displayedNamespace);
  assert(refreshedIdentity);
  assert.notEqual(displayedNamespace, originalNamespace);
  assert.equal(originalIdentity.basis.cut.kind, "table");
  assert.equal(refreshedIdentity.basis.cut.kind, "table");
  const previousPosition = originalIdentity.table_position;
  const refreshedPosition = refreshedIdentity.table_position;
  assert(previousPosition && refreshedPosition);
  assert.equal(refreshedPosition.resource, previousPosition.resource);
  assert.equal(refreshedPosition.partition, previousPosition.partition);
  assert.deepEqual(refreshedPosition.contract, previousPosition.contract);
  assert.deepEqual(refreshedPosition.schema, previousPosition.schema);
  assert(BigInt(refreshedPosition.accepted) > BigInt(previousPosition.accepted));
  assert.notDeepEqual(refreshedIdentity.plan, originalIdentity.plan);
  for (const [name, page] of [
    ["board", board],
    ["counter", counter],
  ]) {
    const metrics = await context.newCDPSession(page);
    const heap = await metrics.send("Runtime.getHeapUsage");
    assert(heap.usedSize < 128 * 1024 * 1024, `${name} browser heap budget`);
    timings[`${name}ObservedHeapBytes`] = heap.usedSize;
    await metrics.detach();
  }
  if (config.screenshots)
    await board.screenshot({
      path: `${config.screenshots}/m21-${config.profile}-board.png`,
      fullPage: true,
    });
  protectedNamespace = displayedNamespace;
  denyCandidate = true;
  await stage("mutate-again");
  await expect(
    board.getByText("Query access denied. Protected workspace data cleared.", { exact: true }),
  ).toBeVisible({ timeout: 180000 });
  assert(deniedBetweenReads, "denial must occur between complete coverage and the visible reread");
  await expect(board.getByLabel("Verified query result")).toHaveCount(0);
  assert.deepEqual(errors, []);
  assert.deepEqual(await context.cookies(), []);
  const stored = await board.evaluate(() => ({
    local: localStorage.length,
    keys: Object.keys(sessionStorage),
    follow: sessionStorage.getItem("transit.query.follow.v1"),
  }));
  assert.equal(stored.local, 0);
  assert.deepEqual(stored.keys, ["transit.query.follow.v1"]);
  assert(Buffer.byteLength(stored.follow) <= 1179648);
  const savedFollow = JSON.parse(stored.follow);
  assert.deepEqual(Object.keys(savedFollow).sort(), [
    "definition",
    "preparation",
    "session",
    "version",
    "view",
  ]);
  assert.equal(savedFollow.version, 1);
  // Recovery is retained after denial, but contains intent/control state rather
  // than the protected result that was just cleared from the workspace.
  const savedView = savedFollow.view === null ? null : JSON.parse(savedFollow.view);
  assert(!savedView || !("snapshot" in savedView));
  assert(!("inspection" in JSON.parse(savedFollow.session)));
  assert(!stored.follow.includes('"private_key"'));
  console.log(
    "Live views: actual shared-client counter and Board metadata, exact query retry, bounded full-result verification, new finite refresh, pause and current read-only revocation passed.",
  );
  console.log("Observed live-view wall times:", JSON.stringify(timings));
} catch (error) {
  if (refreshStatus?.namespace && refreshStatus.namespace !== "0") {
    // One bounded public status read locates the selected finite execution.
    // It cannot resume, replace or cancel accepted work.
    const selected = await board
      .evaluate(async (namespace) => {
        const response = await fetch("/api/v1/query", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ status: namespace }),
          signal: AbortSignal.timeout(10000),
        });
        const result = await response.json();
        return {
          namespace,
          http: response.status,
          phase: result.status?.phase ?? null,
          diagnostic: result.status?.diagnostic?.code ?? result.err ?? null,
        };
      }, refreshStatus.namespace)
      .catch(() => ({ unavailable: true }));
    console.error("Selected refresh query evidence:", JSON.stringify(selected));
  }
  console.error("Counter status:", await counter.locator("#status").allTextContents());
  console.error("Board status:", await board.getByRole("status").allTextContents());
  console.error("Recent API outcomes:", operations);
  console.error("Query status evidence:", JSON.stringify(queryStatus));
  console.error("Refresh status evidence:", JSON.stringify(refreshStatus));
  console.error("Result identity evidence:", JSON.stringify([...resultIdentities]));
  console.error("Reactive observation evidence:", JSON.stringify([...reactiveObservations]));
  console.error("Semantic failure evidence:", JSON.stringify(semanticFailures));
  console.error("Observed live-view wall times before failure:", JSON.stringify(timings));
  console.error("Browser errors:", errors);
  throw error;
} finally {
  await context.close();
  await browser.close();
}
