import { afterEach, expect, test, vi } from "vite-plus/test";
import { QueryError } from "@transit/query-client/error";
import type { ComputationResponse } from "@transit/board-client/computations";
import { ComputationOwner } from "./computation-owner";
// State-machine tests inject already validated owner responses. Contract tests
// independently exercise wire shape and identity checks.
const response = (revision: string, selected = false) =>
  ({
    binding: {
      namespace: 1,
      name: "projection",
      interpretation: {
        object: { scope: { realm: 1, resource: 1, catalog: "1" }, branch: "1", object: "3" },
        revision: "1",
        digest: "a".repeat(64),
      },
    },
    current: selected ? null : { state: "active" },
    completed: { revision, rows: revision === "4" ? "0" : "3" },
  }) as ComputationResponse;
afterEach(() => vi.useRealTimers());
test("a new completion preserves an explicit older selection and exact definition", async () => {
  vi.useFakeTimers();
  let latest = "1";
  const read = vi.fn(async (_selection, revision: string | null) =>
    response(revision ?? latest, revision !== null),
  );
  const owner = new ComputationOwner(
    { namespace: 1, name: "projection", expected: null },
    () => {},
    read,
  );
  owner.retry();
  await vi.advanceTimersByTimeAsync(0);
  owner.select("1");
  await vi.advanceTimersByTimeAsync(0);
  latest = "4";
  await vi.advanceTimersByTimeAsync(5000);
  expect(owner.state.current.value?.completed?.revision).toBe("4");
  expect(owner.state.current.value?.completed?.rows).toBe("0");
  expect(owner.state.selected.value?.completed?.revision).toBe("1");
  expect(read.mock.calls[1]![0].expected).toEqual(response("1").binding.interpretation);
  owner.select(null);
  expect(owner.state.revision).toBeNull();
  expect(owner.state.selected.value).toBeNull();
  owner.dispose();
  expect(vi.getTimerCount()).toBe(0);
});
test.each(["current", "selected"])(
  "%s denial clears both observations and fences late success",
  async (denied) => {
    vi.useFakeTimers();
    const pending: {
      revision: string | null;
      resolve: (value: ComputationResponse) => void;
      reject: (reason: unknown) => void;
    }[] = [];
    const read = vi.fn(
      (_selection, revision: string | null) =>
        new Promise<ComputationResponse>((resolve, reject) =>
          pending.push({ revision, resolve, reject }),
        ),
    );
    const owner = new ComputationOwner(
      { namespace: 1, name: "projection", expected: null },
      () => {},
      read,
    );
    owner.retry();
    await vi.advanceTimersByTimeAsync(0);
    pending[0]!.resolve(response("1"));
    await vi.advanceTimersByTimeAsync(0);
    owner.select("1");
    await vi.advanceTimersByTimeAsync(0);
    pending[1]!.resolve(response("1", true));
    await vi.advanceTimersByTimeAsync(5000);
    const a = [...pending]
      .reverse()
      .find((item) => (item.revision === null) === (denied === "current"))!;
    const b = [...pending]
      .reverse()
      .find((item) => (item.revision === null) !== (denied === "current"))!;
    a.reject(new QueryError(403, "Forbidden"));
    await vi.advanceTimersByTimeAsync(0);
    expect(owner.state.failure?.kind).toBe("denied");
    expect(owner.state.current.value).toBeNull();
    expect(owner.state.selected.value).toBeNull();
    b.resolve(response("4", b.revision !== null));
    await vi.advanceTimersByTimeAsync(60000);
    expect(read).toHaveBeenCalledTimes(4);
    expect(owner.state.current.value).toBeNull();
    expect(owner.state.selected.value).toBeNull();
    expect(vi.getTimerCount()).toBe(0);
    owner.dispose();
  },
);
test("missing revision leaves current completion visible without substituting rows", async () => {
  vi.useFakeTimers();
  const owner = new ComputationOwner(
    { namespace: 1, name: "projection", expected: null },
    () => {},
    async (_selection, revision) => {
      if (revision) throw new QueryError(404, "NotFound");
      return response("4");
    },
  );
  owner.retry();
  await vi.advanceTimersByTimeAsync(0);
  owner.select("9");
  await vi.advanceTimersByTimeAsync(0);
  expect(owner.state.current.value?.completed?.revision).toBe("4");
  expect(owner.state.selected.failure?.code).toBe("NotFound");
  expect(owner.state.selected.value).toBeNull();
  expect(owner.state.revision).toBe("9");
  owner.dispose();
});
test("hide, selection replacement and disposal cancel reads without resurrecting evidence", async () => {
  vi.useFakeTimers();
  const pending: ((value: ComputationResponse) => void)[] = [];
  const read = vi.fn(() => new Promise<ComputationResponse>((resolve) => pending.push(resolve)));
  const owner = new ComputationOwner(
    { namespace: 1, name: "projection", expected: null },
    () => {},
    read,
  );
  owner.retry();
  await vi.advanceTimersByTimeAsync(0);
  owner.visibility(true);
  pending[0]!(response("1"));
  await vi.advanceTimersByTimeAsync(0);
  expect(owner.state.current.value).toBeNull();
  owner.visibility(false);
  await vi.advanceTimersByTimeAsync(0);
  pending[1]!(response("4"));
  await vi.advanceTimersByTimeAsync(0);
  owner.select("1");
  await vi.advanceTimersByTimeAsync(0);
  owner.select("2");
  await vi.advanceTimersByTimeAsync(0);
  pending[3]!(response("2", true));
  pending[2]!(response("1", true));
  await vi.advanceTimersByTimeAsync(0);
  expect(owner.state.selected.value?.completed?.revision).toBe("2");
  owner.dispose();
  await vi.advanceTimersByTimeAsync(60000);
  expect(vi.getTimerCount()).toBe(0);
});
