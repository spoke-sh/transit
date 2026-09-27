import { useCallback, useEffect, useRef, useState } from "react";
import {
  BoardError,
  unifiedQuery as query,
  unifiedCellText,
  type UnifiedQueryResponse,
} from "@rey/transit-board-client";

type Description = Extract<UnifiedQueryResponse, { description: unknown }>["description"];
type Compiled = Extract<UnifiedQueryResponse, { compiled: unknown }>["compiled"];
type Page = Extract<UnifiedQueryResponse, { page: unknown }>["page"];
type Status = Extract<UnifiedQueryResponse, { status: unknown }>["status"];
type Work = {
  namespace: string;
  bundle: string | null;
  input: number | null;
  pending: { token: string } | null;
  cursor: string | null;
};
const empty = (): Work => ({
  namespace: "",
  bundle: null,
  input: null,
  pending: null,
  cursor: null,
});
function freshNamespace() {
  const bytes = crypto.getRandomValues(new Uint32Array(2));
  return ((BigInt(bytes[0]!) << 32n) | BigInt(bytes[1]!) | 1n).toString();
}
function errorText(error: unknown) {
  if (!(error instanceof BoardError))
    return "Connection unavailable. Durable submission may be uncertain.";
  if (error.code === "UnsupportedQuery")
    return "Unsupported SQL for the displayed source capabilities.";
  if (error.code === "Forbidden") return "Query access denied. Protected workspace data cleared.";
  if (error.code === "StateResourceExpired" || error.code === "HistoryReclaimed")
    return "Source or result unavailable. Protected workspace data cleared.";
  if (error.code === "QueryExpired")
    return "The source observation changed. Retry the read without rerunning SQL.";
  return `Query unavailable (${error.code}).`;
}
export function UnifiedWorkspace({
  resource,
  mode,
  visible,
  onBack,
}: {
  resource: number;
  mode: "canvas" | "browse";
  visible: boolean;
  onBack: () => void;
}) {
  const [source, setSource] = useState<Description | null>(null);
  const [draft, setDraft] = useState("");
  const [runDraft, setRunDraft] = useState("");
  const [compiled, setCompiled] = useState<Compiled | null>(null);
  const [status, setStatus] = useState<Status>(null);
  const [page, setPage] = useState<Page | null>(null);
  const [error, setError] = useState("");
  const [authorized, setAuthorized] = useState(false);
  const [working, setWorking] = useState(false);
  const [revision, refresh] = useState(0);
  const [resume, setResume] = useState("");
  const [, render] = useState(0);
  const work = useRef<Work>(empty());
  const lock = useRef(false);
  const alive = useRef(true);
  const abort = useRef(new AbortController());
  const clear = useCallback(() => {
    work.current = empty();
    setSource(null);
    setDraft("");
    setRunDraft("");
    setCompiled(null);
    setStatus(null);
    setPage(null);
    setResume("");
    setAuthorized(false);
  }, []);
  const task = useCallback(
    async (operation: (signal: AbortSignal) => Promise<void>) => {
      if (lock.current) return;
      lock.current = true;
      setWorking(true);
      try {
        await operation(abort.current.signal);
      } catch (cause) {
        if (alive.current && !abort.current.signal.aborted) {
          setError(errorText(cause));
          setAuthorized(false);
          setPage(null);
          if (
            cause instanceof BoardError &&
            (cause.status === 403 || cause.status === 410 || cause.code === "HistoryReclaimed")
          )
            clear();
        }
      } finally {
        lock.current = false;
        if (alive.current) {
          setWorking(false);
          render((n) => n + 1);
        }
      }
    },
    [clear],
  );
  useEffect(() => {
    alive.current = true;
    abort.current = new AbortController();
    return () => {
      alive.current = false;
      abort.current.abort();
    };
  }, []);
  const dispatch = async (signal: AbortSignal) => {
    const pending = work.current.pending;
    if (!pending) return;
    const response = await query({ submit: pending }, signal);
    if (!("receipt" in response)) throw new BoardError(0, "InvalidResponse");
    if (signal.aborted) return;
    work.current.pending = null;
    work.current.input = response.receipt.position;
  };
  const advance = useCallback(async (signal: AbortSignal) => {
    const current = work.current;
    // Continue only a user-started finite upload. Reads never create a new query;
    // an unconfirmed signed request requires the visible explicit retry action.
    if (current.pending || !current.namespace) return;
    if (current.input !== null) {
      const response = await query({ observe: current.input }, signal);
      if (!("observation" in response)) throw new BoardError(0, "InvalidResponse");
      if ("pending" in response.observation) return;
      current.input = null;
      if ("rejected" in response.observation) {
        current.bundle = null;
        throw new BoardError(409, "QueryRejected");
      }
    }
    if (current.bundle !== null && !document.hidden) {
      const next = await query(
        { next: { namespace: current.namespace, bundle: current.bundle } },
        signal,
      );
      if (!("prepared" in next)) throw new BoardError(0, "InvalidResponse");
      if (signal.aborted) return;
      if (next.prepared === null) current.bundle = null;
      else {
        current.pending = next.prepared;
        render((n) => n + 1);
        if (document.hidden) return;
        await dispatch(signal);
      }
    }
  }, []);
  useEffect(() => {
    let disposed = false;
    let timer: ReturnType<typeof setTimeout>;
    const poll = async () => {
      if (disposed || document.hidden) return;
      await task(async (signal) => {
        const response = await query({ describe: {} }, signal);
        if (
          !("description" in response) ||
          response.description.source.source.resource !== resource
        )
          throw new BoardError(0, "InvalidResponse");
        if (disposed || signal.aborted) return;
        setSource(response.description);
        setDraft((text) => text || `SELECT * FROM ${response.description.name}`);
        await advance(signal);
        const current = work.current;
        if (current.namespace) {
          const observation = await query({ status: current.namespace }, signal);
          if (!("status" in observation)) throw new BoardError(0, "InvalidResponse");
          if (disposed || signal.aborted) return;
          setStatus(observation.status);
          if (observation.status?.phase === "denied") {
            clear();
            setError("Query denied. Workspace cleared.");
            return;
          }
          if (observation.status?.phase === "complete") {
            const result = await query(
              { page: { namespace: current.namespace, cursor: current.cursor } },
              signal,
            );
            if (!("page" in result)) throw new BoardError(0, "InvalidResponse");
            if (disposed || signal.aborted || document.hidden) return;
            setPage(result.page);
          } else setPage(null);
        }
        if (!document.hidden) setAuthorized(true);
        setError("");
      });
      if (!disposed)
        timer = setTimeout(
          () => void poll(),
          work.current.bundle || work.current.input !== null ? 500 : 5000,
        );
    };
    const visibility = () => {
      clearTimeout(timer);
      if (document.hidden) {
        setAuthorized(false);
        setPage(null);
      } else void poll();
    };
    void poll();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      disposed = true;
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [resource, revision, task, advance, clear]);
  const execute = () =>
    void task(async (signal) => {
      if (work.current.pending || work.current.input !== null || work.current.bundle) return;
      const response = await query({ compile: { sql: draft } }, signal);
      if (!("compiled" in response)) throw new BoardError(0, "InvalidResponse");
      if (signal.aborted) return;
      work.current = { ...empty(), namespace: freshNamespace(), bundle: response.compiled.bundle };
      setCompiled(response.compiled);
      setRunDraft(draft);
      setPage(null);
      setStatus(null);
      setError("");
      await advance(signal);
      refresh((n) => n + 1);
    });
  const control = (operation: "cancel" | "retire" | "collect") =>
    void task(async (signal) => {
      const current = work.current;
      if (!current.namespace || current.pending || current.input !== null) return;
      const response = await query(
        { prepare_control: { namespace: current.namespace, operation } },
        signal,
      );
      if (!("prepared" in response) || !response.prepared)
        throw new BoardError(0, "InvalidResponse");
      current.pending = response.prepared;
      current.bundle = null;
      await dispatch(signal);
      refresh((n) => n + 1);
    });
  const next = () =>
    void task(async (signal) => {
      if (!page?.evidence.next) return;
      const cursor = page.evidence.next;
      const response = await query({ page: { namespace: work.current.namespace, cursor } }, signal);
      if (!("page" in response)) throw new BoardError(0, "InvalidResponse");
      if (signal.aborted || document.hidden) return;
      work.current.cursor = cursor;
      setPage(response.page);
      setAuthorized(true);
    });
  const busy =
    working ||
    !!work.current.pending ||
    work.current.input !== null ||
    work.current.bundle !== null;
  const controlBusy = working || !!work.current.pending || work.current.input !== null;
  return (
    <section className="query-workspace" hidden={!visible} aria-label="Unified query workspace">
      <div className="atlas-toolbar">
        <button onClick={onBack}>← Neighborhood</button>
        <span>Resource {resource} · separate v2 query capability</span>
        <button disabled={working} onClick={() => refresh((n) => n + 1)}>
          Refresh query access
        </button>
      </div>
      <p role="status" className="query-status">
        {error ||
          (working
            ? "Checking current query evidence…"
            : status
              ? `Query ${work.current.namespace}: ${status.phase}`
              : "Run is explicit; switching views does not execute.")}
      </p>
      {work.current.pending && (
        <div className="uncertain">
          <strong>Submission not yet confirmed.</strong>
          <p>Keep this workspace open to retry the identical signed request.</p>
          <button
            disabled={working}
            onClick={() =>
              void task(async (signal) => {
                await dispatch(signal);
                refresh((n) => n + 1);
              })
            }
          >
            Retry exact submission
          </button>
        </div>
      )}
      {authorized && source && (
        <>
          <div className="query-source">
            <h2>
              {source.name} · {Object.keys(source.source.source.source)[0]}
            </h2>
            <p>
              Resource revision {source.source.resource_revision} · policy{" "}
              {source.source.policy_revision}
            </p>
            <p>
              Statement ≤ {source.sql.statement_bytes} bytes. Star or two named columns; one
              comparison or IS NULL; rows, count, checked int64 sum. Uint64/float64 comparison
              literals and writes are unsupported.
            </p>
            <p>
              Budgets: {source.budgets.pages} pages · {source.budgets.segments} segments ·{" "}
              {source.budgets.result_bytes} result bytes.
            </p>
            <ul>
              {source.columns.map((c) => (
                <li key={c.name}>
                  {c.name}: {c.type}
                </li>
              ))}
            </ul>
          </div>
          {mode === "canvas" && (
            <ol className="query-steps" aria-label="Query steps">
              <li>Declared {Object.keys(source.source.source.source)[0]} source</li>
              <li>Filter → limit → {compiled?.plan.aggregate ?? "rows"}</li>
              <li>Verified nested Arrow result</li>
            </ol>
          )}
          <div className="query-composer">
            <label htmlFor="unified-sql">SQL draft</label>
            <textarea
              id="unified-sql"
              value={draft}
              maxLength={4096}
              onChange={(e) => setDraft(e.target.value)}
            />
            <button disabled={busy || !draft.trim()} onClick={execute}>
              Run query
            </button>
            <button
              disabled={controlBusy || !work.current.namespace}
              onClick={() => control("cancel")}
            >
              Cancel query
            </button>
            <button
              disabled={busy || status?.phase !== "complete"}
              onClick={() => control("retire")}
            >
              Retire request
            </button>
            <button
              disabled={
                busy ||
                (status?.phase !== "retired" && status?.phase !== "cancelled") ||
                status?.collected
              }
              onClick={() => control("collect")}
            >
              Collect request
            </button>
          </div>
          <label htmlFor="unified-resume">Existing query namespace</label>
          <input id="unified-resume" value={resume} onChange={(e) => setResume(e.target.value)} />
          <button
            disabled={
              busy ||
              !/^[1-9][0-9]{0,19}$/.test(resume) ||
              BigInt(resume || "0") > 18446744073709551615n
            }
            onClick={() => {
              work.current = { ...empty(), namespace: resume };
              setPage(null);
              setCompiled(null);
              setRunDraft("");
              refresh((n) => n + 1);
            }}
          >
            Resume without rerunning
          </button>
          {runDraft && runDraft !== draft && (
            <p>Draft changed. The displayed result belongs to the earlier submitted SQL.</p>
          )}
          {page && (
            <div className="query-result" aria-label="Verified query result">
              <h3>Verified complete result · page {BigInt(page.evidence.ordinal) + 1n}</h3>
              <p>
                Source {page.evidence.manifest.basis.kind} · resource{" "}
                {page.evidence.manifest.basis.resource} · revision{" "}
                {page.evidence.manifest.basis.revision} · {page.evidence.manifest.rows} total rows.
              </p>
              <p>
                Contract{" "}
                {page.evidence.manifest.basis.contract
                  .map((b) => b.toString(16).padStart(2, "0"))
                  .join("")}{" "}
                · plan{" "}
                {page.evidence.manifest.plan.map((b) => b.toString(16).padStart(2, "0")).join("")}
              </p>
              <table>
                <thead>
                  <tr>
                    {page.evidence.columns.map((c) => (
                      <th key={c.name}>{c.name}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {page.cells.map((row, i) => (
                    <tr key={i}>
                      {row.map((cell, c) => (
                        <td key={c}>{unifiedCellText(cell)}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
              <button disabled={working || page.evidence.next === null} onClick={next}>
                Next result page
              </button>
              <p>
                {page.evidence.next === null
                  ? "Complete ordered coverage verified."
                  : "More verified segments remain."}
              </p>
            </div>
          )}
        </>
      )}
    </section>
  );
}
