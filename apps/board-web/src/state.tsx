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
  login,
  logout,
  read,
  type Capabilities,
  type Response,
  type Resource,
  type Cut,
} from "@rey/board-client";
const Context = createContext<{ scope: Capabilities | null; denied: () => void }>({
  scope: null,
  denied: () => {},
});
export const useScope = () => useContext(Context);
export function Access({ children }: { children: ReactNode }) {
  const [scope, setScope] = useState<Capabilities | null>(null);
  const [error, setError] = useState("");
  const [checking, setChecking] = useState(true);
  const denied = useCallback(() => {
    setScope(null);
    setError("Access ended. Sign in with the current Board access key.");
  }, []);
  const check = useCallback(async (signal?: AbortSignal) => {
    try {
      for (let attempt = 0; ; attempt++) {
        try {
          setScope(await capabilities(signal));
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
  }, [check]);
  return (
    <Context.Provider value={{ scope, denied }}>
      <header>
        <a href="/" className="brand">
          <span aria-hidden="true">▥</span> Board <small>REY / TRANSIT</small>
        </a>
        <span className="profile">INSPECTION ONLY</span>
        {scope && (
          <button
            onClick={async () => {
              try {
                await logout();
              } finally {
                denied();
              }
            }}
          >
            Sign out
          </button>
        )}
      </header>
      {!scope ? (
        <main className="access">
          <p className="eyebrow">SYSTEM INSPECTION</p>
          <h1>See the sequence.</h1>
          <p>Arrivals, departures, and the evidence between them.</p>
          <form
            onSubmit={async (event) => {
              event.preventDefault();
              const form = event.currentTarget;
              const credential = String(new FormData(form).get("credential") ?? "");
              form.reset();
              try {
                await login(credential);
                await check();
              } catch (cause) {
                setError(message(cause));
              }
            }}
          >
            <label htmlFor="credential">Board access key</label>
            <input
              id="credential"
              name="credential"
              type="password"
              autoComplete="off"
              required
              maxLength={64}
              minLength={64}
            />
            <button type="submit">Open board</button>
          </form>
          <p role="status">{checking ? "Checking session…" : error}</p>
          <p className="muted">
            Viewers share this installation’s configured inspection scope. No operational controls
            are available.
          </p>
        </main>
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
    if (cause.code === "QueryExpired")
      return "The authority changed. Refresh to start a new observation; these pages cannot be combined.";
    if (cause.code === "HistoryReclaimed")
      return "Retention overtook this observation. Refresh and inspect the retained boundary.";
    if (cause.code === "Forbidden" || cause.code === "Unauthorized")
      return "Inspection access denied or session expired.";
    if (cause.code === "RateLimited")
      return "Inspection rate limit reached. Waiting before retrying.";
    if (cause.code === "UnsafePrincipal")
      return "Board requires a Transit principal with only inspect permission.";
    return `Observation unavailable (${cause.code}).`;
  }
  return "Connection unavailable. No new observation was received.";
}
export function useObservation(resource: Resource, pid?: number) {
  const { denied } = useScope();
  const [data, setData] = useState<Response | null>(null);
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
        const next = await read(resource, pid, continuation, controller.signal);
        if (controller.signal.aborted) return;
        setData(next);
        setError("");
        setObservedAt(new Date().toLocaleTimeString());
        failures.current = 0;
      } catch (cause) {
        if (controller.signal.aborted) return;
        failures.current++;
        setError(message(cause));
        if (cause instanceof BoardError && (cause.status === 401 || cause.status === 403)) {
          setData(null);
          denied();
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
  }, [resource, pid, continuation, refresh, denied]);
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
