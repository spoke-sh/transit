# DROP TABLE

DROP TABLE removes a live catalog name and retires its original Table object and
head. It requires current inspect and drop rights, independently of read or
mutation permissions.

```sql
DROP TABLE people;
DROP TABLE IF EXISTS people RESTRICT;
```

The optional RESTRICT keyword is accepted, but the direct runtime does not yet
consult a shared query/resource dependency registry. Named computations, writers
and watches do not automatically block Table retirement. Inspect the application's
consumers before applying DROP. Namespace DROP separately rejects live Tables and
pending Table declarations. CASCADE is unsupported.

IF EXISTS prepared against absence records that absence; it cannot later delete
a Table created under the same name. The shared direct runtime records an
unchanged catalog assertion if the name is still absent at acceptance; a newly
created name rejects the frozen condition. This carries no Table mutation or
resulting definition revision. A dropped name may be reused with a new
object identity. Exact retry and saved-status inspection stay attached to the
original object, including after name reuse.

The live name, retired head/object and operation outcome publish through one
owning decision. Pending conflicting DDL/DML prevents a competing publication.
New queries and writes cannot use the retired object. Already captured readers
can finish against their original schema and cut while current authorization
and their own lifetimes allow it. Historical definitions and recovery evidence
remain distinct from a live name.

DROP does not physically erase data or grant access to history. The direct
service exposes no Table garbage collector. Accepted history, operation receipts
and retained cuts remain distinct from logical retirement; callers explicitly
release their read leases. After an uncertain send, the console checks the
original request; do not repeat DROP against a reused name when its outcome
remains unconfirmed.

See [Tables](../tables.md) and the
[direct lifecycle contract](../../../../contracts/DIRECT_TABLE_V1.md#declaration-and-row-operations).
