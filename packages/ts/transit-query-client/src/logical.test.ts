import { expect, test, vi } from "vite-plus/test";
import { validateUnifiedQuery, unifiedCellText, logicalTypeText } from "./values";
import { logicalTypeEqual, type LogicalType, type LogicalCell } from "./logical";
import { Request as validRequest } from "./validators.js";
import type { ResultPage } from "./result";
import { httpTransport } from "./transport";

const field = (type: LogicalType, name = "value") => ({
  name,
  type,
  nullable: true,
  optional: true,
});
function page(type: LogicalType, cell: LogicalCell): { page: ResultPage } {
  return {
    page: {
      cells: [[cell]],
      evidence: {
        columns: [field(type)],
        rows: 1,
        ordinal: "0",
        ipc: "00",
        next: null,
        manifest: {
          job: 1,
          source: { table: { worker: 2 } },
          requester: 4,
          correlation: "5",
          policy_revision: "1",
          request: "00",
          basis: {
            cut: { kind: "table", resource: 6, position: { table: Array(32).fill(1) } },
            contract: Array(32).fill(2),
            schema: Array(32).fill(3),
          },
          table_position: {
            resource: 6,
            partition: "1",
            accepted: "7",
            contract: Array(32).fill(2),
            schema: Array(32).fill(3),
          },
          plan: Array(32).fill(4),
          pages: "1",
          scanned: "1",
          selected: "1",
          value_count: "0",
          segments: "1",
          rows: "1",
          bytes: "1",
          sum: null,
          finished: "source_end",
          chain: Array(32).fill(5),
        },
      },
    },
  };
}
const atom = (
  value: Extract<Extract<LogicalCell, { value: unknown }>["value"], { atom: unknown }>["atom"],
): LogicalCell => ({ value: { atom: value } });
const admits = (type: LogicalType, value: LogicalCell) => validateUnifiedQuery(page(type, value));

test("all integer widths preserve extrema and reject overflow, cross-kind coercion and noncanonical text", () => {
  for (const signed of [false, true])
    for (const width of [8, 16, 32, 64, 128]) {
      const type = { [`${signed ? "int" : "uint"}${width}`]: {} } as LogicalType;
      const limit = 1n << BigInt(signed ? width - 1 : width),
        low = signed ? -limit : 0n;
      const make = (text: string) => atom(signed ? { signed: text } : { unsigned: text });
      for (const n of [low, 0n, limit - 1n]) {
        expect(admits(type, make(String(n)))).toBe(true);
        expect(unifiedCellText(make(String(n)), type)).toBe(String(n));
      }
      for (const text of [String(low - 1n), String(limit), "-0", "+1", "01", "1.0", "1e0"])
        expect(admits(type, make(text))).toBe(false);
      expect(admits(type, atom(signed ? { unsigned: "0" } : { signed: "0" }))).toBe(false);
    }
});

test("exact decimal, temporal, floats, UUID and variable values have independent admission limits", () => {
  const cases: [LogicalType, LogicalCell, LogicalCell][] = [
    [
      { decimal: { precision: 38, scale: 2 } },
      atom({ decimal: "99999999999999999999999999999999999999" }),
      atom({ decimal: "100000000000000000000000000000000000000" }),
    ],
    [{ date: {} }, atom({ date_days: "-2147483648" }), atom({ date_days: "2147483648" })],
    [{ time: {} }, atom({ time_nanos: "86399999999999" }), atom({ time_nanos: "86400000000000" })],
    [
      { timestamp: "utc" },
      atom({ timestamp_micros: "9223372036854775807" }),
      atom({ timestamp_micros: "9223372036854775808" }),
    ],
    [
      { timestamp: "civil" },
      atom({ timestamp_micros: "-9223372036854775808" }),
      atom({ timestamp_micros: "-9223372036854775809" }),
    ],
    [
      { interval: {} },
      atom({
        interval: { months: "-2147483648", days: "2147483647", nanos: "-9223372036854775808" },
      }),
      atom({ interval: { months: "2147483648", days: "0", nanos: "0" } }),
    ],
    [{ float32: {} }, atom({ float_bits: "00000080" }), atom({ float_bits: "0000807f" })],
    [
      { float64: {} },
      atom({ float_bits: "0000000000000080" }),
      atom({ float_bits: "000000000000f87f" }),
    ],
    [{ boolean: {} }, atom({ boolean: true }), atom({ signed: "1" })],
    [{ utf8: {} }, atom({ utf8: "東京🙂\0" }), atom({ utf8: "\ud800" })],
    [{ binary: {} }, atom({ binary: "00ff01" }), atom({ binary: "00FF01" })],
    [{ uuid: {} }, atom({ uuid: "00112233445566778899aabbccddeeff" }), atom({ uuid: "001122" })],
  ];
  for (const [type, good, bad] of cases) {
    expect(admits(type, good), logicalTypeText(type)).toBe(true);
    expect(admits(type, bad), logicalTypeText(type)).toBe(false);
    for (const state of [
      { missing: {} },
      { null: {} },
      { type_error: "map" },
      {
        conflict: [
          { counter: "9007199254740993", replica: "1", value: good },
          { counter: "18446744073709551615", replica: "2", value: { null: {} } },
        ],
      },
    ])
      expect(validateUnifiedQuery(page(type, state as LogicalCell))).toBe(true);
  }
  expect(unifiedCellText(atom({ decimal: "-1" }), { decimal: { precision: 5, scale: 3 } })).toBe(
    "-0.001",
  );
  expect(unifiedCellText(atom({ float_bits: "00000080" }), { float32: {} })).toBe("-0");
  expect(unifiedCellText(atom({ uuid: "00112233445566778899aabbccddeeff" }))).toBe(
    "00112233-4455-6677-8899-aabbccddeeff",
  );
  expect(admits({ decimal: { precision: 39, scale: 0 } }, atom({ decimal: "1" }))).toBe(false);
  expect(admits({ decimal: { precision: 2, scale: 3 } }, atom({ decimal: "1" }))).toBe(false);
  expect(
    validRequest({
      compile: {
        sql: "SELECT * FROM t",
        parameters: [{ unsigned: "18446744073709551615" }, { decimal: "125" }],
      },
    }),
  ).toBe(true);
  expect(validRequest({ compile: { sql: "SELECT * FROM t", parameters: [{ int64: "1" }] } })).toBe(
    false,
  );
});

