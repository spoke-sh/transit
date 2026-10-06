import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import readline from 'node:readline';
import {Credential, ProcessRef, ResourceRef, TransitError} from '@transit/client';
import {unified as q, DocumentReference, catalog, logical} from '@transit/station';

const [mode, file] = process.argv.slice(2);
const config = JSON.parse(await readFile(file, 'utf8'));
const wide = (1n << 64n)-1n;
const hex = value => Buffer.from(value).toString('hex');
function atomValue(type, value) {
  return type === 'float64' ? {kind: 'float', width: 64, value} :
    {kind: type === 'int64' ? 'signed' : type === 'uint64' ? 'unsigned' : type, value};
}
function tableSource(resource, owner, scope, object, revision, bytes, digest, columns) {
  return {kind: 'table', owner: new ProcessRef(resource.realm, owner),
    metadata: new catalog.Metadata({scope: new catalog.Scope(resource, scope), objectId: object,
      revision, name: 'items', schemaFingerprint: '01'.repeat(32), principal: 17, operation: 1n,
      admittedInput: 1, commitment: new catalog.MetadataCommitment(bytes, digest)}),
    schema: new catalog.Schema(object, 1n, BigInt(columns.length + 1), columns)};
}
async function lookupSource(v, config) {
  const owner = new ProcessRef(v.realm, v.source);
  const client = await catalog.Client.open({url: config.url, profile: 'native_v1', timeoutMs: 10000},
    new Credential(v.realm, v.principal, config.seed_file),
    new catalog.Connection(owner, new catalog.Scope(new ResourceRef(v.realm, v.resource), 1n)));
  try {
    const definition = await client.lookup('items');
    assert.ok(definition);
    return {kind: 'table', owner, metadata: definition.metadata, schema: definition.schema};
  } finally { await client.close(); }
}
function wireType(value) {
  const {kind, ...parts} = value;
  if (kind === 'timestamp') return {timestamp: parts.zone};
  if (kind === 'decimal') return {decimal: parts};
  if (kind === 'structure' || kind === 'tagged_union') return {[kind]: parts.fields.map(wireColumn)};
  if (kind === 'list') return {list: {...parts.element, type: wireType(parts.element.type)}};
  if (kind === 'array') return {array: {length: parts.length, element: {...parts.element, type: wireType(parts.element.type)}}};
  if (kind === 'map') return {map: {key: wireType(parts.key), value: {...parts.value, type: wireType(parts.value.type)}}};
  return {[kind]: {}};
}
function wireColumn(value) { return {...value, type: wireType(value.type)}; }
async function reference(resource, document, epoch, revision) {
  // Independent SDR1 fixture; decoding through the public API establishes shape.
  const bytes = Buffer.alloc(40);
  bytes.write('SDR1'); bytes.writeBigUInt64LE(BigInt(resource.resource), 4);
  bytes.writeBigUInt64LE(document, 12); bytes.writeBigUInt64LE(epoch, 20);
  bytes.writeUInt32LE(1, 28); bytes.writeBigUInt64LE(revision, 32);
  return DocumentReference.decode(resource.realm, bytes);
}
function inspectedPredicate(value) {
  if (value === undefined) return {all: {}};
  if (value.kind === 'state') return {state: {column: value.column, value: value.state}};
  if (value.kind === 'compare') return {compare: {column: value.column, op: value.comparison, type: wireType(value.type)}};
  return {program: value.instructions.map(v => v.kind === 'atom' ? {atom: inspectedPredicate(v.atom)} : {[v.kind]: {}})};
}
async function codecs() {
  const resource = new ResourceRef(46, 7);
  const sources = [
    {kind: 'kv', resource, prefix: Buffer.from('data/'), key: {type: 'binary'}, value: {type: 'uint64'}},
    tableSource(new ResourceRef(1, 7), 3, 9n, 9n, 1n, 200, '01'.repeat(32), [
      {id: 1n, name: 'id', type: {kind: 'int64'}, nullable: false},
      {id: 2n, name: 'label', type: {kind: 'utf8'}, nullable: true},
    ]),
    {kind: 'document', reference: await reference(resource, wide, 3n, 42n), projections: [
      {column: {name: 'title', type: 'utf8'}, path: ['title']},
      {column: {name: 'body', type: 'utf8'}, path: ['body'], mode: 'text'}]},
  ];
  const fixtures = JSON.parse(await readFile(config.bundles, 'utf8'));
  for (const [index, source] of sources.entries()) {
    const bundle = await q.Bundle.prepare(source, {projection: [1, 0], limit: wide, predicate: {
      kind: 'compare', column: 1, comparison: 'ne', value: index === 0 ? {kind: 'unsigned', value: wide} : {kind: 'utf8', value: 'x'.repeat(512)},
    }}, {pages: 1000n, segments: 500n, resultBytes: 1048576n});
    assert.equal(hex(bundle.data), fixtures[index].wire_hex);
    const copy = bundle.data; copy.fill(0);
    assert.equal(hex(bundle.data), fixtures[index].wire_hex);
    const named = await q.Bundle.prepare(source, {projection: [1, 0], outputNames: ['Result', null], limit: wide, predicate: {
      kind: 'compare', column: 1, comparison: 'ne', value: index === 0 ? {kind: 'unsigned', value: wide} : {kind: 'utf8', value: 'x'.repeat(512)},
    }}, {pages: 1000n, segments: 500n, resultBytes: 1048576n});
    assert.equal(hex(named.data), fixtures[index].named_wire_hex);
    const counted = await q.Bundle.prepare(source, {projection: [1], aggregate: 'count_values', outputNames: ['present']}, {pages: 1000n, segments: 500n, resultBytes: 1048576n});
    assert.equal(hex(counted.data), fixtures[index].counted_wire_hex);
  }
  for (const source of [{...sources[0], value: {type: 'uint64', version: 2}}, {...sources[1], owner: new ProcessRef(99, 3)}])
    await assert.rejects(q.Bundle.prepare(source, {projection: [0]}, {pages: 1n, segments: 1n, resultBytes: 1n}));
  const booleanFixtures = JSON.parse(await readFile(config.boolean, 'utf8'));
  const scalarValues = [-(1n << 63n), wide, -0, true, 'café é 🙂', new Uint8Array([0, 255, 128]), 'x'.repeat(512)];
  const types = ['int64', 'uint64', 'float64', 'boolean', 'utf8', 'binary'];
  const atom = value => ({kind: 'atom', atom: value});
  for (const [index, fixture] of booleanFixtures.entries()) {
    const type = types[fixture.type - 1];
    const source = {kind: 'kv', resource, prefix: new Uint8Array(), key: {type}, value: {type: 'uint64'}};
    const instructions = index < 7 ? [atom({kind: 'compare', column: 0, comparison: 'eq', value: atomValue(type, scalarValues[index])}),
      {kind: 'negate'}, atom({kind: 'state', column: 0, state: 'null'}), {kind: 'disjunction'}]
      : fixture.name === 'all-and-not-null' ? [atom(), atom({kind: 'state', column: 0, state: 'null'}), {kind: 'negate'}, {kind: 'conjunction'}]
      : [atom(), ...Array.from({length: 63}, () => ({kind: 'negate'}))];
    const pending = q.Bundle.prepare(source, {projection: [0], predicate: {kind: 'program', instructions}}, {pages: 1000n, segments: 500n, resultBytes: 1048576n});
    instructions.length = 0; // The async boundary must already own the encoded input.
    assert.equal(hex((await pending).data), fixture.wire_hex);
  }
  const predicateSource = {kind: 'kv', resource, prefix: new Uint8Array(), key: {type: 'int64'}, value: {type: 'uint64'}};
  for (const instructions of [[], [{kind: 'negate'}], [atom(), atom()], [atom(), ...Array.from({length: 64}, () => ({kind: 'negate'}))],
    [atom({kind: 'program', instructions: [atom()]})], [atom({kind: 'state', column: 8, state: 'null'})],
    [atom({kind: 'compare', column: 0, comparison: 'eq', value: {kind: 'utf8', value: 'wrong type'}})]])
    await assert.rejects(q.Bundle.prepare(predicateSource, {projection: [0], predicate: {kind: 'program', instructions}}, {pages: 1n, segments: 1n, resultBytes: 1024n}));
  const columns = ['int64', 'uint64', 'float64', 'boolean', 'utf8', 'binary'].map(type => ({name: type, type: {kind: type}, nullable: true, optional: true}));
  const rows = await q.decodeArrow(columns, await readFile(config.arrow), 5).catch(cause => { throw new Error('six-column logical Arrow decode failed', {cause}); });
  assert.equal(rows.length, 5);
  const states = ['missing', 'null', 'type_error', 'value', 'conflict'];
  const expected = [-(1n << 63n), wide, -0, false, 'café é 東京🙂', new Uint8Array([0, 255, 128])];
  for (const [index, row] of rows.entries()) assert.ok(row.every(cell => cell.state === states[index]));
  for (const [index, value] of expected.entries()) {
    assert.deepEqual(rows[3][index].value.atom.value, value);
    assert.deepEqual(rows[4][index].alternatives.map(v => [v.counter, v.replica, v.cell.state]), [
      [wide, 1n, 'value'], [wide, 2n, 'null'],
    ]);
    assert.deepEqual(rows[4][index].alternatives[0].cell.value.atom.value, value);
  }
  assert.ok(Object.is(rows[3][2].value.atom.value, -0));
  assert.deepEqual(await q.decodeArrow(columns, await readFile(config.empty), 0), []);
  await assert.rejects(q.decodeArrow(columns, await readFile(config.malformed), 5));
  const wideColumns = Array.from({length: 128}, (_, i) => ({id: BigInt(i + 1), name: `列 ${i}`, type: {kind: 'uint128'}, nullable: true}));
  const wideSource = tableSource(new ResourceRef(1, 7), 3, 9n, 9n, 1n, 200, '01'.repeat(32), wideColumns);
  const wideBundle = await q.Bundle.prepare(wideSource, {projection: wideColumns.map((_, i) => i),
    predicate: {kind: 'compare', column: 127, comparison: 'eq', value: {kind: 'unsigned', value: (1n << 128n) - 1n}}},
    {pages: 1n, segments: 1n, resultBytes: 65536n});
  assert.ok(wideBundle.data.length > 1000);
  for (const bad of [{projection: [128]}, {projection: [0], outputNames: ['\ud800']}])
    await assert.rejects(q.Bundle.prepare(wideSource, bad, {pages: 1n, segments: 1n, resultBytes: 65536n}));
  const codec = await logical.Codec.open();
  try {
    const type = {kind: 'list', element: {type: {kind: 'uint128'}, nullable: true}};
    const json = JSON.stringify({definition: 'transit.fuze.types.v1.2026-09-30',
      field: {name: '東京', type: wireType(type)},
      cell: {value: {list: [{value: {atom: {unsigned: ((1n << 128n) - 1n).toString()}}}, {null: {}}]}}});
    const value = await logical.Value.fromJson(codec, json);
    const rows = await q.decodeArrow([{name: 'value', type}], await codec.arrow(value), 1).catch(cause => { throw new Error('nested logical Arrow decode failed', {cause}); });
    assert.deepEqual(rows[0][0], {state: 'value', value: {kind: 'list', cells: [
      {state: 'value', value: {kind: 'atom', atom: {kind: 'unsigned', value: (1n << 128n) - 1n}}}, {state: 'null'},
    ]}});
  } finally { await codec.close(); }
  console.log('Node installed unified codecs: three sources, nine Boolean bundles, six scalar types, nested uint128, 128 columns, five states, owned buffers and malformed rejection passed');
}
async function serve() {
  const v = config.connection, resource = new ResourceRef(v.realm, v.resource);
  const connection = new q.Connection(new ProcessRef(v.realm, v.source), resource,
    new ProcessRef(v.realm, v.requester), new ResourceRef(v.realm, v.requests));
  const source = config.kind === 'kv' ? {kind: 'kv', resource, prefix: Buffer.from('k'), key: {type: 'binary'}, value: {type: 'utf8'}}
    : config.kind === 'table' ? await lookupSource(v, config)
    : {kind: 'document', reference: await reference(resource, 17n, 1n, 13n), expand: ['items'], projections: [
        {column: {name: 'value', type: 'utf8'}, relative: true},
        {column: {name: 'counter', type: 'uint64'}, relative: true, mode: 'element_counter'},
        {column: {name: 'replica', type: 'uint64'}, relative: true, mode: 'element_replica'},
        {column: {name: 'optional', type: 'utf8'}, path: ['optional']},
      ]};
  const doc = config.kind === 'document', column = doc ? 0 : 1;
  let predicate = {kind: 'compare', column, comparison: 'ne', value: {kind: 'utf8', value: 'x'.repeat(512)}};
  if (config.compound) predicate = {kind: 'program', instructions: [
    {kind: 'atom', atom: predicate},
    {kind: 'atom', atom: {kind: 'compare', column, comparison: 'ge', value: {kind: 'utf8', value: `東京🙂/${'x'.repeat(doc ? 64 : 128)}/${doc ? '10' : '39'}`}}},
    {kind: 'atom', atom: {kind: 'state', column, state: 'null'}},
    {kind: 'disjunction'}, {kind: 'negate'}, {kind: 'conjunction'},
  ]};
  const bundle = await q.Bundle.prepare(source, {projection: doc ? [0, 1, 2, 3] : [1],
    outputNames: doc ? ['Result', null, null, null] : ['Result'], predicate}, {pages: 1000n, segments: 100n, resultBytes: 1048576n});
  assert.equal(hex(bundle.data), hex(await readFile(config.bundle)));
  const client = await q.Client.open({url: config.url, profile: 'native_v1', timeoutMs: 10000},
    new Credential(v.realm, v.principal, config.seed_file), connection);
  try {
    const description = await client.describe(source);
    assert.equal(description.bundleBytes, 25069); assert.equal(description.batchRows, 8);
    console.log(JSON.stringify({ready: true}));
    for await (const line of readline.createInterface({input: process.stdin})) {
      const action = JSON.parse(line);
      if ('close' in action) break;
      try {
        let result;
        if ('compile' in action) {
          const request = action.compile, limits = request.scope.limits;
          const parameters = request.parameters?.map(item => {
            const [type, input] = Object.entries(item)[0];
            const value = ['signed', 'unsigned', 'decimal', 'date_days', 'time_nanos', 'timestamp_micros'].includes(type) ? BigInt(input)
              : type === 'float_bits' ? (input.length === 8 ? Buffer.from(input, 'hex').readFloatLE() : Buffer.from(input, 'hex').readDoubleLE())
              : type === 'binary' ? Buffer.from(input, 'hex') : input;
            return type === 'float_bits' ? {kind: 'float', width: input.length === 8 ? 32 : 64, value} : {kind: type, value};
          });
          const pending = client.compileSql(source, request.scope.name, request.sql, {
            pages: BigInt(limits.pages), segments: BigInt(limits.segments), resultBytes: BigInt(limits.result_bytes),
          }, parameters);
          parameters?.splice(0); // The pending operation owns its inputs.
          const compiled = await pending;
          result = {compiled: {bundle: hex(compiled.data)}};
        } else if ('inspect' in action) {
          const request = action.inspect, limits = request.scope.limits;
          const value = await client.inspectSql(source, request.scope.name, request.sql, {
            pages: BigInt(limits.pages), segments: BigInt(limits.segments), resultBytes: BigInt(limits.result_bytes),
          });
          assert.deepEqual(value.resource, resource); assert.equal(value.sourceKind, config.kind);
          const d = value.details;
          const details = d.kind === 'description' ? {description: {columns: d.columns.map(wireColumn)}} : d.kind === 'tables' ? {tables: d.names} : {
            explanation: {operators: d.operators, predicate: inspectedPredicate(d.predicate),
              projection: d.projection, limit: d.limit?.toString() ?? null, aggregate: d.aggregate, columns: d.columns.map(wireColumn),
              budgets: {pages: d.budgets.pages.toString(), segments: d.budgets.segments.toString(), result_bytes: d.budgets.resultBytes.toString()}},
          };
          result = {inspection: {version: 1, scope: 'configured_source', name: value.name, resource: value.resource.resource,
            source_kind: value.sourceKind, contract: [...value.sourceDigest], schema: [...value.schemaDigest],
            resource_revision: value.resourceRevision, policy_revision: value.policyRevision.toString(), details}};
        } else if ('next' in action) {
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
          result = {status: value ? {phase: value.phase, correlation: value.correlation.toString(), diagnostic: value.diagnostic, failure: value.failure && {...value.failure, limit: value.failure.limit.toString(), observed: value.failure.observed.toString()}} : null};
        } else if ('page' in action) {
          const v = action.page;
          const value = await client.page(BigInt(v.namespace), v.cursor == null ? undefined : new q.Cursor(v.cursor));
          assert.deepEqual(value.manifest.resource, resource); assert.equal(value.manifest.sourceKind, config.kind);
          assert.equal((await value.decode()).length, value.rows);
          const {unifiedToArrow} = await import('@transit/station/arrow');
          assert.equal(unifiedToArrow(value).numRows, value.rows);
          const ipc = value.ipc; ipc.fill(0); assert.notEqual(hex(ipc), hex(value.ipc));
          result = {page: {ordinal: value.ordinal.toString(), ipc: hex(value.ipc),
            manifest: {segments: value.manifest.segments.toString(), selected: value.manifest.selected.toString(), value_count: value.manifest.valueCount.toString()}, next: value.next?.data ?? null}};
        } else throw new Error('unsupported test operation');
        console.log(JSON.stringify({status: 0, value: result}));
      } catch (error) {
        if (!(error instanceof TransitError)) throw error;
        console.log(JSON.stringify({status: error.status, value: {err: error.code, diagnostic: error.diagnostic ?? null, diagnostic_invalid: error.diagnosticInvalid}}));
      }
    }
  } finally { await client.close(); }
  console.log(JSON.stringify({closed: true}));
}
if (mode === 'codecs') await codecs(); else await serve();
