# Language SDKs

Raw Transit and Station are separate public packages. Raw clients prepare signed
operations, read capabilities and preserve exact recovery. Station adds typed
messages, private turns, Tables and handler runners. Shared protocol and framework
semantics stay in Zig; host packages own language types, codecs and scheduling.

Choose a language below for installation and its client/framework guides.
The handbook SDK section has its own sidebar and shares search with the other
interfaces. Source ownership is described in the [SDK directory](../../../sdks/README.md).

The [Zig SDK](../../../sdks/zig/README.md) also exposes
[`transit_data_client`](../../../packages/zig/transit-data-client/README.md),
an independent direct Catalog caller with explicit allocator/I/O and outcome
ownership. It shares the implementation used by existing Catalog bindings;
ordinary automatic settlement and a unified data/SQL context remain unimplemented.
Its [Catalog context](../../../packages/zig/transit-data-client/docs/context.md)
composes explicit Table, Stream and Queue operations with bounded data/control
admission and joined close. The exported SQL executor independently supports
[pre-dispatch persistence](../../../packages/zig/transit-sql-client/README.md#persisting-an-original-attempt)
of the original attempt through an application callback.

Build and install the SDKs from this checkout on Linux x86_64. Follow each
package's installation commands and the [SDK examples](../../../examples/station-sdk/README.md).
Packages are not distributed through public registries.

The [workload example gallery](../guides/workload-examples.md) walks through typed
observations in Python, durable requests in TypeScript, bounded research results
in Rust, and Document/effect workflows in Zig, with complete source and run commands.

| Language | Raw client | Framework |
| --- | --- | --- |
| [Zig](../../../sdks/zig/README.md) | [transit_client](../../../sdks/zig/README.md) | [transit_station](../../../sdks/zig/README.md) |
| [Python](../../../sdks/python/README.md) | [transit-client](../../../sdks/python/transit-client/README.md) | [transit-station](../../../sdks/python/transit-station/README.md) |
| [TypeScript / Node.js](../../../sdks/ts/README.md) | [transit-client](../../../sdks/ts/transit-client/README.md) | [transit-station](../../../sdks/ts/transit-station-sdk/README.md) |
| [Rust](../../../sdks/rust/README.md) | [transit-client](../../../sdks/rust/transit-client/README.md) | [transit-station](../../../sdks/rust/transit-station-sdk/README.md) |
| [Go](../../../sdks/go/README.md) | [client](../../../sdks/go/README.md) | Not exposed |
| [Ruby](../../../sdks/ruby/README.md) | [transit-client](../../../sdks/ruby/transit-client/README.md) | [transit-station](../../../sdks/ruby/transit-station/README.md) |
| [C](../../../sdks/c/README.md) | [transit-client](../../../sdks/c/transit-client/README.md) | [transit-station](../../../sdks/c/transit-station/README.md) |
| [C++](../../../sdks/cpp/README.md) | [transit-client](../../../sdks/cpp/transit-client/README.md) | [transit-station](../../../sdks/cpp/transit-station-sdk/README.md) |
| [Java](../../../sdks/java/README.md) | [transit-client](../../../sdks/java/transit-client/README.md) | [transit-station](../../../sdks/java/transit-station-sdk/README.md) |
| [.NET](../../../sdks/dotnet/README.md) | [transit-client](../../../sdks/dotnet/transit-client/README.md) | [transit-station](../../../sdks/dotnet/transit-station-sdk/README.md) |
| [Erlang](../../../sdks/beam/README.md) | [transit-client](../../../sdks/beam/transit-client/README.md) | [transit-station](../../../sdks/beam/transit-station-sdk/README.md) |
| [Elixir](../../../sdks/beam/README.md) | [transit-client](../../../sdks/beam/transit-client-elixir/README.md) | [transit-station](../../../sdks/beam/transit-station-elixir/README.md) |

The eleven non-Zig language targets use the shared native boundary. Go exposes
raw input submission, capability reads and exact mutation recovery. The ten
Station SDKs provide the data/framework operations described below. Browser clients
use separate generated, runtime-validated [query](../../../packages/ts/transit-query-client/README.md),
[reactive](../../../packages/ts/transit-reactive-client/README.md) and
[application](../../../packages/ts/transit-application/README.md) packages; the Node
native client is not a browser credential adapter.

## Typed SQL compilation

All ten SDKs compile finite SQL with an explicit source, source name, positive
budgets and optional ordered scalar bindings. They call the same shared
compiler, current-access checks and neutral codecs. Compilation returns an owned
ordinary bundle and performs no snapshot acquisition or admission.

Direct Table sources carry each schema column's declared collation in column
order. Preparing a new bundle binds its plan to that same vector. Lookup
validates the source's row type and collation vector against its
returned schema before exposing a reusable declaration. Missing or inconsistent
source metadata is rejected; it does not acquire a default collation on read.

| Language | Public query method |
| --- | --- |
| Python | [`Client.compile_sql`, `AsyncClient.compile_sql`](../../../sdks/python/transit-station/docs/unified-query.md) |
| TypeScript | [`Client.compileSql`](../../../sdks/ts/transit-station-sdk/docs/unified-query.md) |
| Rust | [`Client::compile_sql`](../../../sdks/rust/transit-station-sdk/docs/UNIFIED_QUERY.md) |
| Ruby | [`Client#compile_sql`](../../../sdks/ruby/transit-station/docs/UNIFIED_QUERY.md) |
| C | [`transit_station_unified_compile_sql`](../../../sdks/c/transit-station/docs/UNIFIED_QUERY.md) |
| C++ | [`Client::compile_sql`](../../../sdks/cpp/transit-station-sdk/docs/UNIFIED_QUERY.md) |
| Java | [`Client.compileSql`](../../../sdks/java/transit-station-sdk/docs/UNIFIED_QUERY.md) |
| .NET | [`Client.CompileSqlAsync`](../../../sdks/dotnet/transit-station-sdk/docs/UNIFIED_QUERY.md) |
| Erlang | [`transit_unified_query:compile_sql/5,6`](../../../sdks/beam/transit-station-sdk/docs/unified-query.md) |
| Elixir | [`UnifiedQuery.compile_sql/5,6`](../../../sdks/beam/transit-station-elixir/docs/unified-query.md) |

Omitted bindings select ordinary SQL; an explicit empty collection selects a
template without placeholders. The [parameter reference](sql/parameters.md)
defines exact typing, grammar sites and limits. Follow the ordinary bundle
upload and saved-command recovery workflow; rebinding is a new query, not a
retry of uncertain work. These methods do not create named prepared statements.

## Finite query output names

All ten language SDKs expose optional names by output position in their finite
query plans. Python, Ruby, Rust, Erlang, Elixir and C++ use `output_names`;
TypeScript and Java use `outputNames`; .NET accepts `outputNames` and exposes
`OutputNames`. An omitted vector retains defaults. A supplied vector matches
the projection width and uses the language's optional/null value for an
unrenamed position. C uses eight nullable `output_names` pointers in its plan;
slots beyond `projection_count` remain null and strings are borrowed only for
the synchronous call.

Names are ASCII identifiers of at most 32 bytes. Resulting names must be distinct;
distinct names allow projecting an input column more than once. Names preserve
cell types/states, source identity and authority requirements, and participate
in canonical bundle identity. The shared Zig compiler uses the same model for
SQL `AS` names, with SQL's 16-byte identifier bound. See the
[query contract](../../../contracts/UNIFIED_QUERY_V1.md#public-surfaces-and-qualification)
and [neutral codecs](../../../packages/zig/transit-station-bindings/docs/unified-query.md).

## Finite query predicate programs

All ten SDKs expose typed postfix programs in their finite query plans. A program has one to 64 instructions: an all-row, state or comparison
atom, or a NOT, AND or OR operator. Programs cannot nest. Shared Zig validates
the whole program against the declared source before encoding; language APIs do
not implement a separate evaluator. Instructions retain eager error order and
three-valued truth, with only true selecting a row. Inspected programs own their
structure and exclude literals.

| Language | Program API |
| --- | --- |
| Python | `PredicateProgram` tuple of `PredicateAtom` / `PredicateOperator` |
| TypeScript | `Predicate` with `kind: "program"` and `PredicateInstruction` array |
| Ruby | `PredicateProgram` with copied/frozen `PredicateAtom` / operator symbols |
| Rust | `Predicate::Program` with owned `PredicateInstruction` / `PredicateAtom` |
| Java | `PredicateProgram` with copied `PredicateAtomInstruction` / `PredicateOperator` list |
| .NET | `PredicateProgram` with copied `PredicateAtomInstruction` / `PredicateOperation` collection |
| Erlang | `transit_unified_predicate_program` record with atom tuples / operator atoms |
| Elixir | `PredicateProgram` struct with atom tuples / operator atoms |
| C | `TRANSIT_UNIFIED_PROGRAM` plan with borrowed tagged instructions; owned inline inspection |
| C++ | `PredicateProgram` with owned `PredicateAtom` / `PredicateOperator` vector |

Native/port codecs and native SQL use the same program contract. See
[query semantics](queries.md) and each language's query guide for bounds, ownership
and recovery. The C/C++ plan and explanation layouts require matching headers,
SDK libraries and native artifacts under the current shared v1 definition.

## Relational callers

[TypeScript `relational.Client`](../../../sdks/ts/transit-station-sdk/docs/relational.md)
and [Python `relational.Client` / `AsyncClient`](../../../sdks/python/transit-station/docs/relational.md)
expose explicit catalog routes, metadata-only explanation, interactive open,
one-row pages and close through the shared Zig relational owner. Typed Zig and
these SQL callers use the same prepared plans, source rights and budgets.
Returned references and rows are owned and immutable; integers preserve their
full declared range. Current rights apply even to repeated and terminal pages.
Only terminal coverage completes a result; errors leave any prefix incomplete.

One client owns one active query. Its reference includes the exact contract
definition, query ID, plan and source basis. Saving the reference does not make
the query durable: host replacement rejects it. Captured and maintained
relational lifetimes remain separate typed Zig interfaces. Other language SDKs
retain their documented single-source query profiles; generated neutral schemas
alone do not provide an idiomatic relational adapter.

## Catalog callers

Python provides [synchronous and asynchronous catalog callers](../../../sdks/python/transit-station/docs/catalog.md);
TypeScript provides [promise-based catalog callers](../../../sdks/ts/transit-station-sdk/docs/catalog.md);
Rust provides [blocking callers with exclusive borrows](../../../sdks/rust/transit-station-sdk/docs/CATALOG.md);
Ruby provides [block-scoped synchronous callers](../../../sdks/ruby/transit-station/docs/CATALOG.md);
C provides [owned handles and inline values](../../../sdks/c/transit-station/docs/CATALOG.md);
C++ provides [typed values and move-only owners](../../../sdks/cpp/transit-station-sdk/docs/CATALOG.md);
Java provides [immutable values and bounded futures](../../../sdks/java/transit-station-sdk/docs/CATALOG.md);
.NET provides [immutable values and bounded tasks](../../../sdks/dotnet/transit-station-sdk/docs/CATALOG.md);
Erlang provides [immutable records and an owned worker](../../../sdks/beam/transit-station-sdk/docs/catalog.md);
Elixir provides [structs over the Erlang caller](../../../sdks/beam/transit-station-elixir/docs/catalog.md).
These support initialization, conditional policy, named Table creation and exact
saved recovery through the shared [native catalog boundary](../../../packages/zig/transit-station-bindings/docs/catalog.md),
retaining full-width identities. All ten SDKs also expose exact-name lookup,
immutable definition reads and ordered pages of at most eight definitions.
Continue with the original mandatory-definition cursor; a changed revision
requires a fresh listing. Every metadata call rechecks current inspection and
native rights. The [catalog caller](../../../packages/zig/transit-catalog/README.md) uses the same
Zig owner; query connections do not enable administration.

## Rules that travel across languages

- Supply credentials and the protocol profile explicitly; imports perform no I/O.
- A host task/future is not a durable call. Cancelling an await does not establish
  external cancellation or undo accepted work.
- Retain a saved mutation's canonical bytes after an unknown outcome. Exact retry
  must preserve its identity across process and language boundaries.
- Handler fields and scheduling queues are volatile. Commit durable values in
  the turn's state resource and release borrowed views at their documented scope.
- Read bounded pages and own/release Arrow buffers through the binding contract;
  do not copy the whole retained collection into a resident queue.

Use [caller and SDK semantics](callers.md) for authority, scoped turns, native
ownership, scheduling and exact recovery.
The local application service installs separately compiled Zig workers. Other SDKs provide client
and framework APIs; the local supervisor has no worker adapter for those languages.

### Structured failure details

Query, Table mutation and catalog compiler or caller-attempt failures can carry the shared
[diagnostic envelope](../../../contracts/DIAGNOSTICS_V1.md). SDK error values retain
it independently of the raw native buffer. Error text stays concise; callers
explicitly render detail when appropriate. A failed send keeps its original
uncertainty and exact saved command. A failed status read does not establish a
new domain outcome. Optional malformed detail is discarded and flagged; it does
not replace the primary native error.

| SDK | Diagnostic access | Invalid optional detail |
| --- | --- | --- |
| Python, Ruby | `error.diagnostic` | `error.diagnostic_invalid` |
| TypeScript | `error.diagnostic` | `error.diagnosticInvalid` |
| Rust | `Error.diagnostic` | `Error.diagnostic_invalid` |
| C | `error.diagnostic.json` and `.size` | `error.diagnostic_invalid` |
| C++ | `error.detail().diagnostic` | `error.detail().diagnostic_invalid` |
| Java | `error.diagnostic()` | `error.diagnosticInvalid()` |
| .NET | `error.Diagnostic` | `error.DiagnosticInvalid` |
| Erlang, Elixir | Error record/struct `diagnostic` | `diagnostic_invalid` |

Native SDKs use the shared Zig diagnostic validator. Port SDKs check the
generated shape; the native port validates semantic evidence/action rules before
emitting its response. These checks do not authorize recovery actions. C errors
own a bounded 32 KiB JSON buffer, with zero size for absent detail. The error
layout and generated binding resources require the matching current definition;
foreign headers/libraries and native artifacts reject before use.

Table mutation statuses, catalog receipts and input dispositions also carry a
mandatory `diagnostic` (`Diagnostic` in .NET). These values preserve the original
domain outcome and recovery guidance after the native buffer or client is
released. Mutation `rejection` reads return a disposition with principal, native
input, payload commitment, reason and diagnostic. An input rejection can leave
the original upload recoverable; inspect its mutation status separately.
Catalog name, object and Table conflicts identify the original requested target.
Current read authorization applies to all retained detail. A failed read never
replaces previously saved evidence with an inferred outcome. C embeds diagnostic
JSON and byte count in the status/disposition struct; C++ owns a JSON string;
the other SDKs retain their language's JSON object or map.

HTTP and gRPC outcome/rejection models also own `diagnostic` (`Diagnostic` in
.NET, `diagnostic()` in C++/Java). C embeds its JSON bytes and size in the outcome
struct for either variant. Rust's `Rejected` reply variant contains a value with
`reason` and `diagnostic`. The detail outlives the local codec host/native buffer.
Observed HTTP errors and non-OK gRPC statuses have a completed capture and their
exact protocol status; this does not certify business success or permit retry.
An exchange without an authorized attempt is `not_dispatched`. Rejected calls
use `input_rejected` and do not replace a prior exchange outcome. The pure reply
codec has no realm input, so the diagnostic's exchange identity retains resource
and full-width ID with an absent realm; the owned outcome has the caller's
explicit `ResourceRef`. Original capture/closure causes absent from the reply
are marked unrecorded. All ten SDKs expose separate HTTP/gRPC diagnostic reads
on a decoded outcome: `capture_failure` returns the original retained local
failure, while `native_effect` projects the independently recorded native effect.
The language guides name each API and kind spelling. These reads work without a
complete capture reference, including after exchange retirement while its resource
and evidence remain readable. A null/empty result means no record of the requested
kind; it does not establish success or justify a fresh attempt.

Each call checks current capture-resource inspection/read grants. Native effect
reads additionally require native inspection scoped to the connector PID;
a caller's own PID grant and resource association do not confer that permission.
The read binds the effect to the immutable intent and checks current capture
access again before returning. Revocation, a changed authority cut, unavailable
evidence or inconsistent history remains a read error; it never rewrites a saved
outcome. The runner must have no pending mutation. Reads create no replay cursor,
resolve no credentials, and dispatch, resume or retry no effect.


## Handler query failures

When query-result handling is enabled, terminal negative results invoke a typed
failure callback. The callback receives the input position, authenticated origin,
full-width correlation, result identity and reason. It runs in the same private
turn that records the outcome and closes the durable wait. Application message
codecs do not parse framework failures.

| SDK | Handler callback | Outcome type |
| --- | --- | --- |
| Python | `handle_query_failure(turn, failure)` | `QueryFailure` |
| TypeScript | `handleQueryFailure(turn, failure)` | `QueryFailure` |
| Rust | `handle_query_failure(turn, failure)` | `QueryFailure` |
| Ruby | `on_query_failure(turn, failure)` | `QueryFailure` |
| C | `transit_station_handler.query_failure` | `transit_station_query_failure` |
| C++ | `handle_query_failure(turn, failure)` | `QueryFailure` |
| Java | `onQueryFailure(turn, failure)` | `Types.QueryFailure` |
| .NET | `OnQueryFailure(turn, failure)` | `QueryFailure` |
| Erlang | `handle_query_failure/3` | `#transit_query_failure{}` |
| Elixir | `handle_query_failure/3` | `%QueryFailure{}` |

Reasons are `result_too_large`, `workspace_exceeded`, `overflow`, `cancelled` and
`denied`, represented by the SDK's typed enum, string union or atom. A failed
query has no completed result reader. Received prefixes remain incomplete
retained evidence. The callback may record application state within the remaining
native write budget; framework closure uses two of the four mutations. Omitting
the callback or raising from it follows the configured stop/block policy and
does not silently consume the outcome. Java and .NET use interface defaults;
applications implementing a failure callback must include it in their handler's
interface implementation.

Duplicates and late outcomes cannot invoke another callback or reopen a closed
wait, including after replacement. Callbacks can still run again after an unsent
proposal is discarded, so external effects require their own recorded intent and
idempotency policy. No SDK automatically retries a failed query. An application
can explicitly submit a new call after addressing the reason. The
[handler query contract](../../../contracts/STATION_QUERY_V1.md) specifies source
checks, first-outcome semantics and retained evidence.
