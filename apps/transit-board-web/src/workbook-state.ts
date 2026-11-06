import type {
  WorkbookBinding,
  WorkbookCell,
  WorkbookValidation,
} from "@transit/query-client/workbook";

export type WorkbookIssue = NonNullable<WorkbookValidation["issue"]>;
export type WorkbookCellBinding = WorkbookBinding;

export type CellExecutionState =
  | "Draft"
  | "Invalid"
  | "Waiting"
  | "Queued"
  | "Running"
  | "Complete"
  | "Incomplete";

export type CellOutputFreshness = "none" | "current" | "earlier";

export type WorkbookPhase = "idle" | "debouncing" | "validating" | "evaluating";

export type WorkbookModelState = {
  active: boolean;
  live: boolean;
  composing: boolean;
  phase: WorkbookPhase;
  queued: boolean;
  generation: number;
  watermark: number;
  depUsesSource: boolean;
  issue: "none" | "invalid";
  sourceState: CellExecutionState;
  depState: CellExecutionState;
  sourceOut: CellOutputFreshness;
  depOut: CellOutputFreshness;
  failure: "none" | "denied" | "unavailable";
};

export type WorkbookModelEffects = {
  action: "none" | "schedule" | "validate" | "evaluate" | "close";
  cancel: boolean;
};

export type WorkbookModelEvent =
  | "EditSource"
  | "EditDep"
  | "ToggleDep"
  | "ComposeStart"
  | "ComposeEnd"
  | "EnableLive"
  | "PauseLive"
  | "QuietTick"
  | "Blur"
  | "Run"
  | "ValidateOk"
  | "ValidateInvalid"
  | "ValidateOld"
  | "EvalComplete"
  | "EvalBlocked"
  | "EvalOld"
  | "WatermarkAdvance"
  | "Deny"
  | "Lost"
  | "Hide"
  | "Show";

const IDLE_EFFECTS: WorkbookModelEffects = { action: "none", cancel: false };

const nextGen = (g: number): number => g + 1;
const nextWatermark = (w: number): number => w + 1;
const demote = (out: CellOutputFreshness): CellOutputFreshness =>
  out === "current" ? "earlier" : out;

function needsEval(state: WorkbookModelState): boolean {
  return state.sourceOut !== "current" || state.depOut !== "current" || state.issue !== "none";
}

function idleCellState(
  live: boolean,
  out: CellOutputFreshness,
  waitingOnInput: boolean,
  issue: "none" | "invalid",
): CellExecutionState {
  if (issue === "invalid") return "Invalid";
  if (out === "current") return "Complete";
  if (live || waitingOnInput) return "Waiting";
  return "Draft";
}

function startValidation(state: WorkbookModelState): WorkbookModelState {
  return {
    ...state,
    phase: "validating",
    queued: false,
    generation: nextGen(state.generation),
    failure: "none",
    sourceState: state.sourceOut === "current" ? "Complete" : "Queued",
    depState: state.depOut === "current" ? "Complete" : "Queued",
  };
}

export function initialWorkbookModel(): WorkbookModelState {
  return {
    active: true,
    live: false,
    composing: false,
    phase: "idle",
    queued: false,
    generation: 0,
    watermark: 1,
    depUsesSource: true,
    issue: "none",
    sourceState: "Draft",
    depState: "Waiting",
    sourceOut: "none",
    depOut: "none",
    failure: "none",
  };
}

