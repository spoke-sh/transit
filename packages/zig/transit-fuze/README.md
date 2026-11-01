# transit-fuze

Fuze's Zig-native query library, exported as `transit_fuze`. It runs in callers;
it has no Transit authority, storage, network or deployment dependency.

Fuze executes finite typed filter, projection, limit, count and checked integer
sum over caller-authorized source batches. Aggregates update bounded state
without materializing discarded row projections. It has no storage, credentials or
native authority. No optimizer rewrites are enabled.

`QueryValues` supplies neutral columns, scalar/cell projections, predicates and
plans over the same `Types`, `LogicalJson` and `LogicalQuery` model. It requires
no Station, transport or source acquisition. Exact integer strings, float bits,
five-state cells, collations, validation errors and canonical plan identities
retain their owning contracts. Composite conversions use a caller-owned operation
arena, including cleanup after failure. `columns` allocates a field array but
borrows the supplied names and descriptors; `Plan.native` copies its schema,
output names and structural arrays, but UTF-8 predicate literals borrow the
input. Keep that text alive through plan consumption. Foreign projections detach
their returned values.
Typed JSON parsing keeps the input alive until the parsed result is released.
`NeutralEncoding` owns the shared decimal/hex helpers, including their existing
error names; Query and Station Document adapters re-export that implementation.

`Spatial` exposes the [pure spatial library](../transit-spatial/README.md):
explicit reference descriptors, exact determinant signs and budgeted planar
ring/polygon operations. These local kernels do not add spatial logical values,
SQL functions or maintained spatial plans.

Finite logical plans bind a separate `QueryCollations` value to every input
column. Binary, ASCII case folding and CP037 order apply consistently in scalar
predicates, vector batches and resumable pages. Plan fingerprints and canonical
FQP1 bytes include the vector. Table DML binds it from its exact schema. CREATE
TABLE and ADD COLUMN accept the corresponding `COLLATE` clauses; types and
physical codecs remain independent. ICU, expression overrides and text
relational joins/group/order are unsupported.

`Batch` retains UTF-8 and binary values in 16-byte `StringVector.Value` lanes.
Up to 12 original bytes fit inline; longer values carry a cached collation sort
prefix and a pointer into immutable owner storage. Comparisons use the declared
collation, while projections preserve spelling and trailing spaces. Owned append
copies long payloads and conflict alternatives into the bounded batch arena;
borrowed append requires source payloads to survive until reset/deinit. Views of
inline bytes also expire at reset. Column arrays, state sidecars and selection
arrays start at 64-byte boundaries. Reset and evaluation reuse the reservation.
These are transient implementation details; canonical values and saved plans
retain their existing definitions. `GermanString` is a separate normalized
comparison-key helper and is not a lossless projection representation.

`WorkloadProjection` prepares finite row projections for original Stream/Queue
results. Stable column IDs and explicit partition/offset or claim epoch/attempt
fields form a bounded input layout. Its source basis binds the original native
operation, exact schema and layout; canonical FQP1 plans retain aliases,
predicates and collations and restore without SQL text or name resolution.
Restored plans own their schema, names and literals. Only finite Stream
consumption permits a projection predicate: claim filtering must happen before
lease acquisition, and RETURNING describes every accepted append row. Limits
and aggregates belong to other owners and are refused by this projection.
`Projector` resolves stable IDs once and evaluates decoded rows in fixed input
and output arrays without per-row allocation. It preserves the original claim's
epoch and attempt and leaves native coverage independent of filtered output.
The caller supplies verified frozen metadata and separately owns admission,
selection, authority and completion. The SQL service owns workload admission
and original-result delivery separately.

Dedicated workload parsers can reuse `TableDml.insertValues` for column/VALUES
syntax and `TableDmlPrepared.adoptSyntax` for typed binding. Successful adoption
transfers the parser arena; failure leaves it with the caller. Row and metadata
parameters share type, index and gap checks, and bound rows own their values.
The enclosing parser still owns its verb, suffixes and statement boundary;
these helpers provide no admission or execution authority.

