# 7. Logical document storage, `.tseg` trees and Station decoupling

[Roadmap](README.md) · [Foundation #125](https://github.com/spoke-sh/transit/issues/125) · [Native State #126](https://github.com/spoke-sh/transit/issues/126) · [Layouts & Codecs #128](https://github.com/spoke-sh/transit/issues/128) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress — Causal maps, conditional ordered/versioned trees, retained topology inspection and verified JSON/XML/MIME raw parts are integrated as storage components. Retained partition membership, logical deletion and partition-aware transaction guards are implemented at the component boundary. Next finish staging/discovery contracts and protected staging, then direct lifecycle and transaction participation alongside the remaining merge/physical-layout work. The Station/consumer replacement retains one coordinated cutover gate ([remaining implementation plan, 2026-11-05](#implementation-plan-for-remaining-work)).

Decouple `Document` (`DOCUMENT`) completely from the `Station` durable actor
runtime ([`transit-station-document`](../../packages/zig/transit-station-document/README.md),
[`STATION_DOCUMENT_V1.md`](../../contracts/STATION_DOCUMENT_V1.md) and
[`STATION_INDEX_V1.md`](../../contracts/STATION_INDEX_V1.md)), replace the
96-byte JSON/CRDT KV-turn format with a **logical algebraic Document model
($\tau \perp \kappa \perp \epsilon$)** in the Direct Data Plane, and implement
**`DocumentPartition`** in `transit-storage` over `TransitLog` (`TWAL1`) and
immutable `.tseg` segments using succinct tree topology bitvectors, adaptive
columnar path shredding, raw-frame coverage commitments and pluggable
revision/merge profiles.

## Prerequisites and architectural rationale

Follow the [declarative data lifecycle](01-declarative-data-lifecycle.md),
[local storage hierarchy](02-storage-and-query-performance.md),
[live storage/SQL cutover](03-live-storage-and-sql-cutover.md),
[statement results](04-statement-results-and-consumption.md),
[transactions](05-transactions-and-atomic-composition.md) and
[declarative streams, queues and durable runtime](06-streams-queues-and-durable-runtime.md).
Start from the [data model](../handbook/reference/data-model.md),
[Document reference](../handbook/reference/documents.md),
[state model](../handbook/internals/state-model.md),
[storage runtime](../handbook/internals/storage-runtime.md) and
[query engine](../handbook/internals/query-engine.md).

The initial architectural review of [`STATION_DOCUMENT_V1.md`](../../contracts/STATION_DOCUMENT_V1.md)
and [`transit-station-document`](../../packages/zig/transit-station-document/README.md)
alongside the [Milestone 6 SQL database cutover](06-streams-queues-and-durable-runtime.md#sql-database-runtime-cutover--2026-10-28)
identified three structural mismatches between the installed `Document`
implementation and Transit's storage and query architecture. The descriptions
below preserve that diagnosis; the [current source audit](#delivered-basis-and-remaining-obligations)
accounts for the components delivered since then:

1. **`Document` remained coupled to `Station` actor turns and `STATE_V1` 256-byte KV limits:**
   The direct Table path and `transit-sql` are independent of `Station` actors.
   `StreamPartition` and `QueuePartition` now have direct owners and callers;
   the common mixed decision now composes Table/KV/Stream/Queue work, while
   transactional Station replacement remains
   [Milestone 6](06-streams-queues-and-durable-runtime.md) work.
   `Document` remains a `Station` service
   (`transit-station-document`) layered over [`STATION_PUBLICATION_V1.md`](../../contracts/STATION_PUBLICATION_V1.md),
   4 KiB 8-ary `SIX1` B-tree nodes ([`STATION_INDEX_V1.md`](../../contracts/STATION_INDEX_V1.md))
   and [`STATE_V1.md`](../../contracts/STATE_V1.md) actor turns (capped at four
   256-byte KV mutations per turn). Naming a Document in `DirectCatalog`
   required a three-turn `Station` `NamedResource` handshake (`reserve` $\to$
   `service init` $\to$ `verify empty head`), and remote edits required `STN1`
   actor calls (`SDQ1`/`SDT1`/`SDO1`) with single-active-job serialization.
2. **A fixed JSON-like CRDT wire format with 96-byte string ceilings instead of a logical Document model:**
   `SDC1` hardcodes a JSON-like register/list tree where inline strings and
   binary scalars are capped at **96 bytes**, map field names are unnormalized
   1–64 byte UTF-8 strings, a change contains at most 8 operations, and growing
   editable text is decomposed into **one `u32` Unicode scalar per CRDT
   element** (requiring thousands of B-tree entries and bounded 32-step
   continuation pages to read a single paragraph).
3. **Isolation from Transit's $\tau \perp \kappa \perp \epsilon$ storage and vectorized query engine:**
   Because `Document` state lived in `SIX1` KV blobs rather than `.tseg`
   segments, Document paths and text could not use physical column codecs
   (`.dictionary`, `.fsst`, `COMP-3`, `ZONED`, `EBCDIC`), declared collations
   (`utf8_binary`, `ascii_ci`, `ebcdic_cp037`, `icu:<locale>`), 16-byte
   collation-prefixed Umbra/German strings ([Milestone 15](15-vectorized-strings-and-search.md)),
   collation-aware zone-map pruning, vectorized `Fuze` scans or single-round-trip
   [Milestone 5](05-transactions-and-atomic-composition.md) database commits.

This milestone brings `DOCUMENT` into the Direct Data Plane alongside `TABLE`,
`KV`, `STREAM` and `QUEUE`, supplies the Document facet to the shared Station-free
client foundation already being built in [Milestone 9](09-client-foundation-and-language-apis.md),
and establishes the storage boundary for
[Milestone 17](17-document-profiles-and-gateway-exchange-lifecycle.md)'s
multi-format Document Type Library (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`) and
gateway exchange capture.

## Logical Document model ($\tau \perp \kappa \perp \epsilon$)

| Dimension | Logical & physical contract in `DocumentPartition` |
| --- | --- |
| **Logical type ($\tau$)** | A rooted, ordered, attributed tree + envelope (and optional multi-part **Container Graph** `Container -> Parts -> Trees/Tables/Spans`) of typed nodes (`map`/`element`, `attribute`/`header`, `list`/`sequence`, `scalar`, `span`, `part_ref`) with five-state cell semantics (`value`, `null`, `missing`, `type_error`, `conflict`) and exact `(part_id, byte_start, byte_end)` raw-frame provenance |
| **Collation & segmentation ($\kappa$)** | Declared per-document and per-path collations (`utf8_binary`, `ascii_ci`, `ebcdic_cp037`, `icu:<locale>`) and deterministic linear, structural and spatial/layout span segmenters governing key lookup, path comparison, range pruning and sequence slicing |
| **Physical layout & codecs ($\epsilon$)** | `.tseg` succinct tree topology bitvectors ($2N$-bit Balanced Parentheses `BP` / `LOUDS`), Dremel/ClickHouse-style shredded subcolumns, `.dictionary` and `.fsst` compression, mainframe/numeric/fixed-point codecs (`COMP-3`, `ZONED`, `NTP` 64-bit fixed-point), `.tdel` Roaring bitmaps and verified raw-frame/part slices |
| **Revision & merge policy** | Uniform revision lineage header `(DocumentId, RevisionId, ParentRevisionIds, MergeEpoch, DefinitionId, LineageKind, CoverageDigest)` supporting `immutable_lineage` (including incremental container/trailer appends such as `PDF` `%%EOF` or `MIME` attachments), 3-way structural merges and the `causal_crdt` observed-remove register/sequence merge profile |

## Delivery sequence

This is the full milestone target, not a list of installed capabilities.
The completion packages below sequence implementation against the current source.

1. **Sever `Document` from `Station` (`transit-document` / `DocumentPartition` $\perp$ `Station`) and unify catalog lifecycle.**
   Remove `Station`, `STATION_PUBLICATION_V1` and the three-turn `NamedResource`
   actor initialization ceremony from the `DOCUMENT` catalog and storage path.
   Introduce `DocumentPartition` in `transit-storage` sharing `TransitLog`
   (`TWAL1`), `TransitObjectStore` (`.tseg` / `.tdel`), `DirectClientToken`
   idempotency (`(AccountId, ClientToken) -> OperationId, CommitLSN, OutcomeReceipt`),
   `ReadCache` snapshot leases and `policy_epoch` fencing with `TablePartition`,
   `StreamPartition` and `QueuePartition`:
   - `CREATE DOCUMENT`, `ALTER DOCUMENT`, `RENAME DOCUMENT` and `DROP DOCUMENT`
     execute directly through `DirectCatalog` and `DocumentPartition` with zero
     `Station` actor turns.
   - Single-partition Document admissions and updates commit in **one round-trip**
     to the partition's `TransitLog` (`TWAL1`).
   - Enforce package-level build gates rejecting transitive `Station` imports in
     `transit-document`, `transit-storage`, `transit-catalog`,
     `transit-query-direct` and `transit-sql`.

2. **Define the logical Document algebra, revision header and pluggable merge profiles.**
   Replace `SDC1`/`SDS2`/`SDR1` with a neutral logical Document contract in
   `transit-protocol` that removes the 96-byte scalar string/binary ceiling,
   64-byte field-name limit and 8-operation per-change cap (enforcing explicit
   deployment and request byte/node quotas instead of format-tag limits):
   - Every committed Document revision binds `(DocumentId, RevisionId,
     ParentRevisionIds, MergeEpoch, DefinitionId, LineageKind, RawFrameCommitment)`.
   - Separate **logical tree storage** from **merge policy** via explicit
     profiles declared on the `DOCUMENT` object:
     - **`versioned` / `immutable_lineage` profile:** Append-only revisions,
       whole-document or path-patch updates under optimistic concurrency
       guards, and three-way structural tree merges for application records,
       versioned specifications and captured protocol documents.
     - **`causal_crdt` profile:** Preserves Transit's deterministic
       observed-remove multi-value register semantics (concurrent unseen
       assignments retained as explicit `conflict` alternatives with their
       operation dots `(counter: u64, replica: u64)`, resolved only by an
       assignment naming the observed dots), parent-removal detachment rules,
       descending-dot sequence ordering, and opted-in finite merge-window
       checkpoint compaction—executed directly by `DocumentPartition` over
       `.tseg` trees without `Station` actors.
     - **Span-based collaborative text (`rope` / `piece_table`):** Replace
       per-Unicode-scalar `u32` B-tree elements with UTF-8/scalar span blocks
       over `.fsst`-compressed `.tseg` pages, supporting arbitrary-length text
       inserts/deletes with stable anchor dots `(counter, replica, byte_offset)`
       and $O(\log B)$ block traversal.

3. **Implement `.tseg` succinct tree topology and zero-copy span storage in `DocumentPartition`.**
   Replace pointer-chasing 4 KiB `SIX1` B-tree nodes with 64-byte cache-line-aligned
   `.tseg` structural column groups:
   - **Succinct Tree Topology ($2N$-bit Balanced Parentheses `BP` or `LOUDS`):**
     Encode document tree hierarchy as a compact bitvector paired with two-level
     `@popCount` rank/select lookup blocks so `parent(v)`, `first_child(v)`,
     `next_sibling(v)`, `subtree_size(v)`, `depth(v)` and Lowest Common Ancestor
     (`LCA(u, v)` / `WITHIN(inner, outer)`) execute in $O(1)$ register
     instructions without pointer chasing.
   - **Parallel Node Attribute & Span Streams:** Store node tags (`map`,
     `element`, `attribute`, `list`, `scalar`, `span`, `conflict`,
     `type_error`), dictionary-coded field/tag symbol IDs, causal operation
     dots (when `causal_crdt` is active), and `(page_id, byte_start, byte_end)`
     span coordinates as bitpacked `.tseg` streams.
   - **Verified Raw-Frame, Multi-Part Container & WiscKey Out-of-Line Blob Storage:** Retain immutable
     staged raw byte/text frames, $> 4\text{ KiB}$ large scalar/attachment payloads
     (using WiscKey-style out-of-line blob `.tseg` segments so document tree
     compaction and [Milestone 21](21-branches-merges-and-restore.md) branch
     merges share large payloads in $O(1)$ without rewriting them), and
     multi-part container directories (such as `MIME` multipart bodies,
     `OPC`/`ZIP` package parts for `DOCX`/`XLSX`/`ODF`, and `PDF` `xref`/stream
     objects, verified by SHA-256 chunk coverage commitments and bounded by
     explicit decompression quotas) in `.tseg` blob pages so slices borrow
     directly from swizzled LeanStore/Umbra RAM/NVMe buffer slabs.

4. **Implement adaptive columnar path shredding (Dremel / ClickHouse style) into `.tseg` subcolumns.**
   Bridge semi-structured Document flexibility with columnar analytical scan
   speed:
   - Shred declared schema paths and frequently occurring paths into native
     typed `.tseg` subcolumns (with definition/repetition levels or sparse
     presence bitmasks), while storing unshredded or high-entropy paths in the
     succinct residual tree column.
   - Equip every shredded subcolumn with five-state cell tags (`value`, `null`,
     `missing`, `type_error`, `conflict`), declared collations ($\kappa$),
     collation-aware Zone Maps (`min`, `max`, `null_count`, `missing_count`,
     `conflict_count`) and composable codecs (`.dictionary`, `.fsst`,
     bitpacking, `COMP-3`, `ZONED`, `EBCDIC`).
   - Push SQL and path predicates (`doc.field = 'x'`, `doc.amount > 100`,
     `doc.field IS CONFLICT`, `doc.field IS MISSING`) directly into `.tseg`
     zone maps and subcolumn vectors in `Fuze`, deferring residual tree
     reconstruction via late materialization until a document passes all filters.

5. **Integrate `DocumentPartition` into [Milestone 5](05-transactions-and-atomic-composition.md) transactions, SQL and `Fuze` execution.**
   Connect `DocumentPartition` to the shared database transaction and query
   surfaces:
   - **Transaction participation:** Implement [Milestone 5's](05-transactions-and-atomic-composition.md)
     Participant Category 1 (`TABLE`/`KV`/`DOCUMENT` state mutations and
     conflict guards) for `DocumentPartition` so interactive and programmatic
     transactions atomically combine Table DML, Document revisions/patches,
     `STREAM` `PRODUCE INTO` and `_lease_epoch`-guarded `QUEUE` `ACK`s.
   - **Declarative SQL and typed-caller operations:** Expose `CREATE DOCUMENT`,
     `ALTER DOCUMENT`, `DROP DOCUMENT`, document admission/mutation/merge,
     bounded path/sequence reads and relational `SELECT` projections over
     Document collections through `transit-sql` and typed callers using shared
     [Milestone 4 `ResultSet`s](04-statement-results-and-consumption.md).
   - Preserve five-state cell propagation (`missing`, `null`, `type_error`,
     `conflict`, `value`) across SQL projections, joins and aggregations without
     picking an arbitrary conflict winner or converting `missing` to `null`.

6. **Execute the current-v1 hard cutover across `Station`, SDKs, examples and Board.**
   Apply the [v1 hard-cutover policy](../handbook/reference/versioning.md):
   - Replace `STATION_DOCUMENT_V1` (`SDC1`/`SDS2`/`SDR1`/`SDQ1`/`SDT1`/`SDO1`)
     and `SIX1` document storage with the new `transit-document` /
     `DocumentPartition` v1 contract; reject old stored formats and saved
     requests before execution without fallback decoders.
   - Re-architect `Station` behaviors that hold document state to read and
     mutate declared database `DOCUMENT` objects inside their
     [Milestone 6](06-streams-queues-and-durable-runtime.md) transactional turns.
   - Migrate all ten public SDKs, `examples/station-document` and Board's
     read-only Document inspector together, and update
     [`documents.md`](../handbook/reference/documents.md) and
     [`state-model.md`](../handbook/internals/state-model.md).

## Implementation plan for remaining work

**Plan basis:** fetched `origin/main` at
`c4dd89c2224ab53fd9139f2f89c328e8ca0b3f25`, 2026-11-05.
This refreshes the 2026-11-03 plan at `63f6369d5` and the subsequent integration
at `47f79de29`; C0–C8 remain the stable completion packages. The
[initial plan](#implementation-plan-for-initial-document-decoupling) and dated
delivery/evidence records retain their scope and attribution. Only merged source
is treated as available; work in other branches or worktrees is not a prerequisite.

During implementation, main advanced to `d8b756f08` with the M6 SQL Queue WAIT
contract and original-operation resume path ([#386](https://github.com/spoke-sh/transit/pull/386)).
The integrated source preserves that work; the handoffs below distinguish its
delivered Queue wait profile from the remaining Stream waits and mixed SQL.

The audit reads the neutral Document types, `DocumentPartition`,
`DocumentOrderedTree`, `DocumentShredder`, catalog authority/lifecycle, transaction
guards/workspaces and their public owners. At this source,
[`Growth.current_definition`](../../packages/zig/transit-protocol/src/Growth.zig)
is `4a79430a0f740284cda72df8341f0af87a87a63a599d7a81c62a934778875e1a`;
earlier qualification records retain their own definitions and revisions.
The source audit confirms that `DirectResource` still requires native Document
allocation, `TableAuthority.Profile` still has no Document domain, and
`Transaction.Guard.requirePagedState` / `Participant.requireLocalState` still
refuse Documents. `DocumentShredder` is still an in-memory component. Those
are implementation gaps, not consequences inferred from milestone status.
This planning refresh executes no runtime qualification; it changes no contract
definition, capability or milestone status.

**Outcome:** an application declares a Document object, applies causal or
versioned changes, reads exact accepted revisions and relational projections,
and recovers its original outcome after disconnect or restart without a Document
worker. A Station behavior uses that same data owner inside a transaction that
also settles its input and records outputs. M7 remains **In Progress** until
both journeys, the physical storage path and the affected consumer cutover pass.

### Changes since the previous source assessment

Use the merged changes below as implementation inputs, retaining each proof's
own revision and limitations. An adjacent feature's successful tests do not
qualify a new Document consumer.

| Merged work | Consequence for this implementation plan |
| --- | --- |
| [Document collection cuts, #370](https://github.com/spoke-sh/transit/pull/370) | Retained partition membership and owned head pages are delivered. Begin with their missing installed ownership, deletion/absence, discovery and transaction contracts; do not reimplement enumeration. Preserve the [recorded component evidence](../history/qualification/storage.md#retained-document-partition-membership--2026-11-03). |
| [M6 Stream groups and offsets, #367](https://github.com/spoke-sh/transit/pull/367) | Explicit SQL group consumption and authenticated offset settlement are available. C5 reuses the same native progress evidence; mixed SQL and transactional Station remain open. Earlier descriptions of group/offset SQL as the next feature are superseded. |
| [M6 SQL Queue waits, #386](https://github.com/spoke-sh/transit/pull/386) | The shared wait observation/resume contract and unfiltered SQL Queue WAIT are delivered. Preserve original-operation identity across denied or interrupted observation; a pending observation is neither a new submission nor completion. Stream WAIT, predicates and mixed SQL remain open. C5/C6 reuse these owners without inventing a Document-only recovery loop. |
| [SQL scalar interface parity, #374](https://github.com/spoke-sh/transit/pull/374), [wire expectations, #377](https://github.com/spoke-sh/transit/pull/377), and [foreground conflict handling, #381](https://github.com/spoke-sh/transit/pull/381) | Carry exact logical descriptors through Document projections and shared results. Preserve the current co-hosted command/foreground lane and interrupted-write recovery. Primitive wire parity does not encode Document missing/type-error/conflict states or qualify every temporal/structured type. |
| [Typed relational ordering, #383](https://github.com/spoke-sh/transit/pull/383) | Fuze now supplies typed grouping, HAVING, ORDER BY and LIMIT with bounded external sorting; Board renders the admitted typed results. C6 must use these owners and preserve ordered failures, canonical ties and complete coverage. Persisted managed revisions have the new definition; old fixtures cannot be relabeled. Document sources and five-state aggregation remain separate admission work. |
| [Board workbook relations, #368](https://github.com/spoke-sh/transit/pull/368), [Run handling, #372](https://github.com/spoke-sh/transit/pull/372), and [responsive proof, #376](https://github.com/spoke-sh/transit/pull/376) | Keep the working unsaved workbook and explicit Run behavior as regressions. These changes add neither accepted Document saves nor durable workbook identity. M30 L2 still needs the non-browser C4 journey before L3/L4 persistence. |
| [Nightly container performance, #379](https://github.com/spoke-sh/transit/pull/379) | M13 now owns a published-image campaign. C8 needs separate matching-source Document measurements first; a promoted older image cannot qualify an unpublished Document implementation, and three independent authorities do not establish distributed transactions. |
| [Filesystem publication, #384](https://github.com/spoke-sh/transit/pull/384) | Candidate/part publication must reuse the shared immutable-file owner and preserve uncertain link/cleanup outcomes. Exercise the named-temporary path without rename flags. Local fault controls do not qualify EFS/Fargate durability or cross-client fencing. |

Earlier handoffs remain available: M16's bounded JSON/XML/MIME candidates,
M10's retained interpretation/collection, M14's owned predicate preparation,
M12's TXR1/CPR1/SOR1 ownership and batched managed pages, M20's immutable Table
forks, and M8/M9's direct dispatch and original-attempt clients. Their outstanding
qualification and broader features retain the owners in the dependency table.

### Delivered basis and remaining obligations

The [2026-10-30 component evidence](../history/qualification/storage.md#direct-document-protocol-succinct-algebra-tseg-shredding-and-documentpartition--2026-10-30)
records D0–D3 and the authority/graph portion of D4. The
[2026-11-01 causal storage evidence](../history/qualification/storage.md#integrated-causal-document-map-trees--2026-11-01)
adds evaluated map roots, disk reopen and authenticated value paging. Preserve
both records' source revisions and exclusions. The audit below includes the
retained-membership increment; the [partition guide](../../packages/zig/transit-storage/docs/document-partitions.md)
owns the component's current behavior. Component integration does not establish
an installed direct Document service.

| Boundary | Delivered implementation | Work still required |
| --- | --- | --- |
| Installed Document lifecycle | [Public Documents](../handbook/reference/documents.md), `transit-station-document`, `DirectResource` and `NamedResource` still use native resource allocation and Station initialization/publication | Replace that lifecycle and every affected caller together; preserve state/input/reply atomicity |
| Neutral contracts (D0, partial C0) | [`DOCUMENT_V1`](../../contracts/DOCUMENT_V1.md), full-width `DCHANGE1`, `DORDER01`, mandatory logical layouts/counts, retained ordered selections, tagged live/deleted collection heads, deletion evidence and partition-aware `DocumentGuard` bindings exist | Specify complete ancestry, causal sequences/spans, multi-request staging and installed collection selection/discovery; preserve existing ordered input rather than defining it again |
| Deterministic algebra (D1, partial C1) | [`LogicalChange`/`CausalTree` and `OrderedChange`](../../packages/zig/transit-document/README.md) supply maps and validated ordered input; storage derives conditional create/root/path replacement. `SpanText`/`VersionedMerge` remain component oracles | Integrate causal lists/span edits, paged three-way merges and validated logical checkpoints. Ordinal-path replacement currently rebuilds the result; it does not establish incremental patch costs |
| Physical layout (D2, partial C2) | [`DocumentOrderedTree`](../../packages/zig/transit-storage/src/DocumentOrderedTree.zig) persists residual node/name/value records, `2N` BP bits and verified raw parts through `DocumentIndex` `.tseg` rows. [`DocumentShredder.shredBatch`](../../packages/zig/transit-storage/src/DocumentShredder.zig) still builds only in-memory subcolumns | Add persisted navigation indexes, span pieces and shared typed subcolumns, with reconstruction and pruning against accepted segments. BP bytes in key/value rows do not yet implement the target column groups or zero-copy buffer path |
| Durable owner (D3, partial C3) | [`DocumentPartition`](../../packages/zig/transit-storage/src/DocumentPartition.zig) derives causal and ordered roots, checks expected heads and accepts with one fenced WAL append. Exact pinned logical pages own up to 240 payload bytes; retained membership pages own up to 16 live/deleted heads. Conditional deletion preserves pins and records permanent tombstones; point inspection omits private operation identities. Opaque mutations/checkpoints cannot replace logical roots | Install collection reads and add resumable protected staging, logical checkpoints and transaction preparation/decision visibility. Keep the opaque receipt seam out of public ingestion |
| Structural reads | `inspectOrderedNode` returns owned parent/child/sibling/depth/subtree metadata from retained BP chunks with current authorization and bounded memory | Replace repeated linear scans with measured persisted indexes where required. Current per-call bit/lookup budgets and a bounded depth stack establish neither constant-time navigation nor whole-tree validation |
| Profile handoff | M16 verified JSON/XML/MIME candidates preserve ordered duplicate members/headers, exact lexemes, mixed content, binary body bytes and raw spans through disk reopen | Complete-frame candidate construction still needs resident input/output buffers. Persist profile attestations and generic container relationships through an explicit M16 contract handoff; multipart parsing, transport/effect ownership and exchange replacement remain M16 |
| Recovery and cursor keys | `open`/`recoverStep` replay bounded units (default 64 records, permitted 1–256), reuse per-record scratch and refuse operations until ready. A nonzero host-supplied `read_secret` is mandatory | Preserve these safeguards while adding logical pages and transaction records; prove bounded candidate construction, checkpoint validation and installed cold recovery. Root readiness is not an exhaustive scrub or zero-allocation claim; define installed key persistence/rotation |
| Two deduplication identities | Same-operation retries recover their receipt. Identical causal changes under another operation receive a receipt for the first revision without advancing the head | Preserve both identities through new layouts, checkpoints, archive/trim and transaction preparation. Changed bytes at either identity must still refuse |
| Catalog/authority (partial D4) | [`DocumentAuthority`](../../packages/zig/transit-catalog/src/DocumentAuthority.zig) supplies masks/bindings; `DirectStorageGraph` walks Document roots | Add the actual Document domain/profile/registrar, typed lifecycle and payload operations, signed node dispatch, original-token recovery and installed disclosure checks. The configured profile still has the six database/schema/Table/Stream/Queue/KV domains |
| Mixed transaction owner (D5 prerequisite) | `DirectTransaction`, `TransactionDirectory`, private state/log workspaces and `TransactionDecisionLog` now execute Table/KV/Stream/Queue composition. Installed schedules recover original mixed decisions and explicit paired Queue transfers. Document targets/guards and paged neutral directories now preserve logical partition ordinals | Documents still reject in `Participant.requireLocalState`, `Guard.requirePagedState`, `DirectCatalog` selection and decision preparation. Add a partition-aware Document cut/workspace/preparation path; removing rejection branches alone is insufficient |
| SQL, shared clients and installed consumers (D5) | M4 results, M6 workload settlement including original renewal handles, M8 local dispatch/startup continuations, M9 Catalog/context/recovery, and M30 independent read-only inspection exist | Add direct Document dispatch, SQL lowering and queries; migrate Station/ABI/SDK/Board/examples under the current-v1 policy. Board persistence and M16 profile publication still require the new public owner |

The [ordered topology qualification](../history/qualification/storage.md#retained-ordered-document-topology-inspection--2026-11-02)
records the one-page-cache disk fixture and the earlier storage-query lane;
the [profile handoff qualification](../history/qualification/storage.md#ordered-document-profile-handoff--2026-11-02)
records JSON/XML/MIME reopen, a later `check::core` and SDK-conformance lane.
The former core task coverage used an interrupted run plus a continuation;
the latter `check::core` is not the separate core CI lane. These are scoped,
source-attributed passes, not a combined qualification of this plan's new basis.

#### First integrated storage slice — 2026-11-01

The merged first increment connects canonical causal
map changes to paged evaluation, `.tseg` storage and fenced WAL acceptance.
`DocumentPartition.applyCausal` derives logical roots and conflicts; duplicate
causal changes under new operation identities retain their first revision.
Pinned path reads return owned, authenticated value pages with cumulative
budgets and current disclosure checks. Retention follows accepted logical
directories and segments and refuses corrupted state descriptors before format
dispatch. The [contract](../../contracts/DOCUMENT_V1.md#integrated-causal-map-tree-storage-slice)
and [partition guide](../../packages/zig/transit-storage/docs/document-partitions.md)
own exact behavior and bounds; [qualification evidence](../history/qualification/storage.md#integrated-causal-document-map-trees--2026-11-01)
records executed checks and their limits.

This delivers parts of C0 and the causal C1–C3 path, without completing those
packages. It uses the paged `DocumentIndex` map/register representation; BP
topology, adaptive subcolumns, list/span edits, versioned merges and logical
checkpoints remain integration work. Direct catalog/client/SQL exposure,
collection routing and scans, Document transaction participation and the
Station/consumer cutover remain open. The installed Document API still uses
Station; the new path is a private storage-library API.

The D0–D5 labels remain attributable delivery slices. C0–C8 below are completion
packages, including integration gaps in D0–D3; they do not erase the earlier
component work or declare D4 complete.

### Changes to the previous plan

1. **Start after the ordered-storage increment.** Canonical ordered input,
   conditional create/replace/path patches, persisted BP/raw parts and verified
   profile-to-disk handoff are available. Retained collection cuts are now also
   component operations. Keep them as regressions. Finish their installed
   ownership/selection contracts and protected candidate ownership so catalog
   callers and transactions can use those roots safely.
2. **Separate development dependencies from release gates.** C4 lifecycle and
   C5 participant work can use the existing evaluated causal/ordered layouts
   after their C0/C3 contract subsets pass. They need not wait for every span,
   merge or subcolumn optimization. All C0–C8 obligations still gate completion
   and the coordinated public replacement; a private caller fixture is not a
   second supported Document engine.
3. **Close the remaining semantic and physical work explicitly.** Conditional
   path replacement is not three-way merge; persisted BP is not indexed
   navigation; an in-memory shredder is not a durable analytical access path;
   recovery checkpoints are not validated causal merge-window checkpoints.
   Each gets its own review unit and disk/failure evidence.
4. **Use current handoffs.** Reuse owned predicate preparation, current-cut
   capture, typed relational ordering and shared managed-page/staging infrastructure
   only where the Document lifetime and five-state contracts apply. Preserve #359's distinction
   between acceptance being possible and an observed operation ID, its bounded
   owner reuse, and collection fences. M6 renewal is delivered; its unresolved
   runtime/maintenance gates are not new M7 implementation tasks or passed proof.
   Grouped Stream progress is also delivered; its authenticated coverage is the
   C5 input-settlement basis, not a caller-supplied row count. Preserve #381's
   foreground conflict handling and #384's immutable publication behavior.
5. **Keep consumer authority with its owner.** M7 supplies M30's conditional
   saves, collection listing and original accepted-operation discovery. M16 owns
   profile-attestation publication and exchange migration over M7 storage.
   M6 R7/R8 supply transactional Station and effect/delivery replacement. The
   plan neither installs Board persistence nor replaces `STATION_EXCHANGE_V1`.

### Milestone context and dependency handoffs

| Owner | Consume now | Dependency or boundary for M7 |
| --- | --- | --- |
| [M1–M3: lifecycle and local storage](03-live-storage-and-sql-cutover.md) | Stable object/definition identities, direct catalog names/dependencies, `LocalWal`/`LocalSegmentStore`, publication guards, retained graphs and local installation | Preserve original named-Document lifecycle/recovery coverage while replacing its mechanism. M3 remains independently In Progress; M7 does not close its other storage or latency gates |
| [M4: statement results](04-statement-results-and-consumption.md) | Implemented command/`ResultSet` distinction, bounded consumption and terminal observation | Use `transit-sql-results` and `transit-sql-client`; no Document-specific SQL result or recovery protocol |
| [M5: transactions](05-transactions-and-atomic-composition.md#selected-delivery-profile-and-exclusions) | Completed local serializable Table profile, common cuts, durable preparations/decisions, private workspaces and savepoints | Its completion excludes direct Document and log settlements. C5 supplies Document obligations to the same decision owner |
| [M6: streams, queues and runtime](06-streams-queues-and-durable-runtime.md#completion-plan-at-current-main--2026-11-05) | Direct KV/logs and native mixed decisions; automatic terminal Queue transfers; SQL append/consume/claim/ACK/NACK/EXTEND LEASE, original renewal handles, explicit group consumption, authenticated offset settlement and unfiltered Queue WAIT with original-operation resume | Extend R5 with Document cuts/preparations. Stream WAIT, acquisition predicates, `STREAM_SLICE`, mixed SQL and complete resource/fault baselines remain open. R7/R8's real transactional Station/effect replacement gates C7; independent workload SQL does not supply atomic Document turns |
| [M8: gateway](08-gateway-architecture-and-protocol-ingress.md#connection-startup-continuations--2026-11-01) | Event-driven SQL recovery, typed local dispatch, node-cohosted execution, pure PG/MySQL command/startup continuations and host-owned TLS/credentials. Later startup/validator work has scoped measurements | Reuse host admission, output lifetimes and resumed-disclosure checks. Socket deadlines/scheduling, core-bounded workers, coarse remote SQL and Flight/Serving integration remain M8 work. Add no Document polling service or per-page HTTP orchestration |
| [M9: shared clients](09-client-foundation-and-language-apis.md#implemented-context-and-kv-recovery-increment--2026-11-01) | [`Catalog` and `Context`](../../packages/zig/transit-data-client/README.md), bounded data/control leases and admission waits, direct KV dispatch, frozen SQL submission and explicit `LocalRecoveryStore`/`SqlRecovery`/`KVRecovery` | Supply the minimal owned Document caller and compose its context facet; reuse the persist-before-send and original-outcome recovery boundary. Ordinary Catalog/log settlement, native principal coordination, aggregate accounting, managed handles and installed data-language APIs remain M9/M21 work; M7 cannot defer migration of existing affected consumers to them |
| [M10: historical interpretation](10-standards-and-catalogs.md#progress-pr-scope--2026-11-01) and [M11: indexes](11-indexing-and-access-paths.md) | Persisted interpretation, retained historical catalogs/SQL, distinct CP037 PAD SPACE/CP1047 NO PAD semantics and shared capability inspection; common-revision M10 closure remains open | Extend exact retained interpretation to Documents; Table historical SQL is not Document `AS OF`. Bind accepted collation/encoding descriptors without silently adding CP1047/ICU to the Document profile. M11 owns secondary indexes; M7 owns base tree/subcolumn access |
| [M13: dataflows](13-sql-and-dataflows.md#next-implementation-slice-owned-staging-and-finite-qualification) | Installed finite Table computations, immutable DFR1 results, TXR1 candidate collection, CPR1 progress replacement and SOR1 original staging/closure; typed grouped/ordered finite execution now extends the shared compiler. Combined finite fault/resource qualification remains open | Reuse neutral ownership/graph seams for Document candidates and preparations. Retained declarations and completed revisions remain indefinite. Supply Document source/revision/change evidence; do not treat DFR1 as Document storage or enable continuous/multi-source Document activation through it |
| [M14: resource/performance](14-data-structures-and-performance.md), [M15: strings](15-vectorized-strings-and-search.md#encoded-predicate-reuse-increment--2026-11-01), [M16: compilation](16-data-centric-compilation-and-specialization.md) | Production lossless 16-byte Batch strings, safe external tails, allocation controls and shared per-column dictionary/FSST predicate traversal | Integrate `TSegReader`/`PhysicalCodecs` rather than the removed prototype evaluator. Preserve raw projection and ordered failures. Retained operator keys, full resource metering, durable search and AOT/adaptive compilation retain their own gates |
| [M17: profiles and exchanges](17-document-profiles-and-gateway-exchange-lifecycle.md#immediate-representation-gap-and-m7-acceptance-handoff) | Offline bounded JSON/XML/MIME readers/constructors, candidate capabilities and compound commitments; verified single-part candidates now survive M7 disk acceptance/reopen | C0–C3 still owe multi-request staging and generic container dependencies. Bind parser/profile/source attestations to accepted revisions through an explicit handoff before claiming verified profile publication. M16 owns parsers, unpackers and exchange capture; no `STATION_EXCHANGE_V1` replacement in M7 |
| [M20: interactive assets and simulation](20-game-asset-pipelines-and-simulation-streaming.md) | Planned consumer of generic Document trees, container parts and immutable revision identities | Preserve those generic storage boundaries. Asset importers, cooking dataflows, GPU/engine adapters and simulation streaming remain M19 and its M16–M18 prerequisites; they add no prerequisite to this storage slice |
| [M21: branches](21-branches-merges-and-restore.md#local-table-branch-increment) | Durable immutable single-Table branches, discovery/retirement and immutable forks with independent owned pins, bounded ancestry/manifest helpers and collection/disclosure checks | Begin Documents on branch one. Reuse pin-ownership and reachability patterns, while explicitly refusing Document branch operations. Versioned Document merge is not catalog branch merge; M20 owns multi-model branching and restore |
| [M22: interface coverage](22-service-and-sdk-coverage.md#sql-type-parity-and-installed-interface-smoke-loop) | Installed scalar parity and explicit admission across native console, PostgreSQL and MySQL, with an independent corpus and driver checks | Extend the actual type/admission matrix for Document projections, preserving exact decimals and five-state meaning. Keep Flight and unsupported wire representations refused; preserve the required installed SQL type loop when SQL/gateway paths change |
| [M23: formal correspondence](23-formal-semantics-and-correspondence.md), [M28: policy](28-control-and-policy-plane.md), [M29: published resources](29-published-resources-and-investigations.md) | Finite decision/workspace models, native grants, interpretation and current disclosure boundaries | Extend affected production replay/negative controls with the new participant; existing Table/log model checks do not prove Document atomicity. Preserve browser/application-migration gates; retained revisions are not investigation pins or a new policy authority |
| [M24–M26: providers, recovery and placement](24-storage-providers-and-concurrency.md), [M45/M45: qualification and releases](45-qualification-and-benchmarks.md) | Shared local file publication and artifact/provenance checks; broader provider and deployment profiles remain unqualified | Reuse local publication/collection fences and preserve original failures. C8 qualifies the local Document profile, not EFS, replication, failover or distributed commit. Add published-image Document coverage through M13/#378 only after an appropriate artifact is promoted |
| [M31: Board](31-board-reimplementation.md#local-connections-and-document-persistence-plan--2026-11-02) | Automatic local data access, reactive storage inspection, independent managed-computation reads and bounded unsaved workbook relations are merged; saved workbook/preferences/connection Documents remain planned | Deliver versioned expected-revision updates, ordered cells/long text, bounded logical-document listing and accepted-operation lookup through C0–C4. Prove the non-browser journey before M30 L3/L4. Existing inspection stays read-only; application saves use a separate typed caller. Basic drafts do not require M28 retained-result publication |

The storage-to-caller path is **C0 → evaluated C1/C2 subset → C3 → C4 → C6**;
each exposed logical operation crosses evaluation, disk persistence and recovery
before its adapters. The current causal/ordered subset starts that path now.
C5 can develop after its C0/C3 subsets against M6 R5's delivered participant owners. C7 joins
C4–C6 with M6 R7's state/input/output decision and R8 where consumers require it;
C8 qualifies the combined cutover. This breaks the apparent
M6/M7 cycle: M6 can qualify Table/KV turns first, M7 supplies its participant
without requiring a finished Station adapter, then both qualify Document turns.
Neither a Table-only transaction nor two recoverable commits opens that gate.

M16 can test its private ordered-tree/part candidate against C1–C3 before SQL
or Station is ready. M30 can test conditional saves through C4's non-browser
caller before analytical projections, but its installed persistence waits for
the coordinated public cutover. These are development handoffs, not alternate
release profiles or new dependencies on all of M16/M30. The full BP, span,
shredding, merge and consumer criteria remain required for M7 completion.

**Independent delivery scope:** storage and participant changes can land with
their own component evidence before installed exposure. The first integrated
slice above extends the earlier retained-read and replay safeguards with causal
map evaluation, persisted state and within-revision value paging. Its current
API and limits are in the
[partition guide](../../packages/zig/transit-storage/docs/document-partitions.md).
The remaining tree/span/shredder integration and C0–C8 obligations below still
require their own implementation and evidence.
Keep one supported public Document engine until the coordinated consumer
replacement passes; do not introduce a selectable second profile to work around
the remaining Station atomicity dependency.

### Selected delivery profile and decisions

Use one local catalog, branch one, disk-backed WAL/object storage and fenced
partition owners. Preserve the existing declaration's partition model:
a catalog `DOCUMENT` object has an immutable interpretation and partition
allocation; a logical `DocumentId` identifies a tree within that object.
A singleton application uses one logical document. C0 must make routing and
collection scan coverage explicit, including empty partitions; a single-document
revision is not an atomic collection cut. Begin installed qualification with
one partition, then exercise multiple partitions in the same local decision
domain before advertising that profile.

Keep object identity, logical DocumentId, definition revision, accepted revision,
merge epoch, causal dots, account/client token, operation ID, WAL position,
transaction decision and policy/owner epoch separate. Names resolve into frozen
identities. Changes, complete replacement values and merge requests use the same
authoritative evaluator and validation; arbitrary supplied state bytes are not
an accepted logical mutation.

Both `causal_crdt` and `versioned` remain milestone requirements. Preserve the
delivered causal-map and conditional versioned ordered-tree integration, then
finish causal sequence/span semantics and qualified three-way merges.
Treat `immutable_lineage` as a lineage requirement to resolve
in C0, not a third currently accepted profile tag. Retain observed-remove
conflicts, detached descendants, deleted anchors and explicit resolution.
Define byte/scalar coordinates for spans; do not silently add grapheme
normalization or locale behavior.

Initial supported collations remain the direct contract's `utf8_binary`,
`ascii_ci` and `ebcdic_cp037`. Use shared canonical comparison/prefix logic and
bind its descriptor in stored artifacts. Per-path overrides need explicit
definition semantics and fixtures. Unsupported ICU/version/codec combinations
must refuse; M10/M14 helper availability does not make them admitted storage
profiles. Keep logical type, ordering semantics and physical codec orthogonal.

Collection size, total revision history and text length must not determine
resident memory. C0 publishes numeric page, request, node/depth, staging, active
candidate, read-pin, response and recovery budgets; C2/C3 enforce them before
allocation/disclosure. Large logical values stream through bounded pages.
A format width or per-segment row cap is not a substitute for a paged directory.
Retain unlimited history by default, with separate explicit merge-window,
logical-retention and physical-cleanup decisions.

Use the following baseline boundaries when setting implementation budgets;
these are existing component limits, not proposed public defaults:

| Boundary | Current component basis | Remaining budget decision |
| --- | --- | --- |
| Logical payload page | At most 240 inline-owned payload bytes; authenticated exact-revision continuation | Batch multiple chunks under explicit row/byte/work limits without tying caller throughput to this record size |
| Recovery | Default 64 WAL records per step, allowed 1–256; resident directory pages default to 16 | Bound decoding, page visits and candidate/preparation work as well as record count; keep control/recovery capacity available |
| Candidate construction | Default 512 pending records, 256 KiB segment buffer, 2 MiB segment scratch and eight logical-index cache pages; ordered builders seal dirty batches | Freeze aggregate active-owner/staging quotas, cumulative index work and upload limits before concurrent installed use |
| Large inputs | Complete canonical request fits `change_bytes`; existing profile-to-storage construction holds bounded complete-frame input/output | Stream accepted 1 KiB–10 MiB values/text through bounded request/staging/read windows; do not allocate a whole-document arena to meet the workload |
| Topology and patch work | Linear BP prefix inspection and full-result ordinal patch reconstruction | Measure page visits and write amplification; qualify persisted navigation and incremental construction separately |

### Remaining work packages and gates

| Package | Reviewable outcome | Depends on | Exit evidence |
| --- | --- | --- | --- |
| C0 | Complete contracts, capability and migration inventory | Current source audit; delivered M5/M6 participant interfaces | Canonical fixtures, partition-aware transaction decisions, budgets and exact removal map |
| C1 | One database-owned logical evaluator for causal and versioned changes | C0; reuse D1 | Independent semantic equivalence, adversarial edits and refusal without partial state |
| C2 | Persisted tree/span/subcolumn representation | C0/C1; reuse D2 and M14 helpers | Shared segment round trips, page-boundary traversal, bounded construction and pruning equivalence |
| C3 | Integrated partition acceptance, reads, recovery and maintenance | C1/C2; reuse D3 | Real disk faults, original outcomes, paged reads/recovery and retained-graph collection |
| C4 | Direct catalog lifecycle, current authority and typed node/client operations | C0/C3 | Signed create/edit/read/recover journey without a Document worker or courier |
| C5 | Document common-cut/workspace/transaction participant | C0/C3; extend M6 R5's existing mixed owner | Atomic Table + Document + Queue ACK + Stream append through faults and revocation |
| C6 | SQL declarations, Fuze projections and shared results | C4; C5 for transactional statements | Actual compiler/service/console outcomes and five-state query equivalence |
| C7 | Station and all existing consumer migration | C4–C6 and M6 R7/R8 where affected | Installed ABI/SDK/Board/example/replacement paths preserve prior guarantees |
| C8 | Measured qualification and one current-v1 cutover | All preceding gates | Common-revision caller/fault/resource evidence, removals and public documentation |

No C package is complete at this baseline. C0–C3 include integrated causal maps,
conditional ordered trees, persisted BP/raw parts and retained structural reads;
persisted navigation indexes, span edits, adaptive subcolumns, merges and logical
checkpoints remain open. C4 has the authority/graph foundation only.
The owner map identifies the concrete extension seams, not new parallel authorities.

| Boundary | Implementation owners to extend | Review constraint |
| --- | --- | --- |
| Logical meaning | `transit-protocol.DocumentDeclaration`/`DocumentOperation`/`DocumentRead`; `transit-document` | One canonical mutation evaluator for standalone and transaction paths; explicit scratch/output lifetimes |
| Persistent representation | `DocumentIndex`, `DocumentShredder`, shared segment readers/writers, `TreeStore`, `DocumentPartition` | Persist residual values, causal evidence and spans alongside topology; candidate bytes are private until acceptance |
| Retention/recovery | `DocumentStorageRoots`, `DirectStorageGraph`, local maintenance and `DataStore` | Include preparations, raw parts, pinned cuts and unknown outcomes before permitting collection |
| Catalog and policy | `DirectResource` Document arm, `DirectCatalog`, `DocumentAuthority`, `TableAuthority.Profile`, `DirectIntent`/`DirectClientToken`, node catalog dispatch | Replace native Document initialization; preserve the already direct KV and log lifecycle and all existing token variants |
| Mixed decisions | `Transaction.Target`/`Guard`/`Participant`, `TransactionDirectory`, `TransactionDecisionLog`, `DirectTransaction`/`DirectTransactionWorkspace` and graph cleanup | Supply typed Document cuts and work; do not force Document semantics into Table row mutation or add a second coordinator |
| SQL and callers | `transit-data-client`, `transit-query-direct`, Fuze, `DatabaseRuntime`, `transit-sql-service`/`transit-sql-host`, SQL client/results | Use shared declaration settlement, source readers, metadata pagination and disclosure guards; expose only qualified operations |

#### C0 — Finish contracts and the migration inventory

Extend the existing [Document](../../contracts/DOCUMENT_V1.md),
[data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[direct operations](../../contracts/DIRECT_TABLE_V1.md),
[transaction bindings](../../contracts/DATA_LIFECYCLE_V1.md#transaction-bindings-and-evidence),
[storage](../../contracts/TRANSIT_STORAGE_V1.md) and
[SQL result](../../contracts/SQL_RESULTS_V1.md) owners before dependent adapters.
Do not invent another definition namespace or transaction coordinator.

Preserve the delivered canonical causal/ordered bytes and mandatory state
descriptors. Extend typed path addressing beyond the current ordinal patch
profile (including separator/escaping ambiguity), logical deletion,
revision-parent sets and raw-frame/part coverage. A
`raw_span` coordinate alone is not proof that bytes exist or match their source.
Pin schema, merge profile, collation and interpretation in every retained root,
intent and result. Define the generic part directory's identity, reference,
cycle/depth and byte limits; format-specific unpacking remains M16.
Resolve the old evaluator's `u64` Document/replica identities versus the direct
contract's 16-byte identities without truncation or hashing away equality.
Freeze multi-parent revision ancestry and the meaning of `immutable_lineage`
before persisting versioned merges; the current optional `parent_revision` is
not a complete arbitrary ancestry contract. Separate expected accepted head,
merge base and candidate parents. Extend the delivered conditional
create/replace/path-patch path with explicit three-way merge; a stale save must report
conflict without changing the accepted head. Keep canonical numeric values
separate from raw number lexemes and preserve duplicate ordered members as
syntax-tree nodes rather than overwriting them in a map.

Bind M16's existing `Event` and compound commitment types to a bounded candidate
builder. Specify when borrowed events cease to be valid, how complete parser
coverage is verified, and how a final manifest names immutable ordered trees,
raw parts and derived projections. Preserve shared/cyclic container relationships
as a graph with explicit traversal limits; BP represents each tree, not the
container graph. No parser completion or matching caller-supplied digest alone
authorizes publication of a logical root.

Define distinct recovery keys for an operation retry and an identical causal
change submitted under another operation. Both recover the original accepted
revision under current rights; changed content at either identity rejects.
Specify missing dependencies, stale replica/merge epochs and exact resync
evidence. Reject missing/foreign definitions before allocation or execution.

Define direct lifecycle, patch/replace/merge, original-operation inspection,
path/sequence/collection reads, accepted-tail reads, checkpoint/resync and close
operations. Bind cursor authentication to principal, target, cut, request,
coverage and live pin, using host-owned private key material. The component
already requires an explicit nonzero key; define durable provisioning, restart
reuse and rotation without orphaning original pins or silently reissuing reads.
Define incomplete progress, per-page versus total budgets, early close, pin lease
recovery and unavailable history explicitly.

Specify accepted-operation discovery as well as exact-token lookup. An authorized
replacement caller must be able to page accepted pending work by object/logical
document and owning account, recover the original canonical attempt and observe
its outcome without inventing a new token. Missing discovery is not rejection;
never imply recovery of edits that were never sent. Keep discovery, operation
ownership and payload disclosure rights distinct. This is M30's browser/Board
loss handoff, implemented in the shared caller/catalog owner rather than a UI
recovery database. Freeze the proposed 64 KiB read-page and 256 KiB save-request
budgets there only after owner measurements; they are not current Document limits.

Define private staging ownership before adding multi-call payload upload.
Reuse M12's transaction-owned root protection and the catalog's
[`DirectOwnedRecord`/`DirectProgressRecord`](../../packages/zig/transit-catalog/README.md)
reservation, readiness and closure semantics where applicable. Original-record
KV attachment does not attach a Document mutation or protect its part/root
inventory. Extend the catalog/storage contract for standalone Document
candidates. Record owner, operation, definition, root inventory and creation
fence before a collector can observe staged bytes. Resolve or fence uncertain
attachment before explicit
abandonment; elapsed time or a missing reply cannot authorize deletion. Duplicate
chunks, interrupted upload, late attach and shared part roots need exact outcomes.

Extend M6 R5's existing preparation, common-cut selection, savepoint and
publication guards before changing persisted transaction unions. Include absent
paths, collection scans and conflict alternatives in the serializable read
basis; initial whole-partition conflict guards are acceptable if stated.
In particular, `Transaction.Target.validate` currently permits an ordinal only
for Stream/Queue, and `Guard.state` carries the Table/KV `StateGuard`. A
Document declaration permits several partitions and many logical DocumentIds.
Add a Document-specific cut/guard with the owning partition ordinal and a
paged logical-head basis. Group all mutations of that partition into one
preparation, ordered alongside other owners; never prepare once per logical
Document and overwrite another candidate from the same partition. Define
collection-cut acquisition across all selected partitions, including empty
ones, and preserve `authorized_catalog_tables` SQL BEGIN scope until an explicit
mixed-selection contract is exposed. Do not merely permit `.document` through
`requireLocalState` or pretend its accepted root is a Table snapshot.
Decide supported ALTER fields; profile/routing/collation changes cannot
reinterpret accepted revisions. Record grammar, lowering, execution and transport
support separately in the capability inventory.

Inventory every legacy root/change/reference/wait, route, exported API, worker,
installation marker and test owner with its replacement and atomicity obligation.
Include unnamed Documents, checkpoint jobs, accepted tails, resync, recorded
remote reply routes and source/result references. This review is the first
implementation gate, not a request to expose the private components publicly.
Use a checked migration inventory with one row per public operation/artifact:
current owner, replacement, atomicity/retention obligation, affected consumers,
rejection fixture and installed proof. Add workload limits with units and exact
refusal points to the contracts: request/change bytes, operations, tree nodes
and depth, active candidates, staging, page/response bytes, cumulative read
steps/bytes, replay units and pin capacity. Record existing numeric limits
separately from proposed values; the 10 MiB text workload must use bounded
pages rather than require a 10 MiB response or whole-document scratch arena.

#### C1 — Connect canonical changes to the logical evaluator

Evolve `transit-document` behind explicit bounded reader/builder interfaces.
Keep storage, policy I/O, clocks and publication outside deterministic evaluation.
Unify the old map/register/list semantics with span text and versioned trees;
do not leave the old eight-operation/96-byte codec as the real execution path
behind larger declaration limits.

Compute resulting roots, conflict counts, causal frontiers, lineage and required
dependencies from verified accepted inputs. Define safe patch/merge behavior
against a stale base and explicit expected-head guards. A conflicting candidate
must not overwrite newer accepted state or silently pick a conflict winner.
Cover node-kind conflicts, subtree delete/edit races, sequence identity and
ordering, duplicate dots, partial-span deletion and multibyte boundaries.
Application-created values have no raw-byte provenance unless explicitly bound.
Define sequence tie-breaking against the full-width direct dot contract before
extending the map-only `DCHANGE1` format; do not assume the old counter/replica
ordering follows from the new encoded dot order. Preserve the specified
accepted-set semantics through independent sequence fixtures and explicit
current-v1 rejection of superseded requests.

For versioned merges, read base/left/right from exact retained roots, walk them
with bounded iterators, and stage a candidate without advancing the head. The
request must separately guard the current publication head. Freeze alignment of
ordered duplicate members, list elements and mixed content before implementing
the walker: ordinals in two independently edited trees are not stable identities.
The initial conservative rule should report an explicit structural conflict when
alignment is ambiguous, preserving both alternatives and provenance. It must not
silently zip by ordinal, collapse duplicate names or normalize raw lexemes.
Qualify that rule against an independent oracle before accepting it as a contract.

Use independent accepted-set and tree oracles, including the existing
24-permutation cases. Add changes exceeding the old name/scalar/operation caps,
nested and structural conflicts, invalid UTF-8/span offsets and exhausted
budgets. Check refusal leaves roots, replica frontiers and outcomes unchanged.
Keep resident helper trees as test oracles where useful; production mutation
must use the bounded persistent interfaces.

#### C2 — Persist succinct trees, spans and adaptive subcolumns

Extend the shared `.tseg` writer/reader and definition-bound metadata for
topology blocks, node tags, field symbols, ordered attributes/children, scalar
payloads, causal evidence, span pieces and generic raw-part slices. Reuse
`TreeStore` for paged directories, not as the replacement for every text scalar.
Store residual values and causal evidence as well as topology: a BP bitvector
alone cannot reconstruct a Document or its conflicts.

Connect `DocumentShredder` to durable segment groups. Preserve declared and
frequent-path selection, sparse/definition/repetition information, exact path
identities, all five cell states, raw provenance and residual reconstruction.
Adaptation changes physical placement only. Reuse dictionary/FSST and supported
numeric codecs through the existing physical owner, with `GermanString` as an
execution representation rather than a persisted process pointer.

Implement page-aware navigation and span seeks with explicit work accounting.
Measure the existing BP implementation before selecting extra rank/select,
excess or range-minimum indexes: `parent`/`lca` contain scans, so zero allocations
and two-level rank/select do not prove the delivery overview's O(1) target.
Likewise, a resident piece array is not an O(log B) disk rope. Document achieved
bounds and remaining targets in the implementation owner; do not declare those
criteria satisfied through naming.

Bind page checksums, alignment/padding, variable-sized payload handles and borrow
lifetimes to the shared buffer owner. No internal SIMD padding assumption may
escape to arbitrary caller slices. Freeze immutable pages before publication.
Validate subtree/text iteration across page boundaries with one-page caches,
deep/wide trees, high-entropy paths and 1 KiB–10 MiB values. Differentially
reconstruct against unshredded evaluation after disk reopen, codec changes,
deletion-vector application and compaction.

Keep the delivered ordered residual representation as the reconstruction oracle
while adding path promotion. Extend the JSON/XML/MIME disk fixtures to streamed
candidate construction and each new layout. Copy borrowed
events into owned candidate pages before advancing the parser. A late grammar,
length or hash failure leaves no accepted revision. Raw spans use half-open
offsets in a named immutable part; decompressed/decoded coordinates carry their
own source mapping. This opens the profile handoff without claiming all adaptive
subcolumns or external formats are installed.

#### C3 — Integrate acceptance, bounded recovery, retention and reads

Make `DocumentPartition` consume a verified C1/C2 candidate built against its
exact accepted basis, rather than trusting caller-supplied result bytes/counts.
Privately stage complete referenced objects and directories; publish the root,
revision, deduplication evidence and original receipt together under the current
publication guard. For a single-partition edit, retain one conditional data-WAL
acceptance append. Count catalog/token, staging and physical durability I/O
separately; that target does not mean one total fsync or network request.

Extend the existing bounded `recoverStep`/read-budget implementation with
mutation/checkpoint workspaces and page/unit scratch reuse. A record count
alone cannot bound decoding an arbitrarily large state or preparation. Resolve
duplicate causal identity through retained receipts, including after archive/trim
and when another token carries the same
change. Missing/corrupt state or evidence refuses recovery; no empty reset.
Checkpoint validation must retain causal/deletion/frontier evidence and cannot
accept an arbitrary supplied checkpoint blob.

Generalize the existing causal value pages to byte/step-bounded ordered-path,
sequence, raw-slice and revision reads; remove whole-state materialization from
the remaining logical paths. Retain one exact cut; distinguish progress-only
pages, genuine emptiness, terminal coverage and failed prefixes. Large values
need a continuation without exceeding the response budget. Ownership must survive
the next scratch reset, cache eviction and repeated fetch. Recheck rights after
buffering and before metadata, rows and terminal evidence.

Extend the existing graph for all new page types, raw parts, unfinished candidates,
transaction workspaces, read pins and original receipts. Unknown or incomplete
reachability blocks deletion. Separate finite merge-window floors/resync from
logical revision expiry and physical reclamation; live pins and unresolved work
remain protected. Integrate bounded local maintenance with Table/Stream/Queue
scheduling and reserved control capacity. Physical rewrites must not advance
logical revisions or invalidate original-operation inspection.

Use the shared owned-root machinery for prepared Document candidates and final
revision dependencies. Add standalone staging ownership where that machinery
does not yet apply. Test collection racing with stage/attach, lost admission
replies, abort, late attachment and shared parts. A generic unmarked object or
terminal work phase is not sufficient deletion evidence. Keep the collector
independent of profile parsers, Fuze and Station.

Reuse [`FilePublication`](../../packages/zig/transit-storage/src/FilePublication.zig)
through the object-store boundary. A named temporary's hard link can succeed
before an error or temporary-name cleanup failure. Reconcile the exact original
content/operation, preserve occupied files/directories/symlinks, and retain the
required file/directory barriers. Add those fault points to candidate/part tests;
do not add a Document-specific rename fallback. The
[filesystem acceptance procedure](../../tests/interfaces/installation/filesystems.md)
keeps local syscall evidence separate from hosted filesystem qualification.

Exercise process death and injected storage failures before/after object
publication, acceptance, receipt delivery, checkpoint replacement, trim and
collection. Use histories exceeding resident caches, cold reopen and fixed
memory/work budgets. Preserve the distinction between SIGKILL evidence and
host power-loss guarantees.

#### C4 — Complete catalog, authority, node and typed callers

Implement `DirectDocument` lifecycle and payload composition alongside the
existing direct owners. Reuse catalog operation/token/name/dependency directories
and frozen intents; remove the Document arm's PID/native-allocation requirement.
Use the delivered direct KV lifecycle as the initialization/recovery pattern;
do not reintroduce its removed writer-backed path. A Document-specific frozen
intent must coexist with Table, log, branch and transaction token variants.
Creation reserves the original object/partitions, accepts exact genesis
definitions, registers current native permissions and publishes only after
verification. Recover each interrupted phase with the same operation identity.

Add the Document authorization domain to public profiles, service configuration,
bootstrap/registrar, grants, generated contracts and strict caller decoders.
Use `DocumentAuthority` masks with current CONNECT/USAGE/CREATE, ownership and
replica checks; its standalone binding helper is not installed authorization.
Replace its current `.create_table` delegation with the agreed Document-domain
creation rule. A fixture using a Table-shaped metadata record does not establish
the new domain or its bootstrap grants.
Test revocation during staging, before acceptance, after buffering and during
receipt inspection. Cached grants, a PID or a replica ID cannot authorize work.

Qualify an independent reader principal from the first installed fixture. Follow
M30's independent computation-inspection boundary: the reader keeps its own
current grant while accepted metadata retains the writer's attribution. Do not
copy publisher credentials, relax generic operation ownership or scan unrelated
resources to make discovery work. Application saves and read-only operational
inspection remain separate permissions and caller operations.

Expose signed typed lifecycle/edit/read/inspect/checkpoint/close operations and
their owned response validation through the native node and
`transit-data-client`/public Zig SDK. Preserve request uncertainty and original
saved bytes through current token recovery and event-driven SQL settlement.
Compose Document calls with M9's data/control leases and owned outputs; retain
control capacity for original-outcome inspection and release during close.
Use M9's original SQL submission hook for SQL recovery. Typed Document attempts
need their own canonical saved reference; a local SQL store is not already a
Document recovery API, and client close must not cancel accepted work.
Integrate typed local dispatch through M8's existing host; do not add per-document
workers, an HTTP orchestration cascade or a periodic recovery poll.

Verify rename, DROP RESTRICT, retirement, DROP/name reuse, altered definitions,
lost genesis/publication replies and late reads against original identities.
Implement and test this replacement on the cutover branch while C5–C7 finish;
do not ship a second selectable Document engine or a temporary Station-backed
direct route.

#### C5 — Supply the Document transaction participant

Extend M5/M6's common owner, not just the participant enum. Add paged Document
cut acquisition, retained definitions, private mutation/read-your-writes state,
read/conflict guards, durable preparation, savepoint rollback, original decision
lookup, decision-aware reads and bounded finalization/cleanup. Include logical
document creation/deletion and absent-path/collection predicates; distinguish
logical mutation from flush or compaction.

The concrete changes are the C0 partition-aware `Transaction.Target`/guard,
`TransactionDirectory` key and evidence validation, a typed Document alternative
in `DirectTransactionWorkspace.StatementWork`/`StatementCompletion`, native
selection/staging/read controls, and Document preparation/decision readers in
storage. Keep the existing shared statement sequence, one pending slot,
permanent operation reservations and savepoint identity rules. Catalog reads,
decision graph traversal and cleanup must dispatch to the Document owner;
`TablePartition` remains the Table/KV preparation owner. Extend the affected
model replay fixture's typed pending-work handling with the same change.

Prepare Document roots without publishing them. Under ordered publication guards,
validate current policy, expected definitions and all participant bases, then
join the original commit/abort decision. Reopen and readers must consult that
decision before exposing any successor even when participant finalization is
interrupted. No handler rerun, automatic fresh SQL submission or independent
Document append may resolve an uncertain mixed commit.

First qualify Table + Document composition, then add M6's delivered exact Queue
lease ACK or Stream offset settlement and outbound Stream/Queue append. Fence lease
expiry/reassignment against the common decision. A successful Document merge
does not waive the input fence. One authoritative multi-partition decision can
require several preparation/finalization writes; preserve that distinction from
C3's single-partition fast path.
Include two logical Documents in one partition, two Document partitions, and
read-only Document dependencies alongside Table/log writes. Run mixed work with
the existing transaction resident limit; M6's installed tests already exposed
overlapping owner-cache allocations. Reuse bounded sequential owner lifetimes
where possible instead of increasing quotas or allocating every participant's
full workspace simultaneously.

Required schedules include rollback/savepoints, provisional query results,
write/write and absent-path conflicts, revocation on every participant,
crash at each preparation/decision/finalization point, expired leases and lost
COMMIT replies. Fresh readers observe all or none; accepted decisions and pins
survive replacement and collection. Unsupported participant combinations keep
typed refusals until their owning gates pass.

#### C6 — Lower SQL and Query through the direct owner

Define and implement the selected CREATE/ALTER/RENAME/DROP Document syntax
through shared typed lifecycle operations. Existing declaration compilation is
offline. Update the reference grammar, capability ledger and positive/negative
compiler corpus with the executable subset; specify mutation/merge syntax before
claiming it, retaining typed operations as the first mutation interface.
Reuse M6's frozen declaration-token and metadata-result paths for named
SHOW/DESCRIBE and paged Document listings. Metadata carries catalog/definition
observation, not an invented data snapshot. Exercise exact-definition changes
and revocation from a second session while metadata is buffered. Pending-work
enumeration must advance across branch, log and Document intents even when a
particular SQL adapter cannot execute them; it must not hide later work or
start polling idle accounts.

Add an authorized Document source to `transit-query-direct` and Fuze. Bind
collection enumeration, document/revision identity, interpretation, collation
and projection in the source basis. Use C5's common cut for transactional
multi-object reads; ordinary independent cuts remain an attributed vector.
Replace the existing captured/native Document source adapter without importing
Station back into the direct packages.

Execute declared-path projections and predicates from persisted subcolumns,
with residual reconstruction after selection. Prove zone-map and compressed
predicate soundness under all admitted collations, five-state predicates,
structural conflicts, schema evolution and `.tdel` visibility. Preserve ordered
error/conflict behavior through joins/aggregates; a pruning optimization cannot
silently remove an error that the reference execution would report.

Use the current [relational operators](../handbook/reference/sql/relational.md)
for grouping, HAVING, ordering and LIMIT after the Document source adapter has
an admitted type/state mapping. Preserve exact logical descriptors, decimal
scale, collation/padding and deterministic tie identities. Sorting and LIMIT
must not hide a later source-order failure or relabel a prefix as complete.
Exercise retained sort/group keys after source scratch reuse and spill; document
unsupported Document combinations before dispatch. Table operator support alone
does not establish semantics for missing, type-error or conflict inputs.

Reuse the production `TSegReader`/`PhysicalCodecs` column-group traversal for
dictionary/FSST predicates and M14's lossless Batch lanes. Preserve independent
atom outcomes at their original positions, separately charge selected projection,
and compare against unpruned evaluation. Do not restore the superseded string
prototype or persist execution pointers in Document pages.

Use M4's existing command counts, `ResultSet`, result reader and terminal
observation. Exercise empty and multi-batch results, large strings, early close,
cancelled prefixes, pin release, scratch ownership and current authorization
after buffering. Recheck prepared reads at their defined execution boundary,
including the recently fixed fresh-frontier behavior; do not reuse a stale cut
unless the caller explicitly selected a retained/transaction basis.

Co-hosted SQL/console and supported native callers form the first installed
proof. PostgreSQL/MySQL and Flight representations must preserve five-state
meaning through their declared mapping or explicit refusal; generic transport
availability cannot imply lossless Document support.
M8's resumable command engines make paused output another disclosure boundary:
revalidate read permission on resume without resubmitting an already accepted
mutation. Keep byte/frame handling in pure protocol packages and all Document
evaluation in its database owner.

#### C7 — Migrate Station and existing consumers

Once C5 and M6 R7 are qualified, make Document behaviors callers of declared
database objects. Atomically commit Document state, the exact input settlement,
journal and recorded reply/output intents. Preserve original destinations,
correlations, activation/lease fences, retirement, cancellation uncertainty and
recovery without handler execution. Connector dispatch remains subject to its
recorded effect protocol; a Document commit never dispatches an external effect.

| Consumer family | Required replacement and proof |
| --- | --- |
| Station service/worker and named resources | Replace Document storage/publication jobs and three-turn initialization with direct lifecycle/transaction adapters; prove worker absence for direct operations and replacement for behaviors |
| Shared ABI/host and public Zig + ten non-Zig SDKs | Migrate `DocumentCodec`, saved operations/references, writer/remote actions, reads and errors through shared Zig semantics; install real consumers with full-width identities and values exceeding old caps |
| Captured/maintained Query and SQL sources | Preserve exact accepted source/result attribution, retention, current access and five-state behavior; do not promote M12's unfinished activation work |
| Board API/browser | Preserve the read-only Document inspector, value-free operational evidence, terminal coverage and revocation through public reads. M30's new workbook application uses separately authorized typed saves after the C4/cutover handoff; M7 supplies no workbook schema or implicit SQL execution. Update reflected validators and actual browser tests for existing consumers |
| Examples, application installation and launchers | Migrate `examples/station-document`, bootstrap manifests, configuration, local/Compose/reference paths and replacement checks. Audit recent application schema-migration bindings; format compatibility and application revision are separate |
| Browser publication/Serving consumers | Audit explicit native-reader/Document source bindings introduced by recent browser work. Preserve existing supported Table paths and strict capability checks; broader direct Document publication needs its own owner-qualified adapter |

Remove superseded Document routes/actions, codecs (including successful `SDS1`
fallback reads), `SDW1` waits, stored heads, worker packaging and Document-only
`SIX1`/Station Publication use. Keep unrelated Station/Exchange users until
their respective owners replace them. A source import search is a removal check,
not proof that accepted-call semantics survived.

#### C8 — Qualify the cutover, measure and promote behavior

Coordinate every incompatible protocol, stored layout and ABI change under the
single current-v1 policy, including intermediate component increments that alter
accepted artifacts. Do not defer definition replacement until the final release.
Replace the shared definition, regenerate reflected
schemas, signing fixtures, ABI/host/browser resources and binding artifacts,
and align manifests/internal pins with `VERSION`. Reject old persisted definitions,
saved requests, roots, cursors and installations before execution/disclosure.
No v2, fallback decoder, silent default, implicit conversion or automatic reset.
Resolve or preserve uncertain accepted work with its matching build; define
the stopped-installation cutover procedure before testing upgrade refusal.

Freeze workload/resource targets before optimizing. Compare the baseline
Station journey and the direct replacement on the same hardware/durability
profile. Measure end-to-end create/edit/read/merge/query/restart distributions,
acceptance appends, staging/catalog requests, bytes written, allocation counts,
peak RSS, page visits and background maintenance debt. Report one-partition and
mixed-transaction costs separately. Use small documents through 10 MiB text,
deep/wide trees, sparse/high-entropy paths, conflict-heavy edits, cold/warm reads
and growing revision/replica populations beyond caches. Include concurrent
Table/Stream/Queue work and control progress. Do not adopt another milestone's
10–100× ambition as a measured Document result.

Keep local implementation measurements separate from M13's
[nightly container campaign](14-data-structures-and-performance.md#nightly-container-scorecard-and-distributed-handoffs).
Record the measured runtime's exact revision/definition and driver identity,
preserve unsuccessful attempts, and run matched comparisons without other heavy
campaigns. Extend the published-image inventory only after the measured release
contains the qualified Document path. Do not rebuild that image from the driver's
checkout or substitute a candidate for the last promoted nightly. These are
handoff requirements for later performance changes, not new executions in this
documentation task.

### Acceptance and verification matrix

All rows below are required future evidence at the implementation revision.
Earlier component passes remain evidence only for their recorded boundaries.

| Gate | Required observation | Owning verification |
| --- | --- | --- |
| Package/runtime independence | No transitive Station dependency in direct Document/storage/catalog/query/SQL/client packages; real lifecycle with Document worker and courier absent | Package checks, signed native/SQL installed journey |
| Logical correctness | Causal accepted-set convergence, explicit structural conflicts, duplicate identity recovery, detached/deleted anchors, safe stale-base updates and budget refusal | Independent semantic fixtures, seeded schedules and C1 oracle |
| Persisted representation | BP/spans/parts and shredded/residual reads agree across codecs, collations, deletions and compaction; bounded page construction/navigation | C2 segment round trips, differential query tests and counting allocator |
| Original operations and lifecycle | Lost replies at reservation/genesis/publication/mutation/checkpoint/close; conflicting token/content; rename/DROP/name reuse cannot retarget work | Catalog/node caller schedules with restart |
| Conditional versioned saves | Two callers share a base; one commits and the other receives an explicit stale-base conflict without losing its candidate. After caller loss, authorized bounded discovery recovers the original accepted save and revision | Non-browser C4 caller on disk, long ordered cell/text fixture, process loss and revoked lookup; M30 owns later Save/Open browser checks |
| Profile and part handoff | Ordered members/arrays/XML content, exact lexemes and raw offsets survive page reuse/reopen; late parser/hash failure cannot publish; missing/shared/cyclic part relationships preserve explicit coverage | M16 independent profile fixtures composed with C1–C3 persistent candidate/reader tests |
| Current authority | Denied metadata/data/mutation/checkpoint, replica impersonation, stale owner/policy epochs and revocation after buffering, including empty/terminal results | Independent signed callers and native policy tests |
| Reads/results | Exact revision/collection basis, progress-only pages, multi-page values, scratch reuse, early close, cancelled/failed prefixes and no silent query restart | Shared Query/SQL client/service tests |
| Mixed decisions and Station | Table + Document + exact Queue ACK + Stream append commit together; multiple logical Documents share one partition preparation; multiple partitions and read-only/absent-path dependencies remain serializable | Extend existing installed mixed caller and disk fault schedules; add real behavior/SDK replacement |
| Recovery/retention/collection | Reopen from accepted WAL/checkpoints, missing/corrupt format refusal, merge-floor resync, pinned old reads and unresolved work retained through collection; stage/attach/abort/late-attach races preserve owned/shared roots | Local disk fault/kill schedules and graph traversal, including M12 transaction-owned candidate regression cases |
| Resources/performance | Retained growth exceeds fixed resident budgets; large values page within a revision; warmed hot loops allocate no heap where claimed; mixed transactions stay inside existing budgets and maintenance/control work progresses | Allocation/growth harness and matched installed workload reports |
| Consumer/cutover completeness | Existing ABI/SDK/Board/examples preserve outcomes; incompatible old artifacts fail before use; no legacy successful decoder remains | Installed consumer, browser, launcher and definition/signing suites |

Start with owning package checks for `transit-protocol`, `transit-document`,
`transit-storage`, `transit-catalog` and affected Fuze/query/client code.
Extend the existing `just test::direct-named-resources`,
`just test::direct-table-service`, `just test::document`,
`just test::document-remote`, `just test::document-local`,
`just test::unified-query` and `just test::sql-transactions` tasks rather than
leaving worker-only tests as proof of the new database path. Move direct-storage
test ownership to its domain and register new real checks in the
[test inventory](../../tests/runner/suite.json).

Use `just test::direct-state-transaction`, `just test::direct-mixed-transaction`
and `just test::direct-queue-transfer` as the existing M6 regression boundary.
Extend the [installed transaction caller](../../tests/catalog/tables/direct_state_transaction.zig)
and [service fault schedule](../../tests/storage/tables/direct_table_service.py)
with Document private state, original statement recovery and committed reads.
Retain Table/KV/log-only cases and negative Document admission until its new
owner passes. Add faults at every Document prepare/decision/finalization
boundary; the existing two-lost-reply schedules cover only selected failures.
Keep the read-budget/recovery cases in
[`document_partition_test.zig`](../../packages/zig/transit-storage/src/document_partition_test.zig)
as regressions while extending them to logical page and cursor-key lifetimes.

Run `bindings::document-*`, Board `document-test`/`document-browser` and the
real `examples::document-compose`/`examples::document-reference` deployment
proofs for changed consumers. Every PR also runs the separate baseline gates
from the repository root:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

Implementation adds `just check contracts` for public contracts/bindings and
dependent owner checks. SQL/server/console/gateway changes also require
`just test console-latency-gate` in the pinned `ci-experience` shell and
`just test server-sql-types`. Scalar/adaptor changes follow the
[SQL interface validation loop](../../tasks/README.md#sql-interface-validation),
including `just test sql-wire-contracts` and `just test sql-wire-types`.
Board/browser contract changes require `just transit-board::check` and the
affected browser proofs. Installation of dependencies is preparation, not a
passing handbook gate; plan-only checks qualify no runtime behavior.

Before pushing implementation, run affected
`just ci clean --lane NAME` checks from committed HEAD: `core`,
`storage-query`, `interfaces-sql`, `interfaces-relational`, `installation-ui`,
`browser`, `launchers` and all affected `sdks-*` lanes; add
`interfaces-connectors` and `formal` when their owners change. Full clean
integration remains the release gate, not an inference from selected lanes.

Record commands, source/definition, backend, budgets, raw evidence, failures and
omissions in the owning qualification ledger. Promote delivered semantics and
numeric limits to the Document/state/SQL/caller references, package guides and
contracts, and source-attributed mechanisms to state/storage/query Internals.
Update the data model, glossary/component map, examples and generated capability
descriptions with the cutover. Keep delivery sequencing here.

Close M7 and its index row together only when C0–C8 and the
[completion evidence](#completion-evidence) agree. M6's remaining work, M16
profiles and later distributed/history extensions retain their own status.
Documentation validation for this plan establishes no new runtime capability.

### Ordered storage increment — 2026-11-02

The 2026-11-02 plan's ordered-storage scope now has a component implementation: canonical `DORDER01`
ordered changes; conditional versioned create/root replacement/ordinal-path
subtree replacement; persisted residual nodes, `2N` BP bits and verified raw
parts in shared `.tseg` records; retained authenticated metadata/value/part/topology
pages; and an M16 verified JSON/XML candidate adapter. Original-operation retries,
stale-head refusal, private candidate staging and one fenced WAL decision reuse
the existing partition owner. The shared current-v1 definition changed because
logical descriptors now require explicit layout and node/part counts.

Current behavior and numeric limits live in the
[ordered partition guide](../../packages/zig/transit-storage/docs/document-partitions.md#ordered-versioned-trees)
and [Document contract](../../contracts/DOCUMENT_V1.md#integrated-ordered-versioned-storage-slice).
The source includes a workbook-shaped JSON and XML disk handoff, bounded dirty
slab/cache growth, parser/part failures, old retained reads and graph coverage.
These component checks do not qualify installed direct callers or Station turns.
The completion record must name the actual executed checks and source revision.

This advances that plan's packets 1/2 without closing C0–C3. Profile attestations and compound
container graphs are not persisted by the generic tree; multi-request staging,
rank/select navigation, incremental patches, adaptive subcolumns, logical
checkpoints, causal lists/span edits and three-way merge remain open. Patches
currently rebuild the resulting tree and envelope within declared work budgets.
C4/C5 caller/transaction work and the coordinated C7 consumer replacement retain
their existing dependencies. M7 remains **In Progress**.

### First implementation changes

**Execution order at `c4dd89c22`, 2026-11-05.** Begin with packet 1's remaining
owner contracts; its retained-membership implementation is already on main.
Packets 2–4 turn those components into protected candidates, direct operations
and a real transaction participant. Finish semantic and physical work through
packets 5–6 alongside that path, then expose the qualified operations through
shared consumers. Keep C0–C8 as the completion checklist; packet numbers sequence
reviews, not new milestone identities or calendar estimates.

| Order | Packages and change | Prerequisite | Exit before dependent work |
| --- | --- | --- | --- |
| 1 | C0/C3 complete owner contracts and migration inventory; preserve delivered collection cuts | Current causal/ordered disk owner and retained-membership regression | Partition-aware guards, deletion/absence, protected staging, installed cursor ownership and original-operation discovery have exact fixtures, bounds and rejection rules |
| 2 | C3 resumable candidate/part staging and attachment with durable ownership | Packet 1 staging contract | Interrupted upload, duplicate/conflicting chunks, late verification failure, lost attach reply and concurrent collection preserve the original outcome and every live root |
| 3 | C4 direct lifecycle/domain/bootstrap and signed owned caller; collection listing and original-operation discovery | Packet 1 cuts; packet 2 for multi-request saves | Disk create/edit/list/read/recover with no Document worker or courier; two independent principals; stale save and rename/DROP/name reuse cannot retarget work |
| 4 | C5 Document cuts, private workspace, preparation and common-decision publication | Packet 1 participant contract; packet 2 owned roots; catalog integration from packet 3 | Table + Document, then exact Queue ACK + Stream append; two logical Documents in one preparation and two partitions; all-or-none visibility through each decision fault |
| 5a | C0/C1/C3 paged versioned ancestry and three-way merge | Delivered ordered roots; ancestry/alignment contract; packet 2 candidate ownership | Independent base/left/right oracle, duplicate/order/structural conflicts, stale publication-head refusal and original merge outcome after restart |
| 5b | C0/C1–C3 causal list/span edits and validated logical checkpoints | Full-width sequence/anchor/checkpoint contract; packet 2 | Permutation convergence, detached/deleted anchors, multibyte span boundaries, finite merge-window resync, original aliases and pinned old reads through archive/trim |
| 6 | C2/C3 indexed BP navigation, durable span pages, adaptive subcolumns and maintenance | Delivered residual/BP oracle; packets 2/5 for affected layouts | Real segment/pruning equivalence, cold reopen/compaction, five states and admitted collations; measured page visits, allocations, bytes and bounded construction |
| 7 | C6 selected SQL lifecycle/metadata and finite Fuze projections with M4 results and current typed relational operators | Packet 3 for lifecycle; packet 6 for pushed-down scans; packet 4 for mixed statements | Compiler/service/console journeys, exact types/five states and result provenance, ordered failures, terminal coverage, empty/multi-batch/failed prefixes and authorization after buffering |
| 8 | C7 transactional Station and existing ABI/SDK/Board/example replacement | Packets 3–7; exact M6 R7/R8 handoffs | Document state, input settlement, journal and replies/outputs share one decision; real installed consumers recover without handler replay |
| 9 | C8 removal inventory, definition regeneration and common-revision qualification | All preceding applicable exits | Full C0–C8/completion criteria, measured workloads, affected clean lanes, stopped-installation procedure and public documentation agree |

Packets 5a/5b can develop independently of installed adapters once their contracts
and retained candidate inputs are available; packet 6 can begin with the existing
ordered layout. Packet 3 may first exercise bounded one-request writes without
waiting for all large-value staging features. Every dependent feature keeps its
specific prerequisite. No unfinished packet is waived at the public cutover.

The shortest path to the **non-browser direct lifecycle proof** is
**1 → 2 → 3** over the delivered causal/ordered subset. The path to the
**atomic Document behavior proof** adds **4 + M6 R7/R8 → 8**. The
**full milestone exit** also requires **5a/5b → 6 → 7 → 9** and the
remaining C0–C8 obligations. These are proof checkpoints, not three public
Document engines. M6 can develop Table/KV behaviors first, M16 can supply
private candidates, and M30 can develop its application schema without making
those entire milestones prerequisites for M7 component work.

#### Concrete next reviews

The next reviews follow this sequence; the component portion of 1A is delivered
in the logical deletion increment below. Keep unsupported
routes refused while these land; a new type, validator or offline fixture does
not enable installed behavior.

| Review | Changes and source owners | Required exit |
| --- | --- | --- |
| 1A — Logical deletion and partition/lifetime contracts (component delivered) | Extend `Transaction.Target`/`Guard` and `DocumentRead.Collection` in `transit-protocol`; amend `DOCUMENT_V1`, `DATA_LIFECYCLE_V1` and `TRANSIT_STORAGE_V1`. Define logical deletion, Document partition ordinals, collection coverage, one preparation per physical partition and installed pin/key ownership | Independent fixtures cover full-width identities, empty/absent/deleted heads, malformed ordinals and wrong pin kinds. Existing Table/KV/log targets remain valid; Document transaction execution stays rejected until packet 4. Replace the current definition if these persisted/wire shapes change |
| 1B — Protected source staging and discovery ([next implementation slice](#protected-source-staging-and-operation-discovery-plan--2026-11-05)) | Extend `DirectOwnedRecord`/`DirectClientToken`, catalog progress and `DirectStorageGraph` with reserved source chunks, a paged inventory, bounded verification and caller-scoped discovery. Freeze the later Document attachment handoff and record the C0 removal map | A 10 MiB source survives interrupted upload, process loss, discovery, verification and collection with fixed resident budgets. Closure permanently fences further writes; original identity survives payload reclamation. Source verification does not accept a Document revision |
| 2 — Implement protected streaming candidates | Extend `DocumentIndex`, `DocumentOrderedTree`, `DocumentPartition`, catalog ownership and the M16 candidate sink through their package interfaces; use shared immutable publication and local collection | A 10 MiB value/tree is constructed and reopened with fixed admitted windows, without a whole-input/output allocation. Duplicate/conflicting chunks, parser backpressure, late hash failure, lost attach reply, link/cleanup uncertainty and collector restart preserve original outcomes and live roots |

The contract portion of reviews 1A/1B specifies dependencies before implementing
protected source ownership. Streaming canonical input remains part of packet 2:
accepting chunks and then concatenating them into the current `change_bytes`
buffer does not remove
the resident whole-request requirement. Keep a bounded one-request evaluator
adapter for existing component regressions, with both paths feeding the same
logical semantics. M16 owns parser verification; M7 owns staged storage and
acceptance. Resume either from a qualified durable continuation or by replaying
the exact retained source into the same operation; never serialize borrowed
parser pointers as recovery state.

The discovery contract must distinguish listing logical heads, locating an exact
operation and discovering accepted pending work. Extend the existing paged
operation owner with an index or bounded continuation whose work is charged;
do not scan every revision into memory or use generic caller-record reads to
disclose private mutations. A second reader can inspect authorized data while
operation recovery retains its own principal/ownership checks. These rules are
needed before M30 can promise recovery after browser or Board process loss.

For review sizing, packet 3 then separates domain/genesis/catalog changes from
signed caller/host integration. Packet 4 separates storage preparation and
decision-aware reads from workspace/savepoint and installed mixed-call tests.
Each review must name its exact start gate, contracts, negative fixtures and
executed checks; partial exits leave the owning C package open.

#### Retained collection cut increment — 2026-11-03

The component portion of packet 1 adds `DocumentRead.Collection` cuts, acquisition,
bounded head enumeration and explicit release. `DocumentPartition` persists a
separate logical-head frontier and collection-pin kind; `DirectStorageGraph`
traverses the captured directory independently of current heads. The current-v1
cutover regenerates shared definitions and independent fixtures. The
[public contract](../../contracts/DOCUMENT_V1.md#retained-partition-membership)
owns semantics and limits; the [qualification record](../history/qualification/storage.md#retained-document-partition-membership--2026-11-03)
owns executed checks and their limits. This increment does not close packet 1 or C0/C3:
partition-aware transaction targets/guards, candidate ownership and original-
operation discovery still need their reviewed contracts and implementation.
Logical deletion and common-cut acquisition remain unsupported.

#### Logical deletion and partition guards increment — 2026-11-05

Review 1A now supplies tagged live/deleted collection heads, conditional logical
deletion, current head observation and whole-partition transaction guards. The
owner records permanent tombstones without releasing retained reads or reusing
logical IDs. Neutral transaction directories group Document work by partition
ordinal; catalog/decision execution remains explicitly refused until packet 4.
The [Document contract](../../contracts/DOCUMENT_V1.md#logical-deletion-and-retained-lifetimes)
owns deletion, pin kinds and host signing-key obligations;
[transaction bindings](../../contracts/DATA_LIFECYCLE_V1.md#transaction-bindings-and-evidence)
own the new guard. The stored/wire definition changes together with generated
contracts and independent fixtures. This is component progress toward C0/C3,
not installed lifecycle, common-cut acquisition, SQL or Station completion.
The [qualification record](../history/qualification/storage.md#logical-document-deletion-and-partition-guards--2026-11-05)
records executed checks, source revisions and proof limits.

#### Next review: staging, discovery and installed lifetime ownership

Continue packet 1 from the retained membership increment above.
`DocumentOperation.Cut` names one logical revision; `DocumentRead.Collection.Cut`
now supplies the retained partition-head basis, including an empty partition.
Catalog listing, collection queries and transaction guards must consume that
basis through their owning contracts.

1. Record the C0 migration inventory and staging/discovery contracts in their
   owners. Specify which catalog records protect standalone candidates and
   permit original-operation enumeration; do not expose arbitrary caller-record
   payloads or call a logical-head list an operation-discovery API.
2. Map the reviewed host pin/key obligations to the installed lifecycle owners
   for C4: persist the key, recover the original operation and release exact
   pins under current authority. The next source-staging PR records this handoff;
   C4 implements it. Any proposed expiry requires application opt-in and its own
   recorded semantics. Key rotation cannot turn a missing retained source into
   a new read.
3. Build protected streaming candidates (review 2), then direct lifecycle and
   the Document preparation/common-cut path (reviews 3–4). Keep transaction
   execution refused until that owner supplies preparation, decision-aware reads
   and one preparation per partition. An independent vector of partition cuts
   remains insufficient for atomic acquisition.

**Retained-membership regression gate:** disk tests grow the logical-head directory beyond the configured
page cache, capture a cut, mutate the live owner, reopen and recover identical paged
membership. Cover an empty partition, page retries, one-less byte/step budgets,
scratch reuse, a second principal, revocation after buffering, released pins,
missing roots and collection during an active cut. Use existing causal and
ordered owners in the same suite. Record component-only scope; this increment adds
no installed route, executable SQL, Board persistence or Station turn.

**Remaining packet-1 exit:** complete protected candidate ownership, original-
operation discovery and the C0 migration inventory; map the reviewed pin/key
lifetimes to installed owners before dependent adapters implement them.

#### Protected source staging and operation discovery plan — 2026-11-05

**Next implementation PR:** an authorized owner can reserve a Document source,
upload it in bounded chunks, lose its process, discover the original operation,
resume and verify the exact source, then explicitly close it. Every acknowledged
chunk remains reachable through restart and collection until closure; the
original operation remains discoverable after the source becomes collectible.
This delivers executable ownership and discovery from review 1B and the source
storage prerequisite for review 2. It does not complete review 2 or C0/C3.

The source basis is `origin/main` at `bb4bbd3ad`, including the merged
[logical deletion and partition guards, #388](https://github.com/spoke-sh/transit/pull/388).
The plan below records the intended scope. The source owner now implements
reservation, paged chunk publication, bounded verification, exact recovery,
discovery and explicit closure at the component boundary. Installed integration
and candidate attachment remain pending. Current semantics and limits belong in
the [Document reference](../handbook/reference/documents.md) and
[owned-original contract](../../contracts/DIRECT_TABLE_V1.md#durable-client-token-bindings).
Preserve the preceding increment's
[qualification limits](../history/qualification/storage.md#logical-document-deletion-and-partition-guards--2026-11-05).

##### Scope and dependency boundary

Use one local source part per operation, an explicit source length and digest,
an exact Document target and expected base, and sequential immutable chunks.
Keep the current native operation identity, definition and partition-ordinal
rules. This PR exercises the catalog/storage component boundary with an explicit
authority guard. A new installed Document domain, declaration/genesis path and
signed Document endpoints belong to C4; unsupported installed routes remain
refused. A bound target is not proof of permission to mutate that target.

The completion state means **source bytes verified**, not parser/profile
verification, a sealed logical tree or an accepted revision. Existing SOR1
`ready` means the original envelope exists; it cannot also mean those later
states. Define a typed source-progress record inside the existing original's
lifetime. Keep Document attachment unavailable in this PR, including through the
existing KV attachment route. State the later handoff now so the source layout
does not require a second recovery authority.

| Existing owner or adjacent work | Reuse and change in this slice |
| --- | --- |
| [`DirectOwnedRecord`](../../packages/zig/transit-catalog/src/DirectOwnedRecord.zig), [`DirectClientToken`](../../packages/zig/transit-catalog/src/DirectClientToken.zig) and [`DirectCatalog`](../../packages/zig/transit-catalog/src/DirectCatalog.zig) | Reuse SOR1 reservation/closure and immutable original receipts, CPR1 progress replacement, revision comparison and account charging. Extend typed ownership for a paged source graph; the existing complete-payload `stage_original` helper cannot carry the source itself |
| [`DirectCatalogStore`](../../packages/zig/transit-catalog/src/DirectCatalogStore.zig) | Reuse the account-scoped `client_operations` and `client_pending` directories and eight-entry pages. Add bounded, redacted source-operation selection over these indexes; do not introduce another operation registry |
| [`DirectStorageGraph`](../../packages/zig/transit-catalog/src/DirectStorageGraph.zig) and [local storage](../../packages/zig/transit-storage/README.md) | Trace original descriptors, ready and reserved chunk references, inventory pages and pending publications. Reuse allocation epochs, reader grace and immutable-file publication, including #384's uncertain link/cleanup outcomes |
| [`DocumentPartition`](../../packages/zig/transit-storage/src/DocumentPartition.zig) and [`DocumentAuthority`](../../packages/zig/transit-catalog/src/DocumentAuthority.zig) | Preserve expected-cut semantics and current authority checks; no partition mutation occurs during staging. Continue refusing Document transaction execution |
| [M13 ownership](13-sql-and-dataflows.md#next-implementation-slice-owned-staging-and-finite-qualification) | Keep existing complete-record staging, managed progress and KV attachment behavior as regressions. Document chunks must not acquire indefinite ownership through generic `direct-records/` |
| [M17 candidates](17-document-profiles-and-gateway-exchange-lifecycle.md#immediate-representation-gap-and-m7-acceptance-handoff) | Bind the intended profile and source commitment, but defer the persistent parser sink. Its offline `Candidate` verification is not a durable source receipt or a Document acceptance |
| M6, M8/M9 and M30 | Preserve current Queue wait/original-operation recovery, host disclosure and saved-attempt rules. This slice supplies storage prerequisites for later shared-client and Save/Open work; it adds no wait loop, SQL result protocol, Station migration or Board persistence |

##### Contracts and durable ownership

Amend `DIRECT_TABLE_V1`, `DOCUMENT_V1` and `TRANSIT_STORAGE_V1` before their
dependent implementation. Put neutral source identity/progress types with their
existing protocol/catalog owners. The expected persisted/wire changes require
one current-v1 definition replacement, generated schemas/bindings, strict
decoders and independent signing/rejection fixtures in the same PR. Preserve
unrelated M6/M8 definition changes when rebasing; old stored layouts must reject.

The immutable original descriptor binds the principal/account/token, catalog
scope, stable target and logical Document identity, partition ordinal, intended
operation kind, expected base, current definition, intended profile, one part
identity, exact source length/hash and admitted limits. It must not pretend to
know the future derived-tree digest. Changed bytes, targets, bases, profiles or
limits require a different operation; an exact retry recovers the original.

Keep mutable progress in a paged, immutable inventory selected by the original
operation's latest catalog revision. Its small root records the contiguous
ready prefix, one optional pending chunk/publication, verification outcome and
charged work. Chunk references and history must not grow an inline array or
force all prior descriptors into memory. Scope chunk identities to the original
operation and part; do not introduce cross-operation deduplication or ownership
transfer in this slice.

Reserve the source record formats for this owner. Generic progress updates,
record staging and original retain/attach controls must not replace its inventory,
erase charges or bypass its transitions. Route source closure through the typed
owner while preserving the existing complete-record profile. Test these bypass
attempts through the actual catalog dispatch, not only the source validator.

| Transition | Required durable owner and outcome |
| --- | --- |
| Reserve original | Atomically bind the original token and budget before writing its descriptor. A reserved original is discoverable even if no descriptor bytes exist; retries must match the complete original commitment |
| Reserve chunk | Compare the current progress revision and publish the next exact offset, length and hash before its physical creation. Admit one outstanding chunk; reject holes, overlap, changed retry content and writes beyond the declared source length |
| Publish chunk and inventory | Write and verify the immutable chunk, then publish the new ready prefix and inventory root. Keep the previous ready root and pending reservation protected until the replacement is durable. Repeating a ready write verifies existing bytes; it never recreates missing acknowledged data |
| Verify source | Read the complete ready source in bounded steps and check coverage, length and digest. Only exact success records source verification. A digest mismatch is an explicit failed observation with retained evidence; it neither accepts a Document nor silently closes the original |
| Recover | Inspect the exact original and its current revision. Resume a matching pending write or restart bounded digest verification from the retained source. A missing ready object is corruption; an absent object belonging only to an unfulfilled reservation may be created |
| Close | Compare the current revision, fence active writers and irreversibly close the unaccepted source. Release pending capacity once; retain the original receipt, commitments and account charge. The collector may reclaim source payloads only after its normal fences |
| Late request | After closure, reject new writes, verification publication and attachment; an exact original retry reports closure without opening or recreating source bytes. A paused writer must not publish through the closure fence |

The graph-publication design must cover **inventory pages as well as chunks**.
Before implementing the writer, record the ownership ordering for every physical
write, including root and index bookkeeping. Use bounded reservations and the
existing allocation-epoch/publication guards to bridge private index construction
to catalog publication. An unpublished manifest that names files does not protect
those files by itself. A collector must tolerate absent reserved objects, require
all ready objects, and traverse pending/ready inventories with bounded memory.
Hold the owning publication fence through each write, or supply an equivalent
proved exclusion, so closure cannot race a later physical creation.

Keep verification state independent of borrowed input buffers. The first profile
may restart digest verification after process loss, using the same source and
operation. Persist charges before doing work, and charge repeat verification
against an explicit work allowance. Do not persist parser pointers or portable
hash internals, reinterpret a partial digest as completion, or concatenate the
source to call a whole-buffer validator. Work-budget exhaustion preserves the
original outcome and leaves inspection/closure available.

Freeze the future attachment rule in the contract: source verification is only
an input to M16 verification and the streaming logical builder. A later qualified
candidate must bind the same original, base, source and profile evidence. Before
acceptance it must reserve its exact native operation; a lost reply is resolved
through that operation. Accepted roots must own all live parts before staging
ownership can end. Unknown or denied native observation cannot authorize
abandonment. This PR has no attachment transition to execute or qualify.

##### Discovery and current authority

Keep three operations distinct: logical-head listing, exact original-operation
lookup and bounded discovery of source operations. Reuse the existing all/pending
account indexes. A source selection fixes the exact scope, optional target and
pending/all choice, and returns at most eight metadata entries. Inspect at most
32 token entries per call; advance continuation by the last **scanned** operation,
including when no entry matches. Return explicit continuation on a budget stop.
Do not scan an account's entire history to fill a page or open every payload to
classify it; keep the necessary type/target commitment in bounded catalog metadata.

The continuation carries its selection identity and last scanned ID. Validate
scope and selection on every call. This is live enumeration, not an atomic
snapshot or a retention pin: later admissions or settlements can change later
pages. An empty filtered page, end of a live scan, denial or a failed observation
cannot establish that an uncertain mutation was rejected. Recovery uses exact
lookup of the immutable original identity.

Return only the caller's authorized operation metadata: original ID, target,
expected base, phase, byte progress, verification/closure outcome and continuation.
Exclude source bytes, credentials and arbitrary inner progress payloads. The
original principal/account owns recovery; independent Document read rights do
not confer access to another principal's pending operations. Recheck current
scope and target authority before disclosure, including retries and buffered or
empty pages. A component fixture supplies the explicit guard; it must not imply
that the installed catalog already has a Document authorization domain.
Bounded source reads use that same original ownership and current authority;
generic record reads must not bypass it or expose unready chunks.

##### Resource profile and failure proofs

Freeze these first-profile limits in the owning types and tests. Account defaults
and accepted budgets remain explicit; the fixtures below do not increase an
existing account's limits or establish production throughput guarantees.

| Bound | Proposed implementation/qualification requirement |
| --- | --- |
| Source and chunk shape | One part; at most 64 KiB per chunk; one outstanding chunk publication per original. Source size comes from the admitted descriptor, with checked arithmetic and a paged directory |
| Durable bytes | Reserve the complete per-operation ceiling through `DirectClientToken.Budget`. Charge source chunks, descriptor/inventory bytes, current and pending progress and simultaneously retained publication metadata. Preserve the existing 4 GiB default account ceiling and permanent original charge; the 10 MiB proof explicitly requests a 32 MiB operation budget |
| Work | Each step admits an explicit page/byte budget; source verification reads at most 4 MiB per step. Persist a cumulative work ceiling, including retries and restarted verification, separately from retained bytes. Metadata/index work also consumes budget |
| Resident memory | Instrument a proposed 8 MiB ceiling for the complete active source path, including owned input/output buffers, cache, scratch and metadata. Qualify with a one-page cache and a 10 MiB source. Reserve active residency through the account/host admission owner; test a 64 MiB aggregate ceiling across roles, independent of durable pending count |
| Discovery | At most eight returned metadata entries and 32 inspected token entries per call; charge actual page work and preserve continuation when that budget stops the scan |
| Controls | Inspection and explicit closure use reserved control capacity even when source byte, active-work or verification budgets are exhausted. No budget pressure authorizes expiry |

Keep superseded physical objects bounded by the admitted byte/work allowance and
collector progress. Record when accounting becomes reusable, if ever, in the
contract; physical deletion does not refund the permanent original reservation.
Do not treat a logical current-root size as the peak staging footprint. Fail a
new step before exceeding its reservation, without dropping an acknowledged
prefix. Qualification must measure the declared allocation scope rather than
infer it from Docker RSS or claim zero steady-state allocations without evidence.

| Fault or negative control | Required evidence |
| --- | --- |
| Loss before/after original or chunk reservation; loss after put before readiness | Reopen on disk; discover and recover the same original, exact prefix and reservation. No duplicate charge or new operation; physical writes have a durable owner |
| Changed duplicate, hole, overlap, extra bytes, wrong part/base/profile/definition | Reject before advancing the ready prefix; preserve the original binding and earlier acknowledged chunks |
| Missing/corrupt ready chunk or inventory; late digest mismatch | Report the exact incomplete/corrupt state. Do not rebuild ready storage, fabricate verification or accept a revision |
| Verification interrupted repeatedly; byte/page/work limit one below need | Resume bounded work or report exhaustion with original identity intact. Borrowed buffers remain valid only for their declared window |
| Close racing a paused writer, verification publication or retry | One permanent closure fence; no later source publication or resurrection. An original closed before payload collection is still discoverable after collection and restart |
| Collector before/after reservation, readiness, root replacement and closure | Preserve ready and pending roots at the collector cut; tolerate only legitimate absent reservations. Cover new allocation epochs, active read guards, collector restart and uncertain file link/cleanup |
| Directory larger than cache; sparse target filter; pending work settles between pages | Bounded steps and increasing continuation, including empty nonterminal pages. Exact lookup retains original identity; enumeration makes no atomic coverage claim |
| Different principal/account/role; revocation after buffering | No private payload or cross-principal metadata disclosure. Role changes cannot evade aggregate quotas or create another identity for the same token |

##### Implementation order and migration inventory

Make the following logical commits on a branch rebased onto current main. Keep
the definition replacement and all affected consumers consistent at the final
PR revision. Types and fixtures alone do not satisfy a runtime exit.

1. **Contract and neutral types:** establish source commitments, typed progress,
   discovery projection, limits and transition/ownership tables. Regenerate the
   shared definition, schemas and independent fixtures. Map installed pin/key
   ownership and every affected legacy operation before adding an adapter.
2. **Reserved chunk storage and retained graph:** implement paged source
   inventories, immutable publication, ready/pending traversal and closure fences
   with disk fault tests. Keep this behind component admission until catalog
   transitions and authority checks are connected.
3. **Catalog ownership and accounting:** connect original reservation, exact
   retries, progress CAS, bounded source verification, cumulative charges and
   closure through existing token/progress owners. Preserve SOR1/CPR1/KV behavior.
4. **Operation discovery:** add bounded metadata selection and exact recovery,
   current-authority checks and sparse-page continuation over existing indexes.
5. **Integrated component proof and documentation:** run the 10 MiB journey and
   fault matrix against local disk, including process reopen and collection.
   Publish implemented component semantics/limits in the Document/storage and
   catalog owners, record evidence and keep installed routes explicitly refused.

The C0 inventory is a checked table, not a deletion in this PR. Start with these
families, then enumerate their exact call sites, fixtures and generated surfaces
before marking that inventory complete:

| Existing family | Replacement owner and removal gate |
| --- | --- |
| `DirectResource`, `DirectResourceClient`, `NamedResource` and Station initialization | C4 direct declaration, native identity allocation, genesis and name publication. Preserve original create/recovery and failure behavior before removing the handshake |
| `STATION_DOCUMENT_V1` requests, `SDC1` changes, `STATION_INDEX_V1`/`SIX1` and publication artifacts | C1–C3 logical evaluation, protected candidates and accepted `.tseg` roots, followed by C7's coordinated stored-format cutover. This source PR replaces none of those accepted artifacts |
| Existing Document SDK/ABI methods, waits, examples and installed tests | C4/C7 shared Document client and original-outcome recovery. M9 supplies composition, but existing consumers must migrate with the owning cutover |
| Read/collection handles, host signing keys and retained source references | C4 installed persistence, exact release and restart/rotation policy; no key loss, timeout or quota pressure implies expiry. Keep deletion and retained-membership regressions throughout |
| SQL/Fuze, Station state/effects, Board and profile/exchange consumers | C5/C6/C7 plus M6/M16/M30 handoffs. Keep typed results, common-decision semantics and parser evidence with their existing owners |

##### Checked migration inventory for this slice

The source owner adds no legacy adapter. The following concrete owners must
move together in their owning cutover; none is removed by this source PR.

| Current call site / artifact | Cutover responsibility and evidence to preserve |
| --- | --- |
| [`DirectResource`](../../packages/zig/transit-catalog/src/DirectResource.zig), [`DirectResourceClient`](../../packages/zig/transit-catalog/src/DirectResourceClient.zig), [`NamedResource.initialize`](../../packages/zig/transit-station-app/src/NamedResource.zig) | C4 replaces allocation/reservation, `Service.create` and initialized-marker publication with direct declaration/genesis. Keep exact create identity and recovery of each separately observed step |
| [`Service`](../../packages/zig/transit-station-document/src/Service.zig), [`Request`](../../packages/zig/transit-station-document/src/Request.zig), [`records`](../../packages/zig/transit-station-document/src/records.zig), [`Client`](../../packages/zig/transit-station-document/src/Client.zig) | C1–C3/C7 replace Station turns and accepted change/checkpoint roots only after logical candidate verification and original-outcome recovery exist. `SDC1` is still the installed change format |
| [`ImmutableIndex`](../../packages/zig/transit-station/src/ImmutableIndex.zig), [`Publication`](../../packages/zig/transit-station/src/Publication.zig), [`PublicationUpload`](../../packages/zig/transit-station/src/PublicationUpload.zig), [`PublicationParts`](../../packages/zig/transit-station/src/PublicationParts.zig) | C3/C7 move Document `SIX1`/publication ownership to accepted `.tseg` closure. Other Station users remain with their existing owner; no indiscriminate deletion of shared publication code |
| [`DocumentBridge`](../../packages/zig/transit-station-bindings/src/DocumentBridge.zig), [`DocumentCodec`](../../packages/zig/transit-station-bindings/src/DocumentCodec.zig), [`GrowingAbi`](../../packages/zig/transit-station-bindings/src/GrowingAbi.zig), [`HostProtocol`](../../packages/zig/transit-station-bindings/src/HostProtocol.zig) | C4/C7 migrate shared ABI/port methods and generated Station SDK contracts together. Preserve ownership, waits, cancellation and uncertain original operations through all language wrappers |
| [`station_document_abi.py`](../../tests/sdk/station_document_abi.py), [`sdk_document_runner.py`](../../tests/sdk/sdk_document_runner.py), [`document_contract.py`](../../tests/runtime/document/document_contract.py), [`runtime journey`](../../tests/runtime/document/document.py), [`Document example`](../../examples/station-document/main.zig) | C7 migrates independent codecs, installed callers, worker/node/store recovery and the real example; the new component source receipt cannot stand in for these proofs |
| [`DocumentPartition`](../../packages/zig/transit-storage/src/DocumentPartition.zig): `beginRead` / `releaseRead`, `beginCollectionRead` / `releaseCollectionRead`; [`DocumentRead`](../../packages/zig/transit-storage/src/DocumentRead.zig) and [`DocumentCollection`](../../packages/zig/transit-storage/src/DocumentCollection.zig) | C4 supplies installed pin ownership and durable provisioning/rotation of `Options.read_secret`. Current component callers supply the secret on reopen; key loss invalidates cursors but must never release pins. Preserve cross-kind release refusal, retained reads after deletion and explicit release recovery |
| [`DirectDocumentSource`](../../packages/zig/transit-catalog/src/DirectDocumentSource.zig), [`DirectStorageGraph`](../../packages/zig/transit-catalog/src/DirectStorageGraph.zig) | Review 2 consumes the original source commitment through the bounded event sink. C4 must persist the host authority/admission composition; a source inventory is neither a partition read pin nor a transferable ownership capability |
| [`transit-query` Document import](../../packages/zig/transit-query/src/root.zig), [`Document Board proof`](../../tests/interfaces/board/document_board.py), [`profile tests`](../../tests/catalog/tables/document_profiles.zig) | C5–C7 and M16/M30 migrate SQL/Fuze, read-only inspection and profile evidence through their shared owners. Preserve typed results and explicit-submit behavior; source verification alone cannot supply parser or accepted-head evidence |

This inventory establishes the handoff locations, not completion of C0: installed
pin/key persistence, direct declarations and migration of all generated consumers
remain dependent implementation work.

##### Validation and exit

During implementation, extend `direct_catalog_test.zig`,
`direct_storage_graph_test.zig` and the owning storage tests with the fault cases
above. Use existing package `zig build test` targets inside the pinned Nix shell;
retain protocol/signing, ordered/causal Document, deletion, collection and
managed-original regressions. If a new installed test task becomes necessary,
register it with the runner and its lane rather than leave an ad hoc script.

Before the implementation PR, run the required fast check, locked docs install
and complete handbook check, plus `just check contracts`. Against committed
HEAD, run clean `core` and `storage-query` lanes and affected SDK/consumer lanes
selected by the final definition changes, following the
[CI workflow](../../tasks/README.md). If the final diff touches server, SQL,
gateway or their startup/build paths, also run the required pinned console
latency and server SQL type gates. Record exact source revisions and all
outcomes; #388's incomplete runtime/browser evidence is not a pass for this work.

Exit requires the complete component journey and negative controls at one
definition: reserve → upload a 10 MiB source → lose the process → discover the
same operation → resume → verify → explicitly close → collect → reopen and
observe permanent closure. The source must exceed resident memory, operation
directories must exceed cache, and every admitted write must have a demonstrated
ownership/fencing path. No Document head changes during this journey.

The immediately following PR completes review 2: connect this protected source
to M16's bounded event sink and a streaming `DocumentIndex`/ordered-tree builder,
persist exact profile/coverage evidence and attach through `DocumentPartition`
with original-outcome recovery. It must prove a large value/tree without whole
input/output buffers; the current complete-frame adapter remains an oracle.
Direct lifecycle, mixed transactions, merges/spans/subcolumns, SQL and the
Station/consumer cutover retain their existing packages and completion gates.

#### Follow-on reviews: caller and common-decision path

For packet 2, separate staged-byte existence, complete candidate verification and
attachment to an accepted mutation. Use bounded chunk writes tied to the original
operation/definition, verify full coverage and raw digests before attachment, and
charge cumulative upload/index work. Recovery must distinguish an unaccepted
candidate from an accepted mutation whose reply was lost. Extend neutral owned-root
tracking, using the available original-operation reservation/readiness/closure
seams and adding Document-specific root inventory and guarded attachment. Do not
treat the existing SOR1 KV attachment as Document acceptance or teach the
collector profile grammar. The existing complete-frame JSON/XML/MIME adapter is
the oracle while a streaming sink is wired in cooperation with M16.

Split packet 3 into catalog/authority and caller/host reviews. The first replaces
`DirectResource`'s writer/native allocation and `NamedResource`'s initialization
handshake with original-operation-owned partition genesis and verified name
publication. Extend `TableAuthority.Profile`/`Kind`, `DocumentAuthority`, registrar,
configuration and generated strict decoders together. The second composes a
proposed `DirectDocumentClient` through `transit-data-client.Catalog`/`Context`,
signed node dispatch and saved-attempt recovery. Preserve native grants as the
authority, output ownership, bounded operation discovery and independent reader
rights. Keep the non-browser save/open journey on the cutover implementation
branch until existing public consumers can switch together.

Split packet 4 into storage preparation/decision reads, then catalog workspace
and installed mixed-caller proof. Extend `TransactionDirectory`,
`TransactionDecisionLog` and `DirectTransactionWorkspace.StatementWork`/
`StatementCompletion` with typed Document work, not Table-shaped payloads. Reuse
one statement sequence and operation reservation; keep savepoint rollback from
reusing identities. Two logical documents sharing a partition must accumulate
in one private head map and one preparation. Test reader visibility immediately
after the common decision, before any participant finalizes, as well as restart,
revocation and exact Queue lease fencing. Do not call standalone `applyOrdered`
after a Table commit to emulate this transaction.

M6 can qualify its Table/KV transactional behavior independently. C7 then adds the
Document participant to the same input/state/output decision. If the M6 handoff
is unavailable, land qualified private components and keep the installed Station
Document owner and M7 status unchanged. M16 exchange cutover and M30 application
Save/Open retain their own implementation and qualification owners.

### Decisions and risks to resolve during implementation

| Decision or risk | Required resolution and gate |
| --- | --- |
| Installed evaluator versus direct identity/size model | Preserve delivered full-width causal maps; finish ordered/span/versioned builders and migrate installed consumers. Larger declaration limits cannot conceal the old 96-byte/eight-operation execution path |
| M16 ordered representation versus causal maps | Preserve duplicate/order/lexeme/raw-part evidence through C0–C3. A causal-map import or opaque byte capture cannot claim a lossless queryable JSON/XML tree |
| M30 conditional persistence versus runtime cutover | Supply owner-enforced expected revisions, listing and accepted-operation discovery before browser integration. Keep workbook schema and Save/Open in M30; typed reads/writes do not bypass the C7 public cutover gate |
| Document collection versus transaction owner | Freeze partition selection, whole-partition conflict basis and one preparation per owner in C0/C5; reject unsupported selection before admission |
| Supplied state and checkpoint bytes | Derive or validate all logical roots, counts and causal evidence in C1/C3; matching a content digest alone cannot establish valid Document state |
| Navigation and memory targets | Benchmark actual paged BP/span traversal and admitted work; retain the O(1)/O(log B) targets as open until evidence supports them. Bound page visits, scratch, output borrows and resident owner overlap |
| Authority and retention across cutover | Install a distinct Document domain, persist cursor-key ownership and trace every private/accepted/pinned root; no key change, quota, unsupported graph edge or stale native resource may cause unauthorized disclosure or deletion |
| Station and language dependency | C7 requires the specific M6 turn/settlement and shared ABI seams. If those remain unfinished, record component delivery and leave the public cutover and M7 open; do not emulate atomicity with two commits |
| Evidence from changing definitions | Re-run affected integrated schedules at the final definition; preserve earlier failures and original uncertain work. Neither later passing M6 lanes nor incomplete M8/M9/M20 runs establish Document qualification at this revision |

## Implementation plan for initial Document decoupling

This earlier P0–P5 plan preserves the initial extraction, scope and gates. Use the
[current C0–C8 plan](#implementation-plan-for-remaining-work) and
[next reviews](#concrete-next-reviews) for delivery order and present gaps;
their source assessment accounts for the subsequent D0–D4 components. The audit
and proposed steps below are not a second current checklist.

**Plan basis:** `origin/main` at `1116604e90f79f1d9c879b4262f62993da4990f1`,
2026-10-28. **Delivery status:** Core and private storage foundation implemented;
the database acceptance and public cutover gates below remain planned.

### Initial implementation scope

The first slice extracts the unchanged canonical change model, codec and merge
evaluator into [`transit-document`](../../packages/zig/transit-document/README.md),
with an owner-supplied immutable-index interface and no Station dependency.
The existing service composes this evaluator with its current Station index,
publication and caller boundaries.

[`DocumentIndex`](../../packages/zig/transit-storage/docs/document-index.md)
adds bounded `.tseg` causal-record staging, paged directories, immutable roots
and scoped candidate workspaces in `transit-storage`. This is a portion of P1
and P2: it preserves current logical/change bounds and stages private roots.
It does not implement the new logical algebra, succinct topology,
`DocumentPartition`, direct catalog initialization, WAL acceptance, retention
walking or public consumer cutover. The shared definition and installed wire
formats do not change in this slice.

The public cutover remains gated on the M5/M6 state/input/output transaction
decision. Keeping the installed callers on their current authority while the
foundation is established avoids introducing another public acceptance model.
The component guide links executable checks; full milestone acceptance requires
the schedules and gates below.

### Intended initial public outcome

The first outcome is a declared Document whose initialization, accepted edits,
revision reads and recovery belong to the database. A caller can create it,
apply a causal change, resolve a lost reply using the original operation, and
read the accepted revision after restart without a Document worker, Station
call, courier or native KV turn. This starts delivery step 1, with the minimum
logical/storage contracts from steps 2–3 and the consumer cutover from step 6.
It does not complete this milestone's analytical or transaction outcomes.

### Source audit and prerequisites

| Boundary at the plan basis | Existing owner and consequence |
| --- | --- |
| Logical changes and reads | [`Model.zig`](https://github.com/spoke-sh/transit/blob/1116604e90f79f1d9c879b4262f62993da4990f1/packages/zig/transit-station-document/src/Model.zig) obtains bounded names/scalars from `Station.ImmutableIndex`; [`Document.zig`](https://github.com/spoke-sh/transit/blob/1116604e90f79f1d9c879b4262f62993da4990f1/packages/zig/transit-station-document/src/Document.zig) performs merge and traversal over that index. Moving the package alone would preserve the storage coupling and old limits. |
| Durable acceptance | [`Service.zig`](../../packages/zig/transit-station-document/src/Service.zig), `Checkpoint`, `Remote` and `Caller` use Station Publication, private turns, one active job and recorded reply routes. Candidate construction is separate from final accepted head publication. |
| Catalog lifecycle | [`DirectResource`](../../packages/zig/transit-catalog/src/DirectResource.zig) requires a writer PID and native allocation. [`NamedResource`](../../packages/zig/transit-station-app/src/NamedResource.zig) reserves the interpretation, creates the Document service and verifies its empty head across three commits. Catalog's absence of Station imports does not eliminate this runtime dependency. |
| Public reads and consumers | [`Client`](../../packages/zig/transit-station-document/src/Client.zig) opens native resource cuts; Query, Board and [`DocumentCodec`](../../packages/zig/transit-station-bindings/src/DocumentCodec.zig) depend on that implementation. The ABI codec also repeats the 96-byte binary limit. |
| Reusable database owners | `DirectCatalog`, `DirectClientToken`, `DirectIntent`, `DatabaseRuntime`, `ReadCache`, `TablePartition`, `TreeStore`, `TransitLog` and `TransitObjectStore` exist. The [SQL cutover](06-streams-queues-and-durable-runtime.md#sql-database-runtime-cutover--2026-10-28) qualifies their specific Table path, not a generic Document path. |
| Transactions and runtime composition | The [M5 delivery profile](05-transactions-and-atomic-composition.md#selected-delivery-profile-and-exclusions) excludes native Document participation. Storage transaction directories, decisions and private Table workspaces do not establish an installed Document transaction. Stream/Queue participants and transactional Station turns remain M6 work. |

P0–P3 below can begin against the existing local WAL/object and catalog owners;
they do not require Streams, Queues, the complete M5 coordinator, M8 clients or
M16 format profiles. Coordinate shared definition, token and retention changes
with M5. P5's public replacement has a separate atomicity gate: an existing
Station operation that commits Document state with input progress and outputs
must acquire a qualified common transaction before its old implementation is
removed. Two recoverable commits do not preserve that guarantee. Until that gate
is met, land only independently useful internal components and tests, or retain
the dependent switch on the implementation branch; do not expose two public
Document engines or a compatibility mode.

### First delivery profile

- Use one existing catalog, branch one, one fenced local owner and one logical
  Document per catalog object/partition. Reuse scoped `DataLifecycle.Object`
  and immutable definition identities. Names, Document revisions, causal dots,
  client tokens, operation IDs, WAL positions and writer/policy epochs remain
  distinct. A Document definition does not require an application PID or a
  per-Document native resource allocation; catalog authority can retain its
  existing native lifetime binding.
- Implement the existing map/list/text **causal CRDT semantics** first:
  observed-remove conflicts, immutable object identities, detached descendants,
  descending-dot sibling order, deleted anchors, replica frontiers and exact
  duplicate acceptance. Convergence applies to the same accepted change set.
  The neutral model separates logical types, collations and physical encodings;
  unsupported profiles receive a typed refusal. Versioned/immutable-lineage
  merges, container graphs and new format parsers remain later work.
- Replace fixed inline payloads with length-delimited values and bounded staged
  references. Publish explicit request bytes, operation/node counts, depth,
  conflicts, staging, active work and response budgets; do not inherit the
  96-byte/64-byte/eight-operation wire ceilings or substitute larger arrays.
  Preserve Unicode-scalar text semantics initially. Span-block text storage,
  grapheme behavior and normalization are separate contracts.
- Establish a bounded `.tseg` residual-tree representation before public
  replacement. Keep causal evidence and revision/operation directories paged;
  `TreeStore` may index those directories but must not become a renamed `SIX1`
  payload engine. Adaptive shredding, collation-aware path pruning and optimized
  succinct navigation remain later M7 outcomes. Select the initial topology in
  P0/P2 using the [candidate evidence](#candidate-structures-and-selection-evidence);
  rank/select alone does not prove all advertised navigation operations are
  constant time.
- Deliver shared typed lifecycle/edit/read operations and SQL lowering for the
  selected Document CREATE/ALTER/RENAME/DROP subset. Existing SQL declaration
  compilation is offline; executable forms and supported ALTER properties must
  be specified and tested before advertising them. Preserve existing accepted
  Query projections through the shared reader. New relational collection scans,
  path-predicate pushdown and multi-object composition remain later steps.

### Ownership and dependency direction

Proposed ownership follows the existing database boundary:

```mermaid
flowchart TD
  Users[SQL and typed callers] --> Catalog[DirectCatalog and direct Document operations]
  Station[Station transaction adapter] --> Catalog
  Catalog --> Partition[transit-storage DocumentPartition]
  Partition --> Semantics[transit-document logical model and merge evaluator]
  Semantics --> Protocol[transit-protocol neutral identities and contracts]
  Partition --> Storage[TransitLog and TransitObjectStore]
  Readers[Query and Board readers] --> Catalog
```

`transit-document` owns deterministic validation, merge evaluation and bounded
logical traversal against explicit reader/builder interfaces. It imports no
Station, provider, catalog or storage implementation. `transit-storage` owns
physical trees, staging, WAL acceptance, retained roots and recovery, and uses
that evaluator. Catalog owns names, policy checks, operation routing and
inspection. Client/SQL packages call the same operations. Station composes above
them; it cannot supply a second acceptance or permission authority. Board uses
only authorized public metadata/read operations and does not decode application
values or inspect raw objects.

### Work packages and exit gates

| Package | Deliverable | Depends on | Exit gate |
| --- | --- | --- | --- |
| P0 | Neutral Document, lifecycle, authority and cutover contracts | Existing M1/M2 contracts; M6 database boundary | Reviewable operation/state transitions, identities, byte layouts, quotas and consumer inventory |
| P1 | Station-free `transit-document` evaluator and fixtures | P0 | Independent semantic equivalence and dependency checks |
| P2 | `DocumentPartition`, residual `.tseg` trees and recovery | P0–P1 | Atomic acceptance and disk reopen under bounded memory |
| P3 | Direct catalog lifecycle, policy, token binding and reads | P0–P2 | Real signed callers create/edit/read/recover without actors |
| P4 | SQL/query/client and inspection integration | P3 | Shared outcomes, exact revision coverage and current-policy disclosure |
| P5 | Consumer migration, current-v1 replacement and qualification | P1–P4; qualified transaction participants where atomic turns require them | One supported Document implementation and complete affected caller/recovery evidence |

#### P0 — Fix contracts and the migration inventory

Create the proposed `contracts/DOCUMENT_V1.md` and neutral public types in
`transit-protocol`. Define canonical changes, accepted references, revision
lineage, merge profile, definition identity and raw-span commitments when present;
do not manufacture raw-frame provenance for values constructed by an application.
Specify full-width identity handling and exact errors for dependency missing,
identity conflict, stale epoch, unsupported profile, quota, denial, unavailable
history and corruption. A missing dependency does not create a pending queue.

Extend the owning [data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[direct operations](../../contracts/DIRECT_TABLE_V1.md),
[storage](../../contracts/TRANSIT_STORAGE_V1.md) and
[authorization](../../contracts/AUTHORIZATION_V1.md) contracts. Specify:

1. Stable Document/object and partition allocation, immutable definitions,
   initial empty revision acceptance, exact dependency edges, rename, logical
   DROP, retirement and retention. Keep namespace removal, data unavailability,
   history-floor advancement and physical deletion distinct.
2. Authenticated direct edit authority, including the principal/role allowed to
   use a replica and the retained authority of delegated work. A payload replica
   or former writer PID is not permission. Define current checks at admission,
   commit, retry inspection and every read disclosure.
3. Frozen Document intents as a typed `DirectIntent` variant and bindings in
   the existing account/client-token owner. Specify token fingerprint conflicts
   separately from duplicate causal changes, which return the original revision
   even when presented under a different operation. Catalog token settlement
   must reference the partition's receipt rather than invent another commit.
4. One conditional partition acceptance for a single-Document update, binding
   root, logical revision, causal/deduplication indexes and original outcome.
   Object staging and catalog admission may precede it. One data-WAL append is
   not a claim that a complete statement needs one HTTP request or one total I/O.
5. Exact retained read cuts, cursor ownership, progress-only pages, terminal
   coverage, current policy, history availability and deterministic close.
   Lease/pin allocation is bounded and recovery-owned; a reference is not a pin.
6. Category-1 transaction preparation/guards and common-decision visibility for
   the later M5 integration. Define the required atomicity for every existing
   public turn action before choosing its replacement. No new coordinator or
   independent Document-specific transaction protocol.

Audit all imports, public exports, stored records, generated schemas, ABI/host
actions, SDK methods, examples, deployment templates and proof tasks. Record an
explicit replacement for each under P5. This includes unnamed Documents,
writer-side jobs, checkpoints, accepted-tail reads, resynchronization, remote
call recovery and Board's value-free register metadata. Existing `SDS1` fallback
reading and `SDW1` saved waits are part of the removal inventory alongside the
formats already listed in delivery step 6. Keep old-format negative fixtures
for rejection, not successful decoding.

**First review:** settle this contract and atomicity inventory before changing
durable formats or wiring a new endpoint. The current public reference continues
to describe the implemented Station service until the cutover lands.

#### P1 — Extract deterministic Document semantics

Add a real `packages/zig/transit-document` package with its own manifest, public
module, README and checks. Move the semantic responsibilities of `Model`,
`codec`, `Document` and checkpoint evaluation behind neutral bounded interfaces;
leave clocks, authorization I/O, publication jobs and durable outcomes with their
owners. Use explicit `scratch` and `output` lifetimes for variable-sized values,
with reusable arenas/buffers and owned output across page advancement.

Port the existing 24-permutation merge scenarios and independent fixtures to
the neutral contract. Check conflict resolution, missing versus null, type
errors, Unicode/full-width values, same-dot/different-content rejection,
missing predecessors, nested deletion/edit races and deleted sequence anchors.
Add cases exceeding the old payload/operation limits within declared budgets,
and atomic refusal immediately above each budget. No rejected candidate may
advance a replica frontier or expose a prefix. Reuse one merge implementation
across storage and language bindings; SDKs do not implement the algorithm.

Add transitive Station-import rejection for the new package and storage, and
preserve the existing gates in Catalog, direct Query and SQL. A mechanical
extraction may be reviewed separately, but passing this gate alone does not
establish runtime decoupling.

#### P2 — Implement the direct durable owner

Add `DocumentPartition` in `transit-storage`, reusing `TransitLog`, object-store
interfaces, epoch fencing and bounded immutable indexes. Share generic storage
primitives through package interfaces; do not wrap Document edits as Table DML
or import Station's Publication/ImmutableIndex. Extend the shared `.tseg`
format/reader owner for residual tree pages rather than writing a second segment
codec. Bind pages to the exact logical definition, document and revision basis.

Build candidates privately, streaming payload/tree pages and retaining causal
records, frontiers, tombstones and change digests. The final fenced WAL record
publishes the whole accepted root and receipt. Small changes may reside in WAL;
large values use verified durable object references. Bound resident dirty state,
staging bytes and active candidates independently of total history. A serialized
local partition is sufficient; removing the actor must not imply concurrent
writers or unlimited active work.

Implement replay, duplicate/outcome lookup, bounded accepted revision reads,
flush/checkpoint progress and retained-root enumeration together. Register
Document roots, staged work and pins with the existing storage graph/collector
before enabling collection. Unknown or incomplete reachability refuses deletion.
Unlimited retention remains the default; finite merge windows require a complete
checkpoint, epoch/floor advancement and retained replica/deletion evidence.
Physical maintenance never changes a logical revision or supplies a new grant.

Use real `LocalWal`/`LocalSegmentStore` directories for crash/reopen tests, with
one-page/disabled caches and data larger than the resident budget. Inject failure
before object durability, before/after the conditional append, after acceptance
but before reply, and during checkpoint publication. Reopen must recover the
same root/outcome or refuse corrupt/incompatible evidence, never an empty reset.

#### P3 — Replace Document catalog initialization and direct access

Replace only the Document arm of `DirectResource`/`DirectCatalog` and the
Document initialization checks in `NamedResource`/node policy. Named native KV
keeps its existing lifecycle. Reserve an object and partition in the catalog,
accept its empty Document definition in the partition, then settle the original
catalog operation from that evidence. Recover interruption between each phase;
never expose a name whose exact initialized definition cannot be verified.
No supplied resource or PID may silently adopt an unrelated Document.

Expose signed direct lifecycle, mutation, inspect, path/sequence, accepted-tail,
checkpoint and resynchronization operations through the owning public client.
Resolve names once into saved identities. Rename preserves object identity;
DROP/recreate cannot retarget an old edit, read or token. Enforce exact dependency
registration and DROP RESTRICT without granting data access. Define supported
ALTER fields and reject changes that would reinterpret accepted causal history.

Extend token pending discovery, quotas and recovery to Document intents; reuse
`DatabaseRuntime` where SQL submits them. Preserve unknown outcomes and original
acceptance after cancellation races or reply loss. Read operations bind exact
Document revisions and recheck current authority after buffering, including
empty/progress/terminal pages and metadata. Reuse the read-cache mechanism only
after its pin/lease contract can represent Document cuts; do not treat a Table
pin or an independent source vector as a common snapshot.

#### P4 — Wire SQL, Query and observable outcomes

Lower the selected SQL declaration subset through the same typed operations and
existing statement-result machinery. Update the grammar/capability inventory
with executable, offline and unsupported forms separately. SQL text heuristics
must not classify outcomes. Shared typed edits and revision reads are sufficient
for the initial mutation surface; broader SQL Document DML syntax needs its own
contract and is not invented by this plan.

Replace Query's Document source adapter with the new authorized reader, keeping
accepted-only projections, five-state values and exact source attribution.
Keep the direct packages Station-free even where captured Query composition
still lives above them. Board receives definition, accepted revision, pending
operation, merge floor/epoch and bounded value-free metadata through public
operations. A live worker, staged tree or partially read sequence is not a
completed Document outcome. Update the browser schema/validators with the API.

#### P5 — Migrate consumers and perform one public cutover

Move all existing Document consumers with the replacement: shared Zig/ABI/host
bindings; the public Zig SDK and ten non-Zig targets; named-resource and Query
adapters; `examples/station-document`; Board API/browser; local, Compose and
reference deployment wiring; build/package/task inventories. Replace the
Document worker's storage role with database composition. Retain Station
application behavior only as a caller above the database.

For writer-side APIs and remote operations whose state/input/reply previously
shared a turn, require the qualified M5 Document participant and M6 settlement/
outbox composition before switching them. Preserve original accepted identities
and recorded destinations. A direct client response can report its retained
receipt; it cannot substitute for an atomic durable Station reply. This gate
does not delay the P0–P4 component work or complete M5/M6 by implication.

Replace the shared current-v1 definition and regenerate wire/schema, signing,
ABI/host and Board artifacts together. Remove the superseded Document package,
worker, successful old-format decoders, public routes/actions and configuration.
Remove Document's use of `SIX1` and Station Publication; their unrelated Station
consumers remain with M6 until separately replaced. Do not delete shared storage
mechanisms solely because Documents no longer use them.

Reject old Document roots, references, changes, waits, saved intents and
installations before execution or disclosure. Preserve original histories and
uncertain work for resolution with the matching build; supply no implicit
conversion, defaulted definition, fallback decoder or reset. Keep package
versions/internal pins aligned with `VERSION` and run `python3 -B tasks/version.py`
after manifest changes.

Promote implemented semantics and numeric bounds to the Document/state/caller
references, affected package guides and contracts; update the data model,
glossary and component directory. Revise state/storage/query Internals with
source-attributed mechanisms and evidence. Keep this plan and remaining milestone
work in the roadmap. Mark the milestone `In Progress` when implementation lands;
do not mark it complete after decoupling alone.

### Verification and closure of the initial slice

These are required new checks or extensions to existing suites, not passing
results. Use [test ownership](../../tests/README.md) and the scoped instructions
when implementing them.

| Gate | Required observation |
| --- | --- |
| Dependency and runtime independence | Transitive build checks plus a real signed caller/SQL schedule with Document worker and courier absent; zero Station sends/turns or native Document allocations during create/edit/read/recovery |
| Lifecycle and identity | Lost replies at reserve/initial acceptance/settlement, same-token races, conflicting fingerprints, duplicate causal changes under distinct tokens, rename/DROP/name reuse, exact dependency refusal and new empty-object initialization |
| Authorization and fencing | Denied create/edit/read/inspect, forged replica binding, replaced writer/policy epochs, revocation during staging and after read buffering, restored permission revealing the original receipt, retained reads after logical DROP under their declared lifetime |
| Merge and limits | Independent accepted-set oracle across all 24 permutations, detached descendants, explicit conflicts, stale replicas, checkpoint floors and recycled counters; values/changes beyond old limits and typed refusal without partial acceptance |
| Durable publication and recovery | Disk process death and I/O faults around staging, acceptance, receipt delivery and checkpoints; exact root/receipt recovery, corrupt/missing dependency refusal and incompatible-definition rejection |
| Read completeness and ownership | Empty results, progress-only pages, deleted spans, multiple pages, early close, cancelled/failed prefixes, scratch reuse and cache eviction; no cross-revision splicing or accidental EOF |
| Growth and retention | Histories, objects and pending operations larger than caches; bounded replay/page work and admitted memory; warmed allocation counters for selected hot loops; no quota-driven expiry or collection from incomplete graphs |
| Existing atomic consumers | Document mutation, input settlement and reply/outbox share the common decision through crash/conflict/lost reply; unavailable participants block that consumer's cutover |
| Performance accounting | One acceptance append for a single-partition edit; report control/token/staging requests separately, plus end-to-end latency, allocations/RSS, bytes written and restart work against the source baseline |

Start with owning package checks and independent contract fixtures. Extend the
existing `just test::direct-named-resources`, `just test::document`,
`just test::document-remote`, `just test::document-local` and
`just test::unified-query` scenarios to the replacement, preserving their
authority/recovery assertions. Migrate `bindings::document-*`, Board's
`document-test`/`document-browser`, and `examples::document-compose`/
`examples::document-reference` with their actual consumers. Reorganize Document
test ownership from runtime to storage/catalog where appropriate; update tasks
and the suite inventory rather than leaving an old worker-based proof as the
only evidence for a direct database path.

Run affected clean CI lanes from committed implementation HEAD, including
contracts/core, growth, interfaces, bindings, Board/browser and launchers where
the cutover changes them; run explicit Compose/reference placement proofs
separately. Select actual lane names from the suite inventory. Record commands,
source definition, backend, budgets, failures and omissions in the owning proof
ledger with raw evidence. Documentation checks establish no runtime guarantee.

After this slice, M7 still owes versioned/three-way merges, span-block text,
qualified succinct navigation, adaptive shredded subcolumns and pruning, broader
Document SQL/relational execution and the full Table/Document/Stream/Queue
transaction proof. Preserve those completion criteria and M5/M6 dependencies.

## Candidate structures and selection evidence

| Work and candidate | Evidence required before selection |
| --- | --- |
| Succinct tree encoding in `.tseg` ($2N$-bit Balanced Parentheses `BP` vs. `LOUDS` vs. level-indexed flat tape) | Navigation latency (`parent`, `first_child`, `next_sibling`, `LCA`, path lookup) in CPU cycles, bits per node overhead, SIMD construction speed on 1 KiB–10 MiB documents, and equivalence with reference tree oracle |
| Adaptive columnar path shredding (declared + thresholded subcolumns vs. residual succinct tree) | Scan throughput, zone-map pruning selectivity, `.tseg` flush/compaction amplification under sparse/evolving keys, and exact 5-state (`missing`, `null`, `conflict`, `type_error`, `value`) fidelity against unshredded evaluation |
| Span-based collaborative text (`piece_table` / `rope` over `.fsst` `.tseg` blocks) | Edit acceptance and sequence read latency on 100 B–10 MiB texts, concurrent insert/delete convergence across 24+ delivery permutations, and memory bound independence from total document length |

## Completion evidence

Require executable proof through real SQL and typed callers in the
[proof ledger](../history/qualification/README.md):

- **Station independence and single-round-trip latency:** Verify that
  `transit-document`, `transit-storage`, `transit-catalog` and `transit-sql`
  execute `CREATE DOCUMENT`, Document mutations/merges, path reads and `SELECT`
  queries with zero compile-time imports or runtime calls to `Station`,
  committing single-partition Document writes in one `TransitLog` (`TWAL1`)
  append with exact `DirectClientToken` duplicate idempotency and lost-reply
  recovery.
- **Causal CRDT and versioned merge equivalence:** Pass the full 24-permutation
  concurrent delivery suite, duplicate suppression, nested parent-delete vs.
  child-edit detachment, observed-remove multi-value `conflict` preservation and
  resolution, sequence/text ordering, opted-in finite merge-window epoch
  advancement, stale-replica rejection and crash/restart recovery over
  `DocumentPartition` (`TWAL1` + `.tseg`)—plus strings and collaborative texts
  spanning 1 KiB to 10 MiB (verifying removal of the 96-byte scalar limit).
- **Shredded `.tseg` subcolumn and succinct-tree query equivalence:** Prove
  differential equivalence between shredded subcolumn execution (with zone-map
  pruning, `.dictionary`/`.fsst` codecs and `utf8_binary` / `ascii_ci` /
  `ebcdic_cp037` collations) and unshredded succinct-tree traversal across all
  five cell states (`value`, `null`, `missing`, `type_error`, `conflict`),
  snapshots and `.tdel` deletions.
- **Multi-object transactional composition:** Prove that a single
  [Milestone 5](05-transactions-and-atomic-composition.md) transaction atomically
  mutates a `TABLE` and a `DOCUMENT`, `ACK`s a leased `QUEUE` message and
  `PRODUCE`s to a `STREAM`, rolling back all participants on conflict or crash
  before the common decision and recovering the committed outcome on lost reply.

## Later owners and execution gates

- [Gateway architecture, sans-I/O wire protocols and direct-plane ingress](08-gateway-architecture-and-protocol-ingress.md),
  [shared client foundation](09-client-foundation-and-language-apis.md) and
  [SDK coverage](22-service-and-sdk-coverage.md) expose idiomatic Station-free
  `Document` APIs and direct-plane ingress across target languages over this
  package boundary.
- [Standards and historical catalogs](10-standards-and-catalogs.md) and
  [indexing](11-indexing-and-access-paths.md) extend `AS OF` snapshot binding
  and secondary path/structural indexes over `DocumentPartition`.
- [First-class strings and vectorized search](15-vectorized-strings-and-search.md)
  and [Document type library and gateway exchange lifecycle](17-document-profiles-and-gateway-exchange-lifecycle.md)
  build 16-byte Umbra/German strings, `comptime` perfect hashing, vectorized
  Block-Max BM25 / structural `NEAR` search, the multi-format Document Type
  Library (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`) and unified gateway/connector
  exchange capture on top of `DocumentPartition`.