export function workbookModelTransition(
  state: WorkbookModelState,
  event: WorkbookModelEvent,
): { state: WorkbookModelState; effects: WorkbookModelEffects } {
  const invalidateLineage = true;
  const enforceComposition = true;
  const compositionBlocked = enforceComposition && state.composing;
  const inFlight = state.phase === "validating" || state.phase === "evaluating";
  const wasBusy = state.phase !== "idle";

  switch (event) {
    case "EditSource": {
      const sOut = demote(state.sourceOut);
      const dOut = state.depUsesSource && invalidateLineage ? demote(state.depOut) : state.depOut;
      const canSchedule = state.active && state.live && !compositionBlocked;
      const nextPhase: WorkbookPhase = canSchedule ? "debouncing" : "idle";
      return {
        state: {
          ...state,
          issue: "none",
          failure: "none",
          queued: false,
          generation: inFlight ? nextGen(state.generation) : state.generation,
          phase: nextPhase,
          sourceOut: sOut,
          depOut: dOut,
          sourceState: idleCellState(state.live, sOut, false, "none"),
          depState: idleCellState(
            state.live,
            dOut,
            state.depUsesSource && sOut !== "current",
            "none",
          ),
        },
        effects: {
          action: canSchedule ? "schedule" : "none",
          cancel: wasBusy,
        },
      };
    }
    case "EditDep": {
      const dOut = demote(state.depOut);
      const canSchedule = state.active && state.live && !compositionBlocked;
      const nextPhase: WorkbookPhase = canSchedule ? "debouncing" : "idle";
      return {
        state: {
          ...state,
          issue: "none",
          failure: "none",
          queued: false,
          generation: inFlight ? nextGen(state.generation) : state.generation,
          phase: nextPhase,
          depOut: dOut,
          sourceState: idleCellState(state.live, state.sourceOut, false, "none"),
          depState: idleCellState(
            state.live,
            dOut,
            state.depUsesSource && state.sourceOut !== "current",
            "none",
          ),
        },
        effects: {
          action: canSchedule ? "schedule" : "none",
          cancel: wasBusy,
        },
      };
    }
    case "ToggleDep": {
      const nextDep = !state.depUsesSource;
      const dOut = demote(state.depOut);
      const canSchedule = state.active && state.live && !compositionBlocked;
      const nextPhase: WorkbookPhase = canSchedule ? "debouncing" : "idle";
      return {
        state: {
          ...state,
          depUsesSource: nextDep,
          issue: "none",
          failure: "none",
          queued: false,
          generation: inFlight ? nextGen(state.generation) : state.generation,
          phase: nextPhase,
          depOut: dOut,
          sourceState: idleCellState(state.live, state.sourceOut, false, "none"),
          depState: idleCellState(
            state.live,
            dOut,
            nextDep && state.sourceOut !== "current",
            "none",
          ),
        },
        effects: {
          action: canSchedule ? "schedule" : "none",
          cancel: wasBusy,
        },
      };
    }
    case "ComposeStart": {
      const stopDebounce = state.phase === "debouncing" && enforceComposition;
      return {
        state: {
          ...state,
          composing: true,
          phase: stopDebounce ? "idle" : state.phase,
        },
        effects: { action: "none", cancel: stopDebounce },
      };
    }
    case "ComposeEnd": {
      const canSchedule = state.active && state.live && needsEval(state) && state.phase === "idle";
      return {
        state: {
          ...state,
          composing: false,
          phase: canSchedule ? "debouncing" : state.phase,
        },
        effects: { action: canSchedule ? "schedule" : "none", cancel: false },
      };
    }
    case "EnableLive": {
      if (!state.active) return { state, effects: IDLE_EFFECTS };
      if (compositionBlocked || !needsEval(state))
        return { state: { ...state, live: true }, effects: IDLE_EFFECTS };
      if (inFlight) return { state: { ...state, live: true, queued: true }, effects: IDLE_EFFECTS };
      return {
        state: {
          ...state,
          live: true,
          phase: "debouncing",
          sourceState: state.sourceOut === "current" ? "Complete" : "Waiting",
          depState: state.depOut === "current" ? "Complete" : "Waiting",
        },
        effects: { action: "schedule", cancel: state.phase === "debouncing" },
      };
    }
    case "PauseLive":
      return {
        state: {
          ...state,
          live: false,
          phase: state.phase === "debouncing" ? "idle" : state.phase,
          sourceState: state.sourceState === "Waiting" ? "Draft" : state.sourceState,
          depState:
            state.depState === "Waiting" && !(state.depUsesSource && state.sourceOut !== "current")
              ? "Draft"
              : state.depState,
        },
        effects: { action: "none", cancel: state.phase === "debouncing" },
      };
    case "QuietTick":
      if (
        !state.active ||
        !state.live ||
        compositionBlocked ||
        state.phase !== "debouncing" ||
        !needsEval(state)
      )
        return { state, effects: IDLE_EFFECTS };
      return {
        state: startValidation(state),
        effects: { action: "validate", cancel: false },
      };
    case "Blur":
      if (!state.active || compositionBlocked || !needsEval(state) || inFlight)
        return { state, effects: IDLE_EFFECTS };
      return {
        state: startValidation(state),
        effects: { action: "validate", cancel: state.phase === "debouncing" },
      };
    case "Run": {
      if (!state.active || compositionBlocked) return { state, effects: IDLE_EFFECTS };
      if (inFlight) return { state: { ...state, queued: true }, effects: IDLE_EFFECTS };
      const forced: WorkbookModelState = {
        ...state,
        sourceOut: demote(state.sourceOut),
        depOut: demote(state.depOut),
      };
      return {
        state: { ...startValidation(forced), queued: true },
        effects: { action: "validate", cancel: state.phase === "debouncing" },
      };
    }
    case "ValidateOk":
      if (state.phase !== "validating") return { state, effects: IDLE_EFFECTS };
      if (state.live || state.queued)
        return {
          state: {
            ...state,
            phase: "evaluating",
            queued: false,
            issue: "none",
            sourceState: state.sourceOut === "current" ? "Complete" : "Running",
            depState: state.depOut === "current" ? "Complete" : "Running",
          },
          effects: { action: "evaluate", cancel: false },
        };
      return {
        state: {
          ...state,
          phase: "idle",
          issue: "none",
          sourceState: idleCellState(state.live, state.sourceOut, false, "none"),
          depState: idleCellState(
            state.live,
            state.depOut,
            state.depUsesSource && state.sourceOut !== "current",
            "none",
          ),
        },
        effects: IDLE_EFFECTS,
      };
    case "ValidateInvalid":
      if (state.phase !== "validating") return { state, effects: IDLE_EFFECTS };
      return {
        state: {
          ...state,
          phase: "idle",
          queued: false,
          issue: "invalid",
          sourceOut: demote(state.sourceOut),
          depOut: demote(state.depOut),
          sourceState: "Invalid",
          depState: state.depUsesSource ? "Incomplete" : "Invalid",
        },
        effects: IDLE_EFFECTS,
      };
    case "ValidateOld":
    case "EvalOld":
      return { state, effects: IDLE_EFFECTS };
    case "EvalComplete":
      if (state.phase !== "evaluating") return { state, effects: IDLE_EFFECTS };
      return {
        state: {
          ...state,
          phase: "idle",
          queued: false,
          issue: "none",
          failure: "none",
          sourceState: "Complete",
          depState: "Complete",
          sourceOut: "current",
          depOut: "current",
        },
        effects: IDLE_EFFECTS,
      };
    case "EvalBlocked":
      if (state.phase !== "evaluating") return { state, effects: IDLE_EFFECTS };
      return {
        state: {
          ...state,
          phase: "idle",
          queued: false,
          issue: "none",
          sourceOut: demote(state.sourceOut),
          depOut: state.depUsesSource ? demote(state.depOut) : "current",
          sourceState: "Incomplete",
          depState: state.depUsesSource ? "Incomplete" : "Complete",
        },
        effects: IDLE_EFFECTS,
      };
    case "WatermarkAdvance": {
      const sOut = invalidateLineage ? demote(state.sourceOut) : state.sourceOut;
      const dOut = invalidateLineage ? demote(state.depOut) : state.depOut;
      const canValidate = state.active && state.live && !compositionBlocked;
      const base: WorkbookModelState = {
        ...state,
        watermark: nextWatermark(state.watermark),
        generation: inFlight ? nextGen(state.generation) : state.generation,
        phase: "idle",
        queued: false,
        sourceOut: sOut,
        depOut: dOut,
        sourceState: idleCellState(state.live, sOut, false, state.issue),
        depState: idleCellState(
          state.live,
          dOut,
          state.depUsesSource && sOut !== "current",
          state.issue,
        ),
      };
      if (canValidate && state.issue === "none")
        return {
          state: startValidation(base),
          effects: { action: "validate", cancel: wasBusy },
        };
      return { state: base, effects: { action: "none", cancel: wasBusy } };
    }
    case "Deny":
      return {
        state: {
          ...state,
          live: false,
          composing: false,
          phase: "idle",
          queued: false,
          generation: nextGen(state.generation),
          failure: "denied",
          issue: "none",
          sourceOut: "none",
          depOut: "none",
          sourceState: "Draft",
          depState: state.depUsesSource ? "Waiting" : "Draft",
        },
        effects: { action: "close", cancel: true },
      };
    case "Lost":
      if (!inFlight) return { state, effects: IDLE_EFFECTS };
      return {
        state: {
          ...state,
          phase: "idle",
          queued: false,
          failure: "unavailable",
          sourceOut: demote(state.sourceOut),
          depOut: demote(state.depOut),
          sourceState: "Incomplete",
          depState: "Incomplete",
        },
        effects: IDLE_EFFECTS,
      };
    case "Hide":
      return {
        state: {
          ...state,
          active: false,
          live: false,
          composing: false,
          phase: "idle",
          queued: false,
          generation: nextGen(state.generation),
          sourceOut: "none",
          depOut: "none",
          sourceState: "Draft",
          depState: state.depUsesSource ? "Waiting" : "Draft",
        },
        effects: { action: "close", cancel: true },
      };
    case "Show":
      return state.active
        ? { state, effects: IDLE_EFFECTS }
        : { state: { ...state, active: true }, effects: IDLE_EFFECTS };
  }
}