`LogAppendSql.Prepared` uses those helpers for dedicated `PRODUCE` and `ENQUEUE`
syntax, optional partition/producer metadata, Queue visibility and RETURNING.
It owns its source, schema, parameter descriptors and output layout; `bind`
returns independently owned rows and validated metadata. `projection` freezes
RETURNING against the adapter's exact original native binding, with borrowed
fields and caller-owned encoded bytes. The [checked compiler
profile](../../../contracts/sql/README.md) states types, collision refusals and
limits. Preparation performs no Catalog reads, routing, uploads or admission;
the SQL service's Catalog adapter owns those steps.

`LogConsumeSql.Prepared` shares row headers and `LogicalPrepared.adoptSyntax`
for typed projections, predicates, LIMIT and group/wait operands. The bound
plan, input field layout and group name own their memory independently of the
template. Star expands before predicate-only metadata is added to the input.
`WorkloadProjection.schemaLayout` supplies that pure metadata layout without
inventing an accepted operation. This preparation helper has no source capture,
group identity, native wait or offset-settlement authority and is not exposed
by the SQL service. Its LIMIT remains a logical output bound; existing original
workload projection encoding still refuses limits. See the [compiler
profile](../../../contracts/sql/README.md) for exact boundaries.

`TSegReader` reads one host-bound immutable segment through a synchronous range
callback. Opening reads the 64-byte header, 16-byte trailer and bounded footer;
projected decoding requests only the selected column pages. The reader verifies
footer/page commitments, schema interpretation, counts and coordinates before
using them. Its primary-key footer is a sorted resident directory, not a paged
B-tree. The host must verify object identity/range integrity, retain the source
and check current authorization; the reader supplies none of those authorities.

Encoded predicates use `PhysicalCodecs.evaluateColumnPage`, also used by the
Table reader. Dictionary execution validates and evaluates each physical entry
once, then reads cached outcomes by code; collation-equivalent spellings may have
distinct codes. FSST equality, ordering and prefix predicates stream symbol bytes
under binary/ASCII case-folding order without allocating decoded strings. They
still validate every token, decoded length and UTF-8 scalar after a decision is
known. CP037 and complex patterns use the bounded shared decoder. Selected
projection uses that same decoder and preserves raw bytes and conflict details;
unselected corrupt values or details cannot be hidden by filtering. Per-page
counters distinguish streamed and materialized FSST predicate values. No new
codec, dictionary format, SQL `IN` syntax or search index lifecycle is introduced.

`TDel.DeletionVector` stores a segment's deleted row offsets in canonical shared
Roaring containers. A sorted sparse directory selects high-16-bit prefixes;
point reads use validated container views. `initBounded` reserves a sidecar byte
budget once, and mutations and unions perform no heap allocations. The default
budget is 512 KiB; it bounds one artifact rather than the segment's row count.
Capacity refusal preserves the previous vector. Serialized sidecars bind the
segment, row count and current contract definition and carry a SHA-256 digest.

`column` decodes into a caller-owned arena with a separate transient encoded
page buffer. `group` additionally enforces a byte limit on actual arena backing
allocations across the selected columns (64 MiB by default), and returns an
owned `Group` released with `deinit`. Footer and page encoded-byte allowances
are separate from that decoded limit and from result buffers. The segment limit
is 16 MiB. Returned values outlive the reader and source. Callback errors
propagate and partial allocations are released by the owner. Requests are synchronous; cancellation is the host's
responsibility between calls, with no background reads surviving return.

`encodedGroup` owns a projected group's verified encoded pages under a total
encoded-byte allowance, including its page directory. Its `select` method accepts
sorted, unique row ordinals and returns a detached `Group`; `rowIndex` maps source
ordinals to that group's selected cells. Repeated selections use cached encoded
bytes and repeat complete page validation. The decoded allowance covers the
output arena and simultaneously live validation/dictionary scratch. `allocatedBytes`
reports retained output arena blocks; `peakAllocatedBytes` includes transient
scratch at its peak. The encoded owner and decoded results have independent
lifetimes. Footer metadata, allocator overhead and final caller result buffers
are separate from these allowances.

