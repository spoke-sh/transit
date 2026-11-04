import { describe, expect, test, vi } from "vite-plus/test";
import {
  WorkbookSession,
  validateWorkbookResponse,
  type WorkbookTransport,
  type WorkbookStatus,
} from "./workbook";
import { readDefinition } from "./read-types";
const id = "a".repeat(32);
const status = (sequence = 0): WorkbookStatus => ({
  id,
  sequence,
  remaining: 32,
  results: [],
  failure: null,
});
describe("temporary workbook session", () => {
  test("a lost evaluation can only observe its original sequence", async () => {
    const transport = vi
      .fn<WorkbookTransport>()
      .mockResolvedValueOnce({ status: status() })
      .mockRejectedValueOnce(new Error("lost reply"));
    const session = new WorkbookSession(transport, id);
    await session.open();
    await expect(session.evaluate([], [], false, false)).rejects.toThrow("lost reply");
    await expect(session.evaluate([], [], false, false)).rejects.toMatchObject({
      code: "InvalidTransition",
    });
    expect(transport).toHaveBeenCalledTimes(2);
    transport.mockResolvedValueOnce({ status: status(1) });
    await session.status();
    expect(transport.mock.calls[2]?.[0].action).toEqual({ status: { id, sequence: 1 } });
    expect(session.unresolved).toBe(false);
    transport.mockResolvedValueOnce({ closed: {} });
    await session.close();
    await session.close();
    expect(transport).toHaveBeenCalledTimes(4);
  });
  test("foreign or late status cannot clear uncertainty", async () => {
    const transport = vi
      .fn<WorkbookTransport>()
      .mockResolvedValue({ status: { ...status(), id: "b".repeat(32) } });
    const session = new WorkbookSession(transport, id);
    await expect(session.open()).rejects.toMatchObject({ code: "InvalidResponse" });
    expect(session.unresolved).toBe(true);
    transport.mockResolvedValue({ status: status(2) });
    await expect(session.status()).rejects.toMatchObject({ code: "InvalidResponse" });
    expect(session.sequence).toBe(0);
  });
  test("derived views retain the shared logical result validation", () => {
    const binding = {
      cell: id,
      name: "counted",
      sql: 'SELECT COUNT(*) FROM "workbook.source"',
      result: "c".repeat(64),
      input: "b".repeat(64),
    };
    const response = {
      result: {
        id,
        cell: id,
        sequence: 1,
        binding,
        view: {
          definition: readDefinition,
          result: binding.result,
          columns: [{ name: "n", type: { uint64: {} }, nullable: false, optional: false }],
          rows: [[{ value: { atom: { unsigned: "145" } } }]],
          observation: "{}",
          observation_kind: "data",
          start: "0",
          delivered: "1",
          complete_rows: "1",
          stopped: "complete",
        },
      },
    };
    expect(validateWorkbookResponse(response)).toBe(true);
    response.result.view.delivered = "100";
    expect(validateWorkbookResponse(response)).toBe(false);
    response.result.view.delivered = "1";
    response.result.binding.result = "d".repeat(64);
    expect(validateWorkbookResponse(response)).toBe(false);
  });
});
