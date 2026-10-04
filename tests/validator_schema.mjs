import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { test } from "node:test";
import { shareValidatorSchemas } from "../tasks/validator_schema.mjs";

const require = createRequire(
  new URL("../packages/ts/transit-board-client/package.json", import.meta.url),
);
const Ajv2020 = require("ajv/dist/2020.js").default;

function compare(schemas, cases) {
  const original = JSON.stringify(schemas);
  const before = new Ajv2020({ strict: true });
  const after = new Ajv2020({ strict: true, inlineRefs: false });
  const shared = shareValidatorSchemas(after, schemas);
  for (const [name, schema] of Object.entries(schemas)) before.addSchema(schema, name);
  for (const [name, schema] of Object.entries(shared)) after.addSchema(schema, name);
  for (const [name, value, expected] of cases) {
    assert.equal(
      before.getSchema(name)(value),
      expected,
      `original ${name}: ${JSON.stringify(value)}`,
    );
    assert.equal(
      after.getSchema(name)(value),
      expected,
      `shared ${name}: ${JSON.stringify(value)}`,
    );
  }
  assert.equal(JSON.stringify(schemas), original, "public schema must not be mutated");
  return shared;
}

test("shared nested validators preserve required fields, unions, bounds and Unicode", () => {
  const item = {
    type: "object",
    additionalProperties: false,
    required: ["name", "key"],
    properties: {
      name: { type: "string", minLength: 1, maxLength: 2 },
      key: { type: "integer", minimum: -2, maximum: 2 },
    },
  };
  const schemas = {
    anything: true,
    nothing: false,
    row: item,
    rows: { type: "array", minItems: 1, maxItems: 2, items: { anyOf: [item, { type: "null" }] } },
    envelope: {
      type: "object",
      additionalProperties: false,
      required: ["value"],
      properties: { value: item },
    },
  };
  const valid = { name: "😀é", key: -2 };
  const cases = [
    ["anything", { unknown: [null, 1] }, true],
    ["nothing", null, false],
    ["row", valid, true],
    ["rows", [valid, null], true],
    ["rows", [], false],
    ["rows", [null, null, null], false],
  ];
  for (const value of [
    valid,
    { name: "a", key: 2 },
    {},
    { ...valid, key: 3 },
    { ...valid, key: "1" },
    { ...valid, key: 0.5 },
    { ...valid, name: "😀éx" },
    { ...valid, extra: 1 },
  ]) {
    const expected = value === valid || (value.name === "a" && value.key === 2);
    cases.push(
      ["row", value, expected],
      ["rows", [value], expected],
      ["envelope", { value }, expected],
    );
  }
  const shared = compare(schemas, cases);
  assert.ok(shared.envelope.properties.value.$ref, "repeated nested types must be shared");
});

test("local references retain their document scope and const objects remain data", () => {
  const schemas = {
    number: {
      $id: "https://example.test/number",
      $defs: { value: { type: "integer", minimum: 1 } },
      type: "object",
      properties: { value: { $ref: "#/$defs/value" } },
      required: ["value"],
    },
    string: {
      $id: "https://example.test/string",
      $defs: { value: { type: "string", minLength: 1 } },
      type: "object",
      properties: { value: { $ref: "#/$defs/value" } },
      required: ["value"],
    },
    constant: { const: { properties: { value: { type: "integer", minimum: 1 } } } },
    tuple: {
      type: "array",
      prefixItems: [{ type: "integer" }, { type: "string" }],
      minItems: 2,
      maxItems: 2,
      items: false,
    },
  };
  compare(schemas, [
    ["number", { value: 1 }, true],
    ["number", { value: "x" }, false],
    ["string", { value: "x" }, true],
    ["string", { value: 1 }, false],
    ["constant", schemas.constant.const, true],
    ["constant", {}, false],
    ["tuple", [1, "x"], true],
    ["tuple", [1, "x", null], false],
  ]);
});

test("pointers into repeated type interiors keep their original target", () => {
  const payload = {
    type: "object",
    properties: { name: { type: "string", minLength: 1, maxLength: 8 } },
  };
  const schemas = {
    container: {
      $id: "https://example.test/container",
      $defs: { payload },
      type: "object",
      properties: { left: payload, right: payload },
    },
    field: { $ref: "https://example.test/container#/$defs/payload/properties/name" },
  };
  compare(schemas, [
    ["field", "valid", true],
    ["field", "", false],
    ["field", 1, false],
  ]);
});
