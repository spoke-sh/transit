import assert from 'node:assert/strict';
import { readFile, open, mkdir } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { createInterface } from 'node:readline';
import { Credential, ResourceRef, TransitError } from '@transit/client';
import { catalog as m, relational as r } from '@transit/station';

assert.ok(import.meta.resolve('@transit/station').startsWith(new URL('./node_modules/', import.meta.url).href));
const config = JSON.parse(await readFile(process.argv[2], 'utf8'));
const c = config.connection;
const scope = new m.Scope(new ResourceRef(c.scope.realm, c.scope.resource), BigInt(c.scope.catalog));
const connection = new m.Connection(scope, c.audience, BigInt(c.branch), c.role ?? undefined);
const credential = new Credential(c.scope.realm, c.principal, config.seed_file);
const configuration = {url:config.url, profile:'native_v1', timeoutMs:10000, serviceUrl:config.service_url};
const client = await m.Client.open(configuration, credential, connection);
const root = join(dirname(process.argv[2]), 'node');
await mkdir(root, {recursive:true});
const query = await r.Client.open(configuration, credential, [connection], {
  consistency:'independent_table_snapshots', residentBytes:16777216n, spillBytes:16777216n, resultBytes:8388608n,
  outputRows:1000n, workSteps:100000n, sourcePins:2, requests:100000n, spillWork:100000n, spillDirectory:root,
});
const name = 'node_items', objectId = (1n << 64n)-2n;
let identity = '00000000000000000000000000000001', opened, sources;
const statement = {namespace:1, sql:`SELECT id FROM ${name}`, routes:[0]};
const read = filename => readFile(join(root, filename), 'utf8');
async function persist(filename, data) {
  const file = await open(join(root, filename), 'w', 0o600);
  try { await file.writeFile(data); await file.sync(); } finally { await file.close(); }
}
const compiled = (sql, operation, createObject) => client.compileSql(sql, new m.Identity(BigInt(operation)), createObject === undefined ? {} : {createObject});
async function complete(work) {
  await persist('work.json', work.saved.save());
  const original = await client.stage(work.intent);
  await persist('work-reference.json', original.save());
  let observed = await client.admit(original);
  for (let i=0; i<16 && observed.state === 'admitted'; i++) observed = await client.execute(original, 32);
  assert.equal(observed.state, 'committed');
  return observed;
}
async function uncertain(invoke, original) {
  await assert.rejects(invoke, error => {
    assert(error instanceof m.Uncertain);
    assert.equal(error.recovery.save(), original.save());
    assert.equal(error.status, 6);
    assert.equal(error.diagnostic.outcome, 'unknown');
    assert.equal(error.diagnosticInvalid, false);
    return true;
  });
}
const snapshot = async () => m.Snapshot.restore(await read('snapshot.json'));
async function openRetained() {
  const basis = m.Basis.restore(await read('basis.json'));
  sources = [{basis, snapshot:await snapshot()}];
  opened = await query.openQuery(identity, statement, sources);
  const repeated = await query.openQuery(identity, statement, sources);
  assert.deepEqual(opened, repeated);
  assert.equal(opened.description.sources[0].basis.save(), basis.save());
  assert.equal(opened.completeCoverage, false);
}
const atom = (kind, value) => ({state:'value', value:{kind:'atom', atom:{kind,value}}});
const write = value => console.log(JSON.stringify({status:0,value}));
try {
  console.log(JSON.stringify({ready:true}));
  for await (const line of createInterface({input:process.stdin})) {
    const action = JSON.parse(line);
    if ('close' in action) break;
    const command = Object.keys(action)[0];
    if (command === 'prepare') {
      assert.equal((await client.describe()).subject.principal, c.principal);
      await complete(await compiled(`CREATE TABLE ${name} (id BIGINT PRIMARY KEY, payload BINARY)`, 1, objectId));
      const current = await client.lookup(name);
      assert.equal(current.rowCount, 0n);
      assert.equal(current.basis.definition.interpretation.object.objectId, objectId);
      const rows = Array.from({length:9}, (_, i) => [
        {column:1n, value:atom('signed', BigInt(i))}, {column:2n, value:atom('binary', new Uint8Array(32768).fill(i))},
      ]);
      const work = await client.prepare(name, new m.Identity(2n), {kind:'mutate', basis:current.basis, mutation:{kind:'insert', rows}, ingestion:'bulk'});
      assert.equal((await client.preview(work.intent)).current.rowCount, 0n);
      await persist('intent.json', work.saved.save());
      const loaded = await client.load(m.SavedIntent.restore(await read('intent.json')));
      const original = await client.stage(loaded);
      await persist('original.json', original.save());
      assert.equal((await client.admit(original)).state, 'admitted');
      await uncertain(() => client.execute(original, 32), original);
      write({uncertain:true, operation:original.operation.toString()});
    } else if (command === 'recover') {
      const original = m.Reference.restore(await read('original.json'));
      const observed = await client.inspect(original);
      assert.equal(observed.state, 'committed');
      assert.deepEqual([observed.commit.matched, observed.commit.affected, observed.commit.liveRows], [9n,9n,9n]);
      assert.deepEqual(await client.execute(original, 32), observed);
      const current = await client.lookup(name);
      const acquisition = client.prepareSnapshot(current, 90000n);
      await persist('basis.json', current.basis.save());
      await persist('acquisition.json', acquisition.save());
      await uncertain(() => client.acquireSnapshot(acquisition), acquisition);
      write({retention_uncertain:true});
    } else if (command === 'retained') {
      const acquisition = m.SnapshotAcquisition.restore(await read('acquisition.json'));
      const status = await client.snapshotStatus(acquisition.owner);
      assert(!status.released && status.snapshot);
      await persist('snapshot.json', status.snapshot.save());
      const metadata = await client.snapshotMetadata(status.snapshot);
      assert.deepEqual(metadata.accepted, acquisition.expected);
      assert.equal(metadata.rowCount, 9n);
      const explained = await query.explain(statement);
      assert.equal(explained.sources[0].basis.save(), m.Basis.restore(await read('basis.json')).save());
      await openRetained();
      assert.deepEqual(opened.cuts[0].position, acquisition.expected);
      const first = await query.page(opened.reference, 0n);
      assert.deepEqual(first.row.cells, [0n]); assert.equal(first.completeCoverage, false);
      assert.deepEqual(await query.page(opened.reference, 0n), first);
      write({opened:true});
    } else if (command === 'denied') {
      for (const invoke of [() => query.page(opened.reference, BigInt(action[command].ordinal)), () => query.openQuery(identity, statement, sources)]) {
        await assert.rejects(invoke, error => {
          assert(error instanceof TransitError && error.status === 4);
          assert.equal(error.diagnostic.category, 'access');
          return true;
        });
      }
      write({denied:true});
    } else if (command === 'rows') {
      for (let ordinal=0n; ordinal<9n; ordinal++) {
        const page = await query.page(opened.reference, ordinal);
        assert.deepEqual(page.row.cells, [ordinal]); assert.equal(page.completeCoverage, false);
        assert.deepEqual(await query.page(opened.reference, ordinal), page);
      }
      const page = await query.page(opened.reference, 9n);
      assert.equal(page.completeCoverage, true); assert.equal(page.row, undefined);
      assert.deepEqual(await query.page(opened.reference, 9n), page);
      write({rows:9, complete:true});
    } else if (command === 'retire') {
      assert.equal((await query.page(opened.reference, 9n)).completeCoverage, true);
      await query.closeQuery(opened.reference);
      const unchanged = await complete(await compiled(`UPDATE ${name} SET id = 0 WHERE id = 0`, 3));
      assert.deepEqual([unchanged.commit.matched, unchanged.commit.affected], [1n,0n]);
      const deleted = await complete(await compiled(`DELETE FROM ${name} WHERE id = 8`, 4));
      assert.deepEqual([deleted.commit.matched, deleted.commit.affected], [1n,1n]);
      await complete(await compiled(`ALTER TABLE ${name} ADD COLUMN extra BIGINT`, 5));
      await complete(await compiled(`ALTER TABLE ${name} RENAME TO ${name}_old`, 6));
      await complete(await compiled(`DROP TABLE ${name}_old`, 7));
      await complete(await compiled(`CREATE TABLE ${name} (replacement BIGINT)`, 8, objectId-1n));
      assert.equal((await client.lookup(name)).basis.definition.interpretation.object.objectId, objectId-1n);
      assert.equal((await client.snapshotMetadata(await snapshot())).rowCount, 9n);
      identity = '00000000000000000000000000000002';
      await openRetained();
      write({original:true});
    } else if (command === 'release') {
      await query.closeQuery(opened.reference); await query.closeQuery(opened.reference);
      const retained = await snapshot();
      assert.equal((await client.snapshotStatus(retained.owner)).released, false);
      await uncertain(() => client.releaseSnapshot(retained), retained);
      write({release_uncertain:true});
    } else if (command === 'verify') {
      const retained = await snapshot();
      assert.equal((await client.snapshotStatus(retained.owner)).released, true);
      await client.releaseSnapshot(retained);
      const original = m.Reference.restore(await read('original.json'));
      assert.equal((await client.inspect(original)).commit.affected, 9n);
      assert.equal((await client.load(m.SavedIntent.restore(await read('intent.json')))).operation, original.operation);
      assert.equal((await client.lookup(name)).basis.definition.interpretation.object.objectId, objectId-1n);
      assert.equal((await client.tables(1)).consistency, 'independent');
      write({recovered:true});
    } else if (command === 'history_begin') {
      const key = client.prepareHistoryKey(new Uint8Array(32).fill(67), Buffer.from((92000n).toString(16).padStart(32, '0'), 'hex'));
      const step = client.prepareHistoryStep(client.prepareHistorySelection(92000n), 1, name);
      await persist('history-step.json', step.save());
      const selected = await client.selectHistory(step);
      const original = client.prepareHistoryAcquisition(selected, key);
      await persist('history-acquisition.json', original.save());
      await uncertain(() => client.acquireHistory(original), original);
      write({history_uncertain:true});
    } else if (command === 'history_recover') {
      const original = m.HistoryAcquisition.restore(await read('history-acquisition.json'));
      let status = await client.inspectHistory(original.key);
      assert.equal(status.intent.operation, 92000n);
      for (let i=0; i<16 && status.phase !== 'published'; i++) status = await client.advanceHistory(original.key);
      assert.equal(status.phase, 'published'); assert.equal(status.basis.consistency.kind, 'single_partition');
      assert.deepEqual((await client.acquireHistory(original)).basis, status.basis);
      await persist('history-snapshot.json', status.basis.snapshot.save());
      const source = await client.historicalSource(status.basis.snapshot, objectId);
      assert.equal(source.rowCount, 9n); assert.equal(source.schema.columns.length, 2);
      write({published:true});
    } else if (command === 'history_denied') {
      const retained = m.HistoricalSnapshot.restore(await read('history-snapshot.json'));
      for (const invoke of [() => client.historicalSource(retained, objectId), () => client.historicalTables(retained, 1)]) {
        await assert.rejects(invoke, error => error instanceof TransitError && error.status === 4 && !(error instanceof m.Uncertain));
      }
      write({denied:true});
    } else if (command === 'history_inspect') {
      const retained = m.HistoricalSnapshot.restore(await read('history-snapshot.json'));
      assert.equal(await client.historicalLookup(retained, 1, name), objectId);
      const source = await client.historicalSource(retained, objectId);
      assert.equal(source.rowCount, 9n); assert.equal(source.schema.columns.length, 2);
      const page = await client.historicalTables(retained, 1);
      assert.equal(page.entries.length, 1); assert.equal(page.next, undefined); assert.equal(page.entries[0].name, name);
      assert.deepEqual(page.entries[0].definition, source.binding.definition);
      assert.equal(page.basis.snapshot.selector, retained.selector); assert.equal(page.basis.sourceCount, 1n);
      write({original:true});
    } else if (command === 'history_release') {
      const retained = m.HistoricalSnapshot.restore(await read('history-snapshot.json'));
      assert.equal((await client.historicalSource(retained, objectId)).rowCount, 9n);
      const original = m.HistoryAcquisition.restore(await read('history-acquisition.json'));
      const control = client.prepareHistoryControl(original.key, 'release');
      await persist('history-control.json', control.save());
      await uncertain(() => client.resumeHistoryControl(control), control);
      write({history_release_uncertain:true});
    } else if (command === 'history_finish') {
      const control = m.HistoryControl.restore(await read('history-control.json'));
      let status = await client.inspectHistory(control.key);
      assert(['releasing','released'].includes(status.phase));
      for (let i=0; i<16 && status.phase !== 'released'; i++) status = await client.advanceHistory(control.key);
      assert.equal(status.phase, 'released');
      assert.equal((await client.resumeHistoryControl(control)).phase, 'released');
      const retained = m.HistoricalSnapshot.restore(await read('history-snapshot.json'));
      assert.equal(status.basis.snapshot.selector, retained.selector);
      await assert.rejects(() => client.historicalSource(retained, objectId), error => error instanceof TransitError && !(error instanceof m.Uncertain));
      write({released:true});
    } else throw new Error(`Unknown proof phase: ${command}`);
  }
} finally { await query.close(); await client.close(); }
console.log(JSON.stringify({closed:true}));