`bufferedGroup` returns a `BufferedGroup` containing verified encoded pages and
column views. Plain int64, uint64, float64, Boolean, UTF-8, binary and JSON use
64-byte-aligned value buffers, with sparse owned error/conflict details. These
columns avoid materializing a cell array. Other plain types retain decoded
metadata and borrowed byte payloads; other codecs retain bounded owned decoding. The total
encoded-page allowance includes the page directory, while the separate decoded
allowance includes live validation scratch and arena growth. Views remain valid
until `BufferedGroup.deinit`, which releases metadata before page buffers; the
reader and source may close earlier. Each column supplies `len` and `cell`;
`Values.cloneValidated` detaches a cell for longer use. Qualified `.plain`
columns also expose `buffers.arrowValues`, which fills a caller's three-entry
buffer directory and returns borrowed Arrow `ArrayData` on little-endian hosts.
It verifies 64-byte address alignment. All non-value states are null in this
nullable value child; the complete column retains state and error/conflict
evidence separately. Both directory and group must outlive every derived Arrow
view. Buffer `retain` does not extend these borrowed lifetimes.

`TSegReader.SharedGroup.init(allocator, group)` transfers a `BufferedGroup` on
success; failure leaves it with the caller. `shared.arrowValues(index)` returns
an owned Arrow `ArrayRef` for a qualified plain column in the projection. It
allocates only the array header and buffer directory and pins the original group.
Slices and `arrow.exportArrayToC` retain that pin; the final release frees the
group, including its state/error/conflict metadata. The original reader and
the caller's shared reference can close first. Every backing allocator must
outlive the final reference, and the host must respect its allocator's thread
discipline when invoking release callbacks. Retaining arrays consumes the host's
memory allowance and does not retain a durable Table lease or access rights.
The C array represents only the nullable value child. Full five-state interchange
uses the logical Arrow schema/sidecars and bounded IPC conversion below; these
value views do not admit arbitrary external Arrow input.

`PhysicalCodecs.decodeColumnPageSelected` accepts sorted, unique row ordinals
and owns only their decoded cells in the output arena. It validates the complete
page, including skipped values and conflict details, using a reusable scratch
workspace. Dictionary entries borrow encoded scalar bytes until selected;
selected repetitions share one owned value. Symbol-table and EBCDIC strings
still require transient expansion for validation. This reduces retained decoded
values without skipping complete-page validation.
`decodeColumnPageBorrowingBytes` uses the same validation with an explicit input
lifetime for plain payloads, including selected nested and conflict values.
Both immutable input and the metadata arena must outlive its cells. Compressed
columns use the owned fallback; unselected rows are still validated.
`Types.Codec.decodeBoundBorrowingBytes` exposes the underlying explicit lifetime:
text, binary and JSON bytes borrow immutable input, recursive arrays belong to
the supplied arena, and `Values.cloneValidated` produces a detached owned cell.

`PhysicalCodecs.evaluateColumnPage` evaluates one `ColumnPredicate` over physical
values, runs or dictionary codes. Its output owns one byte per row, preserving
true, false, unknown, type error and conflict separately. RLE runs and dictionary
entries evaluate once. Binary/ASCII symbol-table comparisons stream validated
bytes; other symbol-table predicates and EBCDIC strings use bounded transient
decoding. The caller keeps the typed literal alive during evaluation and owns
scratch/output allocations. The complete encoded page is validated before
success, including nonmatching values. Comparisons use the column's declared
logical type and binary, ASCII case-insensitive or CP037 collation.

`TableProjection` derives a canonical input-column set from a finite Table plan,
including predicate inputs and all primary-key columns. Its projected schema
preserves stable column descriptors; its private plan remaps positions without
changing output names, collations, LIMIT or source basis. Remapped plans borrow
the caller's bounded workspace until copied into execution. The direct Table
query owner keeps the original plan fingerprint for failure attribution.

