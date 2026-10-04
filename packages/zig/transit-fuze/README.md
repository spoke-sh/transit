# transit-fuze

Fuze's Zig-native query library, exported as `transit_fuze`. It runs in callers;
it has no Transit authority, storage, network or deployment dependency.

Fuze executes finite typed filter, projection, limit, count and checked integer
sum over caller-authorized source batches. Aggregates update bounded state
without materializing discarded row projections. It has no storage, credentials or
native authority. No optimizer rewrites are enabled.

`Types` owns bounded logical descriptors and the specialized scalar profile used
by `Unified`. `Types.Semantics` binds checked integer/decimal, finite float,
boolean, UTF-8/binary, Gregorian date, time, civil/UTC timestamp and UUID atoms.
Casts and lossless domain promotion have separate admission rules. Recursive
struct/list/array/map/union cells preserve null, missing, errors and conflicts;
`Types.Codec` owns decoded descriptor/value bytes in an explicitly released arena.
`Types.Json` keeps exact numeric lexemes and rejects duplicate decoded keys.
The [logical type contract](../../../contracts/FUZE_TYPES_V1.md) specifies codecs,
budgets and capability limits. These APIs do not extend SQL, persisted Tables,
native query plans or Flight. Run `just test::fuze-types` for independent fixtures.

`Type.validateDiagnostic(limits, &failure)` retains the first recursive descriptor
rejection in an owned `Types.Diagnostic`. `LogicalJson.decodeTypeContext` carries
that record through JSON descriptor decoding alongside the separate lexical
budget diagnostic. Paths address descriptor members from `/type`, including
zero-based field positions, without relying on valid or unique field names.
The record includes the violated rule, measured values, permitted maximum,
duplicate origin and a bounded supplied-value preview. It allocates no memory;
256-byte paths/previews report truncation explicitly. Member decoding also retains
missing/unknown/duplicate member paths, expected JSON shape or scalar range and
the byte offset of a present member/value. Scalar parsing uses the pinned JSON
decoder. Lexical preflight failures before member decoding retain their original
cause and measured budget without inventing a descriptor path.

`Type.clone(allocator)` validates descriptor and encoding budgets and returns a
`Decoded` owner with independent copies of every name and recursive child.
Release it with `deinit`; its canonical bytes and fingerprint match the source.
File SQL compilation uses this copy while retaining the source binding's current
metadata and identity checks. Lowering checks plan constraints against that owned,
immutable schema without repeating descriptor validation. Public plan admission
validates both descriptor and plan constraints.

`FileSource` implements bounded CSV/JSONL discovery and decoding over immutable
host-provided bytes. Explicit, sampled, full and raw modes freeze one schema;
`SourceCodec` saves/restores its exact binding under current source access.
The [file-source guide](docs/file-sources.md) owns modes, ownership, cancellation,
framing, limits and the separate acquisition/durable-job boundary.

`Unified` implements the [finite query v1 contract](../../../contracts/UNIFIED_QUERY_V1.md):
up to eight typed columns, full-width signed/unsigned values, finite float64,
UTF-8/binary, five cell states and preserved conflict alternatives. Its canonical
`FZP1` codec borrows decoded input. `Unified.Stream` retains bounded progress
across source pages; `Unified.Arrow` emits nested typed state/conflict columns.
KV, Table and Document adapters, interactive snapshots and durable public
submission compose these types through [transit-query](../transit-query/README.md).
The contract fixes workspace, segment and encoding budgets.

Typed plans provide optional owned `output_names` by output position. Row names
default to their source names; aggregate names default to `count` or `sum`.
Distinct output names permit projecting one input column more than once.
Validation rejects duplicate output names, malformed names and names outside the
output width. Output names affect the saved plan and result schema, while the
input schema and source basis stay unchanged. `FZP1` requires its current plan
definition before decoding; incompatible saved plans reject.

`Unified.Plan.predicateTruth` evaluates an already validated predicate as
`Unified.Truth`: `true_value`, `false_value` or `unknown`. Comparisons against
null or missing cells produce unknown; evaluated type errors and conflicts
remain errors. Exact state tests produce true or false. `Plan.matches` selects
only true, preserving the existing filter behavior. The pure truth operations
combine already evaluated values; they do not specify operand evaluation order,
suppress errors or authorize evaluation rewrites.

`Unified.PredicateProgram` composes these atoms in a borrowed postfix instruction
slice with `negate`, `conjunction` and `disjunction`. It accepts one to 64
instructions, validates all atoms against a schema before source processing and
requires exactly one final truth value. Evaluation uses a fixed 64-byte truth
stack with no allocation, recursion, jumps or shared subexpressions. It evaluates
atoms eagerly in instruction order and returns the first error; a determining
true/false operand does not suppress the other operand's error. Instruction and
literal storage must remain immutable while borrowed. `PredicateProgram.Owned`
copies instructions into a bounded inline array; its `view` borrows that owner's
current address. Scalar text/binary bytes remain borrowed. `Plan.Predicate.program`
stores this copyable value and participates in validation, fingerprints and
stream continuation checks. `FZP1` decoding owns instructions while borrowing
projection/literal bytes from its input. Programs use the same 8192-byte plan
budget. Native and local file SQL lower NOT, AND, OR and grouping through the same
bounded evaluator; each profile retains its own schema and literal admission.

