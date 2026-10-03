import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from "react";
import {
  BoardError,
  unifiedQuery as query,
  unifiedCellText,
  type UnifiedQueryResponse,
} from "@rey/transit-board-client";

import { acquireCaller } from "@rey/transit-reactive-client";
import { QueryRecovery, saveQueryReference, terminalQuery } from "./query-recovery";
import { verifiedPage } from "./unified-result";
import { liveQuery, liveDraft, querySession, selectLiveTemplate } from "./query-live";
import { QueryCandidates } from "./query-candidates";
import { SqlEditor } from "./sql-editor";
import type { Diagnostic } from "@rey/transit-query-client";
import { QueryDiagnostic } from "./query-diagnostic";
import { QueryProfile } from "./query-profile";
import { QueryInspection, type Inspection } from "./query-inspection";
import { DraftControls } from "./draft-controls";
import { useScope } from "./state";
import { unifiedContract, unifiedPage, mismatch, type QueryBinding } from "./binding";

type Description = Extract<UnifiedQueryResponse, { description: unknown }>["description"];
type Compiled = Extract<UnifiedQueryResponse, { compiled: unknown }>["compiled"];
type Page = Extract<UnifiedQueryResponse, { page: unknown }>["page"];
type Status = Extract<UnifiedQueryResponse, { status: unknown }>["status"];
type Work = {
  namespace: string;
  resultSelected: boolean;
  bundle: string | null;
  input: number | null;
  pending: { token: string } | null;
  cursor: string | null;
};
const empty = (): Work => ({
  namespace: "",
  resultSelected: false,
  bundle: null,
  input: null,
  pending: null,
  cursor: null,
});
// One configured workspace per Board origin. Frozen work and its caller lock
// outlive route components; no browser storage or result history is created.
const retained = {
  draft: "",
  draftBinding: "",
  runDraft: "",
  resource: 0,
  work: { current: empty() },
  active: false,
  follow: false,
  blocked: false,
  binding: null as string | null,
  release: null as (() => void) | null,
};
function freshNamespace() {
  const bytes = crypto.getRandomValues(new Uint32Array(2));
  return ((BigInt(bytes[0]! & 0x7fffffff) << 32n) | BigInt(bytes[1]!) | 1n).toString();
}
function errorText(error: unknown) {
  if (!(error instanceof BoardError))
    return "Connection unavailable. Durable submission may be uncertain.";
  if (error.code === "BindingChanged")
    return "Declared source contract changed. Prior accepted work remains recoverable; its results are not shown in this binding.";
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
  binding,
  followLabel,
}: {
  resource: number;
  binding?: QueryBinding;
  followLabel?: string;
  mode: "canvas" | "browse";
  visible: boolean;
  onBack: () => void;
}) {
  const [source, setSource] = useState<Description | null>(null);
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
  const [inspection, setInspection] = useState<Inspection | null>(null);
  const [inspectionDraft, setInspectionDraft] = useState("");
  const [status, setStatus] = useState<Status>(null);
  const [page, setPage] = useState<Page | null>(null);
  const [error, updateError] = useState("");
  const [diagnostic, setDiagnostic] = useState<Diagnostic | null>(null);
  const setError = (message: string) => {
    updateError(message);
    setDiagnostic(null);
  };
  const showError = (cause: unknown) => {
    setError(errorText(cause));
    if (cause instanceof BoardError) setDiagnostic(cause.diagnostic ?? null);
  };
  const [authorized, setAuthorized] = useState(false);
  const [working, setWorking] = useState(false);
  const [revision, refresh] = useState(0);
  const [resume, setResume] = useState("");
  const [, render] = useState(0);
  const { scope } = useScope();
  const live = useSyncExternalStore(liveQuery.subscribe, liveQuery.getSnapshot);
  const draftLive = useSyncExternalStore(liveDraft.subscribe, liveDraft.getSnapshot);
  const work = retained.work;
  const bindingId = binding ? JSON.stringify(binding) : null;
  if (retained.resource === 0) retained.resource = resource;
  const verified = useRef<string | null>(null);
  const alive = useRef(true);
  const visibleNow = useRef(visible);
  visibleNow.current = visible;
  const abort = useRef(new AbortController());
  const clear = useCallback(() => {
    // Frozen signatures and the original upload plan survive current denial.
    // Clearing the rendered data cannot discard an accepted partial upload.
    liveDraft.invalidate();
    retained.follow = false;
    retained.blocked = true;
    // Rechecking access can recover the upload/status, but selecting cleared
    // rows again requires an explicit run or namespace resume.
    work.current.resultSelected = false;
    abort.current.abort();
    abort.current = new AbortController();
    verified.current = null;
    setDiagnostic(null);
    setSource(null);
    setDraft("");
    setRunDraft("");
    setCompiled(null);
    setInspection(null);
    setStatus(null);
    setPage(null);
    setResume("");
    setAuthorized(false);
  }, []);
  const task = useCallback(
    async (operation: (signal: AbortSignal) => Promise<void>) => {
      if (retained.active) return;
      retained.active = true;
      const signal = abort.current.signal;
      setWorking(true);
      try {
        if (retained.resource !== resource) throw new BoardError(409, "QueryConflict");
        await operation(signal);
      } catch (cause) {
        if (alive.current && !signal.aborted) {
          showError(cause);
          if (cause instanceof BoardError && cause.code === "BindingChanged") {
            setAuthorized(false);
            setPage(null);
            setInspection(null);
          }
          if (
            cause instanceof BoardError &&
            (cause.status === 403 || cause.status === 410 || cause.code === "HistoryReclaimed")
          )
            clear();
        }
      } finally {
        if (!work.current.pending) {
          retained.release?.();
          retained.release = null;
        }
        retained.active = false;
        if (alive.current) {
          setWorking(false);
          render((n) => n + 1);
        }
      }
    },
    [clear, resource],
  );
  useEffect(() => {
    alive.current = true;
    abort.current = new AbortController();
    return () => {
      alive.current = false;
      abort.current.abort();
      void liveQuery.pause();
      liveDraft.pause();
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
    retained.release?.();
    retained.release = null;
  };
  const caller = async (signal: AbortSignal) => {
    if (retained.release) return;
    const response = await query({ describe: {} }, signal);
    if (!("description" in response)) throw new BoardError(0, "InvalidResponse");
    retained.release = await acquireCaller(response.description.connection, signal);
  };
  const advance = useCallback(
    async (signal: AbortSignal) => {
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
      if (current.bundle !== null && !document.hidden && visible) {
        await caller(signal);
        const next = await query(
          { next: { namespace: current.namespace, bundle: current.bundle } },
          signal,
        );
        if (!("prepared" in next)) throw new BoardError(0, "InvalidResponse");
        if (signal.aborted) return;
        if (next.prepared === null) {
          current.bundle = null;
          retained.release?.();
          retained.release = null;
        } else {
          current.pending = next.prepared;
          render((n) => n + 1);
          if (document.hidden) return;
          await dispatch(signal);
        }
      }
    },
    [visible],
  );
  useEffect(() => {
    let disposed = false;
    let timer: ReturnType<typeof setTimeout>;
    const poll = async () => {
      // A known terminal result stops automatic disclosure until the user
      // explicitly checks access again. A previously running read is aborted
      // by clear(), including when the denial came from the independent stream.
      if (disposed || document.hidden || retained.blocked) return;
      if (liveQuery.following || liveDraft.getSnapshot().acceptedWork) {
        // Keep one local wakeup so automatic budget exhaustion resumes current
        // reads without a user click. No request is sent while follow owns work.
        timer = setTimeout(() => void poll(), 1000);
        return;
      }
      await task(async (signal) => {
        const response = await query({ describe: {} }, signal);
        if (
          !("description" in response) ||
          response.description.source.source.resource !== resource
        )
          throw new BoardError(0, "InvalidResponse");
        if (disposed || signal.aborted) return;
        if (binding) {
          if (response.description.name !== binding.name) mismatch();
          const contract = await query({ compile: { sql: binding.sql } }, signal);
          if (!("compiled" in contract)) throw new BoardError(0, "InvalidResponse");
          unifiedContract(binding, contract.compiled);
        }
        if (disposed || signal.aborted || document.hidden) return;
        setSource(response.description);
        setInspection((previous) =>
          previous &&
          previous.resource_revision === response.description.source.resource_revision &&
          previous.policy_revision === response.description.source.policy_revision
            ? previous
            : null,
        );
        setDraft((text) => text || `SELECT * FROM ${response.description.name}`);
        if (retained.binding === bindingId) await advance(signal);
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
          if (current.resultSelected && observation.status?.phase === "complete") {
            const namespace = current.namespace;
            const result =
              verified.current === namespace
                ? await query({ page: { namespace, cursor: current.cursor } }, signal)
                : {
                    page: await verifiedPage(
                      namespace,
                      current.cursor,
                      response.description.budgets.segments,
                      signal,
                    ),
                  };
            if (!("page" in result)) throw new BoardError(0, "InvalidResponse");
            if (
              disposed ||
              signal.aborted ||
              document.hidden ||
              work.current.namespace !== namespace
            )
              return;
            if (binding) unifiedPage(binding, result.page);
            verified.current = namespace;
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
        void liveQuery.pause();
        liveDraft.pause();
        setAuthorized(false);
        setPage(null);
        setInspection(null);
      } else void poll();
    };
    void poll();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      disposed = true;
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [resource, revision, task, advance, clear, binding, bindingId]);
  useEffect(() => {
    if (!visible) {
      void liveQuery.pause();
      liveDraft.pause();
      setInspection(null);
    }
  }, [visible]);
  useEffect(() => {
    liveDraft.edit(draft);
  }, [draft]);
  useEffect(() => {
    if (draftLive.phase === "denied") {
      clear();
      setError("Query access denied. Protected workspace data cleared.");
      return;
    }
    if (["DraftSourceChanged", "DraftScopeChanged"].includes(draftLive.detail)) {
      setPage(null);
      setInspection(null);
      setAuthorized(false);
      setError(draftLive.detail);
      return;
    }
    const result = draftLive.result;
    if (!result || !visible || document.hidden) return;
    try {
      if (result.page.evidence.manifest.basis.resource !== resource) mismatch();
      if (binding) unifiedPage(binding, result.page);
    } catch (cause) {
      setPage(null);
      setInspection(null);
      setAuthorized(false);
      showError(cause);
      liveDraft.pause();
      return;
    }
    retained.follow = false;
    retained.binding = bindingId;
    work.current = { ...empty(), namespace: result.namespace, resultSelected: true };
    verified.current = result.namespace;
    setRunDraft(result.sql || "Recovered query; saved SQL is unavailable");
    setPage(result.page);
    setAuthorized(true);
    setError("");
    refresh((value) => value + 1);
  }, [
    draftLive.result,
    draftLive.phase,
    draftLive.detail,
    visible,
    resource,
    binding,
    bindingId,
    clear,
    work,
  ]);
  useEffect(() => {
    if (live.phase === "denied") {
      clear();
      setError("Query access denied. Protected workspace data cleared.");
      return;
    }
    if (retained.follow && liveQuery.following && live.snapshot && visible && !document.hidden) {
      work.current.namespace = live.snapshot.namespace!;
      work.current.resultSelected = true;
      work.current.cursor = null;
      verified.current = work.current.namespace;
      try {
        if (binding) unifiedPage(binding, live.snapshot.value);
      } catch (cause) {
        setPage(null);
        setInspection(null);
        setAuthorized(false);
        showError(cause);
        void liveQuery.pause();
        return;
      }
      setPage(live.snapshot.value);
      setAuthorized(true);
    }
  }, [live.snapshot, live.phase, visible, clear, work, binding]);
  const inspect = () =>
    void task(async (signal) => {
      setInspection(null);
      const response = await query({ inspect: { sql: draft } }, signal);
      if (
        !("inspection" in response) ||
        response.inspection.resource !== resource ||
        response.inspection.name !== source?.name
      )
        throw new BoardError(0, "InvalidResponse");
      if (signal.aborted || document.hidden || !visibleNow.current) return;
      setInspection(response.inspection);
      setInspectionDraft(draft);
      setError("");
    });
  const execute = () =>
    void task(async (signal) => {
      if (work.current.pending || work.current.input !== null || work.current.bundle) return;
      const response = await query({ compile: { sql: draft } }, signal);
      if (!("compiled" in response)) throw new BoardError(0, "InvalidResponse");
      if (signal.aborted) return;
      if (binding) unifiedContract(binding, response.compiled);
      retained.binding = bindingId;
      retained.follow = false;
      work.current = {
        ...empty(),
        namespace: freshNamespace(),
        resultSelected: true,
        bundle: response.compiled.bundle,
      };
      setCompiled(response.compiled);
      setInspection(null);
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
      await caller(signal);
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
      if (binding) unifiedPage(binding, response.page);
      work.current.cursor = cursor;
      setPage(response.page);
      setAuthorized(true);
    });
  const busy =
    working ||
    liveQuery.following ||
    draftLive.acceptedWork ||
    ["opening", "running", "active"].includes(draftLive.phase) ||
    !!work.current.pending ||
    work.current.input !== null ||
    work.current.bundle !== null;
  const controlBusy =
    working ||
    liveQuery.following ||
    draftLive.acceptedWork ||
    ["opening", "running", "active"].includes(draftLive.phase) ||
    !!work.current.pending ||
    work.current.input !== null;
  return (
    <section className="query-workspace" hidden={!visible} aria-label="Unified query workspace">
      <div className="atlas-toolbar">
        <button onClick={onBack}>← Neighborhood</button>
        <span>Resource {resource} · separate v1 query capability</span>
        <button
          disabled={working}
          onClick={() => {
            retained.blocked = false;
            refresh((n) => n + 1);
          }}
        >
          Refresh query access
        </button>
      </div>
      <p role="status" className="query-status">
        {(!diagnostic && error) ||
          (working
            ? "Checking current query evidence…"
            : status
              ? `Query ${work.current.namespace}: ${status.phase}`
              : "Run is explicit; switching views does not execute.")}
      </p>
      {diagnostic ? (
        <QueryDiagnostic value={diagnostic} />
      ) : status?.diagnostic ? (
        <QueryDiagnostic value={status.diagnostic} />
      ) : null}
      <DraftControls
        session={liveDraft}
        available={authorized && source !== null && "table" in source.source.source.source}
        busy={
          working ||
          liveQuery.following ||
          !!work.current.pending ||
          work.current.input !== null ||
          work.current.bundle !== null
        }
      />
      {work.current.namespace && (
        <QueryRecovery
          id={work.current.namespace}
          phase={status?.phase}
          busy={controlBusy}
          canSelect={!busy}
          inspect={() =>
            void task(async (signal) => {
              const namespace = work.current.namespace;
              const response = await query({ status: namespace }, signal);
              if (!("status" in response)) throw new BoardError(0, "InvalidResponse");
              if (signal.aborted || namespace !== work.current.namespace) return;
              setStatus(response.status);
              setError(
                `Retained query ${namespace}: ${response.status?.phase ?? "unobserved"}. No result was read.`,
              );
            })
          }
          cancel={() => control("cancel")}
          select={() => {
            saveQueryReference("unified_v1", retained.resource, work.current.namespace);
            retained.follow = false;
            retained.binding = bindingId;
            work.current = empty();
            verified.current = "";
            setPage(null);
            setStatus(null);
            setCompiled(null);
            setRunDraft("");
            refresh((value) => value + 1);
          }}
        />
      )}
      {retained.binding !== bindingId &&
        (work.current.bundle || work.current.input !== null) &&
        !work.current.pending && (
          <div className="uncertain">
            <p>
              An earlier binding has an accepted upload. Continue its exact retained plan
              independently of this screen.
            </p>
            <button disabled={working} onClick={() => void task(advance)}>
              Resume prior binding upload
            </button>
          </div>
        )}
      {work.current.pending && (
        <div className="uncertain">
          <strong>Submission not yet confirmed.</strong>
          <p>The identical signed request is retained across Board navigation in this tab.</p>
          <button
            disabled={working}
            onClick={() =>
              void task(async (signal) => {
                await caller(signal);
                await dispatch(signal);
                refresh((n) => n + 1);
              })
            }
          >
            Retry exact submission
          </button>
        </div>
      )}
      {(!binding || binding.refresh === "follow") &&
        scope?.reactive_table &&
        source &&
        "table" in source.source.source.source && (
          <div aria-label="Query follow controls">
            <p role="status">
              {live.phase.replaceAll("_", " ")} · {live.detail}
            </p>
            <button
              disabled={busy || status?.phase !== "complete" || !page}
              onClick={() => {
                retained.follow = true;
                selectLiveTemplate();
                void liveQuery.start(work.current.namespace, binding?.starts ?? 8).catch(() => {});
              }}
            >
              {followLabel ?? "Follow changes"}
            </button>
            <button onClick={() => void liveQuery.pause().then(() => refresh((n) => n + 1))}>
              Pause changes
            </button>
            {querySession.pending && (
              <button onClick={() => void liveQuery.recover().catch(() => {})}>
                Recover exact control
              </button>
            )}
            {live.refresh && (
              <p>
                {live.refresh.starts} / {live.refresh.limit} refresh intents used. Accepted results
                remain retained.
              </p>
            )}
          </div>
        )}
      <label htmlFor="unified-resume">Existing query namespace</label>
      <input id="unified-resume" value={resume} onChange={(e) => setResume(e.target.value)} />
      <button
        disabled={
          busy ||
          (!!work.current.namespace && !terminalQuery(status?.phase)) ||
          !/^[1-9][0-9]{0,19}$/.test(resume) ||
          BigInt(resume || "0") > 18446744073709551615n
        }
        onClick={() => {
          if (work.current.namespace)
            saveQueryReference("unified_v1", retained.resource, work.current.namespace);
          retained.follow = false;
          work.current = { ...empty(), namespace: resume, resultSelected: true };
          setPage(null);
          setStatus(null);
          verified.current = "";
          setCompiled(null);
          setRunDraft("Recovered query; saved SQL is unavailable");
          refresh((n) => n + 1);
        }}
      >
        Resume without rerunning
      </button>
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
              Statement ≤ {source.sql.statement_bytes} bytes. Star or up to{" "}
              {source.sql.named_columns} named columns; comparisons and exact cell-state tests with
              NOT, AND, OR and parentheses; rows, count, checked int64 sum. Uint64/float64 literals
              use explicit type suffixes. Writes are unsupported.
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
            <QueryCandidates resource={resource} select={setDraft} denied={clear} />
            <label htmlFor="unified-sql">SQL draft</label>
            <SqlEditor
              value={draft}
              change={setDraft}
              resource={resource}
              scope={JSON.stringify([
                source.connection,
                source.source.source,
                source.source.policy_revision,
              ])}
              contract={binding?.schema ?? null}
              visible={visible}
              denied={clear}
            />
            <button disabled={busy || !draft.trim()} onClick={execute}>
              Run query
            </button>
            <button disabled={busy || !draft.trim()} onClick={inspect}>
              Inspect SQL
            </button>
            <p>Inspect SQL accepts DESCRIBE, SHOW TABLES and EXPLAIN SELECT.</p>
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
          {runDraft && runDraft !== draft && (
            <p>Draft changed. The displayed result belongs to the earlier submitted SQL.</p>
          )}
          {inspection && <QueryInspection value={inspection} changed={inspectionDraft !== draft} />}
          {page && (
            <div className="query-result" aria-label="Verified query result">
              <QueryProfile page={page} />
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
                  : "Complete coverage verified; more pages are available from this result."}
              </p>
            </div>
          )}
        </>
      )}
    </section>
  );
}
