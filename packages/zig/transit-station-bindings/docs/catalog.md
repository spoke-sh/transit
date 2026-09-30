# Catalog callers

`station_catalog_create/call/destroy` expose the shared signed catalog client
through an explicit native handle. The native port selects `catalog_client` and
accepts `catalog` actions. Both use the
[neutral catalog values](../../../../contracts/DECLARATIVE_CATALOG_V1.md#neutral-caller-values),
with generated `CatalogConfig`, `CatalogAction` and `CatalogResult` schemas.
They compose the same Zig declaration compiler, current metadata reader and
signed caller used by native applications and the
[catalog CLI](../../../../apps/transit-cli/docs/catalog.md). Python exposes [typed sync/async catalog methods](../../../python/transit-station/docs/catalog.md);
TypeScript exposes [typed promise methods](../../../ts/transit-station-sdk/docs/catalog.md);
Rust exposes [typed blocking methods](../../../rust/transit-station-sdk/docs/CATALOG.md);
Ruby exposes [typed synchronous methods](../../../ruby/transit-station/docs/CATALOG.md);
C exposes [owned typed handles](../../../c/transit-station/docs/CATALOG.md);
C++ exposes [typed move-only callers](../../../cpp/transit-station-sdk/docs/CATALOG.md);
Java exposes [typed futures](../../../java/transit-station-sdk/docs/CATALOG.md);
.NET exposes [typed tasks](../../../dotnet/transit-station-sdk/docs/CATALOG.md);
Erlang exposes [typed records](../../../beam/transit-station-sdk/docs/catalog.md);
Elixir exposes [typed structs](../../../beam/transit-station-elixir/docs/catalog.md).

Creation takes ABI version one, an explicit authority URL, a 32-byte signing seed
and JSON configuration containing `connection` and optional `timeout_ms` (default
5000, range 1–60000). The connection contains `scope` (realm/resource numbers and
a decimal-string catalog ID), owner PID and caller principal. URLs are at most
2048 bytes, configuration at most 8192 bytes and complete action JSON at most
256 KiB. The model enforces its narrower name, request and 8192-byte prepared
command limits. Catalog, operation/object IDs and policy revisions retain the
full u64 range as strings; native counters retain their safe-integer bounds.

Creating a handle performs no network request, native provisioning, grant change,
writer activation or catalog initialization. `capabilities` and `compile` are
local; compilation returns reviewed fields and canonical request bytes without
implying permission or publication. Preparation checks current native metadata
and application policy, then signs a command without submitting it. The supplied
catalog host independently checks authorization and conditional state on input
application. Administrator control and result inspection remain separate rights.

## Owned calls and exact recovery

The handle uses the [shared ownership rules](bindings.md): an 8 MiB calling-thread
stack, one active operation per handle, `busy` on overlap and joined destruction.
It owns bounded I/O work and wipes its signing key during destruction. Native
result buffers outlive their caller handle and must each be released once with
`station_buffer_destroy`. Retain prepared strings and admission receipts outside
the handle or host task; they are the exact recovery material.

`submit` checks the saved command's definition, connection, complete frame and
signature before dispatch. Malformed local recovery returns `invalid_argument`.
Once a valid dispatch starts, unconfirmed transport/response failures and result
allocation failure return `uncertain`. No result triggers re-signing or automatic
retry. Submit the same saved string to reconcile, including after native handle
or port replacement. A returned receipt establishes native admission only.

Use `observe` for pending/processed input, `status` for the original Table
operation and `input_disposition` for control/rejection outcomes. Null status or
disposition is absence, not success. Current native and application inspection
rights gate old results. After restoring inspection policy, observe that control's
processing before trying a newly authorized result read. Input observation alone
does not establish application success.

Errors retain their native cause and authority code where available. Native or
catalog denial returns `denied`; changed scope/owner/configuration or conditional
policy conflict, changed cursor revision or changed referenced metadata returns
`conflict`; missing catalog initialization returns
`not_ready`; unavailable resource/owner returns `unavailable`. The ABI adds these
exports and schemas without changing earlier layouts or saved creation bytes.
Callers still require matching definition checks and the requested exports.

## Bounded metadata

`lookup` takes an exact name and returns an optional definition after validating
the binding and live Table schema. `definition` takes canonical decimal-string
`object` and `revision` IDs and returns an optional immutable definition.
`list` takes null or a complete cursor and returns at most eight ordered
definitions at one current resource revision. Definition results own their
names, schema and original creation attribution; full-width IDs remain strings.

The page has exactly eight optional slots, dense present entries and optional
`next`. A cursor includes the mandatory current contract definition, scope,
resource revision and last name. Reuse that exact cursor for continuation;
missing/foreign definitions and malformed fields reject. A changed resource
revision returns `conflict` and requires a new listing. Do not concatenate the
old partial result with a new revision. An empty final page is possible.

Metadata calls check current catalog inspection policy and native grants, including
when continuing an earlier page. They acquire no view and submit no command.
Dependent definition/Table batches stay at the initial revision and recheck
native grants. These actions add no handle-layout or saved-command changes.
Public SDK metadata methods remain separate from existing typed controls.

## Port configuration

Configure an explicit `url`, private `seed_file` and `catalog_client` containing
the same configuration as the native handle. The profile is mutually exclusive
with query, mutation, server and local-codec profiles. Other profiles return
`not_ready` for catalog actions. The catalog profile validates reflected JSON
shapes at configuration and request boundaries: numeric catalog IDs and quoted
native counters reject instead of being coerced.

`shutdown` joins and destroys catalog and raw transport owners before acknowledging
closure. Cancellation or port loss cannot cancel durable accepted work. Preserve
the original prepared string and known receipts independently of child-process
lifetime, and retain current grants when reconciling.
