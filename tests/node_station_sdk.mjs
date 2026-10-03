import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile, writeFile, chmod } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { setTimeout as delay } from 'node:timers/promises';
import { Client, ProcessRef, ResourceRef, Busy, Closed, CodecError, TurnExpired, ReadFailed, StaleOwnership, AccessDenied, ProcessRetired, HandlerError } from '@transit/client';
import { Activation, Runner, ReadVersion, IpcSegment, encodeCast, Key, prepareHttp, decodeHttpReply, HttpOutcome, grpcMethod, prepareGrpc, decodeGrpcReply, GrpcOutcome } from '@transit/station';
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
  if (mode.startsWith('document-')) return documentConsumer();
  if (mode.startsWith('grpc-')) return grpcConsumer();
  if (mode.startsWith('http-')) return httpConsumer();
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
    for (const row of rows) for (const cell of [row.id, row.value]) {
      assert.equal(cell.alternatives.length, 0);
      assert.ok(cell.state === 1 || cell.state === 3);
      assert.equal(cell.kind, cell.state === 1 ? 7 : 1);
      if (cell.state === 1) assert.equal(cell.value, null);
    }
    assert.equal(rows[0].id.value, -(1n << 63n)); assert.equal(rows[0].value.value, 17n);
    assert.equal(rows[1].value.value, (1n << 63n) - 1n); assert.equal(rows[2].value.value, (1n << 53n) + 1n);
    assert.equal(rows[5].value.state, 1);
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
    const fixture = JSON.parse(await readFile(cfg.http_fixtures, 'utf8'));
    const prepared = await prepareHttp(new ResourceRef(72, 8), (1n << 64n) - 1n,
      { method: 'POST', target: [{ kind: 'literal', value: '/write' }] },
      new Uint8Array(Buffer.from(fixture.body, 'hex')), { endpointRevision: 7n, reconcileBeforeMs: 9000, maxAttempts: 2 });
    assert.equal(Buffer.from(prepared.reference).toString('hex'), fixture.reference);
    assert.equal(Buffer.from(prepared.metadata).toString(), fixture.metadata);
    const reply = await decodeHttpReply(72, new Uint8Array(Buffer.from(fixture.outcome, 'hex')));
    assert.ok(reply instanceof HttpOutcome); assert.equal(reply.exchange, (1n << 64n) - 1n);
    assert.equal(reply.phase, 'observed'); assert.equal(reply.status, 200);
    assert.equal(reply.diagnostic.code, 'http.response_observed');
    assert.equal(reply.diagnostic.identity.id, ((1n << 64n) - 1n).toString());
    const rejected = await decodeHttpReply(72, new Uint8Array(Buffer.from(fixture.rejection, 'hex')));
    assert.equal(rejected.reason, 'denied'); assert.equal(rejected.diagnostic.code, 'http.request_denied');
    assert.equal(rejected.diagnostic.outcome, 'input_rejected');
    const disposal = JSON.parse(await readFile(cfg.http_release_fixtures, 'utf8'));
    const released = await decodeHttpReply(72, new Uint8Array(Buffer.from(disposal.reply, 'hex')));
    assert.deepEqual(released, { kind: 'http-released', resource: new ResourceRef(72, 7), exchange: (1n << 64n) - 1n });
    assert.ok(Object.isFrozen(released));
    await assert.rejects(decodeHttpReply(72, new Uint8Array(Buffer.from(disposal.reply, 'hex').subarray(0, -1))));
    prepared.reference.fill(0); prepared.body.fill(0);
    assert.equal(Buffer.from(prepared.reference).toString('hex'), fixture.reference);
    assert.equal(Buffer.from(prepared.body).toString('hex'), fixture.body);
    for (const target of [[{ kind: 'literal', value: '//other/' }], [{ kind: 'literal', value: '/' }, { kind: 'secret', binding: 'api', version: 1n }]])
      await assert.rejects(prepareHttp(new ResourceRef(72, 8), 1n, { method: 'GET', target }, new Uint8Array(), { endpointRevision: 1n, reconcileBeforeMs: 9000 }));
    for (const bytes of [Buffer.alloc(0), Buffer.from(fixture.outcome, 'hex').subarray(0, -1)])
      await assert.rejects(decodeHttpReply(72, new Uint8Array(bytes)));
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
      if (action === 'ready') { report({ ready: true }); continue; }
      if (action === 'close') { await runner.close(); if (handler.saveOwned) await handler.saveOwned(); report({ closed: true }); return; }
      assert.ok(['one', 'reconcile'].includes(action));
      let event;
      try {
        for (let i = 0; i < 32; i++) { event = await (action === 'reconcile' && i === 0 ? runner.reconcile() : runner.next()); if (['committed', 'needs-recovery', 'blocked', 'idle'].includes(event.kind)) break; }
      } catch (error) {
        if (!(error instanceof ReadFailed) || error.status !== 7) throw error;
        report({ event: 'ReadUnavailable', code: error.code }); continue;
      }
      if (event.kind === 'needs-recovery') assert.deepEqual(event.mutation.export(), new Uint8Array(await readFile(cfg.pending)));
      report({ event: { committed: 'Committed', 'needs-recovery': 'NeedsRecovery', blocked: 'Blocked', idle: 'Idle' }[event.kind], phase: event.phase, code: event.error?.code });
    }
  } finally { await runner.close(); }
}
async function httpConsumer() {
  const body = new Uint8Array(Buffer.from(cfg.body, 'hex'));
  const request = await prepareHttp(new ResourceRef(72, cfg.resource), (1n << 64n) - 1n, {
    method: 'POST', target: [{ kind: 'literal', value: '/items/' }, { kind: 'variable', name: 'id', value: 'λ /' }],
    headers: [{ name: 'X-Tag', value: [{ kind: 'literal', value: 'one' }] },
      { name: 'X-Tag', value: [{ kind: 'literal', value: 'two' }] },
      { name: 'Authorization', value: [{ kind: 'literal', value: 'Bearer ' }, { kind: 'secret', binding: 'api', version: 7n }] }],
  }, body, { endpointRevision: 7n, reconcileBeforeMs: cfg.deadline });
  body.fill(0);
  const correlation = new Key(new TextEncoder().encode('http-correlation'), u64Codec);
  const status = new Key(new TextEncoder().encode('http-status'), u64Codec);
  const disposal = new Key(new TextEncoder().encode('http-disposal'), u64Codec);
  const followup = new Key(new TextEncoder().encode('http-followup'), u64Codec);
  const codec = { typeId: 'test.http-control', version: 1, maxEncodedBytes: 243, encode: value => new Uint8Array(value), decode: value => new Uint8Array(value) };
  const handler = {
    result: undefined, escaped: undefined,
    async initialize() {},
    async handle(turn, input) {
      assert.equal(input.kind, 'cast'); this.escaped = turn;
      if (Buffer.from(input.value).toString() === 'followup') {
        const original = await decodeHttpReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        const wrong = await decodeHttpReply(73, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        await assert.rejects(turn.followupHttp(peer, wrong, cfg.followup_reason, request), TypeError);
        await assert.rejects(turn.followupHttp(peer, original, 'automatic', request), TypeError);
        const call = await turn.followupHttp(peer, original, cfg.followup_reason, request);
        await turn.state.put(followup, call);
        this.result = { followup: false };
      } else if (Buffer.from(input.value).toString() === 'dispose') {
        const original = await decodeHttpReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        await assert.rejects(turn.releaseHttp(peer, new ResourceRef(73, original.resource.resource), original.exchange), TypeError);
        const call = await turn.releaseHttp(peer, original.resource, original.exchange);
        await turn.state.put(disposal, call);
        this.result = { released: false };
      } else if (await turn.state.find(correlation)) this.result = { called: true };
      else if (await turn.stageHttp(request)) {
        const call = await turn.callHttp(peer, request);
        await turn.state.put(correlation, call);
        this.result = { called: true };
      } else this.result = { called: false };
    },
    async handleHttpReply(turn, input) {
      this.escaped = turn;
      if (input.value.kind === 'http-rejected') {
        turn.requireReply(input, { peer, correlation: await turn.state.require(followup) });
        assert.equal(input.value.reason, 'denied');
        await turn.state.put(new Key(new TextEncoder().encode('http-followup-denied'), u64Codec), input.correlation);
        this.result = { followup: true };
        return;
      }
      if (input.value.kind === 'http-released') {
        turn.requireReply(input, { peer, correlation: await turn.state.require(disposal) });
        const original = await decodeHttpReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        assert.deepEqual(input.value.resource, original.resource);
        assert.equal(input.value.exchange, original.exchange);
        await turn.state.put(new Key(new TextEncoder().encode('http-disposed'), u64Codec), input.value.exchange);
        this.result = { released: true };
        return;
      }
      turn.requireReply(input, { peer, correlation: await turn.state.require(correlation) });
      assert.ok(input.value instanceof HttpOutcome);
      assert.equal(input.value.phase, 'observed'); assert.equal(input.value.status, 200);
      assert.equal(input.value.diagnostic.code, 'http.response_observed');
      assert.equal(input.value.diagnostic.outcome, 'completed');
      await turn.state.put(status, BigInt(input.value.status));
      this.result = { observed: true };
    },
  };
  const runner = await Runner.open(config, handler, codec, { failure: 'stop', recovery: { kind: 'fence-on-restart' } });
  let reader, outcome, owned = Buffer.alloc(0);
  try {
    if (mode === 'http-async') {
      outcome = await decodeHttpReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
      reader = await runner.openHttp(outcome);
      const first = await reader.read(); assert.ok(first.data.length); assert.ok(!first.complete);
      await writeFile(cfg.ready, '');
      while (!existsSync(cfg.continue)) await delay(10);
      const active = reader.read();
      const deadline = Date.now() + 15000;
      while (!existsSync(cfg.accepted)) { assert.ok(Date.now() < deadline); await delay(10); }
      await assert.rejects(reader.read(), Busy);
      runner.stop();
      let finished = false, beats = 0;
      const close = runner.close().then(() => { finished = true; });
      while (!finished) { beats++; await delay(10); }
      await close; await active;
      assert.ok(beats > 5); assert.ok(first.data.length);
      await assert.rejects(reader.read(), Closed);
      report({ joined: true }); return;
    }
    const input = createInterface({ input: process.stdin });
    for await (const action of input) {
      let result;
      if (action === 'step') {
        let committed = false;
        for (let i = 0; i < 32; i++) if ((await runner.next()).kind === 'committed') { committed = true; break; }
        assert.ok(committed); assert.throws(() => handler.escaped.stageHttp(request), TurnExpired);
        assert.throws(() => handler.escaped.releaseHttp(peer, new ResourceRef(72, cfg.resource), 1n), TurnExpired);
        assert.throws(() => handler.escaped.followupHttp(peer, outcome, 'retry', request), TurnExpired);
        result = handler.result;
      } else if (action === 'open') {
        outcome = await decodeHttpReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        reader = await runner.openHttp(outcome);
        await assert.rejects(runner.openHttp(outcome), Busy);
        const first = await reader.read(); assert.ok(first.data.length); assert.ok(!first.complete);
        result = { prefix: true };
      } else if (action === 'denied') {
        await assert.rejects(reader.read(), AccessDenied); result = { denied: true };
      } else if (action === 'reopen') {
        await assert.rejects(reader.read(), error => error instanceof ReadFailed && error.code === 'HttpReplayFailed');
        await reader.close(); await reader.close();
        reader = await runner.openHttp(outcome);
        for (;;) {
          const part = await reader.read(); if (!part) break;
          if (part.kind === 'response_body') owned = Buffer.concat([owned, part.data]);
        }
        assert.ok(reader.complete); await reader.close();
        result = { complete: true, body: owned.toString('hex') };
      } else if (action === 'close') {
        await runner.close(); report({ closed: true, owned: owned.toString('hex') }); return;
      } else throw new Error('Unexpected HTTP consumer command');
      report(result);
    }
  } finally { await runner.close(); }
}
async function grpcConsumer() {
  const body = new Uint8Array(Buffer.from(cfg.body, 'hex'));
  const request = await prepareGrpc(new ResourceRef(72, cfg.resource), (1n << 64n) - 1n, {
    method: await grpcMethod(new Uint8Array(Buffer.from(cfg.descriptor, 'hex')), cfg.method),
    metadata: [ { name: 'x-tag', value: { kind: 'literal', bytes: new TextEncoder().encode('one') } },
      { name: 'x-tag', value: { kind: 'literal', bytes: new TextEncoder().encode('two') } },
      { name: 'x-data-bin', value: { kind: 'literal', bytes: new Uint8Array([0, 255]) } },
      { name: 'authorization', value: { kind: 'secret', binding: 'api', version: 7n } } ],
  }, [new Uint8Array(Buffer.from(cfg.body, 'hex')), new Uint8Array()], { endpointRevision: 7n, reconcileBeforeMs: cfg.deadline });
  const correlation = new Key(new TextEncoder().encode('grpc-correlation'), u64Codec);
  const status = new Key(new TextEncoder().encode('grpc-status'), u64Codec);
  const disposal = new Key(new TextEncoder().encode('grpc-disposal'), u64Codec);
  const followup = new Key(new TextEncoder().encode('grpc-followup'), u64Codec);
  const codec = { typeId: 'test.grpc-control', version: 1, maxEncodedBytes: 243, encode: value => new Uint8Array(value), decode: value => new Uint8Array(value) };
  const handler = {
    result: undefined, escaped: undefined,
    async initialize() {},
    async handle(turn, input) {
      assert.equal(input.kind, 'cast'); this.escaped = turn;
      if (Buffer.from(input.value).toString() === 'followup') {
        const original = await decodeGrpcReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        const wrong = await decodeGrpcReply(73, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        await assert.rejects(turn.retryGrpc(peer, wrong, request), TypeError);
        const call = await turn.retryGrpc(peer, original, request);
        await turn.state.put(followup, call);
        this.result = { followup: false };
      } else if (Buffer.from(input.value).toString() === 'dispose') {
        const original = await decodeGrpcReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        await assert.rejects(turn.releaseGrpc(peer, new ResourceRef(73, original.resource.resource), original.exchange), TypeError);
        const call = await turn.releaseGrpc(peer, original.resource, original.exchange);
        await turn.state.put(disposal, call);
        this.result = { released: false };
      } else if (await turn.state.find(correlation)) this.result = { called: true };
      else if (await turn.stageGrpc(request)) {
        const call = await turn.callGrpc(peer, request);
        await turn.state.put(correlation, call);
        this.result = { called: true };
      } else this.result = { called: false };
    },
    async handleGrpcReply(turn, input) {
      this.escaped = turn;
      if (input.value.kind === 'grpc-rejected') {
        assert.equal(input.value.diagnostic.code, 'grpc.request_denied');
        turn.requireReply(input, { peer, correlation: await turn.state.require(followup) });
        assert.equal(input.value.reason, 'denied');
        await turn.state.put(new Key(new TextEncoder().encode('grpc-followup-denied'), u64Codec), input.correlation);
        this.result = { followup: true };
        return;
      }
      if (input.value.kind === 'grpc-released') {
        turn.requireReply(input, { peer, correlation: await turn.state.require(disposal) });
        const original = await decodeGrpcReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        assert.deepEqual(input.value.resource, original.resource);
        assert.equal(input.value.exchange, original.exchange);
        await turn.state.put(new Key(new TextEncoder().encode('grpc-disposed'), u64Codec), input.value.exchange);
        this.result = { released: true };
        return;
      }
      turn.requireReply(input, { peer, correlation: await turn.state.require(correlation) });
      assert.ok(input.value instanceof GrpcOutcome);
      assert.equal(input.value.phase, 'observed'); assert.equal(input.value.status, 0);
      assert.equal(input.value.diagnostic.code, 'grpc.ok_observed');
      assert.equal(input.value.diagnostic.outcome, 'completed');
      await turn.state.put(status, BigInt(input.value.status));
      this.result = { observed: true };
    },
  };
  const runner = await Runner.open(config, handler, codec, { failure: 'stop', recovery: { kind: 'fence-on-restart' } });
  let reader, outcome, owned = Buffer.alloc(0);
  try {
    if (mode === 'grpc-async') {
      outcome = await decodeGrpcReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
      reader = await runner.openGrpc(outcome);
      const first = await reader.read(); assert.ok(first.data.length); assert.ok(!first.complete);
      await writeFile(cfg.ready, '');
      while (!existsSync(cfg.continue)) await delay(10);
      const active = reader.read();
      const deadline = Date.now() + 15000;
      while (!existsSync(cfg.accepted)) { assert.ok(Date.now() < deadline); await delay(10); }
      await assert.rejects(reader.read(), Busy);
      runner.stop();
      let finished = false, beats = 0;
      const close = runner.close().then(() => { finished = true; });
      while (!finished) { beats++; await delay(10); }
      await close; await active;
      assert.ok(beats > 5); assert.ok(first.data.length);
      await assert.rejects(reader.read(), Closed);
      report({ joined: true }); return;
    }
    const input = createInterface({ input: process.stdin });
    for await (const action of input) {
      let result;
      if (action === 'step') {
        let committed = false;
        for (let i = 0; i < 32; i++) if ((await runner.next()).kind === 'committed') { committed = true; break; }
        assert.ok(committed); assert.throws(() => handler.escaped.stageGrpc(request), TurnExpired);
        assert.throws(() => handler.escaped.releaseGrpc(peer, new ResourceRef(72, cfg.resource), 1n), TurnExpired);
        assert.throws(() => handler.escaped.retryGrpc(peer, outcome, request), TurnExpired);
        result = handler.result;
      } else if (action === 'open') {
        outcome = await decodeGrpcReply(72, new Uint8Array(Buffer.from(cfg.outcome, 'hex')));
        reader = await runner.openGrpc(outcome);
        await assert.rejects(runner.openGrpc(outcome), Busy);
        const first = await reader.read(); assert.ok(first.data.length); assert.ok(!first.complete);
        result = { prefix: true };
      } else if (action === 'denied') {
        await assert.rejects(reader.read(), AccessDenied); result = { denied: true };
      } else if (action === 'reopen') {
        await assert.rejects(reader.read(), error => error instanceof ReadFailed && error.code === 'GrpcReplayFailed');
        await reader.close(); await reader.close();
        reader = await runner.openGrpc(outcome);
        for (;;) {
          const part = await reader.read(); if (!part) break;
          if (part.kind === 'response_body') owned = Buffer.concat([owned, part.data]);
        }
        assert.ok(reader.complete); await reader.close();
        result = { complete: true, body: owned.toString('hex') };
      } else if (action === 'close') {
        await runner.close(); report({ closed: true, owned: owned.toString('hex') }); return;
      } else throw new Error('Unexpected RPC consumer command');
      report(result);
    }
  } finally { await runner.close(); }
}
async function documentConsumer() {
  const { prepareDocument, decodeDocument, DocumentReference } = await import('@transit/station');
  const bytes = value => new Uint8Array(Buffer.from(value, 'hex'));
  const toHex = value => Buffer.from(value).toString('hex');
  const document = BigInt(cfg.document), replica = (1n << 64n)-1n;
  const resource = new ResourceRef(cfg.realm, cfg.resource);
  if (mode === 'document-codecs') {
    const fixtures = JSON.parse(await readFile(cfg.document_fixtures, 'utf8'));
    for (const entry of fixtures.changes) {
      const decoded = await decodeDocument(bytes(entry.wire_hex));
      assert.equal(toHex((await prepareDocument(decoded)).data), entry.wire_hex);
      for (const length of [0, 1, bytes(entry.wire_hex).length-1]) await assert.rejects(decodeDocument(bytes(entry.wire_hex).subarray(0, length)));
    }
    const ref = await DocumentReference.decode(cfg.realm, bytes(fixtures.reference_hex));
    assert.equal(ref.document, replica); assert.equal(ref.revision, replica);
    assert.equal(toHex(ref.data), fixtures.reference_hex);
    const mutable = { document, epoch: 1n, replica, first: 1n, operations: [
      { kind: 'assign', field: 'value', value: { kind: 'signed', value: -(1n<<63n) } },
      { kind: 'assign', field: 'body', value: { kind: 'text' } },
      { kind: 'insert', object: { counter: 2n, replica }, value: { kind: 'character', value: '🙂' } }] };
    const pending = prepareDocument(mutable); mutable.document = 4n; mutable.operations.length = 0;
    const prepared = await pending;
    assert.equal(prepared.document, document); assert.equal(toHex(prepared.data), cfg.changes[0]);
    prepared.data.fill(0); assert.equal(toHex(prepared.data), cfg.changes[0]);
    await assert.rejects(prepareDocument({ document, epoch: 1n, replica, first: 1n, operations: [{ kind: 'insert', object: { counter: 2n, replica }, value: { kind: 'character', value: 'é' } }] }));
    report({ codecs: true }); return;
  }
  const changes = await Promise.all(cfg.changes.map(async value => prepareDocument(await decodeDocument(bytes(value)))));
  const codec = { typeId: 'test.document.tick', version: 1, maxEncodedBytes: 32, encode: value => new Uint8Array(value), decode: value => new Uint8Array(value) };
  const handler = {
    phase: null, escaped: undefined,
    async initialize(turn) { await turn.document(document).create(); },
    async handle(turn, incoming) {
      this.escaped = turn.document(document);
      const value = Buffer.from(incoming.value).toString();
      if (value === 'initialize') return;
      if (value === '0' || value === '1') this.phase = (await this.escaped.stage(BigInt(Number(value)+1), changes[Number(value)], 256)).phase;
      else if (value === 'checkpoint') this.phase = (await this.escaped.checkpoint(90n)).phase;
      else if (value === 'window') await this.escaped.mergeWindow(2n);
      else if (value === 'retire') await this.escaped.retire();
      else throw new Error(value);
    },
  };
  const options = { failure: 'stop', recovery: { kind: 'fence-on-restart' } };
  const runner = await Runner.open({ ...config, timeoutMs: 15000 }, handler, codec, options);
  let saved;
  const input = createInterface({ input: process.stdin });
  try {
    for await (const action of input) {
      let out;
      if (action === 'close') { report({ closed: true }); return; }
      if (action === 'one') {
        handler.phase = null;
        let committed = false;
        for (let i = 0; i < 12; i++) {
          const event = await runner.next();
          if (event.kind === 'committed') { committed = true; break; }
          assert.equal(event.kind, 'progress');
        }
        assert.ok(committed); if (handler.escaped) assert.throws(() => handler.escaped.retire(), TurnExpired);
        out = { event: 'committed', phase: handler.phase };
      } else if (action === 'read') {
        const description = await runner.documents.describe(resource, document);
        const ref = description.reference;
        assert.equal(description.floor, 0n); assert.equal(description.mergeWindow, 0n);
        const field = (await runner.documents.path(ref, ['value'])).field;
        const page = await runner.documents.sequence(ref, { counter: 2n, replica });
        assert.equal(page.next, undefined);
        assert.equal(page.items.map(item => item.field.assignments[0].value.value).join(''), ref.revision === 2n ? '🙂' : '🙂́');
        assert.deepEqual(field.assignments[0].value, { kind: 'signed', value: -(1n<<63n) });
        assert.equal((await runner.documents.path(ref, ['missing'])).field.status, 'missing');
        assert.equal(toHex((await prepareDocument(await runner.documents.acceptedChange(ref))).data), cfg.changes[Number(ref.revision)-2]);
        saved ??= ref; out = { revision: ref.revision.toString(), items: page.items.length, status: field.status };
      } else if (action === 'old') {
        assert.equal((await runner.documents.path(saved, ['value'])).field.status, 'scalar'); out = { retained: true };
      } else if (action === 'denied') {
        await assert.rejects(runner.documents.path(saved, ['value']), AccessDenied); out = { denied: true };
      } else if (action === 'resynchronize') {
        const v = await runner.documents.resynchronize(resource, document, replica);
        assert.equal(v.reference.revision, 3n); out = { previous: v.previousCounter.toString(), clock: v.clock.toString() };
      } else if (action === 'retired') {
        assert.ok((await runner.documents.describe(resource, document)).retired);
        await assert.rejects(runner.documents.path(saved, ['value']), error => error.code === 'DocumentRetired'); out = { retired: true };
      } else if (action === 'async-close') {
        const other = await Runner.open(config, handler, codec, options), reader = other.documents;
        const reading = reader.describe(resource, document);
        const outcome = reading.then(() => {}, error => { assert.ok(error instanceof Closed); });
        await other.close(); await outcome;
        await assert.rejects(reader.describe(resource, document), Closed); out = { joined: true };
      } else throw new Error(action);
      report(out);
    }
  } finally { input.close(); await runner.close(); }
}

await main();
