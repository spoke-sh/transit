import fixture from "../../../packages/zig/transit-protocol/src/fixtures/diagnostic-v1.json" with { type: "json" };
import { expect, test } from "vite-plus/test";
import { inspectionResponse } from "@transit/board-client";

function page() {
  const facts = Object.entries({
    object: "1",
    attempt: "5",
    executor: "2",
    authorization_policy: "4",
    actual_count: "1",
    limit: "2",
    deadline: "1000",
    native_input: "9",
    principal: "0",
    resolution_policy: "0",
    observed_clock: "1000",
  }).map(([field, value]) => ({
    field,
    value: { unsigned: value },
    origin: "authority",
    availability: "provided",
  }));
  const diagnostic = {
    ...structuredClone(fixture),
    code: "effect.reconciliation_expired",
    category: "lifecycle",
    stage: "reconcile",
    outcome: "closed_unknown",
    evidence: "domain_status",
    message: "The reconciliation deadline closed; the remote outcome remains unknown.",
    cause: null,
    location: null,
    identity: { domain: "effect", id: "3", realm: "1", resource: null, sequence: null },
    actions: Array(4).fill(null),
    facts: [
      ...facts,
      {
        field: "operation",
        value: { text: "closed_unknown" },
        origin: "authority",
        availability: "provided",
      },
      {
        field: "resolution_reason",
        value: { text: "deadline" },
        origin: "authority",
        availability: "provided",
      },
      null,
      null,
      null,
    ],
  };
  const effect = {
    id: 3,
    pid: 1,
    payload: "",
    phase: "closed_unknown",
    attempt: 5,
    executor: 2,
    authorization_policy: 4,
    last_observation: { input: 7, policy_revision: 4 },
    closure: { reason: "deadline", principal: 0, policy_revision: 0, clock_lower_ms: 1000 },
    result: null,
    closed_at: 9,
    reconcile_before_ms: 1000,
    max_observations: 2,
    observations: 1,
  };
  return {
    observation: {
      version: 1,
      realm: 1,
      resource: "effects",
      pid: 1,
      cut: { position: 10, policy_revision: 0, retained_from: 0 },
      reader: { principal: 0, permissions: 16, pid: null, policy_revision: 0 },
      next: null,
      complete: true,
      history: "retained",
      last_collection: null,
      scanned: 1,
      processes: Array(8).fill(null),
      events: Array(8).fill(null),
      outbox: Array(8).fill(null),
      effects: [effect, ...Array(7).fill(null)],
      payloads: Array(8).fill(null),
    },
    edges: Array(16).fill(null),
    effect_diagnostics: [diagnostic, ...Array(7).fill(null)],
  };
}

test("effect detail is owned and matches original closure identity, policy and clock", () => {
  const source = page();
  const value = inspectionResponse(source);
  expect(value.effectDiagnosticsInvalid).toBeUndefined();
  expect(value.effect_diagnostics[0]?.code).toBe("effect.reconciliation_expired");
  source.effect_diagnostics[0].message = "replaced";
  expect(value.effect_diagnostics[0]?.message).toContain("remote outcome remains unknown");
});

test("invalid optional effect detail preserves the primary observation", () => {
  for (const change of [
    (p: ReturnType<typeof page>) => {
      p.effect_diagnostics[0].identity.id = "4";
    },
    (p: ReturnType<typeof page>) => {
      p.effect_diagnostics[0].identity.realm = "2";
    },
    (p: ReturnType<typeof page>) => {
      p.effect_diagnostics[0].outcome = "completed";
    },
    (p: ReturnType<typeof page>) => {
      p.effect_diagnostics[0].facts[3].value = { unsigned: "8" };
    },
    (p: ReturnType<typeof page>) => {
      p.effect_diagnostics[0].facts[10].value = { unsigned: "999" };
    },
    (p: ReturnType<typeof page>) => {
      p.effect_diagnostics[0].actions[0] = {
        kind: "resume_exact",
        target: p.effect_diagnostics[0].identity,
      };
    },
  ]) {
    const source = page();
    change(source);
    const value = inspectionResponse(source);
    expect(value.effectDiagnosticsInvalid).toBe(true);
    expect(value.effect_diagnostics[0]).toBeNull();
    expect(value.observation.effects[0]?.closure?.reason).toBe("deadline");
    expect(value.observation.effects[0]?.phase).toBe("closed_unknown");
  }
  const source = page();
  source.observation.effects[0].closure.reason = "invented";
  expect(() => inspectionResponse(source)).toThrow("InvalidResponse");
});
