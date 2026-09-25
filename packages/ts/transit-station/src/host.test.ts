import assert from "node:assert/strict";
import { chmod, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { NativeHost } from "./index.ts";

async function fixture(mode: string): Promise<{ host: NativeHost; cleanup: () => Promise<void> }> {
  const directory = await mkdtemp(join(tmpdir(), "transit-node-host-"));
  const executable = join(directory, "host.mjs");
  await writeFile(
    executable,
    `#!${process.execPath}
import { createInterface } from 'node:readline';
const lines = createInterface({ input: process.stdin });
lines.on('line', line => {
  const request = JSON.parse(line);
  if ('hello' in request) process.stdout.write(JSON.stringify({status:0,value:{host_version:1,station_version:1,transit_version:1}})+'\\n');
  else if (process.argv[2] === 'malformed') process.stdout.write('{"status":0,"value":{}}\\n');
  else if (process.argv[2] === 'oversized') process.stdout.write('x'.repeat(600000));
  else if (process.argv[2] === 'exit') process.exit(1);
});
lines.on('close', () => process.exit(0));
`,
  );
  await chmod(executable, 0o700);
  const host = await NativeHost.open(executable, mode);
  return {
    host,
    cleanup: async () => {
      await host.close();
      await rm(directory, { recursive: true, force: true });
    },
  };
}

test("native waits leave the event loop responsive, bound pending work and preserve cancellation uncertainty", async () => {
  const { host, cleanup } = await fixture("stall");
  try {
    const abort = new AbortController();
    const pending = host.next(Date.now() + 1000, abort.signal);
    await assert.rejects(host.next(), { status: 9 });
    let ticks = 0;
    const clock = setInterval(() => {
      ticks++;
    }, 2);
    await new Promise((resolve) => setTimeout(resolve, 50));
    clearInterval(clock);
    assert.ok(ticks > 2);
    abort.abort();
    await assert.rejects(pending, { status: 6 });
    await assert.rejects(host.next(), { status: 7 });
  } finally {
    await cleanup();
  }
});

for (const mode of ["malformed", "oversized", "exit"]) {
  test(`${mode} native completion cannot turn a possible commit into a rejection`, async () => {
    const { host, cleanup } = await fixture(mode);
    try {
      await assert.rejects(host.next(), { status: 6 });
    } finally {
      await cleanup();
    }
  });
}

test("native result validation fails closed for a private operation too", async () => {
  const { host, cleanup } = await fixture("malformed");
  try {
    await assert.rejects(host.apply({ get: "61" }), { status: 8 });
  } finally {
    await cleanup();
  }
});
