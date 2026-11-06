import { fileURLToPath } from "node:url";
import { readFileSync } from "node:fs";
import { defineConfig } from "vite-plus";
const mutation = process.env.BOARD_MODEL_MUTATION;
export default defineConfig({
  resolve: {
    alias: [
      // Mutation copies live outside the app's node_modules ancestry. Resolve
      // the same public package entries, including feature subpaths, there.
      ...["application", "reactive-client", "query-client", "board-client"].flatMap((name) => {
        const root = new URL(`../../../packages/ts/transit-${name}/`, import.meta.url);
        const manifest = JSON.parse(readFileSync(new URL("package.json", root), "utf8")) as {
          exports: Record<string, string>;
        };
        return Object.entries(manifest.exports).map(([entry, target]) => ({
          find: new RegExp(`^@transit/${name}${entry === "." ? "" : entry.slice(1)}$`),
          replacement: fileURLToPath(new URL(target, root)),
        }));
      }),
      ...(mutation
        ? [
            {
              find: mutation.includes("statement-state-")
                ? /.*\/apps\/transit-board-web\/src\/statement-state(?:\.ts)?$/
                : mutation.includes("plane-state-")
                  ? /.*\/apps\/transit-board-web\/src\/plane-state(?:\.ts)?$/
                  : mutation.includes("workbook-state-")
                    ? /.*\/apps\/transit-board-web\/src\/workbook-state(?:\.ts)?$/
                    : /.*\/apps\/transit-board-web\/src\/observation(?:\.ts)?$/,
              replacement: mutation,
            },
          ]
        : []),
    ],
  },
  test: { include: ["tests/verification/models/board-replay.test.ts"], testTimeout: 90000 },
});
