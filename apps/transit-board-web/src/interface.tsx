import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import {
  generation,
  presentation,
  readInterface,
  type Compiled,
  type Definition,
} from "@rey/transit-application";
import type { Capabilities } from "@rey/transit-board-client";
import "./shell.css";
type Current = { compiled: Compiled; identity: string; published: boolean };
const Interface = createContext<Current | null>(null);
export const useInterface = () => useContext(Interface);
export function InterfaceShell({ scope, children }: { scope: Capabilities; children: ReactNode }) {
  const [current, setCurrent] = useState<Current | null>(null);
  const [error, setError] = useState("");
  const [retry, setRetry] = useState(0);
  const [density, setDensity] = useState<"comfortable" | "compact" | null>(null);
  const [navigation, setNavigation] = useState(false);
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const [area, setArea] = useState<"workspace" | "operations">("workspace");
  useEffect(() => {
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout>;
    let reading = false;
    async function refresh() {
      if (controller.signal.aborted || document.hidden || reading) return;
      reading = true;
      try {
        const value = await readInterface(controller.signal);
        const compiled = "builtin" in value ? value.builtin : value.published.compiled;
        if (compiled.definition.realm !== scope.realm) throw new Error("Interface realm changed");
        if (!controller.signal.aborted && !document.hidden) {
          const identity =
            "builtin" in value
              ? `builtin/${scope.realm}/${compiled.spec.digest.join(".")}`
              : generation(scope.realm, compiled.definition.name, value.published.head);
          setCurrent((previous) =>
            previous?.identity === identity
              ? previous
              : { compiled, identity, published: "published" in value },
          );
          setError("");
        }
      } catch (cause) {
        if (!controller.signal.aborted) {
          // A failed published acquisition cannot authorize stale navigation or
          // install a built-in fallback. Recovery has an independent fixed route.
          setCurrent(null);
          setError(cause instanceof Error ? cause.message : "Interface unavailable");
        }
      } finally {
        reading = false;
        if (!controller.signal.aborted) timer = setTimeout(() => void refresh(), 5000);
      }
    }
    const visibility = () => {
      clearTimeout(timer);
      if (document.hidden) setCurrent(null);
      else void refresh();
    };
    void refresh();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      clearTimeout(timer);
      controller.abort();
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [scope.realm, retry]);
  const definition = current?.compiled.definition;
  useEffect(() => {
    const screen = definition?.screens.find((candidate) => candidate.path === pathname);
    if (screen) setArea(screen.area);
    setNavigation(false);
  }, [pathname, definition]);
  const tokens = density ?? (definition ? presentation(definition).density : "comfortable");
  return (
    <Interface.Provider value={current}>
      <div
        className="transit-shell"
        data-density={tokens}
        data-interface-generation={current?.identity ?? "unavailable"}
      >
        <header className="shell-header">
          <Link
            className="brand"
            to="/"
            search={{ status: "all", sort: "pid" }}
            aria-label="Transit Board home"
          >
            <span aria-hidden="true">▥</span> Transit <small>BOARD</small>
          </Link>
          <nav className="shell-areas" aria-label="Area">
            <button aria-pressed={area === "workspace"} onClick={() => setArea("workspace")}>
              Workspace
            </button>
            <button aria-pressed={area === "operations"} onClick={() => setArea("operations")}>
              Operations
            </button>
          </nav>
          <span className="shell-realm">Realm {scope.realm}</span>
          <button
            className="shell-menu"
            aria-expanded={navigation}
            aria-controls="shell-navigation"
            onClick={() => setNavigation(!navigation)}
          >
            Navigation
          </button>
        </header>
        <aside
          id="shell-navigation"
          className={`shell-navigation ${navigation ? "open" : ""}`}
          aria-label="Workspace navigation"
        >
          <p className="eyebrow">{area}</p>
          <nav>
            {definition?.screens
              .filter((screen) => screen.area === area)
              .map((screen) => (
                <Link
                  key={screen.name}
                  to={screen.path}
                  aria-current={pathname === screen.path ? "page" : undefined}
                >
                  {screen.label}
                </Link>
              ))}
          </nav>
          <div className="shell-recovery">
            <Link to="/recovery/definition">Definition recovery</Link>
            <p>
              {current
                ? `${current.published ? "Published" : "Built-in"} revision ${definition?.revision}`
                : "Definition unavailable"}
            </p>
            <label>
              Preview density
              <select
                aria-label="Preview density"
                value={density ?? "definition"}
                onChange={(event) =>
                  setDensity(
                    event.target.value === "definition"
                      ? null
                      : (event.target.value as "comfortable" | "compact"),
                  )
                }
              >
                <option value="definition">From definition</option>
                <option value="comfortable">Comfortable</option>
                <option value="compact">Compact</option>
              </select>
            </label>
          </div>
        </aside>
        <div className="shell-content">
          <aside className="scope">
            Realm {scope.realm} ·{" "}
            {scope.scope_pid === null ? "All authorized processes" : `PID ${scope.scope_pid}`} ·
            shared read principal
          </aside>
          {current || pathname === "/recovery/definition" ? (
            children
          ) : (
            <main>
              <h1>Definition unavailable</h1>
              <p role="status">{error || "Reading the current interface…"}</p>
              <button onClick={() => setRetry((value) => value + 1)}>Retry definition read</button>
            </main>
          )}
        </div>
      </div>
    </Interface.Provider>
  );
}
export function selectedScreen(definition: Definition, path: string) {
  return definition.screens.find((screen) =>
    path === "/" ? screen.name === definition.entry : screen.path === path,
  );
}
