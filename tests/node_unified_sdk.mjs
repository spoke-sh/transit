import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import readline from 'node:readline';
import {Credential, ProcessRef, ResourceRef, TransitError} from '@transit/client';
import {unified as q, DocumentReference} from '@transit/station';

const [mode, file] = process.argv.slice(2);
const config = JSON.parse(await readFile(file, 'utf8'));
const wide = (1n << 64n)-1n;
const hex = value => Buffer.from(value).toString('hex');
async function reference(resource, document, epoch, revision) {
  // Independent SDR1 fixture; decoding through the public API establishes shape.
  const bytes = Buffer.alloc(40);
  bytes.write('SDR1'); bytes.writeBigUInt64LE(BigInt(resource.resource), 4);
  bytes.writeBigUInt64LE(document, 12); bytes.writeBigUInt64LE(epoch, 20);
  bytes.writeUInt32LE(1, 28); bytes.writeBigUInt64LE(revision, 32);
  return DocumentReference.decode(resource.realm, bytes);
}
async function codecs() {
  const resource = new ResourceRef(46, 7);
  const sources = [
    {kind: 'kv', resource, prefix: Buffer.from('data/'), key: {type: 'binary'}, value: {type: 'uint64'}},
    {kind: 'table', resource, table: 9, names: ['id', 'label'], valueType: 'utf8'},
    {kind: 'document', reference: await reference(resource, wide, 3n, 42n), projections: [
      {column: {name: 'title', type: 'utf8'}, path: ['title']},
      {column: {name: 'body', type: 'utf8'}, path: ['body'], mode: 'text'}]},
  ];
  const fixtures = JSON.parse(await readFile(config.bundles, 'utf8'));
  for (const [index, source] of sources.entries()) {
    const bundle = await q.Bundle.prepare(source, {projection: [1, 0], limit: wide, predicate: {
      kind: 'compare', column: 1, comparison: 'ne', value: index === 0 ? {type: 'uint64', value: wide} : {type: 'utf8', value: 'x'.repeat(512)},
    }}, {pages: 1000n, segments: 500n, resultBytes: 1048576n});
    assert.equal(hex(bundle.data), fixtures[index].wire_hex);
    const copy = bundle.data; copy.fill(0);
    assert.equal(hex(bundle.data), fixtures[index].wire_hex);
  }
  for (const source of [{...sources[0], value: {type: 'uint64', version: 2}}, {...sources[1], valueType: 'uint64'}])
    await assert.rejects(q.Bundle.prepare(source, {projection: [0]}, {pages: 1n, segments: 1n, resultBytes: 1n}));
  const columns = ['int64', 'uint64', 'float64', 'boolean', 'utf8', 'binary'].map(type => ({name: type, type}));
  const rows = await q.decodeArrow(columns, await readFile(config.arrow), 5);
  assert.equal(rows.length, 5);
  const states = ['missing', 'null', 'type_error', 'value', 'conflict'];
  const expected = [-(1n << 63n), wide, -0, false, 'café é 東京🙂', new Uint8Array([0, 255, 128])];
  for (const [index, row] of rows.entries()) assert.ok(row.every(cell => cell.state === states[index]));
  for (const [index, value] of expected.entries()) {
    assert.deepEqual(rows[3][index].value.value, value);
    assert.deepEqual(rows[4][index].alternatives.map(v => [v.counter, v.replica, v.state]), [
      [wide, 1n, 'value'], [wide, 2n, 'null'],
    ]);
    assert.deepEqual(rows[4][index].alternatives[0].value.value, value);
  }
  assert.ok(Object.is(rows[3][2].value.value, -0));
  assert.deepEqual(await q.decodeArrow(columns, await readFile(config.empty), 0), []);
  await assert.rejects(q.decodeArrow(columns, await readFile(config.malformed), 5));
  console.log('Node installed unified codecs: three sources, six types, five states, owned buffers and malformed rejection passed');
}
async function serve() {
  const v = config.connection, resource = new ResourceRef(v.realm, v.resource);
  const connection = new q.Connection(new ProcessRef(v.realm, v.source), resource,
    new ProcessRef(v.realm, v.requester), new ResourceRef(v.realm, v.requests));
  const source = config.kind === 'kv' ? {kind: 'kv', resource, prefix: Buffer.from('k'), key: {type: 'binary'}, value: {type: 'utf8'}}
    : config.kind === 'table' ? {kind: 'table', resource, table: 1, names: ['id', 'value'], valueType: 'utf8'}
    : {kind: 'document', reference: await reference(resource, 17n, 1n, 13n), expand: ['items'], projections: [
        {column: {name: 'value', type: 'utf8'}, relative: true},
        {column: {name: 'counter', type: 'uint64'}, relative: true, mode: 'element_counter'},
        {column: {name: 'replica', type: 'uint64'}, relative: true, mode: 'element_replica'},
        {column: {name: 'optional', type: 'utf8'}, path: ['optional']},
      ]};
  const bundle = await q.Bundle.prepare(source, {projection: config.kind === 'document' ? [0, 1, 2, 3] : [1], predicate: {
    kind: 'compare', column: config.kind === 'document' ? 0 : 1, comparison: 'ne', value: {type: 'utf8', value: 'x'.repeat(512)},
  }}, {pages: 1000n, segments: 100n, resultBytes: 1048576n});
  assert.equal(hex(bundle.data), hex(await readFile(config.bundle)));
  const client = await q.Client.open({url: config.url, profile: 'growing_v3', timeoutMs: 10000},
    new Credential(v.realm, v.principal, config.seed_file), connection);
  try {
    const description = await client.describe(source);
    assert.equal(description.bundleBytes, 16384); assert.equal(description.batchRows, 8);
    console.log(JSON.stringify({ready: true}));
    for await (const line of readline.createInterface({input: process.stdin})) {
      const action = JSON.parse(line);
      if ('close' in action) break;
      try {
        let result;
        if ('next' in action) {
          const prepared = await client.prepareNext(BigInt(action.next.namespace), new q.Bundle(Buffer.from(action.next.bundle, 'hex')));
          result = {prepared: prepared?.data ?? null};
        } else if ('submit' in action) {
          const prepared = new q.Prepared(action.submit);
          try { result = {receipt: await client.submit(prepared)}; }
          catch (error) { if (error instanceof q.Uncertain) assert.equal(error.prepared.data, prepared.data); throw error; }
        } else if ('observe' in action) {
          const value = await client.observe(action.observe);
          result = {observation: {[value.state]: value.state === 'rejected' ? Buffer.from(value.reason).toString('hex') : {}}};
        } else if ('status' in action) {
          const value = await client.status(BigInt(action.status));
          result = {status: value ? {phase: value.phase, correlation: value.correlation.toString()} : null};
        } else if ('page' in action) {
          const v = action.page;
          const value = await client.page(BigInt(v.namespace), v.cursor == null ? undefined : new q.Cursor(v.cursor));
          assert.deepEqual(value.manifest.resource, resource); assert.equal(value.manifest.sourceKind, config.kind);
          assert.equal((await value.decode()).length, value.rows);
          const {unifiedToArrow} = await import('@transit/station/arrow');
          assert.equal(unifiedToArrow(value).numRows, value.rows);
          const ipc = value.ipc; ipc.fill(0); assert.notEqual(hex(ipc), hex(value.ipc));
          result = {page: {ordinal: value.ordinal.toString(), ipc: hex(value.ipc),
            manifest: {segments: value.manifest.segments.toString()}, next: value.next?.data ?? null}};
        } else throw new Error('unsupported test operation');
        console.log(JSON.stringify({status: 0, value: result}));
      } catch (error) {
        if (!(error instanceof TransitError)) throw error;
        console.log(JSON.stringify({status: error.status, value: {err: error.code}}));
      }
    }
  } finally { await client.close(); }
  console.log(JSON.stringify({closed: true}));
}
if (mode === 'codecs') await codecs(); else await serve();
