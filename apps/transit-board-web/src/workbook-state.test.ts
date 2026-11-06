import { describe, expect, test } from "vite-plus/test";
import {
  extractReferencedCellNames,
  initialWorkbookModel,
  projectWorkbookDag,
  workbookModelTransition,
} from "./workbook-state";

describe("D5 composed workbook state machine", () => {
  test("extracts workbook cell references in quoted and unquoted forms", () => {
    expect(
      extractReferencedCellNames(
        'SELECT * FROM "workbook.shipments" JOIN workbook.delayed_shipments ON true',
      ),
    ).toEqual(["shipments", "delayed_shipments"]);
  });

  test("projects topological chains, independent cells, and reactive badges", () => {
    const cells = [
      { id: "c1", name: "shipments", sql: "SELECT * FROM shipments" },
      {
        id: "c2",
        name: "delayed_shipments",
        sql: 'SELECT * FROM "workbook.shipments" WHERE delay_min > 30',
      },
      {
        id: "c3",
        name: "by_region",
        sql: 'SELECT region, COUNT(*) FROM "workbook.delayed_shipments" GROUP BY region',
      },
      { id: "c4", name: "summary", sql: "SELECT COUNT(*) FROM carriers" },
    ];
    const currentSet = new Set(["c1"]);
    const viewSet = new Set(["c1", "c2", "c3"]);
    const dag = projectWorkbookDag(cells, {
      live: true,
      phase: "idle",
      validation: null,
      results: [],
      hasView: (id) => viewSet.has(id),
      isCurrent: (id) => currentSet.has(id),
    });

    expect(dag.chains).toHaveLength(1);
    expect(dag.chains[0]!.map((c) => c.name)).toEqual([
      "shipments",
      "delayed_shipments",
      "by_region",
    ]);
    expect(dag.independent.map((c) => c.name)).toEqual(["summary"]);

    expect(dag.cells.get("c1")?.executionState).toBe("Complete");
    expect(dag.cells.get("c1")?.badgeLabel).toBe("✓ Current draft");

    expect(dag.cells.get("c2")?.executionState).toBe("Waiting");
    expect(dag.cells.get("c2")?.outputFreshness).toBe("earlier");
    expect(dag.cells.get("c2")?.badgeLabel).toBe("Earlier result · Recalculating");

    expect(dag.cells.get("c3")?.executionState).toBe("Waiting");
    expect(dag.cells.get("c3")?.badgeLabel).toBe("Waiting for delayed_shipments");
  });

  test("advancing reactive watermark demotes current outputs to earlier and triggers live validation", () => {
    let { state } = workbookModelTransition(initialWorkbookModel(), "EnableLive");
    state = workbookModelTransition(state, "QuietTick").state;
    state = workbookModelTransition(state, "ValidateOk").state;
    state = workbookModelTransition(state, "EvalComplete").state;
    expect(state.sourceOut).toBe("current");
    expect(state.depOut).toBe("current");

    const next = workbookModelTransition(state, "WatermarkAdvance");
    expect(next.state.watermark).toBe(2);
    expect(next.state.sourceOut).toBe("earlier");
    expect(next.state.depOut).toBe("earlier");
    expect(next.state.phase).toBe("validating");
    expect(next.effects.action).toBe("validate");
  });
});