test("recursive states obey descriptors, exact array lengths, union variants and canonical map order", () => {
  const list: LogicalType = { list: { type: { int64: {} }, nullable: true } };
  const structure: LogicalType = {
    structure: [field(list, "named value"), field({ utf8: {} }, "雪")],
  };
  const value: LogicalCell = {
    value: {
      structure: [{ value: { list: [atom({ signed: "7" }), { null: {} }] } }, { missing: {} }],
    },
  };
  expect(admits(structure, value)).toBe(true);
  expect(unifiedCellText(value, structure)).toBe('{"named value": [7, NULL], "雪": MISSING}');
  expect(
    admits({ list: { type: { int64: {} }, nullable: false } }, { value: { list: [{ null: {} }] } }),
  ).toBe(false);
  expect(admits(list, { value: { list: [{ missing: {} }] } })).toBe(false);
  const array: LogicalType = {
    array: { length: 2, element: { type: { uint16: {} }, nullable: true } },
  };
  expect(admits(array, { value: { array: [atom({ unsigned: "65535" }), { null: {} }] } })).toBe(
    true,
  );
  expect(admits(array, { value: { array: [atom({ unsigned: "65535" })] } })).toBe(false);
  const union: LogicalType = {
    tagged_union: [
      { ...field({ int8: {} }, "integer"), optional: false },
      { ...field({ utf8: {} }, "text"), optional: false },
    ],
  };
  expect(admits(union, { value: { tagged_union: { index: 1, value: atom({ utf8: "x" }) } } })).toBe(
    true,
  );
  expect(admits(union, { value: { tagged_union: { index: 2, value: atom({ utf8: "x" }) } } })).toBe(
    false,
  );
  const map: LogicalType = {
    map: { key: { utf8: {} }, value: { type: { boolean: {} }, nullable: true } },
  };
  const entries = ["\ue000", "𐀀"].map((utf8) => ({ key: { utf8 }, value: { null: {} } }));
  expect(admits(map, { value: { map: entries } })).toBe(true); // UTF-8 order differs from UTF-16 order.
  expect(admits(map, { value: { map: [...entries].reverse() } })).toBe(false);
  expect(admits(map, { value: { map: [entries[0]!, entries[0]!] } })).toBe(false);
  expect(
    admits(
      { map: { key: { float32: {} }, value: { type: { boolean: {} }, nullable: true } } },
      {
        value: {
          map: [
            { key: { float_bits: "00000080" }, value: { null: {} } },
            { key: { float_bits: "00000000" }, value: { null: {} } },
          ],
        },
      },
    ),
  ).toBe(false);
  expect(
    logicalTypeEqual(structure, {
      structure: [
        { optional: true, nullable: true, type: list, name: "named value" },
        field({ utf8: {} }, "雪"),
      ],
    }),
  ).toBe(true);
});

