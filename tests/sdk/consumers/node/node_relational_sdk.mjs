import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { Credential, ResourceRef, TransitError } from '@transit/client';
import { catalog, relational as r } from '@transit/station';

assert.ok(import.meta.resolve('@transit/station').startsWith(new URL('./node_modules/', import.meta.url).href));
const config = JSON.parse(await readFile(process.argv[2], 'utf8'));
const catalogs = config.catalogs.map(c => new catalog.Connection(new catalog.Scope(new ResourceRef(c.scope.realm, c.scope.resource), BigInt(c.scope.catalog)), c.audience, BigInt(c.branch), c.role ?? undefined));
const credential = new Credential(config.catalogs[0].scope.realm, config.catalogs[0].principal, config.seed_file);
const options = {consistency:'independent_table_snapshots', residentBytes:16777216n, spillBytes:16777216n, resultBytes:8388608n, outputRows:1000n, workSteps:100000n, sourcePins:2, requests:100000n, spillWork:100000n, spillDirectory:config.spill_directory};
const connect = () => r.Client.open({url:config.url, profile:'native_v1', serviceUrl:config.service_url}, credential, catalogs, options);
let client = await connect();
const description = value => ({...value, join:value.join ?? null, sources:value.sources.map(s => ({alias:s.alias, binding:JSON.parse(s.basis.save()), position:{partition:s.position.partition, next_lsn:s.position.nextLsn}}))});
const cuts = values => values.map(c => ({objectId:c.object.objectId, position:c.position, commitment:c.commitment, schema:c.schema}));
const write = value => console.log(JSON.stringify(value, (_, v) => typeof v === 'bigint' ? v.toString() : v));
try {
  write({ready:true});
  for await (const line of createInterface({input:process.stdin})) {
    const a = JSON.parse(line);
    if ('close' in a) break;
    try {
      let value;
      if ('explain' in a) value = description(await client.explain(a.explain));
      else if ('open' in a) {
        const result = await client.openQuery(a.open.id, a.open.statement, a.open.sources.map(source => ({basis:catalog.Basis.restore(source.basis), snapshot:catalog.Snapshot.restore(source.snapshot)})));
        value = {...result, reference:result.reference.save(), description:description(result.description), cuts:cuts(result.cuts)};
        assert(Object.isFrozen(result) && Object.isFrozen(result.cuts));
      } else if ('page' in a) {
        const result = await client.page(r.Reference.restore(a.page.reference), BigInt(a.page.ordinal));
        value = {...result, reference:result.reference.save(), row:result.row ?? null};
        if (result.row) assert(Object.isFrozen(result.row.cells));
      } else if ('close_query' in a) {
        await client.closeQuery(r.Reference.restore(a.close_query)); value = {};
      } else if ('reconnect' in a) {
        await client.close(); client = await connect(); value = {};
      } else throw new Error('Unknown proof operation');
      write({status:0,value});
    } catch (error) {
      if (!(error instanceof TransitError)) throw error;
      assert(!error.diagnosticInvalid);
      write({status:error.status ?? 1,value:{err:error.code,diagnostic:error.diagnostic}});
    }
  }
} finally { await client.close(); }
write({closed:true});
