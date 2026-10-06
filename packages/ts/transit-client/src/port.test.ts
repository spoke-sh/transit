import assert from "node:assert/strict";
import test from "node:test";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ValidateFunction } from "ajv";
import { Port } from "./port.ts";
import { ReadFailed, UnknownOutcome } from "./errors.ts";

async function host(response: unknown, run: (path: string) => Promise<void>): Promise<void> {
  const directory = await mkdtemp(join(tmpdir(), "transit-port-bounds-"));
  const path = join(directory, "host.mjs");
  try {
    await writeFile(
      path,
      `#!${process.execPath}\nimport {createInterface} from 'node:readline';\nfor await (const line of createInterface({input: process.stdin})) console.log(${JSON.stringify(JSON.stringify({ status: 0, value: response }))});\n`,
      { mode: 0o700 },
    );
    await run(path);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}
function nested(depth: number): unknown {
  let result: unknown = null;
  for (let i = 0; i < depth; ++i) result = [result];
  return result;
}
test("port rejects hostile recursive requests before validation and keeps the handle usable", async () => {
  await host({ accepted: true }, async (path) => {
    let calls = 0;
    const validate = (() => {
      calls++;
      return true;
    }) as unknown as ValidateFunction;
    const port = await Port.open(path, {}, validate);
    try {
      const cycle: { self?: unknown } = {};
      cycle.self = cycle;
      for (const input of [cycle, { value: nested(97) }, { value: "\ud800" }, { value: Infinity }])
        await assert.rejects(port.request(input, { phase: "preflight" }), TypeError);
      assert.equal(calls, 0);
      const shared = { value: 1 };
      assert.deepEqual(
        await port.request({ left: shared, right: shared, optional: undefined }, { phase: "read" }),
        { accepted: true },
      );
      assert.equal(calls, 1);
    } finally {
      await port.close();
    }
  });
});
for (const mutation of [false, true]) {
  test(`port bounds recursive responses before validation and preserves uncertainty (${mutation})`, async () => {
    await host(nested(97), async (path) => {
      const validate = (() => true) as unknown as ValidateFunction;
      const responseValidator = (() =>
        assert.fail(
          "unbounded response reached the schema validator",
        )) as unknown as ValidateFunction;
      const port = await Port.open(path, {}, validate);
      try {
        await assert.rejects(
          port.request({}, { phase: "operation", mutation, validator: responseValidator }),
          mutation ? UnknownOutcome : ReadFailed,
        );
      } finally {
        await port.close();
      }
    });
  });
}
