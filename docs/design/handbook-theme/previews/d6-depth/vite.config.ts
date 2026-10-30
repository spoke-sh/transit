import { fileURLToPath } from "node:url";
import { defineConfig } from "vite-plus";

export default defineConfig({
  root: fileURLToPath(new URL("../../", import.meta.url)),
  build: {
    outDir: fileURLToPath(new URL("../../../../../.cache/design/handbook-d6/", import.meta.url)),
    emptyOutDir: true,
    rolldownOptions: { input: fileURLToPath(new URL("./index.html", import.meta.url)) },
  },
});
