# Finite relational semantics v1

Fuze's [Relational module](../packages/zig/transit-fuze/src/Relational.zig)
supplies pure typed-plan validation, stable column resolution, output descriptors,
prepared/bound fingerprints and scalar null/count/sum rules. Slices borrow
immutable caller storage. Operations allocate no heap memory and acquire no
source, permission, storage, clock or I/O.

`RelationalSql` lowers finite SELECT into these same definitions through the
shared lexer, identifiers, literals and predicate grammar. `RelationalExecution`
executes over supplied ordered sources and external group storage. The query
package's `RelationalQuery` owns interactive native Table cuts, current rights,
bounded allocation and private disk grouping. Durable captured/maintained
admission, checkpoint codecs, foreign-language ABI and result manifests remain
outside this interface. The small finite interpreter under `tests/` supplies an
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
results. Pins cover every distinct source resource, at most two. Actual resource
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
cut has resource/revision, nonzero opaque root commitment and full schema hash.
Missing cuts, resource/schema mismatches and inconsistent cuts for aliases of
one resource reject. Different Tables sharing a resource also share its cut.

An adapter must authenticate and retain the root and validate the schema at that
cut. Nonzero hashes alone establish neither authenticity nor retention. Capture
all cuts and seal the vector before execution; partial failure releases all
acquired pins. Different resources may be captured at different moments. This
is not an atomic or causal cross-resource snapshot; atomic-snapshot requests reject.

Interactive and captured lifetimes have different prepared identities. Interactive
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
6. Lifetime byte (interactive 0, captured 1), uint64 resident/spill/result bytes,
   output rows and work steps, then one-byte pin capacity.

Bound bytes are domain, NUL, `bound`, NUL, prepared hash, then each cut's uint64
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

## Disclosure and completion obligations

Execution and each bounded disclosure/publication require current rights to
every transitive source, including inputs producing no matches. A derived-result
grant, source pin or checkpoint cannot replace source permission.

Completion requires source/partition coverage, result schema, ordered output
coverage and terminal validation. Empty inputs also need completion evidence.
Arithmetic, authority, storage, allocation and budget failures leave any returned
prefix incomplete. Fuze owns deterministic semantics; query/Station and authorized
hosts own capture, I/O, spill, atomic publication and recovery.

Maintained revisions, exchanges and reassignment need separately qualified
lifecycle contracts. Table invalidation watches are not complete changelogs.
Neither runtime nor distributed qualification follows from the local contract.
