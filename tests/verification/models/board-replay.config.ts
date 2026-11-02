import { fileURLToPath } from "node:url";
import { defineConfig } from "vite-plus";
const mutation = process.env.BOARD_MODEL_MUTATION;
export default defineConfig({
  resolve: {
    alias: [
      ...["application", "reactive-client", "query-client", "board-client"].map((name) => ({
        find: new RegExp(`^@transit/${name}$`),
        replacement: fileURLToPath(
          new URL(`../../../packages/ts/transit-${name}/src/index.ts`, import.meta.url),
        ),
      })),
      ...(mutation
        ? [
            {
              find: mutation.includes("statement-state-")
                ? /.*\/apps\/transit-board-web\/src\/statement-state(?:\.ts)?$/
                : /.*\/apps\/transit-board-web\/src\/observation(?:\.ts)?$/,
              replacement: mutation,
            },
          ]
        : []),
    ],
  },
  test: { include: ["tests/verification/models/board-replay.test.ts"], testTimeout: 90000 },
});
