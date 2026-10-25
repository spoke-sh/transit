# Index declaration and coverage contract v1

## Scope and implementation boundary

[`IndexLifecycle`](../packages/zig/transit-protocol/src/IndexLifecycle.zig) supplies
neutral catalog declarations, build identities, maintenance observations, exact
coverage descriptors and conditional publication bindings. The public protocol
package implements deterministic validation, declaration commitments and binding
comparisons. Its [schema](index-lifecycle-v1.schema.json) is reflected from these
types; the roots group descriptors and are not a request envelope.

These are offline descriptors. The installed catalog has no index declaration,
build, publish or drop operation, and SQL has no executable `CREATE INDEX` form.
The contract implements no secondary access method, online build, constraint
enforcement, planner eligibility decision or index storage format. It adds no
permission authority. Validating a descriptor establishes its shape and internal
attribution, not that an object exists or an owner accepted its claims.

This is a new, separate descriptor family. Existing requests, saved operations,
ABIs and stored formats retain their exact definitions and bytes. All new
declarations, generations and publication bindings require the explicit current
shared `definition`; absent or foreign identifiers reject. No decoder defaults
an old artifact to the current definition. An incompatible extension of these
descriptors requires the shared-definition review in the
[versioning policy](../docs/handbook/reference/versioning.md).

## Identities, interpretation and dependencies

The contract reuses [data lifecycle identities](DATA_LIFECYCLE_V1.md):

| Field | Meaning |
| --- | --- |
| `Declaration.interpretation` | Stable index object identity, immutable definition revision and complete declaration digest |
| `Declaration.source` | Exact source object and definition, including the declared column interpretation |
| `Key.column` / `included` | Stable source column identities; names and physical column offsets are not bindings |
| `Purpose.constraint.interpretation` | Separate exact logical constraint identity and definition |
| `Generation.operation` | Original build operation, independently of worker/process identity |
| `Generation.generation` | Nonzero full-width generation allocated for this index build; a rebuild uses a new generation |

Index, source and any constraint must share catalog scope and branch and have
distinct object identities. Renaming a human label does not change those
identities. Source interpretation changes require a newly bound declaration;
reusing a name cannot retarget saved work. Identifiers preserve their full `u64`
range, except native realm/resource/principal bounds inherited from
`DataLifecycle`. JSON callers must preserve exact integers.

The declaration has 1–128 ordered keys and 0–128 included columns, with at most
128 columns combined. Columns must be nonzero and unique across both lists.
These bound one declaration's validation work, not the number of indexes,
objects, entries or generations in a durable catalog. Zig slices borrow the
caller. Decoders own their parsed allocations and must apply their enclosing
input/memory budgets before parsing. The reflected schema bounds each sequence;
domain validation also enforces nonempty keys, uniqueness and the combined bound.

The catalog owner must resolve the exact source and every column before it can
accept a declaration. For constraint-owned indexes it must additionally verify
the logical constraint's source, key semantics and dependency. Structural
validation alone cannot establish those relationships. Accepted declarations
must register dependencies before publication and retain them through uncertain
publication or retirement. A physical structure's removal cannot remove its
logical constraint or silently disable enforcement.

## Key semantics and constraint ownership

Each key specifies ascending/descending order and NULL placement (`first` or
`last`). `comparison: declared_column` selects the logical type and collation
from the exact source definition. The source digest binds the column descriptor;
the mandatory shared definition pins the admitted comparison/collation algorithms.
A collation implementation or semantic-version change cannot reuse those
commitments implicitly. There is no per-index collation override in this profile.

Logical type, physical codec and collation remain orthogonal. An encoding's byte
order, dictionary ordinal, abbreviation or hash never supplies comparison truth.
Storage must use the declared comparison and resolve abbreviation/hash collisions
with the complete key. NULL placement is independent of descending value order.
Composite keys compare lexicographically in declaration order. Included columns
are payload only; they neither change ordering nor add uniqueness constraints.

The source profile is Table values and SQL NULL. Missing values, type errors and
conflicts cannot be silently omitted or mapped to NULL. Unsupported logical
comparisons or fallible key evaluation must reject before publication; errors
cannot establish complete coverage. Expression keys, partial predicates,
document projections, inverted/spatial/vector methods and arbitrary collation
versions require separate admitted contracts. The descriptor has no fields that
silently enable these profiles.

`Purpose.acceleration` imposes no uniqueness. Duplicate keys retain distinct
stable row/version identities in an eventual physical layout, including keyless
Tables. `Purpose.constraint` binds a separate primary-key or unique constraint.
Its NULL uniqueness policy is `forbidden`, `distinct` or `equal`; primary keys
require `forbidden`. This policy is independent of NULL sort placement. A build's
progress or query readiness never permits lagging constraint enforcement. Until
the transaction owner can enforce a constraint for every accepted write, it
cannot advertise that constraint as active.

## Immutable declaration commitment

`Declaration.fingerprint()` uses SHA-256 over this exact binary sequence. All
integers, including list lengths, are unsigned 64-bit big endian unless a byte
is specified. There is no text normalization, implicit field or name lookup.