`Unified.Sql` lowers SELECT syntax against declared sources. The
[SQL guide](docs/unified-sql.md) describes capabilities, allocated ownership and
errors. `Sql` owns the shared parser and cursor assistance. All callers execute
through `Unified.Plan` and `Unified.Stream`, including Station Table delivery.
`Prepared` compiles explicitly requested typed parameter templates and binds
owned values into that same plan. Its [template API](docs/unified-sql.md#typed-templates)
checks name/schema compatibility; callers retain resource identity and admission.
`Prepared.initDiagnostic` and `bindDiagnostic` retain owned parameter indices,
all use-site byte offsets, expected/supplied types and counts, and changed-schema
fingerprints in an optional `Sql.Binding`. Ordinary and diagnostic entry points
produce the same plans and errors; diagnostic storage requires no allocation.

`Sql.parseMutation` and `TableMutation.compile/lower` produce owned, exactly
typed plans for literal INSERT, UPDATE and DELETE against one declared Table.
These plans are separate from read queries. The application invokes Station's
private-turn helper under its own command authorization; public query transports
reject mutation statements. See the [Table mutation contract](../../../contracts/TABLE_MUTATION_V1.md).

`Sql.parseDeclaration` and `Declaration.compile` parse and validate offline
`CREATE TABLE`, `CREATE KV` and `CREATE DOCUMENT` definitions. Definitions own
their names and up to eight Table columns, preserve omitted nullability and
format canonical review SQL into a caller-owned buffer. `Definition.tableSchema`
explicitly checks compatibility with the existing two-column Table model.
Compilation does not provision resources, publish a catalog or confer authority;
query transports still reject declarations. The
[state declaration contract](../../../contracts/STATE_DECLARATION_V1.md) defines
types, ownership, errors and capability limits.

`Sql.hints` uses the production parser up to a token-boundary cursor and returns
bounded grammar expectations. `SqlInput` frames semicolon termination and
whole-token replacement while respecting quotes, nested comments and UTF-8.
Neither reads a catalog nor executes a statement. Callers filter expectations
against their authorized schema and executable capability profile.

`SqlInput.classify` combines tolerant lexical tokens with `Sql.classifyTokens`,
which records roles as the production SELECT, mutation, declaration and
inspection parsers consume input. Keywords, names, aggregate functions, types,
literals, numbers, parameters and comments have distinct presentation roles;
contextual words remain identifiers in name positions. Each semicolon-delimited
statement is classified independently. Incomplete or malformed suffixes retain
lexical roles, including unfinished strings, quoted identifiers and comments.
The caller supplies one role per UTF-8 byte within the 4,096-byte input bound;
classification allocates no memory, reads no catalog and grants no authority.
These local roles do not change parser acceptance or serialized contracts.
`SqlDiagnostic` owns excerpt roles captured before redaction and clipping;
its styled renderer supplies those roles alongside the escaped source text.

`Unified.Stream.stepDiagnostic` optionally captures the first failing scan row,
page row, source column, operation and postfix predicate instruction. Page cell
validation and eager predicate evaluation retain their existing order. Its owned
sidecar allocates no memory and does not change progress or publish a candidate
on failure. Callers own source identities, frozen bases and disclosure checks.

`Unified.Inspect.decode` validates that exact nested IPC schema and all cell
states, conflict IDs/order, scalar widths, nullability and complete stream framing.
Arrow allocations stay in caller-supplied workspace; decoded text/binary is copied
into the caller's result allocator. Keep the output `Batch` at its final address:
conflict slices borrow its fixed alternative arrays. Any error invalidates the
whole output. PyArrow-produced round trips and thirteen malformed schema/state
cases qualify this reader independently of Fuze's encoder.

Station owns Table storage and an authorized Table capture/delivery helper.
The [query reference](../../../docs/reference/queries.md) describes interactive
and durable queries across all supported sources. All use the same plan, source
basis and nested Arrow result definition. `model` contains Table storage cells
and descriptors, not a second query engine.

Bind a `Unified.Plan` to the exact basis/schema, initialize
`Unified.Stream.Progress.start(bound)`, and call `Unified.Stream.step` for each
bounded page. Workspace, output buffers and cancellation belong to the caller.
A changed source identity, schema, plan or page ordinal rejects continuation.
No native pointers or background tasks survive a step. See the
[incremental execution guide](docs/streaming.md).

`encode(allocator, batch, output)` writes a complete Arrow IPC stream into the
caller-supplied buffer and returns a borrowed slice. Failure returns no result;
the caller must discard the buffer. The batch remains caller-owned. Allocation
and stream/batch limits are separate: a bounded output buffer does not itself
bound every upstream intermediate allocation.

Run through the pinned development shell:

```sh
just test::arrow
(cd packages/zig/transit-fuze && zig build test)
```

The first command checks actual IPC bytes with independently implemented
PyArrow. The package tests exercise shared Arrow/compute types, ownership and
output failure, and the compatible upstream compute suite. PyArrow is a test
dependency; no C++ query engine is linked into Fuze.

[Integration notes](docs/integration.md) record pins, compatibility changes and
measured limits. [Tables](../../../docs/reference/tables.md) owns transaction and result
semantics; [Arrow](../../../docs/reference/arrow.md) owns Arrow interchange.

`SqlDiagnostic.structured()` projects the compiler's original binding context into
the shared [diagnostic value](../../../contracts/DIAGNOSTICS_V1.md): stable SQL
codes, source coordinates, expected/actual types, parameter sites and typed
correction actions. It does not perform additional catalog reads. Human console
hints remain a separate presentation; structured actions contain no dot commands.
