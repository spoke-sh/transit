# Language SDKs

Raw Transit and Station are separate public packages. Raw clients prepare signed
operations, read capabilities and preserve exact recovery. Station adds typed
messages, private turns, Tables and handler runners. Shared protocol and framework
semantics stay in Zig; host packages own language types, codecs and scheduling.

Build and install the SDKs from this checkout on Linux x86_64. Follow each
package's installation commands and the [SDK examples](../../examples/station-sdk/README.md).
Packages are not distributed through public registries.

The [workload example gallery](../guides/workload-examples.md) walks through typed
observations in Python, durable requests in TypeScript, bounded research results
in Rust, and Document/effect workflows in Zig, with complete source and run commands.

| Language | Raw client | Framework |
| --- | --- | --- |
| Zig | [transit-client](../../packages/zig/transit-client/README.md) | [transit-station](../../packages/zig/transit-station/README.md) |
| Python | [transit-client](../../packages/python/transit-client/README.md) | [transit-station](../../packages/python/transit-station/README.md) |
| TypeScript / Node.js | [transit-client](../../packages/ts/transit-client/README.md) | [transit-station](../../packages/ts/transit-station-sdk/README.md) |
| Rust | [transit-client](../../packages/rust/transit-client/README.md) | [transit-station](../../packages/rust/transit-station-sdk/README.md) |
| Ruby | [transit-client](../../packages/ruby/transit-client/README.md) | [transit-station](../../packages/ruby/transit-station/README.md) |
| C | [transit-client](../../packages/c/transit-client/README.md) | [transit-station](../../packages/c/transit-station/README.md) |
| C++ | [transit-client](../../packages/cpp/transit-client/README.md) | [transit-station](../../packages/cpp/transit-station-sdk/README.md) |
| Java | [transit-client](../../packages/java/transit-client/README.md) | [transit-station](../../packages/java/transit-station-sdk/README.md) |
| .NET | [transit-client](../../packages/dotnet/transit-client/README.md) | [transit-station](../../packages/dotnet/transit-station-sdk/README.md) |
| Erlang | [transit-client](../../packages/beam/transit-client/README.md) | [transit-station](../../packages/beam/transit-station-sdk/README.md) |
| Elixir | [transit-client](../../packages/beam/transit-client-elixir/README.md) | [transit-station](../../packages/beam/transit-station-elixir/README.md) |

The ten non-Zig language targets use the shared native boundary. Browser clients
use separate generated, runtime-validated [query](../../packages/ts/transit-query-client/README.md),
[reactive](../../packages/ts/transit-reactive-client/README.md) and
[application](../../packages/ts/transit-application/README.md) packages; the Node
native client is not a browser credential adapter.

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
[query contract](../../contracts/UNIFIED_QUERY_V1.md#public-surfaces-and-qualification)
and [neutral codecs](../../packages/zig/transit-station-bindings/docs/unified-query.md).

## Finite query predicate programs

Python, TypeScript, Ruby, Rust, Java, .NET, Erlang and Elixir expose typed postfix
programs in their finite query plans. A program has one to 64 instructions: an all-row, state or comparison
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

C and C++ typed plan constructors currently accept a
single comparison or state predicate. Native/port codecs and native SQL support
the program contract independently. See [query semantics](queries.md) and each
language's query guide for bounds, ownership and recovery.

## Catalog callers

Python provides [synchronous and asynchronous catalog callers](../../packages/python/transit-station/docs/catalog.md);
TypeScript provides [promise-based catalog callers](../../packages/ts/transit-station-sdk/docs/catalog.md);
Rust provides [blocking callers with exclusive borrows](../../packages/rust/transit-station-sdk/docs/CATALOG.md);
Ruby provides [block-scoped synchronous callers](../../packages/ruby/transit-station/docs/CATALOG.md);
C provides [owned handles and inline values](../../packages/c/transit-station/docs/CATALOG.md);
C++ provides [typed values and move-only owners](../../packages/cpp/transit-station-sdk/docs/CATALOG.md);
Java provides [immutable values and bounded futures](../../packages/java/transit-station-sdk/docs/CATALOG.md);
.NET provides [immutable values and bounded tasks](../../packages/dotnet/transit-station-sdk/docs/CATALOG.md);
Erlang provides [immutable records and an owned worker](../../packages/beam/transit-station-sdk/docs/catalog.md);
Elixir provides [structs over the Erlang caller](../../packages/beam/transit-station-elixir/docs/catalog.md).
These support initialization, conditional policy, named Table creation and exact
saved recovery through the shared [native catalog boundary](../../packages/zig/transit-station-bindings/docs/catalog.md),
retaining full-width identities. All ten SDKs also expose exact-name lookup,
immutable definition reads and ordered pages of at most eight definitions.
Continue with the original mandatory-definition cursor; a changed revision
requires a fresh listing. Every metadata call rechecks current inspection and
native rights. The [catalog CLI](../../apps/transit-cli/docs/catalog.md) uses the same
Zig owner; query connections do not enable administration.

## Table mutation callers

Typed mutation clients provide SQL compilation, explicit staging, exact saved
retries and durable status through the shared Zig owner. They require an
explicit writer/resource/Table connection and a separate mutation policy.
Read-query clients do not confer mutation access.

| Language | Caller API |
| --- | --- |
| Python | [Synchronous and asynchronous clients](../../packages/python/transit-station/docs/mutations.md) |
| TypeScript | [Promise methods and owned native port](../../packages/ts/transit-station-sdk/docs/mutations.md) |
| Ruby | [Blocking client with owned worker and immutable values](../../packages/ruby/transit-station/docs/MUTATIONS.md) |
| Rust | [Blocking client with exclusive borrows and owned requests](../../packages/rust/transit-station-sdk/docs/MUTATIONS.md) |
| C | [Owned handles, buffers and typed observations](../../packages/c/transit-station/docs/TABLE_MUTATIONS.md) |
| C++ | [Move-only clients and saved commands](../../packages/cpp/transit-station-sdk/docs/TABLE_MUTATIONS.md) |
| Java | [Immutable values and bounded asynchronous calls](../../packages/java/transit-station-sdk/docs/MUTATIONS.md) |
| .NET | [Immutable values, asynchronous calls and joined disposal](../../packages/dotnet/transit-station-sdk/docs/MUTATIONS.md) |
| Erlang | [Immutable records and an owned native-port worker](../../packages/beam/transit-station-sdk/docs/mutations.md) |
| Elixir | [Immutable structs and tagged recovery results](../../packages/beam/transit-station-elixir/docs/mutations.md) |

The
[native ABI/port](../../packages/zig/transit-station-bindings/docs/table-mutations.md)
exposes the same neutral operation independently of those public adapters.

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
`transit app` installs separately compiled Zig workers. Other SDKs provide client
and framework APIs; the local supervisor has no worker adapter for those languages.
