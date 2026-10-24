import { ReactiveError } from "./error";
import {
  currentDefinition,
  type HostResponse,
  type ReactiveRead,
  type SignedCommand,
} from "./types";
import * as validate from "./validators.js";
import type { Pending, Selection } from "./session";

export type SessionRecovery = {
  version: 1;
  definition: typeof currentDefinition;
  description: Extract<HostResponse, { description: unknown }>["description"] | null;
  pending: Omit<Pending, "command"> | null;
  scope: ReactiveRead["read"]["scope"] | null;
  cursor: ReactiveRead["read"]["cursor"] | null;
  attachment: number;
  nonce: number[];
  leaseBefore: number;
  selection: Selection | null;
  selectionControl: SignedCommand | null;
};
export const maxSessionRecoveryBytes = 65536;
const invalid = (): never => {
  throw new ReactiveError(0, "invalid_session_recovery");
};
const record = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const fields = (value: Record<string, unknown>, expected: string[]) =>
  Object.keys(value).sort().join(",") === expected.sort().join(",");
const natural = (value: unknown): value is number =>
  typeof value === "number" && Number.isSafeInteger(value) && value >= 0;

/** Compare semantic JSON independent of object-property order. */
export function sameRecoveryValue(left: unknown, right: unknown): boolean {
  if (left === right) return true;
  if (Array.isArray(left) && Array.isArray(right))
    return (
      left.length === right.length && left.every((value, i) => sameRecoveryValue(value, right[i]))
    );
  if (!record(left) || !record(right)) return false;
  const keys = Object.keys(left);
  return (
    keys.length === Object.keys(right).length &&
    keys.every((key) => Object.hasOwn(right, key) && sameRecoveryValue(left[key], right[key]))
  );
}

export function readSessionRecovery(source: string): SessionRecovery {
  if (
    source.length > maxSessionRecoveryBytes ||
    new TextEncoder().encode(source).length > maxSessionRecoveryBytes
  )
    return invalid();
  let input: unknown;
  try {
    input = JSON.parse(source);
  } catch {
    return invalid();
  }
  // Bound nesting before invoking recursive generated validators.
  const work: Array<[unknown, number]> = [[input, 0]];
  let visited = 0;
  while (work.length) {
    const [value, depth] = work.pop()!;
    if (++visited > 8192 || depth > 32) return invalid();
    if (typeof value === "object" && value !== null)
      for (const child of Object.values(value)) work.push([child, depth + 1]);
  }
  if (
    !record(input) ||
    !fields(input, [
      "version",
      "definition",
      "description",
      "pending",
      "scope",
      "cursor",
      "attachment",
      "nonce",
      "leaseBefore",
      "selection",
      "selectionControl",
    ]) ||
    input.version !== 1 ||
    input.definition !== currentDefinition ||
    (input.description !== null && !validate.HostResponse({ description: input.description })) ||
    !natural(input.attachment) ||
    !natural(input.leaseBefore) ||
    !Array.isArray(input.nonce) ||
    input.nonce.length !== 16 ||
    !input.nonce.every((value) => natural(value) && value <= 255)
  )
    return invalid();
  if (input.pending !== null) {
    const pending = input.pending;
    if (
      !record(pending) ||
      !fields(pending, ["signed", "input"]) ||
      !validate.SignedCommand(pending.signed) ||
      (pending.input !== null && (!natural(pending.input) || pending.input === 0))
    )
      return invalid();
  }
  if (input.scope === null) {
    if (input.cursor !== null || input.attachment !== 0 || input.selection !== null)
      return invalid();
  } else {
    if (
      !record(input.scope) ||
      !validate.HostRequest({
        sign_read: {
          scope: input.scope,
          kind: "events",
          attachment: input.attachment,
          nonce: input.nonce,
          cursor: input.cursor,
        },
      })
    )
      return invalid();
    for (const key of ["realm", "principal", "service", "ingress", "session", "generation"])
      if (!natural(input.scope[key]) || input.scope[key] === 0) return invalid();
    if (
      ((input.scope.subscription ?? 0) === 0) !==
      ((input.scope.subscription_generation ?? 0) === 0)
    )
      return invalid();
    if (
      input.cursor !== null &&
      (!record(input.cursor) ||
        !record(input.cursor.position) ||
        !sameRecoveryValue(input.cursor.position.scope, input.scope))
    )
      return invalid();
  }
  if (input.selection !== null && !validate.HostRequest({ refresh_status: input.selection }))
    return invalid();
  if (
    (input.selection === null) !== (input.selectionControl === null) ||
    (input.selectionControl !== null && !validate.SignedCommand(input.selectionControl))
  )
    return invalid();
  const saved = input as SessionRecovery;
  if (!saved.description) {
    if (saved.scope || saved.pending || saved.selection) return invalid();
  } else {
    const connection = saved.description.connection;
    if (saved.scope)
      for (const key of ["realm", "principal", "service", "ingress"] as const)
        if (saved.scope[key] !== connection[key]) return invalid();
    for (const token of [saved.pending?.signed, saved.selectionControl]) {
      if (!token) continue;
      const request = token.request;
      if (
        request.realm !== connection.realm ||
        request.principal !== connection.principal ||
        request.command.send.pid !== connection.ingress ||
        (request.command.send.role ?? null) !== (connection.role ?? null)
      )
        return invalid();
    }
    if (
      saved.selection &&
      (!saved.scope ||
        saved.selection.session.session !== saved.scope.session ||
        saved.selection.session.generation !== saved.scope.generation)
    )
      return invalid();
    if (
      saved.cursor &&
      saved.cursor.position.watch_revision !== saved.description.discovery.watch_revision
    )
      return invalid();
  }
  return saved;
}
