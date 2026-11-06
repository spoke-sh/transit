import { readFileSync } from "node:fs";
import { expect, test } from "vite-plus/test";
import {
  initialObservation,
  transition,
  type ObservationEvent,
  type ReadFailure,
} from "../../../apps/transit-board-web/src/observation";
import {
  initialStatement,
  statementTransition,
  type StatementEvent,
} from "../../../apps/transit-board-web/src/statement-state";
import { admitRequest } from "../../../apps/transit-board-web/src/request-scheduler";
import {
  initialPlane,
  planeLayout,
  planeTransition,
  type PlaneEvent,
} from "../../../apps/transit-board-web/src/plane-state";
import {
  initialWorkbookModel,
  workbookModelTransition,
  type WorkbookModelEvent,
} from "../../../apps/transit-board-web/src/workbook-state";

type Mode = "Observation" | "Statement" | "Scheduler" | "Plane" | "Workbook";
type Graph = {
  mode: Mode;
  nodes: Record<string, { expected: unknown; event: string }>;
  edges: [string, string][];
  initial: string;
};
const failure = (kind: ReadFailure["kind"]): ReadFailure => ({
  kind,
  code: kind,
  retryable: kind === "unavailable" || kind === "limited",
});
const initial = () => ({
  a: initialObservation<string>(),
  b: initialObservation<string>(),
  statement: initialStatement(),
  counts: { read: 0, control: 0 },
  plane: initialPlane(1440),
  workbook: initialWorkbookModel(),
  effects: {} as Record<string, unknown>,
});
type Machine = ReturnType<typeof initial>;
function start(mode: Mode) {
  const state = initial();
  state.effects =
    mode === "Observation"
      ? { cancel: false, read: false, delay: 0 }
      : mode === "Statement"
        ? { cancel: false, close: "none", action: "none" }
        : mode === "Workbook"
          ? { action: "none", cancel: false }
          : {};
  return state;
}
function project(mode: Mode, machine: Machine) {
  if (mode === "Observation") {
    const value = (state: Machine["a"]) => ({
      ...state,
      value: state.value !== null,
      failure: state.failure?.kind ?? "none",
    });
    return { a: value(machine.a), b: value(machine.b), effects: machine.effects };
  }
  if (mode === "Statement")
    return {
      state: {
        ...machine.statement,
        reader: machine.statement.reader ?? "none",
        failure: machine.statement.failure?.kind ?? "none",
      },
      effects: machine.effects,
    };
  if (mode === "Plane") {
    const layout = planeLayout(machine.plane);
    return {
      state: {
        ...machine.plane,
        leftOpen: layout.left,
        rightOpen: layout.right,
        takeover: layout.takeover ?? "none",
      },
    };
  }
  if (mode === "Workbook") {
    return {
      state: machine.workbook,
      effects: machine.effects,
    };
  }
  return { state: machine.counts };
}
function step(mode: Mode, machine: Machine, name: string): Machine {
  if (mode === "Observation") {
    const owner = name[0] === "A" ? "a" : name[0] === "B" ? "b" : null;
    if (!owner) throw new Error(`Unknown observation owner: ${name}`);
    const event = name.slice(1),
      state = machine[owner];
    let input: ObservationEvent<string>;
    if (["Read", "Hide", "Show", "Dispose"].includes(event))
      input = { type: event.toLowerCase() as "read" | "hide" | "show" | "dispose" };
    else if (["Receive", "Old", "Future"].includes(event))
      input = {
        type: "received",
        generation: state.generation + (event === "Old" ? -1 : event === "Future" ? 1 : 0),
        value: "protected",
      };
    else {
      const kinds: Record<string, ReadFailure["kind"]> = {
        Deny: "denied",
        Lost: "unavailable",
        Limited: "limited",
        Disabled: "unconfigured",
        Expired: "expired",
        Incompatible: "incompatible",
      };
      const kind = kinds[event];
      if (!kind) throw new Error(`Unknown observation event: ${event}`);
      input = { type: "failed", generation: state.generation, failure: failure(kind) };
    }
    const next = transition(state, input);
    for (const effect of next.effects)
      if (effect.type === "read") expect(effect.generation).toBe(next.state.generation);
    return {
      ...machine,
      [owner]: next.state,
      effects: {
        cancel: next.effects.some((e) => e.type === "cancel"),
        read: next.effects.some((e) => e.type === "read"),
        delay: next.effects.find((e) => e.type === "schedule")?.delay ?? 0,
      },
    };
  }
  if (mode === "Statement") {
    const state = machine.statement;
    let event: StatementEvent;
    if (["RunA", "RunB"].includes(name))
      event = { type: "run", reader: name === "RunA" ? "a" : "b" };
    else if (["Hide", "Show", "Disable", "Enable"].includes(name))
      event = {
        type: name === "Hide" || name === "Show" ? "visibility" : "availability",
        value: name === "Show" || name === "Enable",
      };
    else if (["Observe", "Next", "Close", "Dispose"].includes(name))
      event = { type: name.toLowerCase() as "observe" | "next" | "close" | "dispose" };
    else if (["Receive", "Old", "Foreign"].includes(name))
      event = {
        type: "received",
        reader: name === "Foreign" ? "foreign" : (state.reader ?? "none"),
        generation: state.generation - (name === "Old" ? 1 : 0),
      };
    else if (["Deny", "Lost"].includes(name))
      event = {
        type: "failed",
        reader: state.reader ?? "none",
        generation: state.generation,
        failure: failure(name === "Deny" ? "denied" : "unavailable"),
      };
    else throw new Error(`Unknown statement event: ${name}`);
    const next = statementTransition(state, event);
    for (const effect of next.effects)
      if ("generation" in effect) {
        expect(effect.generation).toBe(next.state.generation);
        expect(effect.reader).toBe(next.state.reader);
      }
    return {
      ...machine,
      statement: next.state,
      effects: {
        cancel: next.effects.some((e) => e.type === "cancel"),
        close: next.effects.find((e) => e.type === "close")?.reader ?? "none",
        action:
          next.effects.find((e) => ["run", "observe", "next"].includes(e.type))?.type ?? "none",
      },
    };
  }
  if (mode === "Plane") {
    const planeEvents: Record<string, PlaneEvent> = {
      OpenLeft: { type: "open", side: "left" },
      OpenRight: { type: "open", side: "right" },
      FoldLeft: { type: "fold", side: "left" },
      FoldRight: { type: "fold", side: "right" },
      ToggleLeft: { type: "toggle", side: "left" },
      ToggleRight: { type: "toggle", side: "right" },
      TabInspector: { type: "tab", tab: "inspector" },
      TabAssistant: { type: "tab", tab: "assistant" },
      Detail: { type: "detail" },
      ResizeWide: { type: "resize", width: 1440 },
      ResizeMedium: { type: "resize", width: 1000 },
      ResizeNarrow: { type: "resize", width: 390 },
    };
    const event = planeEvents[name];
    if (!event) throw new Error(`Unknown plane event: ${name}`);
    return {
      ...machine,
      plane: planeTransition(machine.plane, event),
    };
  }
  if (mode === "Workbook") {
    const next = workbookModelTransition(machine.workbook, name as WorkbookModelEvent);
    return {
      ...machine,
      workbook: next.state,
      effects: next.effects,
    };
  }
  if (!["ReadStart", "ReadFinish", "ControlStart", "ControlFinish"].includes(name))
    throw new Error(`Unknown scheduling event: ${name}`);
  return {
    ...machine,
    counts: admitRequest(
      machine.counts,
      name.startsWith("Read") ? "read" : "control",
      name.endsWith("Start") ? "start" : "finish",
    ),
  };
}

