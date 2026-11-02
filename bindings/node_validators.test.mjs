import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import test from "node:test";

// The old runtime compiler is the independent oracle. The bounded corpus visits
// every exported schema, valid nested values and malformed leaves/containers.
function sample(schema, root, depth = 0) {
  assert.ok(depth < 64, "fixture recursion must terminate");
  if (schema.$ref) return sample(root.$defs[schema.$ref.split("/").at(-1)], root, depth + 1);
  if (schema.const !== undefined) return schema.const;
  if (schema.enum) return schema.enum[0];
  const variants = schema.anyOf ?? schema.oneOf;
  if (variants)
    return sample(variants.find((s) => s.type === "null") ?? variants[0], root, depth + 1);
  switch (schema.type) {
    case "null":
      return null;
    case "boolean":
      return false;
    case "integer":
    case "number":
      return schema.minimum ?? 0;
    case "string":
      return "0".repeat(schema.minLength ?? 0);
    case "array":
      return Array.from({ length: schema.minItems ?? 0 }, () =>
        sample(schema.items, root, depth + 1),
      );
    case "object":
      return Object.fromEntries(
        (schema.required ?? []).map((key) => [
          key,
          sample(schema.properties[key], root, depth + 1),
        ]),
      );
    default:
      throw new Error(`Uncovered fixture schema: ${JSON.stringify(schema)}`);
  }
}
function* corruptions(value, depth = 0) {
  yield null;
  yield {};
  yield [];
  yield "foreign";
  yield Number.MAX_SAFE_INTEGER + 1;
  yield NaN;
  yield Infinity;
  if (depth > 4 || value === null || typeof value !== "object") return;
  if (Array.isArray(value)) {
    yield value.slice(1);
    if (value.length)
      for (const changed of corruptions(value[0], depth + 1)) yield [changed, ...value.slice(1)];
  } else {
    yield { ...value, unexpected: true };
    for (const key of Object.keys(value)) {
      const omitted = { ...value };
      delete omitted[key];
      yield omitted;
      for (const changed of corruptions(value[key], depth + 1)) yield { ...value, [key]: changed };
    }
  }
}
for (const directory of ["transit-client", "transit-station-sdk"]) {
  test(`${directory}: standalone validation retains acceptance and complete Ajv errors`, async () => {
    const source = new URL(`../sdks/ts/${directory}/src/`, import.meta.url);
    const require = createRequire(new URL("../package.json", source));
    const { Ajv } = require("ajv");
    const ajv = new Ajv({ strict: true });
    const schemas = JSON.parse(readFileSync(new URL("schemas.json", source), "utf8"));
    const generated = await import(new URL("validators.js", source));
    assert.deepEqual(Object.keys(generated).sort(), Object.keys(schemas).sort());
    let comparisons = 0;
    for (const [name, schema] of Object.entries(schemas)) {
      const original = ajv.compile(schema),
        candidate = generated[name];
      const valid = sample(schema, schema);
      assert.equal(
        original(valid),
        true,
        `${name} corpus needs a valid value: ${JSON.stringify(original.errors)}`,
      );
      const fixtures = [valid, ...corruptions(valid)];
      // Exercise recursive wire values and full-width integer strings explicitly.
      if (name === "ArrowCell") {
        const cell = (type, value) => ({ rows: 1, columns: 1, name: "value", type, value });
        const values = [
          cell(
            { int128: {} },
            { value: { atom: { signed: "-170141183460469231731687303715884105728" } } },
          ),
          cell(
            { uint128: {} },
            { value: { atom: { unsigned: "340282366920938463463374607431768211455" } } },
          ),
          cell({ utf8: {} }, { value: { atom: { utf8: "λ雪\u0000☃" } } }),
          cell(
            { list: { type: { int64: {} }, nullable: true } },
            {
              value: { list: [{ value: { atom: { signed: "-1" } } }, { null: {} }] },
            },
          ),
        ];
        for (const value of values) {
          assert.equal(original(value), true, JSON.stringify(original.errors));
          fixtures.push(value, ...corruptions(value));
        }
      }
      for (const value of fixtures) {
        assert.equal(candidate(value), original(value), `${name} acceptance`);
        assert.deepEqual(candidate.errors ?? null, original.errors ?? null, `${name} diagnostics`);
        comparisons++;
      }
      assert.equal(candidate(valid), true, `${name} reusable after rejection`);
      assert.equal(candidate.errors, null);
    }
    console.log(`${directory}: ${comparisons} differential cases`);
  });
}
