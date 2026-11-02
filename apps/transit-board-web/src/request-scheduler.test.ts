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
  const aborts = Array.from({ length: 64 }, () => new AbortController());
  const work = vi.fn(async () => {});
  const pending = aborts.map((abort) => scheduler.run("read", work, abort.signal).catch(() => {}));
  await expect(scheduler.run("read", work)).rejects.toMatchObject({ code: "ReadQueueCapacity" });
  aborts.forEach((abort) => abort.abort());
  await Promise.all(pending);
  await vi.runAllTimersAsync();
  expect(work).not.toHaveBeenCalled();
  expect(scheduler.snapshot()).toEqual({ read: 0, control: 0, queued: 0 });
});
