import { afterEach, describe, expect, test, vi } from "vite-plus/test";
import {
  StatementReader,
  readDefinition,
  readTransport,
  validateReadResponse,
  type ReadTransport,
  type ResultView,
} from "./read";
import type { ReadRequest, ReadResponse } from "./read-types";
const id = "a".repeat(32);
afterEach(() => vi.unstubAllGlobals());
function result(overrides: Partial<ResultView> = {}): ReadResponse {
  return {
    result: {
      id,
      view: {
        definition: readDefinition,
        result: "b".repeat(64),
        columns: [{ name: "n", type: { uint128: {} }, nullable: false, optional: false }],
        rows: [[{ value: { atom: { unsigned: "340282366920938463463374607431768211455" } } }]],
        observation: '{"metadata":{}}',
        observation_kind: "metadata",
        start: "0",
        delivered: "1",
        complete_rows: "1",
        stopped: "complete",
        ...overrides,
      },
    },
  };
}
describe("shared statement reader", () => {
  test("pre-dispatch throttling preserves the original statement and has a finite retry budget", async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce(Response.json({ err: "RateLimited" }, { status: 429 }))
      .mockResolvedValueOnce(Response.json(result()));
    vi.stubGlobal("fetch", fetcher);
    const reader = new StatementReader("SHOW TABLES", readTransport, id);
    await reader.run();
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(fetcher.mock.calls[0]?.[1].body).toBe(fetcher.mock.calls[1]?.[1].body);
    fetcher.mockImplementation(async () => Response.json({ err: "RateLimited" }, { status: 429 }));
    await expect(reader.refresh()).rejects.toMatchObject({ status: 429, code: "RateLimited" });
    expect(fetcher).toHaveBeenCalledTimes(6);
  });

  test("capacity refusals and uncertain responses never replay SQL", async () => {
    const fetcher = vi.fn();
    vi.stubGlobal("fetch", fetcher);
    for (const [status, err] of [
      [429, "ReadWorkspaceCapacity"],
      [503, "IncompleteResult"],
      [403, "Forbidden"],
    ] as const) {
      fetcher.mockResolvedValueOnce(Response.json({ err }, { status }));
      await expect(
        new StatementReader("SHOW TABLES", readTransport, id).run(),
      ).rejects.toMatchObject({ status, code: err });
    }
    fetcher.mockRejectedValueOnce(new Error("reply lost"));
    await expect(new StatementReader("SHOW TABLES", readTransport, id).run()).rejects.toThrow(
      "reply lost",
    );
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  test("cancelling a throttled request prevents another dispatch", async () => {
    const controller = new AbortController();
    const fetcher = vi.fn(async () => {
      setTimeout(() => controller.abort(), 10);
      return Response.json({ err: "RateLimited" }, { status: 429 });
    });
    vi.stubGlobal("fetch", fetcher);
    await expect(
      readTransport({ definition: readDefinition, action: { describe: {} } }, controller.signal),
    ).rejects.toThrow();
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  test("throttling does not renew the request deadline", async () => {
    vi.useFakeTimers();
    const timeout = vi.spyOn(AbortSignal, "timeout").mockImplementation((milliseconds) => {
      const controller = new AbortController();
      setTimeout(() => controller.abort(new Error("request deadline")), milliseconds);
      return controller.signal;
    });
    try {
      const fetcher = vi.fn(async () => {
        await new Promise((resolve) => setTimeout(resolve, 5800));
        return Response.json({ err: "RateLimited" }, { status: 429 });
      });
      vi.stubGlobal("fetch", fetcher);
      const completed = expect(
        readTransport({ definition: readDefinition, action: { describe: {} } }),
      ).rejects.toThrow("request deadline");
      await vi.advanceTimersByTimeAsync(6050);
      await completed;
      expect(fetcher).toHaveBeenCalledTimes(1);
    } finally {
      timeout.mockRestore();
      vi.useRealTimers();
    }
  });

  test("validates full-width cells, terminal coverage and empty results", () => {
    expect(validateReadResponse(result())).toBe(true);
    expect(validateReadResponse(result({ rows: [], delivered: "0", complete_rows: "0" }))).toBe(
      true,
    );
    expect(validateReadResponse(result({ complete_rows: null }))).toBe(false);
    expect(validateReadResponse(result({ delivered: "2" }))).toBe(false);
    expect(
      validateReadResponse(
        result({
          rows: [[{ value: { atom: { unsigned: "340282366920938463463374607431768211456" } } }]],
        }),
      ),
    ).toBe(false);
    expect(
      validateReadResponse({
        result: {
          id,
          view: { ...(result() as { result: { view: ResultView } }).result.view, unexpected: 1 },
        },
      }),
    ).toBe(false);
  });
  test("lost submission observes the original identity without another execution", async () => {
    const actions: ReadRequest["action"][] = [];
    const transport: ReadTransport = async (request) => {
      actions.push(request.action);
      if ("run" in request.action) throw new Error("reply lost");
      return result();
    };
    const reader = new StatementReader("SHOW TABLES", transport, id);
    await expect(reader.run()).rejects.toThrow("reply lost");
    expect(() => reader.run()).toThrow();
    expect((await reader.refresh()).complete_rows).toBe("1");
    expect(actions.map((action) => Object.keys(action)[0])).toEqual(["run", "observe"]);
    expect(actions[1]).toEqual({ observe: id });
  });
  test("a lost next window retries its original position and rejects substitution", async () => {
    const actions: ReadRequest["action"][] = [];
    let fail = true;
    const transport: ReadTransport = async (request) => {
      actions.push(request.action);
      if ("next" in request.action) {
        if (fail) {
          fail = false;
          throw new Error("lost");
        }
        return result({ start: "1", delivered: "2", complete_rows: "2" });
      }
      if ("observe" in request.action) return result({ result: "c".repeat(64) });
      return result({ complete_rows: null, stopped: "row_limit" });
    };
    const reader = new StatementReader("SELECT n FROM items", transport, id);
    await reader.run();
    await expect(reader.next()).rejects.toThrow("lost");
    await reader.next();
    expect(actions[1]).toEqual(actions[2]);
    await expect(reader.refresh()).rejects.toThrow("ResultIdentityChanged");
  });
  test("closure discards an in-flight result and never creates replacement work", async () => {
    let resolve!: (value: ReadResponse) => void;
    const actions: ReadRequest["action"][] = [];
    const transport: ReadTransport = async (request) => {
      actions.push(request.action);
      return "close" in request.action
        ? { closed: {} }
        : new Promise((done) => {
            resolve = done;
          });
    };
    const reader = new StatementReader("SHOW TABLES", transport, id);
    const pending = reader.run();
    await reader.close();
    resolve(result());
    await expect(pending).rejects.toThrow("ResultClosed");
    await expect(reader.refresh()).rejects.toThrow("ResultUnavailable");
    expect(actions.map((action) => Object.keys(action)[0])).toEqual(["run", "close"]);
  });
});
