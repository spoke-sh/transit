import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import {
  generation,
  presentation,
  readInterface,
  type Compiled,
  type Definition,
} from "@transit/application";
import type { Deployment } from "@transit/board-client";
import "./shell.css";
import { useRead } from "./use-observation";
type Current = { compiled: Compiled; identity: string; published: boolean };
const Interface = createContext<Current | null>(null);
export const useInterface = () => useContext(Interface);
export function InterfaceShell({ scope, children }: { scope: Deployment; children: ReactNode }) {
  const [density, setDensity] = useState<"comfortable" | "compact" | null>(null);
  const [navigation, setNavigation] = useState(false);
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const [area, setArea] = useState<"workspace" | "operations">("workspace");
  const observed = useRead<Current>(`interface/${scope.realm}`, async (signal) => {
    const value = await readInterface(signal);
    const compiled = "builtin" in value ? value.builtin : value.published.compiled;
    if (compiled.definition.realm !== scope.realm) throw new Error("Interface realm changed");
    return {
      compiled,
      published: "published" in value,
      identity:
        "builtin" in value
          ? `builtin/${scope.realm}/${compiled.spec.digest.join(".")}`
          : generation(scope.realm, compiled.definition.name, value.published.head),
    };
  });
  // Only the public built-in shell may survive hiding/revalidation. Never retain
  // a published definition or install a built-in fallback after failed access.
  const builtin = useRef<Current | null>(null);
  if (observed.value) builtin.current = observed.value.published ? null : observed.value;
  if (observed.failure) builtin.current = null;
  const current =
    observed.value ??
    (builtin.current?.compiled.definition.realm === scope.realm ? builtin.current : null);
  const error = observed.failure?.code ?? "";
  const definition = current?.compiled.definition;
  const dataPage =
    pathname === "/catalog" ||
    pathname.startsWith("/datasets/") ||
    (pathname === "/" && !current?.published);
  const workbookPage = pathname === "/workbook";
  const workbenchPage =
    (dataPage ||
      workbookPage ||
      pathname === "/operations" ||
      pathname === "/recovery/relational") &&
    !(current?.published && definition?.screens.some((screen) => screen.path === pathname));
  const application = current?.published
    ? definition?.screens.find((screen) => screen.name === definition.entry)
    : undefined;
  const operations = definition?.screens.find((screen) => screen.renderer === "operations");
  useEffect(() => {
    const screen = definition?.screens.find((candidate) => candidate.path === pathname);
    if (
      pathname === "/catalog" ||
      pathname === "/workbook" ||
      pathname.startsWith("/datasets/") ||
      (pathname === "/" && !current?.published)
    )
      setArea("workspace");
    else if (screen) setArea(current?.published ? screen.area : "operations");
    setNavigation(!workbenchPage && window.matchMedia("(min-width: 761px)").matches);
  }, [pathname, definition, current?.published, workbenchPage]);
  const tokens = density ?? (definition ? presentation(definition).density : "comfortable");
  return (
    <Interface.Provider value={current}>
      <div
        className="transit-shell"
        data-density={tokens}
        data-interface-generation={current?.identity ?? "unavailable"}
        data-navigation={navigation && !workbenchPage}
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
          <nav className="shell-areas" aria-label="Activities">
            <Link to="/catalog" aria-current={dataPage ? "page" : undefined}>
              Data{!scope.features.catalog && <small> · Not configured</small>}
            </Link>
            <Link to="/workbook" aria-current={workbookPage ? "page" : undefined}>
              Workbooks{!scope.features.sql && <small> · Not configured</small>}
            </Link>
            {operations && (
              <Link
                to={operations.path}
                aria-current={
                  area === "operations" && !dataPage && !workbookPage ? "page" : undefined
                }
              >
                Operations
              </Link>
            )}
            {application && (
              <Link
                to={application.path}
                aria-current={
                  area === "workspace" && !dataPage && !workbookPage ? "page" : undefined
                }
              >
                Application
              </Link>
            )}
          </nav>
          <span className="shell-realm">Realm {scope.realm}</span>
          <Link className="shell-recovery-link" to="/recovery/definition">
            Definition recovery
          </Link>
          {!workbenchPage && (
            <button
              className="shell-menu"
              aria-expanded={navigation}
              aria-controls="shell-navigation"
              onClick={() => setNavigation(!navigation)}
            >
              Navigation
            </button>
          )}
        </header>
        <aside
          id="shell-navigation"
          className={`shell-navigation ${navigation && !workbenchPage ? "open" : ""}`}
          aria-label="Workspace navigation"
        >
          <p className="eyebrow">{area}</p>
          <nav>
            {area === "workspace" && (
              <>
                <Link
                  to="/catalog"
                  aria-current={
                    pathname === "/catalog" || (pathname === "/" && !current?.published)
                      ? "page"
                      : undefined
                  }
                >
                  Catalog
                </Link>
                <Link to="/workbook" aria-current={pathname === "/workbook" ? "page" : undefined}>
                  Workbook <small>Session</small>
                </Link>
              </>
            )}
            {definition?.screens
              .filter((screen) =>
                current?.published ? screen.area === area : area === "operations",
              )
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
            Realm {scope.realm} · Private workspace · Reads check current permissions
          </aside>
          {current || pathname.startsWith("/recovery/") ? (
            children
          ) : (
            <main>
              <h1>Definition unavailable</h1>
              <p role="status">{error || "Reading the current interface…"}</p>
              <button onClick={observed.retry}>Retry definition read</button>
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
