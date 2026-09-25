import { defineConfig } from "vite-plus";
export default defineConfig({
  lint: { ignorePatterns: ["src/types.ts"] },
  fmt: { ignorePatterns: ["src/types.ts", "src/schemas.json"] },
});
