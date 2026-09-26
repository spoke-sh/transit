import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile, writeFile, chmod } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { setTimeout as delay } from 'node:timers/promises';
import { Client, ProcessRef, Busy, CodecError, TurnExpired, ReadFailed, StaleOwnership, AccessDenied, ProcessRetired, HandlerError } from '@transit/client';
import { Activation, Runner, ReadVersion, IpcSegment, encodeCast } from '@transit/station';
import { Counter, Requester, TableService, QueryRequester, TABLE, TOTAL, counter, query, u64Codec,
  counterCodec, requesterCodec, queryServiceCodec, queryRequesterCodec } from '@transit/sdk-examples';

const [mode, path] = process.argv.slice(2);
const cfg = JSON.parse(await readFile(path, 'utf8'));
assert.ok(import.meta.resolve('@transit/station').startsWith(new URL('./node_modules/', import.meta.url).href));
const config = { url: cfg.url, profile: cfg.profile, queryResults: cfg.query_results,
  activation: new Activation(new ProcessRef(cfg.realm, cfg.pid), cfg.principal, cfg.generation, cfg.seed_file) };
const peer = new ProcessRef(cfg.realm, cfg.peer);
const report = value => console.log(JSON.stringify(value));
const tagged = (_key, value) => typeof value === 'bigint' ? { bigint: value.toString() } : value;
const revived = (_key, value) => value && typeof value === 'object' && Object.keys(value).join() === 'bigint' ? BigInt(value.bigint) : value;

