import { useCallback, useEffect, useRef, useState } from "react";
import { BoardError, query, type QueryResponse } from "@rey/transit-board-client";
import { acquireCaller } from "@rey/transit-reactive-client";
import {
  tableContract,
  tablePage,
  mismatch,
  type QueryBinding,
  type TableContract,
} from "./binding";

type Source = Extract<QueryResponse, { source: unknown }>["source"];
type Compiled = Extract<QueryResponse, { prepared: unknown }>["prepared"];
type Status = Extract<QueryResponse, { status: unknown }>["status"];
type Page = Extract<QueryResponse, { page: unknown }>["page"];
type Cell = NonNullable<NonNullable<Page["rows"][number]>[number]>;
type Pending = { kind: "start" | "cancel"; frozen: { token: string } };
// Frozen admissions and sequence ownership survive disposable routes/generations.
const retained = {
  draft: "",
  draftBinding: "",
  runDraft: "",
  pending: null as Pending | null,
  correlation: null as number | null,
  lock: { current: false },
  release: null as (() => void) | null,
};
export function cellText(cell: Cell): string {
  if ("null" in cell) return "NULL";
  if ("int64" in cell) return cell.int64;
  if ("boolean" in cell) return cell.boolean ? "true" : "false";
  if ("binary" in cell) return `0x${cell.binary}`;
  return cell.utf8 === "" ? '""' : cell.utf8;
}
function name(value: Source["schema"]["names"][number]) {
  return String.fromCharCode(...value.bytes.slice(0, value.len));
}
function queryError(cause: unknown): string {
  if (!(cause instanceof BoardError))
    return "Connection unavailable. No durable outcome was confirmed.";
  switch (cause.code) {
    case "BindingChanged":
      return "Declared source contract changed. Prior accepted work remains recoverable; its results are not shown in this binding.";
    case "Forbidden":
      return "Query access denied. Protected workspace data has been cleared.";
    case "StateResourceExpired":
      return "The source or result is unavailable or expired. Workspace data has been cleared.";
    case "QueryBusy":
      return "This query principal already has active work. Wait for completion or cancel it explicitly.";
    case "UnsupportedQuery":
      return "Unsupported SQL. Use the qualified single-Table SELECT subset.";
    case "QueryRequestTooLarge":
      return "The compiled predicate exceeds the public request budget. Shorten the literal.";
    case "QueryExpired":
      return "The observation changed. Retry the read; the query has not been rerun.";
    case "QueryConflict":
      return "Submission identity conflict. Do not rerun SQL to replace an uncertain operation.";
    case "IncompleteResult":
      return "The result is incomplete. Rows require a verified complete manifest.";
    default:
      return `Query observation unavailable (${cause.code}).`;
  }
}
export function QueryWorkspace({
  resource,
  mode,
  visible,
  onBack,
  binding,
}: {
  resource: number;
  binding?: QueryBinding;
  mode: "canvas" | "browse";
  visible: boolean;
  onBack: () => void;
}) {
  const [source, setSource] = useState<Source | null>(null);
  const draftBinding = binding ? JSON.stringify(binding) : `resource/${resource}`;
  const [draft, updateDraft] = useState(() => {
    if (retained.draftBinding !== draftBinding) {
      retained.draft = binding?.sql ?? "";
      retained.draftBinding = draftBinding;
    }
    return retained.draft;
  });
  const setDraft = (value: string | ((previous: string) => string)) => {
    const next = typeof value === "function" ? value(retained.draft) : value;
    retained.draft = next;
    updateDraft(next);
  };
  const [runDraft, updateRunDraft] = useState(retained.runDraft);
  const setRunDraft = (value: string) => {
    retained.runDraft = value;
    updateRunDraft(value);
  };
  const [compiled, setCompiled] = useState<Compiled | null>(null);
  const [pending, updatePending] = useState(retained.pending);
  const setPending = (value: Pending | null) => {
    retained.pending = value;
    updatePending(value);
  };
  const [correlation, updateCorrelation] = useState(retained.correlation);
  const setCorrelation = (value: number | null) => {
    retained.correlation = value;
    updateCorrelation(value);
  };
  const [status, setStatus] = useState<Status | null>(null);
  const [page, setPage] = useState<Page | null>(null);
  const [error, setError] = useState("");
  const [working, setWorking] = useState(false);
  const [authorized, setAuthorized] = useState(false);
  const [refresh, setRefresh] = useState(0);
  const lock = retained.lock;
  const bound = useRef<TableContract | null>(null);
  const alive = useRef(true);
  const controller = useRef(new AbortController());
  const selection = useRef<number | null>(retained.correlation);
  const selectedPage = useRef<number | null>(null);
  const protectedClear = useCallback(() => {
    setSource(null);
    setDraft("");
    setRunDraft("");
    setCompiled(null);
    // Current denial clears presentation, never the frozen admission.
    bound.current = null;
    selection.current = null;
    setStatus(null);
    setPage(null);
    selectedPage.current = null;
    setAuthorized(false);
  }, []);
  const fail = useCallback(
    (cause: unknown) => {
      setError(queryError(cause));
      if (cause instanceof BoardError && (cause.status === 403 || cause.status === 410))
        protectedClear();
      else setAuthorized(false);
    },
    [protectedClear],
  );
  const runTask = useCallback(
    async (task: (signal: AbortSignal) => Promise<void>) => {
      if (lock.current) return;
      lock.current = true;
      setWorking(true);
      try {
        await task(controller.current.signal);
      } catch (cause) {
        if (alive.current && !controller.current.signal.aborted) fail(cause);
      } finally {
        if (!retained.pending) {
          retained.release?.();
          retained.release = null;
        }
        lock.current = false;
        if (alive.current) setWorking(false);
      }
    },
    [fail],
  );
  useEffect(() => {
    alive.current = true;
    controller.current = new AbortController();
    return () => {
      alive.current = false;
      controller.current.abort();
    };
  }, []);
  useEffect(() => {
    let disposed = false;
    let timer: ReturnType<typeof setTimeout>;
    const poll = async () => {
      if (disposed || document.hidden) return;
      await runTask(async (signal) => {
        const response = await query({ describe: {} }, signal);
        if (!("source" in response) || response.source.connection.resource !== resource)
          throw new BoardError(0, "InvalidResponse");
        if (disposed || signal.aborted) return;
        if (binding) {
          const contract = await query({ contract: {} }, signal);
          if (!("contract" in contract)) throw new BoardError(0, "InvalidResponse");
          tableContract(binding, contract.contract);
          bound.current = contract.contract;
        }
        if (disposed || signal.aborted || document.hidden) return;
        setSource(response.source);
        setDraft((value) => value || `SELECT * FROM ${response.source.connection.name}`);
        const current = selection.current;
        if (current !== null) {
          const observation = await query({ status: { correlation: current } }, signal);
          if (!("status" in observation)) throw new BoardError(0, "InvalidResponse");
          if (disposed || signal.aborted) return;
          setStatus(observation.status);
          if (["denied", "expired"].includes(observation.status.phase)) {
            protectedClear();
            setError(`Query ${observation.status.phase}. Workspace cleared.`);
            return;
          }
          if (observation.status.phase === "complete" && selectedPage.current === null) {
            const result = await query({ page: { correlation: current, ordinal: 0 } }, signal);
            if (!("page" in result)) throw new BoardError(0, "InvalidResponse");
            if (disposed || signal.aborted) return;
            if (binding) {
              if (!bound.current) mismatch();
              tablePage(bound.current, result.page);
            }
            setPage(result.page);
            selectedPage.current = 0;
          }
        }
        setAuthorized(true);
        setError("");
      });
      if (!disposed) timer = setTimeout(() => void poll(), 5000);
    };
    const visibility = () => {
      clearTimeout(timer);
      if (document.hidden) {
        setAuthorized(false);
        setPage(null);
        selectedPage.current = null;
      } else void poll();
    };
    void poll();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      disposed = true;
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [resource, refresh, runTask, protectedClear, binding]);
  const caller = async (signal: AbortSignal) => {
    if (retained.release) return;
    const response = await query({ describe: {} }, signal);
    if (!("source" in response)) throw new BoardError(0, "InvalidResponse");
    retained.release = await acquireCaller(response.source.connection, signal);
  };
  const dispatch = async (value: Pending, signal: AbortSignal) => {
    await caller(signal);
    const response = await query(
      value.kind === "start" ? { submit: value.frozen } : { cancel: value.frozen },
      signal,
    );
    if (!("receipt" in response)) throw new BoardError(0, "InvalidResponse");
    if (signal.aborted || !alive.current) return;
    setPending(null);
    setError("");
    if (value.kind === "start") {
      selection.current = response.receipt.position;
      setCorrelation(response.receipt.position);
      setPage(null);
      selectedPage.current = null;
      setStatus({
        version: 1,
        correlation: response.receipt.position,
        phase: "submitted",
        result: null,
        received_segments: 0,
        received_rows: 0,
        manifest: null,
      });
    } else setError("Cancellation submitted. The durable outcome will be observed separately.");
    setRefresh((value) => value + 1);
  };
  const execute = () =>
    void runTask(async (signal) => {
      if (pending) throw new BoardError(409, "QueryConflict");
      await caller(signal);
      const response = await query({ prepare: { sql: draft } }, signal);
      if (!("prepared" in response)) throw new BoardError(0, "InvalidResponse");
      if (signal.aborted || !alive.current) return;
      if (binding) {
        const contract = await query({ contract: {} }, signal);
        if (!("contract" in contract)) throw new BoardError(0, "InvalidResponse");
        tableContract(binding, contract.contract);
        if (
          response.prepared.source.connection.table !== contract.contract.source.connection.table ||
          JSON.stringify(response.prepared.source.schema) !==
            JSON.stringify(contract.contract.source.schema)
        )
          mismatch();
        bound.current = contract.contract;
      }
      if (signal.aborted || !alive.current) return;
      setCompiled(response.prepared);
      setRunDraft(draft);
      const frozen: Pending = { kind: "start", frozen: response.prepared.frozen };
      setPending(frozen);
      await dispatch(frozen, signal);
    });
  const cancel = () =>
    void runTask(async (signal) => {
      if (correlation === null || pending) return;
      await caller(signal);
      const response = await query({ prepare_cancel: { correlation } }, signal);
      if (!("cancellation" in response)) throw new BoardError(0, "InvalidResponse");
      if (signal.aborted || !alive.current) return;
      const frozen: Pending = { kind: "cancel", frozen: response.cancellation };
      setPending(frozen);
      await dispatch(frozen, signal);
    });
  const next = () =>
    void runTask(async (signal) => {
      if (correlation === null || page?.next === null || page?.next === undefined) return;
      const response = await query({ page: { correlation, ordinal: page.next } }, signal);
      if (!("page" in response)) throw new BoardError(0, "InvalidResponse");
      if (signal.aborted || !alive.current) return;
      if (binding) {
        if (!bound.current) mismatch();
        tablePage(bound.current, response.page);
      }
      setPage(response.page);
      selectedPage.current = response.page.ordinal;
      setAuthorized(true);
      setError("");
    });
  const columns = page?.columns.filter((value) => value !== null) ?? [];
  const rows = page?.rows.filter((value) => value !== null) ?? [];
  return (
    <section className="query-workspace" hidden={!visible} aria-label="Table query workspace">
      <div className="atlas-toolbar">
        <button onClick={onBack}>← Neighborhood</button>
        <span>Resource {resource} · separate query capability</span>
        <button disabled={working} onClick={() => setRefresh(refresh + 1)}>
          Refresh query access
        </button>
      </div>
      <p role="status" className="query-status">
        {error ||
          (working
            ? "Checking current query evidence…"
            : status
              ? `Query ${status.correlation}: ${status.phase}`
              : source
                ? "Ready. Run is explicit; switching views does not execute."
                : "Checking query access…")}
      </p>
      {pending && (
        <div className="uncertain">
          <strong>Submission not yet confirmed.</strong>
          <p>The identical signed request is retained across Board navigation in this tab.</p>
          <button
            disabled={working}
            onClick={() => void runTask((signal) => dispatch(pending, signal))}
          >
            Retry exact submission
          </button>
        </div>
      )}
      {source && (
        <div className={`worksheet ${mode}`}>
          <aside className="source-card">
            <p className="eyebrow">DECLARED TABLE / SOURCE</p>
            <h2>{source.connection.name}</h2>
            <p>
              Resource {source.connection.resource} · schema entry revision{" "}
              {source.descriptor_revision}
            </p>
            <ul>
              {source.schema.names.map((column, index) => (
                <li key={index}>
                  <strong>{name(column)}</strong>{" "}
                  <span>
                    {index === 0 ? "int64 key" : `${source.schema.value_type} · nullable`}
                  </span>
                </li>
              ))}
            </ul>
            <p className="muted">
              Current resource revision {source.resource_revision}. Execution captures its own exact
              source basis.
            </p>
          </aside>
          <div className="query-composer">
            <label htmlFor="query-sql">SQL draft</label>
            <textarea
              id="query-sql"
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              rows={6}
              spellCheck={false}
              maxLength={4096}
              placeholder={`SELECT * FROM ${source.connection.name}`}
            />
            <p className="muted">
              Single Table SELECT · columns, one predicate, COUNT or SUM · no writes, joins or
              export
            </p>
            <div className="atlas-toolbar">
              <button
                className="primary"
                disabled={working || !authorized || pending !== null || !draft.trim()}
                onClick={execute}
              >
                Run query
              </button>
              <button
                disabled={
                  working ||
                  pending !== null ||
                  correlation === null ||
                  status?.phase === "complete" ||
                  status?.phase === "cancelled"
                }
                onClick={cancel}
              >
                Cancel query
              </button>
            </div>
            {runDraft && draft !== runDraft && (
              <p className="draft-changed">
                Draft changed. The result still belongs to the last submitted SQL.
              </p>
            )}
            {compiled && (
              <ol className="query-steps" aria-label="Compiled query steps">
                <li>Read {compiled.source.connection.name}</li>
                {compiled.explanation.filter && <li>Apply typed predicate</li>}
                <li>
                  {compiled.explanation.aggregate === "rows"
                    ? "Project declared columns"
                    : compiled.explanation.aggregate.toUpperCase()}
                </li>
                <li>
                  {compiled.explanation.limit === null
                    ? "All selected rows, delivered in bounded segments"
                    : `Input limit ${compiled.explanation.limit}`}
                </li>
              </ol>
            )}
          </div>
        </div>
      )}
      {status && (
        <p className="result-evidence">
          {status.phase === "complete" && status.manifest
            ? `Complete manifest · result ${status.manifest.result} · ${status.manifest.rows} rows · ${status.manifest.segments} segments · source revision ${status.manifest.basis.revision}`
            : `${status.phase} · ${status.received_segments} received segments · ${status.received_rows} received rows · no complete result yet`}
        </p>
      )}
      {page && authorized && (
        <div className="query-result" aria-label="Verified query result">
          <div className="atlas-toolbar">
            <h2>
              Result · segment {page.ordinal + 1} of {page.manifest.segments}
            </h2>
            <button disabled={working || page.next === null} onClick={next}>
              Next result segment
            </button>
          </div>
          {mode === "browse" ? (
            <table>
              <thead>
                <tr>
                  {columns.map((column) => (
                    <th key={column.name}>
                      {column.name} <small>{column.type}</small>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((row, index) => (
                  <tr key={index}>
                    {row.map(
                      (cell, column) => cell !== null && <td key={column}>{cellText(cell)}</td>,
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <div className="result-tiles">
              {rows.map((row, index) => (
                <article key={index} className="result-tile">
                  {row.map(
                    (cell, column) =>
                      cell !== null && (
                        <div key={column}>
                          <small>{columns[column]?.name}</small>
                          <strong>{cellText(cell)}</strong>
                        </div>
                      ),
                  )}
                </article>
              ))}
            </div>
          )}
          {page.count === 0 && <p>No rows in this verified segment.</p>}
          <p className="muted">
            This page belongs to one verified complete result. No offline cache or retention pin is
            created.
          </p>
        </div>
      )}
    </section>
  );
}
