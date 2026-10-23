# Relational semantics v1

Fuze's [Relational module](../packages/zig/transit-fuze/src/Relational.zig)
supplies pure typed-plan validation, stable column resolution, output descriptors,
prepared/bound fingerprints and scalar null/count/sum rules. Slices borrow
immutable caller storage. Operations allocate no heap memory and acquire no
source, permission, storage, clock or I/O.

`RelationalSql` lowers finite SELECT into these same definitions through the
shared lexer, identifiers, literals and predicate grammar. `RelationalExecution`
executes over supplied ordered sources and external group storage. The query
package's `RelationalQuery` owns interactive native-resource cuts;
`DirectRelationalQuery` owns local traversal over retained direct Table pins.
Both validate current rights and use
bounded allocation and private disk grouping. The query owners below compose
these operators with captured jobs and maintained revisions. Foreign-language
ABI admission remains separately defined. The small finite interpreter under `tests/` supplies an
independent specification oracle.

## Plans and capabilities

Plans contain one or two explicit Table sources in one realm. Two sources require
one inner or left equijoin from source 0 to source 1. Each source includes alias,
realm, resource, catalog, owner and complete immutable Table schema. Aliases are
unique. Object identity includes resource and catalog scope. Aliases of one
resource share its owner; aliases of one object share its schema.
Name resolution uses supplied normalized names only; unknown qualifiers,
unknown columns and ambiguous unqualified columns reject without discovery.

Columns use source/alias ordinal and stable column ID. Renames preserve IDs but
change schema/prepared commitments. DROP/recreate cannot redirect old work.
Rows use Table `(origin, operation, ordinal)` identity, independent of primary
keys; keyless and composite-key Tables use the same relational model.

Referenced projection, join, grouping, predicate and SUM columns must be int64.
SQL declares these columns with BIGINT; INTEGER denotes int32.
COUNT(*) and COUNT(int64-column) return uint64; SUM returns nullable int64.
Unreferenced columns may use other valid stored types. Left joins make right
projections nullable, including originally NOT NULL columns. Output names are
explicit and unique. Storage support does not widen operator admission.

| Dimension | Limit |
| --- | --- |
| Sources / joins | 1–2 / zero for one source, one for two |
| Outputs / group columns | 1–128 / 0–128 |
| Each source-local or joined predicate | 0–64 postfix instructions |
| Names | 1–255 UTF-8 bytes, no NUL; 4096 output-name bytes total |
| Prepared identity preimage | 8192 bytes |

Table schemas retain their descriptor/default/key bounds. These limits bound
plans, not retained collections. Budgets explicitly declare resident, spill and
result bytes, output rows, work steps and source pins. Resident/result/work must
be positive. Zero spill forbids spilling; zero output rows allows only empty
results. Pins cover every distinct atomic source domain, at most two. Actual resource
enforcement belongs to the execution owner. Capacity pressure cannot truncate answers,
discard accepted work or expire data.

## Evaluation and canonical order

Logical stages are source row validation, source-local filtering, join, joined
filtering, grouped/ungrouped aggregation and projection. Local filters reference
only their source. Predicates are eager postfix comparisons, state tests, NOT,
AND and OR using three-valued logic: NULL comparison is unknown and only true
selects. IS NULL/IS NOT NULL are exact tests. Native integration must define and
preserve validation-page/error precedence independently of execution batches.

The finite executor advances at most one ordered source row and one group update
per step. Its initial join strategy rescans the frozen right input for each
selected left row, preserving canonical order without buffering a relation.
Group updates process all aggregates provisionally before storing the group.
Group output starts only after input completion and sorts by the entire key
tuple. The host validates every dependency before disclosure and completion,
including empty or fully filtered inputs. A failed execution is terminal.

The interactive owner uses an AVL index in an exclusively created, immediately
unlinked disk file. It holds fixed record buffers and a bounded index path, with
no in-memory array of retained groups. Disk quotas count retained records;
separate spill-work limits count every record read/write. Cancellation, quota,
short reads, digest failure or I/O failure poison the execution. Private spill
is not a durable checkpoint and is released on process termination. The owner
accounts all query heap allocations and reserves its bounded working frames;
the supplied native Client owns its separate transport memory.

SQL admits explicit columns and multiple COUNT/SUM expressions, AS output names,
one optional INNER/LEFT [OUTER] JOIN with one column equality, WHERE predicates
and GROUP BY columns. `RelationalSql.parse` owns its syntax; `bind` borrows the
acquired immutable Table descriptors. Source-local filters are typed-plan fields;
SQL WHERE lowers after the join. No parameter substitution or implicit coercion
is added. Unsupported LIMIT/HAVING/ORDER BY/DISTINCT and additional joins reject.

