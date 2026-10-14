import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { shareValidatorSchemas } from "../../../tasks/validator_schema.mjs";
import Ajv2020 from "ajv/dist/2020.js";
import standalone from "ajv/dist/standalone/index.js";
const schemas = JSON.parse(readFileSync(new URL("./src/schemas.json", import.meta.url), "utf8"));
const ajv = new Ajv2020({
  allErrors: false,
  // Reuse referenced validators instead of duplicating them in every response.
  inlineRefs: false,
  code: { source: true, esm: true, lines: true },
  strict: true,
});
ajv.addSchema(shareValidatorSchemas(ajv, { root: schemas }).root);
const names = Object.keys(schemas.$defs);
const relational = ["RelationalRequest", "RelationalResponse"];
const outputs = [];
for (const [file, selected] of [
  ["validators", names.filter((name) => !relational.includes(name))],
  ["relational-validators", relational],
]) {
  const generated = standalone(
    ajv,
    Object.fromEntries(selected.map((name) => [name, `${schemas.$id}#/$defs/${name}`])),
  );
  const reexports =
    file === "validators"
      ? '\nexport { RelationalRequest, RelationalResponse } from "./relational-validators.js";\n'
      : "";
  const text =
    '// Generated; no runtime code generation or eval.\nimport lengthModule from "ajv/dist/runtime/ucs2length.js";\nconst ucs2length = lengthModule.default ?? lengthModule;\n' +
    generated.replaceAll('require("ajv/dist/runtime/ucs2length").default', "ucs2length") +
    reexports;
  const declarations =
    (file === "validators" ? names : selected)
      .map((name) => `export function ${name}(value: unknown): boolean;`)
      .join("\n") + "\n";
  outputs.push(
    [new URL(`./src/${file}.js`, import.meta.url), text],
    [new URL(`./src/${file}.d.ts`, import.meta.url), declarations],
  );
}
for (const [target, content] of outputs) {
  if (process.argv.includes("--check")) {
    if (readFileSync(target, "utf8") !== content)
      throw new Error(`Validator drift: ${fileURLToPath(target)}`);
  } else writeFileSync(target, content);
}
