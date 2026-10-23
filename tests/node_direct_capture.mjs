import assert from 'node:assert/strict';
import {readFile, writeFile, chmod} from 'node:fs/promises';
import {dirname, join} from 'node:path';
import {Credential, ProcessRef, ResourceRef} from '@transit/client';
import {unified as q, catalog} from '@transit/station';

const [endpoint, profilePath, phase] = process.argv.slice(2);
const profile = JSON.parse(await readFile(profilePath, 'utf8')).captured;
const route = profile.connection, realm = route.realm;
const declaration = profile.declaration.source.table;
const resource = new ResourceRef(realm, declaration.scope.resource);
const scope = new catalog.Scope(resource, BigInt(declaration.scope.catalog));
const connection = new q.Connection(new ProcessRef(realm, route.source), new ResourceRef(realm, route.resource),
  new ProcessRef(realm, route.requester), new ResourceRef(realm, route.requests));
assert.notEqual(resource.resource, connection.resource.resource);
const seed = join(dirname(profilePath), 'node-capture.seed');
await writeFile(seed, (phase === 'prepare' ? '1d' : '3b').repeat(32)); await chmod(seed, 0o600);
const tables = new q.Tables(endpoint, scope, BigInt(declaration.branch), declaration.owner);
const bundle = new q.Bundle(Buffer.from(profile.bundle.base64, 'base64'));
const client = await q.Client.open({url: endpoint, profile: 'native_v1', timeoutMs: 10000},
  new Credential(realm, route.principal, seed), connection, tables);
try {
  if (phase === 'prepare') {
    assert.equal(await client.lookupTable('missing_capture_input'), undefined);
    const definition = await client.lookupTable('captured_input'); assert.ok(definition);
    assert.equal(definition.partition, BigInt(profile.capture.expected.partition));
    assert.equal(definition.nextLsn, BigInt(profile.capture.expected.next_lsn));
    const compiled = await client.compileSql(definition.source, 'captured_input', 'SELECT COUNT(*) AS n FROM captured_input',
      {pages: 64n, segments: 64n, resultBytes: 1048576n});
    const sealed = await client.authorizeBundle(compiled, definition.capture(profile.capture.executor, BigInt(profile.capture.operation)));
    assert.ok(sealed.data.length > 0); assert.deepEqual(sealed.data, bundle.data);
  } else {
    assert.equal(await client.lookupTable('captured_input'), undefined);
    const definition = await client.lookupTable('captured_renamed'); assert.ok(definition);
    assert.equal(definition.source.interpretation.revision, 2n); assert.equal(definition.source.schema.revision, 1n);
    const page = await client.page(1n); assert.equal(page.next, undefined); assert.equal(page.rows, 1);
    assert.deepEqual(page.manifest.resource, resource); assert.deepEqual(page.manifest.source, connection.source);
    assert.equal(page.manifest.cut.kind, 'table'); assert.equal(page.manifest.pages, 3n); assert.equal(page.manifest.scanned, 19n);
    const rows = await page.decode(); assert.equal(rows.length, 1); assert.equal(rows[0].length, 1);
    assert.equal(rows[0][0].state, 'value'); assert.equal(rows[0][0].value.atom.kind, 'unsigned'); assert.equal(rows[0][0].value.atom.value, 19n);
    assert.ok(await client.prepareCleanup(1n, bundle) instanceof q.Prepared);
  }
} finally { await client.close(); }
console.log(`TypeScript installed direct capture ${phase}: public API passed`);
