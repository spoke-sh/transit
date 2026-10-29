import { expect, test } from "vite-plus/test";
import { profileResult } from "./result-profile";
import { readDefinition, type ResultView } from "@transit/query-client";
function view(rows: ResultView["rows"], type: ResultView["columns"][number]["type"]): ResultView {
  return {
    definition: readDefinition,
    result: "a".repeat(64),
    columns: [{ name: "value", type, nullable: true, optional: true }],
    rows,
    observation: "{}",
    observation_kind: "data",
    start: "100",
    delivered: String(100 + rows.length),
    complete_rows: null,
    stopped: "row_limit",
  };
}
test("profiles use exact integers beyond Number precision and only received rows", () => {
  const profile = profileResult(
    view(
      [
        [{ value: { atom: { unsigned: "18446744073709551614" } } }],
        [{ value: { atom: { unsigned: "18446744073709551615" } } }],
        [{ value: { atom: { unsigned: "18446744073709551615" } } }],
        [{ null: {} }],
        [{ missing: {} }],
        [{ type_error: "unknown" }],
        [
          {
            conflict: [
              { counter: "1", replica: "1", value: { null: {} } },
              { counter: "1", replica: "2", value: { null: {} } },
            ],
          },
        ],
      ],
      { uint64: {} },
    ),
    0,
  );
  expect(profile.counts).toEqual({ value: 3, null: 1, missing: 1, type_error: 1, conflict: 1 });
  expect(profile.distinct).toBe(2);
  expect(profile.minimum).toBe("18446744073709551614");
  expect(profile.maximum).toBe("18446744073709551615");
  expect(profile.histogram.reduce((a, b) => a + b, 0)).toBe(3);
});
test("unsupported ordering cannot fabricate distribution statistics", () => {
  const profile = profileResult(view([[{ value: { atom: { utf8: "z" } } }]], { utf8: {} }), 0);
  expect(profile.numeric).toBe(false);
  expect(profile.minimum).toBeUndefined();
});