`TSegReader.filteredGroup` combines that kernel with verified zone-map pruning
and projected row selection. It validates interpretation and projection before
pruning, reads the predicate column only for candidate groups, then decodes
requested columns only at matching ordinals. No projected payload is read for an
empty selection. Error/conflict counts prevent comparison pruning from hiding
eager failures; `FilterFailure` records the first failing source row/column.
State predicates can select errors/conflicts while retaining their details.
The decoded budget includes outcomes, selection ordinals, output arena and
simultaneously live validation/dictionary scratch. At most one encoded page is
held; projecting the predicate column reads that page again after selection.
Missing/oversized sort keys use the unpruned path. Pruning trusts the bound
footer's statistics and does not verify omitted payloads. Hosts own deletion
visibility, query limits, snapshot retention and final disclosure; direct SQL
uses the retained Table owner's bounded predicate path for finite identity scans.
Relational predicate pushdown remains separate.

Each indexed column group has a fixed 64-bit, two-hash membership filter over
collation sort keys. This is a low-distinct-count optimization, not an adaptive
filter with a target false-positive rate. Duplicate values consume no additional
bits; many distinct values saturate it and retain the bounded predicate-page
fallback. The [selectivity measurement](../../../docs/handbook/reference/performance.md#segment-membership-filter-selectivity)
compares 4, 16, 64 and 256 distinct values with identical row/page sizes. Row-group
size alone does not determine selectivity. Missing bounds disable pruning, and
the filter never authorizes skipping a possible source error.

`filteredCandidates` applies the same program to at most 1,024 unique physical
row ordinals supplied in the owner's logical traversal order. The owner supplies
only rows visible in its retained directory. An optional match limit stops
semantic evaluation at that prefix; omitted or later rows cannot win an operator
failure. Encoded pages still undergo complete integrity and value validation.
The result reports how many supplied candidates were examined, including misses,
and owns matching cells indexed by sorted physical ordinal. `Group.rowIndex`
lets the owner restore its original traversal order. Examined candidates do not
establish complete-source coverage. This component supplies no snapshot,
visibility, authorization or SQL execution authority.

`TSegReader.decisions` retains a bounded group of filter decisions so an owner
can visit physical rows in a different logical order without repeating encoded
predicate evaluation. Each row records selection or its first semantic failure
and original instruction/column. False and unknown are both non-selections;
pruned groups do not claim exact three-valued truth. Structural and requested-page
integrity failures still fail the read immediately. Decisions own no source
cells or borrowed literals. The host binds cached decisions to its exact plan
and group, selects live identities, and discloses failures only when visiting
those identities. Outcome vectors, scratch and retained decisions share the
supplied decoded allocation budget.

`filteredProgram` accepts a `ColumnPredicate.Program` with at most 64 postfix
instructions across the declared columns. It evaluates all atoms, then uses the
shared Boolean machine to preserve eager row/instruction failure order.
Conservative zone-map truth sets retain unknown values under NOT/AND/OR; any
possible eager error prevents pruning. Each atom's outcome vector shares the
decoded budget, and only one encoded page is live. Repeated atoms can read the
same column again. `Program.fromLogical` and `Program.fromPlan` retain atom and instruction order while
borrowing literals into caller-supplied instruction storage. The host binds its
exact Table interpretation; this conversion creates no saved plan or new wire
identity. Plain decoded `Program.truth` and encoded evaluation use the same
declared collation and Boolean semantics.

`AuthorizationSql.compile` parses the selected role, membership, privilege,
default-privilege, schema and ownership statements into unresolved typed syntax.
Its owned arena is released with `deinit`. Names are bounded to 63 UTF-8 bytes;
one statement, target and grantee are admitted at a time. PUBLIC delegation,
column privileges, passwords, superuser attributes and unsupported forms reject.
Catalog and native administration must resolve and authorize this syntax before
execution; the parser itself reads no policy and changes no authority.

`Relational` supplies pure admission, stable column resolution, output descriptors
and prepared/bound identities for finite int64/UTF-8 Table join/group plans. It also
defines distinct join/group NULL rules and checked aggregate steps.
`RelationalSql` lowers the selected finite SQL profile through shared syntax and
typed literals. `RelationalExecution` advances ordered source rows and externally
stored groups with bounded resident state, preserving bag multiplicity, null
extension and first-error order. Hosts own source capture, current permission,
spill and complete-result publication. The
[relational contract](../../../contracts/RELATIONAL_V1.md) defines capabilities,
ownership, canonical order, budgets and remaining integration obligations.
`RelationalIndex` supplies immutable group roots and bounded copy-on-write
updates. Its traversal stack holds references and directions, reloading verified
immutable parents during an update instead of retaining their payloads across
tree depth. The host charges those additional reads to its work budget; read or
write failure preserves the original root. `RelationalCheckpoint` encodes exact operator progress; execution restore
rechecks the bound source vector and current rights through its adapter. Hosts
stage and atomically publish these records with input/output progress. Source
rows, group keys, returned outputs and decoded records own their text buffers;
move them or clone through the bounded host allocator and release with `deinit`.
`checkpoint()` borrows the executor until its next mutation; `restore` copies it.
Group equality, order and exchange routing share the declared column collation.
Each row/key/cell vector permits at most 1 MiB of text, with actual payloads
charged to the host's resident budget.
`RelationalExchange` specifies canonical collation-aware int64/UTF-8/null routing and source-qualified
row segments with exact bound identities and explicit terminal coverage. Hosts
own durable acceptance, credits and current authorization under the
[exchange contract](../../../contracts/RELATIONAL_EXCHANGE_V1.md).

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
Descriptor `decodeInto`/`cloneInto`, neutral-value and `TableRow` `decodeInto`,
bound-value `decodeBoundInto` and logical-plan `decodeInto` also compose within a
caller-owned request arena. Neutral-value and row decoding copy input bytes;
their scratch can be reset between rows once retained outputs have detached.
The enclosing owner
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

`Batch` and `BatchExecution` provide owned typed columns, eagerly bound programs,
ordered aggregates and guarded AVX2 comparisons for file and Table execution.
Logical/Unified pages and relational predicates share their kernels. The
[batch guide](docs/batches.md) defines compute limits, lifetimes, host worker
configuration and the unchanged source/recovery boundaries.

`LogicalPlanCodec` owns canonical `FQP1` serialization of these plans under an
exact supplied schema and source binding. Decode rejects foreign definitions and
stale bindings before reading dependent literals, then returns an independently
owned plan. The [Table query contract](../../../contracts/TABLE_QUERY_V1.md#canonical-logical-plans)
defines its byte budget, field layout and separation from query admission.

`LogicalPrepared.adoptSyntax` lets dedicated workload parsers reuse the same
typed projection/predicate binder and parameter checks. Metadata operands share
its type and index space. Success transfers the parser arena; failure leaves
cleanup with the caller. Bound FQP1 plans own their values independently of the
template and metadata. The workload owner separately freezes metadata in its
native operation; this compiler helper grants no admission or coverage.

`LogicalPrepared` owns general logical SELECT templates with typed comparison
and LIMIT parameters, including Boolean predicates and recursive projections.
Binding checks the complete source/schema commitment and returns independent
canonical logical plans. Parameters retain exact integer/decimal/temporal values;
unsupported comparisons stay unsupported. Input and plan budgets apply before a
bound result is returned. See the [parameter contract](../../../contracts/SQL_PARAMETERS_V1.md#general-logical-template-compiler)
for scope, ownership and the separate caller-integration boundary.

`TableDmlPrepared` owns typed INSERT/UPDATE/DELETE templates. Its binder preserves
NULL versus DEFAULT and returns independent canonical intents. The shared lexer
has explicit Transit `$n` and MySQL positional `?` profiles; values never become
SQL text. Logical SELECT and DML bindings accept SQL NULL with three-valued
comparison semantics. See [Table preparation](../../../contracts/SQL_PARAMETERS_V1.md#catalog-table-preparation)
for bounds and the catalog owners' current-identity checks.

`TableDdl.compileDialect` and `RelationalSql.parseDialect` use the same explicit
lexer dialect. MySQL accepts escaped backtick names, ANSI double-quoted names and
literal backslashes in SQL strings. DDL and relational plans admit literals only;
neither interface enables identifier parameters or parameterized relational SQL.

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

`LogDdl` compiles Stream/Queue declarations and the named `SHOW`/`DESCRIBE`
syntax shared with the SQL service. Policy binding uses an explicit schema and
captured configuration. Catalog lookup, destination resolution, authorization
and publication remain outside this pure parser.

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
The [query reference](../../../docs/handbook/reference/queries.md) describes interactive
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
measured limits. [Tables](../../../docs/handbook/reference/tables.md) owns transaction and result
semantics; [Arrow](../../../docs/handbook/reference/arrow.md) owns Arrow interchange.

`SqlDiagnostic.structured()` projects the compiler's original binding context into
the shared [diagnostic value](../../../contracts/DIAGNOSTICS_V1.md): stable SQL
codes, source coordinates, expected/actual types, parameter sites and typed
correction actions. It does not perform additional catalog reads. Human console
hints remain a separate presentation; structured actions contain no dot commands.


`MemoryBudget` accounts concurrent requested backing bytes for query and storage
workspaces, including arena growth slack. Successful free/shrink operations
release capacity; failed growth leaves accounting unchanged. Callers own the
budget's stable lifetime and map exhaustion at their domain boundary. The finite
relational owner and Table compaction share this allocator; reader caches and
provider buffers keep their separately declared bounds.

`DecimalArithmetic` evaluates validated `DECIMAL(p,s)` coefficients with
`p <= 38` and `s <= p`. Addition promotes to the larger input scale;
multiplication, division and rescaling use an explicit output precision, scale
and rounding rule (`reject`, `half_even`, or `toward_zero`). Fixed 512-bit
intermediates cover every admitted input/scale combination without allocation.
An unrepresentable output returns `DecimalOverflow`; discarded nonzero digits
under `reject` return `InexactDecimalRounding`. These scalar helpers do not
extend SQL arithmetic or stored schema descriptors.

`Timezone.Database` loads a sorted, immutable set of named TZif files and hashes
both their complete bytes and the version label. Conversion requires the exact
`Timezone.Version` content identity supplied by the caller. It never reads host
timezone files or substitutes rules based on a version string. Loading validates
TZif 2/3/4 without leap seconds; each file is bounded to 128 KiB. UTC conversion
uses the recorded transitions and returns `TimezoneCoverageUnavailable` beyond
the last explicit transition; POSIX-footer extrapolation is unsupported. Fixed
zones with one local-time type and no transitions require an empty footer or
a matching fixed-offset POSIX footer; an unsupported DST footer cannot establish
fixed coverage. Missing names,
foreign content identities and timestamp overflow reject explicitly. These
helpers do not add SQL `AT TIME ZONE` syntax.

`Collation.Profile.ebcdic_037_pad` compares UTF-8 strings in CP037 order with
virtual space padding of the shorter operand, including control characters
below CP037 space. Its sort keys omit trailing spaces and encode non-space
symbols with their preceding space-run length; each non-space symbol uses ten
bytes plus one final terminator. The caller supplies the bounded key buffer.
This helper and `ebcdic_1047_nopad` are separate from the currently admitted
TableSchema/SQL collation tags.

`StandardsLedger` exposes the generated projection of
[`standards-ledger.json`](../../../contracts/sql/standards-ledger.json).
Its states describe public entry points. `OperatorTraits` derives effects,
fallibility, five-state filtering, collation counts and work bounds from validated
logical/relational plans; direct Table EXPLAIN returns these traits without data
acquisition. Maintained relational execution reports finite recomputation with
paired deltas, not incremental Z-set execution.
