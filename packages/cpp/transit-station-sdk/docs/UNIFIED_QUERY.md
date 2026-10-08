# Unified state queries

Include `transit/unified_query.hpp` and use
`transit::sdk::station::unified`. The C++17 API composes the
[public C SDK](../../../c/transit-station/docs/UNIFIED_QUERY.md); source validation,
encoding, signatures and query semantics remain in shared Zig.

```cpp
namespace q = transit::sdk::station::unified;
q::Source source = q::KvSource{
    resource, {'d', 'a', 't', 'a', '/'}, {q::DecoderType::Binary}, {q::DecoderType::UInt64}
};
auto bundle = q::prepare(source, {{1}, All{}, Aggregate::Rows, std::nullopt, std::nullopt},
                         {1000, 100, 1048576});
auto client = q::Client::open(config, credential, connection);
auto capabilities = client.describe(source);
auto command = client.prepare_next(namespace_id, bundle);
```

The surrounding application supplies realm-scoped process/resource refs, the
explicit credential and a durable positive namespace. `Source` is a variant of
`KvSource`, `TableSource` and `DocumentSource`. `Plan` uses ordered projections,
`All`, `IsState`, typed `Compare` or `PredicateProgram`, an optional full-width limit and an explicit
aggregate. `TableSource` owns its catalog owner, metadata and schema; metadata
retains the immutable publication commitment. `Column` uses `logical::Type` with
nullable/optional flags. Result projections allow 128 columns and 255-byte UTF-8
names. KV decoders and Document `DecoderColumn` projections retain their six
scalar types and the eight-column Document projection limit. Unsupported decoder
versions, types and paths reject.

`PredicateProgram` owns a vector of one to 64 `PredicateInstruction` values.
Each instruction is either a `PredicateAtom` variant (`All`, `IsState`, `Compare`)
or `PredicateOperator::Negate`, `Conjunction` or `Disjunction`. Two atoms followed
by `Conjunction` express AND. Programs cannot nest. The synchronous C adapter
borrows the plan's owned values through preparation; the returned bundle keeps
its bytes independently. Shared Zig checks the complete program and source types,
evaluates eagerly with null/missing as unknown, and selects only true.

`InspectedProgram` owns the same postfix structure using `InspectedAtom` values
with names/types instead of literals. Its vectors and strings can outlive the
client. The C ABI layout and shared-definition cutover require matching C/C++
headers, SDK libraries and native artifacts; follow the C guide's recovery rules.

`client.compile_sql(source, name, sql, budgets, parameters)` returns a move-only
owned `Bundle`. `parameters` is an optional vector of `Scalar`: omission or
`std::nullopt` selects ordinary SQL; an empty vector selects a template without
placeholders. The result survives the source and binding inputs.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned uint64-range atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

`client.inspect_sql(source, name, sql, budgets)` executes scoped `DESCRIBE name`,
`SHOW TABLES` or `EXPLAIN SELECT ...`. Its owned `Inspection` carries source/schema
digests, current resource/policy revisions and a variant of `SourceDescription`,
`TableListing` and `Explanation`. The explanation owns typed operators, predicate
structure without literals, projection/output columns and explicit budgets.
Full-width values use `uint64_t`; results can be copied and outlive the client.
The shared Zig owner checks current authorization before and after resolution,
creates no snapshot and admits no query. The listing covers one configured source.

Persist `command->data()` before `client.submit(*command)`. An
`Error` with `TRANSIT_SDK_UNKNOWN_OUTCOME` leaves the caller-owned token intact;
recover it using `Prepared::recover` and resubmit the identical bytes. Admission,
`observe` disposition and `status` completion are separate. An empty
`prepare_next` result means inspect status, not completed results.

After completion, `page` returns owned IPC, typed columns, manifest evidence and
an optional owned cursor. Manifest evidence includes the retained source head.
`Page::decode` returns owned `logical::Cell` values, preserving missing, null,
type errors, nested values and ordered conflicts. `Scalar` is `logical::Atom`;
use constructors such as `Scalar::signed_integer`, `unsigned_integer` and `utf8`.
Integers preserve their complete 128-bit range. Both pages and decoded values
outlive the client. A local decode checks Arrow shape; only an authorized page
read checks current source availability and result coverage. No Arrow C++
dependency is selected by the core SDK.

Clients, bundles, prepared commands and cursors are move-only. Calls block on the
C SDK's bounded worker. Close/RAII joins work without cancelling the durable
query. Join caller threads before moving/destroying a handle. Use
`prepare_control(Control::Cancel/Retire/Collect, namespace_id)` to explicitly
record lifecycle work, with the same persistence and uncertain-outcome rules.

`just bindings::unified-c` builds installed C11/C++17 consumers, independent nested
Arrow fixtures and the signed service recovery schedule. Source-specific evidence
and remaining deployment work are in the [proof guide](../../../../tests/README.md).