Canonical source order for this new profile is lexicographic Table row identity
order (`TableRow.Identity.encode`). Join order is left identity then right
identity. Existing single-source query ordering is unchanged. Joined identity is
the pair of source-qualified row identities; an unmatched right side has an
explicit absent marker. Unmatched emission requires complete right coverage.

Equal non-null int64 keys join; NULL never joins NULL. Bag multiplicity is
preserved: two matching left rows and three right rows produce six pairs.
Joined filtering happens after null extension; moving a right filter across a
left join is not generally equivalent.

Grouping treats NULL keys as equal and sorts them before int64 values. Output
groups sort lexicographically by declared key tuple; contributors retain input
order. Every non-aggregate output in an aggregate/grouped query must be a group
key. Grouping without aggregates emits one row per distinct tuple.

Aggregates advance in contributor order, then output-list order per contributor.
The first arithmetic failure wins across groups; sorting groups cannot reorder
failures. COUNT(*) includes null-extended rows; COUNT(column) excludes NULL. Both
use checked uint64 counts. SUM skips NULL and checks each int64 addition.
`[MAX_I64, 1, -1]` fails on its second contributor; partition totals cannot replace
ordered addition. Empty ungrouped aggregation returns one row with zero counts
and NULL SUM; grouped empty input returns none. All-null SUM returns NULL.

`AggregateState.observe` preserves its state on overflow. Each instance belongs
to one aggregate; hosts must discard an entire provisional step when a later
aggregate fails. Scalar rollback is not atomic result publication. The independent
oracle receives validated rows and does not qualify native page-error precedence.

LIMIT, HAVING, arbitrary ORDER BY, DISTINCT, additional/multiple joins, implicit
coercion, richer aggregates, windows, recursion and file/KV/Document or cross-realm
joins have no representation in this profile.

## Source basis and lifetime

Prepared identity includes aliases, routing, full schema fingerprints (including
names/defaults/keys), operators, outputs, predicates, lifetime and all budgets.
Bound identity additionally includes one cut per alias in source order. Each
cut has a mandatory domain, resource/revision, nonzero opaque root commitment
and full schema hash. The domain is `native_resource` or `table_partition` with
branch/object/partition identities. A direct Table revision is its accepted next
LSN, not a native resource revision. Missing domains/cuts and resource/schema
mismatches reject. Native aliases in one resource share its cut; direct aliases
of one Table share its pin. Different direct Tables retain independent cuts even
within one resource. Mixing domain kinds for one resource or aliasing a partition
to a different object rejects. Prepared direct bindings must match each retained
interpretation, including definition changes that preserve the column schema.

An adapter must authenticate and retain the root and validate the schema at that
cut. Nonzero hashes alone establish neither authenticity nor retention. Capture
all cuts and seal the vector before execution; partial failure releases all
acquired pins. Different resources may be captured at different moments. This
is not an atomic or causal cross-resource snapshot; atomic-snapshot requests reject.

Interactive, captured and maintained lifetimes have different prepared identities. Interactive
execution requires live leases, cancellation and cleanup. Captured execution must
retain exact inputs and original durable call through recovery. Missing historical
input fails rather than becoming a newer cut. The local Bound type performs none
of these lifecycle operations.

## Canonical identity preimages

Domain: `transit.fuze.relational.v1.2026-10-11`. Strings have one-byte byte-length
prefixes; integers are little endian. SHA-256 hashes the following prepared bytes:

1. Domain, NUL, `prepared`, NUL, one-byte source count.
2. Per source: alias, uint64 realm/resource/catalog/owner, 32-byte schema hash.
3. Join tag (none 0, inner 1, left 2), followed by two columns when present.
   A column is one-byte source ordinal and uint64 stable column ID.
4. Each source predicate, then joined predicate: one-byte instruction count,
   then instructions. Tags are compare 0, is-null 1, is-not-null 2, negate 3,
   conjunction 4, disjunction 5. Compare carries column, one-byte comparison
   (equal 0, not-equal 1, less 2, less-equal 3, greater 4, greater-equal 5), int64
   literal. State tests carry a column; Boolean operators have no payload.
5. One-byte group count and columns; one-byte output count, then output names
   and expression tags (column 0, count-all 1, count-column 2, sum 3). Expressions
   other than count-all carry a column.
6. Lifetime byte (interactive 0, captured 1, maintained 2), uint64 resident/spill/result bytes,
   output rows and work steps, then one-byte pin capacity.

Bound bytes are the hash domain, NUL, `bound`, NUL, prepared hash, then each
cut's atomic-domain tag (native resource=0, Table partition=1). A Table tag adds
little-endian uint64 branch/object/partition. Both tags then append uint64
resource/revision and 32-byte root/schema commitments.

