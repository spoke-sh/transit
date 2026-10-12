# transit-fuze

Fuze's Zig-native query library, exported as `transit_fuze`. It runs in callers;
it has no Transit authority, storage, network or deployment dependency.

Fuze executes finite typed filter, projection, limit, count and checked integer
sum over caller-authorized source batches. Aggregates update bounded state
without materializing discarded row projections. It has no storage, credentials or
native authority. No optimizer rewrites are enabled.

`Relational` supplies pure admission, stable column resolution, output descriptors
and prepared/bound identities for finite int64 Table join/group plans. It also
defines distinct join/group NULL rules and checked aggregate steps.
`RelationalSql` lowers the selected finite SQL profile through shared syntax and
typed literals. `RelationalExecution` advances ordered source rows and externally
stored groups with bounded resident state, preserving bag multiplicity, null
extension and first-error order. Hosts own source capture, current permission,
spill and complete-result publication. The
[relational contract](../../../contracts/RELATIONAL_V1.md) defines capabilities,
ownership, canonical order, budgets and remaining integration obligations.
`RelationalIndex` supplies immutable group roots and bounded copy-on-write
updates. `RelationalCheckpoint` encodes exact operator progress; execution restore
rechecks the bound source vector and current rights through its adapter. Hosts
stage and atomically publish these records with input/output progress.
`RelationalDelta` encodes paired changes between complete maintained outputs,
binding both source vectors and preserving stable identities independently of
output ordinals. It acquires no publication or disclosure authority.
Existing single-source profiles retain their separately admitted operators.

`Types` owns bounded logical descriptors and the specialized scalar profile used
by `Unified`. `Types.Semantics` binds checked integer/decimal, finite float,
boolean, UTF-8/binary, Gregorian date, time, civil/UTC timestamp and UUID atoms.
Casts and lossless domain promotion have separate admission rules. Recursive
struct/list/array/map/union cells preserve null, missing, errors and conflicts;
`Types.Codec` owns decoded descriptor/value bytes in an explicitly released arena.
Descriptor `decodeInto`/`cloneInto`, bound-value `decodeBoundInto` and logical-plan
`decodeInto` also compose within a caller-owned request arena. The enclosing owner
releases both successful values and all partial allocations after a failure;
returned slices never outlive that arena. The same format and budget checks apply.
`Types.Kind` preserves observed decoder and Document mismatch kinds independently
of admissible descriptor tags. `Values.fromQuery` converts every six-scalar cell
state and conflict alternative without inventing an actual type or selecting a
winner; its copied values belong to the supplied arena.
`Types.Json` keeps exact numeric lexemes and rejects duplicate decoded keys.
The [logical type contract](../../../contracts/FUZE_TYPES_V1.md) specifies codecs,
budgets and capability limits. These APIs do not extend SQL, persisted Tables,
native query plans or Flight. Run `just test::fuze-types` for independent fixtures.

`LogicalPredicate` owns typed scalar predicate atoms and bounded postfix Boolean
programs over logical rows. File plans use these same primitives; source capture
and statement admission remain with their callers. NULL/state handling, eager
evaluation and comparison rejection follow the shared finite-query semantics.

`LogicalQuery` owns source-independent logical projection, filtering, limits,
counting and checked int64 summation. Its pull executor consumes one owned row
at a time and retains bounded aggregate state and original failure evidence.
`FileQuery.execute` binds it to the verified file scan; other adapters must
establish their own immutable schema/source binding and current disclosure rights.
The executor itself acquires no source or permission.

