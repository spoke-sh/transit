import { readFileSync, writeFileSync } from "node:fs";
import Ajv2020 from "ajv/dist/2020.js";
import standalone from "ajv/dist/standalone/index.js";
const schema = JSON.parse(readFileSync(new URL("./src/schema.json", import.meta.url), "utf8"));
const ajv = new Ajv2020({
  allErrors: false,
  code: { source: true, esm: true, lines: true },
  strict: true,
});
ajv.addSchema(schema);
const names = Object.keys(schema.$defs);
const generated = standalone(
  ajv,
  Object.fromEntries(names.map((name) => [name, `${schema.$id}#/$defs/${name}`])),
);
const text =
  '// Generated; no runtime code generation or eval.\nimport lengthModule from "ajv/dist/runtime/ucs2length.js";\nconst ucs2length = lengthModule.default ?? lengthModule;\n' +
  generated.replaceAll('require("ajv/dist/runtime/ucs2length").default', "ucs2length");
for (const [name, content] of [
  ["validators.js", text],
  [
    "validators.d.ts",
    names.map((name) => `export function ${name}(value: unknown): boolean;`).join("\n") + "\n",
  ],
]) {
  const path = new URL(`./src/${name}`, import.meta.url);
  if (process.argv.includes("--check")) {
    if (readFileSync(path, "utf8") !== content)
      throw new Error(`Diagnostic validator drift: ${name}`);
  } else writeFileSync(path, content);
}
