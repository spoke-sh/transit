import assert from 'node:assert/strict';
import { readFile, open } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { createInterface } from 'node:readline';
import { Credential, ProcessRef, ResourceRef, TransitError } from '@transit/client';
import { catalog as m } from '@transit/station';

assert.ok(import.meta.resolve('@transit/station').startsWith(new URL('./node_modules/', import.meta.url).href));
const config = JSON.parse(await readFile(process.argv[2], 'utf8'));
const c = config.connection;
const scope = new m.Scope(new ResourceRef(c.scope.realm, c.scope.resource), BigInt(c.scope.catalog));
const connection = new m.Connection(new ProcessRef(c.scope.realm, c.owner), scope);
const credential = new Credential(c.scope.realm, c.principal, config.seed_file);
const connect = () => m.Client.open({url:config.url, profile:'native_v1', timeoutMs:10000}, credential, connection);
let client = await connect();
async function persist(name, data) {
  const file = await open(join(dirname(process.argv[2]), name), 'w', 0o600);
  try { await file.writeFile(data); await file.sync(); } finally { await file.close(); }
}
const identity = operation => new m.Identity(BigInt(operation), BigInt(operation + 100000));
async function finish(compiled) {
  await persist('intent.bin', compiled.saved.bytes);
  const ref = compiled.intent.reference;
  const deadline = Date.now() + 120000;
  while (Date.now() < deadline) {
    const step = await client.next(ref);
    if (step.kind === 'terminal') return step.outcome;
    if (step.kind === 'running') continue;
    assert.equal(step.kind, 'send');
    await persist('step.json', step.prepared.data);
    const input = await client.submit(step.prepared);
    await persist('receipt.json', JSON.stringify({position:input.position}));
    while (Date.now() < deadline) {
      const progress = await client.progress(ref, step.prepared, input.position, true);
      if (progress.kind === 'pending') continue;
      assert.equal(progress.disposition, undefined);
      if (progress.outcome?.terminal) return progress.outcome;
      break;
    }
  }
  throw new Error('Installed Table operation exceeded its budget');
}
const atom = (kind, value) => ({state:'value', value:{kind:'atom', atom:{kind,value}}});
async function scenario(index) {
  const base = 1100 + index * 100;
  const object = BigInt(12001 + index * 10);
  const name = `sdk_people_${index}`;
  const ids = offset => identity(base + offset);
  const description = await client.describe();
  assert.equal(description.configuration.scope.catalog, scope.catalog);
  assert.equal(description.policy.principal, credential.principal);
  const compiled = await client.compileSql(`CREATE TABLE ${name} (id INTEGER PRIMARY KEY, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2))`, ids(0), object);
  const created = await finish(compiled);
  assert.equal(created.phase, 'applied');
  const original = await client.lookup(name);
  assert.equal(original.schema.columns.length, 3);
  const payload = {state:'value',value:{kind:'structure',cells:[atom('binary',new Uint8Array([0,128,255])),atom('utf8','東京')]}};
  const insert = await client.prepare(name, ids(1), {kind:'mutate', basis:original.metadata.basis, mutation:{kind:'insert',rows:[[
    {column:3n,value:atom('decimal',123456789012345678901234567890n)},
    {column:1n,value:atom('signed',1n)}, {column:2n,value:payload},
  ]]}});
  const applied = await finish(insert);
  assert.deepEqual(applied.counts,{matched:1n,changed:1n});
  const saved = insert.saved;
  const unchanged = await finish(await client.prepare(name,ids(2),{kind:'mutate',basis:original.metadata.basis,mutation:{kind:'update',assignments:[{column:3n,value:atom('decimal',123456789012345678901234567890n)}],predicate:[{kind:'compare',column:1n,op:'eq',value:{kind:'signed',value:1n}}]}}));
  assert.deepEqual(unchanged.counts,{matched:1n,changed:0n});
  const altered = await finish(await client.prepare(name,ids(3),{kind:'alter',basis:original.metadata.basis,change:{kind:'add',column:{name:'enabled',type:{kind:'boolean'},nullable:false,default:atom('boolean',true)}}}));
  assert.equal(altered.phase,'applied');
  await assert.rejects(client.prepare(name,ids(4),{kind:'drop',basis:original.metadata.basis}), TransitError);
  const current = await client.lookup(name);
  const deleted = await finish(await client.prepare(name,ids(5),{kind:'mutate',basis:current.metadata.basis,mutation:{kind:'delete',predicate:[{kind:'compare',column:1n,op:'eq',value:{kind:'signed',value:1n}}]}}));
  assert.deepEqual(deleted.counts,{matched:1n,changed:1n});
  assert.equal((await finish(await client.prepare(name,ids(6),{kind:'drop',basis:current.metadata.basis}))).phase,'applied');
  assert.equal((await finish(await client.compileSql(`CREATE TABLE ${name} (replacement TEXT)`,ids(7),(object + 1n)))).phase,'applied');
  await client.close(); client = await connect();
  const loaded = await client.load(new m.SavedIntent(saved.definition,saved.bytes));
  assert.equal(loaded.objectId,object);
  assert.deepEqual((await client.status(loaded.reference)).outcome,applied);
  assert.equal((await client.lookup(name)).metadata.objectId,(object + 1n));
  const page = await client.list(); assert.ok(page.entries.length > 0);
  return {profile:'installed-node-general-table',original_object:loaded.objectId.toString(),replacement_object:(object + 1n).toString(),counts:{matched:applied.counts.matched.toString(),changed:applied.counts.changed.toString()}};
}
try {
  console.log(JSON.stringify({ready:true}));
  for await (const line of createInterface({input:process.stdin})) {
    const action = JSON.parse(line);
    if ('close' in action) break;
    assert.ok('scenario' in action);
    console.log(JSON.stringify({status:0,value:await scenario(action.scenario.index)}));
  }
} finally { await client.close(); }
console.log(JSON.stringify({closed:true}));
