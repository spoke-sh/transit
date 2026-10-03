import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { Credential, ProcessRef, ResourceRef, TransitError } from '@transit/client';
import { catalog as m } from '@transit/station';

const config = JSON.parse(await readFile(process.argv[2], 'utf8'));
assert.ok(import.meta.resolve('@transit/station').startsWith(new URL('./node_modules/', import.meta.url).href));
const c = config.connection;
const scope = v => new m.Scope(new ResourceRef(v.realm, v.resource), BigInt(v.catalog));
const scopeJson = v => ({ realm:v.resource.realm, resource:v.resource.resource, catalog:v.catalog.toString() });
const configuration = v => new m.Configuration(scope(v.scope), new ProcessRef(v.scope.realm, v.owner), v.administrator);
const configurationJson = v => ({ scope:scopeJson(v.scope), owner:v.owner.pid, administrator:v.administrator });
const policy = v => new m.Policy(scope(v.scope), v.principal, BigInt(v.revision), v.inspect, v.create);
const policyJson = v => ({ scope:scopeJson(v.scope), principal:v.principal, revision:v.revision.toString(), inspect:v.inspect, create:v.create });
const request = v => new m.CreateTable(scope(v.scope), BigInt(v.operation), BigInt(v.object), v.table, v.name, new m.Schema(v.schema.names, v.schema.value_type));
const requestJson = v => ({ scope:scopeJson(v.scope), operation:v.operation.toString(), object:v.objectId.toString(), table:v.table, name:v.name, schema:{ names:v.schema.names, value_type:v.schema.valueType } });
const prepared = v => new m.Prepared(v);
const hex = v => Buffer.from(v).toString('hex');
const cursor = v => v === null ? undefined : new m.Cursor(v.definition, scope(v.scope), v.resource_revision, v.after);
const cursorJson = v => v === undefined ? null : ({ definition:v.definition, scope:scopeJson(v.scope), resource_revision:v.resourceRevision, after:v.after });
const definitionJson = v => v === undefined ? null : ({ scope:scopeJson(v.scope), object:v.objectId.toString(), revision:v.revision.toString(), name:v.name,
  source:{ table:{ id:v.source.table, schema:{ names:v.source.schema.names, value_type:v.source.schema.valueType } } }, principal:v.principal, operation:v.operation.toString(), input:v.input });
const connection = new m.Connection(new ProcessRef(c.scope.realm, c.owner), scope(c.scope));
const client = await m.Client.open({ url:config.url, profile:'native_v1', timeoutMs:10000 }, new Credential(c.scope.realm, c.principal, config.seed_file), connection);
async function call(action) {
  const [name,v] = Object.entries(action)[0];
  if (name === 'capabilities') {
    const r = await client.capabilities();
    return { capabilities:{ version:r.version, definition:r.definition, initialize:r.initialize, create_table:r.createTable, conditional_policy:r.conditionalPolicy, current_metadata:r.currentMetadata, max_saved_bytes:r.maxSavedBytes, table_columns:r.tableColumns } };
  }
  if (name === 'describe') {
    const r = await client.describe();
    return { description:{ configuration:configurationJson(r.configuration), policy:policyJson(r.policy), resource_revision:r.resourceRevision } };
  }
  if (name === 'lookup') return { definition:definitionJson(await client.lookup(v)) };
  if (name === 'definition') return { definition:definitionJson(await client.definition(BigInt(v.object), BigInt(v.revision))) };
  if (name === 'list') {
    const r = await client.list(cursor(v));
    return { page:{ resource_revision:r.resourceRevision, entries:[...r.entries.map(definitionJson), ...Array(8-r.entries.length).fill(null)], next:cursorJson(r.next) } };
  }
  if (name === 'compile') {
    const r = await client.compileSql(v.sql, BigInt(v.operation), BigInt(v.object), v.table);
    const original = hex(r.canonical); r.canonical.fill(0); assert.equal(hex(r.canonical), original);
    return { compiled:{ request:requestJson(r.request), canonical:original } };
  }
  if (name === 'prepare_initialize') return { prepared:(await client.prepareInitialize(configuration(v))).data };
  if (name === 'prepare_create') return { prepared:(await client.prepareCreate(request(v))).data };
  if (name === 'prepare_policy') return { prepared:(await client.preparePolicy(new m.PolicyChange(BigInt(v.expected_revision), policy(v.policy)))).data };
  if (name === 'submit') return { receipt:{ position:(await client.submit(prepared(v))).position } };
  if (name === 'observe') return { observation:await client.observe(prepared(v.prepared), v.input) };
  if (name === 'input_disposition') {
    const r = await client.inputDisposition(prepared(v.prepared), v.input);
    return { disposition:r === undefined ? null : { scope:scopeJson(r.scope), origin:r.origin, principal:r.principal, input:r.input, payload:hex(r.payload), outcome:r.outcome } };
  }
  if (name === 'status') {
    const r = await client.status(request(v));
    return { status:r === undefined ? null : { request:requestJson(r.request), principal:r.principal, input:r.input, outcome:r.outcome } };
  }
  throw new Error('Unsupported catalog test action');
}
try {
  console.log(JSON.stringify({ ready:true }));
  for await (const line of createInterface({ input:process.stdin })) {
    const action = JSON.parse(line);
    if ('close' in action) break;
    try { console.log(JSON.stringify({ status:0, value:await call(action) })); }
    catch (error) {
      if (!(error instanceof TransitError)) throw error;
      if (error instanceof m.Uncertain) assert.equal(error.prepared.data, action.submit);
      console.log(JSON.stringify({ status:error.status, value:{ err:error.code,diagnostic:error.diagnostic ?? null,diagnostic_invalid:error.diagnosticInvalid } }));
    }
  }
} finally { await client.close(); }
console.log(JSON.stringify({ closed:true }));
