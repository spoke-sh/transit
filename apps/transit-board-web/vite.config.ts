import { defineConfig } from "vite-plus";
import react from "@vitejs/plugin-react";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
export default defineConfig({
  // Keep route renderers together: they share a declaration context and many
  // small lazy chunks previously overwhelmed the host's bounded request pool.
  plugins: [tanstackRouter({ target: "react", autoCodeSplitting: false }), react()],
  build: {
    sourcemap: false,
    assetsInlineLimit: 0,
    // Discover shared chunks after the entry loads, instead of
    // preloading them alongside HTML, CSS and the entry into four handler slots.
    modulePreload: false,
    rolldownOptions: {
      output: {
        codeSplitting: {
          includeDependenciesRecursively: false,
          groups: [
            {
              name: "inspection",
              test: /packages\/ts\/transit-board-client\/(?!src\/(relational|catalog)-validators\.js$)/,
            },
            {
              name: "query",
              test: /packages\/ts\/transit-(query-client|diagnostics)\/|packages\/ts\/transit-board-client\/src\/relational-validators\.js$|packages\/ts\/transit-reactive-client\/src\/(caller-gate|error)\.ts$|ajv\/dist\/runtime\//,
            },
            // Application and live-view contracts share a bounded asset group;
            // keep richer finite-query validators in their own chunk. The caller
            // gate is also used by finite queries: keep it with that dependency
            // to avoid a cycle through the generated AJV runtime initializers.
            {
              name: "application",
              test: /packages\/ts\/transit-application\/|packages\/ts\/transit-reactive-client\/(?!src\/(caller-gate|error)\.ts$)/,
            },
          ],
        },
      },
    },
  },
  test: {
    include: ["src/**/*.test.ts", "../../packages/ts/transit-board-client/src/**/*.test.ts"],
  },
  lint: {
    ignorePatterns: ["src/routeTree.gen.ts"],
  },
  fmt: { ignorePatterns: ["src/routeTree.gen.ts"] },
});
