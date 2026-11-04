import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useReducer,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { createPortal } from "react-dom";
import {
  initialPlane,
  planeLayout,
  planeTransition,
  type Plane,
  type PlaneEvent,
  type Side,
} from "./plane-state";

export type Inspection = {
  owner: string;
  kind: "dataset" | "column" | "result" | "storage" | "computation" | "cell";
  metric?: string;
  dimension: "definition" | "profile" | "evidence";
  result?: string;
  column?: number;
};
type InspectorState = {
  selection: Inspection | null;
  select: (selection: Inspection, trigger: HTMLButtonElement) => void;
  dimension: (dimension: Inspection["dimension"]) => void;
  release: (owner: string) => void;
  clear: () => void;
  close: () => void;
  expanded: boolean;
  expand: () => void;
  host: HTMLElement | null;
  setHost: (element: HTMLDivElement | null) => void;
  scopeHost: HTMLElement | null;
  setScopeHost: (element: HTMLDivElement | null) => void;
  navigationHost: HTMLElement | null;
  setNavigationHost: (element: HTMLDivElement | null) => void;
  navigation: boolean;
  toggleNavigation: () => void;
  plane: Plane;
  layout: ReturnType<typeof planeLayout>;
  dispatch: (event: PlaneEvent) => void;
  fold: (side: Side) => void;
};
const Context = createContext<InspectorState | null>(null);
export function useInspector() {
  const state = useContext(Context);
  if (!state) throw new Error("Workbench inspection requires its shell");
  return state;
}

/** Selection holds identities only. Authorized evidence remains with its owner. */
export function WorkbenchPlane({ children, route }: { children: ReactNode; route: string }) {
  const [plane, dispatch] = useReducer(
    planeTransition,
    document.documentElement.clientWidth,
    initialPlane,
  );
  const [selection, setSelection] = useState<Inspection | null>(null);
  const [host, setHost] = useState<HTMLDivElement | null>(null);
  const [scopeHost, setScopeHost] = useState<HTMLDivElement | null>(null);
  const [navigationHost, setNavigationHost] = useState<HTMLDivElement | null>(null);
  const triggers = useRef<Record<Side, HTMLElement | null>>({ left: null, right: null });
  const frame = useRef<number | null>(null);
  const layout = planeLayout(plane);
  const focus = useCallback((read: () => HTMLElement | null) => {
    if (frame.current !== null) cancelAnimationFrame(frame.current);
    frame.current = requestAnimationFrame(() => {
      frame.current = null;
      read()?.focus({ preventScroll: true });
    });
  }, []);
  const clear = useCallback(() => setSelection(null), []);
  useEffect(clear, [route, clear]);
  useEffect(() => {
    const resize = () => dispatch({ type: "resize", width: document.documentElement.clientWidth });
    window.addEventListener("resize", resize);
    const observer = new ResizeObserver(([entry]) => {
      if (entry) dispatch({ type: "resize", width: entry.contentRect.width });
    });
    observer.observe(document.documentElement);
    return () => {
      window.removeEventListener("resize", resize);
      observer.disconnect();
      if (frame.current !== null) cancelAnimationFrame(frame.current);
    };
  }, []);
  const fold = useCallback(
    (side: Side) => {
      dispatch({ type: "fold", side });
      focus(() =>
        triggers.current[side]?.isConnected && triggers.current[side].getClientRects().length
          ? triggers.current[side]
          : document.querySelector(`[data-plane-toggle="${side}"]`),
      );
    },
    [focus],
  );
  useEffect(() => {
    if (!layout.takeover) return;
    focus(() => document.querySelector(`[data-plane-back="${layout.takeover}"]`));
  }, [layout.takeover, focus]);
  useEffect(() => {
    const escape = (event: KeyboardEvent) => {
      if (event.key !== "Escape" || event.defaultPrevented || (!layout.left && !layout.right))
        return;
      event.preventDefault();
      fold(
        layout.takeover ??
          (plane.last === "left" && layout.left ? "left" : layout.right ? "right" : "left"),
      );
    };
    document.addEventListener("keydown", escape);
    return () => document.removeEventListener("keydown", escape);
  }, [layout.left, layout.right, layout.takeover, plane.last, fold]);
  const release = useCallback((owner: string) => {
    setSelection((previous) => (previous?.owner === owner ? null : previous));
  }, []);
  const value: InspectorState = {
    selection,
    clear,
    release,
    plane,
    layout,
    dispatch,
    fold,
    select: (next, element) => {
      triggers.current.right = element;
      setSelection(next);
      dispatch({ type: "tab", tab: "inspector" });
    },
    dimension: (dimension) =>
      setSelection((previous) => (previous ? { ...previous, dimension } : null)),
    close: () => fold("right"),
    expanded: plane.detail,
    expand: () => dispatch({ type: "detail" }),
    host,
    setHost,
    scopeHost,
    setScopeHost,
    navigationHost,
    setNavigationHost,
    navigation: layout.left,
    toggleNavigation: () => {
      triggers.current.left =
        document.activeElement instanceof HTMLElement ? document.activeElement : null;
      dispatch({ type: "toggle", side: "left" });
    },
  };
  return <Context.Provider value={value}>{children}</Context.Provider>;
}

export function Workbench({
  children,
  available = true,
  className = "",
}: {
  children: ReactNode;
  available?: boolean;
  className?: string;
}) {
  const { clear } = useInspector();
  useEffect(() => {
    if (!available) clear();
  }, [available, clear]);
  return <main className={"data-workbench " + className}>{children}</main>;
}
export function NavigatorToggle({ label = "Objects" }: { label?: string }) {
  const inspector = useInspector();
  return (
    <button
      aria-expanded={inspector.navigation}
      aria-controls="shell-navigation"
      onClick={inspector.toggleNavigation}
    >
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
  return (
    <div className="workbench-body">
      {navigator &&
        state.navigationHost &&
        createPortal(
          <nav className="workbench-navigator" aria-label="Object navigator">
            {navigator}
          </nav>,
          state.navigationHost,
        )}
      <div className="workbench-canvas">{children}</div>
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

export function WorkbenchScope({
  children,
  active = true,
}: {
  children: ReactNode;
  active?: boolean;
}) {
  const { scopeHost } = useInspector();
  return scopeHost && active
    ? createPortal(<div className="workbench-scope">{children}</div>, scopeHost)
    : null;
}
