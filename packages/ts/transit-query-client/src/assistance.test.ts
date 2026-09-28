import { afterEach, expect, test, vi } from "vite-plus/test";
import {
  AssistanceReader,
  applySuggestion,
  byteCursor,
  type AssistanceState,
  type Assisted,
} from "./assistance";
import { QueryError, type Transport } from "./transport";
const suggestion = (generation: number): Assisted["response"] => ({
  version: 1,
  generation,
  profile: "unified_v2",
  resource: 1,
  contract: Array(32).fill(7),
  resource_revision: 2,
  policy_revision: "1",
  range: { start: 7, end: 10, quoted: false },
  items: [{ text: '"value"', kind: "column", detail: "int64" }],
});
afterEach(() => vi.useRealTimers());
test("UTF-16 cursors and byte replacement preserve Unicode, suffixes and no effects", () => {
  expect(byteCursor("-- 🌱\nSELECT ", 13)).toBe(15);
  expect(() => byteCursor("🌱", 1)).toThrow("InvalidSqlCursor");
  const selected = {
    input: { sql: "SELECT val FROM items", cursor: 9, generation: 1 },
    response: suggestion(1),
  };
  expect(applySuggestion(selected.input.sql, selected, 0)).toEqual({
    sql: 'SELECT "value" FROM items',
    cursor: 14,
  });
  expect(() => applySuggestion("SELECT other", selected, 0)).toThrow("StaleAssistance");
  expect(() =>
    applySuggestion(selected.input.sql, { ...selected, response: suggestion(2) }, 0),
  ).toThrow("StaleAssistance");
});
test("one outstanding read coalesces edits and discards late generations", async () => {
  vi.useFakeTimers();
  const states: AssistanceState[] = [];
  let release: ((response: Awaited<ReturnType<Transport>>) => void) | undefined;
  const query = vi.fn<Transport>(
    () =>
      new Promise((resolve) => {
        release = resolve;
      }),
  );
  const reader = new AssistanceReader(query, 1, null, (value) => states.push(value), vi.fn());
  reader.edit("SELECT val", 10, true);
  await vi.advanceTimersByTimeAsync(200);
  reader.edit("SELECT valu", 11);
  reader.edit("SELECT value", 12);
  await vi.advanceTimersByTimeAsync(500);
  expect(query).toHaveBeenCalledTimes(1);
  release!({ assistance: suggestion(1) });
  await vi.advanceTimersByTimeAsync(200);
  expect(states.some((value) => value.result)).toBe(false);
  expect(query).toHaveBeenCalledTimes(2);
  expect(query.mock.calls[1]?.[0]).toEqual({
    assist: { sql: "SELECT value", cursor: 12, generation: 3, mode: "sql" },
  });
  release!({ assistance: { ...suggestion(3), range: { start: 7, end: 12, quoted: false } } });
  await vi.advanceTimersByTimeAsync(1);
  expect(states.at(-1)?.result?.input.generation).toBe(3);
  reader.dispose();
  await vi.advanceTimersByTimeAsync(10000);
  expect(query).toHaveBeenCalledTimes(2);
});
test("current denial and changed contracts clear suggestions without dispatching", async () => {
  vi.useFakeTimers();
  const states: AssistanceState[] = [],
    denied = vi.fn();
  const query = vi
    .fn<Transport>()
    .mockResolvedValueOnce({ assistance: suggestion(1) })
    .mockRejectedValueOnce(new QueryError(403, "Forbidden"));
  const reader = new AssistanceReader(
    query,
    1,
    Array(32).fill(7),
    (value) => states.push(value),
    denied,
  );
  reader.edit("SELECT val", 10, true);
  await vi.advanceTimersByTimeAsync(200);
  expect(states.at(-1)?.result).not.toBeNull();
  await vi.advanceTimersByTimeAsync(5000);
  expect(states.at(-1)?.result).toBeNull();
  expect(denied).toHaveBeenCalledTimes(1);
  reader.dispose();
  const other = new AssistanceReader(
    async () => ({ assistance: suggestion(1) }),
    1,
    Array(32).fill(8),
    (value) => states.push(value),
    vi.fn(),
  );
  other.edit("SELECT val", 10, true);
  await vi.advanceTimersByTimeAsync(200);
  expect(states.at(-1)?.error).toBe("DraftSourceChanged");
  other.dispose();
});
