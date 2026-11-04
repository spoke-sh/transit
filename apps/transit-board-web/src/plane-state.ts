export type Side = "left" | "right";
export type Plane = {
  left: boolean;
  right: boolean;
  last: Side;
  tab: "inspector" | "assistant";
  width: number;
  detail: boolean;
};
export type PlaneEvent =
  | { type: "toggle"; side: Side }
  | { type: "open"; side: Side }
  | { type: "fold"; side: Side }
  | { type: "tab"; tab: Plane["tab"] }
  | { type: "resize"; width: number }
  | { type: "detail" };
export const initialPlane = (width: number): Plane => ({
  left: false,
  right: false,
  last: "right",
  tab: "inspector",
  width,
  detail: false,
});
/** Requested expansion survives constrained geometry. No execution state or effects. */
export function planeTransition(state: Plane, event: PlaneEvent): Plane {
  switch (event.type) {
    case "resize":
      return { ...state, width: event.width };
    case "tab":
      return { ...state, tab: event.tab, right: true, last: "right", detail: false };
    case "detail":
      return { ...state, right: true, last: "right", detail: !state.detail };
    case "fold":
      return { ...state, [event.side]: false, detail: false };
    case "open":
      return { ...state, [event.side]: true, last: event.side, detail: false };
    case "toggle":
      return { ...state, [event.side]: !state[event.side], last: event.side, detail: false };
  }
}
export function planeLayout(state: Plane): {
  left: boolean;
  right: boolean;
  takeover: Side | null;
} {
  const constrained = state.width < 1232;
  const left =
    !state.detail && state.left && !(constrained && state.right && state.last === "right");
  const right = state.right && !(constrained && state.left && state.last === "left");
  return {
    left,
    right,
    takeover: state.detail
      ? "right"
      : state.width < 800
        ? right
          ? "right"
          : left
            ? "left"
            : null
        : null,
  };
}
