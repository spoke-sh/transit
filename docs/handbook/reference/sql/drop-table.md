# DROP TABLE

DROP TABLE removes a live catalog name and retires its original Table object and
head. It requires current inspect and drop rights, independently of read or
mutation permissions.

```sql
DROP TABLE people;
DROP TABLE IF EXISTS people RESTRICT;
```

RESTRICT is the default. Registered query-source, writer, watch and maintained
relation dependencies can block removal; the rejection identifies an authorized
blocker. Dependency records are installed explicitly through the owning public
control. The registry does not automatically discover external application
references. CASCADE is unsupported.

IF EXISTS prepared against absence records that absence; it cannot later delete
a Table created under the same name. A dropped name may be reused with a new
object identity. Exact retry and saved-status inspection stay attached to the
original object, including after name reuse.

The live name, retired head/object and operation outcome publish through one
owning decision. Pending conflicting DDL/DML prevents a competing publication.
New queries and writes cannot use the retired object. Already captured readers
can finish against their original schema and cut while current authorization
and their own lifetimes allow it. Historical definitions and recovery evidence
remain distinct from a live name.

DROP does not physically erase data or grant access to history. Accepted history
retains its separate retention policy. Qualified cleanup of rejected/cancelled
candidate storage preserves receipts and identity floors. After an uncertain
send, the console checks the original request; do not repeat DROP against a
reused name when its outcome remains unconfirmed.

See [Tables](../tables.md) and the
[catalog lifecycle and dependency rules](../../../../packages/zig/transit-catalog/docs/table-metadata.md).
