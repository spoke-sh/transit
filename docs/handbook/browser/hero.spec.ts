import { expect, test, type Page } from "@playwright/test";

type AudioProbe = {
  context: AudioContext;
  analyser: AnalyserNode;
  voices: number;
};
type AudioWindow = Window & { heroAudio: AudioProbe[] };

async function observeAudio(page: Page) {
  await page.addInitScript(() => {
    const probes: AudioProbe[] = [];
    (window as unknown as AudioWindow).heroAudio = probes;
    const NativeAudioContext = window.AudioContext;
    window.AudioContext = class extends NativeAudioContext {
      probe: AudioProbe;
      masterSeen = false;
      constructor() {
        super();
        this.probe = { context: this, analyser: this.createAnalyser(), voices: 0 };
        probes.push(this.probe);
      }
      createGain() {
        const gain = super.createGain();
        if (!this.masterSeen) {
          this.masterSeen = true;
          gain.connect(this.probe.analyser);
        }
        return gain;
      }
      createOscillator() {
        this.probe.voices++;
        return super.createOscillator();
      }
    };
  });
}

const audioStates = (page: Page) =>
  page.evaluate(() =>
    (window as unknown as AudioWindow).heroAudio.map(({ context }) => context.state),
  );

test("hero keeps its artwork, reacts to proximity, and respects reduced motion", async ({
  page,
  baseURL,
}, testInfo) => {
  await page.emulateMedia({ colorScheme: "light", reducedMotion: "no-preference" });
  await page.goto(baseURL!);
  await expect(
    page.locator(".navbar").getByRole("link", { name: "Data model", exact: true }),
  ).toHaveCount(0);
  await expect(page.locator(".transit-hero-introduction strong")).toHaveText("current");
  await expect(
    page.getByRole("link", { name: "Explore the data model", exact: true }),
  ).toBeVisible();
  await expect(page.locator(".transit-hero-light")).toHaveAttribute(
    "src",
    /d1-refraction-graphite/,
  );
  const art = page.locator(".transit-hero-art");
  await art.scrollIntoViewIfNeeded();
  const beacon = page.locator(".hero-beacon");
  const channels = page.locator(".hero-prismatic-planes");
  await expect(beacon).toHaveCSS("opacity", "0");
  await expect(channels).toHaveCSS("opacity", "0");
  const bounds = (await art.boundingBox())!;
  await page.mouse.move(bounds.x + bounds.width * 0.917, bounds.y + bounds.height * 0.08);
  const energy = () =>
    art.evaluate((element) => Number(element.style.getPropertyValue("--beacon-energy")));
  await expect.poll(energy).toBeGreaterThan(0.98);
  await expect
    .poll(() =>
      page.locator(".hero-beacon").evaluate((element) => Number(getComputedStyle(element).opacity)),
    )
    .toBeGreaterThan(0.97);
  await page.screenshot({ path: testInfo.outputPath("summit-light.png") });
  await page.mouse.move(bounds.x + bounds.width * 0.8, bounds.y + bounds.height * 0.7);
  await expect
    .poll(() => art.evaluate((element) => Number(element.style.getPropertyValue("--prism-energy"))))
    .toBeGreaterThan(0.9);
  await expect
    .poll(() => channels.evaluate((element) => Number(getComputedStyle(element).opacity)))
    .toBeGreaterThan(0.35);
  await page.screenshot({ path: testInfo.outputPath("channel-light.png") });
  await page.mouse.move(0, 0);
  await expect.poll(energy).toBe(0);
  // Leaving the artwork eases through intermediate light levels before going dark.
  await expect
    .poll(() =>
      channels.evaluate((element) => {
        const opacity = Number(getComputedStyle(element).opacity);
        return opacity > 0.01 && opacity < 0.3;
      }),
    )
    .toBe(true);
  await expect(channels).toHaveCSS("opacity", "0");
  await expect(beacon).toHaveCSS("opacity", "0");
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.mouse.move(bounds.x + bounds.width * 0.917, bounds.y + bounds.height * 0.08);
  await expect
    .poll(() => art.evaluate((element) => element.style.getPropertyValue("--beacon-energy")))
    .toBe("");
  await expect(page.locator(".hero-beacon-aura")).toHaveCSS("transform", "none");
  await page.emulateMedia({ colorScheme: "dark" });
  await expect(page.locator(".hero-light-scene")).toBeHidden();
  await expect(page.locator(".transit-hero-dark")).toBeVisible();
});

