import { diagnosticLines } from "@transit/query-client";
import { InterfaceShell } from "./interface";
import { useRead } from "./use-observation";
import { ReadStatus } from "./read-status";
import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import {
  BoardError,
  deployment,
  read,
  readState,
  type StateResponse,
  type StateResource,
  type Deployment,
  type Response,
  type Resource,
  type Cut,
} from "@transit/board-client";
const Context = createContext<{ scope: Deployment | null; refresh: () => void }>({
  scope: null,
  refresh: () => {},
});
export const useScope = () => useContext(Context);
export function Access({ children }: { children: ReactNode }) {
  const connection = useRead("deployment", deployment, 0, false);
  // Configuration is not an authorized resource observation. Upstream denial
  // stays with the affected view and never disables an unrelated connection.
  return (
    <Context.Provider value={{ scope: connection.value, refresh: connection.retry }}>
      {connection.value ? (
        <InterfaceShell scope={connection.value}>{children}</InterfaceShell>
      ) : (
        <main className="access">
          <h1>Transit Board</h1>
          <ReadStatus failure={connection.failure} retry={connection.retry} subject="Board" />
        </main>
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
  return usePagedRead<Response, Resource>(resource, pid, read);
}
export function useStateObservation(resource: StateResource, id?: number) {
  return usePagedRead<StateResponse, StateResource>(resource, id, readState);
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
) {
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
  }, [resource, pid, continuation, refresh, fetchPage]);
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