1. UTF-8 bytes `transit.index.declaration.v1` followed by one zero byte.
2. The 32 raw bytes of the current shared contract definition.
3. Index object: realm, resource, catalog, branch and object; then definition revision.
4. Source definition: the same five object fields, revision and 32 digest bytes.
5. Key count, then each key's column ID and three single-byte tags: direction
   (`ascending=1`, `descending=2`), NULL placement (`first=1`, `last=2`) and
   comparison (`declared_column=1`).
6. Included-column count, then each column ID in declared order.
7. Purpose byte: `acceleration=0`, or `constraint=1` followed by its complete
   definition using step 4's framing, kind byte (`primary_key=1`, `unique=2`)
   and NULL uniqueness byte (`forbidden=1`, `distinct=2`, `equal=3`).

The result must equal `interpretation.digest`. The digest field itself is not
hashed. Authoring computes it after fixing all fields; reading validates the
stored value and never repairs it. The independent
[fixture](../packages/zig/transit-protocol/src/fixtures/index-lifecycle-v1.json)
and [Python commitment implementation](../tests/index_lifecycle_contract.py)
cover ordinary and constraint-owned definitions.

## Build progress and exact coverage

`Generation` freezes the index definition, generation, original operation and
complete initial `SourceCut`. `requireDeclaration` checks both the index and
source interpretation against the declaration. Build operation scope must match
the index catalog. A generation is neither a worker fence nor an execution grant;
the owning runtime must fence publication separately.

`Progress` distinguishes `backfill`, `catch_up`, `validating` and `complete`.
Backfill has no complete `through` frontier. Later phases require a frontier in
the initial source partition at or after the starting cut. This is maintenance
attribution only. In particular, `complete` is not published query eligibility.

`Coverage` binds one generation to a complete source cut and immutable index-root
content commitment. Its source definition and partition must match the build;
the accepted frontier cannot move backwards. Source cuts preserve checkpoint
coverage plus all accepted unflushed WAL data. A WAL-only cut is valid; a nonzero
checkpoint without its manifest is not. The index root must identify all data,
visibility and layout information required to interpret that generation. This
contract fixes no `.tidx` format or tree layout.

`requireBasis(declaration, snapshot, requested)` checks exact index/source
attribution and the snapshot's scope, branch and declared consistency model.
The requested source definition and accepted frontier must equal the coverage.
A newer high-water mark does not prove an older historical cut, and an older
coverage does not prove a newer cut. Different physical checkpoints at the same
logical definition/frontier are allowed; their existence and reachability still
require owner evidence. Independent source vectors remain independent, even
when every index matches its individual source.

This method does not prove membership in `snapshot.sources_root`, completeness
of the index root, visibility, retained history or current authorization. The
query owner must establish each before selecting an access path. A later
index-plus-delta path requires a complete, gap-free delta from the covered cut
to the requested cut and an explicit composition contract; this profile has no
such eligibility shortcut. Otherwise use another qualified path.

## Conditional publication, permissions and lifetime

`Publication` freezes an original publication operation, the complete coverage
and an expected prior publication commitment. Null means expected absence;
otherwise the catalog owner must compare the exact previously accepted
publication. `requireSame` rejects retries that change any field, including
caller, build generation, root, source cut or expectation. Changing the
expectation after an uncertain response is different work, not recovery.

An implementing catalog owner must atomically validate the expected predecessor,
source/index definitions, complete build evidence and current authority before
publishing the successor. The catalog root binds declarations and accepted
coverage separately. An arbitrary content-addressed object or structurally
valid proposal is not that publication. Current source/catalog permissions must
gate declaration, build, metadata inspection and query disclosure, including
index-only reads; cached coverage and snapshot roots grant no rights.

Retirement must preserve active reader/build/branch/backup roots and pending
publication recovery. Descriptor possession is not a retention pin. Logical
retirement, constraint removal and physical reclamation remain separate owner
operations. No cleanup, expiry, lock or storage action occurs in these types.

## Validation failures

The Zig validators return domain errors; there is no service error envelope for
these offline operations. Identity, content and snapshot errors from
`DataLifecycle` propagate unchanged. Index-specific failures distinguish:

| Error | Rejected condition |
| --- | --- |
| `InvalidIndexColumns` | Empty/oversized key lists, zero/duplicate columns or the combined column bound |
| `InvalidIndexDependency` | Different scope/branch, self dependency or operation-scope mismatch |
| `InvalidIndexConstraint` | A primary-key declaration that permits NULLs |
| `IndexDefinitionMismatch` | Changed declaration commitment or mismatched exact index/source definition |
| `InvalidIndexGeneration` | Zero build generation |
| `InvalidIndexProgress` | Missing/invalid phase frontier, backward progress or a different partition |
| `IndexCoverageMismatch` | Requested source identity/definition/frontier differs from covered data |
| `IndexPublicationConflict` | A retry changes any frozen publication field |

JSON decoding additionally rejects missing/foreign definitions, unknown fields
and unsupported enum values. A valid shape is still subject to domain validation
and the owner's separate acceptance and current-authority checks.
