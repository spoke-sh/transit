import { defineConfig } from "vite-plus";
export default defineConfig({
  lint: { ignorePatterns: ["src/types.ts", "src/validators.js", "src/validators.d.ts"] },
  fmt: {
    ignorePatterns: ["src/types.ts", "src/schema.json", "src/validators.js", "src/validators.d.ts"],
  },
});
