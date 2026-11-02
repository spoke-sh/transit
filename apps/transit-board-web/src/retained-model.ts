import type { HistoricalCoverage, HistoricalSource } from "@transit/board-client";

type Definition = NonNullable<HistoricalCoverage["definitions"]>;
type Location = HistoricalCoverage["locations"][number];
export type Placement = {
  key: string;
  label: string;
  destination: string;
  group: string;
  location: string;
  schema: string;
  bytes?: number;
};

/** Stable IDs are the join. Names only label an already identified logical column. */
export function definitionPlacement(
  definition: Pick<Definition, "columns" | "schema_revision">,
  columns: readonly Pick<HistoricalSource["schema"]["columns"][number], "id" | "name">[],
): Placement[] {
  return definition.columns.map((column) => {
    const name = columns.find((candidate) => candidate.id === column.column)?.name;
    const origin = column.source;
    const physical = "physical" in origin;
    const destination = physical
      ? `Physical schema ${definition.schema_revision}`
      : `ADD-time definition ${origin.initial.definition.revision}`;
    return {
      key: column.column,
      label: `Column ${column.column}${name ? ` · ${name}` : ""}`,
      destination,
      group: physical
        ? `physical/${definition.schema_revision}`
        : `initial/${origin.initial.definition.digest}`,
      location: physical
        ? `physical column ${origin.physical}`
        : `ADD-time ${origin.initial.state}, definition ${origin.initial.definition.revision}`,
      schema: definition.schema_revision,
    };
  });
}

/** One API page only: destinations group rows without claiming a complete inventory. */
export function rowPlacement(
  locations: readonly Pick<Location, "identity" | "schema_revision" | "location">[],
): Placement[] {
  return locations.map((row) => {
    const key = `${row.identity.origin}:${row.identity.operation}:${row.identity.ordinal}`;
    const where = row.location;
    return {
      key,
      label: `Row ${key}`,
      schema: row.schema_revision,
      ...("wal" in where
        ? {
            destination: `WAL LSN ${where.wal.lsn}`,
            group: `wal/${where.wal.lsn}`,
            location: `Offset ${where.wal.offset}`,
            bytes: where.wal.bytes,
          }
        : {
            destination: `Segment ${where.segment.id}`,
            group: `segment/${where.segment.id}/${where.segment.content.sha256}`,
            location: `Row ${where.segment.row}`,
          }),
    };
  });
}
