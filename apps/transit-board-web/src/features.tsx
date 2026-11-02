import { lazy } from "react";

// Declare feature boundaries once. Selecting a route or published renderer loads
// its implementation; navigation links and definition validation do not preload it.
export const CatalogPage = /* @__PURE__ */ lazy(() =>
  import("./catalog").then((module) => ({ default: module.CatalogPage })),
);
export const DatasetPage = /* @__PURE__ */ lazy(() =>
  import("./dataset").then((module) => ({ default: module.DatasetPage })),
);
export const WorkbookPage = /* @__PURE__ */ lazy(() =>
  import("./workbook").then((module) => ({ default: module.WorkbookPage })),
);
export const Operations = /* @__PURE__ */ lazy(() =>
  import("./operations").then((module) => ({ default: module.Operations })),
);
export const Activity = /* @__PURE__ */ lazy(() =>
  import("./activity").then((module) => ({ default: module.Activity })),
);
export const Atlas = /* @__PURE__ */ lazy(() =>
  import("./atlas").then((module) => ({ default: module.Atlas })),
);
export const DefinitionEditor = /* @__PURE__ */ lazy(() =>
  import("./definition").then((module) => ({ default: module.DefinitionEditor })),
);
export const UnifiedWorkspace = /* @__PURE__ */ lazy(() =>
  import("./unified-workspace").then((module) => ({ default: module.UnifiedWorkspace })),
);
export const RelationalWorkspace = /* @__PURE__ */ lazy(() =>
  import("./relational-workspace").then((module) => ({ default: module.RelationalWorkspace })),
);
export const Overview = /* @__PURE__ */ lazy(() =>
  import("./process-evidence").then((module) => ({ default: module.Overview })),
);
export const ProcessPage = /* @__PURE__ */ lazy(() =>
  import("./process-evidence").then((module) => ({ default: module.ProcessPage })),
);
export const JourneyPage = /* @__PURE__ */ lazy(() =>
  import("./process-evidence").then((module) => ({ default: module.JourneyPage })),
);
export const ResourcePage = /* @__PURE__ */ lazy(() =>
  import("./process-evidence").then((module) => ({ default: module.ResourcePage })),
);
export const LiveTable = /* @__PURE__ */ lazy(() =>
  import("./live-table").then((module) => ({ default: module.LiveTable })),
);

export const Computations = /* @__PURE__ */ lazy(() =>
  import("./computations").then((module) => ({ default: module.Computations })),
);
