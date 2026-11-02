import type { ReadFailure } from "./observation";

export type StatementState = {
  reader: string | null;
  generation: number;
  phase: "idle" | "submitting" | "observing" | "advancing" | "ready" | "failed";
  visible: boolean;
  available: boolean;
  disclosed: boolean;
  disposed: boolean;
  failure: ReadFailure | null;
};
export const initialStatement = (): StatementState => ({
  reader: null,
  generation: 0,
  phase: "idle",
  visible: true,
  available: true,
  disclosed: false,
  disposed: false,
  failure: null,
});
export type StatementEvent =
  | { type: "run"; reader: string }
  | { type: "observe" | "next" | "close" | "dispose" }
  | { type: "visibility" | "availability"; value: boolean }
  | { type: "received"; reader: string; generation: number }
  | { type: "failed"; reader: string; generation: number; failure: ReadFailure };
export type StatementEffect =
  | { type: "cancel" }
  | { type: "close"; reader: string }
  | { type: "run" | "observe" | "next"; reader: string; generation: number };
export const statementBusy = (state: StatementState) =>
  ["submitting", "observing", "advancing"].includes(state.phase);

/** Presentation owns explicit intent and disclosure. StatementReader owns all
 * result truth, sequencing, uncertainty and server cleanup semantics. */
export function statementTransition(
  state: StatementState,
  event: StatementEvent,
): {
  state: StatementState;
  effects: StatementEffect[];
} {
  const unchanged = { state, effects: [] };
  if (state.disposed) return unchanged;
  if (event.type === "close" || event.type === "dispose")
    return {
      state: {
        ...state,
        reader: null,
        generation: state.generation + 1,
        phase: "idle",
        disclosed: false,
        failure: null,
        disposed: event.type === "dispose",
      },
      effects: [
        { type: "cancel" },
        ...(state.reader ? [{ type: "close" as const, reader: state.reader }] : []),
      ],
    };
  if (event.type === "visibility" || event.type === "availability") {
    const next = { ...state, [event.type === "visibility" ? "visible" : "available"]: event.value };
    if (!event.value)
      return {
        state: { ...next, generation: state.generation + 1, phase: "idle", disclosed: false },
        effects: [{ type: "cancel" }],
      };
    return next.visible && next.available && next.reader
      ? statementTransition(next, { type: "observe" })
      : { state: next, effects: [] };
  }
  if (event.type === "run" || event.type === "observe" || event.type === "next") {
    if (!state.visible || !state.available || statementBusy(state)) return unchanged;
    const reader = event.type === "run" ? event.reader : state.reader;
    if (!reader) return unchanged;
    return {
      state: {
        ...state,
        reader,
        generation: state.generation + 1,
        phase:
          event.type === "run" ? "submitting" : event.type === "next" ? "advancing" : "observing",
        disclosed: event.type === "run" ? false : state.disclosed,
        failure: null,
      },
      effects: [
        { type: "cancel" },
        ...(event.type === "run" && state.reader
          ? [{ type: "close" as const, reader: state.reader }]
          : []),
        { type: event.type, reader, generation: state.generation + 1 },
      ],
    };
  }
  if (event.type !== "received" && event.type !== "failed") return unchanged;
  if (
    event.reader !== state.reader ||
    event.generation !== state.generation ||
    !statementBusy(state) ||
    !state.visible ||
    !state.available
  )
    return unchanged;
  if (event.type === "received")
    return {
      state: { ...state, phase: "ready", disclosed: true, failure: null },
      effects: [],
    };
  const denied = event.failure.kind === "denied";
  return {
    state: {
      ...state,
      phase: "failed",
      disclosed: false,
      failure: event.failure,
      reader: denied ? null : state.reader,
    },
    effects: denied ? [{ type: "close", reader: event.reader }] : [],
  };
}
