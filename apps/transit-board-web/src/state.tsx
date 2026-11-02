import { diagnosticLines } from "@transit/query-client";
import { InterfaceShell } from "./interface";
import { useRead } from "./use-observation";
import { ReadStatus } from "./read-status";
import { createContext, useContext, useState, type ReactNode } from "react";
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
  const scopeKey = JSON.stringify([resource, pid]);
  const [cursor, setCursor] = useState<{ scope: string; value: { cut: Cut; after: number } }>();
  const continuation = cursor?.scope === scopeKey ? cursor.value : undefined;
  const setContinuation = (value?: { cut: Cut; after: number }) =>
    setCursor(value ? { scope: scopeKey, value } : undefined);
  const key = JSON.stringify([resource, pid, continuation]);
  const state = useRead(
    key,
    async (signal) => ({
      data: await fetchPage(resource, pid, continuation, signal),
      observedAt: new Date().toLocaleTimeString(),
    }),
    continuation ? 0 : 5000,
  );
  const data = state.value?.data ?? null;
  return {
    data,
    error: state.failure ? message(new BoardError(0, state.failure.code)) : "",
    observedAt: state.value?.observedAt ?? "",
    next: () => {
      if (data?.observation.next != null)
        setContinuation({ cut: data.observation.cut, after: data.observation.next });
    },
    reset: () => {
      if (continuation) setContinuation(undefined);
      else state.retry();
    },
    paginated: continuation !== undefined,
  };
}
