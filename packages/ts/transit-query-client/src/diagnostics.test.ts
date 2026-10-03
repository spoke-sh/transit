import fixtureValue from "../../../zig/transit-protocol/src/fixtures/diagnostic-v1.json" with { type: "json" };
import { afterEach, expect, test, vi } from "vite-plus/test";
import { validateUnifiedQuery } from "./values";
import { diagnosticLines, ownedDiagnostic } from "./diagnostics";
import { httpTransport, QueryError } from "./transport";
import type { Diagnostic } from "./types";
const fixture = (): Diagnostic => structuredClone(fixtureValue) as Diagnostic;
afterEach(() => vi.unstubAllGlobals());

test("owned caller detail preserves exact integers, unavailable facts and text escaping", () => {
  const original = fixture();
  const error = new QueryError(400, "UnsupportedQuery", original);
  expect(error.diagnosticInvalid).toBe(false);
  expect(error.diagnostic).toEqual(original);
  original.message = "changed by caller";
  expect(error.diagnostic?.message).not.toBe(original.message);
  expect(error.message).toBe("UnsupportedQuery");
  expect(diagnosticLines(error.diagnostic!).join("\n")).toContain("key: -9223372036854775808");
  expect(diagnosticLines(error.diagnostic!).join("\n")).toContain("constraint: unrecorded");
});
test("malformed optional evidence cannot replace the primary HTTP error", async () => {
  const fetcher = vi.fn();
  vi.stubGlobal("fetch", fetcher);
  for (const diagnostic of [
    {},
    { ...fixture(), definition: "0".repeat(64) },
    { ...fixture(), message: "\ud800" },
    { ...fixture(), outcome: "unknown" },
    { ...fixture(), message: "😀".repeat(200) },
  ]) {
    fetcher.mockResolvedValueOnce(Response.json({ err: "Forbidden", diagnostic }, { status: 403 }));
    await expect(
      httpTransport("/query")({ compile: { sql: "SELECT private FROM source" } }),
    ).rejects.toMatchObject({
      status: 403,
      code: "Forbidden",
      diagnostic: undefined,
      diagnosticInvalid: true,
    });
  }
  expect(fetcher).toHaveBeenCalledTimes(5);
});
test("unknown send guidance cannot initiate retry or authorize replacement SQL", async () => {
  const diagnostic = fixture();
  diagnostic.outcome = "unknown";
  diagnostic.evidence = "saved_intent";
  diagnostic.actions = [{ kind: "resume_exact", target: diagnostic.identity }, null, null, null];
  expect(ownedDiagnostic(diagnostic).invalid).toBe(false);
  const fetcher = vi
    .fn()
    .mockResolvedValueOnce(Response.json({ err: "Unavailable", diagnostic }, { status: 503 }));
  vi.stubGlobal("fetch", fetcher);
  await expect(
    httpTransport("/query")({ submit: { token: "original-signed-bytes" } }),
  ).rejects.toMatchObject({ status: 503, diagnostic });
  expect(fetcher).toHaveBeenCalledTimes(1);
  diagnostic.actions[1] = { kind: "correct_input", target: null };
  expect(ownedDiagnostic(diagnostic).invalid).toBe(true);
  diagnostic.actions[1] = null;
  diagnostic.actions[0]!.target = { ...diagnostic.identity!, id: "22" };
  expect(ownedDiagnostic(diagnostic).invalid).toBe(true);
});
test("out of range coordinates, sparse facts and escaped size overflow reject", () => {
  for (const edit of [
    (d: Diagnostic) => {
      d.identity!.id = "18446744073709551616";
    },
    (d: Diagnostic) => {
      d.facts[0] = null;
    },
    (d: Diagnostic) => {
      d.location = {
        source: null,
        source_encoding: "utf8",
        source_truncated: false,
        statement: null,
        offset: "18446744073709551615",
        length: "1",
        line: "1",
        byte_column: "1",
      };
    },
    (d: Diagnostic) => {
      d.facts = Array.from({ length: 16 }, () => ({
        field: "parameter_use",
        origin: "caller",
        availability: "provided",
        value: {
          location: {
            source: "\x01".repeat(512),
            source_encoding: "utf8",
            source_truncated: false,
            statement: null,
            offset: "0",
            length: "1",
            line: "1",
            byte_column: "1",
          },
        },
      }));
    },
  ]) {
    const value = fixture();
    edit(value);
    expect(ownedDiagnostic(value).invalid).toBe(true);
  }
});

test("saved status detail cannot contradict the returned domain outcome", () => {
  const diagnostic = fixture();
  diagnostic.identity!.domain = "query";
  diagnostic.code = "query.cancelled";
  diagnostic.category = "lifecycle";
  diagnostic.stage = "control";
  diagnostic.outcome = "cancelled";
  diagnostic.actions = [{ kind: "inspect_status", target: diagnostic.identity }, null, null, null];
  const status = {
    reference: "00",
    phase: "cancelled",
    correlation: "1",
    manifest: null,
    collected: false,
    failure: null,
    diagnostic,
  };
  expect(validateUnifiedQuery({ status })).toBe(true);
  status.phase = "complete";
  expect(validateUnifiedQuery({ status })).toBe(false);
  status.phase = "cancelled";
  diagnostic.actions[0]!.kind = "resume_exact";
  expect(validateUnifiedQuery({ status })).toBe(false);
});