test("score is opt-in, generates native audio, and releases it on stop, interruption and navigation", async ({
  page,
  baseURL,
}) => {
  await observeAudio(page);
  const remoteRequests: string[] = [];
  page.on("request", (request) => {
    if (new URL(request.url()).origin !== new URL(baseURL!).origin)
      remoteRequests.push(request.url());
  });
  await page.goto(baseURL!);
  const play = page.getByRole("button", { name: "Play warm ambient music" });
  await expect(play).toBeAttached();
  await expect(play).toHaveText("");
  await expect(play).toHaveCSS("background-color", "rgba(0, 0, 0, 0)");
  expect(await audioStates(page)).toEqual([]);
  await expect(play).toHaveCSS("opacity", "0");
  await play.focus();
  await expect(play).toHaveCSS("opacity", "1");
  await page.keyboard.press("Enter");
  await expect.poll(() => audioStates(page)).toEqual(["running"]);
  await expect
    .poll(() =>
      page.evaluate(() => {
        const probe = (window as unknown as AudioWindow).heroAudio[0]!;
        const samples = new Float32Array(probe.analyser.fftSize);
        probe.analyser.getFloatTimeDomainData(samples);
        return Math.max(...samples.map(Math.abs));
      }),
    )
    .toBeGreaterThan(0.001);
  const stop = page.getByRole("button", { name: "Stop music" });
  await expect(stop).toHaveAttribute("aria-pressed", "true");
  const current = page.locator(".hero-music-current path").first();
  await page.mouse.move(0, 0);
  await expect(page.locator(".hero-beacon")).toHaveCSS("opacity", "0.65");
  await expect(current).toHaveCSS("animation-play-state", "running");
  const offset = await current.evaluate((element) => getComputedStyle(element).strokeDashoffset);
  await expect
    .poll(() => current.evaluate((element) => getComputedStyle(element).strokeDashoffset))
    .not.toBe(offset);
  await page.locator("#handbook").scrollIntoViewIfNeeded();
  await expect(current).toHaveCSS("animation-play-state", "paused");
  expect(await audioStates(page)).toEqual(["running"]);
  await page.locator(".transit-hero-art").scrollIntoViewIfNeeded();
  await expect(current).toHaveCSS("animation-play-state", "running");
  await stop.click();
  await page.mouse.move(0, 0);
  await expect.poll(() => audioStates(page)).toEqual(["closed"]);
  await expect(page.locator(".hero-beacon")).toHaveCSS("opacity", "0");
  await expect(page.locator(".hero-prismatic-planes")).toHaveCSS("opacity", "0");
  await play.click();
  await expect.poll(() => audioStates(page)).toEqual(["closed", "running"]);
  await page.evaluate(() => (window as unknown as AudioWindow).heroAudio[1]!.context.suspend());
  await expect.poll(() => audioStates(page)).toEqual(["closed", "closed"]);
  await expect(play).toHaveAttribute("aria-pressed", "false");
  await play.click();
  await expect.poll(() => audioStates(page)).toEqual(["closed", "closed", "running"]);
  await page.getByRole("link", { name: "Explore the data model", exact: true }).click();
  await expect(page.getByRole("navigation", { name: "Story chapters" })).toBeVisible();
  await expect.poll(() => audioStates(page)).toEqual(["closed", "closed", "closed"]);
  expect(remoteRequests).toEqual([]);
});

test("touch scroll lights the summit and exposes a tappable score, including reduced motion", async ({
  browser,
  baseURL,
}, testInfo) => {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    colorScheme: "light",
  });
  const page = await context.newPage();
  await observeAudio(page);
  await page.goto(baseURL!);
  const art = page.locator(".transit-hero-art");
  const energy = () =>
    art.evaluate((element) => Number(element.style.getPropertyValue("--beacon-energy")));
  await expect.poll(energy).toBeGreaterThan(0);
  const before = await energy();
  await page.evaluate(() => window.scrollBy(0, 230));
  await expect.poll(energy).toBeGreaterThan(before + 0.3);
  const play = page.getByRole("button", { name: "Play warm ambient music" });
  await expect(play).toHaveCSS("opacity", "1");
  const button = (await play.boundingBox())!;
  expect(button.width).toBeGreaterThanOrEqual(44);
  expect(button.height).toBeGreaterThanOrEqual(44);
  await page.screenshot({ path: testInfo.outputPath("mobile-light.png") });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect
    .poll(() => art.evaluate((element) => element.style.getPropertyValue("--beacon-energy")))
    .toBe("");
  await play.tap();
  await expect.poll(() => audioStates(page)).toEqual(["running"]);
  await expect(page.locator(".hero-beacon")).toHaveCSS("opacity", "0.65");
  await expect(page.locator(".hero-music-current path").first()).toHaveCSS(
    "animation-name",
    "none",
  );
  await expect(page.locator(".hero-beacon-breath")).toHaveCSS("animation-name", "none");
  await page.getByRole("button", { name: "Stop music" }).tap();
  await expect.poll(() => audioStates(page)).toEqual(["closed"]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await context.close();
});

test("audio failures are recoverable and unsupported browsers omit the control", async ({
  page,
  browser,
  baseURL,
}) => {
  await page.addInitScript(() => {
    const resume = AudioContext.prototype.resume;
    let reject = true;
    AudioContext.prototype.resume = function () {
      if (reject) {
        reject = false;
        return Promise.reject(new Error("Playback unavailable"));
      }
      return resume.call(this);
    };
  });
  await page.goto(baseURL!);
  const play = page.getByRole("button", { name: "Play warm ambient music" });
  await play.focus();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("status")).toContainText("Audio could not start");
  await expect(play).toHaveAttribute("aria-pressed", "false");
  await play.click();
  await expect(page.getByRole("button", { name: "Stop music" })).toBeVisible();
  await expect(page.getByRole("status")).toBeEmpty();
  await page.getByRole("button", { name: "Stop music" }).click();
  const unsupported = await browser.newContext();
  await unsupported.addInitScript(() =>
    Object.defineProperty(window, "AudioContext", { value: undefined }),
  );
  const fallback = await unsupported.newPage();
  await fallback.goto(baseURL!);
  await expect(fallback.locator("html")).toHaveAttribute("data-has-hydrated", "true");
  await expect(fallback.locator(".hero-score-button")).toHaveCount(0);
  await expect(
    fallback.getByRole("link", { name: "Explore the data model", exact: true }),
  ).toBeVisible();
  await unsupported.close();
});