`LogicalPlanCodec` owns canonical `FQP1` serialization of these plans under an
exact supplied schema and source binding. Decode rejects foreign definitions and
stale bindings before reading dependent literals, then returns an independently
owned plan. The [Table query contract](../../../contracts/TABLE_QUERY_V1.md#canonical-logical-plans)
defines its byte budget, field layout and separation from query admission.

`LogicalPrepared` owns general logical SELECT templates with typed comparison
and LIMIT parameters, including Boolean predicates and recursive projections.
Binding checks the complete source/schema commitment and returns independent
canonical logical plans. Parameters retain exact integer/decimal/temporal values;
unsupported comparisons stay unsupported. Input and plan budgets apply before a
bound result is returned. See the [parameter contract](../../../contracts/SQL_PARAMETERS_V1.md#general-logical-template-compiler)
for scope, ownership and the separate caller-integration boundary.

Logical binding failures retain the exact caller identifier at the failing token,
including quoted, escaped and UTF-8 names up to 255 bytes. The owned diagnostic
survives releasing parser inputs; it does not reread source metadata for context.

`LogicalStream` evaluates bounded logical pages with canonical resumable progress
and Arrow segments. It shares the pull executor's ordered row operators and
returns no candidate after an error or cancellation. Its
[step contract](../../../contracts/TABLE_QUERY_V1.md#bounded-resumable-steps)
keeps current authorization, captured source lifetime and atomic publication with
the source owner.

`LogicalInspect` decodes one complete canonical `LogicalArrow` segment into owned
recursive rows and a descriptor. It checks exact schema bytes before interpreting
IPC metadata, then validates physical arrays and complete logical cell semantics.
Its [segment contract](../../../contracts/FUZE_ARROW_V1.md#canonical-segment-decoding)
defines independent input/workspace/row budgets and excludes general external
Arrow import. The result owns all bytes until `deinit`; source authority and
publication evidence remain with the consumer.

`LogicalInspect.infer` recovers the embedded logical descriptor and row count
from a plain canonical segment. A bounded metadata-only reader locates the two
required metadata entries; the logical descriptor and complete canonical schema
are checked before Arrow traverses physical field trees. `segment` also validates
all cells and returns the logical schema fingerprint for delivery consistency.
Neither helper supplies source, authorization or computation evidence.

`TableDml` compiles [typed Table statements](../../../contracts/TABLE_DML_V1.md)
against a supplied name and complete schema. It owns generalized INSERT rows,
constant/default UPDATE assignments and DELETE predicates using stable column
IDs. It performs no source resolution or publication; statement owners retain
authorization, frozen selection, atomic completion and recovery obligations.

`TableSelect` compiles [general Table SELECT](../../../contracts/TABLE_QUERY_V1.md)
over up to 128 logical columns, with typed predicates, aliases, limits and finite
COUNT/checked int64 SUM. It shares typed literals and predicate lowering with
Table DML and row execution with file queries. The supplied schema and source
binding remain the caller's responsibility; compilation does not acquire access.
Non-SELECT input returns `UnsupportedStatement`. Query-side diagnostics validate
Table DDL/DML with the production general grammar before explaining the required
catalog interface; valid implicit INSERT columns and schema lifecycle syntax are
not reported as malformed legacy statements. This presentation check has a
256 KiB scratch bound and never invents a schema or performs catalog reads.

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

`TableDml.compile` produces owned, schema-bound INSERT, UPDATE and DELETE plans
with typed cells, column assignments and predicates. These plans are separate
from read queries. Station's staged Table owner validates the captured basis and
publishes the complete result atomically. See the
[Table mutation contract](../../../contracts/TABLE_DML_V1.md).

`TableSchema` supplies the pure general schema/row model with stable column IDs,
nullable defaults, typed defaults and declared keys. Its owned codec and exact
bounds are documented in [Table schemas](docs/table-schemas.md). Storage and SQL
admission retain their separate profiles.

`TableDdl` compiles general typed CREATE/ALTER/DROP through the shared SQL lexer
and schema model. It owns names, descriptors and typed defaults in an arena;
ALTER/DROP retain the captured object/schema identity. The
[compiler contract](../../../contracts/TABLE_DDL_V1.md) separates these pure
definitions from catalog/native/console admission.

`SqlTyped.literal` captures unbound constructor syntax and source spans before
`SqlLiteral.bind` admits it against a logical descriptor. Bound cells allocate in the caller's
arena and byte values share the parsed syntax lifetime. Nested binding failures identify the
original child or union alternative after parsing has advanced. Direct syntax
callers are bounded to the SQL depth, node and text budgets before cell allocation;
row width, nullability and constraints remain schema responsibilities.

`SqlTyped.Editor` captures bounded cursor expectations from the same Table DDL,
DML and SELECT parsers. Their `compileWithEditor` and `targetWithEditor` entry
points report syntax/name/type context without dispatching work. Catalog callers
supply actual authorized schemas and filter suggestions by the selected execution
profile. These expectations do not establish that an unfinished statement binds
or executes.

`Sql.parseDeclaration` and `Declaration.compile` parse and validate offline
`CREATE KV` and `CREATE DOCUMENT` definitions. Definitions own their names and
format canonical review SQL into a caller-owned buffer. General Table declarations
use `TableDdl.compile` and the shared schema/type rules described above; there is
one Table parser for offline review and catalog publication. Compilation does not
provision resources, publish a catalog or confer authority. The
[state declaration contract](../../../contracts/STATE_DECLARATION_V1.md) defines
KV/Document types, ownership, errors and capability limits.

`Sql.hints` uses the production parser up to a token-boundary cursor and returns
bounded grammar expectations. `SqlInput` frames semicolon termination and
whole-token replacement while respecting quotes, nested comments and UTF-8.
Neither reads a catalog nor executes a statement. Callers filter expectations
against their authorized schema and executable capability profile.

`SqlInput.classify` combines tolerant lexical tokens with roles recorded as the
production parsers consume input. `Sql.classifyTokens` covers finite source,
parameter and inspection syntax; general Table DDL, DML and SELECT use their
unbound syntax parsers. Column/source references retain their original spans
through binding, including predicate and ALTER failures. Keywords, names, aggregate functions, types,
literals, numbers, parameters and comments have distinct presentation roles;
contextual words remain identifiers in name positions. Each semicolon-delimited
statement is classified independently. Type aliases, rich constructors and ALTER
actions are contextual; those same spellings remain identifiers in name positions.
Incomplete or malformed suffixes retain
lexical roles, including unfinished strings, quoted identifiers and comments.
The caller supplies one role per UTF-8 byte within the 4,096-byte input bound;
classification reads no catalog and grants no authority. General Table syntax
uses a fixed 256 KiB workspace without heap allocation. Exhaustion or malformed
input retains consumed roles and lexical classification on the remaining suffix.
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
