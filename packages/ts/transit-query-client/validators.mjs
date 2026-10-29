import { readFileSync, writeFileSync } from "node:fs";
import { shareValidatorSchemas } from "../../../tasks/validator_schema.mjs";
import Ajv2020 from "ajv/dist/2020.js";
import standalone from "ajv/dist/standalone/index.js";
for (const prefix of ["", "read-"]) {
  const schema = JSON.parse(
    readFileSync(new URL(`./src/${prefix}schema.json`, import.meta.url), "utf8"),
  );
  const ajv = new Ajv2020({
    allErrors: false,
    // Callers consume booleans and their owned diagnostics, not AJV error prose.
    messages: false,
    // Reuse referenced validators instead of duplicating them in every response.
    inlineRefs: false,
    code: { source: true, esm: true, lines: true },
    strict: true,
  });
  ajv.addSchema(shareValidatorSchemas(ajv, { root: schema }).root);
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
    const path = new URL(`./src/${prefix}${name}`, import.meta.url);
    if (process.argv.includes("--check")) {
      if (readFileSync(path, "utf8") !== content) throw new Error(`Query validator drift: ${name}`);
    } else writeFileSync(path, content);
  }
}
