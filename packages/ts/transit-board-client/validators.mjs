import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { shareValidatorSchemas } from "../../../tasks/validator_schema.mjs";
import Ajv2020 from "ajv/dist/2020.js";
import standalone from "ajv/dist/standalone/index.js";
import { booleanValidatorSource } from "../../../tasks/validator_source.mjs";
const schemas = JSON.parse(readFileSync(new URL("./src/schemas.json", import.meta.url), "utf8"));
const ajv = new Ajv2020({
  allErrors: false,
  // Callers consume booleans and their owned diagnostics, not AJV error prose.
  messages: false,
  // Reuse referenced validators instead of duplicating them in every response.
  inlineRefs: false,
  code: { source: true, esm: true, lines: true },
  strict: true,
});
ajv.addSchema(shareValidatorSchemas(ajv, { root: schemas }).root);
const names = Object.keys(schemas.$defs).filter((name) => !name.startsWith("SqlRead"));
const catalog = ["CatalogRequest", "CatalogResponse"];
const relational = ["RelationalRequest", "RelationalResponse"];
const groups = [
  ["host-validators", ["Deployment", "Capabilities", "Error"]],
  ["inspection-validators", ["Response", "StateResponse"]],
  ["storage-validators", ["StorageResponse"]],
  [
    "evidence-validators",
    [
      "AtlasResponse",
      "ParticipationResponse",
      "RecordsResponse",
      "HttpResponse",
      "GrpcResponse",
      "DocumentResponse",
    ],
  ],
  ["query-validators", ["UnifiedQueryRequest", "UnifiedQueryResponse"]],
  ["relational-validators", relational],
  ["catalog-validators", catalog],
];
if (
  names.length !== groups.flatMap(([, selected]) => selected).length ||
  names.some((name) => groups.filter(([, selected]) => selected.includes(name)).length !== 1)
)
  throw new Error("Every Board contract must belong to exactly one validator group");
const outputs = [];
for (const [file, selected] of groups) {
  const generated = standalone(
    ajv,
    Object.fromEntries(selected.map((name) => [name, `${schemas.$id}#/$defs/${name}`])),
  );
  const text =
    '// Generated; no runtime code generation or eval.\nimport lengthModule from "ajv/dist/runtime/ucs2length.js";\nconst ucs2length = lengthModule.default ?? lengthModule;\n' +
    booleanValidatorSource(generated).replaceAll(
      'require("ajv/dist/runtime/ucs2length").default',
      "ucs2length",
    );
  const declarations =
    selected.map((name) => `export function ${name}(value: unknown): boolean;`).join("\n") + "\n";
  outputs.push(
    [new URL(`./src/${file}.js`, import.meta.url), text],
    [new URL(`./src/${file}.d.ts`, import.meta.url), declarations],
  );
}
const exports =
  groups
    .map(([file, selected]) => `export { ${selected.join(", ")} } from "./${file}.js";`)
    .join("\n") + "\n";
outputs.push(
  [
    new URL("./src/validators.js", import.meta.url),
    "// Generated; contract groups load with their consumers.\n" + exports,
  ],
  [
    new URL("./src/validators.d.ts", import.meta.url),
    names.map((name) => `export function ${name}(value: unknown): boolean;`).join("\n") + "\n",
  ],
);
for (const [target, content] of outputs) {
  if (process.argv.includes("--check")) {
    if (readFileSync(target, "utf8") !== content)
      throw new Error(`Validator drift: ${fileURLToPath(target)}`);
  } else writeFileSync(target, content);
}
