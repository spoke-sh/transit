import { defineConfig } from "vite-plus";
import react from "@vitejs/plugin-react";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
export default defineConfig({
  // These bounded renderer artifacts share one declaration context. Route
  // splitting fanned a single navigation into more simultaneous static reads
  // than the host's finite handler pool, causing module-load 503 failures.
  plugins: [tanstackRouter({ target: "react", autoCodeSplitting: false }), react()],
  build: { sourcemap: false, assetsInlineLimit: 0 },
  test: {
    include: ["src/**/*.test.ts", "../../packages/ts/transit-board-client/src/**/*.test.ts"],
  },
  lint: {
    ignorePatterns: ["src/routeTree.gen.ts"],
  },
  fmt: { ignorePatterns: ["src/routeTree.gen.ts"] },
});
