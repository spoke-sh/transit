import { useEffect, useId, useRef, useState } from "react";
import {
  StatementReader,
  QueryError,
  logicalTypeText,
  unifiedCellText,
  type ResultView,
} from "@transit/query-client";
import { InspectorPanel, useInspector } from "./workbench-layout";
import { profileResult, states } from "./result-profile";

export function useStatement(onDenied?: () => void) {
  const reader = useRef<StatementReader | null>(null);
  const controller = useRef<AbortController | null>(null);
  const generation = useRef(0);
  const [view, setView] = useState<ResultView | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [submitted, setSubmitted] = useState("");
  const denial = useRef(onDenied);
  denial.current = onDenied;
  const fail = (cause: unknown) => {
    setView(null);
    setError(cause instanceof Error ? cause.message : "Result unavailable");
    if (cause instanceof QueryError && cause.status === 403) {
      denial.current?.();
      void reader.current?.close().catch(() => {});
      reader.current = null;
    }
  };
  async function load(kind: "refresh" | "next") {
    const current = reader.current;
    if (!current || controller.current) return;
    const abort = new AbortController();
    controller.current = abort;
    setBusy(true);
    try {
      const value = await current[kind](abort.signal);
      if (!abort.signal.aborted && reader.current === current && !document.hidden) {
        setView(value);
        setError("");
      }
    } catch (cause) {
      if (!abort.signal.aborted && reader.current === current) fail(cause);
    } finally {
      if (controller.current === abort) {
        controller.current = null;
        setBusy(false);
      }
    }
  }
  useEffect(() => {
    const timer = setInterval(() => {
      if (!document.hidden) void load("refresh");
    }, 5000);
    const visibility = () => {
      if (document.hidden) {
        controller.current?.abort();
        controller.current = null;
        setView(null);
        setBusy(false);
      } else void load("refresh");
    };
    document.addEventListener("visibilitychange", visibility);
    return () => {
      generation.current++;
      clearInterval(timer);
      document.removeEventListener("visibilitychange", visibility);
      controller.current?.abort();
      controller.current = null;
      void reader.current?.close().catch(() => {});
      reader.current = null;
    };
  }, []);
  async function run(sql: string, expected: string | null = null) {
    const ticket = ++generation.current;
    controller.current?.abort();
    controller.current = null;
    const previous = reader.current;
    reader.current = null;
    setView(null);
    setError("");
    setBusy(true);
    await previous?.close().catch(() => {});
    if (ticket !== generation.current) return;
    if (document.hidden) {
      setBusy(false);
      return;
    }
    const current = new StatementReader(sql, undefined, undefined, expected);
    reader.current = current;
    setSubmitted(sql);
    const abort = new AbortController();
    controller.current = abort;
    try {
      const value = await current.run(abort.signal);
      if (!abort.signal.aborted && reader.current === current && !document.hidden) setView(value);
    } catch (cause) {
      if (!abort.signal.aborted && reader.current === current) fail(cause);
    } finally {
      if (controller.current === abort) {
        controller.current = null;
        setBusy(false);
      }
    }
  }
  function close() {
    generation.current++;
    controller.current?.abort();
    controller.current = null;
    void reader.current?.close().catch(() => {});
    reader.current = null;
    setView(null);
    setBusy(false);
    setError("Result closed. Closing a view does not rerun its statement.");
  }
  return {
    view,
    error,
    busy,
    submitted,
    run,
    close,
    next: () => load("next"),
    refresh: () => load("refresh"),
  };
}