async function main() {
  if (mode === 'arrow') {
    const { toArrow } = await import('@transit/station/arrow');
    const rows = [];
    for (let i = 0; i < 6; i++) {
      const value = JSON.parse(await readFile(`${cfg.output}/${i}.segment`, 'utf8'), revived);
      const original = new Uint8Array(await readFile(`${cfg.output}/${i}.arrow`));
      const segment = new IpcSegment(value.manifest, value.ordinal, value.rows, new Uint8Array(value.digest), original, 8192);
      const table = toArrow(segment);
      original.fill(0);
      segment.ipc.fill(0);
      rows.push(...table.toArray());
    }
    assert.equal(rows.length, 41);
    assert.equal(rows[0].id, -(1n << 63n)); assert.equal(rows[0].value, 17n);
    assert.equal(rows[1].value, (1n << 63n) - 1n); assert.equal(rows[2].value, (1n << 53n) + 1n);
    assert.equal(rows[5].value, null);
    return;
  }
  if (mode === 'codecs') {
    await assert.rejects(import('apache-arrow'), { code: 'ERR_MODULE_NOT_FOUND' });
    const fixtures = JSON.parse(await readFile(cfg.fixtures, 'utf8'));
    const codecs = { counter, query, u64: u64Codec };
    for (const item of fixtures.valid) {
      const codec = codecs[item.codec], bytes = new Uint8Array(Buffer.from(item.hex, 'hex')), value = codec.decode(bytes);
      assert.deepEqual(codec.encode(value), bytes);
      if (item.codec === 'u64') assert.equal(value, BigInt(item.value));
      else {
        assert.equal(value.kind, item.variant.toLowerCase());
        for (const name of ['key', 'value']) if (name in item) assert.equal(value[name], item[name] === null ? null : BigInt(item[name]));
      }
    }
    for (const item of fixtures.invalid) assert.throws(() => codecs[item.codec].decode(new Uint8Array(Buffer.from(item.hex, 'hex'))));
    for (const invalid of [true, -1n, 1n << 64n, 1]) assert.throws(() => u64Codec.encode(invalid));
    const value = { kind: 'add', value: (1n << 53n) + 1n };
    assert.deepEqual(await encodeCast(value, counterCodec), new Uint8Array(Buffer.concat([Buffer.from('STN1'), Buffer.from([1]), Buffer.alloc(8), counter.encode(value)])));
    return;
  }
  class CounterProof extends Counter {
    initialized = 0; handled = 0; escaped;
    async initialize(turn) { this.initialized++; assert.equal((await turn.budgets()).mutations, 3); await super.initialize(turn); }
    async handle(turn, input) { this.handled++; this.escaped = turn; await super.handle(turn, input); }
  }
  let handler = new CounterProof(), codec = counterCodec;
  if (cfg.role === 'requester') { handler = new Requester(peer); codec = requesterCodec; }
  else if (cfg.role === 'table') {
    class TableProof extends TableService {
      async handle(turn, input) {
        const saved = `${cfg.output}/version.json`;
        if (input.kind === 'cast' && input.value.kind === 'rows') {
          let cursor, rows = [], pages = 0;
          const table = await turn.table(TABLE);
          do {
            const page = await table.page(cursor);
            assert.ok(page.entries.length <= 8); assert.deepEqual(page.basis, table.basis);
            rows.push(...page.entries); pages++; cursor = page.next;
          } while (cursor !== undefined);
          assert.equal(rows.length, 41); assert.equal(pages, 6);
          assert.deepEqual(rows[0], { key: -(1n << 63n), value: null });
          const version = await turn.retain();
          await writeFile(saved, JSON.stringify(version));
          await table.update({ key: -(1n << 63n), value: 17n });
        } else if (input.value.kind === 'initialize' && existsSync(saved)) {
          const value = JSON.parse(await readFile(saved, 'utf8'));
          const version = new ReadVersion(value.pid, value.input, value.index);
          assert.equal((await (await turn.table(TABLE)).get(-(1n << 63n))).value, 17n);
          const source = turn.openVersion(version), table = await source.table(TABLE);
          assert.equal((await table.get(-(1n << 63n))).value, null);
          assert.equal((await table.page()).entries.length, 8);
          assert.ok((await source.state.page()).entries.length <= 8);
          await turn.release(version);
        } else await super.handle(turn, input);
      }
    }
    handler = new TableProof(peer); codec = queryServiceCodec;
  } else if (cfg.role === 'query') {
    const segments = [];
    async function consume(segment) { segments.push(segment); }
    class QueryProof extends QueryRequester {
      async handle(turn, input) {
        if (existsSync(`${cfg.output}/manifest.json`)) {
          const manifest = JSON.parse(await readFile(`${cfg.output}/manifest.json`, 'utf8'));
          const reader = turn.result(BigInt(manifest.correlation));
          assert.equal((await reader.manifest()).rows, 41n);
          await writeFile(`${cfg.output}/ready`, '');
          const deadline = Date.now() + 30000;
          while (!existsSync(`${cfg.output}/continue`)) { assert.ok(Date.now() < deadline); await delay(10); }
          await reader.segment(0n);
        } else await super.handle(turn, input);
      }
      async handleResult(turn, reader) {
        await super.handleResult(turn, reader);
        // Publish test observations after reading all segments, so the driver can
        // close the runner; the owned buffers are written after that close below.
        const manifest = await reader.manifest();
        await writeFile(`${cfg.output}/manifest.json`, JSON.stringify({ rows: Number(manifest.rows), segments: Number(manifest.segments),
          correlation: manifest.correlation.toString(), source: manifest.source.pid, destination: manifest.destination.pid,
          resource: manifest.basis.resource.resource, revision: manifest.basis.revision, bytes: Number(manifest.byteCount) }));
      }
      async saveOwned() {
        for (const segment of segments) {
          await writeFile(`${cfg.output}/${segment.ordinal}.arrow`, segment.ipc);
          await writeFile(`${cfg.output}/${segment.ordinal}.segment`, JSON.stringify({ manifest: segment.manifest,
            ordinal: segment.ordinal, rows: segment.rows, digest: [...segment.digest] }, tagged));
        }
      }
    }
    handler = new QueryProof(peer, consume); codec = queryRequesterCodec;
  }
  if (mode.startsWith('handler-')) handler.handle = async turn => { await turn.state.put(TOTAL, 73n); throw new HandlerError('injected handler failure'); };
  if (mode === 'dropped-operation') handler.initialize = async turn => { void turn.state.put(TOTAL, 73n); };
  const store = {
    current: undefined, beforeFailed: new Set(), confirmFailed: new Set(), saved: new Map(), confirmations: new Map(),
    async beforeDispatch(mutation) {
      this.current = mutation;
      if (mode === 'gates') {
        assert.throws(() => this.runner.next(), Busy); assert.throws(() => this.runner.close(), Busy);
        if (!this.beforeFailed.has(mutation.purpose)) { this.beforeFailed.add(mutation.purpose); throw new Error('persistence unavailable'); }
      }
      const bytes = mutation.export(), key = mutation.identity.sha256;
      if (this.saved.has(key)) assert.deepEqual(this.saved.get(key), bytes); else this.saved.set(key, bytes);
      await writeFile(cfg.pending, bytes, { mode: 0o600 }); await chmod(cfg.pending, 0o600);
    },
    async confirmed(identity, receipt) {
      assert.ok(this.saved.has(identity.sha256)); assert.ok(receipt.position > 0);
      if (mode === 'gates' && !this.confirmFailed.has(this.current.purpose)) { this.confirmFailed.add(this.current.purpose); throw new Error('confirmation unavailable'); }
      this.confirmations.set(identity.sha256, receipt);
    },
  };
  if (mode === 'recover') {
    const client = await Client.open({ url: cfg.url, profile: cfg.profile });
    try {
      const pending = await client.recoverMutation(new Uint8Array(await readFile(cfg.pending)));
      try { const result = await client.dispatchMutation(pending); assert.equal(result.kind, 'confirmed'); report({ receipt: result.receipt.position }); }
      finally { pending.close(); }
    } finally { await client.close(); }
    return;
  }
  const options = { failure: mode.endsWith('-block') ? 'block-input' : 'stop', recovery: { kind: 'persist-before-dispatch', store } };
  if (mode === 'denied') { await assert.rejects(Runner.open(config, handler, codec, options), AccessDenied); return; }
  const runner = await Runner.open(config, handler, codec, options); store.runner = runner;
  try {
    if (mode === 'async') {
      assert.notEqual((await runner.next()).kind, 'committed');
      const abort = new AbortController(), iterator = runner.run({ signal: abort.signal });
      const active = iterator.next(), deadline = Date.now() + 20000;
      while (!existsSync(`${cfg.output}/accepted`)) { assert.ok(Date.now() < deadline); await delay(10); }
      assert.throws(() => runner.next(), Busy);
      abort.abort();
      let finished = false, beats = 0;
      const closing = runner.close().then(() => { finished = true; });
      while (!finished) { beats++; await delay(10); }
      await closing; await active; await iterator.return();
      assert.ok(beats > 5); assert.equal(runner.lastEvent.kind, 'committed'); assert.equal(handler.handled, 1); assert.equal(runner.pending, undefined);
      report({ committed: true, beats }); return;
    }
    if (mode === 'gates') {
      const phases = new Set();
      let done = false;
      for (let i = 0; i < 40; i++) {
        let event = await runner.next();
        if (event.kind === 'needs-recovery') {
          phases.add(event.phase); if (event.phase === 'confirm') assert.ok(event.receipt);
          assert.equal(await runner.next(), event); event = await runner.reconcile();
        }
        if (event.kind === 'committed') { done = true; break; }
      }
      assert.ok(done); assert.deepEqual([...phases].sort(), ['confirm', 'persist']);
      assert.equal(store.confirmations.size, 3); assert.equal(handler.initialized, 1); assert.equal(handler.handled, 1);
      assert.throws(() => handler.escaped.state.require(TOTAL), TurnExpired);
      report({ gates: [...store.confirmFailed].sort(), handled: handler.handled, dispatches: store.saved.size }); return;
    }
    if (mode.startsWith('decode-') || mode.startsWith('handler-') || mode === 'dropped-operation') {
      let stopped = false;
      for (let i = 0; i < 8; i++) {
        let event;
        try { event = await runner.next(); }
        catch (error) {
          assert.ok(['decode-stop', 'handler-stop', 'dropped-operation'].includes(mode));
          // The dropped initializer also makes the overlapping handle fail Busy;
          // either failure rejects success and the native proposal is discarded.
          assert.ok(error instanceof (mode === 'decode-stop' ? CodecError : HandlerError) || (mode === 'dropped-operation' && error instanceof Busy));
          stopped = true; break;
        }
        if (event.kind === 'blocked') { assert.ok(mode.endsWith('-block')); assert.ok(event.receipt); stopped = true; break; }
      }
      assert.ok(stopped); return;
    }
    if (['stale', 'expired', 'revoked-result'].includes(mode)) {
      await assert.rejects(async () => { for (let i = 0; i < 8; i++) await runner.next(); }, mode === 'stale' ? StaleOwnership : mode === 'expired' ? ProcessRetired : AccessDenied);
      report({ denied: true }); return;
    }
    if (mode === 'poison') {
      handler.handle = async turn => { try { await turn.state.require(TOTAL); } catch (error) { assert.ok(error instanceof ReadFailed); } };
      await assert.rejects(async () => { for (let i = 0; i < 8; i++) await runner.next(); }, ReadFailed); return;
    }
    const input = createInterface({ input: process.stdin });
    for await (const action of input) {
      if (action === 'close') { await runner.close(); if (handler.saveOwned) await handler.saveOwned(); report({ closed: true }); return; }
      assert.equal(action, 'one');
      let event;
      for (let i = 0; i < 32; i++) { event = await runner.next(); if (['committed', 'needs-recovery', 'blocked', 'idle'].includes(event.kind)) break; }
      if (event.kind === 'needs-recovery') assert.deepEqual(event.mutation.export(), new Uint8Array(await readFile(cfg.pending)));
      report({ event: { committed: 'Committed', 'needs-recovery': 'NeedsRecovery', blocked: 'Blocked', idle: 'Idle' }[event.kind], phase: event.phase, code: event.error?.code });
    }
  } finally { await runner.close(); }
}
await main();
