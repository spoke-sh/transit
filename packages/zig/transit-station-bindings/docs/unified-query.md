# Unified query clients and codecs

The `station_unified_query_codec(json, length, output)` export and
`unified_query_codec` port action share `QueryCodec`. Generated schemas come from
the same Zig types. The [v1 contract](../../../../contracts/UNIFIED_QUERY_V1.md)
owns source identity, typed semantics and the foreign representation.

| Action | Returned value |
| --- | --- |
| `prepare` | Canonical finite bundle as hex plus its Publication specification |
| `decode` | Validated typed source, plan and explicit work limits |
| `source` | Canonical source bytes, exact digest, policy declaration digest and schema |
| `inspect_arrow` | Owned typed rows from one verified nested IPC segment and declared schema |

`prepare` binds the plan to the declared source schema before encoding. It cannot
infer a KV decoder, adopt an unknown Document format or widen a Table schema.
Document paths are UTF-8 name arrays; list expansion and text projections retain
their explicit traversal/byte budgets. `decode` rejects incomplete/trailing bytes.

Logical source schemas describe every column, including nested types, nullability
and optionality. Table declarations bind catalog scope, owner, stable object and
immutable metadata; they do not identify a two-column positional layout.

Keep all non-counter integers, including 128-bit values, as decimal strings.
Typed scalar bindings use `signed` or `unsigned`, with the inferred logical
descriptor selecting the exact width; decimal coefficients, temporal values and
UUIDs use the shared [logical value encoding](../../../../contracts/FUZE_TYPES_V1.md). Float values use
`float_bits` hex to preserve negative zero; binary uses hex and UTF-8 uses text.
Projection indices are numeric arrays. Returned conflicts include their original
ordered assignment IDs and distinguish null from a typed value or type error.

Plans accept `output_names` as null for all defaults or an array matching the
projection width. Each position is null or a nonempty UTF-8 name of at most 255
bytes, without NUL. Named output positions may repeat an input index when resulting names
are distinct. Decoding preserves owned names and null slots, so preparing a
decoded bundle retains its exact bytes and immutable Publication identity.

The neutral `predicate.program` array accepts one to 64 postfix instructions.
Atoms reuse the `all`, `state` and `compare` values; `negate`, `conjunction` and
`disjunction` have empty-object payloads. The shared owner validates complete
stack shape and every typed atom before encoding. Decode copies instruction
and literal storage into its owned result. The generated array limit is specific
to programs; column limits are 128 and row pages contain at most eight rows. Native SQL lowers NOT, AND, OR
and grouping to these programs. All ten SDKs expose typed program constructors
and inspected programs. The C/C++ layout extension replaces the shared ABI
definition; deploy matching headers, SDK libraries and native artifacts.

The complete JSON input is at most 256 KiB. The native implementation additionally
enforces the 25069-byte bundle, 128-column/eight-row page, 4 KiB comparison
literal and 64 KiB Arrow segment bounds. Recursive cells retain the logical
child, nesting and byte budgets; KV and Document keep their narrower decoder
profiles. Arrow parsing uses a 4 MiB fixed workspace. All returned arrays,
names, scalars and IPC-derived values are copied into the owned result; they do
not borrow temporary parsing storage. Release every native `station_buffer`
once, and join in-flight work before destroying a foreign owner.

The port can run with `{"local_codec":true}`. It needs no authority URL, key or
execution handle. Pure decoding does not establish current source availability
or authorization; signed submission/result qualification is separate.

`tests/query/unified/unified_codec.py HOST LIBRARY ARROW_PRODUCER` checks both transports
against independently encoded source/schema-bound bundles. The native producer
supplies the canonical schema header, which the decoder requires exactly;
PyArrow independently interprets its data and produces the test record batches. It covers all three sources, six
primitive types, five cell states, Unicode, binary, full-width integers/IDs,
negative zero, empty results and malformed inputs. Installed SDK transport
checks and their execution limits are recorded in the [proof ledger](../../../../docs/history/qualification/README.md).

## Signed caller ownership

`station_unified_query_create/call/destroy` own a separate query caller. Creation
requires a URL, explicit seed, realm/principal and source/requester PID/resource
bindings; it requires no activation or writer ownership. The generated
`UnifiedQueryConfig`, `UnifiedQueryAction` and `UnifiedQueryResult` schemas define
the additive ABI. The port selects `query_client` instead of either server
profile and accepts `unified_query` actions. Importing a language package does
not open this owner or load a credential.

