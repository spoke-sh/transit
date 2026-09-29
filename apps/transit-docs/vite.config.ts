import { defineConfig } from "vite-plus";

// Docusaurus owns the site build. Vite+ owns checks, tests and dependencies.
export default defineConfig({
  test: { include: ["lib/**/*.test.ts"] },
  lint: { ignorePatterns: [".docusaurus/**", ".generated/**", "dist/**"] },
  fmt: { ignorePatterns: [".docusaurus/**", ".generated/**", "dist/**"] },
});
