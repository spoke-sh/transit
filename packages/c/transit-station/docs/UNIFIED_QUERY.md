# Unified state queries

Include `transit/unified_query.h` for the explicit v1 KV/Table/accepted-Document
profile. This is separate from the original Table query API in `station.h`.
[The shared contract](../../../../contracts/UNIFIED_QUERY_V1.md) defines source
identity, decoder versions, projection budgets, five cell states and availability.

Build a `transit_station_unified_source`, typed plan and positive work budgets,
then call `transit_station_unified_prepare_bundle`. KV declares both decoders;
Table binds its ID/schema; Document binds an accepted reference and bounded
path/list/text projections. Six scalar types preserve full-width signed/unsigned
integers, finite double bits, bool, UTF-8 and arbitrary bytes. Input pointers borrow
only through the synchronous call. Zig owns encoding and semantic validation.

`transit_station_unified_open` takes a growing client config, explicit credential
and source/resource/requester/request-resource connection. It owns a bounded
native worker and copied credential; it acquires no process activation.
`describe` checks current policy and the declared source. The maximum bundle is
16 KiB, an Arrow segment is at most 64 KiB and a batch has at most eight rows and
eight columns. Local capability support does not establish remote permission.

`transit_station_unified_inspect_sql(client, source, name, sql, budgets, out)`
executes scoped `DESCRIBE name`, `SHOW TABLES` or `EXPLAIN SELECT ...` through the
shared Zig owner. The output struct owns all names, digests, revisions and tagged
description/list/explanation details inline; copying it retains no client pointer
and needs no destroy call. The response contains at most eight columns and four
operators. The Table listing has zero or one names for the configured source.
Explanation exposes predicate structure without literal values and preserves
full-width limits and budgets. Inspection rechecks current authorization before
returning, creates no snapshot and admits no query. Failure clears the output.

For a positive namespace, call `prepare_next`, copy and persist the returned
prepared bytes, then `submit`. Keep the prepared owner until a definite outcome.
`TRANSIT_SDK_UNKNOWN_OUTCOME` requires resubmitting the identical persisted bytes;
never replace them with another freshly prepared command. `observe` checks the
admitted input's behavior disposition. A receipt is admission, and a null next
command means inspect status. Neither means the result is complete.

Read pages only after a complete status. Every page checks current grants,
source lifecycle, manifest/segment digests and ordered coverage. `page_next`
returns an owned opaque cursor; null means verified complete coverage. A saved
cursor does not grant access. Cancellation, retirement and collection are explicit
prepared controls with the same persistence/submission rules. Closing a client
does not record cancellation or remove accepted work.

Destroy every bundle, prepared command, cursor, page, decoded rows and client with
its matching function. `page_get` borrows IPC/schema-name pointers from its page;
`rows_cell` and `rows_alternative` borrow scalar byte pointers from decoded rows.
Pages survive client destruction, and decoded rows survive page destruction.
Standalone `decode_arrow` validates shape and preserves conflict alternatives;
it establishes neither current access nor complete-result provenance.

Operations block on the bounded worker. One operation may be in flight; overlapping
work returns BUSY. Close joins owned work; join caller threads before moving or
destroying public handles. No destructor dispatches a durable control.

`just bindings::unified-c` installs independent archives and exercises C11 and
C++17 consumers against signed KV recovery. An optional source argument chooses
`table` or `document`. The [proof guide](../../../../tests/README.md) records
measured runs and remaining qualification separately.