export type CellProjection = {
  id: string;
  index: number;
  name: string;
  upstreamId: string | null;
  upstreamName: string | null;
  downstreamIds: string[];
  executionState: CellExecutionState;
  outputFreshness: CellOutputFreshness;
  badgeLabel: string;
  badgeTone: "complete" | "earlier" | "waiting" | "invalid" | "running" | "draft";
  issue: WorkbookIssue | null;
};

const WORKBOOK_REF_PATTERN =
  /(?:"workbook\.([A-Za-z_][A-Za-z0-9_]*)"|\bworkbook\.([A-Za-z_][A-Za-z0-9_]*)\b)/gi;

export function extractReferencedCellNames(sql: string): string[] {
  const names = new Set<string>();
  for (const match of sql.matchAll(WORKBOOK_REF_PATTERN)) {
    const name = match[1] ?? match[2];
    if (name) names.add(name);
  }
  return [...names];
}

export function projectWorkbookDag(
  cells: readonly WorkbookCell[],
  options: {
    live: boolean;
    phase: WorkbookPhase;
    validation: WorkbookValidation | null;
    results: readonly WorkbookCellBinding[];
    hasView: (cellId: string) => boolean;
    isCurrent: (cellId: string) => boolean;
    blockedCells?: ReadonlySet<string>;
  },
): {
  cells: Map<string, CellProjection>;
  chains: CellProjection[][];
  independent: CellProjection[];
} {
  const byName = new Map<string, WorkbookCell>();
  for (const cell of cells) {
    if (cell.name?.trim()) byName.set(cell.name.trim(), cell);
  }
  const validatedUpstream = new Map<string, string | null>();
  if (options.validation) {
    for (const binding of options.validation.bindings) {
      validatedUpstream.set(binding.cell, binding.input);
    }
  }
  const upstreamById = new Map<string, WorkbookCell | null>();
  const downstreamById = new Map<string, string[]>();
  for (const cell of cells) downstreamById.set(cell.id, []);

  for (const cell of cells) {
    const refs = extractReferencedCellNames(cell.sql);
    let upstream: WorkbookCell | null = null;
    if (refs.length > 0) {
      const target = byName.get(refs[0]!);
      if (target && target.id !== cell.id) upstream = target;
    } else if (validatedUpstream.has(cell.id)) {
      const validId = validatedUpstream.get(cell.id);
      if (validId) upstream = cells.find((c) => c.id === validId) ?? null;
    }
    upstreamById.set(cell.id, upstream);
    if (upstream) {
      downstreamById.get(upstream.id)?.push(cell.id);
    }
  }

  const issue = options.validation?.issue ?? null;
  const issueSet = new Set<string>(issue ? [issue.cell, ...issue.path] : []);
  const projections = new Map<string, CellProjection>();

  for (let idx = 0; idx < cells.length; idx++) {
    const cell = cells[idx]!;
    const upstream = upstreamById.get(cell.id) ?? null;
    const current = options.isCurrent(cell.id);
    const hasOutput = options.hasView(cell.id);
    const freshness: CellOutputFreshness = current ? "current" : hasOutput ? "earlier" : "none";
    const cellHasIssue = issue?.cell === cell.id || issueSet.has(cell.id);
    const upstreamProj = upstream ? projections.get(upstream.id) : null;
    const upstreamInvalidOrBlocked =
      upstreamProj !== null &&
      upstreamProj !== undefined &&
      (upstreamProj.executionState === "Invalid" || upstreamProj.executionState === "Incomplete");
    const upstreamNotCurrent = upstream !== null && !options.isCurrent(upstream.id);

    let executionState: CellExecutionState;
    if (cellHasIssue) {
      executionState = "Invalid";
    } else if (upstreamInvalidOrBlocked || options.blockedCells?.has(cell.id)) {
      executionState = "Incomplete";
    } else if (options.phase === "validating" && !current) {
      executionState = "Queued";
    } else if (options.phase === "evaluating" && !current) {
      executionState = "Running";
    } else if (current) {
      executionState = "Complete";
    } else if (options.live || upstreamNotCurrent) {
      executionState = "Waiting";
    } else {
      executionState = "Draft";
    }

    let badgeLabel: string;
    let badgeTone: CellProjection["badgeTone"];
    switch (executionState) {
      case "Complete":
        badgeLabel = "✓ Current draft";
        badgeTone = "complete";
        break;
      case "Invalid":
        badgeLabel = "Invalid draft";
        badgeTone = "invalid";
        break;
      case "Incomplete":
        badgeLabel = upstreamInvalidOrBlocked ? "Blocked by input" : "Incomplete result";
        badgeTone = "invalid";
        break;
      case "Running":
        badgeLabel = "Recalculating…";
        badgeTone = "running";
        break;
      case "Queued":
        badgeLabel = "Queued…";
        badgeTone = "running";
        break;
      case "Waiting":
        badgeLabel = upstreamNotCurrent
          ? `Waiting for ${upstream?.name || "input"}`
          : freshness === "earlier"
            ? "Earlier result · Recalculating"
            : "Waiting for evaluation";
        badgeTone = "waiting";
        break;
      case "Draft":
        badgeLabel = freshness === "earlier" ? "Earlier result" : "Draft";
        badgeTone = freshness === "earlier" ? "earlier" : "draft";
        break;
    }

    projections.set(cell.id, {
      id: cell.id,
      index: idx + 1,
      name: cell.name?.trim() || `cell_${idx + 1}`,
      upstreamId: upstream?.id ?? null,
      upstreamName: upstream?.name?.trim() || null,
      downstreamIds: downstreamById.get(cell.id) ?? [],
      executionState,
      outputFreshness: freshness,
      badgeLabel,
      badgeTone,
      issue: cellHasIssue ? issue : null,
    });
  }

  // Group into connected DAG chains vs independent cells for the D5 dependency bar
  const roots: CellProjection[] = [];
  const independent: CellProjection[] = [];
  for (const cell of cells) {
    const proj = projections.get(cell.id)!;
    if (!proj.upstreamId) {
      if (proj.downstreamIds.length > 0) roots.push(proj);
      else independent.push(proj);
    }
  }
  const chains: CellProjection[][] = [];
  for (const root of roots) {
    const chain: CellProjection[] = [root];
    let cursor: CellProjection | undefined = root;
    const visited = new Set<string>([root.id]);
    while (cursor && cursor.downstreamIds.length > 0) {
      const nextId = cursor.downstreamIds[0]!;
      if (visited.has(nextId)) break;
      visited.add(nextId);
      cursor = projections.get(nextId);
      if (cursor) chain.push(cursor);
    }
    chains.push(chain);
  }

  return { cells: projections, chains, independent };
}
