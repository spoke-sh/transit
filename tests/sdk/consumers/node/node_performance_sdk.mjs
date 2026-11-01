// Installed public Catalog/Query consumer. Expected rows belong to the driver.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, open, rename } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { createInterface } from 'node:readline';

const beganImport = process.hrtime.bigint();
const { Credential, ResourceRef } = await import('@transit/client');
const { catalog: m, relational: r } = await import('@transit/station');
const importNs = Number(process.hrtime.bigint() - beganImport);
assert.ok(import.meta.resolve('@transit/station').startsWith(new URL('./node_modules/', import.meta.url).href));
const config = JSON.parse(await readFile(process.argv[2], 'utf8'));
const c = config.connection;
const connection = new m.Connection(new m.Scope(new ResourceRef(c.scope.realm, c.scope.resource), BigInt(c.scope.catalog)), c.audience, BigInt(c.branch), c.role ?? undefined);
const credential = new Credential(c.scope.realm, c.principal, config.seed_file);
const configuration = { url: config.url, profile: 'native_v1', timeoutMs: 10000, serviceUrl: config.service_url };
const root = dirname(process.argv[2]);
async function persist(name, data) {
  const path = join(root, name);
  const file = await open(path + '.tmp', 'w', 0o600);
  try { await file.writeFile(data); await file.sync(); } finally { await file.close(); }
  await rename(path + '.tmp', path);
  const directory = await open(root, 'r');
  try { await directory.sync(); } finally { await directory.close(); }
}
const opening = process.hrtime.bigint();
const client = await m.Client.open(configuration, credential, connection);
let query;
try {
  query = await r.Client.open(configuration, credential, [connection], {
    consistency: 'independent_table_snapshots', residentBytes: 16777216n, spillBytes: 16777216n,
    resultBytes: 8388608n, outputRows: 1000n, workSteps: 100000n, sourcePins: 2,
    requests: 100000n, spillWork: 100000n, spillDirectory: root,
  });
  const openNs = Number(process.hrtime.bigint() - opening);
  console.log(JSON.stringify({ ready: true }));
  for await (const line of createInterface({ input: process.stdin })) {
    const request = JSON.parse(line);
    if ('close' in request) break;
    const started = process.hrtime.bigint(), cpu = process.cpuUsage();
    const result = {};
    switch (request.operation) {
      case 'info':
        Object.assign(result, { import_ns: importNs, open_ns: openNs, runtime: process.version });
        break;
      case 'lookup': {
        const value = await client.lookup(request.name);
        Object.assign(result, { rows: value ? Number(value.rowCount) : null,
          columns: value ? value.schema.columns.length : null, complete: true });
        break;
      }
      case 'query': {
        const current = await client.lookup(request.name);
        const acquisition = client.prepareSnapshot(current, BigInt(request.id));
        await persist('pending.json', acquisition.save());
        const snapshot = await client.acquireSnapshot(acquisition);
        await persist('snapshot.json', snapshot.save());
        let opened;
        try {
          opened = await query.openQuery(BigInt(request.id).toString(16).padStart(32, '0'),
            { namespace: 1, sql: request.sql, routes: [0] }, [{ basis: current.basis, snapshot }]);
          const values = [];
          let rows = 0, first = null, complete = false;
          while (rows <= 1000) {
            const page = await query.page(opened.reference, BigInt(rows));
            if (page.row !== undefined) {
              if (first === null) first = Number(process.hrtime.bigint() - started);
              assert.equal(page.row.cells.length, 2);
              assert.ok(page.row.cells.every(value => typeof value === 'bigint'));
              assert.ok(rows < 1000, 'Result row budget exhausted');
              values.push(page.row.cells);
              rows++;
            }
            if (page.completeCoverage) { complete = true; break; }
            assert.ok(page.row !== undefined);
          }
          assert.ok(complete, 'Result row budget exhausted');
          values.sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0);
          const digest = createHash('sha256'), bytes = Buffer.alloc(16);
          for (const value of values) {
            bytes.writeBigInt64LE(value[0], 0); bytes.writeBigInt64LE(value[1], 8);
            digest.update(bytes);
          }
          Object.assign(result, { rows, digest: digest.digest('hex'), complete, first_row_ns: first });
        } finally {
          try { if (opened) await query.closeQuery(opened.reference); }
          finally { await client.releaseSnapshot(snapshot); }
        }
        break;
      }
      case 'write': {
        const work = await client.compileSql(request.sql, new m.Identity(BigInt(request.id)));
        await persist('pending.json', work.saved.save());
        const original = await client.stage(work.intent);
        await persist('original.json', original.save());
        let observed = await client.admit(original);
        for (let i = 0; i < 128 && observed.state === 'admitted'; i++) observed = await client.execute(original, 32);
        assert.equal(observed.state, 'committed');
        Object.assign(result, { changed: Number(observed.commit.affected), matched: Number(observed.commit.matched), complete: true });
        break;
      }
      default: throw new Error('Unsupported benchmark operation');
    }
    const used = process.cpuUsage(cpu);
    Object.assign(result, { elapsed_ns: Number(process.hrtime.bigint() - started),
      cpu_ns: (used.user + used.system) * 1000, peak_rss_bytes: process.resourceUsage().maxRSS * 1024 });
    console.log(JSON.stringify({ status: 0, value: result }));
  }
} finally {
  try { if (query) await query.close(); }
  finally { await client.close(); }
}
console.log(JSON.stringify({ closed: true }));
