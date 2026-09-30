import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { Credential, ProcessRef, ResourceRef, TransitError } from '@transit/client';
import { mutations as m } from '@transit/station';

const config = JSON.parse(await readFile(process.argv[2], 'utf8'));
assert.ok(import.meta.resolve('@transit/station').startsWith(new URL('./node_modules/',import.meta.url).href));
const c = config.connection;
const connection = new m.Connection(new ProcessRef(c.realm,c.writer),new ResourceRef(c.realm,c.resource),c.table);
const client = await m.Client.open({ url:config.url,profile:'native_v1',timeoutMs:10000 },
  new Credential(c.realm,c.principal,config.seed_file),connection);
const hex = value => Buffer.from(value).toString('hex');
const ref = value => new m.Reference(new Uint8Array(Buffer.from(value,'hex')));
const prepared = value => new m.Prepared(value);
function compiled(value) {
  const bytes = new Uint8Array(Buffer.from(value.request,'hex'));
  const result = new m.Compiled(bytes,ref(value.reference));
  bytes.fill(0); result.request.fill(0); result.reference.data.fill(0);
  assert.equal(hex(result.request),value.request);
  assert.equal(hex(result.reference.data),value.reference);
  return result;
}
async function call(action) {
  if ('capabilities' in action) return { capabilities:{ version:1,max_rows:3 } };
  if ('describe' in action) {
    const v = await client.describe();
    return { description:{ resource:v.resource.resource,table:v.table,names:v.names,value_type:v.valueType,
      resource_revision:v.resourceRevision,policy_revision:v.policyRevision.toString(),declaration:hex(v.declaration),
      permissions:v.permissions,active:v.active?.toString() ?? null } };
  }
  if ('compile' in action) {
    const v = action.compile;
    const result = await client.compileSql(v.name,v.sql,BigInt(v.namespace));
    return { compiled:{ request:hex(result.request),reference:hex(result.reference.data) } };
  }
  if ('next' in action) return { prepared:(await client.prepareNext(compiled(action.next)))?.data ?? null };
  if ('prepare' in action) {
    const [name,value] = Object.entries(action.prepare)[0];
    assert.ok(name === 'apply' || name === 'cancel');
    return { prepared:(await client[name === 'apply' ? 'prepareApply' : 'prepareCancel'](ref(value))).data };
  }
  if ('submit' in action) return { receipt:await client.submit(prepared(action.submit)) };
  if ('observe' in action) return { observation:await client.observe(prepared(action.observe.prepared),action.observe.input) };
  if ('rejection' in action) return { rejection:(await client.rejection(prepared(action.rejection.prepared),action.rejection.input)) ?? null };
  if ('status' in action) {
    const v = await client.status(ref(action.status));
    return { status:v === undefined ? null : { reference:hex(v.reference.data),principal:v.principal,table:v.table,
      declaration:hex(v.declaration),policy_revision:v.policyRevision.toString(),phase:v.phase,affected_rows:v.affectedRows,
      reason:v.reason,input:v.input } };
  }
  throw new Error('Unsupported mutation test action');
}
try {
  console.log(JSON.stringify({ ready:true }));
  for await (const line of createInterface({ input:process.stdin })) {
    const action = JSON.parse(line);
    if ('close' in action) break;
    try { console.log(JSON.stringify({ status:0,value:await call(action) })); }
    catch (error) {
      if (!(error instanceof TransitError)) throw error;
      if (error instanceof m.Uncertain) assert.equal(error.prepared.data,action.submit);
      console.log(JSON.stringify({ status:error.status,value:{ err:error.code } }));
    }
  }
} finally { await client.close(); }
console.log(JSON.stringify({ closed:true }));