`RelationalCodec` owns the canonical `FRP1` plan artifact. It contains the four
magic bytes, the 32-byte shared native definition, a one-byte source count, each
complete Table schema prefixed by its uint32 byte length, and the prepared
preimage prefixed by its uint16 byte length. Decoding checks both definitions,
every schema fingerprint, all admission constraints, complete consumption and
canonical re-encoding. Decoded schemas, aliases and names belong to the returned
owner; no current-name resolution or default compatibility assumption occurs.
Its maximum is 39 + 2 × (4 + 65536) + 8192 bytes. This artifact serializes a
prepared definition, not source pins, accepted job identity or completion.
The shared native definition changes with incompatible stored/wire semantics;
older saved artifacts reject rather than being rebound to current data.

## Immutable operator records and checkpoints

`RelationalIndex` stores groups in an immutable AVL tree. An update copies a
bounded search path and any rotated nodes, assigning fresh monotone record IDs.
The previous root remains readable after a failed candidate write. Resident
frames and candidate records depend on the 94-frame traversal bound, not the
number of durable groups. A host budgets all retained record bytes, including
old roots and unreachable staging records, separately from its active staging
reservation. Neither this index nor pressure on that budget expires history.

A reference contains uint64 record ID, uint32 byte length, 32-byte SHA-256 of the
record, uint8 height and uint64 entry count. Optional references use a Boolean
byte followed by that payload only when present. `FRN1` nodes contain magic,
32-byte shared native definition, 32-byte bound fingerprint, optional left/right
references, one-byte group/output counts, nullable int64 keys, then per-output
uint64 row/value counts and nullable int64 sum. Nullable integers always occupy
nine bytes: Boolean presence and little-endian int64, zero when absent. Child IDs
precede their parent; lengths, integrity, binding, balance, height, subtree count
and aggregate-state shape are checked when read. All integer fields are little
endian. Hosts stage candidates privately; a node record's existence is not a
published operator root.

`RelationalCheckpoint` contains one exact root and execution cursor. Its `FRC1`
encoding has magic, shared native definition, bound fingerprint, optional root,
phase byte (input 1, empty-right coverage 2, grouped output 3, complete 4, failed
5), optional left/right continuation row identities, optional retained left row,
matched and right-covered Booleans, uint64 group/work/result-row/result-byte
counts, optional last output group and optional failure witness. Optional
identities have a Boolean prefix and the Table's 20-byte stable identity. A
retained row contains its identity and one nullable int64 per schema column;
unreferenced non-int64 columns remain null. Group keys have the prepared number
of nullable int64 cells. A failure records left identity, optional right identity,
one-byte output ordinal and group key. Decoders reject noncanonical Booleans,
truncation, trailing bytes, wrong definitions/bindings and inconsistent progress.
The record fits an 8192-byte caller-owned buffer; it is not a native inline value.

`RelationalExecution.checkpoint` and `restore` preserve the join cursor, match
state, output position, counters and canonical failure witness. Restoring requires
current source validation and the exact immutable group root. Hosts must publish
the checkpoint, input progress and output coverage atomically; decoding a record
does not establish that transaction or authorize reading retained inputs.

The query package's `RelationalState` stages these records through Station
Publication with one active record reservation and bounded candidate memory.
Group records use format `0x314e5246`; checkpoints use `0x31435246`. Reconstructed
candidates retain their reserved IDs and bytes; conflicting reuse rejects. The
host owns accepted allocation counters, continuation identity, retained source
versions, cancellation and cleanup. These storage primitives do not themselves
admit a durable query request or publish a complete result manifest; the captured
owner operations below compose them with source retention and current policy.

## Disclosure and completion obligations

Execution and each bounded disclosure/publication require current rights to
every transitive source, including inputs producing no matches. A derived-result
grant, source pin or checkpoint cannot replace source permission.

Completion requires source/partition coverage, result schema, ordered output
coverage and terminal validation. Empty inputs also need completion evidence.
Arithmetic, authority, storage, allocation and budget failures leave any returned
prefix incomplete. Fuze owns deterministic semantics; query/Station and authorized
hosts own capture, I/O, spill, atomic publication and recovery.

Exchanges and reassignment require their own lifecycle contracts. Table
invalidation watches are not complete changelogs.
Neither runtime nor distributed qualification follows from the local contract.

## Captured Table owner operations

