import { describe, expect, test, vi } from "vite-plus/test";
import {
  WorkbookSession,
  validateWorkbookResponse,
  type WorkbookTransport,
  type WorkbookStatus,
} from "./workbook";
import { readDefinition } from "./read-types";
const id = "a".repeat(32);
function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: Error) => void;
  const promise = new Promise<T>((accept, fail) => {
    resolve = accept;
    reject = fail;
  });
  return { promise, resolve, reject };
}
const status = (sequence = 0): WorkbookStatus => ({
  id,
  sequence,
  remaining: 32,
  results: [],
  failure: null,
});
describe("temporary workbook session", () => {
  test.each(["open", "evaluate"] as const)("close waits for pending %s", async (action) => {
    const pending = deferred<Awaited<ReturnType<WorkbookTransport>>>();
    const transport = vi.fn<WorkbookTransport>();
    const session = new WorkbookSession(transport, id);
    if (action === "evaluate") {
      transport.mockResolvedValueOnce({ status: status() });
      await session.open();
    }
    transport.mockReturnValueOnce(pending.promise).mockResolvedValueOnce({ closed: {} });
    const admission = action === "open" ? session.open() : session.evaluate([], [], false, false);
    const closing = session.close();
    const repeated = session.close();
    await Promise.resolve();
    expect(transport.mock.calls.some(([request]) => "close" in request.action)).toBe(false);
    pending.resolve({ status: status(action === "open" ? 0 : 1) });
    await Promise.all([admission, closing, repeated]);
    expect(transport.mock.calls.filter(([request]) => "close" in request.action)).toHaveLength(1);
    await expect(session.evaluate([], [], false, false)).rejects.toMatchObject({
      code: "InvalidTransition",
    });
  });
  test("failed admission still closes the original identity and preserves cleanup uncertainty", async () => {
    const pending = deferred<Awaited<ReturnType<WorkbookTransport>>>();
    const transport = vi
      .fn<WorkbookTransport>()
      .mockReturnValueOnce(pending.promise)
      .mockRejectedValueOnce(new Error("close reply lost"));
    const session = new WorkbookSession(transport, id);
    const opening = expect(session.open()).rejects.toThrow("open reply lost");
    const closing = expect(session.close()).rejects.toThrow("close reply lost");
    pending.reject(new Error("open reply lost"));
    await Promise.all([opening, closing]);
    await expect(session.close()).rejects.toThrow("close reply lost");
    expect(transport.mock.calls.map(([request]) => request.action)).toEqual([
      { open: id },
      { close: id },
    ]);
  });
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
          columns: [
            {
              name: "n",
              type: { uint64: {} },
              nullable: false,
              optional: false,
              max_characters: null,
            },
          ],
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