export function ResultPanel({
  state,
  draft,
  preview = false,
  parent,
}: {
  state: ReturnType<typeof useStatement>;
  draft?: string;
  preview?: boolean;
  parent: string;
}) {
  const owner = useId();
  const inspector = useInspector();
  const { release } = inspector;
  const view = state.view;
  const selected =
    inspector.selection?.owner === owner && inspector.selection.result === view?.result
      ? inspector.selection
      : null;
  const index = selected?.column ?? 0;
  const field = view?.columns[index];
  const profile =
    view && selected?.dimension === "profile" && field ? profileResult(view, index) : null;
  const earlier = draft !== undefined && state.submitted && draft !== state.submitted;
  // Replacing, hiding or removing the result must also clear its inspection.
  useEffect(() => () => release(owner), [release, owner, view?.result]);
  return (
    <section
      className="workbench-result"
      aria-label={preview ? "Dataset preview" : "Statement result"}
    >
      {earlier && (
        <p className="workbench-notice">
          Earlier result · The displayed result belongs to the submitted SQL. Your edited draft has
          not run.
        </p>
      )}
      {state.busy && <p role="status">Reading authorized results…</p>}
      {state.error && (
        <div role="alert" className="workbench-notice problem">
          <p>{state.error}</p>
          <button disabled={state.busy} onClick={() => void state.refresh()}>
            Check original result
          </button>
        </div>
      )}
      {view && (
        <>
          <div className="workbench-result-heading">
            <div>
              <strong>{preview ? "Preview rows" : "Result"}</strong>
              <ResultStatus view={view} />
            </div>
            <button
              disabled={!view.columns.length}
              aria-pressed={selected?.dimension === "profile"}
              onClick={(event) =>
                inspector.select(
                  {
                    owner,
                    kind: "column",
                    dimension: "profile",
                    result: view.result,
                    column: index,
                  },
                  event.currentTarget,
                )
              }
            >
              Column profile
            </button>
            <button
              aria-pressed={selected?.dimension === "evidence"}
              onClick={(event) =>
                inspector.select(
                  { owner, kind: "result", dimension: "evidence", result: view.result },
                  event.currentTarget,
                )
              }
            >
              Result evidence
            </button>
            {view.stopped !== "complete" && (
              <button disabled={state.busy} onClick={() => void state.next()}>
                Next window
              </button>
            )}
            <button onClick={state.close}>Close result</button>
          </div>
          {preview && (
            <p className="muted">
              Bounded preview · Dataset coverage unknown. This window is not a random sample or a
              whole-dataset profile.
            </p>
          )}

          <div
            className="workbench-grid"
            tabIndex={0}
            role="region"
            aria-label="Scrollable result table"
          >
            <table>
              <caption>
                Rows {view.rows.length ? (BigInt(view.start) + 1n).toString() : "0"}–
                {view.delivered} of this result
              </caption>
              <thead>
                <tr>
                  <th scope="col">Row</th>
                  {view.columns.map((field, i) => (
                    <th scope="col" key={i}>
                      <button
                        className="column-select"
                        aria-pressed={selected?.kind === "column" && index === i}
                        onClick={(event) =>
                          inspector.select(
                            {
                              owner,
                              kind: "column",
                              dimension: "profile",
                              result: view.result,
                              column: i,
                            },
                            event.currentTarget,
                          )
                        }
                      >
                        {field.name}
                        <small>{logicalTypeText(field.type)}</small>
                      </button>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {view.rows.map((row, i) => (
                  <tr key={`${view.start}/${i}`}>
                    <th scope="row">{(BigInt(view.start) + BigInt(i) + 1n).toString()}</th>
                    {row.map((cell, j) => (
                      <td key={j} data-cell-state={Object.keys(cell)[0]}>
                        <span>{unifiedCellText(cell, view.columns[j]?.type)}</span>
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
            {view.rows.length === 0 && (
              <p>
                {view.complete_rows === "0"
                  ? "No rows · verified empty result"
                  : "No rows in this window"}
              </p>
            )}
          </div>
          {selected && (
            <InspectorPanel
              owner={owner}
              title={selected.kind === "column" ? (field?.name ?? "Column") : "Result"}
              subtitle={selected.kind === "column" ? `Column / ${parent}` : `Result / ${parent}`}
              dimensions={
                selected.kind === "column"
                  ? [
                      { id: "profile", label: "Profile" },
                      { id: "definition", label: "Definition" },
                      { id: "evidence", label: "Evidence" },
                    ]
                  : [{ id: "evidence", label: "Evidence" }]
              }
              summary={
                <>
                  <ResultStatus view={view} />
                  <p>
                    Rows {view.rows.length ? (BigInt(view.start) + 1n).toString() : "0"}–
                    {view.delivered} ·{" "}
                    {view.observation_kind === "data"
                      ? "Source data; independent cuts"
                      : "Metadata; not a data snapshot"}
                  </p>
                  {earlier && (
                    <p className="workbench-notice">Earlier result · Edited draft has not run.</p>
                  )}
                </>
              }
            >
              {selected.dimension === "definition" && field && (
                <dl>
                  <div>
                    <dt>Logical type</dt>
                    <dd>{logicalTypeText(field.type)}</dd>
                  </div>
                  <div>
                    <dt>Column position</dt>
                    <dd>{index + 1}</dd>
                  </div>
                  <div>
                    <dt>Definition basis</dt>
                    <dd>
                      This result's logical schema. Physical codec and source collation are not
                      reported by this result.
                    </dd>
                  </div>
                </dl>
              )}
              {selected.dimension === "profile" && profile && (
                <div>
                  <p>Population: {view.rows.length} received rows in this window.</p>
                  <dl>
                    {states.map((name) => (
                      <div key={name}>
                        <dt>{name.replaceAll("_", " ")}</dt>
                        <dd>{profile.counts[name]}</dd>
                      </div>
                    ))}
                  </dl>
                  {profile.numeric ? (
                    <>
                      <h4>Typed-value distribution</h4>
                      <p>{profile.counts.value} values; other states excluded.</p>
                      {profile.histogram.map((count, i) => (
                        <label className="histogram-bin" key={i}>
                          Bin {i + 1}
                          <meter min={0} max={Math.max(1, profile.counts.value)} value={count}>
                            {count}
                          </meter>
                          <span>{count}</span>
                        </label>
                      ))}
                      <dl>
                        <div>
                          <dt>Minimum</dt>
                          <dd>{profile.minimum}</dd>
                        </div>
                        <div>
                          <dt>Maximum</dt>
                          <dd>{profile.maximum}</dd>
                        </div>
                        <div>
                          <dt>Distinct values</dt>
                          <dd>{profile.distinct}</dd>
                        </div>
                      </dl>
                    </>
                  ) : (
                    <p>
                      Distribution and ordering metrics are unavailable for this type. State counts
                      remain exact.
                    </p>
                  )}
                  <p>
                    Received window only · Dataset coverage unknown. This is not a random sample or
                    a whole-dataset profile.
                  </p>
                </div>
              )}
              {selected.dimension === "evidence" && (
                <div className="workbench-evidence">
                  <h4>Result basis and completion evidence</h4>
                  <dl>
                    <div>
                      <dt>Result</dt>
                      <dd>
                        <code>{view.result}</code>
                      </dd>
                    </div>
                    <div>
                      <dt>Observation</dt>
                      <dd>
                        {view.observation_kind === "data"
                          ? "Source data · independent cuts remain independent"
                          : "Metadata · not a data snapshot"}
                      </dd>
                    </div>
                    <div>
                      <dt>Received terminal count</dt>
                      <dd>{view.complete_rows ?? "Not received"}</dd>
                    </div>
                  </dl>
                  <pre>{view.observation}</pre>
                  <p>A displayed result grants neither continuing access nor durable retention.</p>
                </div>
              )}
            </InspectorPanel>
          )}
        </>
      )}
    </section>
  );
}

function ResultStatus({ view }: { view: ResultView }) {
  return (
    <p>
      {view.rows.length} displayed ·{" "}
      {view.complete_rows === null
        ? "Incomplete result"
        : `${view.complete_rows} result rows verified`}
      {view.stopped !== "complete" ? " · Display window reached" : " · End of result"}
    </p>
  );
}
