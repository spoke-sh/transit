import type { Diagnostic } from "./types";
import { Diagnostic as validate } from "./validators.js";

/** Optional detail never replaces the transport status or controls retries. */
export function ownedDiagnostic(value: unknown): { diagnostic?: Diagnostic; invalid: boolean } {
  if (value === undefined || value === null) return { invalid: false };
  try {
    const bytes = JSON.stringify(value);
    if (new TextEncoder().encode(bytes).length > 32768 || !validate(value))
      return { invalid: true };
    const diagnostic = JSON.parse(bytes) as Diagnostic;
    if (
      !validValues(diagnostic) ||
      !validEvidence(diagnostic) ||
      bytes.replace(/[\u007f-\uffff]/g, "\\u0000").length > 32768
    )
      return { invalid: true };
    return { diagnostic, invalid: false };
  } catch {
    return { invalid: true };
  }
}
const u64 = (value: string) => BigInt(value) <= 18446744073709551615n;
const text = (value: string, limit: number) =>
  !/[\uD800-\uDFFF]/u.test(value) && new TextEncoder().encode(value).length <= limit;
function validIdentity(id: NonNullable<Diagnostic["identity"]>): boolean {
  return (
    BigInt(id.id) > 0n &&
    u64(id.id) &&
    (id.domain !== "exchange" || id.resource !== null) &&
    [id.realm, id.resource, id.sequence].every(
      (n) => n === null || (BigInt(n) > 0n && BigInt(n) <= 9007199254740991n),
    )
  );
}
function validLocation(loc: NonNullable<Diagnostic["location"]>): boolean {
  return (
    (loc.source === null
      ? !loc.source_truncated && loc.source_encoding === "utf8"
      : text(loc.source, 512) &&
        (loc.source_encoding === "utf8" ||
          /^(?:[\x20-\x21\x23-\x5b\x5d-\x7e]|\\x[0-9a-f]{2})*$/.test(loc.source))) &&
    BigInt(loc.line) > 0n &&
    u64(loc.line) &&
    BigInt(loc.byte_column) > 0n &&
    u64(loc.byte_column) &&
    (loc.statement === null || (BigInt(loc.statement) > 0n && u64(loc.statement))) &&
    BigInt(loc.offset) + BigInt(loc.length) <= 18446744073709551615n
  );
}
function validValues(d: Diagnostic): boolean {
  if (
    !/^[a-z0-9_]+(?:\.[a-z0-9_]+)*$/.test(d.code) ||
    !text(d.message, 384) ||
    (d.cause !== null && !text(d.cause, 96)) ||
    (d.identity !== null && !validIdentity(d.identity)) ||
    (d.location !== null && !validLocation(d.location))
  )
    return false;
  for (const fact of d.facts) {
    const value = fact?.value;
    if (!value) continue;
    if ("text" in value && !text(value.text, 256)) return false;
    if (
      "signed" in value &&
      (BigInt(value.signed) < -9223372036854775808n || BigInt(value.signed) > 9223372036854775807n)
    )
      return false;
    if ("unsigned" in value && !u64(value.unsigned)) return false;
    if ("location" in value && !validLocation(value.location)) return false;
  }
  return d.actions.every((action) => !action?.target || validIdentity(action.target));
}
function validEvidence(d: Diagnostic): boolean {
  const expected = {
    not_submitted: ["local_before_dispatch"],
    not_dispatched: ["domain_status"],
    prepared: ["saved_intent"],
    pending: ["native_receipt", "domain_status"],
    rejected: ["domain_status"],
    applied: ["domain_status"],
    completed: ["domain_status"],
    failed: ["domain_status"],
    cancelled: ["domain_status"],
    retired: ["domain_status"],
    input_rejected: ["domain_status"],
    closed_unknown: ["domain_status"],
    unknown: ["none", "local_before_dispatch", "saved_intent", "domain_status"],
    not_applicable: [
      "none",
      "local_before_dispatch",
      "saved_intent",
      "native_receipt",
      "domain_status",
    ],
  } satisfies Record<Diagnostic["outcome"], string[]>;
  if (!(expected[d.outcome] as string[]).includes(d.evidence)) return false;
  if (d.outcome === "not_dispatched" && d.identity?.domain !== "exchange") return false;
  if (d.outcome === "unknown" && d.evidence === "domain_status" && d.identity?.domain !== "effect")
    return false;
  let end = false;
  for (const fact of d.facts) {
    if (!fact) end = true;
    else if (end || ["provided", "truncated"].includes(fact.availability) !== (fact.value !== null))
      return false;
  }
  const kinds = new Set<string>();
  end = false;
  for (const action of d.actions) {
    if (!action) {
      end = true;
      continue;
    }
    if (end || kinds.has(action.kind)) return false;
    kinds.add(action.kind);
    if (
      ["resume_exact", "cancel_wait", "cancel_mutation", "reconcile_effect"].includes(action.kind)
    ) {
      if (
        !d.identity ||
        !action.target ||
        !(["domain", "id", "realm", "resource", "sequence"] as const).every(
          (key) => d.identity![key] === action.target![key],
        )
      )
        return false;
      if (
        !["unknown", "prepared", "pending", "input_rejected"].includes(d.outcome) &&
        !(d.outcome === "closed_unknown" && action.kind === "reconcile_effect")
      )
        return false;
      if (action.kind === "cancel_mutation" && action.target.domain !== "mutation") return false;
      if (action.kind === "reconcile_effect" && action.target.domain !== "effect") return false;
      if (action.target.domain === "effect" && action.kind !== "reconcile_effect") return false;
    }
    if (
      ["correct_input", "recompile"].includes(action.kind) &&
      ["unknown", "pending", "prepared", "input_rejected", "closed_unknown"].includes(d.outcome)
    )
      return false;
  }
  return true;
}
const words = (value: string) => value.replaceAll("_", " ");
const actions: Record<NonNullable<Diagnostic["actions"][number]>["kind"], string> = {
  correct_input: "Correct the input before submitting it.",
  inspect_status: "Inspect the saved operation's status.",
  resume_exact: "Reconcile using the exact saved command. Do not repeat the SQL.",
  cancel_wait: "Cancel the wait through its owning control; accepted work may continue.",
  cancel_mutation: "Cancel the saved mutation through its owning control.",
  refresh: "Refresh the current observation.",
  recompile: "Compile against the current source definition before submitting new work.",
  retry_read: "Retry this read without replacing any saved command.",
  inspect_scope: "Inspect the current access scope and source policy.",
  reconcile_effect:
    "Reconcile the recorded external effect. Closure does not prove external cancellation.",
  contact_operator: "Contact the operator with this code and the saved operation identity.",
};
function location(value: NonNullable<Diagnostic["location"]>): string {
  const source =
    value.source === null
      ? ""
      : `${JSON.stringify(value.source)}${value.source_truncated ? " (truncated)" : ""}${value.source_encoding === "escaped_bytes" ? " (escaped bytes)" : ""}: `;
  return `${source}${value.statement === null ? "" : `statement ${value.statement}, `}line ${value.line}, byte column ${value.byte_column} (byte ${value.offset}, length ${value.length})`;
}
/** Text for a caller-facing view only. Never use this text as a log or retry policy. */
export function diagnosticLines(d: Diagnostic): string[] {
  const lines = [
    d.message,
    `${words(d.category)} · ${d.code}`,
    `Outcome: ${words(d.outcome)}; evidence: ${words(d.evidence)}.`,
  ];
  if (d.identity)
    lines.push(
      `${words(d.identity.domain)} ${d.identity.id}${d.identity.sequence === null ? "" : `; sequence ${d.identity.sequence}`}`,
    );
  if (d.location) lines.push(location(d.location));
  for (const fact of d.facts) {
    if (!fact) continue;
    const value = fact.value;
    const detail =
      value === null
        ? words(fact.availability)
        : "text" in value
          ? JSON.stringify(value.text)
          : "signed" in value
            ? value.signed
            : "unsigned" in value
              ? value.unsigned
              : "boolean" in value
                ? String(value.boolean)
                : "location" in value
                  ? location(value.location)
                  : value.digest.map((byte) => byte.toString(16).padStart(2, "0")).join("");
    lines.push(
      `${words(fact.field)}: ${detail}${fact.availability === "truncated" ? " (truncated)" : ""}`,
    );
  }
  for (const action of d.actions) if (action) lines.push(actions[action.kind]);
  return lines;
}

export type { Diagnostic } from "./types";
