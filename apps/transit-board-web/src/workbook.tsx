import { WorkbenchScope } from "./workbench-layout";
import { useEffect, useRef, useState } from "react";
import { Link, useBlocker } from "@tanstack/react-router";
import { describeReads } from "@transit/query-client/read";
import { ResultPanel, useStatement } from "./workbench-result";
import {
  Workbench,
  WorkbenchBody,
  NavigatorToggle,
  useInspector,
  InspectorPanel,
} from "./workbench-layout";
import { WorkbookOwner } from "./workbook-owner";
import { FeatureAccess } from "./feature-access";
import { useMetadata, Unavailable } from "./data-metadata";
import "./workbench.css";
type Cell = { id: string; name: string; sql: string; note: string };
const newCell = (): Cell => ({
  id: crypto.randomUUID().replaceAll("-", ""),
  name: "",
  sql: "SHOW TABLES",
  note: "",
});
export function WorkbookPage({ active = true }: { active?: boolean }) {
  return (
    <FeatureAccess feature="sql">
      <WorkbookPageContent active={active} />
    </FeatureAccess>
  );
}
function WorkbookPageContent({ active }: { active: boolean }) {
  const [cells, setCells] = useState<Cell[]>(() => [newCell()]);
  const [title, setTitle] = useState("Untitled investigation");
  const [open, setOpen] = useState(true);
  const [dirty, setDirty] = useState(false);
  const [cleanup, setCleanup] = useState("");
  const [connected, setConnected] = useState(false);
  const [visible, setVisible] = useState(!document.hidden);
  const [, render] = useState(0);
  const owner = useRef<WorkbookOwner | null>(null);
  const graph = (owner.current ??= new WorkbookOwner(
    () => render((value) => value + 1),
    () => {
      setCells((previous) => previous.map((cell) => ({ ...cell, name: "", sql: "", note: "" })));
      setTitle("");
    },
  ));
  useBlocker({ shouldBlockFn: () => false, enableBeforeUnload: dirty });
  const connection = useMetadata("sql", (signal) => describeReads(signal), active && open);
  useEffect(() => {
    if (connection.value) setConnected(true);
  }, [connection.value]);
  useEffect(() => {
    const visibility = () => setVisible(!document.hidden);
    document.addEventListener("visibilitychange", visibility);
    return () => document.removeEventListener("visibilitychange", visibility);
  }, []);
  useEffect(() => {
    graph.activity(active && visible && open && Boolean(connection.value));
  }, [graph, active, visible, open, connection.value]);
  const lifecycle = useRef(0);
  const currentCells = useRef(cells);
  currentCells.current = cells;
  useEffect(() => {
    const generation = ++lifecycle.current;
    const relations = currentCells.current
      .filter((cell) => cell.name.trim())
      .map(({ id, name, sql }) => ({ id, name, sql }));
    if (relations.length) graph.edit(relations, relations[0]!.id);
    return () => {
      queueMicrotask(() => {
        if (lifecycle.current === generation) void graph.dispose();
      });
    };
  }, [graph]);
  const replace = (next: Cell[], changed: string, computation = true) => {
    setCells(next);
    setDirty(true);
    if (computation)
      graph.edit(
        next.filter((cell) => cell.name.trim()).map(({ id, name, sql }) => ({ id, name, sql })),
        changed,
      );
  };
  const close = async () => {
    if (dirty && !window.confirm("Discard this unsaved workbook and close its results?")) return;
    setOpen(false);
    setDirty(false);
    setCells([]);
    await graph.dispose();
    setCleanup(graph.cleanup);
  };
  const restart = async () => {
    await graph.dispose();
    setCleanup(graph.cleanup);
    owner.current = null;
    // A new finite session is explicit; it does not enable Live or run SQL.
    render((value) => value + 1);
  };
  return (
    <Workbench className="workbook" available={active && Boolean(connection.value)}>
      <div className="page-heading">
        <div>
          <p className="eyebrow">
            WORKBOOK ·{" "}
            <span title="Drafts stay in this tab when changing activities. Close workbook or leave Board to discard them.">
              UNSAVED
            </span>
          </p>
          <h1>Workbook</h1>
          <p>Narrative, SQL and observed results in one place.</p>
        </div>
        <div className="workbench-toolbar">
          <NavigatorToggle label="Cells" />
          <Link to="/catalog">Browse catalog →</Link>
          {open && <button onClick={() => void close()}>Close workbook</button>}
        </div>
      </div>
      {cleanup && <p role="status">{cleanup}</p>}
      {!open ? (
        <div className="workbench-empty">
          <h2>Workbook closed</h2>
          <button
            onClick={() => {
              owner.current = null;
              setCells([newCell()]);
              setTitle("Untitled investigation");
              setOpen(true);
            }}
          >
            New workbook
          </button>
        </div>
      ) : (
        <>
          {!connection.value && <Unavailable error={connection.error} retry={connection.retry} />}
          {connected && (
            <div hidden={!connection.value}>
              <WorkbenchScope active={active && Boolean(connection.value)}>
                <strong>{connection.value?.database}</strong>
                <span>{connection.value?.source ?? "Configured SQL namespace"}</span>
                <span>Read-only statements</span>
                <span>Up to {connection.value?.window_rows} rows per window</span>
              </WorkbenchScope>
              <WorkbenchBody
                navigator={
                  active ? (
                    <>
                      <p className="eyebrow">THIS WORKBOOK</p>
                      <strong>{title}</strong>
                      {cells.map((cell, index) => (
                        <CellNavigation key={cell.id} cell={cell} index={index} />
                      ))}
                      <p>Unsaved · {cells.length} of 4 cells</p>
                    </>
                  ) : undefined
                }
              >
                <label className="workbook-title">
                  Investigation title
                  <input
                    value={title}
                    maxLength={160}
                    onChange={(event) => {
                      setTitle(event.target.value);
                      setDirty(true);
                    }}
                  />
                </label>
                <div className="workbook-evaluation" aria-label="Workbook evaluation">
                  <div>
                    <strong>
                      {graph.live ? "Live" : graph.remaining === 0 ? "Budget exhausted" : "Paused"}
                    </strong>
                    <span className="muted">
                      {graph.remaining} cell evaluations remaining · five-minute session
                    </span>
                  </div>
                  <button
                    disabled={
                      !cells.some((cell) => cell.name) || graph.unresolved || graph.remaining === 0
                    }
                    onClick={() => (graph.live ? graph.pause() : graph.enable())}
                  >
                    {graph.live ? "Pause" : "Enable Live"}
                  </button>
                  <button disabled={graph.busy} onClick={() => void restart()}>
                    New evaluation session
                  </button>
                </div>
                <p className="muted">
                  Name SELECT cells to compose relations. Reference an input as{" "}
                  <code>FROM "workbook.name"</code>. Live recalculates after a typing pause or blur;
                  notes do not run SQL.
                </p>
                {graph.validation?.issue && (
                  <p role="status" className="workbench-notice problem">
                    Draft blocked · {graph.validation.issue.code}
                    {graph.validation.issue.path.length > 0 &&
                      ` · ${graph.validation.issue.path.map((id) => cells.find((cell) => cell.id === id)?.name ?? id).join(" → ")}`}
                  </p>
                )}
                {graph.status?.failure && (
                  <p role="status" className="workbench-notice problem">
                    {cells.find((cell) => cell.id === graph.status?.failure?.cell)?.name ?? "Cell"}{" "}
                    · {graph.status.failure.code}. Dependents retain their earlier results.
                  </p>
                )}
                {graph.error && (
                  <p role="alert">
                    {graph.error}{" "}
                    <button disabled={graph.busy} onClick={() => void graph.refresh()}>
                      Check original evaluation
                    </button>
                  </p>
                )}
                {graph.busy && (
                  <p role="status">
                    {graph.unresolved ? "Evaluating the accepted draft…" : "Checking workbook…"}
                  </p>
                )}
                {cells.map((cell, index) => (
                  <WorkbookCell
                    key={cell.id}
                    cell={cell}
                    index={index}
                    graph={graph}
                    active={active && visible}
                    available={Boolean(connection.value)}
                    edit={(patch, computation) =>
                      replace(
                        cells.map((value) =>
                          value.id === cell.id ? { ...value, ...patch } : value,
                        ),
                        cell.id,
                        computation,
                      )
                    }
                    remove={() =>
                      replace(
                        cells.filter((value) => value.id !== cell.id),
                        cell.id,
                      )
                    }
                    move={(offset) => {
                      const next = [...cells];
                      [next[index], next[index + offset]] = [next[index + offset]!, next[index]!];
                      setCells(next);
                      setDirty(true);
                    }}
                    last={index === cells.length - 1}
                  />
                ))}
                <button
                  disabled={cells.length >= 4}
                  onClick={() => {
                    const cell = newCell();
                    replace([...cells, cell], cell.id);
                  }}
                >
                  Add SQL cell
                </button>
              </WorkbenchBody>
            </div>
          )}
        </>
      )}
    </Workbench>
  );
}
function CellNavigation({ cell, index }: { cell: Cell; index: number }) {
  const { fold } = useInspector();
  return (
    <button
      onClick={() => {
        fold("left");
        requestAnimationFrame(() =>
          document.getElementById(`cell-${cell.id}`)?.querySelector("textarea")?.focus(),
        );
      }}
    >
      Cell {index + 1}
      {cell.name && ` · ${cell.name}`}
    </button>
  );
}
function WorkbookCell({
  cell,
  index,
  graph,
  available,
  active,
  edit,
  remove,
  move,
  last,
}: {
  cell: Cell;
  index: number;
  graph: WorkbookOwner;
  available: boolean;
  active: boolean;
  last: boolean;
  edit: (patch: Partial<Cell>, computation: boolean) => void;
  remove: () => void;
  move: (offset: number) => void;
}) {
  const inspector = useInspector();
  const relation = Boolean(cell.name.trim());
  const statement = useStatement(
    () => edit({ sql: "", note: "" }, false),
    available && !relation,
    active,
  );
  const derived = graph.views.get(cell.id);
  const result = relation
    ? {
        view: available && active ? (derived?.view ?? null) : null,
        error: "",
        cleanup: "",
        busy: graph.busy,
        submitted: derived?.binding.sql ?? "",
        run: () => void graph.flush(cell.id),
        close: () => graph.hide(cell.id),
        next: () => void graph.next(cell.id),
        refresh: () => void graph.refresh(),
      }
    : statement;
  const run = () => {
    if (relation) void graph.flush(cell.id);
    else void statement.run(cell.sql);
  };
  const runBusy = relation ? graph.busy && !graph.validating : result.busy;
  const selection = `workbook/${cell.id}`;
  useEffect(() => () => inspector.release(selection), [inspector.release, selection]);
  const dependency = graph.validation?.bindings.find((binding) => binding.cell === cell.id)?.input;
  return (
    <section id={`cell-${cell.id}`} className="workbook-cell" aria-label={`SQL cell ${index + 1}`}>
      <div className="workbench-toolbar">
        <h2>Cell {index + 1}</h2>
        <span className="muted">
          {relation
            ? graph.current(cell.id)
              ? "Current draft"
              : derived
                ? "Earlier result"
                : "Draft"
            : "Standalone statement"}
        </span>
        <button
          aria-label={`Move cell ${index + 1} up`}
          disabled={index === 0}
          onClick={() => move(-1)}
        >
          ↑
        </button>
        <button aria-label={`Move cell ${index + 1} down`} disabled={last} onClick={() => move(1)}>
          ↓
        </button>
        <button
          onClick={(event) =>
            inspector.select(
              { owner: selection, kind: "cell", dimension: "definition" },
              event.currentTarget,
            )
          }
        >
          Inspect cell
        </button>
        <button onClick={remove}>Remove cell</button>
      </div>
      <label>
        Relation name
        <input
          value={cell.name}
          maxLength={40}
          placeholder="Optional · e.g. filtered"
          onChange={(event) => edit({ name: event.target.value }, true)}
          onBlur={() => void graph.flush()}
        />
      </label>
      <label>
        Investigation notes
        <textarea
          className="workbook-note"
          value={cell.note}
          maxLength={8000}
          placeholder="What are you investigating?"
          onChange={(event) => edit({ note: event.target.value }, false)}
        />
      </label>
      <label>
        SQL
        <textarea
          className="workbook-sql"
          spellCheck={false}
          value={cell.sql}
          maxLength={60000}
          onChange={(event) => edit({ sql: event.target.value }, relation)}
          onCompositionStart={() => graph.composition(true)}
          onCompositionEnd={() => graph.composition(false)}
          onBlur={() => {
            if (relation) void graph.flush();
          }}
          onKeyDown={(event) => {
            if (
              (event.ctrlKey || event.metaKey) &&
              event.key === "Enter" &&
              !event.nativeEvent.isComposing
            ) {
              event.preventDefault();
              if (!runBusy && cell.sql.trim()) run();
            }
          }}
        />
      </label>
      <div className="workbench-toolbar">
        <button className="primary" disabled={runBusy || !cell.sql.trim()} onClick={run}>
          Run cell {index + 1}
        </button>
        <span className="muted">
          Ctrl / ⌘ Enter ·{" "}
          {relation
            ? "SELECT · complete inputs, bounded evaluation"
            : "SELECT, SHOW, DESCRIBE, EXPLAIN"}
        </span>
      </div>
      {relation && derived && (
        <details className="workbench-evidence">
          <summary>Derivation and source basis</summary>
          <p>
            The source observation belongs to the original input. Cell evaluations do not form an
            atomic snapshot.
          </p>
          <pre>{JSON.stringify(derived.binding, null, 2)}</pre>
        </details>
      )}
      <ResultPanel
        state={result}
        draft={cell.sql}
        parent={`Cell ${index + 1}`}
        earlierResult={relation && Boolean(derived) && !graph.current(cell.id)}
        closeLabel={relation ? "Hide result" : "Close result"}
      />
      {available && active && (
        <InspectorPanel
          owner={selection}
          title={cell.name || `Cell ${index + 1}`}
          subtitle="WORKBOOK CELL"
          dimensions={[{ id: "definition", label: "Definition" }]}
        >
          <p>{relation ? "Temporary relation" : "Standalone statement"}</p>
          <p>
            {dependency
              ? `Input: ${graph.cells.find((value) => value.id === dependency)?.name ?? dependency}`
              : "Input: configured SQL source"}
          </p>
          <p>
            {relation && graph.current(cell.id)
              ? "Output matches the current draft and exact inputs."
              : "Edits are separate from completed results."}
          </p>
          <pre>{cell.sql}</pre>
          {derived && <p>Result {derived.binding.result}</p>}
        </InspectorPanel>
      )}
    </section>
  );
}
