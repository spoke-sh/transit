import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useId,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { createPortal } from "react-dom";

export type Inspection = {
  owner: string;
  kind: "dataset" | "column" | "result";
  dimension: "definition" | "profile" | "evidence";
  result?: string;
  column?: number;
};
type InspectorState = {
  selection: Inspection | null;
  select: (selection: Inspection, trigger: HTMLButtonElement) => void;
  dimension: (dimension: Inspection["dimension"]) => void;
  release: (owner: string) => void;
  close: () => void;
  expanded: boolean;
  expand: () => void;
  host: HTMLElement | null;
  setHost: (element: HTMLDivElement | null) => void;
  navigation: boolean;
  toggleNavigation: () => void;
};
const Context = createContext<InspectorState | null>(null);
export function useInspector() {
  const state = useContext(Context);
  if (!state) throw new Error("Workbench inspection requires its layout");
  return state;
}

/** Retain only selection identities, never a second copy of authorized data. */
export function Workbench({
  children,
  available = true,
  className = "",
}: {
  children: ReactNode;
  available?: boolean;
  className?: string;
}) {
  const [selection, setSelection] = useState<Inspection | null>(null);
  const [expanded, setExpanded] = useState(false);
  const [navigation, setNavigation] = useState(false);
  const [host, setHost] = useState<HTMLDivElement | null>(null);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const root = useRef<HTMLElement | null>(null);
  const frame = useRef<number | null>(null);
  const focus = useCallback((read: () => HTMLElement | null) => {
    if (frame.current !== null) cancelAnimationFrame(frame.current);
    frame.current = requestAnimationFrame(() => {
      frame.current = null;
      read()?.focus({ preventScroll: true });
    });
  }, []);
  useEffect(
    () => () => {
      if (frame.current !== null) cancelAnimationFrame(frame.current);
    },
    [],
  );
  const close = useCallback(() => {
    setSelection(null);
    setExpanded(false);
    focus(() =>
      trigger.current?.isConnected && trigger.current.getClientRects().length
        ? trigger.current
        : (root.current?.querySelector("button") ?? null),
    );
  }, [focus]);
  const release = useCallback((owner: string) => {
    setSelection((previous) => (previous?.owner === owner ? null : previous));
  }, []);
  useEffect(() => {
    if (!available) {
      setSelection(null);
      setExpanded(false);
    }
  }, [available]);
  useEffect(() => {
    if (!selection) return;
    const escape = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !event.defaultPrevented) {
        event.preventDefault();
        close();
      }
    };
    document.addEventListener("keydown", escape);
    return () => document.removeEventListener("keydown", escape);
  }, [selection, close]);
  useEffect(() => {
    if (!selection) return;
    const narrow = window.matchMedia("(max-width: 1000px)");
    const resize = () => {
      if (narrow.matches) focus(() => root.current?.querySelector(".inspector-close") ?? null);
    };
    narrow.addEventListener("change", resize);
    return () => narrow.removeEventListener("change", resize);
  }, [selection, focus]);
  const value: InspectorState = {
    selection: available ? selection : null,
    select: (next, element) => {
      trigger.current = element;
      setSelection(next);
      setExpanded(false);
      setNavigation(false);
      if (window.matchMedia("(max-width: 1000px)").matches)
        focus(() => root.current?.querySelector(".inspector-close") ?? null);
    },
    dimension: (next) =>
      setSelection((previous) => (previous ? { ...previous, dimension: next } : null)),
    release,
    close,
    expanded,
    expand: () => {
      setExpanded((previous) => !previous);
      focus(() => root.current?.querySelector(".inspector-expand") ?? null);
    },
    host: available ? host : null,
    setHost,
    navigation,
    toggleNavigation: () => {
      setNavigation((previous) => !previous);
      if (window.matchMedia("(max-width: 1350px)").matches) {
        setSelection(null);
        setExpanded(false);
      }
    },
  };
  return (
    <Context.Provider value={value}>
      <main ref={root} className={"data-workbench " + className}>
        {children}
      </main>
    </Context.Provider>
  );
}

export function NavigatorToggle({ label = "Objects" }: { label?: string }) {
  const inspector = useInspector();
  return (
    <button aria-expanded={inspector.navigation} onClick={inspector.toggleNavigation}>
      {label}
    </button>
  );
}

export function WorkbenchBody({
  children,
  navigator,
}: {
  children: ReactNode;
  navigator?: ReactNode;
}) {
  const state = useInspector();
  const title = useId();
  return (
    <div
      className="workbench-body"
      data-inspecting={Boolean(state.selection)}
      data-expanded={state.expanded}
      data-navigation={state.navigation && Boolean(navigator)}
    >
      {navigator && (
        <nav
          className="workbench-navigator"
          aria-label="Object navigator"
          hidden={!state.navigation}
        >
          {navigator}
        </nav>
      )}
      <div className="workbench-canvas">{children}</div>
      <aside className="workbench-inspector" aria-labelledby={title} hidden={!state.selection}>
        <div className="inspector-controls">
          <h2 id={title}>Inspector</h2>
          <button className="inspector-close" onClick={state.close}>
            Close inspector
          </button>
        </div>
        <div ref={state.setHost} />
        <button className="inspector-expand" onClick={state.expand}>
          {state.expanded ? "Return to workspace" : "Open detail in workspace"}
        </button>
      </aside>
    </div>
  );
}

export function InspectorPanel({
  owner,
  title,
  subtitle,
  dimensions,
  children,
  summary,
}: {
  owner: string;
  title: string;
  subtitle: string;
  dimensions: { id: Inspection["dimension"]; label: string }[];
  children: ReactNode;
  summary?: ReactNode;
}) {
  const inspector = useInspector();
  if (inspector.selection?.owner !== owner || !inspector.host) return null;
  return createPortal(
    <>
      <p className="eyebrow">{subtitle}</p>
      <h3 className="inspector-subject">{title}</h3>
      {summary && <div className="inspector-summary">{summary}</div>}
      <div className="workbench-tabs inspector-dimensions" aria-label="Inspection dimensions">
        {dimensions.map((dimension) => (
          <button
            key={dimension.id}
            aria-pressed={inspector.selection?.dimension === dimension.id}
            onClick={() => inspector.dimension(dimension.id)}
          >
            {dimension.label}
          </button>
        ))}
      </div>
      {children}
    </>,
    inspector.host,
  );
}
