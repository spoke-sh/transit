import { defineConfig } from "vite-plus";

// Docusaurus owns the site build. Vite+ owns checks, tests and dependencies.
export default defineConfig({
  test: { include: ["lib/**/*.test.ts"] },
  lint: { ignorePatterns: [".docusaurus/**", ".generated/**", "dist/**"] },
  // Handbook prose follows repository Markdown conventions, checked by tests/runner/docs.py.
  fmt: {
    ignorePatterns: [
      ".docusaurus/**",
      ".generated/**",
      "dist/**",
      "guides/**",
      "reference/**",
      "internals/**",
    ],
  },
});
