# Interactive relational queries

`relational.Client` evaluates the selected Table join and grouped aggregate
profile through the shared Zig query owner. Configure one or two
`catalog.Connection` values in the caller's realm. A statement supplies one
route index per `FROM`/`JOIN` target; names never select another catalog implicitly.
The [relational caller contract](../../../../packages/zig/transit-query/docs/relational-callers.md)
defines SQL, ordering, budgets and current authorization.

```typescript
import { relational } from "@transit/station";

const client = await relational.Client.open(config, credential, catalogs, {
  consistency: "per_resource_snapshot_vector",
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
  routes: [0, 1],
};
try {
  const proposed = await client.explain(statement); // metadata only
  const id = relational.freshId(); // retain with the statement for open retries
  const opened = await client.openQuery(id, statement);
  try {
    for (let ordinal = 0n; ; ordinal++) {
      const page = await client.page(opened.reference, ordinal);
      if (page.completeCoverage) break;
      consume(page.row!); // a prefix until completeCoverage is observed
    }
  } finally {
    await client.closeQuery(opened.reference);
  }
} finally {
  await client.close();
}
```

`explain` returns the prepared plan digest, typed columns and exact source
identities without opening a snapshot. `openQuery` returns the same plan, an
immutable reference and explicit resource cuts. Aliases on one resource share a
cut; two resources form a snapshot vector without a global transaction claim.

One client owns one active query. Retry an uncertain open using the same ID and
statement. Retry a page using its exact reference and ordinal. The current page
is repeatable; advance by exactly one ordinal after a row. Older pages and
skipped ordinals are rejected. Only a terminal page with no row establishes
complete coverage. A failure preserves the incomplete prefix and the original
diagnostic; it does not produce an empty successful result.

Rows own immutable `bigint | null` cells and pair or group identities. Pair
identities own their Table row bytes; group keys are nullable signed 64-bit
integers. Counts retain the full unsigned 64-bit range. Budgets and ordinals are
`bigint`, while route indices and native resource positions are checked numbers.

Every page, including a repeated or terminal page, rechecks current access to
all sources. Source access can be revoked after a prefix. Closing the query
releases its own pins and spill file even when source access is denied. Closing
the client joins its native host. There is no automatic retry or background
query scheduling.

`Reference.save()` and `Reference.restore()` preserve the mandatory contract
definition, query ID, plan and basis. The reference belongs to its live host;
host replacement rejects it instead of rerunning the statement. Interactive
references are not durable captured jobs or maintained result revisions. This
SDK surface exposes interactive queries only; the typed Zig owner separately
provides captured and maintained lifetimes.
