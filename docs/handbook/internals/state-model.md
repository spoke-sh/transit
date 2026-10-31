# State, publication and lifetime

This account asks how a data definition becomes an accepted, inspectable version
without exposing partial changes or losing the evidence needed for recovery.
It connects Table, KV and Document semantics to publication, bounded resident
work and retention. The [data model](../reference/data-model.md) supplies the
user-facing context. The [state](../reference/state.md), [Table](../reference/tables.md),
[Document](../reference/documents.md) and [retention](../reference/retention.md)
references own APIs, supported types and numeric bounds.

## Model

Keep a definition revision, data revision and execution progress separate.
A Table can accept many data revisions under one schema; a Document's visible
projection does not contain all its causal history. The owning published head
connects the accepted interpretation and data. Generic storage bytes or a worker
checkpoint alone cannot establish that semantic relationship.

A resource has a realm-qualified identity and immutable committed revisions.
An association records a process's declared access/dependency relationship.
Writer identity, lifetime ownership and permission remain independent facts.
The supported turn boundary mutates one resource with input progress and outputs;
reading other resources does not create a global snapshot or transaction.

The paged representation separates retained data from the pages, operation
batches and active views held in memory. This distinction depends on bounded
access at every layer; placing a paged backend beneath a caller that loads the
entire collection would not establish a bounded working set.

## Visibility and publication

Larger logical values are staged as bounded immutable pieces. Staging establishes
the existence of those bytes, while a final validated head/root establishes their
logical visibility. A crash before that decision can leave staged data but must
not expose a partially accepted value. A crash after acceptance must recover the
same head and required dependencies.

This separates byte completeness from semantic validity. Publication can verify
pieces and commitments; a Document owner must still validate change dependencies,
merge rules and the accepted index. The
[publication contract](../../../contracts/STATION_PUBLICATION_V1.md) and
[Document contract](../../../contracts/STATION_DOCUMENT_V1.md) own those different checks.

### Durable private Table statements

