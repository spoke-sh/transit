import { defineConfig } from "vite-plus";
export default defineConfig({
  lint: {
    ignorePatterns: [
      "src/wire.ts",
      "src/validators.js",
      "src/validators.d.ts",
      "src/validators.json",
    ],
  },
  fmt: {
    ignorePatterns: [
      "src/wire.ts",
      "src/contract.json",
      "src/schemas.json",
      "src/validators.js",
      "src/validators.d.ts",
      "src/validators.json",
    ],
  },
});
