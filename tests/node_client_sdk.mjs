import assert from 'node:assert/strict';
import { readFile, access } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { setTimeout as wait } from 'node:timers/promises';
import { Client, Credential, ProcessRef, Busy, Closed, UnsupportedCapability, IncompatibleNative, AccessDenied } from '@transit/client';
import { writeFile } from 'node:fs/promises';

const [mode, configPath] = process.argv.slice(2);
const cfg = JSON.parse(await readFile(configPath, 'utf8'));
const options = { url: cfg.url, profile: 'native_v1', timeoutMs: 3000 };
const credential = new Credential(72, 65536, cfg.seed);
const peer = new ProcessRef(72, cfg.pid);
const require = createRequire(import.meta.url);
for (const name of ['@transit/station', '@transit/native-station', '@rey/transit-station']) {
  assert.throws(() => require.resolve(name), { code: 'MODULE_NOT_FOUND' });
}
for (const value of [true, -1, 0, 2**53, '1']) assert.throws(() => new ProcessRef(72, value), TypeError);
await assert.rejects(Client.open({ ...options, nativeHost: '/missing-transit' }), IncompatibleNative);
if (mode === 'first') {
  const client = await Client.open(options);
  try {
    const caps = await client.capabilities(credential);
    assert.equal(caps.principalSequence, 0);
    assert.equal(caps.pageSize, 8);
    assert.equal(caps.retainedVersions, true);
    const bytes = new Uint8Array(Buffer.from('wide'));
    const pending = await client.prepareSend(peer, bytes, { credential, sequence: 1 });
    const frozen = pending.export();
    bytes.fill(0);
    assert.deepEqual(pending.export(), frozen);
    const copy = pending.export(); copy.fill(0);
    assert.deepEqual(pending.export(), frozen);
    assert.equal(pending.identity.sha256, createHash('sha256').update(frozen).digest('hex'));
    await writeFile(cfg.pending, frozen, { mode: 0o600 });
    const result = await client.dispatch(pending);
    assert.equal(result.kind, 'uncertain');
    assert.equal(result.error.status, 6);
    assert.deepEqual(result.recovery, frozen);
    pending.close();
    assert.throws(() => pending.export(), Closed);
  } finally { await client.close(); }
} else if (mode === 'recover') {
  await assert.rejects(access(cfg.seed));
  const client = await Client.open(options);
  try {
    const pending = await client.recoverSend(new Uint8Array(await readFile(cfg.pending)));
    const result = await client.dispatch(pending);
    assert.equal(result.kind, 'admitted');
    assert.equal(result.receipt.position, client.lastReceipt.position);
    process.stdout.write(JSON.stringify({ position: result.receipt.position }) + '\n');
    const parse = JSON.parse;
    JSON.parse = (text, reviver) => {
      const value = parse(text, reviver);
      if (value?.status === 0 && typeof value.value?.position === 'number') throw new Error('Injected host response allocation failure');
      return value;
    };
    try {
      const unknown = await client.dispatch(pending);
      assert.equal(unknown.kind, 'uncertain');
      assert.equal(client.lastReceipt, undefined);
      assert.deepEqual(unknown.recovery, pending.export());
    } finally { JSON.parse = parse; pending.close(); }
  } finally { await client.close(); }
  const fresh = await Client.open(options);
  try {
    await assert.rejects(fresh.recoverSend(new Uint8Array(await readFile(cfg.spawn))), UnsupportedCapability);
    await assert.rejects(fresh.recoverSend(new Uint8Array(Buffer.concat([Buffer.from(' '), await readFile(cfg.pending)]))));
  } finally { await fresh.close(); }
} else if (mode === 'async') {
  const client = await Client.open(options);
  const pending = await client.prepareSend(peer, new Uint8Array(Buffer.from('async')), { credential, sequence: 2 });
  const stop = new AbortController();
  const work = client.dispatch(pending, { signal: stop.signal });
  const deadline = Date.now() + 15000;
  while (true) {
    try { await access(cfg.accepted); break; } catch { assert.ok(Date.now() < deadline); await wait(5); }
  }
  await assert.rejects(client.dispatch(pending), Busy);
  stop.abort();
  assert.equal((await work).kind, 'uncertain');
  let joined = false, beats = 0;
  const close = client.close().then(() => { joined = true; });
  while (!joined) { beats++; await wait(10); }
  await close;
  assert.ok(beats > 5 && client.lastReceipt !== undefined);
  await assert.rejects(client.dispatch(pending), Closed);
  pending.close();
  process.stdout.write(JSON.stringify({ await_cancelled: stop.signal.aborted, overlap_rejected: true,
    responsive_during_join: beats > 5, disposed_handle_rejected: true }) + '\n');
} else if (mode === 'denied') {
  const client = await Client.open(options);
  try {
    const pending = await client.recoverSend(new Uint8Array(await readFile(cfg.pending)));
    const result = await client.dispatch(pending);
    assert.equal(result.kind, 'rejected');
    assert.ok(result.error instanceof AccessDenied);
    assert.equal(result.error.status, 4);
    pending.close();
  } finally { await client.close(); }
} else { throw new Error('Unknown consumer mode'); }
