import { describe, expect, it } from "vite-plus/test";
import { initialPlane, planeLayout, planeTransition } from "./plane-state";
describe("accordion plane", () => {
  it("remembers both requested panes across constrained and narrow layouts", () => {
    let state = planeTransition(initialPlane(1440), { type: "open", side: "left" });
    state = planeTransition(state, { type: "open", side: "right" });
    expect(planeLayout(state)).toEqual({ left: true, right: true, takeover: null });
    state = planeTransition(state, { type: "resize", width: 1000 });
    expect(planeLayout(state)).toEqual({ left: false, right: true, takeover: null });
    state = planeTransition(state, { type: "open", side: "left" });
    state = planeTransition(state, { type: "resize", width: 390 });
    expect(planeLayout(state)).toEqual({ left: true, right: false, takeover: "left" });
    state = planeTransition(state, { type: "resize", width: 1440 });
    expect(planeLayout(state)).toEqual({ left: true, right: true, takeover: null });
  });
  it("folds the requested side explicitly and preserves the selected tab", () => {
    let state = planeTransition(initialPlane(390), { type: "tab", tab: "assistant" });
    state = planeTransition(state, { type: "fold", side: "right" });
    expect(planeLayout(state).takeover).toBeNull();
    state = planeTransition(state, { type: "open", side: "right" });
    expect(state.tab).toBe("assistant");
    expect(planeLayout(state).takeover).toBe("right");
  });
});

it("opens a constrained requested side and returns all the way to work on narrow Back", () => {
  let state = planeTransition(initialPlane(390), { type: "open", side: "left" });
  state = planeTransition(state, { type: "open", side: "right" });
  state = planeTransition(state, { type: "toggle", side: "left" });
  expect(planeLayout(state).takeover).toBe("left");
  state = planeTransition(state, { type: "fold", side: "left" });
  expect(planeLayout(state)).toEqual({ left: false, right: false, takeover: null });
});