`capabilities` advertises the local v1 implementation. `describe` separately
checks the configured current source policy and declared schema. `next` prepares
one upload/admission command for a caller-selected namespace and canonical
bundle. Persist its opaque `prepared` string before `submit`. An admission
receipt supplies the input position for `observe`; wait for `committed` before
preparing the next command. A null prepared command means upload/admission has
stopped; inspect `status` for completion, denial or cancellation. It is not a
complete-result claim. `prepare` also supports explicit cancel, retire and
bounded collect commands.

`inspect` accepts a `scope` (`name`, `source`, `limits`) and complete inspection
SQL. It delegates to `UnifiedClient.inspectSql` and returns `inspection`, with
current metadata evidence and description, Table listing or proposed plan.
It never returns a prepared token or query result. The
[SQL inspection contract](../../../../contracts/SQL_INSPECTION_V1.md) defines the
one-source scope, current access checks and exact metadata bounds.

`compile` accepts the same explicit `scope`, a finite SELECT `sql` string and
optional `parameters`. A parameter array uses typed `$n` template syntax; an
omitted/null array uses ordinary SQL. Scalars use the shared representations
above, with exact inferred types and no substitution into SQL text. The
`compiled` result owns canonical bundle hex, source/plan/limits and exact
source/schema fingerprints. Current source permission and budgets are checked
before and after compilation; no snapshot, upload or admission is created.
The separate local `sql_capabilities` action advertises `parameters: true` and
the statement/parameter bounds; existing capability responses are unchanged. The
[parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md#neutral-compilation-operation)
defines validation, ownership and compatibility. The returned bundle can be
passed to `next`; retain those exact bundle and prepared-command bytes across
uncertainty instead of compiling or binding again.

After uncertain dispatch, retain and resubmit the **identical prepared string**,
including after replacing the native owner. Never parse/re-encode it or prepare
a new command to resolve the old attempt. Local invalid-envelope failures occur
before dispatch; unconfirmed transport or result failures after dispatch return
`uncertain`. Successful admission still differs from observed behavior completion.

`page` returns an owned IPC segment, typed source/plan commitments and complete
manifest counters. Its opaque `next` string preserves verification progress,
not permission. Each page rechecks current source/request access and lifecycle;
only a null continuation after whole-result verification establishes coverage.
Save a cursor only with its exact connection/namespace. A failed page cannot
advance it. Decimal strings retain full-width quantities in manifests; signed
prepared/cursor strings must remain opaque to numeric JSON parsers.

Each handle admits one operation at a time and returns `busy` on overlap. Join
all calls before destroy. Foreign cancellation of an await does not cancel
durable work; an explicit prepared cancellation is a separate command. Native
buffers own their data independently of the handle. Calls use bounded request,
bundle, Arrow workspace and segment sizes from the codec profile above.

## Failed caller operations

Query ABI and port failures retain `err` and `protocol_error` when available,
and add a nullable shared `diagnostic` envelope. Compilation and EXPLAIN binding
errors include the original compiler's subject, scope, SQL byte position,
parameter sites and expected/supplied type evidence. These details are returned
to the caller; they are not telemetry or automatic exception text.

The diagnostic describes the failed attempt. A locally rejected saved command
has `not_submitted` evidence. An unconfirmed dispatched command has `unknown`
outcome and its exact native sequence identity; retain the saved signed bytes.
A native command rejection does not establish a query's terminal outcome.
Status/page read failures have no new domain outcome and cannot replace a saved
receipt or terminal status. Unrecognized failures are internal diagnostics,
mapped to native `invalid_response`, rather than SQL input errors. Failure to
allocate diagnostic output preserves the native status and original recovery
obligations. SDK exception adoption is documented by each caller interface.

## Relational catalog callers

The same query ABI/port accepts a `relational` action with its separately
configured direct catalog routes. A relational-only configuration omits
`connection` and supplies the current `relational.definition`, direct
`relational.catalogs`, explicit budgets and a private
spill directory. It opens no behavior activation. Explanation, exact active-open
retry, one-row pages and explicit close share the Zig relational owner. Open
requires complete saved source bindings and explicit retained snapshots. Local
close never releases their durable pins; catalog retention owns that operation. Current
source rights apply to repeated pages and completion. Interactive handle loss
cannot become durable recovery. See the [relational caller guide](../../transit-query/docs/relational-callers.md)
for exact actions, representations, bounds and supported lifetimes.
