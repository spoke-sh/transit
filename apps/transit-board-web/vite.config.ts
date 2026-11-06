import { defineConfig, type Plugin } from "vite-plus";
import react from "@vitejs/plugin-react";
import { tanstackRouter } from "@tanstack/router-plugin/vite";

function bundleBudget(): Plugin {
  return {
    name: "board-bundle-budget",
    generateBundle: {
      order: "post",
      handler(_, bundle) {
        const scripts = Object.values(bundle).filter((item) => item.type === "chunk");
        const bytes = (code: string) => new TextEncoder().encode(code).byteLength;
        for (const script of scripts)
          if (bytes(script.code) >= 900_000)
            this.error(`${script.fileName} exceeds Board's 900 kB script budget`);
        const closure = (roots: string[]) => {
          const visited = new Set<string>();
          const visit = (name: string) => {
            const chunk = bundle[name];
            if (visited.has(name) || chunk?.type !== "chunk") return;
            visited.add(name);
            chunk.imports.forEach(visit);
          };
          roots.forEach(visit);
          return visited;
        };
        const initial = closure(
          scripts.filter((item) => item.isEntry).map((item) => item.fileName),
        );
        const initialBytes = scripts
          .filter((item) => initial.has(item.fileName))
          .reduce((sum, item) => sum + bytes(item.code), 0);
        if (initial.size > 4 || initialBytes >= 800_000)
          this.error(
            `Board bootstrap exceeds four scripts / 800 kB (${initial.size} scripts, ${initialBytes} bytes: ${[...initial].join(", ")})`,
          );
        const featureRoot =
          /transit-board-web\/src\/(?:catalog|dataset|workbook|operations|computations|activity|atlas|process-evidence|definition|unified-workspace|relational-workspace|live-table)\.tsx$/;
        for (const script of scripts) {
          if (
            initial.has(script.fileName) &&
            Object.keys(script.modules).some((id) => featureRoot.test(id))
          )
            this.error(`Feature implementation loaded eagerly in ${script.fileName}`);
          for (const target of script.dynamicImports) {
            const additional = [...closure([target])].filter((name) => !initial.has(name));
            if (additional.length > 4)
              this.error(
                `${target} needs ${additional.length} additional scripts; group its feature dependencies`,
              );
          }
        }
      },
    },
  };
}
export default defineConfig({
  // Route metadata stays small; features define their own coarse import boundaries.
  plugins: [tanstackRouter({ target: "react", autoCodeSplitting: false }), react(), bundleBudget()],
  build: {
    sourcemap: false,
    assetsInlineLimit: 0,
    cssCodeSplit: false,
    // Discover shared chunks after the entry loads, instead of
    // preloading them alongside HTML, CSS and the entry into four handler slots.
    modulePreload: false,
    manifest: true,
    rolldownOptions: {
      output: {
        codeSplitting: {
          // A feature must not capture the shell or another feature through a
          // shared context. Keep dependency ownership explicit and acyclic.
          includeDependenciesRecursively: false,
          groups: [
            {
              name: "framework",
              test: /node_modules\/(?:react|react-dom|scheduler|use-sync-external-store|@tanstack)\//,
            },
            {
              name: "catalog",
              test: /transit-board-web\/src\/(?:catalog|retained-[^/]+)\.tsx?$|transit-board-client\/src\/catalog(?:-validators)?\.(?:ts|js)$/,
            },
            {
              name: "operations",
              test: /transit-board-web\/src\/(?:operations|storage|storage-model|maintenance-model)\.tsx?$|transit-board-client\/src\/storage(?:-validators)?\.(?:ts|js)$/,
            },
            {
              name: "computations",
              test: /transit-board-web\/src\/(?:computations|computation-owner)\.tsx?$|transit-board-client\/src\/(?:computations|computation-validators)\.(?:ts|js)$/,
            },
            { name: "dataset", test: /transit-board-web\/src\/dataset\.tsx$/ },
            { name: "workbook", test: /transit-board-web\/src\/workbook\.tsx$/ },
            {
              name: "statements",
              test: /transit-board-web\/src\/(?:workbench-result|result-profile|statement-owner|statement-state|workbook-owner|workbook-state)\.tsx?$|transit-query-client\/src\/(?:read(?:-validators|-http)?|workbook)\.(?:ts|js)$/,
            },
            {
              name: "inspection",
              test: /transit-board-web\/src\/(?:atlas|atlas-observation|activity|process-evidence|inspection-state|inspection-evidence|components|resources|framework|records|participation|capture-failure|http-metadata|grpc-metadata|document-metadata|use-metadata)\.tsx?$|transit-board-client\/src\/(?:inspection|evidence)(?:-validators)?\.(?:ts|js)$|transit-board-client\/src\/effects\.ts$/,
            },
            {
              name: "recovery",
              test: /transit-board-web\/src\/(?:definition|interface-bindings|relational-storage|relational-workspace)\.tsx?$|transit-board-client\/src\/relational(?:-validators)?\.(?:ts|js)$|transit-application\/src\/client\.ts$/,
            },
            {
              name: "query-workspace",
              test: /transit-board-web\/src\/(?:unified-workspace|unified-result|query-(?:live|profile|inspection|recovery|candidates)|draft-controls|sql-editor|workspace-tasks|binding|follow-recovery)\.tsx?$|transit-query-client\/src\/(?!(?:error|logical|diagnostics|read-types|read|read-http|read-validators|workbook)\.(?:ts|js)$)|transit-board-client\/src\/(?:query|unified)\.ts$/,
            },
            {
              name: "live",
              test: /transit-board-web\/src\/live-table\.tsx$|transit-reactive-client\/src\/(?!(?:caller-gate|request-scheduling|error)\.ts$)/,
            },
            {
              name: "shell",
              test: /transit-board-web\/src\/(?:routes\/|(?:state|plane-state|interface|declared|features|feature-status|feature-access|data-route|data-metadata|dataset-selection|use-observation|observation|observation-owner|read-status|request-scheduler|workbench-layout|quantity|quantities|query-diagnostic|process-tabs|routeTree.gen)\.tsx?$)|transit-board-client\/src\/(?:deployment|request|host-validators)\.(?:ts|js)$|transit-application\/src\/(?:interface|definition|error|validators)\.(?:ts|js)$|transit-query-client\/src\/(?:error|logical|diagnostics|read-types)\.ts$|transit-reactive-client\/src\/(?:caller-gate|request-scheduling|error)\.ts$|transit-diagnostics\/src\/|ajv\/dist\/runtime\/|preload-helper/,
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