`transit-query.RelationalBundle` (`RQB1`, publication format `0x31425152`)
contains the shared definition, explicit independent-Table-vector tag 2, one-byte
source count, uint32-length-prefixed `FRP1`, an authorization-presence byte,
the 185-byte [original caller proof](UNIFIED_QUERY_V1.md#larger-requests-and-durable-publication)
when present, a one-byte direct-grant count, that many 310-byte `TRG1` grants,
and one uint32-length-prefixed `TQS1` declaration per source. Descriptions have
zero grants; authorized bundles require one grant per source. Same-Table aliases
repeat exactly the same grant and immutable declaration. Physical schema
fingerprints, stable columns and logical row types must all match.

The native proof covers the bundle with only its native authorization omitted,
including every signed direct grant. Each direct grant's purpose hashes domain
`transit.query.relational.direct-retention.v1`, NUL, four little-endian uint64
identities (worker PID, computation resource, requester PID, request resource),
then the bundle with both native authorization and direct grants omitted. The
grant fixes the executor principal, original caller/role/credential epoch, exact
Table interpretation/frontier and pin owner. Aliases share one pin; distinct
Tables consume separate `source_pins`, even within one catalog. The complete
bundle fingerprint uses domain `transit.query.relational.request.v1`, NUL,
then the complete encoded bytes.

`RelationalCapture` admits an authenticated Station call whose payload is the
request's Publication reference. A committed coordinator policy constrains the
calling PID, request resource, exact bundle fingerprint, original principal and
policy revision. Its native computation resource is independent of the source
catalog resources. The host registers the request view and supplies one configured
direct executor route per source. Those routes use the executor's own key;
ordinary executor Table privileges do not substitute for the caller's grant.

Admission commits the job, peer/correlation index and Publication budget, retains
the request's native version and schedules a continuation. It checks current
CONNECT, schema USAGE and Table SELECT for all sources, including empty inputs.
For each distinct Table, a later native turn commits pin eligibility before any
direct acquisition. Acquisition preserves the original signed grant and frontier,
then records the immutable handle, interpretation and native authority references.
After every handle is committed, one vector commits before traversal begins.
This is an independent vector, without catalog-wide or cross-owner atomicity.

Recovery reads the request through its original native version and the original
Table pins. It never reparses SQL or replaces a stale cut with a fresh one.
Continuations recheck coordinator policy and original caller authority. Every
native progress/result commit carries the retained Tables' exact authority
requirements, including their resource-lifetime prerequisites. Result disclosure
uses a separate fresh subject and these same retained authority objects without
reopening released source pins.

One executor step constructs a bounded candidate map and checkpoint. Immutable
node, output and checkpoint staging retains exact reserved IDs and bytes across
continuations. Only a turn in which these records are already complete advances
the accepted checkpoint/allocation counters and output index. A completed job
also binds its source vector, final checkpoint and complete output digest chain
in a manifest. Lost native responses belong to the host's existing saved pending
operation/receipt protocol; reconstructing operator candidates does not authorize
replacing an uncertain native proposal.

The owner receives a caller-owned allocation workspace. Its length plus the
published `resident_base` must fit the plan's resident budget. The workspace
contains decoded descriptors, source adapters and the bounded node candidate.
A continuation performs at most one source-row read and a tree-height-bounded
index operation. `spill_bytes` bounds retained logical node/checkpoint/output/
manifest bytes, including older roots; Publication separately reserves one active
record of at most 8192 bytes. A terminal semantic failure has one additional
bounded checkpoint reserve, at most 8192 bytes, to record its original witness
when ordinary state capacity is exhausted. This reserve neither permits further
query execution nor deletes accepted state. Physical storage failure can still
prevent the native turn from committing.

`close` records cancellation, denial, failure or explicit result retirement and
releases the native request version once. It schedules direct cleanup from the
computation-owned pin records without reading the request body or source rows.
Completion also schedules pin cleanup. A cleanup input commits one closing or
settled pin transition; lost replies repeat the original operation. Current
denial leaves cleanup pending. An authenticated host can call `retryCleanup`, or
supply a separately signed fresh closure through `authorizeCleanup` after caller
credential rotation. That proof cannot resume execution or replace its attribution.
A job closed before pin eligibility has no pin to acquire during cleanup.

Application handlers authenticate cancellation, retirement and cleanup controls.
A native read failure poisons the current turn; the host must settle any pending
request and prepare a fresh proposal. Direct cleanup never changes a complete
manifest or terminal failure. Native publication collection and physical storage
cleanup remain separate operations.

`collect` requires a released, closed job and an empty mutation proposal. It
examines one immutable descriptor or removes at most two chunks per turn. The
job's collection cursor is zero before collection, a record ID while advancing,
and UINT64_MAX after complete coverage. Records are staged in contiguous ID
order, so collection includes abandoned private candidates beyond `next_record`
and ends at the first absent descriptor at or above it. A missing descriptor
below `next_record` rejects. Publication descriptors keep their own chunk cursor
when collection uses all four native mutations. Permanent descriptors and
job/vector/output-index records remain. Failed/denied jobs preserve their last
bounded checkpoint for diagnostic evidence; other closed jobs collect all their
operator/output/manifest chunks. Request publication cleanup remains with its
publisher. This does not authorize expiry of active or complete results.

### Retained historical source records

`RelationalHistoryRecord` encodes a complete direct source in one 246-byte
`QHB1` native value. It is a source-evidence codec; encoding it does not acquire a
lease or advance a maintained query. After magic and the mandatory shared
32-byte definition, fields are: one history-presence byte; lease content length
and SHA-256; Table partition and exclusive frontier; 32-byte acceptance-record
commitment; interpretation revision and digest; declaration byte length;
schema fingerprint; retirement byte; logical-change frontier; row count; and
native database/schema/Table authority IDs. Integers are uint64 little-endian;
Boolean bytes are exactly zero or one. Object identity comes from the validated
Table source, pin-owner identity from its signed grant, and the declaration
content digest equals the interpretation digest.

A history record requires a history grant and a nonzero record commitment.
A captured snapshot requires a snapshot grant and zero commitment bytes. Every
record preserves its actual lease content, authority references and full-width
Table coordinates. Historical positions cannot precede the grant's original
frontier; the original position also requires its exact original interpretation.
Subsequent definition/schema changes remain explicit evidence for the consuming
computation to evaluate. Truncated, foreign-definition, noncanonical or
scope-inconsistent values reject. The source fingerprint hashes
`transit.query.retained-history-source.v1`, NUL, the complete
`DirectTableReader.Basis` fingerprint, a presence byte and the optional record
commitment. Accepted no-op revisions therefore retain distinct identities even
when their logical-change frontier is equal.

### Captured record encodings

All records below use their four-byte magic and the 32-byte shared native
definition. Fields are little endian unless noted; native values are bounded by
256 bytes. Definitions are mandatory and are never inferred from missing fields.

- `RQA1`: uint64 peer, request resource, catalog principal and policy revision;
  32-byte complete bundle fingerprint; Boolean allow.
- `RQV1`: 32-byte bundle fingerprint; one-byte source count; for each source,
  uint64 Table partition, uint64 exclusive accepted frontier and 32-byte full
  `DirectTableReader.Basis` fingerprint. Same-Table aliases repeat the same entry.
  Bound cuts use the Table-partition domain and the declaration's branch/object;
  no native resource revision stands in for a Table position. Full source and
  authority evidence remains in the computation's `QTP1`/`QTH1` pin records.
- `RQJ1`: uint64 job ID, destination, correlation, policy revision, checkpoint ID,
  next record ID, retained bytes, continuation input, output count, encoded output
  bytes, manifest ID and collection cursor; 72-byte request reference; retained
  request version; phase byte; 32-byte output chain; Boolean native-request-released;
  one capture byte (source count in bits 0–1, acquired alias count in bits 2–3,
  upper bits zero). Phases are capturing 1, complete 2, failed 3, cancelled 4,
  denied 5, retired 6, admitted 7 and acquiring 8. The record occupies 256 bytes.
  Admitted/acquiring work cannot expose checkpoints or outputs; traversal requires
  all sources. Final manifest identity fixes continuation to the original job ID.
- `RQS1`: uint64 output ordinal and 72-byte immutable output reference. The initial
  output chain is SHA-256 of `transit.query.relational.outputs.v1`, NUL; each next
  chain is SHA-256 of previous chain followed by complete `RQS1` bytes.
- `RQF1`: one-byte-length-prefixed original cause and public diagnostic code,
  followed by the Diagnostic category ordinal. The failed checkpoint retains the
  contributor/output/group witness when one was observed. Unclassified
  infrastructure failures remain failed attempts rather than invented outcomes.
- `RQM1`, publication format `0x314d5152`: uint16-length-prefixed complete `RQJ1`,
  uint16-length-prefixed `RQV1`, and the final checkpoint's 72-byte publication
  reference. It fits 1024 bytes; referenced records carry their own definitions,
  commitments and complete-coverage checks.

`FRO1` output records use format `0x314f5246`. After magic and definition they
contain the 32-byte bound fingerprint, uint64 ordinal and identity tag: pair 0
or group 1. A pair has a 20-byte left row identity, Boolean right presence and
optional 20-byte right identity. A group has one-byte width and nullable int64
keys. One-byte output width precedes cells, each a Boolean presence and eight
integer bytes; absent values encode zero. The output schema determines int64
versus uint64 interpretation. Nullability, identity kind, referenced type, width,
ordinal, trailing bytes and canonical representation are validated.

### Reading captured results

`RelationalResult` accepts the caller's frozen bundle and explicit coordinator,
peer, resource, job and native-request budget, plus a separate
[result-disclosure subject](UNIFIED_QUERY_V1.md#larger-requests-and-durable-publication).
The selection binds the unchanged bundle fingerprint and all these options.
Current privileges are evaluated for this reader; the stored query keeps its
original execution attribution. It opens a fresh leased snapshot
of the result resource and verifies the complete job, manifest, checkpoint,
request identity and source vector. Its final combined native reads check the
job, coordinator policy and every source catalog policy at one authority root,
including empty and noncontributing sources. The immutable pin records bind
source interpretations, grants, full cut commitments and native authority IDs.
Source resources need no raw native reads. A result-resource grant does not
satisfy the source authority requirements.

Iteration returns one owned scalar row at a time. The reader verifies each
publication, output ordinal, pair/group order, encoded bytes, canonical result
bytes and digest-chain coverage. A prefix is incomplete until terminal validation
succeeds. Current denial, retirement, missing/corrupt records, exhausted request
budgets and incomplete coverage reject. Closing the iterator closes its lease;
it does not cancel the durable job or retire the result. Replay of its terminal
iterator state returns no further data; a new result read opens and authenticates
a fresh snapshot.

The generic single-source `UnifiedClient` protocol, existing foreign-language
ports, console and Flight routes have their own admitted profiles; the captured
owner operations above do not implicitly enable those transports for relational
plans. The maintained owner below uses a separate activation and revision ledger.


## Maintained Table owner operations

`RelationalMaintenance` admits a bundle with lifetime `maintained`. The same
explicit source routes, scalar types, ordering, budget and current policy rules
apply. Activation is an authenticated Station call; its peer/correlation names
one permanent admission. Query progress and the request publication use their
own native resource; the coordinator need not own a source Table or its catalog.
An authorized host installs its exact `RQA1` request policy and invokes `start`
with explicit direct clients for the sources. The admission turn replies with
its original `RMH1` record, settling the activation call; this reply is not a
complete result. SQL compilation or an editor change does not activate it.

Admission retains the original request publication and creates its private
Publication namespace. Later bounded turns commit acquisition eligibility,
acquire each exact history lease through the signed direct service, and commit
its immutable handle. Same-Table aliases share that lease. The owner records
the complete initial vector only after all handles are committed. Lost replies
retry the original operation; replacement cannot select a later cut. Direct
history reads include accepted unflushed rows and enforce the original caller's
current rights. Native publication commits also fence those rights. History or
page loss is a failure, never permission to substitute the latest Table.

A basis records the complete direct source interpretation, immutable lease,
accepted Table frontier and WAL commitment. Same-Table aliases carry identical
records. Distinct Tables remain independent even within one catalog. The owner
captures a fixed upper bound for each Table, then chooses an eligible Table
using its persisted round-robin preference. Bounded traversal through physical
storage records persists a separate cursor before continuation. A selected
logical acceptance advances only that Table's aliases; its full source vector
commits before computation. Each logical acceptance produces one revision,
including an accepted no-op. Admission, flush and other storage-only records do
not fabricate revisions. There is no implied catalog-wide or global transaction.

The first basis remains frozen through backfill while later transactions stay
in Table history. The implementation recomputes each complete basis through the
same canonical finite executor and immutable paged group index. It then merges
the previous and new ordered outputs using at most one row from each side.
Equal identities and equal cells produce no delta; changed cells produce one
paired update. Insertions/deletions preserve stable pair/group identity. An
output ordinal change alone is not a logical row change. First/last outer
matches may remove one identity and insert others in the same complete delta
transaction. This implementation does not reuse unaffected groups or claim
incremental computational cost.

Private stages and checkpoints span bounded native turns. Mutable work records
carry output/delta cursors, counts, chains and allocation accounting; the old
complete root stays visible. A final conditional turn binds one immutable
manifest, final checkpoint, source vector, complete outputs and complete delta
coverage, advances the root, and consumes the input together. Accepted retry
returns that original decision. A publication record's existence alone is not
admission of a complete result or delta transaction.

`advance` accepts only the exact durable self-continuation. Active work schedules
its continuation; an idle owner does not poll or spin. The authenticated host
calls `wake` when explicitly requested or prompted by its bounded scheduler.
Invalidation may prompt a wake, but history supplies every transaction. A fresh
wake with no relevant change publishes no revision. This typed owner does not
by itself provide a background daemon or an automatic SQL subscription.

A semantic failure records the failed successor's basis, original cause and
checkpoint witness, preserves the last complete manifest, and stops advancement.
Later input cannot make it skip an earlier overflow. A gap or incompatible schema
also stops maintenance; an explicitly activated new query identity is needed to
rebuild from another basis. A failure while looking for the next transaction
retains the last complete basis without inventing an unobserved successor.
Unclassified infrastructure errors remain failed attempts. A poisoned native
read requires a fresh closure proposal after settling pending work.

`close` authenticates through its application handler and needs only the query's
own resource. Cancellation stops maintenance while preserving published revisions.
Failure and cancellation retain the request dependency needed by those revisions.
Explicit retirement makes the query's revisions unavailable and releases the
request version. Terminal closure schedules bounded cleanup of the original
history leases. Pending closure is separately observable through `cleanup_cursor`
and the pin records. Denial or transport failure leaves it pending; an explicit
`retryCleanup` or current, original-caller `authorizeCleanup` can resume it.
Closure permission cannot renew the original execution proof or acquire a newer
cut. Completed revision disclosure uses immutable source evidence and current
native rights after lease closure. Retirement does not delete query pages.
Physical query-page collection is not exposed by this owner.

The workspace plus `resident_base` must fit the resident budget. Retained logical
bytes include every immutable group/checkpoint/output/delta/manifest version;
`spill_bytes` bounds their cumulative size. Publication reserves one active
record of at most 8192 bytes separately. A failed semantic step can retain one
additional bounded failure checkpoint. Four native mutations and 256-byte values
remain unchanged. Recomputing every transaction can increase maintenance lag and
state growth; quota pressure stops work without deleting accepted history.

### Maintained record encodings

These encodings are additive to captured execution. Existing captured cuts and
records keep their meanings; captured owners reject a maintained plan. Every
record below includes its four-byte magic and mandatory 32-byte shared native
definition. Integer fields are little endian unless stated otherwise.

- `RQH1`: 32-byte bundle fingerprint, one-byte source count, then per source
  uint64 exclusive Table frontier and uint16-length-prefixed `QHB1`. It fits
  581 bytes. Each frontier equals its source record's accepted position.
  Same-Table aliases repeat the complete record; distinct Tables remain
  independent even within one catalog. Bound cuts use the Table-partition
  domain, declared branch/object, accepted frontier and complete source-record
  fingerprint. Captured exchanges use snapshot records; maintained vectors use
  history records. Original definitions and lease ownership come from the
  bundle's original grants, never a new name lookup or native resource revision.
- `QHS1`, 102 bytes: 32-byte exact preceding-vector fingerprint, one-byte source
  count and scheduling preference, then two uint64 cursor/upper pairs. Unused
  pairs are zero. Aliases repeat their Table's pair. Each cursor lies between
  that Table's selected logical cut and its fixed observed upper bound. This is
  physical traversal progress, not a result vector. A bounded empty history page
  advances it without publishing a logical revision. Persisting this record
  before continuation prevents rescanning the same physical-only prefix after
  replacement. Vector fingerprints hash
  `transit.query.direct-history-vector.v1`, NUL and complete `RQH1` bytes.
- `RMH1`, 219 bytes: uint64 admission ID, peer, correlation, policy revision,
  current complete revision, manifest ID, next record ID, retained bytes and
  continuation input; 72-byte request reference; retained request version
  (uint64 PID/input and one-byte slot); two uint64 pending source coordinates;
  one-byte source count, acquired count, cleanup cursor, scheduling preference,
  phase and request-released flag. Phases are admitted 1, running 2, idle 3,
  failed 4, cancelled 5, retired 6, acquiring 7, seeking 8. Counts/cursors never
  exceed the source count. Source coordinates use the full uint64 Table domain;
  initial acquisition may have zero coordinates. Running, idle and seeking
  require every source acquired; idle/seeking require a completed revision.
  Only retirement marks the native request dependency released. Complete revision zero has
  manifest zero. Pending work leaves the last complete allocation floor intact.
- `RMW1`, 189 bytes: uint64 target revision, checkpoint, output count, output
  bytes, old/new merge cursors, delta count, delta bytes, next record ID, retained
  bytes and manifest ID; 32-byte output and delta chains; one-byte phase
  (compute 1, delta 2, manifest 3, complete 4, failed 5).
- `RMC1`, 60 bytes: uint64 peer, correlation and exact scheduling input.
- `FRD1`, publication format `0x31445246`: Boolean previous-basis presence,
  32-byte previous binding (zero when absent), 32-byte next binding, uint64 delta
  ordinal, uint16-length-prefixed before `FRO1`, and uint16-length-prefixed after
  `FRO1`. Zero length means absent. At least one side exists. A pair has the same
  stable identity and different cells. Both bounds have the same prepared plan.
- `RMD1`, 116 bytes: uint64 delta ordinal and 72-byte immutable delta reference.
  The initial delta chain hashes `transit.relational.delta-transactions.v1`, NUL;
  the next chain hashes the previous chain followed by complete `RMD1` bytes.
- `RMV1`, publication format `0x31564d52`, at most 1200 bytes: uint64 admission ID,
  uint16-length-prefixed complete `RMW1`, Boolean previous-manifest presence and
  optional 72-byte reference, uint16-length-prefixed `RQH1`, and 72-byte final
  checkpoint reference. The first revision has no predecessor. Later revisions
  bind its exact identity; previous output coverage must equal the old cursor.

Maintained ledger keys are NUL, `rm`, one-byte tag, then three big-endian uint64
coordinates. `h` uses peer/correlation/zero; `b` uses admission/target-revision/
source ordinal; `s` uses admission/target-revision/zero for `QHS1`; `w` uses admission/target-revision/zero; `o` and `d` use admission/
revision/output or delta ordinal; `r` uses admission/revision/zero for the complete
manifest reference; `f` uses admission/failed-successor/zero for `RQF1`. Immutable
records use the Publication namespace with the high bit set on the admission ID.

### Complete revision reads and resume

`RelationalRevision.open` receives the frozen bundle, owner, resource, admission
peer/correlation, request budget, optional local cancellation flag, and either a
selected revision or the latest complete revision observed when opening. It
requires a fresh disclosure proof bound to the frozen bundle fingerprint, owner,
resource, peer/correlation, selected revision, result/delta mode, exact predecessor
and request budget. `ResultDisclosure` uses the same domain-separated canonical
selection digest as captured result reads. The proof authenticates the reading
caller, independently of the retained original execution identity. Native raw
resource grants remain a separate requirement for this low-level reader. It
captures a fresh result lease and verifies the manifest, final checkpoint, source
vector and predecessor. An authorized historical revision remains readable as
newer revisions publish or the query fails/cancels. Retirement requires a reset.

The reader supports full rows or the delta against an exact caller-supplied
previous manifest reference. Initial delta delivery uses an absent predecessor.
Wrong predecessors reject before delivery. Every page and terminal completion
rechecks current coordinator policy plus the reading caller's native/catalog rights to all sources,
including noncontributors. The original bundle is never rebound through names.
Output/delta order, ordinals, publication digests, counts and chains must cover the
whole manifest; a prefix cannot replace the consumer's exact relation.

`checkpoint` succeeds only after terminal null. Its persisted position requires
version 1, the shared definition, owner, peer/correlation, admission ID, complete
revision, exact manifest reference and bundle fingerprint. Save this position
atomically with applying the complete result/delta. `openNext` asks for exactly
the following revision. Pending keeps the old position; reset-required requires
an explicit complete snapshot or newly activated definition. A partial retry
replays the entire transaction from the previous complete position. Missing
compatibility fields reject rather than defaulting to the current definition.
Closing a read releases its lease and does not stop maintenance.

## Neutral interactive caller

`RelationalCaller.Request`/`Response` composes this interface for an owned host.
`describe` reads the explicit catalog routes and optionally the active query's
opened reference, current decimal ordinal and read flag. It checks current
catalog metadata and active-source disclosure rights, advances no execution and
opens no data snapshot. The returned reference resumes only this host's session.
`query` wraps the exact `RelationalBridge` actions/results below. Board reflects
these shared types in its separately configured relational route.

`transit-query.RelationalBridge` owns the neutral interactive action/result types;
Station's query ABI and port reflect them without another executor. See the
[caller guide](../packages/zig/transit-query/docs/relational-callers.md) for exact
configuration and action fields. Routes are explicit indices into at most two
configured catalog connections and share one authenticated realm caller.

An open ID is nonzero 16-byte lowercase hex. Active exact open retries preserve
the captured basis; changed IDs/statements reject. References require the current
native definition, open ID, prepared plan hash and bound hash. Missing or foreign
definitions reject. Ordinals and full-width quantities are canonical decimal
strings. Pair row identities are the 20-byte Table identity encodings; group
identities preserve the ordered nullable int64 keys as decimal strings.

One page contains one row or a terminal null row. Only the current ordinal and
its immediate successor are admissible; a successor requires a previous row.
The terminal ordinal equals delivered row count and is the sole
`complete_coverage: true` page. Each disclosure rechecks all current source rights,
including cached and terminal pages. A response allocation/encoding failure does
not discard its pending row. A semantic failure retains the original cause and
cannot publish completion. Closing releases the interactive execution, and an
exact retry of its last close succeeds. Host loss expires references; this
interface neither persists interactive spill nor restarts SQL implicitly.
