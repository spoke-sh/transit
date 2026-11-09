import { afterEach, expect, test, vi } from "vite-plus/test";
import { readDefinition } from "@transit/query-client";
import { initialStatement, statementTransition } from "./statement-state";
import { StatementOwner } from "./statement-owner";
afterEach(() => {
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

test("only explicit Run starts new work, duplicate clicks and stale replies are inert", () => {
  const first = statementTransition(initialStatement(), { type: "run", reader: "original" });
  expect(first.effects.at(-1)?.type).toBe("run");
  expect(statementTransition(first.state, { type: "run", reader: "replacement" }).state).toEqual(
    first.state,
  );
  const hidden = statementTransition(first.state, { type: "visibility", value: false });
  const visible = statementTransition(hidden.state, { type: "visibility", value: true });
  expect(visible.effects.at(-1)?.type).toBe("observe");
  expect(visible.state.reader).toBe("original");
  expect(
    statementTransition(visible.state, {
      type: "received",
      reader: "original",
      generation: first.state.generation,
    }).state,
  ).toEqual(visible.state);
});

test("lost Run reply reconnects to the same shared reader without resubmitting SQL", async () => {
  vi.useFakeTimers();
  const calls: Record<string, unknown>[] = [];
  let id = "";
  const fetcher = vi.fn(async (_path, options) => {
    const action = JSON.parse(options.body).action;
    calls.push(action);
    if (action.run) {
      id = action.run.id;
      throw new Error("reply lost");
    }
    if (action.close) return Response.json({ closed: {} });
    return Response.json({
      result: {
        id,
        view: {
          definition: readDefinition,
          result: "b".repeat(64),
          columns: [
            {
              name: "n",
              type: { int64: {} },
              nullable: false,
              optional: false,
              max_characters: null,
            },
          ],
          rows: [],
          observation: '{"metadata":{}}',
          observation_kind: "metadata",
          start: "0",
          delivered: "0",
          complete_rows: "0",
          stopped: "complete",
        },
      },
    });
  });
  vi.stubGlobal("fetch", fetcher);
  const owner = new StatementOwner(
    () => {},
    () => {},
  );
  owner.run("SHOW TABLES", null);
  owner.run("SELECT * FROM replacement", null);
  await vi.advanceTimersByTimeAsync(0);
  expect(owner.state.failure?.kind).toBe("unavailable");
  owner.send({ type: "availability", value: false });
  await vi.advanceTimersByTimeAsync(30000);
  expect(calls).toHaveLength(1);
  owner.send({ type: "availability", value: true });
  await vi.advanceTimersByTimeAsync(0);
  expect(calls).toEqual([
    { run: { id, sql: "SHOW TABLES", expected_definition: null } },
    { observe: id },
  ]);
  expect(owner.view?.complete_rows).toBe("0");
  owner.send({ type: "dispose" });
  await vi.advanceTimersByTimeAsync(0);
  expect(calls.at(-1)).toEqual({ close: id });
});

test("malformed results require action and lost close replies remain visibly unconfirmed", async () => {
  vi.useFakeTimers();
  const calls: Record<string, unknown>[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (_path, options) => {
      const action = JSON.parse(options.body).action;
      calls.push(action);
      if (action.close) throw new Error("lost cleanup reply");
      return new Response("{malformed", { headers: { "content-type": "application/json" } });
    }),
  );
  const owner = new StatementOwner(
    () => {},
    () => {},
  );
  owner.run("SHOW TABLES", null);
  await vi.advanceTimersByTimeAsync(0);
  expect(owner.state.failure?.kind).toBe("incompatible");
  expect(owner.view).toBeNull();
  await vi.advanceTimersByTimeAsync(60000);
  expect(calls).toHaveLength(1);
  owner.send({ type: "close" });
  await vi.advanceTimersByTimeAsync(0);
  expect(owner.cleanup).toContain("unconfirmed");
  expect(owner.state.reader).toBeNull();
  await vi.advanceTimersByTimeAsync(60000);
  expect(calls).toHaveLength(2);
  owner.send({ type: "dispose" });
});

test("a changed shared result identity clears rows and stops automatic observation", async () => {
  vi.useFakeTimers();
  let id = "";
  const fetcher = vi.fn(async (_path, options) => {
    const action = JSON.parse(options.body).action;
    if (action.close) return Response.json({ closed: {} });
    if (action.run) id = action.run.id;
    return Response.json({
      result: {
        id,
        view: {
          definition: readDefinition,
          result: (action.run ? "b" : "c").repeat(64),
          columns: [
            {
              name: "n",
              type: { int64: {} },
              nullable: false,
              optional: false,
              max_characters: null,
            },
          ],
          rows: [],
          observation: '{"metadata":{}}',
          observation_kind: "metadata",
          start: "0",
          delivered: "0",
          complete_rows: "0",
          stopped: "complete",
        },
      },
    });
  });
  vi.stubGlobal("fetch", fetcher);
  const owner = new StatementOwner(
    () => {},
    () => {},
  );
  owner.run("SHOW TABLES", null);
  await vi.advanceTimersByTimeAsync(5000);
  expect(owner.state.failure).toEqual({
    kind: "incompatible",
    code: "ResultIdentityChanged",
    retryable: false,
  });
  expect(owner.view).toBeNull();
  expect(owner.state.reader).toBe(id);
  await vi.advanceTimersByTimeAsync(60000);
  expect(fetcher).toHaveBeenCalledTimes(2);
  owner.send({ type: "dispose" });
  await vi.advanceTimersByTimeAsync(0);
});
