import { afterEach, expect, test, vi } from "vite-plus/test";
import { RequestScheduler } from "./request-scheduler";
afterEach(() => vi.useRealTimers());
const deferred = () => {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
};

test("stalled reads cannot starve control; aborted active work keeps its permit until settlement", async () => {
  vi.useFakeTimers();
  const scheduler = new RequestScheduler(10);
  const first = deferred(),
    second = deferred();
  const abort = new AbortController();
  const order: string[] = [];
  const a = scheduler.run(
    "read",
    () => {
      order.push("a");
      return first.promise;
    },
    abort.signal,
  );
  const b = scheduler.run("read", () => {
    order.push("b");
    return second.promise;
  });
  const c = scheduler.run("read", async () => {
    order.push("c");
  });
  await vi.advanceTimersByTimeAsync(30);
  expect(order).toEqual(["a", "b"]);
  abort.abort();
  expect(scheduler.snapshot()).toEqual({ read: 2, control: 0, queued: 1 });
  await scheduler.run("control", async () => {
    order.push("close");
  });
  expect(order).toEqual(["a", "b", "close"]);
  first.resolve();
  await a;
  await vi.advanceTimersByTimeAsync(10);
  expect(order).toEqual(["a", "b", "close", "c"]);
  second.resolve();
  await Promise.all([b, c]);
  expect(scheduler.snapshot()).toEqual({ read: 0, control: 0, queued: 0 });
});

test("replaced queued scopes never dispatch; queue capacity is finite and listeners release", async () => {
  vi.useFakeTimers();
  const scheduler = new RequestScheduler(10);
  const aborts = Array.from({ length: 60 }, () => new AbortController());
  const work = vi.fn(async () => {});
  const pending = aborts.map((abort) => scheduler.run("read", work, abort.signal).catch(() => {}));
  await expect(scheduler.run("read", work)).rejects.toMatchObject({ code: "ReadQueueCapacity" });
  await scheduler.run("control", async () => {});
  aborts.forEach((abort) => abort.abort());
  await Promise.all(pending);
  await vi.runAllTimersAsync();
  expect(work).not.toHaveBeenCalled();
  expect(scheduler.snapshot()).toEqual({ read: 0, control: 0, queued: 0 });
});

test("public Board and SQL transports share permits through response body consumption", async () => {
  vi.useFakeTimers();
  const { request } = await import("@transit/board-client");
  const { StatementReader } = await import("@transit/query-client");
  const { setRequestScheduler } = await import("@transit/reactive-client/request-scheduling");
  const scheduler = new RequestScheduler(10);
  const restore = setRequestScheduler(scheduler.run);
  const bodies: (() => void)[] = [];
  let cancelled = 0;
  const fetcher = vi.fn(async (path: string) => {
    if (path.endsWith("sql-read")) return Response.json({ err: "QueryDisabled" }, { status: 404 });
    return new Response(
      new ReadableStream({
        start(controller) {
          bodies.push(() => {
            controller.enqueue(new TextEncoder().encode("{}"));
            controller.close();
          });
        },
        cancel() {
          cancelled += 1;
        },
      }),
    );
  });
  vi.stubGlobal("fetch", fetcher);
  try {
    const reads = Array.from({ length: 3 }, () =>
      request("/api/v1/deployment", (_value): _value is object => true),
    );
    await vi.advanceTimersByTimeAsync(30);
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(scheduler.snapshot()).toEqual({ read: 2, control: 0, queued: 1 });
    await expect(new StatementReader("SHOW TABLES").run()).rejects.toMatchObject({
      code: "QueryDisabled",
    });
    expect(fetcher).toHaveBeenCalledTimes(3);
    bodies[0]!();
    await vi.advanceTimersByTimeAsync(10);
    expect(fetcher).toHaveBeenCalledTimes(4);
    bodies[1]!();
    bodies[2]!();
    await Promise.all(reads);
    expect(cancelled).toBe(0);
    expect(scheduler.snapshot()).toEqual({ read: 0, control: 0, queued: 0 });
  } finally {
    restore();
    vi.unstubAllGlobals();
  }
});