test("stored JSON retains number lexemes and rejects duplicate decoded names and deep syntax", () => {
  const check = (json: string) => admits({ json: {} }, { value: { json } });
  for (const json of [
    '{"n":9007199254740993,"x":0.1234567890123456789}',
    '{"n":1e999}',
    '"\\uD83D\\uDE42"',
    "[null,true,false,{},[]]",
  ])
    expect(check(json)).toBe(true);
  for (const json of [
    '{"a":1,"\\u0061":2}',
    "[1,]",
    '{"a":1,}',
    "01",
    "NaN",
    '"\\ud800"',
    "[".repeat(17) + "]".repeat(17),
  ])
    expect(check(json)).toBe(false);
});

test("128 Unicode columns, recursive budgets and nullability are checked before presentation", () => {
  const response = page({ int64: {} }, atom({ signed: "1" }));
  response.page.evidence.columns = Array.from({ length: 128 }, (_, i) =>
    field({ int64: {} }, `列 ${i}`),
  );
  response.page.cells = [Array.from({ length: 128 }, () => atom({ signed: "1" }))];
  expect(validateUnifiedQuery(response)).toBe(true);
  response.page.evidence.columns.push(field({ int64: {} }, "extra"));
  response.page.cells[0]!.push(atom({ signed: "1" }));
  expect(validateUnifiedQuery(response)).toBe(false);
  for (const name of ["", "a\0b", "\ud800", "🙂".repeat(64)]) {
    const bad = page({ int64: {} }, atom({ signed: "1" }));
    bad.page.evidence.columns[0]!.name = name;
    expect(validateUnifiedQuery(bad)).toBe(false);
  }
  const notNull = page({ int64: {} }, { null: {} });
  notNull.page.evidence.columns[0]!.nullable = false;
  expect(validateUnifiedQuery(notNull)).toBe(false);
  const required = page({ int64: {} }, { missing: {} });
  required.page.evidence.columns[0]!.optional = false;
  expect(validateUnifiedQuery(required)).toBe(false);
  let nested: LogicalType = { int64: {} };
  for (let i = 0; i < 14; i++) nested = { list: { type: nested, nullable: false } };
  expect(admits(nested, { null: {} })).toBe(true); // Includes the top row descriptor node.
  expect(admits({ list: { type: nested, nullable: false } }, { null: {} })).toBe(false);
  const cyclic: { list: { type?: unknown; nullable: boolean } } = { list: { nullable: false } };
  cyclic.list.type = cyclic;
  expect(validateUnifiedQuery({ inspection: { details: cyclic } })).toBe(false);
  expect(
    admits(
      { list: { type: { int8: {} }, nullable: true } },
      { value: { list: Array.from({ length: 65536 }, () => ({ null: {} })) } },
    ),
  ).toBe(false);
});

test("hostile recursive request input fails locally without consuming a query identity", async () => {
  const recursive: Record<string, unknown> = {};
  recursive.self = recursive;
  await expect(httpTransport("/query")(recursive as never)).rejects.toMatchObject({
    code: "InvalidRequest",
  });
});

test("the complete admitted query bundle fits the bounded browser request envelope", async () => {
  const fetcher = vi.fn().mockResolvedValue(Response.json({ prepared: null }));
  vi.stubGlobal("fetch", fetcher);
  try {
    await expect(
      httpTransport("/query")({
        next: { namespace: "18446744073709551615", bundle: "00".repeat(25743) },
      }),
    ).resolves.toEqual({ prepared: null });
    const body = fetcher.mock.calls[0]![1].body as string;
    expect(new TextEncoder().encode(body).length).toBeGreaterThan(49152);
    expect(new TextEncoder().encode(body).length).toBeLessThan(65536);
    await expect(
      httpTransport("/query")({ next: { namespace: "1", bundle: "00".repeat(65536) } }),
    ).rejects.toMatchObject({ code: "RequestTooLarge" });
    expect(fetcher).toHaveBeenCalledTimes(1);
  } finally {
    vi.unstubAllGlobals();
  }
});

test("verified Table positions require matching source evidence and full-width canonical counters", () => {
  const result = page({ int64: {} }, atom({ signed: "7" }));
  const manifest = result.page.evidence.manifest;
  manifest.table_position!.partition = "18446744073709551615";
  manifest.table_position!.accepted = "18446744073709551615";
  expect(validateUnifiedQuery(result)).toBe(true);
  for (const changed of [
    null,
    { ...manifest.table_position!, resource: 8 },
    { ...manifest.table_position!, accepted: "18446744073709551616" },
    { ...manifest.table_position!, partition: "01" },
    { ...manifest.table_position!, contract: Array(32).fill(9) },
    { ...manifest.table_position!, schema: Array(32).fill(9) },
  ]) {
    expect(
      validateUnifiedQuery({
        page: {
          ...result.page,
          evidence: { ...result.page.evidence, manifest: { ...manifest, table_position: changed } },
        },
      }),
    ).toBe(false);
  }
});
