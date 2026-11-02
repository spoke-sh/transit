import { expect, test } from "vite-plus/test";
import { definitionPlacement, rowPlacement } from "./retained-model";

test("physical mappings join stable column IDs across rename and expose ADD origin", () => {
  const definition = {
    schema_revision: "7",
    columns: [
      { column: "9007199254740993", source: { physical: "6" } },
      {
        column: "8",
        source: {
          initial: {
            state: "null" as const,
            definition: {
              object: { scope: { realm: 1, resource: 2, catalog: "3" }, branch: "4", object: "5" },
              revision: "9",
              digest: "a".repeat(64),
            },
          },
        },
      },
    ],
  };
  const projected = definitionPlacement(definition, [
    { id: "9007199254740993", name: "renamed" },
    { id: "8", name: "added" },
  ]);
  expect(projected.map((row) => [row.key, row.label, row.destination, row.location])).toEqual([
    [
      "9007199254740993",
      "Column 9007199254740993 · renamed",
      "Physical schema 7",
      "physical column 6",
    ],
    ["8", "Column 8 · added", "ADD-time definition 9", "ADD-time null, definition 9"],
  ]);
  expect(definitionPlacement(definition, [])[0]!.label).toBe("Column 9007199254740993");
});

test("row identity, WAL bytes and shared segment destinations remain exact", () => {
  const rows = rowPlacement([
    {
      identity: { origin: "1", operation: "9007199254740993", ordinal: 0 },
      schema_revision: "2",
      location: {
        wal: { lsn: "18446744073709551614", offset: 45, bytes: 1536, row_digest: "a".repeat(64) },
      },
    },
    ...[1, 2].map((ordinal) => ({
      identity: { origin: "1", operation: "2", ordinal },
      schema_revision: "3",
      location: {
        segment: {
          id: "9007199254740993",
          row: ordinal,
          content: { bytes: "4096", sha256: "b".repeat(64) },
        },
      },
    })),
  ]);
  expect(rows[0]).toEqual({
    key: "1:9007199254740993:0",
    label: "Row 1:9007199254740993:0",
    destination: "WAL LSN 18446744073709551614",
    group: "wal/18446744073709551614",
    location: "Offset 45",
    schema: "2",
    bytes: 1536,
  });
  expect(rows[1]!.group).toBe(rows[2]!.group);
  expect(rows[1]!.location).toBe("Row 1");
  expect(rows[2]!.location).toBe("Row 2");
  // Content bytes are descriptor evidence, not inferred segment size.
  expect(rows[1]!.bytes).toBeUndefined();
  expect(rowPlacement([])).toEqual([]);
});
