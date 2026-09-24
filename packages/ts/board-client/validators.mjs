import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import Ajv2020 from 'ajv/dist/2020.js';
import standalone from 'ajv/dist/standalone/index.js';
const schemas = JSON.parse(readFileSync(new URL('./src/schemas.json', import.meta.url), 'utf8'));
const ajv = new Ajv2020({ allErrors: false, code: { source: true, esm: true, lines: true }, strict: true });
for (const [name, schema] of Object.entries(schemas)) ajv.addSchema(schema, name);
const generated = standalone(ajv, Object.fromEntries(Object.keys(schemas).map(name => [name, name])));
const text = '// Generated; no runtime code generation or eval.\nimport lengthModule from "ajv/dist/runtime/ucs2length.js";\nconst ucs2length = lengthModule.default ?? lengthModule;\n' + generated.replaceAll('require("ajv/dist/runtime/ucs2length").default', 'ucs2length');
const path = new URL('./src/validators.js', import.meta.url);
const declarations = Object.keys(schemas).map(name => `export function ${name}(value: unknown): boolean;`).join('\n') + '\n';
for (const [target, content] of [[path, text], [new URL('./src/validators.d.ts', import.meta.url), declarations]]) {
  if (process.argv.includes('--check')) {
    if (readFileSync(target, 'utf8') !== content) throw new Error(`Validator drift: ${fileURLToPath(target)}`);
  } else writeFileSync(target, content);
}
