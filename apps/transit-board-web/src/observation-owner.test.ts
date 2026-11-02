import { afterEach, expect, test, vi } from "vite-plus/test";
import { ObservationOwner } from "./observation-owner";
import { QueryError } from "@transit/query-client";
afterEach(() => vi.useRealTimers());

test("hide/show and scope disposal fence even transports that ignore cancellation", async () => {
  vi.useFakeTimers();
  const replies: ((value: string) => void)[] = [];
  const read = vi.fn(() => new Promise<string>((resolve) => replies.push(resolve)));
  const owner = new ObservationOwner(read, () => {});
  owner.send({ type: "read" });
  owner.send({ type: "read" });
  await vi.advanceTimersByTimeAsync(0);
  expect(read).toHaveBeenCalledTimes(1);
  owner.send({ type: "hide" });
  owner.send({ type: "show" });
  await vi.advanceTimersByTimeAsync(0);
  replies[1]!("current");
  await vi.advanceTimersByTimeAsync(0);
  replies[0]!("obsolete");
  await vi.advanceTimersByTimeAsync(0);
  expect(owner.state.value).toBe("current");
  owner.send({ type: "dispose" });
  await vi.advanceTimersByTimeAsync(60000);
  expect(owner.state.value).toBeNull();
  expect(read).toHaveBeenCalledTimes(2);
});

test("denial clears all disclosure and stops automatic effects until explicit retry", async () => {
  vi.useFakeTimers();
  const read = vi
    .fn()
    .mockResolvedValueOnce("protected")
    .mockRejectedValueOnce(new QueryError(403, "Forbidden"))
    .mockResolvedValue("authorized again");
  const owner = new ObservationOwner<string>(read, () => {});
  owner.send({ type: "read" });
  await vi.advanceTimersByTimeAsync(5000);
  expect(owner.state.value).toBeNull();
  expect(owner.state.failure?.kind).toBe("denied");
  await vi.advanceTimersByTimeAsync(60000);
  expect(read).toHaveBeenCalledTimes(2);
  owner.send({ type: "read" });
  await vi.advanceTimersByTimeAsync(0);
  expect(owner.state.value).toBe("authorized again");
  owner.send({ type: "dispose" });
});

test("deadlines reject late success and a replacement scope cannot revive the disposed owner", async () => {
  vi.useFakeTimers();
  let late!: (value: string) => void;
  const read = vi.fn(
    () =>
      new Promise<string>((resolve) => {
        late = resolve;
      }),
  );
  const changed = vi.fn();
  const owner = new ObservationOwner(read, changed);
  owner.send({ type: "read" });
  await vi.advanceTimersByTimeAsync(15000);
  expect(owner.state.failure?.code).toBe("ReadTimeout");
  late("late protected value");
  await vi.advanceTimersByTimeAsync(0);
  expect(owner.state.value).toBeNull();
  owner.send({ type: "dispose" });
  const calls = changed.mock.calls.length;
  const replacement = new ObservationOwner(
    async () => "replacement",
    () => {},
  );
  replacement.send({ type: "read" });
  await vi.advanceTimersByTimeAsync(0);
  expect(replacement.state.value).toBe("replacement");
  owner.send({ type: "received", generation: owner.state.generation, value: "obsolete" });
  expect(changed.mock.calls).toHaveLength(calls);
  replacement.send({ type: "dispose" });
});

test.each([
  [429, "RateLimited", "limited", 500],
  [503, "Unavailable", "unavailable", 10000],
  [0, "InvalidResponse", "incompatible", 0],
  [409, "IncompatibleDefinition", "incompatible", 0],
  [410, "QueryExpired", "expired", 0],
] as const)(
  "typed refusal %s %s clears data and owns its retry policy",
  async (status, code, kind, delay) => {
    vi.useFakeTimers();
    const read = vi
      .fn()
      .mockResolvedValueOnce("protected")
      .mockRejectedValueOnce(new QueryError(status, code))
      .mockResolvedValue("new");
    const owner = new ObservationOwner(read, () => {});
    owner.send({ type: "read" });
    await vi.advanceTimersByTimeAsync(5000);
    expect(owner.state.value).toBeNull();
    expect(owner.state.failure?.kind).toBe(kind);
    await vi.advanceTimersByTimeAsync(delay ? delay - 1 : 60000);
    expect(read).toHaveBeenCalledTimes(2);
    if (delay) {
      await vi.advanceTimersByTimeAsync(1);
      expect(read).toHaveBeenCalledTimes(3);
      expect(owner.state.value).toBe("new");
    }
    owner.send({ type: "dispose" });
  },
);
