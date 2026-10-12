import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { Credential, ProcessRef, ResourceRef, TransitError } from '@transit/client';
import { catalog, relational as r } from '@transit/station';

assert.ok(import.meta.resolve('@transit/station').startsWith(new URL('./node_modules/', import.meta.url).href));
const config = JSON.parse(await readFile(process.argv[2], 'utf8'));
const catalogs = config.catalogs.map(c => new catalog.Connection(new ProcessRef(c.scope.realm, c.owner), new catalog.Scope(new ResourceRef(c.scope.realm, c.scope.resource), BigInt(c.scope.catalog))));
const credential = new Credential(config.catalogs[0].scope.realm, config.catalogs[0].principal, config.seed_file);
const options = {consistency:'per_resource_snapshot_vector', residentBytes:16777216n, spillBytes:16777216n, resultBytes:8388608n, outputRows:1000n, workSteps:100000n, sourcePins:2, requests:100000n, spillWork:100000n, spillDirectory:config.spill_directory};
const connect = () => r.Client.open({url:config.url, profile:'native_v1'}, credential, catalogs, options);
let client = await connect();
const write = value => console.log(JSON.stringify(value, (_, v) => typeof v === 'bigint' ? v.toString() : v));
try {
  write({ready:true});
  for await (const line of createInterface({input:process.stdin})) {
    const a = JSON.parse(line);
    if ('close' in a) break;
    try {
      let value;
      if ('explain' in a) value = await client.explain(a.explain);
      else if ('open' in a) {
        const result = await client.openQuery(a.open.id, a.open.statement);
        value = {...result, reference:result.reference.save()};
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
