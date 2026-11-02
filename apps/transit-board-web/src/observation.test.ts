import { expect, test } from "vite-plus/test";
import { BoardError } from "@transit/board-client";
import { QueryError } from "@transit/query-client";
import {
  initialObservation,
  transition,
  readFailure,
  type Observation,
  type ObservationEvent,
} from "./observation";

test("configuration and authorization failures stop polling, for both public clients", () => {
  for (const ErrorType of [BoardError, QueryError]) {
    for (const [status, code, kind] of [
      [503, "QueryDisabled", "unconfigured"],
      [403, "Forbidden", "denied"],
      [410, "Expired", "expired"],
      [200, "InvalidResponse", "incompatible"],
    ] as const) {
      const failure = readFailure(new ErrorType(status, code));
      expect(failure).toEqual({ kind, code, retryable: false });
      const loading = transition(initialObservation(), { type: "read" }).state;
      const result = transition(loading, {
        type: "failed",
        generation: loading.generation,
        failure,
      });
      expect(result.effects).toEqual([]);
      expect(result.state.value).toBeNull();
    }
  }
});

test("refresh keeps a qualified observation until replacement, denial removes it", () => {
  const loading = transition(initialObservation<string>(), { type: "read" }).state;
  const ready = transition(loading, {
    type: "received",
    generation: loading.generation,
    value: "original",
  }).state;
  const refreshing = transition(ready, { type: "read" }).state;
  expect(refreshing.tag).toBe("refreshing");
  expect(refreshing.value).toBe("original");
  expect(
    transition(refreshing, { type: "received", generation: loading.generation, value: "late" })
      .state,
  ).toEqual(refreshing);
  const denied = transition(refreshing, {
    type: "failed",
    generation: refreshing.generation,
    failure: readFailure(new QueryError(403, "Denied")),
  }).state;
  expect(denied.value).toBeNull();
  expect(
    transition(denied, { type: "received", generation: refreshing.generation, value: "late" })
      .state,
  ).toEqual(denied);
});

test("failures back off with a bounded delay and successful empty data is distinct", () => {
  let state = initialObservation<string[]>();
  const delays: number[] = [];
  for (let index = 0; index < 5; index++) {
    state = transition(state, { type: "read" }).state;
    const result = transition(state, {
      type: "failed",
      generation: state.generation,
      failure: readFailure(new QueryError(503, "Unavailable")),
    });
    state = result.state;
    delays.push(result.effects.find((effect) => effect.type === "schedule")!.delay);
  }
  expect(delays).toEqual([10000, 20000, 30000, 30000, 30000]);
  state = transition(state, { type: "read" }).state;
  state = transition(state, { type: "received", generation: state.generation, value: [] }).state;
  expect(state.tag).toBe("ready");
  expect(state.value).toEqual([]);
  expect(state.failures).toBe(0);
});

test("bounded exploration fences every completion across hide, retry and disposal", () => {
  // Independent disclosure oracle over all event schedules up to depth six.
  // Generations are supplied by the environment, including a future/late reply.
  let frontier: Observation<string>[] = [initialObservation<string>()];
  let explored = 0;
  for (let depth = 0; depth < 6; depth++) {
    const next = new Map<string, Observation<string>>();
    for (const before of frontier) {
      const events: ObservationEvent<string>[] = [
        { type: "read" },
        { type: "show" },
        { type: "hide" },
        { type: "dispose" },
        ...[before.generation - 1, before.generation, before.generation + 1].flatMap(
          (generation): ObservationEvent<string>[] => [
            { type: "received", generation, value: "protected" },
            {
              type: "failed",
              generation,
              failure: { kind: "denied", code: "Denied", retryable: false },
            },
          ],
        ),
      ];
      for (const event of events) {
        const result = transition(before, event);
        const after = result.state;
        if (["hidden", "disposed", "failed", "idle", "loading"].includes(after.tag))
          expect(after.value).toBeNull();
        if (before.tag === "disposed") expect(result).toEqual({ state: before, effects: [] });
        if (
          "generation" in event &&
          (event.generation !== before.generation ||
            !["loading", "refreshing"].includes(before.tag))
        )
          expect(after).toEqual(before);
        if (event.type === "hide" || event.type === "dispose")
          expect(result.effects.some((effect) => effect.type === "read")).toBe(false);
        if (result.effects.some((effect) => effect.type === "read"))
          expect(["loading", "refreshing"]).toContain(after.tag);
        next.set(JSON.stringify(after), after);
        explored++;
      }
    }
    frontier = [...next.values()];
  }
  expect(explored).toBe(870);
});
