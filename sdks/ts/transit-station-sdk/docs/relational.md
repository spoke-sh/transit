# Interactive relational queries

`relational.Client` evaluates the selected Table join and grouped aggregate
profile through the shared Zig query owner. Configure one direct `catalog.Connection` in the caller's realm; a second configured route
must contain the same connection. `config.serviceUrl` optionally selects a direct
service endpoint separately from the native authority. A statement supplies one
route index per `FROM`/`JOIN` target; names never select another catalog implicitly.
The [relational caller contract](../../../../packages/zig/transit-query/docs/relational-callers.md)
defines SQL, ordering, budgets and current authorization.

```typescript
import { relational } from "@transit/station";

const client = await relational.Client.open(config, credential, catalogs, {
  consistency: "independent_table_snapshots",
  residentBytes: 16777216n,
  spillBytes: 16777216n,
  resultBytes: 8388608n,
  outputRows: 1000n,
  workSteps: 100000n,
  requests: 100000n,
  spillWork: 100000n,
  sourcePins: 2,
  spillDirectory: privateSpillDirectory,
});
const statement = {
  sql: "SELECT l.k, COUNT(*) AS rows FROM left_table l LEFT JOIN right_table r ON l.k = r.k GROUP BY l.k",
  routes: [0, 0],
};
try {
  const proposed = await client.explain(statement); // metadata only
  // catalogClient uses the same connection and credential. Persist each
  // acquisition before dispatch and keep it if its outcome is unknown.
  const sources = [];
  for (const source of proposed.sources) {
    const acquisition = catalogClient.prepareSnapshot(source, nextOperation());
    persistAcquisition(acquisition.save());
    const snapshot = await catalogClient.acquireSnapshot(acquisition);
    persistSnapshot(snapshot.save());
    sources.push({ basis: source.basis, snapshot });
  }
  const id = relational.freshId(); // retain with statement and sources
  const opened = await client.openQuery(id, statement, sources);
  try {
    for (let ordinal = 0n; ; ordinal++) {
      const page = await client.page(opened.reference, ordinal);
      if (page.completeCoverage) break;
      consume(page.row!); // a prefix until completeCoverage is observed
    }
  } finally {
    await client.closeQuery(opened.reference);
    // Save the closure decision before release. Resolve uncertain releases
    // through snapshotStatus with the original owner.
    for (const source of sources) {
      persistClosure(source.snapshot.save());
      await catalogClient.releaseSnapshot(source.snapshot);
    }
  }
} finally {
  await client.close();
}
```

`explain` returns the prepared plan digest, typed columns and exact source
bindings and observed positions without retaining data. `openQuery` receives
explicit saved bindings and snapshots, returning an immutable query reference
and exact Table cuts. Repeated aliases of one Table must share one pin; preserve
that sharing when preparing sources. Separate Tables form independent cuts, even
inside the same catalog. A saved binding remains the source after DROP/name reuse.

One client owns one active query. Retry an uncertain open using the same ID,
statement, bindings and snapshots. Retry a page using its exact reference and ordinal. The current page
is repeatable; advance by exactly one ordinal after a row. Older pages and
skipped ordinals are rejected. Only a terminal page with no row establishes
complete coverage. A failure preserves the incomplete prefix and the original
diagnostic; it does not produce an empty successful result.

Rows own immutable `bigint | null` cells and pair or group identities. Pair
identities own their Table row bytes; group keys are nullable signed 64-bit
integers. Counts retain the full unsigned 64-bit range. Budgets and ordinals are
`bigint`, including Table partition positions; route indices and native realm/resource
identities are checked numbers.

Every page, including a repeated or terminal page, rechecks current access to
all sources. Source access can be revoked after a prefix. Closing the query
disposes local execution and spill even when source access is denied. Durable
pins require separate explicit catalog release. Closing the client joins its
native host and does not release retained snapshots. There is no automatic retry or background
query scheduling.

`Reference.save()` and `Reference.restore()` preserve the mandatory contract
definition, query ID, plan and basis. The reference belongs to its live host;
host replacement rejects it instead of rerunning the statement. Interactive
references are not durable captured jobs or maintained result revisions. This
SDK surface exposes interactive queries only; the typed Zig owner separately
provides captured and maintained lifetimes.
