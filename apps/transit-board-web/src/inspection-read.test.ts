import { afterEach, expect, test, vi } from "vite-plus/test";
import { BoardError } from "@rey/transit-board-client";
import { retryInspectionRead } from "./inspection-read";

afterEach(() => vi.useRealTimers());

test("staggered retries recover a throttled observation before the next poll", async () => {
  vi.useFakeTimers();
  const controller = new AbortController();
  const value = { revision: 47 };
  const throttled = vi.fn();
  const load = vi
    .fn()
    .mockRejectedValueOnce(new BoardError(429, "RateLimited"))
    .mockRejectedValueOnce(new BoardError(429, "RateLimited"))
    .mockResolvedValue(value);
  const result = retryInspectionRead(load, controller.signal, () => true, throttled);
  await vi.advanceTimersByTimeAsync(249);
  expect(load).toHaveBeenCalledTimes(1);
  expect(throttled).toHaveBeenCalledTimes(1);
  await vi.advanceTimersByTimeAsync(1);
  expect(load).toHaveBeenCalledTimes(2);
  expect(throttled).toHaveBeenCalledTimes(2);
  await vi.advanceTimersByTimeAsync(250);
  expect(await result).toBe(value);
  expect(load).toHaveBeenCalledTimes(3);
  expect(vi.getTimerCount()).toBe(0);
});

test("persistent throttling ends after three retries", async () => {
  vi.useFakeTimers();
  const cause = new BoardError(429, "RateLimited");
  const load = vi.fn().mockRejectedValue(cause);
  const result = retryInspectionRead(load, new AbortController().signal, () => true);
  const rejected = expect(result).rejects.toBe(cause);
  await vi.runAllTimersAsync();
  await rejected;
  expect(load).toHaveBeenCalledTimes(4);
  expect(vi.getTimerCount()).toBe(0);
});

test("denial, stale continuations and unclassified failures do not retry", async () => {
  vi.useFakeTimers();
  for (const cause of [
    new BoardError(403, "Forbidden"),
    new BoardError(409, "QueryExpired"),
    new BoardError(410, "HistoryReclaimed"),
    new BoardError(503, "Unavailable"),
    new BoardError(429, "InvalidResponse"),
    new Error("offline"),
  ]) {
    const load = vi.fn().mockRejectedValue(cause);
    await expect(retryInspectionRead(load, new AbortController().signal, () => true)).rejects.toBe(
      cause,
    );
    expect(load).toHaveBeenCalledTimes(1);
  }
  expect(vi.getTimerCount()).toBe(0);
});

test("aborting a pending retry cancels its timer and starts no more reads", async () => {
  vi.useFakeTimers();
  const controller = new AbortController();
  const load = vi.fn().mockRejectedValue(new BoardError(429, "RateLimited"));
  const result = retryInspectionRead(load, controller.signal, () => true);
  const rejected = expect(result).rejects.toMatchObject({ name: "AbortError" });
  await vi.advanceTimersByTimeAsync(0);
  controller.abort();
  await rejected;
  await vi.runAllTimersAsync();
  expect(load).toHaveBeenCalledTimes(1);
  expect(vi.getTimerCount()).toBe(0);
});

test("hiding while waiting stops acquisition before the next attempt", async () => {
  vi.useFakeTimers();
  let visible = true;
  const load = vi.fn().mockRejectedValue(new BoardError(429, "RateLimited"));
  const result = retryInspectionRead(load, new AbortController().signal, () => visible);
  const rejected = expect(result).rejects.toMatchObject({ name: "AbortError" });
  await vi.advanceTimersByTimeAsync(0);
  visible = false;
  await vi.runAllTimersAsync();
  await rejected;
  expect(load).toHaveBeenCalledTimes(1);
});

test("already aborted or hidden owners do not acquire a first observation", async () => {
  const load = vi.fn();
  const controller = new AbortController();
  controller.abort();
  await expect(retryInspectionRead(load, controller.signal, () => true)).rejects.toMatchObject({
    name: "AbortError",
  });
  await expect(
    retryInspectionRead(load, new AbortController().signal, () => false),
  ).rejects.toMatchObject({ name: "AbortError" });
  expect(load).not.toHaveBeenCalled();
});
