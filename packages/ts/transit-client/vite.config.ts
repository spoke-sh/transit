import { defineConfig } from "vite-plus";
export default defineConfig({
  lint: { ignorePatterns: ["src/wire.ts"] },
  fmt: { ignorePatterns: ["src/wire.ts", "src/contract.json", "src/schemas.json"] },
});
