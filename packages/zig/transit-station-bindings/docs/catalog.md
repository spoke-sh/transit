# Catalog callers

`station_catalog_create/call/destroy` expose the shared general Table client
through an owned native handle. The Station port selects `catalog_client` and
accepts `catalog` actions. Both execute the same
[neutral Table session](../../transit-catalog/docs/table-metadata.md#neutral-general-table-callers)
and generated `CatalogConfig`, `CatalogAction` and `CatalogResult` contracts.
SQL and typed requests lower to the same immutable intent and owning Table
operations. No caller handle is a Table worker or grants execution rights.

Creation takes ABI version one, an explicit authority URL, a 32-byte signing seed
and JSON configuration containing `connection` and optional `timeout_ms` (default
5000, range 1–60000). The connection contains `scope` (realm/resource numbers and
a decimal-string catalog ID), owner PID and caller principal. URLs are at most
2048 bytes, configuration at most 8192 bytes and complete action JSON at most
16 MiB. Native counters remain safe integers; catalog, object, operation, schema,
column and row counts use canonical decimal strings for their full widths.

Creating a handle performs no network request, provisioning, grant change,
activation or catalog initialization. `capabilities` and loading saved intent are
local. CREATE compilation is local; other SQL compilation and typed preparation
resolve current authorized metadata. No preparation submits a command. The owning
catalog independently checks current authorization and conditional state when
applying each input. Inspect, create, read, insert, update, delete, alter and drop
rights remain independent.

## Owned calls and exact recovery

The handle uses the [shared ownership rules](bindings.md): an 8 MiB calling-thread
stack, one active call per handle, `busy` on overlap and joined destruction. It
owns one immutable Table intent and bounded transport work, and wipes its signing
key during destruction. Native result buffers outlive the handle and each require
one `station_buffer_destroy` call.

`compile` and typed `prepare` return an intent summary and exact saved bytes.
Persist the saved value before dispatch. Subsequent calls carry its small reference,
which commits to the full original intent, rather than repeating its body. `next`
returns a signed step, running state, terminal Table outcome or closed upload.
Persist every signed step before calling `submit`, then retain its admission
receipt. `load` restores the original saved intent after handle replacement without
name resolution, recompilation or dispatch. `forget` releases local memory; it
neither cancels nor discards durable accepted work. A mismatched or unloaded
reference rejects before remote access.

`submit` checks the saved step's definition, connection, complete frame and
signature before dispatch. Malformed local recovery returns `invalid_argument`.
Once valid dispatch starts, unconfirmed transport/response failures and result
allocation failure return `uncertain`. Submit failures never trigger re-signing. Reconcile
with the identical signed bytes, including after handle or port replacement.
A returned receipt establishes native admission only.

`observe`/`wait_observe` report input progress. `status` reports the original
Table outcome and upload independently. `progress`/`wait_progress` combine
observation with the exact intent and signed input. `input_disposition` describes
control application or input rejection; it is not a row-mutation result. Null
outcome or disposition is absence, not success. Applied DML exposes recorded
matched and changed counts. Current inspection rights gate retained outcomes. Reads and local preparation may
restart after the exact native `StaleStateResource` rejection, within eight
restarts and the configured deadline. Each restart releases its workspace; cursor
conflicts, denials and submits are not retried.

`prepare_resume`, `prepare_control`, `prepare_initialize`, `prepare_policy` and
`prepare_dependency` return signed commands without sending them. Operation
cancellation, upload cancellation and cleanup are distinct controls. Closed
uploads do not imply cancelled Table operations; cleanup does not erase accepted
history or receipts.

## Metadata and failures

`lookup` returns the current owned metadata, complete typed schema and live head
for an exact authorized name. `list` returns up to eight metadata/head entries
ordered by object identity at one resource revision; listing does not decode every
schema. Its dense optional slots and mandatory-definition cursor preserve scope,
resource revision and the last scanned object. A cursor may pass retired objects,
including an empty page with continuation. A changed resource revision requires
restarting the listing without combining different cuts.

`definition` takes exact object and metadata-revision decimal strings and returns
an optional `historical` value containing owned metadata and schema. It has no
live head. Applied historical definitions remain inspectable after rename, DROP
and name reuse under current grants and inspection policy. Absent revisions and
known unaccepted candidates return null; corrupt or missing original acceptance
evidence returns an error. Private metadata publication alone grants no visibility.

Metadata reads validate retained publication evidence and current grants. A
missing or inconsistent retained definition is not an absent live name. Preparing
against a typed basis freezes object identity, metadata revision and full schema
fingerprint; name reuse cannot redirect saved work to another Table.

Errors retain the native cause, available authority rejection and an owned
structured diagnostic. SQL errors use the general parser's captured location;
typed inputs retain their own schema and operation failures. Failed reads never
claim terminal outcomes. A lost submit confirmation remains unknown with its
original sequence and exact-recovery guidance. Definitive native rejection does
not settle previously accepted Table work.

Denied operations return `denied`; changed identities, scope, metadata or policy
return `conflict`. Missing initialization or unloaded local intent returns
`not_ready`; unavailable transport, resource or owner returns `unavailable`.

## Port configuration and budgets

Configure `url`, a private `seed_file` and `catalog_client` with the same options
as the native handle. The profile is mutually exclusive with query, mutation,
server and local-codec profiles. Other profiles return `not_ready` for catalog
calls. JSON validation rejects numeric wide identities, quoted native counters,
unknown fields and incompatible definitions. Recursive logical cells preserve
numeric precision and typed nested structure.

The generated `limits.catalog_line_bytes` bounds the complete catalog host line
at 16 MiB plus 16 KiB of framing space. Other profiles retain the raw-client bound.
The host uses a 16 KiB input buffer and grows storage only for the current line;
an oversized or truncated line terminates framing without dispatching it.
Catalog JSON has independent depth, token and field budgets. Table schema,
value, row, intent and prepared-step bounds still apply below the transport.
These limits do not widen kernel frames, 256-byte native values or turn budgets.

`shutdown` joins and destroys catalog and raw transport owners before acknowledging
closure. Keep saved intent, signed steps and known receipts independently of
child-process lifetime, with current grants for reconciliation.
