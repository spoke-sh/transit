import assert from "node:assert/strict";
import test from "node:test";
import contract from "./contract.json" with { type: "json" };
import { nativeError, UnknownOutcome, type Diagnostic } from "./errors.ts";

test("optional diagnostic validation preserves uncertainty and owns caller detail", () => {
  const diagnostic: Diagnostic = {
    version: 1,
    definition: contract.definition as Diagnostic["definition"],
    code: "query.send_unknown",
    category: "unavailable",
    stage: "submit",
    outcome: "unknown",
    evidence: "saved_intent",
    message: "Retain the saved command.",
    cause: null,
    identity: null,
    location: null,
    facts: Array(16).fill(null),
    actions: Array(4).fill(null),
  };
  const error = nativeError(6, { err: "ProcessExpired", diagnostic }, "submit");
  assert.ok(error instanceof UnknownOutcome);
  assert.deepEqual(error.diagnostic, diagnostic);
  diagnostic.message = "Changed caller object";
  assert.equal(error.diagnostic?.message, "Retain the saved command.");
  assert.equal(error.message.includes("Retain"), false);
  for (const detail of [
    {},
    { ...diagnostic, definition: "foreign" },
    { ...diagnostic, facts: [] },
  ]) {
    const malformed = nativeError(6, { err: "ProcessExpired", diagnostic: detail }, "submit");
    assert.ok(malformed instanceof UnknownOutcome);
    assert.equal(malformed.code, "ProcessExpired");
    assert.equal(malformed.diagnostic, undefined);
    assert.equal(malformed.diagnosticInvalid, true);
  }
});
