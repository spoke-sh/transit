# Catalog callers

`station_catalog_create/call/destroy` expose the shared direct catalog caller
through an owned native handle. The Station port selects `catalog_client` and
accepts `catalog` actions. Both execute
[`DirectTableBridge.Session`](../../transit-catalog/src/DirectTableBridge.zig)
using the generated `CatalogConfig`, `CatalogAction` and `CatalogResult`
contracts. SQL and typed declarations lower to the same immutable work and public
direct operations. A caller handle does not provision a catalog or grant rights.

Creation takes ABI version one, an explicit authority URL, a 32-byte signing seed
and JSON configuration with mandatory `definition` and `connection` fields.
The connection contains `scope` (native realm/resource counters and a decimal
catalog ID), decimal `branch`, native `audience` and `principal`, and nullable
selected `role`. The service validates the supported branch and native authority
bindings. There is no actor PID in this connection.

Optional `service_url` selects the direct service endpoint; its default is the
explicit authority URL. The shared client uses `/table/v1` for direct requests
and the authority endpoint for current credentials and authorization evidence.
`timeout_ms` defaults to 5000 and accepts 1–60000. Endpoints are at most 2048 bytes
and exclude user information, query strings and fragments. Configuration is at
most 8192 bytes. Creation performs no I/O, activation, initialization or grants.
An omitted service URL never selects an actor transport.

Native counters remain safe integers. Catalog, branch, object, operation,
interpretation, position and row-count fields use canonical decimal strings for
their full widths. Missing or foreign definitions, old actor configurations,
unknown fields and incorrectly encoded numbers are rejected. No persisted
compatibility field defaults to the current definition.

## Saved work and explicit recovery

The handle owns one immutable local Table intent or conditional name assertion.
SQL `compile` and typed `prepare` return a local summary and an independently
owned `saved` value. They may read current authorized definitions; neither stages
nor admits work. A typed basis retains the entire original connection, namespace,
name and exact stored interpretation. A later lookup or reused name cannot redirect
that binding to a replacement Table.

Persist the saved value before `stage`. `load` restores it without I/O and
replaces local work only after successful validation and allocation. `preview`
checks current state and rights without staging, claims or admission. `stage`
publishes a Table intent's content and returns its complete recovery reference;
a conditional name assertion already contains its complete recovery binding.
Persist that reference before `admit`. Staging does not imply acceptance.

`admit` requests durable admission. `operation.inspect`, `operation.execute` and
`operation.cancel` address the original complete recovery reference. They never
recompile SQL or look up a replacement by name. Execution takes an explicit step
budget; the caller chooses whether to make another call after inspecting progress.
Conditional name assertions use admission, inspection and cancellation; they do
not have a separate execute action. Their outcomes retain a catalog position
without inventing a Table commit.

`forget` only releases local work. Destroying a handle, closing a port or stopping
a wait does not cancel or expire accepted work. Original recovery references
remain usable under current rights after local forgetting, caller replacement,
Table retirement and name reuse. Keep saved work and recovery references outside
the handle's lifetime. An uncertain staging result can be recovered by loading
and staging the original saved work; it does not authorize fresh compilation.

## Inspection and related declarations

`catalog` actions expose local capabilities, current configuration and subject,
individual namespaces, and bounded namespace/Table pages. Page cursors retain
the original connection, selection and catalog position. A changed directory
rejects continuation; a returned prefix is not complete coverage. Table pages
report independent observations rather than a cross-Table transaction snapshot.
`lookup` returns the complete prepared binding, logical schema and authorized
current metadata. It is not a general row reader or arbitrary historical-definition
lookup.

`retention.acquire` takes a separately saved exact snapshot acquisition. Persist
its owner, connection, stable object and expected position before sending it.
`retention.status` resolves that original owner after an uncertain reply or caller
replacement. Its current Table interpretation and position are distinct from
the retained snapshot's basis. `retention.metadata` reads the snapshot's accepted
position, original schema and interpretation under current rights, including
after DROP and name reuse. `retention.release` addresses the exact owner and
content; an uncertain release preserves that reference for status inspection or
exact retry. Local handle disposal never releases these durable pins, and release
does not claim physical reclamation.

`administration` actions prepare namespace operations and native policy changes.
Namespace publication uses explicit saved bindings and admission/execution/
inspection/cancellation. Policy preparation returns the native authorization
owner's signed record without submitting it; selecting a role remains explicit.
`dependencies` and `resources` use their original saved bindings for graph and
named KV/Document lifecycle operations. Graph membership remains distinct from
old operation receipts. Resource execution preserves recorded allocation and
initialization progress; it does not create a second resource authority.

## Ownership, diagnostics and transport bounds

The [shared ownership rules](bindings.md) require an 8 MiB calling-thread stack,
one active call per handle, `busy` on overlap and joined destruction. Each result
buffer outlives the handle and requires one `station_buffer_destroy`. Destruction
wipes the caller's signing key and releases both transports.

Errors retain the native cause, available authority rejection and an owned
structured diagnostic. SQL compile failures retain source locations. Failures
before a direct mutation attempt report `not_submitted`; failed reads report
`not_applicable`. After any mutation attempt, an unconfirmed result reports ABI
`uncertain` and diagnostic `unknown`, including a denial, conflict, malformed
response or result allocation failure. An authority rejection may follow earlier
acceptance within the same operation. Preserve the original work and inspect its
owner; a transport error is not a terminal catalog outcome.

Before mutation dispatch, denied requests return `denied`, conflicts return
`conflict`, missing local work returns `not_ready`, and transport failures return
`unavailable`. Local malformed input returns `invalid_argument`. A failure to
allocate an error buffer can leave the returned buffer empty; the status still
preserves possible dispatch.

The port accepts `url`, private `seed_file` and `catalog_client` with the same
configuration. Its catalog profile is exclusive with query, server and
local-codec profiles. Other profiles return `not_ready` for catalog calls.
Generated `catalog_intent_bytes`, `catalog_action_bytes` and `catalog_line_bytes`
limits govern saved work, action JSON and complete port lines respectively.
The host starts with a 16 KiB input buffer and grows only for the current bounded
line. Oversized or truncated lines fail before dispatch. Independent logical-cell,
row, batch, schema, JSON depth, token and field limits still apply. Bulk direct
requests can exceed an actor frame without changing native turn limits.

`shutdown` joins and destroys the catalog owner before acknowledging closure.
The native port retains machine-readable stdout; diagnostics do not disclose
signing seeds or application payloads.

The native catalog handle delegates transport, local intent ownership and attempt
evidence to [the shared data client](../../transit-data-client/README.md). The ABI
retains its current declarations, owned buffers and host scheduling rules; the
package extraction changes neither saved work nor wire definitions.