function matchesExpected(actual: Record<string, unknown>, expected: Record<string, unknown>): boolean {
  for (const key of Object.keys(expected)) {
    const a = actual[key] as Record<string, unknown> | undefined;
    const b = expected[key] as Record<string, unknown> | undefined;
    if (!a || !b) return false;
    for (const field of Object.keys(b)) {
      if (a[field] !== b[field]) return false;
    }
  }
  return true;
}

test("every exported finite edge matches the production state/effect owner", () => {
  const path = process.env.BOARD_MODEL_ARTIFACT;
  if (!path) throw new Error("Run through test::board-model with completed TLC graphs");
  const artifact = JSON.parse(readFileSync(path, "utf8")) as {
    graphs: Graph[];
    controls: { mode: Mode; events: string[]; bad: unknown }[];
  };
  expect(artifact.graphs.map((g) => g.mode)).toEqual([
    "Observation",
    "Statement",
    "Scheduler",
    "Plane",
    "Workbook",
  ]);
  for (const graph of artifact.graphs) {
    const adjacency = new Map<string, string[]>();
    for (const [from, to] of graph.edges) {
      if (!graph.nodes[from] || !graph.nodes[to]) throw new Error("Unknown edge endpoint");
      let list = adjacency.get(from);
      if (!list) {
        list = [];
        adjacency.set(from, list);
      }
      list.push(to);
    }
    const reached = new Map<string, Machine>([[graph.initial, start(graph.mode)]]);
    const pending = [graph.initial];
    expect(project(graph.mode, reached.get(graph.initial)!)).toEqual(
      graph.nodes[graph.initial]!.expected,
    );
    let edges = 0;
    for (let index = 0; index < pending.length; index++) {
      const from = pending[index]!,
        before = reached.get(from)!;
      for (const to of adjacency.get(from) ?? []) {
        const node = graph.nodes[to]!;
        const after = step(graph.mode, before, node.event);
        const projected = project(graph.mode, after) as Record<string, unknown>;
        if (!matchesExpected(projected, node.expected as Record<string, unknown>)) {
          expect(projected, `BOARD_MODEL_DIVERGENCE ${graph.mode} ${node.event}`).toEqual(
            node.expected,
          );
        }
        if (!reached.has(to)) {
          reached.set(to, after);
          pending.push(to);
        }
        edges++;
      }
    }
    expect(reached.size).toBe(Object.keys(graph.nodes).length);
    expect(edges).toBe(graph.edges.length);
  }
  for (const control of artifact.controls) {
    let state = start(control.mode);
    for (const event of control.events) state = step(control.mode, state, event);
    expect(project(control.mode, state)).not.toEqual(control.bad);
  }
});
