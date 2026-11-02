import { expect, test } from "vite-plus/test";
import { initialObservation, transition, type ReadFailure } from "./observation";
import { inspectionEvidence } from "./inspection-evidence";

test("stale process evidence keeps its exact basis through retries but clears on denial, hide or scope change", () => {
  const loading = transition(initialObservation<string>(), { type: "read" }).state;
  const ready = transition(loading, {
    type: "received",
    generation: loading.generation,
    value: "position 44",
  }).state;
  const original = inspectionEvidence(null, "process/1", ready);
  const refreshing = transition(ready, { type: "read" }).state;
  for (const kind of [
    "unavailable",
    "limited",
    "denied",
    "expired",
    "incompatible",
    "unconfigured",
  ] as ReadFailure["kind"][]) {
    const failed = transition(refreshing, {
      type: "failed",
      generation: refreshing.generation,
      failure: { kind, code: kind, retryable: kind === "unavailable" || kind === "limited" },
    }).state;
    const evidence = inspectionEvidence(original, "process/1", failed);
    if (kind === "unavailable" || kind === "limited") {
      expect(evidence?.value).toBe("position 44");
      expect(evidence?.failure?.kind).toBe(kind);
      const retry = transition(failed, { type: "read" }).state;
      expect(inspectionEvidence(evidence, "process/1", retry)).toEqual(evidence);
      expect(inspectionEvidence(evidence, "process/2", retry)).toBeNull();
      const denied = transition(retry, {
        type: "failed",
        generation: retry.generation,
        failure: { kind: "denied", code: "Forbidden", retryable: false },
      }).state;
      expect(inspectionEvidence(evidence, "process/1", denied)).toBeNull();
    } else expect(evidence).toBeNull();
  }
  for (const type of ["hide", "dispose"] as const)
    expect(inspectionEvidence(original, "process/1", transition(ready, { type }).state)).toBeNull();
});