The question is how a transaction can recover accepted private statements without
exposing their rows as committed Table data. This implemented component profile,
at source `48405c6c20d6`, uses a catalog-acquired common cut, one serialized local
database owner and immutable private Table roots. It supplies no installed
transaction session or multi-Table commit decision. The
[catalog component guide](../../../packages/zig/transit-catalog/docs/direct-catalog.md)
and [reserved record contract](../../../contracts/DIRECT_TABLE_V1.md#durable-client-token-bindings)
own the operations, formats and limits.

Let `C` be the retained acquired cut, `W` the paged map from Table IDs to private
roots, `R` the paged map from statement sequences to completed outcomes, and `P`
the optional pending request. The accepted catalog token names
`(C, W, R, n, P, q)`, where `n` is the last consumed sequence and `q` is a
conservative cumulative staging charge. A request freezes its transaction,
sequence, original Table operation and immutable DML bytes. This model assumes
an atomic fenced catalog append, durable immutable objects, authentic current
policy checks and a host that excludes database publication throughout each
component call. Reply loss can occur after acceptance; an exception alone cannot
establish non-acceptance.

Admission requires sequence `n + 1` and empty `P`. It first claims the original
Table operation specifically for this transaction statement, then accepts `P`
and advances `n`. Evaluation restores the selected Table's private root, or its
original retained source on first use. It reuses the bulk Table mutation engine
without appending public Table data. Completion stages the next private root and
outcome, then publishes both directory roots while clearing `P` in one catalog
append. Rejection also consumes the sequence and records its original outcome.

These transitions explain three safety claims. A completed provisional outcome
cannot name a different accepted private root because they share one acceptance.
An exact retry reads `R` instead of executing again; conflicting request content
cannot reuse the sequence. Finally, the separate immutable operation claim
prevents a private statement from being submitted later as an ordinary Table
write, including after lost admission acknowledgment. Removing that claim would
leave a route from one original operation to both private and public execution.
An interrupted evaluation leaves its admitted `P` intact. Unreachable staging
is not accepted progress and cannot replace the previous `W`.

Current SELECT and original DML permissions are checked before execution and
repeated outcome disclosure. Independent guards must report one writer/policy
epoch through publication; they do not accumulate one authorization array for
all selected Tables. Possession of a private root or retained pin grants no
permission. Generic caller-record operations reject the reserved workspace
formats, preventing CONNECT-only access to their payloads.

The retained graph follows accepted catalog history into both workspace
directories, pending/completed intents, private Table indexes and segment data.
Private evaluator positions are never interpreted as public WAL acceptances.
When old row locators require archived WAL, traversal uses the real accepted
Table owner's archive coverage. The original Table pins retain the source cut.
Pages bound resident traversal, not durable cardinality; the graph emits at most
three child jobs per step.

Account admission separately sums transaction ceilings for count, resident
bytes, workspace bytes, participants, statements and savepoints. These counters
share the begin's catalog acceptance and the principal/account scope across login
roles. Lost replies do not duplicate a reservation. This reserves capacity
without allocating all declared memory. Current limits can stop new admission
while original accepted-token recovery continues. Pending work retains its
reservation; pressure does not authorize expiration or cleanup.

The design pays two catalog acceptances per new private statement plus immutable
identity/staging work, and permits one pending statement per transaction. A
session-local result cache would avoid some writes but lose original outcomes
on restart. Reusing autocommit operation claims would erase the distinction
between private and public execution. The chosen directories and conservative
staging charges favor recoverability and bounded resident state; no latency or
throughput comparison is claimed. Account ceilings do not replace deployment-wide
scheduling or physical disk quotas, and failed unreachable staging has a separate
collection lifetime.

The [catalog tests](../../../packages/zig/transit-catalog/src/direct_catalog_test.zig)
exercise disk reopen after lost admission/completion replies, original private
row contents, duplicate-key rejection, revocation, paged reachability and quota
refusal. Reproduce the focused component cases with
`zig build test -Dtest-filter=transaction` in the catalog package under the pinned
development shell. The [qualification ledger](../../history/qualification/verification.md)
records exact revisions and executed methods. These checks establish neither
automatic model refinement nor host power-loss behavior. Participant preparation,
common-decision visibility, durable savepoints, abort/cleanup settlement and
signed/SQL workspace callers remain separate obligations. In particular, a
resource failure may leave a statement pending; this component has no general
liveness or automatic abort guarantee.

## Typed state and causality

### Named direct KV partitions

A named KV object shares catalog identity, name reservation and policy with
Tables, but its data belongs to `KVPartition`. The catalog persists the data kind
in its intent and physical declaration; the exact key/value schema fingerprint
and kind must both match before the partition opens. The native Document marker
cannot establish a KV object. These checks keep the policy domain and physical
interpretation aligned without routing database changes through a Station turn.

The key lifecycle question is whether a failed batch or lost response can expose
only part of the intended state. KV lowers a bounded change list to the shared
partition engine under one current publication guard. All key expectations and
optional observed-position guards precede publication; state and original receipt
share one accepted partition root. Inspection and exact retry recover that receipt
without accepting another mutation. Missing-key reads disclose their source basis,
so a caller can guard absence against a concurrent insertion. A retained snapshot
keeps its original interpretation after rename or DROP and still requires current
read authority.

The [typed KV contract](../../../contracts/DIRECT_TABLE_V1.md#direct-kv) specifies
identity, value and batch bounds. The [catalog checks](../../../packages/zig/transit-catalog/src/direct_catalog_test.zig)
exercise disk reopen, large batches, original receipts, missing-key conflicts,
revocation and dependencies in both directions with native Documents. The
[installed caller schedule](../../../tests/catalog/tables/direct_kv.zig) exercises
the signed service boundary; an executed run is required before claiming its
fault coverage. Native private state remains a separate Station resource, and
Table transactions still refuse KV participants before admission.

### Naming initialized native resources

The question is how a catalog name can identify usable Document state when
metadata acceptance, native allocation and framework initialization have different
commit owners. The implemented profile uses one direct catalog, one existing
native resource writer and explicit caller-driven progress. It assumes authentic
native receipts, fenced native commits, durable catalog WAL recovery and an
application writer that implements the declared initializer. It does not assume
that a supplied resource ID proves initialization or that protocol validation
proves honest application computation.

Let `B` be the frozen declaration, `A` its prepared original-caller allocation,
`R` the native resource accepted by `A`, and `I` the initial interpretation of
`B` and `R`. Catalog phases advance from admitted to prepared to allocated to
complete. The native owner separately accepts `A`; the Station owner separately
commits initialization of `R` under `I`. Catalog visibility requires the exact
native receipt and initialization marker under a current native authority fence.
The [neutral marker](../../../contracts/DATA_LIFECYCLE_V1.md#native-resource-initialization)
and [resource request contract](../../../contracts/DIRECT_TABLE_V1.md#named-native-resources)
specify the representations and checks.

This gives three useful invariants. First, retry preserves `B` and `A`; a lost
reply cannot select another native sequence or resource. Second, allocation alone
cannot publish a name: missing initialization leaves the operation allocated.
Third, logical cancellation or DROP does not erase the native allocation or
retire its data. These properties follow from the separate retained receipts and
the catalog's phase transitions, rather than a transaction spanning all owners.
One prepared allocation per principal occupies a paged catalog index so two
declarations cannot freeze the same next native sequence. Reconciliation or
cancellation releases that reservation. Independent native activity can still
conflict; the actual native receipt remains decisive.

Document initialization needs three commits: reserve `I`, create the actual Document service state, then verify
its empty accepted head and record completion. Restart between those commits
reads the same reservation and never adopts an unrelated existing Document.
Metadata registration does not grant data access; publication checks the original
caller's current rights, and reads check them again after buffering. A completed
catalog receipt remains historical publication evidence after later revocation,
retirement or expiry.

An explicit dependency edge binds exact source and consumer interpretations.
For a named resource consumer, its allocated definition already fixes `I`, so
registration can precede name publication without inventing a future resource ID.
The catalog verifies its actual kind and definition and requires its metadata
owner's authority. Requiring WRITE on the shared catalog backing resource would
couple independent object owners and expose an unrelated authority; native data
permissions would incorrectly make metadata cleanup depend on data availability.
Source reads instead require their own current rights. Published named sources
participate in the same paged forward/reverse graph and DROP restriction as Tables.
Rename preserves old exact edges. Consumer retirement and edge removal remain
separate explicit acceptances, so an interrupted cleanup leaves conservative
DROP protection. These edges neither retain data cuts nor discover undeclared
consumers. The [named computation workflow](query-engine.md#immutable-names-and-query-attribution)
uses a saved registration plan before its separate native publication.

The implementation is in
[DirectCatalog](../../../packages/zig/transit-catalog/src/DirectCatalog.zig),
[LocalCatalogPolicy](../../../apps/transit-node/LocalCatalogPolicy.zig) and
[NamedResource](../../../packages/zig/transit-station-app/src/NamedResource.zig).
The [public caller fault schedule](../../../tests/storage/tables/direct_table_service.py) drives
separate catalog and native callers. Reproduction commands, executed results
and their source basis belong in the [proof ledger](../../history/qualification/README.md).
The bounded directory/recovery tests exercise a one-page resident cache. Those
checks do not establish distributed atomicity, automatic reconciliation, arbitrary
writer honesty or a retained multi-resource snapshot. Reusing a supplied resource
ID would avoid allocation steps but could silently adopt unrelated data; this
profile instead requires a fresh exact native allocation.

### Complete Table history under a bounded turn

The question is how a reader can finish a frozen backfill and later recover
every intervening Table transaction without adding an unbounded resident log
or exceeding the native metadata and block budgets. The implemented Table history applies
to one stable Table object; it is separate from the proposed branch mechanisms
below and from a global snapshot.

Let `H_n` be committed head revision `n`, and `c_n` the native revision of the
entry that published it. Before accepting `H_(n+1)`, `TableHead.replace` preserves
`(H_n, c_n)` under immutable key `j/n`. The current head is the upper bound on
accepted revisions. This construction assumes one fenced resource writer,
conditional native commit, immutable row/index records and current scoped read
permission. [The codec and transition checks](../../../contracts/TABLE_DATA_V1.md#complete-committed-head-history)
specify those records precisely.

Staging `j/n` early cannot falsely admit a successor: it contains only the
already accepted predecessor, and the current head still names `n`. Conditional
replacement either accepts the next head with its outcome and input progress,
or leaves the previous root visible. Induction from the creation head therefore
gives consecutive predecessor coverage for every accepted head. A retained
reader finishing at `H_n` resumes at `n+1`, even if many writes completed while
it was paused. A gap or conflicting predecessor falsifies the coverage premise
and causes an error. Coalesced invalidation alone cannot provide this property.

The native coordinate must be the head entry's own revision. Using the resource
revision at the later archive read would move the old Table state forward in
time; using the archive commit would be wrong for the same reason. The reader
therefore obtains the head and entry revision together in one bounded native
page. Reconstructing a Table head at a coordinate does not reconstruct native
authority, grants or a resource-wide historical view.

Diff traversal merges immutable row identities with at most two owned rows and
two schemas. It pairs updates, preserves inserts/deletes, and exposes a complete
transaction boundary even when no row changes. Equal schema/index roots permit
constant-work no-op completion; other differences can require a full traversal.
Each replaced head adds one retained block. The small head and receipt mutations
can share a turn with that block and row/index blocks; candidates beyond the
separate block-count/byte budget need additional staging. This favors exact
history and bounded memory without making each predecessor consume a metadata
write slot. It does not imply sublinear change extraction or a measured catch-up
rate for large changing relations.

The [proof ledger](../../history/qualification/catalog.md#complete-table-history-and-snapshot-tail)
records the pinned toolchain commands for the reference-store, codec and signed
snapshot/tail schedules. The
[reference-store tests](../../../packages/zig/transit-station/src/table_pages_test.zig)
exercise missing/corrupt predecessors and allocation failures; the
[native schedule](https://github.com/spoke-sh/transit/blob/b861597c460896f0bfb7d8568f95ce549e94f38e/tests/typed_table_native.py) uses disk-backed Ursula.
[Executed results](../../history/qualification/catalog.md#complete-table-history-and-snapshot-tail)
state which revisions and schedules passed. These observations do not establish
distributed history availability, automatic retention collection or maintained
query semantics.

| Representation | Additional meaning | Boundary it does not remove |
| --- | --- | --- |
| KV | Explicit opaque keys and values | Current access and revision basis |
| Table | Declared schema, primary keys and typed row encoding | One-resource turn atomicity |
| Document | Stable object/operation identities, observed dependencies and explicit conflicts | Fenced acceptance and current write permission |

Document mergeability is a property of changes under declared rules, not
permission to publish them. Visible values alone are insufficient recovery state:
causal dependencies, deletions and history floors prevent stale changes from
resurrecting removed content. Missing, null and conflict therefore remain distinct
through reads and query projections.

## Retention argument

Checkpoint publication must precede trimming the history it replaces. The
checkpoint and retained tail must preserve the specified recovery projection,
including unfinished work and identity/rejection evidence. Once that prefix is
removed, the checkpoint is essential data rather than an optional cache.

Logical expiry, terminal closure and physical cleanup have separate conditions.
A late physical delete must not target a replacement identity. An old reference
must not renew permission, revive a retired resource or pin arbitrary history.
Unlimited retention is the default; capacity pressure can refuse new admission
but cannot supply application consent to expiry.

## Tradeoffs, evidence and limits

Keeping every retained value resident would make memory proportional to durable
cardinality. Bounded pages avoid that dependency but introduce indirection,
cache misses and staging/cleanup work. The
[storage account](storage-runtime.md) and [measured costs](../reference/performance.md)
explain those costs without treating configured cache size as measured peak RSS.

[State-resource evidence](../../history/qualification/runtime.md#m7-state-resources),
[publication evidence](../../history/qualification/query.md#m14-immutable-publication) and
[Document qualification](../../history/qualification/runtime.md#m17-qualification) record the
applicable contracts, crash schedules, commands and limits. They do not establish
arbitrary multi-resource transactions, generic dependency deletion or erasure
from every external copy. Historical details remain in the
[state](../../history/STATE.md), [Tables](../../history/TABLES.md),
[Documents](../../history/DOCUMENTS.md) and [retention](../../history/RETENTION.md) records.

## Schema history and branches

This section is design analysis, researched on 2026-09-29 against Transit
`113588b6`. It asks how application data and its interpretation can branch without
duplicating execution authority. Historical catalogs, writable branches and generic
merge are not implemented. The analysis extends the existing state/publication
model; it does not qualify a new storage or recovery capability.

The terminology and authority boundaries below are clarified on 2026-10-23:
branching is a primitive within one realm, while independent export and a
project/application fork relationship have separate semantics. This is a design
clarification; it supplies no new branch implementation or measured evidence.

### Lessons from Dolt and Neon

The two systems offer complementary reference models:

| Source | Observed semantics | Implication for Transit |
| --- | --- | --- |
| [Dolt history queries](https://www.dolthub.com/docs/sql-reference/version-control/querying-history/) | AS OF accepts commit/branch/ancestry references or timestamps; historical SHOW/DESCRIBE are available. Its unit is a Dolt commit, separate from SQL transaction commit by default | Name the exact unit of history and resolve a mutable reference once |
| [Dolt branch selection](https://www.dolthub.com/docs/sql-reference/version-control/branches/) | Branch-qualified databases can expose a working set, while commit-qualified databases are read-only | Do not hide committed-head versus working-state differences behind one selector |
| [Dolt schema override](https://www.dolthub.com/docs/sql-reference/version-control/dolt-sysvars/#dolt_override_schema) | An explicit session setting maps data through another revision's schema, including NULL for absent columns | Separate historical interpretation from schema projection; preserve Transit's missing/null distinction |
| [Dolt merges](https://www.dolthub.com/docs/sql-reference/version-control/merges/) | Merges expose schema/data conflicts and constraint violations for resolution | A merge needs semantic validation and a durable conflict model |
| [Neon branching](https://github.com/neondatabase/website/blob/69b85134dbf7aa8154ee69e655452f2e29856b8a/content/docs/introduction/branching.md) | Copy-on-write child branches diverge from a selected current or retained historical state | Share immutable data where possible while creating independent branch state |
| [Neon schema-only branches](https://github.com/neondatabase/website/blob/69b85134dbf7aa8154ee69e655452f2e29856b8a/content/docs/handbook/guides/branching-schema-only.md) | Copy definitions without rows into an independent root | Make data inclusion and provenance explicit |
| [Neon Schema Diff](https://github.com/neondatabase/website/blob/69b85134dbf7aa8154ee69e655452f2e29856b8a/content/docs/handbook/guides/schema-diff.md) | Compares branch schemas, including historical bases | Definition differences need a public typed inspection surface |

There are useful limits to examine. Dolt documents that AS OF on a view uses
the current view definition over historical rows; a commit-qualified database
can select the historical definition instead. Transit should choose historical
definitions by default when selecting a snapshot. This is a proposed behavioral
choice, not a claim that Dolt cannot query historical views.

Neon's [promotion workflow](https://neon.com/blog/promoting-postgres-changes-safely-production)
describes snapshot replacement separately from Git-like merging and warns that
intervening target writes can be lost. Its
[backend branching account](https://github.com/neondatabase/website/blob/69b85134dbf7aa8154ee69e655452f2e29856b8a/content/docs/concepts/branch-your-backend.md)
also covers Auth, Object Storage, Functions and AI Gateway. That account says
database restore restores Postgres/Auth but not objects or deployed functions.
It would be inaccurate to characterize current Neon as only branching tables.
For Transit, the design question is the explicit closure of data, definitions,
captured inputs and execution evidence, rather than an unqualified product-parity
or superiority claim.

The Neon documentation basis is website commit `69b85134`; the reviewed
[storage account](https://github.com/neondatabase/neon/blob/fa504217c61bbcaf5c512d75830564541f917f8f/docs/pageserver-storage.md)
is from Neon commit `fa504217`. It explains immutable layers, timeline ancestry
and historical page reads, but marks portions obsolete. Use it for the mechanism,
not current limits or performance numbers. No peer database was run for this study.

### A snapshot includes interpretation

The proposed logical snapshot is an immutable manifest for an explicit
application namespace. Its ID identifies an accepted publication, not a raw
journal offset or just a hash of row contents. Content commitments remain useful
for verification and sharing; parentage and publication identity remain distinct.

| Manifest component | Required meaning |
| --- | --- |
| Scope and ancestry | Namespace, snapshot ID, parent snapshot IDs and publication provenance |
| Catalog | Stable object/column identities, names at that snapshot, schemas, constraints, views and graph mappings |
| Data | Exact resource roots/accepted Document bases and schema/codec commitments |
| Dependencies | Explicit captured-source manifests, immutable payload/artifact references and availability policy |
| Computation evidence | Query/transform definitions and compatible implementation commitments; optional captured outcomes as input evidence |
| Consistency | Single-owner atomic publication or an explicitly described source basis vector |

These are conceptual fields, not a new wire schema. Only existing records and
declared dependencies belong in a snapshot. An external URI is not an immutable
input; missing content, old artifacts or unavailable history are explicit failures.
Artifact references can document provenance without promising executable replay.
Current rights and compatible code remain required for every execution/disclosure.

A branch adds an immutable branch identity, a human name, current head, generation
and policy/lifetime metadata. Publishing a successor compares the expected head
and generation, then advances them through accepted history. Branch movement is
auditable; restoring a name never erases earlier head transitions. A tag is an
optional immutable name for a snapshot. None requires a new KV/Table/Document
kind: they are catalog objects and generic state/publication operations above
the resource boundary. Efficient branching may still require new native operations.

There is no separate Git-style staging index or shared uncommitted working set in
the first proposal. Each accepted branch publication advances its durable head;
an incomplete schema migration or merge candidate stays private staging. Naming
a snapshot creates a reference to that accepted state, not another SQL transaction
commit. A mutable branch selector resolves once to a concrete head per statement;
continuations and accepted operations retain that exact identity.

Branching is the versioning primitive within a realm in this model. The realm
continues to own identity and authorization; a branch is not inherently a new
ownership or export boundary. A project/application fork relationship, analogous
to a hosting service's collaboration feature, could be layered above branches.
Its ownership and cross-realm semantics are separate questions. Branch policy
can allow creation/edit/sharing while prohibiting every merge and equivalent
write to a protected destination. A human-approved profile additionally needs
approval bound to an exact candidate and destination expectation; a branch or
UI selection alone supplies no approval evidence.

### Coherent catalogs require a publication boundary

The existing one-resource turn can atomically accept a branch head and its staged
data/catalog manifest under one writer. This is the proposed first coherent
scope, requiring its own framework layout and validation. It does not make all
existing Tables or independent writers part of a global database transaction.

For broader snapshots, a manifest of independently captured revisions is only a
basis vector. A coherent application checkpoint needs a proven owner/barrier
protocol, such as pausing participating writes and validating the entire closure
before publication. It must account for pending inputs and dependencies where
reproducible computation is promised. Do not label a convenient collection of
latest references transactionally consistent.

Schema and data activate together at the owning head. Renames preserve stable
column identity; dropping then recreating a spelling creates a different column.
Type changes need declared conversions with explicit overflow, precision and
failure behavior. Defaults do not retroactively populate historical rows. A
schema-only branch contains empty data by construction; its omitted rows do not
mean that all parent rows were deleted during a later schema merge. Its data
lineage and schema lineage therefore need separate inclusion metadata.

### Branch creation and shared storage

Transit already uses immutable pages, but that is insufficient for cheap writable
branches when pages live inside a shared global B-tree root. The
[retained-version contract](../../../contracts/READ_VERSIONS_V1.md) binds reads to
current owners, grants and source lifetimes. Its captured root covers a shared
catalog and can retain unrelated pages. It neither grants another writer access
to that root nor exposes selective resource cloning and page reclamation.

The proposed branch-creation operation binds a frozen source snapshot, realm,
new branch identity/head, branch-scoped catalog interpretation, current source
and branch-creation permissions, storage lifetime, quotas and an exact receipt.
Branch access and any inheritance follow explicitly defined current realm policy;
creation neither freezes permissions nor establishes an independent export.
A bounded materialized copy can serve as a correctness oracle for the same
logical branch semantics. A copy-on-write implementation must prove equivalent
writes, deletes, reads and retained reachability while sharing eligible immutable
data. Neither implementation copies grants, principal sequences, retired
identities or pending control records into new authority.

In the target [four-tier storage architecture](storage-runtime.md#four-tier-storage-architecture-tseg-segments-and-multi-writer-occ),
committed table state is represented by an immutable **Manifest ($M_v$)**
referencing immutable **`.tseg` Data Segments** and **`.tdel` Deletion Vectors**
in `TransitObjectStore`. This representation turns branching and three-way
merging into manifest-level operations without per-page B-tree reference counting:

```mermaid
flowchart LR
  subgraph SharedSegments["Immutable Tier 3 Object Storage (.tseg / .tdel)"]
    S1["seg_01.tseg (rows 1..65536)"]
    S2["seg_02.tseg (rows 65537..131072)"]
    S3Main["seg_03_main.tseg (new main rows)"]
    S3Branch["seg_03_trial.tseg + del_02_trial.tdel"]
  end

  Base["Base Manifest v10\n(refs: seg_01, seg_02)"] --> S1
  Base --> S2

  Main["Main Head Manifest v11\n(refs: seg_01, seg_02, seg_03_main)"] --> S1
  Main --> S2
  Main --> S3Main

  Trial["Branch 'trial' Manifest v1\n(O(1) branch publication from v10 + seg_03_trial, del_02_trial)"] --> S1
  Trial --> S2
  Trial --> S3Branch

  Merge["Three-Way Segment Merge -> Main Manifest v12\n(Skips shared seg_01/seg_02; checks PK B-tree intersection on seg_03_main vs seg_03_trial + del_02_trial)"]
  Main --> Merge
  Trial --> Merge
```

1. **$O(1)$ Branch-Head Publication:** Creating a branch writes a new branch manifest
   head (`refs/heads/trial -> manifest/v1`) referencing the exact same `.tseg`
   and `.tdel` object keys as the base snapshot $M_{v}$, and allocates an
   independent `TransitLog` partition for the branch's subsequent writes. Zero
   `.tseg` data bytes are copied.
2. **Isolated Branch Writes:** Mutations on the branch append to the branch's
   `TransitLog` partition and flush branch-owned `.tseg` segments and `.tdel`
   deletion bitmaps without altering any parent `.tseg` file.
3. **Sublinear Segment-Aware Three-Way Merge:** When merging branch manifest
   $M_{\text{src}}$ into target manifest $M_{\text{tgt}}$ from common ancestor
   $M_{\text{base}}$:
   - Any `.tseg` segment with identical `(segment_key, tdel_key)` across
     $M_{\text{base}}$, $M_{\text{src}}$ and $M_{\text{tgt}}$ is skipped in
     $O(1)$ metadata time—merge work is proportional to the **divergent delta
     segments**, never total table cardinality.
   - Primary-key conflicts between $\Delta M_{\text{src}}$ and
     $\Delta M_{\text{tgt}}$ are detected by intersecting the embedded `.tseg`
     footer primary-key B-tree indexes and `.tdel` bitmaps under the column's
     declared collation $\kappa$.

Branchable data declarations must identify application data separately from framework
records sharing its KV resource. An opaque byte copy cannot establish that an
arbitrary application's continuation is safe to execute. Such state remains
read-only evidence unless its owner supplies a validated branch initializer and
explicit fresh runtime bindings. The kernel checks generic authority and
publication rules; it does not infer application behavior from stored bytes.

Independent export is a separate operation from branching within a realm. It
needs its own destination/ownership and disclosure contract. Distinguish a
borrowed historical reference from a published independent copy: borrowed reads
keep the source's current permission and lifetime constraints.
An explicitly authorized independent export gives the destination its own data
ownership: later source revocation does not erase that copy, and source retirement
does not authorize deleting segments it still owns. Physical sharing must preserve
this same declared logical-copy contract. It cannot silently convert a borrowed
reference into an independent copy or extend the original resource's hard expiry.
The current API implements retained reads, not writable branching or independent export.

Copy-on-write needs deletion markers, correct source/child overlays or resource
roots, bounded ancestry lookup, durable segment ownership and race-safe reclamation.
Branch deletion cannot remove `.tseg` or page objects reachable by another live
manifest or owner. Logical expiry, reference release and physical reclamation
stay separate; retention is unlimited unless explicitly opted into. Resident
memory must remain independent of retained branch count and data size. A claim
of fast branching requires measuring creation latency, bytes copied, ancestor
read cost and reclamation under failure, not merely observing shared hashes.

### Merge, restore and execution are different operations

A three-way merge compares a common base and both immutable heads. It produces a
staged candidate plus typed conflicts before any destination changes. KV can use
per-key three-way comparison; Tables additionally need stable schema/row identity,
constraint validation and explicit key-change semantics. Opaque values cannot
silently acquire field-level merge semantics. Document changes can use the
Document algebra only with compatible causal history, epochs and fresh replica
identities; a generic row merge is not a substitute. Graph mappings and endpoints
must be validated against the candidate, and derived indexes/results must be
rebuilt or verified against that same basis.

Conflict-free edits can still violate a cross-row uniqueness or graph constraint.
Never infer domain validity from disjoint keys. Conflicts between branch versions
are durable merge-review records; they are not automatically the existing
Document conflict cell state. Resolve them with explicit policy or reviewed
changes, and conditionally publish against the unchanged destination head. If it
moved, replan; never overwrite intervening work as an optimization. Ambiguous
merge bases need a specified policy or rejection, not an arbitrary ancestor.

Restore publishes a new successor whose selected application data/definitions
come from an old snapshot. It retains the prior head, provenance and all current
authority/effect-control evidence. It is not a rollback of the native realm.
Schema-only promotion applies a validated migration to current destination data;
it does not replace that data with the branch's empty tables. An inverse data
migration must be defined rather than assumed.

```mermaid
flowchart LR
  Base[Accepted snapshot A] --> Main[Main snapshot B]
  Base --> Trial[Trial snapshot C]
  Main --> Review[Staged merge and conflict validation]
  Trial --> Review
  Review --> Next[New main snapshot D]
  Policy[Current policy and fenced owner] --> Next
  Evidence[Existing effect and retirement evidence] --> Next
```

The diagram describes a proposed publication, not concurrent multi-resource
transactions. Existing processes, accepted mailbox progress, call identities,
outboxes and potentially in-flight effects cannot be copied into newly executable
work. Branch execution starts with fresh identities and explicit input bindings.
Past captures can be replay inputs; a missing outcome remains unavailable/unknown,
not permission to redispatch. New branches default to external effects disabled.
Running new I/O requires explicit destination/credential/activation policy.

Merging or restoring data can change a maintained query's results. Activation must
specify whether to backfill, recompute or emit new deltas, with stable identities
for any newly authorized intents. Replacing data cannot undo an external payment,
HTTP request or published message. Application-owned security state also needs
review: copying an old access-control table cannot revive Transit permissions.
A restore that would contradict irreversible domain outcomes needs reconciliation
or refusal; retaining the effect ledger alone does not repair the domain state.

### What would establish the design

The desired improvement is a declared, inspectable closure across schema, data,
graphs, Documents and captured computations, with explicit merge and effect
boundaries. This is a testable target, not measured superiority over Dolt or Neon.
Full snapshots must reproduce their historical names/types/view definitions;
branches must isolate writes and deletes; schema-only promotion must preserve target
rows; stale merges must reject; and revocation, expiry and retirement must never
be undone by selecting old application data.

Independent small models should enumerate base/left/right edits, renames,
drop/recreate, conflicting conversions and Document tombstones. Compare the
published result with an independent merge oracle and recompute all derived
results. Inject loss before/after publication, concurrent head changes and page-GC
races. Grow data and branch counts beyond resident caches while recording actual
memory, copied bytes and retained reachability. Use disk-backed recovery and
fresh callers, not only an in-memory manifest test.

No such branch proof or benchmark ran for this analysis. Reproduction begins at
the stated Transit/peer revisions and the existing state, retained-read,
publication and migration proofs linked above; those prove only their existing
profiles. Open questions are branch/storage interfaces, catalog
closure across independent owners, typed merge coverage and retained artifact
availability. Supporting application schema revisions within the current
descriptor format is compatible with a single current v1 contract; it does not
authorize fallback decoding of incompatible historical Transit formats.
