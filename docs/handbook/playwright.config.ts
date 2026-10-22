import { defineConfig } from "@playwright/test";

const port = Number(process.env.TRANSIT_DOCS_TEST_PORT ?? "4179");
if (!Number.isInteger(port) || port < 1024 || port > 65535)
  throw new Error("Invalid documentation test port");
const base = process.env.TRANSIT_DOCS_BASE_URL ?? "/transit/";
export default defineConfig({
  testDir: "./browser",
  fullyParallel: false,
  workers: 1,
  timeout: 60000,
  outputDir: "../../.cache/verification/docs-browser",
  use: { baseURL: `http://127.0.0.1:${port}${base}`, browserName: "chromium" },
  webServer: {
    command: `vp run serve --port ${port}`,
    url: `http://127.0.0.1:${port}${base}`,
    reuseExistingServer: false,
    timeout: 60000,
  },
});
