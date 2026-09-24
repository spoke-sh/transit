import { defineConfig } from "vite-plus";
import react from "@vitejs/plugin-react";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
export default defineConfig({
  plugins: [tanstackRouter({ target: "react", autoCodeSplitting: true }), react()],
  build: { sourcemap: false, assetsInlineLimit: 0 },
  test: {
    include: ["src/**/*.test.ts", "../../packages/ts/transit-board-client/src/**/*.test.ts"],
  },
  lint: {
    ignorePatterns: ["src/routeTree.gen.ts"],
  },
  fmt: { ignorePatterns: ["src/routeTree.gen.ts"] },
});
