import { expect, test } from "vite-plus/test";
import {
  decodeDefinition,
  decodeHead,
  diagram,
  generation,
  presentation,
  requireArtifacts,
  withTheme,
  type Definition,
  type Head,
} from "./index";

const definition: Definition = {
  version: 1,
  name: "board",
  realm: 49,
  revision: "18446744073709551615",
  components: 1,
  entry: "atlas",
  theme: "mono",
  themes: [
    { name: "mono", density: "comfortable" },
    { name: "dense", density: "compact" },
  ],
  bindings: [{ name: "catalog", source: { inspection: { projection: "atlas", page_budget: 1 } } }],
  screens: [
    {
      name: "atlas",
      path: "/atlas",
      label: "Atlas",
      area: "workspace",
      renderer: "atlas",
      binding: "catalog",
    },
  ],
  actions: [{ name: "open", label: "Open Atlas", target: { navigate: "atlas" } }],
};
const head: Head = {
  revision: definition.revision,
  record: "18446744073709551614",
  operation: "3",
  principal: 44,
  input: 81,
  spec: {
    format: 0x41505031,
    length: 512,
    digest: Array.from({ length: 32 }, (_, index) => index),
  },
};

test("generated artifacts allow compatible publication without acting as fallback or authority", () => {
  const next = { ...definition, revision: "2", theme: "dense" };
  expect(() => requireArtifacts(definition, next)).not.toThrow();
  for (const changed of [
    { ...next, name: "another_application" },
    { ...next, realm: 50 },
    { ...next, components: 2 },
    { ...next, screens: [{ ...definition.screens[0]!, renderer: "work_items" as const }] },
  ])
    expect(() => requireArtifacts(definition, changed)).toThrow();
  expect(next.revision).toBe("2");
});

test("reflected validators reject coercion, unknown fields, unsupported versions and wide overflow", () => {
  expect(decodeDefinition(structuredClone(definition))).toEqual(definition);
  for (const changed of [
    { ...definition, components: 2 },
    { ...definition, realm: "49" },
    { ...definition, realm: 0 },
    { ...definition, revision: 1 },
    { ...definition, revision: "18446744073709551616" },
    { ...definition, revision: "01" },
    { ...definition, unknown: "ignored" },
    { ...definition, actions: Array(17).fill(definition.actions[0]) },
  ])
    expect(() => decodeDefinition(changed)).toThrow();
  expect(decodeHead(head)).toEqual(head);
  expect(() => decodeHead({ ...head, spec: { ...head.spec, digest: "a".repeat(32) } })).toThrow();
  expect(() => decodeHead({ ...head, spec: { ...head.spec, length: 65537 } })).toThrow();
  expect(() => decodeHead({ ...head, operation: "-1" })).toThrow();
});

test("visual theme edits and diagram projections preserve the operation graph", () => {
  const original = structuredClone(definition);
  const edited = withTheme(original, "dense");
  expect(presentation(edited)).toEqual({ density: "compact", theme: "dense" });
  expect(presentation(original)).toEqual({ density: "comfortable", theme: "mono" });
  expect(edited.bindings).toEqual(original.bindings);
  expect(edited.actions).toEqual(original.actions);
  expect(diagram(edited)).toEqual({
    nodes: [
      { id: "screen:atlas", kind: "screen", label: "Atlas" },
      { id: "binding:catalog", kind: "binding", label: "catalog" },
      { id: "action:open", kind: "action", label: "Open Atlas" },
    ],
    edges: [
      { from: "screen:atlas", to: "binding:catalog" },
      { from: "action:open", to: "screen:atlas" },
    ],
  });
  expect(() => withTheme(original, "missing")).toThrow();
});

test("generation includes full-width revision, record, scope and exact body commitment", () => {
  const current = generation(49, "board", head);
  expect(current).toContain("18446744073709551615/18446744073709551614/");
  expect(generation(50, "board", head)).not.toEqual(current);
  expect(generation(49, "example", head)).not.toEqual(current);
  expect(
    generation(49, "board", {
      ...head,
      spec: { ...head.spec, digest: [...head.spec.digest.slice(0, 31), 200] },
    }),
  ).not.toEqual(current);
  expect(() => generation(Number.MAX_SAFE_INTEGER + 1, "board", head)).toThrow();
});
