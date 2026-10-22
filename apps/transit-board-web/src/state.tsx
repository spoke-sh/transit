import { diagnosticLines } from "@transit/query-client";
import { InterfaceShell } from "./interface";
import { Link } from "@tanstack/react-router";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  BoardError,
  capabilities,
  read,
  readState,
  type StateResponse,
  type StateResource,
  type Capabilities,
  type Response,
  type Resource,
  type Cut,
} from "@transit/board-client";
const Context = createContext<{ scope: Capabilities | null; denied: () => void }>({
  scope: null,
  denied: () => {},
});
export const useScope = () => useContext(Context);
export function Access({ children }: { children: ReactNode }) {
  const [scope, setScope] = useState<Capabilities | null>(null);
  const [error, setError] = useState("");
  const [checking, setChecking] = useState(true);
  const [retry, setRetry] = useState(0);
  const denied = useCallback(() => {
    setScope(null);
    setError("Transit denied inspection. Check Board’s configured read grant, then retry.");
  }, []);
  const check = useCallback(async (signal?: AbortSignal) => {
    setChecking(true);
    try {
      for (let attempt = 0; ; attempt++) {
        try {
          const next = await capabilities(signal);
          if (signal?.aborted) return;
          setScope(next);
          setError("");
          break;
        } catch (cause) {
          if (
            !(cause instanceof BoardError) ||
            cause.status !== 429 ||
            attempt >= 3 ||
            signal?.aborted
          )
            throw cause;
          await new Promise((resolve) => setTimeout(resolve, 250));
        }
      }
    } catch (cause) {
      if (!signal?.aborted) setError(message(cause));
    } finally {
      if (!signal?.aborted) setChecking(false);
    }
  }, []);
  useEffect(() => {
    const controller = new AbortController();
    void check(controller.signal);
    return () => controller.abort();
  }, [check, retry]);
  return (
    <Context.Provider value={{ scope, denied }}>
      {scope?.profile !== "native_v1" && (
        <header>
          <a href="/" className="brand">
            <span aria-hidden="true">▥</span> Transit <small>BOARD</small>
          </a>
          <Link to="/definition">Definition</Link>
          <span className="profile">
            {scope?.query_enabled ? "INSPECTION · SQL QUERIES" : "INSPECTION ONLY"}
          </span>
        </header>
      )}
      {!scope ? (
        <main className="access">
          <p className="eyebrow">SYSTEM INSPECTION</p>
          <h1>See the sequence.</h1>
          <p>Arrivals, departures, and the evidence between them.</p>
          <p role="status">{checking ? "Connecting to Board…" : error}</p>
          {!checking && (
            <button onClick={() => setRetry((value) => value + 1)}>Retry connection</button>
          )}
          <p className="muted">
            Viewers share this installation’s configured inspection scope. Operator actions require
            a separately enabled endpoint and signing identity.
          </p>
        </main>
      ) : scope.profile === "native_v1" ? (
        <InterfaceShell scope={scope}>{children}</InterfaceShell>
      ) : (
        <>
          <aside className="scope">
            Realm {scope.realm} ·{" "}
            {scope.scope_pid === null ? "All authorized processes" : `PID ${scope.scope_pid}`} ·
            shared read principal
          </aside>
          {children}
        </>
      )}
    </Context.Provider>
  );
}
export function message(cause: unknown): string {
  if (cause instanceof BoardError) {
    if (cause.diagnostic) return diagnosticLines(cause.diagnostic).join(" ");
    if (cause.code === "QueryExpired")
      return "The authority changed. Refresh to start a new observation; these pages cannot be combined.";
    if (cause.code === "HistoryReclaimed")
      return "Retention overtook this observation. Refresh and inspect the retained boundary.";
    if (cause.code === "Forbidden")
      return "Transit denied inspection. Check Board’s configured read grant, then retry.";
    if (cause.code === "RateLimited")
      return "Inspection rate limit reached. Waiting before retrying.";
    if (cause.code === "UnsafePrincipal")
      return "Board requires a Transit principal with only inspect permission.";
    return `Observation unavailable (${cause.code}).`;
  }
  return "Connection unavailable. No new observation was received.";
}
export function useObservation(resource: Resource, pid?: number) {
  return usePagedRead<Response, Resource>(resource, pid, read, true);
}
export function useStateObservation(resource: StateResource, id?: number) {
  return usePagedRead<StateResponse, StateResource>(resource, id, readState, false);
}
function usePagedRead<
  T extends { observation: { cut: Cut; next: number | null } },
  R extends string,
>(
  resource: R,
  pid: number | undefined,
  fetchPage: (
    resource: R,
    pid?: number,
    continuation?: { cut: Cut; after: number },
    signal?: AbortSignal,
  ) => Promise<T>,
  clearScope: boolean,
) {
  const { denied } = useScope();
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState("");
  const [observedAt, setObservedAt] = useState<string>("");
  const [continuation, setContinuation] = useState<{ cut: Cut; after: number }>();
  const [refresh, setRefresh] = useState(0);
  const failures = useRef(0);
  useEffect(() => {
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout>;
    setData(null);
    setError("");
    setObservedAt("");
    async function poll() {
      if (document.hidden) {
        timer = setTimeout(poll, 5000);
        return;
      }
      try {
        const next = await fetchPage(resource, pid, continuation, controller.signal);
        if (controller.signal.aborted) return;
        setData(next);
        setError("");
        setObservedAt(new Date().toLocaleTimeString());
        failures.current = 0;
      } catch (cause) {
        if (controller.signal.aborted) return;
        failures.current++;
        setError(message(cause));
        if (cause instanceof BoardError && cause.status === 403) {
          setData(null);
          if (clearScope) denied();
          return;
        }
        // A stale continuation needs an explicit restart, never automatic stitching.
        if (cause instanceof BoardError && cause.status === 409) return;
      }
      if (!continuation)
        timer = setTimeout(poll, Math.min(30000, 5000 * 2 ** Math.min(failures.current, 3)));
    }
    // One first request after the capability check; no parallel screen fan-out.
    timer = setTimeout(poll, 150);
    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [resource, pid, continuation, refresh, denied, fetchPage, clearScope]);
  return {
    data,
    error,
    observedAt,
    next: () => {
      if (data?.observation.next != null)
        setContinuation({ cut: data.observation.cut, after: data.observation.next });
    },
    reset: () => {
      setContinuation(undefined);
      setRefresh((value) => value + 1);
    },
    paginated: continuation !== undefined,
  };
}
