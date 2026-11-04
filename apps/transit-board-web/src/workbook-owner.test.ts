import { afterEach, describe, expect, test, vi } from "vite-plus/test";
import {
  WorkbookSession,
  type WorkbookCell,
  type WorkbookStatus,
  type WorkbookTransport,
  type WorkbookValidation,
} from "@transit/query-client/workbook";
import { QueryError } from "@transit/query-client/error";
import { WorkbookOwner } from "./workbook-owner";
const source = "1".repeat(32),
  count = "2".repeat(32),
  id = "a".repeat(32);
const cells: WorkbookCell[] = [
  { id: source, name: "source", sql: "SELECT * FROM metrics" },
  { id: count, name: "count", sql: 'SELECT COUNT(*) FROM "workbook.source"' },
];
const validation: WorkbookValidation = {
  bindings: [
    { cell: source, input: null },
    { cell: count, input: source },
  ],
  issue: null,
};
afterEach(() => vi.useRealTimers());
function setup() {
  vi.useFakeTimers();
  let state: WorkbookStatus = { id, sequence: 0, remaining: 32, results: [], failure: null };
  const transport = vi.fn<WorkbookTransport>(async (request) => {
    if ("close" in request.action) return { closed: {} };
    if ("evaluate" in request.action) {
      const input = request.action.evaluate;
      state = {
        ...state,
        sequence: input.sequence,
        remaining: state.remaining - 2,
        results: input.cells.map((cell, index) => ({
          cell: cell.id,
          name: cell.name,
          sql: cell.sql,
          result: String(index + 1).repeat(64),
          input: index === 0 ? null : "1".repeat(64),
        })),
      };
    }
    if ("observe" in request.action) {
      const cell = request.action.observe.cell;
      const binding = state.results.find((value) => value.cell === cell)!;
      return {
        result: {
          id,
          cell: binding.cell,
          sequence: state.sequence,
          binding,
          view: {
            definition: "" as never,
            result: binding.result,
            columns: [],
            rows: [],
            observation: "{}",
            observation_kind: "data",
            start: "0",
            delivered: "0",
            complete_rows: "0",
            stopped: "complete",
          },
        },
      };
    }
    return { status: state };
  });
  const validate = vi.fn(async () => validation);
  const denied = vi.fn();
  const owner = new WorkbookOwner(
    vi.fn(),
    denied,
    () => new WorkbookSession(transport, id),
    validate,
  );
  owner.activity(true);
  owner.edit(cells, source);
  const runs = () => transport.mock.calls.filter(([request]) => "evaluate" in request.action);
  return { owner, validate, transport, denied, runs };
}
describe("workbook scheduling and disclosure", () => {
  test("quiet time and unchanged blur coalesce; editing invalidates the dependent immediately", async () => {
    const { owner, runs } = setup();
    owner.enable();
    await vi.advanceTimersByTimeAsync(300);
    expect(runs()).toHaveLength(1);
    expect(owner.current(count)).toBe(true);
    const next = [{ ...cells[0]!, sql: "SELECT id FROM metrics" }, cells[1]!];
    owner.edit(next, source);
    expect(owner.current(count)).toBe(false);
    expect(owner.views.size).toBe(2);
    await owner.flush();
    await vi.advanceTimersByTimeAsync(300);
    await owner.flush();
    expect(runs()).toHaveLength(2);
    expect(owner.current(count)).toBe(true);
    await owner.dispose();
  });
  test("Run during blur validation keeps one explicit request for the same draft", async () => {
    const { owner, validate, runs } = setup();
    let resolve!: (value: WorkbookValidation) => void;
    validate.mockImplementationOnce(
      () =>
        new Promise((done) => {
          resolve = done;
        }),
    );
    const checking = owner.flush();
    await owner.flush(count);
    await owner.flush(count);
    resolve(validation);
    await checking;
    await vi.advanceTimersByTimeAsync(1);
    expect(runs()).toHaveLength(1);
    expect(owner.current(count)).toBe(true);
    await owner.dispose();
  });
  test("an edited or hidden draft cannot consume a Run queued during validation", async () => {
    const { owner, validate, runs } = setup();
    let resolve!: (value: WorkbookValidation) => void;
    validate.mockImplementationOnce(
      () =>
        new Promise((done) => {
          resolve = done;
        }),
    );
    const checking = owner.flush();
    await owner.flush(count);
    owner.edit([{ ...cells[0]!, sql: "SELECT id FROM metrics" }, cells[1]!], source);
    resolve(validation);
    await checking;
    await vi.advanceTimersByTimeAsync(300);
    expect(runs()).toHaveLength(0);
    owner.activity(false);
    await owner.flush(count);
    expect(runs()).toHaveLength(0);
    await owner.dispose();
  });
  test("IME composition waits; invalid graphs and pause never execute", async () => {
    const { owner, validate, runs } = setup();
    owner.enable();
    owner.composition(true);
    await vi.advanceTimersByTimeAsync(1000);
    await owner.flush();
    expect(runs()).toHaveLength(0);
    owner.composition(false);
    validate.mockResolvedValue({
      bindings: [],
      issue: { cell: source, code: "WorkbookCycle", path: [source, count, source] },
    });
    await vi.advanceTimersByTimeAsync(300);
    expect(runs()).toHaveLength(0);
    owner.pause();
    owner.edit(cells, source);
    validate.mockResolvedValue(validation);
    await vi.advanceTimersByTimeAsync(300);
    expect(runs()).toHaveLength(0);
    await owner.dispose();
  });
  test("inactive workbooks clear disclosure, pause Live and only reobserve on return", async () => {
    const { owner, runs } = setup();
    owner.enable();
    await vi.advanceTimersByTimeAsync(300);
    owner.edit([{ ...cells[0]!, sql: "SELECT id FROM metrics" }, cells[1]!], source);
    owner.activity(false);
    expect(owner.views.size).toBe(0);
    expect(owner.live).toBe(false);
    await vi.advanceTimersByTimeAsync(10000);
    expect(runs()).toHaveLength(1);
    owner.activity(true);
    await vi.advanceTimersByTimeAsync(1);
    expect(runs()).toHaveLength(1);
    expect(owner.current(source)).toBe(false);
    await owner.dispose();
  });
  test("removing an input drops its presentation and blocks its dependent without rerunning", async () => {
    const { owner, validate, runs } = setup();
    owner.enable();
    await vi.advanceTimersByTimeAsync(300);
    validate.mockResolvedValue({
      bindings: [{ cell: count, input: null }],
      issue: { cell: count, code: "MissingCellInput", path: [] },
    });
    owner.edit([cells[1]!], source);
    expect(owner.views.has(source)).toBe(false);
    expect(owner.views.has(count)).toBe(true);
    expect(owner.current(count)).toBe(false);
    await vi.advanceTimersByTimeAsync(300);
    expect(owner.validation?.issue?.code).toBe("MissingCellInput");
    expect(runs()).toHaveLength(1);
    await owner.dispose();
  });
  test("denial clears all relation disclosure and protected drafts", async () => {
    const { owner, transport, denied } = setup();
    owner.enable();
    await vi.advanceTimersByTimeAsync(300);
    transport.mockRejectedValueOnce(new QueryError(403, "Forbidden"));
    await owner.refresh();
    expect(owner.views.size).toBe(0);
    expect(owner.cells).toEqual([]);
    expect(owner.status).toBeNull();
    expect(denied).toHaveBeenCalledOnce();
    await owner.dispose();
  });
});
