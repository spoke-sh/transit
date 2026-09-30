# Unified state queries

`Transit::Station::Unified` provides typed v1 KV/Table/accepted Document sources,
plans, finite budgets and owned nested Arrow results. It composes shared Zig
through one joined native worker; Ruby contains no query execution or protocol
implementation. Import starts no process or credential access.

Use `KVSource` with explicit versioned `Decoder` values, `TableSource` with its
exact table/schema, or `DocumentSource` with an accepted `DocumentReference` and
bounded `Projection` values. `Bundle.prepare(source, plan, budgets)` validates
and creates canonical bytes without admitting work. All wide values use Ruby
`Integer`; binary strings and returned bytes are copied and frozen.

`Client.open(config, credential, connection) { |client| ... }` owns one query
port. The explicit `Connection` binds source/requester PIDs and resources in one
realm. It needs no activation or writer ownership. `describe(source)` checks
current availability and policy. Native requests and results are checked against
the generated schema, including the complete tagged variants.

`inspect_sql(source, name, sql, budgets)` executes scoped `DESCRIBE name`,
`SHOW TABLES` or `EXPLAIN SELECT ...` through the same Zig inspection owner as
the console. The immutable `Inspection` carries source/schema digests, current
resource/policy revisions and `SourceDescription`, `TableListing` or
`Explanation` details. Explanation includes ordered operator symbols, a typed
predicate without literal values, projection/output columns and explicit budgets.
Wide values remain `Integer`; returned strings, digests and arrays are frozen.
The operation checks current authorization before and after resolution, creates
no snapshot and admits no query. The listing covers only the configured source.

For each command, call `prepare_next(namespace, bundle)`, persist the returned
`Prepared.data`, and then `submit(prepared)`. The returned input position proves
admission only; wait for `observe(position).state == :committed` before preparing
again. A nil prepared command does not establish query completion. Read
`status(namespace)` for admitted and terminal phases. A rejected observation
retains the durable behavior rejection separately from admission failure.

`Uncertain` carries the unchanged `prepared` value after unconfirmed dispatch.
Resubmit those identical bytes, including after replacing the owner. Do not
parse/re-encode the token or generate another command to resolve that attempt.
`prepare_cancel`, `prepare_retire` and `prepare_collect` use the same persistence,
submission and observation sequence. Interrupting a Ruby wait does not cancel
accepted work; closing joins the worker before destroying the native owner.

After completion, `page(namespace, cursor)` returns an immutable page with owned
IPC, typed manifest provenance and optional next `Cursor`. Every page rechecks
current source/request grants and lifecycle. A cursor is verification progress,
not permission; save it only with the same connection and namespace. Read failure
does not advance it. Nil next establishes verified whole-result coverage.

`Page#decode` and `Unified.decode_arrow(columns, ipc, rows)` return typed cells
through shared Zig. Missing, null, type error, value and conflict remain distinct;
alternatives retain their original ordered assignment identities. Scalar bounds
are 4 KiB, batches have at most eight rows/columns, bundles at most 16 KiB and IPC
segments at most 64 KiB. No optional Ruby Arrow dependency is selected; original
owned IPC remains available to an application-selected consumer.

`nix develop .#bindings --command just bindings::unified-ruby kv` builds fresh
gems and tests shared codecs plus signed recovery. Other source selections are
`table` and `document`; consult [completed evidence](../../../../tests/README.md).
