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
