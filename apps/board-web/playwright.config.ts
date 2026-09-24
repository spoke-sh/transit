import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./browser",
  timeout: 45000,
  workers: 1,
  reporter: "list",
  outputDir: "../../.cache/board-browser",
  use: {
    baseURL: process.env.BOARD_TEST_URL,
    headless: true,
    reducedMotion: "reduce",
    viewport: { width: 1440, height: 1050 },
    trace: "retain-on-failure",
  },
});
