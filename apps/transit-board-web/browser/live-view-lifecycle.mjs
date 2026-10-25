import assert from "node:assert/strict";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { chromium, expect as baseExpect } from "@playwright/test";
const expect = baseExpect.configure({ timeout: 40000 });
const config = JSON.parse(readFileSync(process.argv[2], "utf8"));
const browser = await chromium.launch({
  headless: true,
  args: [`--ignore-certificate-errors-spki-list=${config.spki}`],
});
const context = await browser.newContext();
for (const origin of [config.board, config.counter])
  await context.grantPermissions(["local-network-access"], { origin });
const errors = [];
const operations = [];
const counter = await context.newPage();
const peer = await context.newPage();
const board = await context.newPage();
for (const page of [counter, peer, board]) {
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("response", async (response) => {
    if (!response.url().includes("/reactive/v1/client/") || !response.request().postData()) return;
    const result = await response.json().catch(() => ({}));
    operations.push([
      page === board ? "board" : page === peer ? "peer" : "counter",
      Object.keys(response.request().postDataJSON())[0],
      response.status(),
      result.err ??
        (result.observation ? Object.keys(result.observation)[0] : Object.keys(result)[0]),
    ]);
    if (operations.length > 30) operations.shift();
  });
}
async function stage(name) {
  writeFileSync(config.marker, name);
  const until = Date.now() + 90000;
  while (
    !existsSync(config.marker + "-ack") ||
    readFileSync(config.marker + "-ack", "utf8") !== name
  ) {
    assert(Date.now() < until, `stage ${name} timed out`);
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
}
async function follow(page) {
  await page.getByRole("button", { name: "Follow counter", exact: true }).click();
  await expect(page.locator("#status")).toHaveAttribute("data-phase", "current");
}
try {
  await counter.goto(config.counter);
  await follow(counter);
  await expect(counter.locator("#rows tr").first()).toHaveText("11");
  await board.goto(config.board);
  await board.getByRole("button", { name: "Follow metadata", exact: true }).click();
  await expect(board.getByLabel("Live Table metadata").getByRole("status")).toContainText(
    "current",
  );
  await peer.goto(config.counter);
  await follow(peer);
  await stage("sessions-before");
  const offlineBasis = await counter.locator("#basis").textContent();

  // Chromium's actual network failure closes this tab's fetch stream. The
  // other tab shares the same origin/principal but retains its own live view.
  const network = await context.newCDPSession(counter);
  await network.send("Network.enable");
  await network.send("Network.emulateNetworkConditions", {
    offline: true,
    latency: 0,
    downloadThroughput: -1,
    uploadThroughput: -1,
  });
  await expect(counter.locator("#status")).toHaveAttribute("data-phase", "disconnected");
  await stage("mutate");
  await expect(peer.locator("#rows tr").first()).toHaveText("12");
  await expect(counter.locator("#rows tr").first()).toHaveText("11");
  await expect(counter.locator("#basis")).toHaveText(offlineBasis);
  await network.send("Network.emulateNetworkConditions", {
    offline: false,
    latency: 0,
    downloadThroughput: -1,
    uploadThroughput: -1,
  });
  await expect(counter.locator("#rows tr").first()).toHaveText("12");
  await expect(counter.locator("#status")).toHaveAttribute("data-phase", "current");
  await stage("sessions-after");
  await network.detach();

  // A real reload starts a new page with no retained private snapshot or
  // implicit Follow. The other tab keeps its independent session and data.
  await peer.reload();
  await expect(peer.locator("#status")).toHaveAttribute("data-phase", "paused");
  await expect(peer.locator("#rows tr")).toHaveCount(0);
  await expect(peer.locator("#basis")).toHaveText("No authorized snapshot.");
  await stage("peer-reloaded");
  await expect(counter.locator("#status")).toHaveAttribute("data-phase", "current");
  await follow(peer);
  await expect(peer.locator("#rows tr").first()).toHaveText("12");

  // Real navigation dispatches pagehide and closes local work. Lease
  // maintenance also bounds a close lost during browser teardown.
  await peer.goto("about:blank");
  await stage("peer-closed");
  await expect(counter.locator("#status")).toHaveAttribute("data-phase", "current");
  await stage("rotate-viewer");
  await expect(counter.locator("#status")).toHaveAttribute("data-phase", "denied");
  await expect(counter.locator("#rows tr")).toHaveCount(0);
  await expect(counter.locator("#basis")).toHaveText("No authorized snapshot.");
  await expect(board.getByLabel("Live Table metadata").getByRole("status")).toContainText(
    "current",
  );
  await stage("replace-viewer");
  const recovery = counter.getByRole("button", { name: "Recover exact control", exact: true });
  if (await recovery.isVisible()) await recovery.click();
  await follow(counter);
  await expect(counter.locator("#rows tr").first()).toHaveText("12");
  // Isolate source-generation reset from a lease reaching its deadline during
  // the abandoned-peer check. Reopening is an explicit user action.
  await counter.getByRole("button", { name: "Pause counter", exact: true }).click();
  await expect(counter.locator("#status")).toContainText("Follow paused.");
  await follow(counter);
  const basis = await counter.locator("#basis").textContent();
  await stage("reset");
  await expect(counter.locator("#status")).toHaveAttribute("data-phase", "reset_required");
  await expect(counter.locator("#basis")).toHaveText(basis);
  await expect(board.getByLabel("Live Table metadata").getByRole("status")).toContainText(
    "reset required",
  );
  await follow(counter);
  await expect(counter.locator("#rows tr").first()).toHaveText("12");
  // This fixture explicitly binds all direct catalog authority domains to the
  // retired resource. Its disappearance denies the current guard; it is not
  // merely a lost transport like the disconnected tab above.
  await stage("retire");
  await expect(counter.locator("#status")).toHaveAttribute("data-phase", "denied");
  await expect(counter.locator("#status")).toContainText("serving.access_denied");
  await expect(counter.locator("#rows tr")).toHaveCount(0);
  await expect(counter.locator("#basis")).toHaveText("No authorized snapshot.");
  assert.deepEqual(errors, []);
  assert.deepEqual(await context.cookies(), []);
  console.log(
    "Live-view lifecycle: shared-principal tabs, actual stream loss with retained basis, resume without session replacement, reload paused without private data, pagehide/expiry, credential rotation with cleared data and explicit recovery, visible watch-generation reset, explicit resnapshot and cleared protected state after catalog lifetime retirement passed.",
  );
} catch (error) {
  console.error("Recent control outcomes:", operations);
  for (const page of [counter, peer, board])
    console.error("View state:", await page.getByRole("status").allTextContents());
  throw error;
} finally {
  await context.close();
  await browser.close();
}
