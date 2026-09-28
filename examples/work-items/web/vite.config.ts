import { defineConfig } from "vite-plus";
export default defineConfig({
  build: { sourcemap: false, assetsInlineLimit: 0 },
  fmt: { ignorePatterns: ["src/proposal.generated.ts"] },
});
