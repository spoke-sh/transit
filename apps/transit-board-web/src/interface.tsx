import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  Suspense,
  type ReactNode,
} from "react";
import { CatchBoundary, Link, useRouterState } from "@tanstack/react-router";
import { ApplicationTransportError } from "@transit/application/error";
import { generation, presentation } from "@transit/application/definition";
import { readInterface } from "@transit/application/interface";
import { type Compiled, type Definition } from "@transit/application";
import type { Deployment } from "@transit/board-client";
import "./shell.css";
import { useRead } from "./use-observation";
import { WorkbookPage } from "./features";
import { FeatureLoading, FeatureUnavailable } from "./feature-status";
import { WorkbenchPlane, useInspector } from "./workbench-layout";
type Current = { compiled: Compiled; identity: string; published: boolean };
const Interface = createContext<Current | null>(null);
export const useInterface = () => useContext(Interface);
export function InterfaceShell({ scope, children }: { scope: Deployment; children: ReactNode }) {
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  return (
    <WorkbenchPlane key={scope.realm} route={pathname}>
      <InterfaceBody scope={scope}>{children}</InterfaceBody>
    </WorkbenchPlane>
  );
}
function InterfaceBody({ scope, children }: { scope: Deployment; children: ReactNode }) {
  const inspector = useInspector();
  const { plane, layout } = inspector;
  const [density, setDensity] = useState<"comfortable" | "compact" | null>(null);
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const [area, setArea] = useState<"workspace" | "operations">("workspace");
  const observed = useRead<Current>(`interface/${scope.realm}`, async (signal) => {
    const value = await readInterface(signal);
    const compiled = "builtin" in value ? value.builtin : value.published.compiled;
    if (compiled.definition.realm !== scope.realm)
      throw new ApplicationTransportError(0, "InvalidResponse");
    return {
      compiled,
      published: "published" in value,
      identity:
        "builtin" in value
          ? `builtin/${scope.realm}/${compiled.spec.digest.join(".")}`
          : generation(scope.realm, compiled.definition.name, value.published.head),
    };
  });
  // A revalidated generation has the same immutable bindings. Preserve their
  // object identity so its consumers do not restart effects on every refresh.
  const qualified = useRef<Current | null>(null);
  if (!observed.value) qualified.current = null;
  else if (qualified.current?.identity !== observed.value.identity)
    qualified.current = observed.value;
  // Only the public built-in shell may survive hiding/revalidation. Never retain
  // a published definition or install a built-in fallback after failed access.
  const builtin = useRef<Current | null>(null);
  if (observed.value) builtin.current = observed.value.published ? null : observed.value;
  if (observed.failure) builtin.current = null;
  const current =
    qualified.current ??
    (builtin.current?.compiled.definition.realm === scope.realm ? builtin.current : null);
  const error = observed.failure?.code ?? "";
  const definition = current?.compiled.definition;
  const dataPage =
    pathname === "/catalog" ||
    pathname.startsWith("/datasets/") ||
    (pathname === "/" && !current?.published);
  const workbookPage = pathname === "/workbook";
  const workbookActive =
    workbookPage &&
    Boolean(current) &&
    !(current?.published && definition?.screens.some((screen) => screen.path === pathname));
  const [workbookVisited, setWorkbookVisited] = useState(false);
  useEffect(() => {
    if (workbookActive) setWorkbookVisited(true);
  }, [workbookActive]);
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
  }, [pathname, definition, current?.published]);
  const tokens = density ?? (definition ? presentation(definition).density : "comfortable");
  return (
    <Interface.Provider value={current}>
      <div
        className="transit-shell"
        data-density={tokens}
        data-interface-generation={current?.identity ?? "unavailable"}
        data-left={layout.left}
        data-right={layout.right}
        data-takeover={layout.takeover ?? "none"}
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
          <span className="shell-realm">Realm {scope.realm}</span>
          <Link className="shell-recovery-link" to="/recovery/definition">
            Definition recovery
          </Link>
        </header>
        <section className="shell-scope" aria-label="Workspace scope">
          Realm {scope.realm} · Private workspace · Reads check current permissions
          <div ref={inspector.setScopeHost} />
        </section>
        <aside id="shell-navigation" className="shell-navigation" aria-label="Workspace navigation">
          <button
            className="plane-toggle"
            data-plane-toggle="left"
            aria-expanded={layout.left}
            aria-controls="navigation-detail"
            aria-label={layout.left ? "Fold navigation" : "Open navigation"}
            title={layout.left ? "Fold navigation" : "Open navigation"}
            onClick={inspector.toggleNavigation}
          >
            <span aria-hidden="true">{layout.left ? "‹" : "›"}</span>
          </button>
          {layout.takeover === "left" && (
            <button data-plane-back="left" onClick={() => inspector.fold("left")}>
              Back to workspace
            </button>
          )}
          <nav className="shell-areas" aria-label="Activities">
            <Link
              to="/catalog"
              title="Catalog"
              aria-label="Data"
              aria-current={dataPage ? "page" : undefined}
            >
              <span aria-hidden="true">▦</span>
              <span className="activity-label">
                Catalog{!scope.features.catalog && <small> · Not configured</small>}
              </span>
            </Link>
            <Link
              to="/workbook"
              title="Workbook"
              aria-label="Workbooks"
              aria-current={workbookPage ? "page" : undefined}
            >
              <span aria-hidden="true">▤</span>
              <span className="activity-label">
                Workbook{!scope.features.sql && <small> · Not configured</small>}
              </span>
            </Link>
            {operations && (
              <Link
                to={operations.path}
                title="Operations"
                aria-label="Operations"
                aria-current={
                  area === "operations" && !dataPage && !workbookPage ? "page" : undefined
                }
              >
                <span aria-hidden="true">◷</span>
                <span className="activity-label">Operations</span>
              </Link>
            )}
            {application && (
              <Link
                to={application.path}
                title="Application"
                aria-label="Application"
                aria-current={
                  area === "workspace" && !dataPage && !workbookPage ? "page" : undefined
                }
              >
                <span aria-hidden="true">◇</span>
                <span className="activity-label">Application</span>
              </Link>
            )}
          </nav>
          <div id="navigation-detail" hidden={!layout.left}>
            <div ref={inspector.setNavigationHost} />
            <nav aria-label="Activity views" className="shell-views">
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
          </div>
        </aside>
        <div className="shell-content" hidden={Boolean(layout.takeover)}>
          {current || pathname.startsWith("/recovery/") ? (
            children
          ) : (
            <main>
              <h1>Definition unavailable</h1>
              <p role="status">{error || "Reading the current interface…"}</p>
              <button onClick={observed.retry}>Retry definition read</button>
            </main>
          )}
          {(workbookVisited || workbookActive) && (
            <div hidden={!workbookActive}>
              <CatchBoundary getResetKey={() => "workbook"} errorComponent={FeatureUnavailable}>
                <Suspense fallback={<FeatureLoading />}>
                  <WorkbookPage active={workbookActive} />
                </Suspense>
              </CatchBoundary>
            </div>
          )}
        </div>
        <section className="shell-context" aria-label="Context pane">
          <div
            role="tablist"
            aria-label="Context"
            aria-orientation={layout.right ? "horizontal" : "vertical"}
            onKeyDown={(event) => {
              if (
                !["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].includes(
                  event.key,
                )
              )
                return;
              event.preventDefault();
              const tab =
                event.key === "Home"
                  ? "inspector"
                  : event.key === "End"
                    ? "assistant"
                    : plane.tab === "inspector"
                      ? "assistant"
                      : "inspector";
              inspector.dispatch({ type: "tab", tab });
              document.getElementById(`context-${tab}-tab`)?.focus();
            }}
          >
            {(["inspector", "assistant"] as const).map((tab) => (
              <button
                key={tab}
                role="tab"
                id={`context-${tab}-tab`}
                data-plane-toggle={tab === "inspector" ? "right" : undefined}
                aria-controls={`context-${tab}`}
                aria-selected={plane.tab === tab}
                tabIndex={plane.tab === tab ? 0 : -1}
                aria-expanded={layout.right && plane.tab === tab}
                title={tab === "inspector" ? "Inspector" : "Assistant"}
                onClick={() => inspector.dispatch({ type: "tab", tab })}
              >
                <span aria-hidden="true">{tab === "inspector" ? "ⓘ" : "✧"}</span>
                <span className="context-label">
                  {tab === "inspector" ? "Inspector" : "Assistant"}
                </span>
              </button>
            ))}
          </div>
          <div hidden={!layout.right}>
            <button className="inspector-close" data-plane-back="right" onClick={inspector.close}>
              {layout.takeover === "right"
                ? "Back to workspace"
                : plane.tab === "inspector"
                  ? "Close inspector"
                  : "Close assistant"}
            </button>
            <section
              role="tabpanel"
              id="context-inspector"
              aria-labelledby="context-inspector-tab"
              hidden={plane.tab !== "inspector"}
            >
              <aside className="workbench-inspector" aria-label="Inspector">
                {!inspector.selection && (
                  <p className="muted">
                    Select an object, result column or operation to inspect its definition and
                    evidence.
                  </p>
                )}
                <div ref={inspector.setHost} />
                {inspector.selection && (
                  <button className="inspector-expand" onClick={inspector.expand}>
                    {inspector.expanded ? "Return to workspace" : "Open detail in workspace"}
                  </button>
                )}
              </aside>
            </section>
            <section
              role="tabpanel"
              id="context-assistant"
              aria-labelledby="context-assistant-tab"
              hidden={plane.tab !== "assistant"}
            >
              <aside className="workbench-inspector" aria-label="Assistant">
                <h2>Assistant</h2>
                <p>No assistant connector is configured for this workspace.</p>
                <p>No context attached.</p>
                <label>
                  Message
                  <textarea disabled placeholder="Assistant unavailable" />
                </label>
                <button disabled>Send</button>
              </aside>
            </section>
          </div>
        </section>
      </div>
    </Interface.Provider>
  );
}

export function selectedScreen(definition: Definition, path: string) {
  return definition.screens.find((screen) =>
    path === "/" ? screen.name === definition.entry : screen.path === path,
  );
}
