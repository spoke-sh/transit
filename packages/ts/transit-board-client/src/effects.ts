import { ownedDiagnostic, QueryError } from "@rey/transit-query-client";
import type { Response as WireResponse } from "./types";
import { Response as validate } from "./validators.js";

export type Response = WireResponse & { effectDiagnosticsInvalid?: boolean };

/** Optional detail cannot erase an otherwise valid authorized observation. */
export function inspectionResponse(value: unknown): Response {
  if (typeof value !== "object" || value === null) throw new QueryError(0, "InvalidResponse");
  const primary = { ...value, effect_diagnostics: Array(8).fill(null) };
  if (!validate(primary)) throw new QueryError(0, "InvalidResponse");
  const result = primary as Response;
  const supplied = "effect_diagnostics" in value ? value.effect_diagnostics : undefined;
  if (supplied === undefined || supplied === null) return result;
  if (!Array.isArray(supplied) || supplied.length !== 8) {
    result.effectDiagnosticsInvalid = true;
    return result;
  }
  result.effect_diagnostics = supplied.map((item, index) => {
    const owned = ownedDiagnostic(item);
    const detail = owned.diagnostic;
    const effect = result.observation.effects[index];
    if (!detail && !owned.invalid) return null;
    const fact = (name: string) => detail?.facts.find((entry) => entry?.field === name)?.value;
    const number = (name: string, expected: number | null) => {
      const found = fact(name);
      return expected === null
        ? found === undefined
        : found !== undefined &&
            found !== null &&
            "unsigned" in found &&
            found.unsigned === String(expected);
    };
    const operation = fact("operation");
    const resolution = fact("resolution_reason");
    const outcomes = {
      pending: "pending",
      authorized: "unknown",
      unknown: "unknown",
      observed: "completed",
      cancelled: "cancelled",
      closed_unknown: "closed_unknown",
    } as const;
    if (
      owned.invalid ||
      detail?.facts.some(
        (entry, ordinal) =>
          entry !== null &&
          detail.facts.findIndex((earlier) => earlier?.field === entry.field) !== ordinal,
      ) ||
      !effect ||
      !detail ||
      detail.identity?.domain !== "effect" ||
      detail.identity.id !== String(effect.id) ||
      detail.identity.realm !== String(result.observation.realm) ||
      detail.identity.resource !== null ||
      detail.evidence !== "domain_status" ||
      detail.outcome !== outcomes[effect.phase] ||
      !operation ||
      !("text" in operation) ||
      operation.text !== effect.phase ||
      !number("object", effect.pid) ||
      !number("attempt", effect.attempt) ||
      !number("executor", effect.executor) ||
      !number("authorization_policy", effect.authorization_policy) ||
      !number("actual_count", effect.observations) ||
      !number("limit", effect.max_observations) ||
      !number("deadline", effect.reconcile_before_ms) ||
      !number("native_input", effect.closed_at ?? effect.last_observation?.input ?? null) ||
      !number("principal", effect.closure?.principal ?? null) ||
      !number(
        "resolution_policy",
        effect.closure?.policy_revision ?? effect.last_observation?.policy_revision ?? null,
      ) ||
      !number("observed_clock", effect.closure?.clock_lower_ms ?? null) ||
      (effect.closure
        ? !resolution || !("text" in resolution) || resolution.text !== effect.closure.reason
        : resolution !== undefined)
    ) {
      result.effectDiagnosticsInvalid = true;
      return null;
    }
    return detail;
  });
  return result;
}
