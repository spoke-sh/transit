import { ApplicationTransportError } from "@transit/application";
import { ReactiveError } from "@transit/reactive-client";
import { QueryError } from "@transit/query-client";
import { BoardError } from "@transit/board-client";

export type ReadFailure = {
  kind:
    | "unconfigured"
    | "denied"
    | "expired"
    | "incompatible"
    | "limited"
    | "unavailable"
    | "refused";
  code: string;
  retryable: boolean;
};

/** Preserve typed causes. Transport loss never establishes an empty result. */
export function readFailure(cause: unknown): ReadFailure {
  if (
    !(cause instanceof QueryError) &&
    !(cause instanceof BoardError) &&
    !(cause instanceof ApplicationTransportError) &&
    !(cause instanceof ReactiveError)
  )
    return { kind: "unavailable", code: "ConnectionUnavailable", retryable: true };
  const code = cause instanceof ReactiveError ? cause.reason : cause.code;
  if (code === "QueryDisabled") return { kind: "unconfigured", code, retryable: false };
  if (cause.status === 403) return { kind: "denied", code, retryable: false };
  if (cause.status === 429 || code === "QueryBusy" || code === "ReadWorkspaceCapacity")
    return { kind: "limited", code, retryable: true };
  if (
    code === "InvalidResponse" ||
    code === "ResultIdentityChanged" ||
    code === "IncompatibleDefinition" ||
    code === "ResponseTooLarge" ||
    code === "invalid_response" ||
    code === "response_too_large" ||
    code === "incompatible_definition"
  )
    return { kind: "incompatible", code, retryable: false };
  if (cause.status === 409 || cause.status === 410)
    return { kind: "expired", code, retryable: false };
  if (cause.status === 0 || cause.status >= 500)
    return { kind: "unavailable", code, retryable: true };
  return { kind: "refused", code, retryable: false };
}

type Phase<T> =
  | { tag: "idle" | "loading" | "hidden" | "disposed"; value: null; failure: null }
  | { tag: "ready" | "refreshing"; value: T; failure: null }
  | { tag: "failed"; value: null; failure: ReadFailure };
export type Observation<T> = Phase<T> & { generation: number; failures: number };
export type ObservationEvent<T> =
  | { type: "read" | "hide" | "show" | "dispose" }
  | { type: "received"; generation: number; value: T }
  | { type: "failed"; generation: number; failure: ReadFailure };
export type ObservationEffect =
  | { type: "read"; generation: number }
  | { type: "cancel" }
  | { type: "schedule"; delay: number };
export const initialObservation = <T>(): Observation<T> => ({
  tag: "idle",
  value: null,
  failure: null,
  generation: 0,
  failures: 0,
});

/** The production transition owner. I/O, clocks and React live in its adapter. */
export function transition<T>(
  state: Observation<T>,
  event: ObservationEvent<T>,
  interval = 5000,
): { state: Observation<T>; effects: ObservationEffect[] } {
  const unchanged = { state, effects: [] };
  if (state.tag === "disposed") return unchanged;
  if (event.type === "hide" || event.type === "dispose")
    return {
      state: {
        tag: event.type === "hide" ? "hidden" : "disposed",
        value: null,
        failure: null,
        generation: state.generation + 1,
        failures: 0,
      },
      effects: [{ type: "cancel" }],
    };
  if (event.type === "read" || event.type === "show") {
    if (
      state.tag === "loading" ||
      state.tag === "refreshing" ||
      (state.tag === "hidden" && event.type !== "show")
    )
      return unchanged;
    const generation = state.generation + 1;
    return {
      state:
        state.tag === "ready"
          ? {
              tag: "refreshing",
              value: state.value,
              failure: null,
              generation,
              failures: state.failures,
            }
          : { tag: "loading", value: null, failure: null, generation, failures: state.failures },
      effects: [{ type: "cancel" }, { type: "read", generation }],
    };
  }
  if (
    !("generation" in event) ||
    event.generation !== state.generation ||
    (state.tag !== "loading" && state.tag !== "refreshing")
  )
    return unchanged;
  if (event.type === "received")
    return {
      state: {
        tag: "ready",
        value: event.value,
        failure: null,
        generation: state.generation,
        failures: 0,
      },
      effects: interval ? [{ type: "schedule", delay: interval }] : [],
    };
  if (event.type !== "failed") return unchanged;
  const failures = Math.min(3, state.failures + 1);
  return {
    state: {
      tag: "failed",
      value: null,
      failure: event.failure,
      generation: state.generation,
      failures,
    },
    effects:
      interval && event.failure.retryable
        ? [
            {
              type: "schedule",
              delay: Math.min(
                30000,
                (event.failure.kind === "limited" ? 250 : interval) * 2 ** failures,
              ),
            },
          ]
        : [],
  };
}
