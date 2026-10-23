# Direct Table request contract v1

`DirectTableProtocol` defines signed Table declaration, row mutation, operation
inspection and retained-read requests. The node's internal `LocalTableService`
dispatches these requests through `DirectCatalog`, the Table storage owner and
native authorization. Installed HTTP and SQL integration remains unfinished;
this contract does not add a runnable route by itself. The
[generated schema](direct-table-v1.schema.json) reflects the owning Zig types.

## Requests and authority

A request contains the mandatory current shared definition, connection, nonce,
action and original-caller authorization proof. The connection binds the existing
realm/resource/catalog, branch one, audience, principal and optional selected
role. Changing any request field changes its context digest. The request domain
is `transit.table.direct.request.v1` followed by a zero byte and canonical JSON
of `Request.Input` in declared field order. Fixed byte arrays remain JSON arrays;
unsigned identifiers preserve their full range. Consumers must use exact integer
parsing. The proof signs that context through the existing authorization claim
contract; it creates no new permission authority.

The node authenticates the original caller against its current native credential,
role graph and backing-resource lifetime. Catalog operations check the registered
database/schema/Table bindings and their current privileges. A response binds the
request context and checked policy revision. The node checks all successfully
used requirements again after buffering the complete response. Denial at this
boundary suppresses the response, even if a mutation has already committed.
Recover that mutation through its original operation binding.

`DirectTableClient` checks response context and kind, exact operation bindings,
terminal phase consistency, resulting definition revisions, matched/changed
counts, schema fingerprints, listing order and page limits. It owns decoded
responses independently of transport buffers. It performs one exchange per call;
timeouts do not trigger implicit mutation retries. A page consumer still needs
the retained source's schema, exact metadata and complete-consumption checks.

## Declaration and row operations

`initialize` initializes the configured catalog under its native owner;
`describe`, `list` and `lookup` inspect current authorized definitions. Listing
is an independent directory/Table observation, with at most eight entries per
page. Empty filtered pages may still have a continuation. An `after` value is
the last visited object ID, not a retained snapshot or offset into returned rows.

`admit_ddl` freezes namespace, name, exact binding and CREATE/ALTER/RENAME/DROP
intent. CREATE carries the selected owner and binary FTS1 schema; ALTER uses
shared column IDs, types, codecs and collations. Optional defaults carry typed
FVL1 cells, preserving binary bytes and finite floating-point bit patterns.
The native intent digest and all actual schema/value constraints are checked
before catalog admission. Admission publishes no Table.

`admit_rows` freezes a complete batch of insert rows, replacements identified by
their original storage keys, or deletion keys. FTR1 rows include their stable
row identities. The request includes its exact immutable interpretation and FTS1
schema. It admits at most 1024 changes within the storage owner's 4 MiB framed
work bound. Decoding additionally bounds cumulative row/key payloads to 4 MiB;
that preliminary bound does not promise the complete framed work will fit.
INSERT, UPDATE and DELETE admit only their matching change shapes.

The row intent digest uses `transit.table.direct.rows.v1`, a zero byte and
canonical JSON of `interpretation`, `schema`, `changes`, `ingestion` in that
order. It covers the complete frozen work independently of transport nonce or
current credentials. Retrying an operation with changed work conflicts. DDL
uses the existing canonical native catalog intent digest. The storage owner
also retains and compares the complete immutable admitted payload.

`operation` carries the original binding and `inspect`, `execute` or `cancel`.
Inspection starts no work. Execution resumes only admitted frozen work; CREATE
uses the native registration ledger before Table publication. Its step limit
is 1–256 native registration attempts per call, not a total progress limit.
Unknown operations remain `not_observed`. Rejection and cancellation require
accepted terminal evidence. A lost transport or storage reply establishes
neither; late cancellation returns the original commit.

## Retained reads and binary payloads

`pin` binds the original principal and exact expected Table frontier to a
durable read root. `snapshot` returns its retained interpretation, schema,
accepted frontier, logical-change frontier and row count. `scan` returns up to
eight owned rows under an explicit encoded-byte budget, with a cursor bound to
that retained root. It never substitutes the latest name or definition.
`release` records terminal pin release through reserved control capacity.
Current CONNECT/USAGE/SELECT rights apply to every operation, including release.

Pages are transport batches over one source. Their row counts, source identity
and continuation do not by themselves certify a completed query result or a
consistent cut across Tables. A caller must retain the exact source and consume
its pages without silently reopening at a newer frontier.

Binary fields contain canonical padded RFC 4648 base64. Invalid alphabet,
padding or nonzero unused pad bits reject. Schemas and rows retain their Fuze
binary codecs; transport does not reinterpret them as JSON numbers or text.
The request limit is 8 MiB and the buffered response limit is 16 MiB. Direct
requests limit a page to eight rows and at most 8 MiB of encoded row bytes,
within the storage owner's separate 16 MiB bound. Individual binary fields
remain within 4 MiB. These bound one
request's work; durable Table/catalog cardinality has no corresponding limit.

`just contract::direct-table-check` verifies reflected envelopes and independent
Python signing vectors. The catalog package tests consume those same vectors;
the [proof ledger](../tests/README.md) distinguishes codec and node composition
checks from installed service qualification.
