import fixtureValue from "../../../zig/transit-protocol/src/fixtures/diagnostic-v1.json" with { type: "json" };
import { expect, test } from "vite-plus/test";
import { diagnosticLines, ownedDiagnostic, type Diagnostic } from "./index";
const fixture = (): Diagnostic => structuredClone(fixtureValue) as Diagnostic;

test("shared caller detail is owned, exact and safe to render", () => {
  const original = fixture();
  const parsed = ownedDiagnostic(original);
  expect(parsed.invalid).toBe(false);
  original.facts[0]!.value = { text: "changed" };
  expect(parsed.diagnostic?.facts[0]).not.toEqual(original.facts[0]);
  const lines = diagnosticLines(parsed.diagnostic!).join("\n");
  expect(lines).toContain("-9223372036854775808");
  expect(lines).toContain("constraint: unrecorded");
  const escaped = fixture();
  escaped.facts[0]!.value = { text: "\u001b[31m\nsecret-looking-label" };
  expect(diagnosticLines(ownedDiagnostic(escaped).diagnostic!).join("\n")).toContain(
    '"\\u001b[31m\\nsecret-looking-label"',
  );
});
test("foreign, oversized, malformed and contradictory optional details reject", () => {
  for (const value of [
    {},
    { ...fixture(), definition: "0".repeat(64) },
    { ...fixture(), message: "\ud800" },
    { ...fixture(), message: "😀".repeat(200) },
    { ...fixture(), outcome: "unknown" },
    { ...fixture(), facts: [null, fixture().facts[0], ...Array(14).fill(null)] },
  ])
    expect(ownedDiagnostic(value)).toEqual({ invalid: true });
});
test("recovery guidance cannot change the operation identity or authorize fresh input", () => {
  const value = fixture();
  value.outcome = "input_rejected";
  value.actions = [{ kind: "inspect_status", target: value.identity }, null, null, null];
  expect(ownedDiagnostic(value).invalid).toBe(false);
  value.actions[0]!.kind = "correct_input";
  expect(ownedDiagnostic(value).invalid).toBe(true);
  value.outcome = "unknown";
  value.evidence = "saved_intent";
  value.actions[0]!.kind = "resume_exact";
  expect(ownedDiagnostic(value).invalid).toBe(false);
  value.actions[0]!.target = { ...value.identity!, id: "22" };
  expect(ownedDiagnostic(value).invalid).toBe(true);
});
test("full-width integer and byte-coordinate overflow cannot round into valid evidence", () => {
  const value = fixture();
  value.identity!.id = "18446744073709551616";
  expect(ownedDiagnostic(value).invalid).toBe(true);
  value.identity!.id = "18446744073709551615";
  expect(ownedDiagnostic(value).invalid).toBe(false);
  value.location = {
    source: null,
    source_encoding: "utf8",
    source_truncated: false,
    statement: null,
    offset: "18446744073709551615",
    length: "1",
    line: "1",
    byte_column: "1",
  };
  expect(ownedDiagnostic(value).invalid).toBe(true);
});

test("catalog cancellation requires a recorded pending operation", () => {
  const value = fixture();
  value.outcome = "pending";
  value.evidence = "domain_status";
  value.identity!.domain = "catalog";
  value.actions = [{ kind: "cancel_mutation", target: value.identity }, null, null, null];
  expect(ownedDiagnostic(value).invalid).toBe(false);
  for (const outcome of [
    "unknown",
    "prepared",
    "not_applicable",
    "input_rejected",
    "applied",
    "rejected",
    "cancelled",
  ] as const)
    expect(ownedDiagnostic({ ...value, outcome }).invalid).toBe(true);
  expect(ownedDiagnostic({ ...value, evidence: "native_receipt" }).invalid).toBe(true);
  value.actions[0]!.target = { ...value.identity!, id: "22" };
  expect(ownedDiagnostic(value).invalid).toBe(true);
});

test("recorded effect uncertainty has owner evidence without authorizing fresh work", () => {
  const value = fixture();
  value.outcome = "unknown";
  value.evidence = "domain_status";
  value.identity!.domain = "effect";
  value.actions = [{ kind: "inspect_status", target: value.identity }, null, null, null];
  expect(ownedDiagnostic(value).invalid).toBe(false);
  value.identity!.domain = "mutation";
  value.actions[0]!.target = value.identity;
  expect(ownedDiagnostic(value).invalid).toBe(true);
});

test("not-dispatched evidence requires a scoped exchange and cannot resume it", () => {
  const value = fixture();
  value.outcome = "not_dispatched";
  value.identity = {
    domain: "exchange",
    id: "18446744073709551615",
    resource: "7",
    realm: null,
    sequence: null,
  };
  value.actions = [{ kind: "inspect_status", target: value.identity }, null, null, null];
  expect(ownedDiagnostic(value).invalid).toBe(false);
  value.actions[0]!.kind = "resume_exact";
  expect(ownedDiagnostic(value).invalid).toBe(true);
  value.actions[0]!.kind = "inspect_status";
  value.identity.resource = null;
  expect(ownedDiagnostic(value).invalid).toBe(true);
  value.identity.domain = "effect";
  expect(ownedDiagnostic(value).invalid).toBe(true);
});
