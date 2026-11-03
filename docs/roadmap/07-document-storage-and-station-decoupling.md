# 7. Logical document storage, `.tseg` trees and Station decoupling

[Roadmap](README.md) · [Foundation #125](https://github.com/spoke-sh/transit/issues/125) · [Native State #126](https://github.com/spoke-sh/transit/issues/126) · [Layouts & Codecs #128](https://github.com/spoke-sh/transit/issues/128) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress — Causal maps and conditional ordered/versioned trees with verified raw parts are integrated as storage components. Next finish merge/physical-layout gates, direct lifecycle, transaction participation and the coordinated Station/consumer cutover ([remaining implementation plan, 2026-11-02](#implementation-plan-for-remaining-work)).

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
   collation-prefixed Umbra/German strings ([Milestone 14](14-vectorized-strings-and-search.md)),
   collation-aware zone-map pruning, vectorized `Fuze` scans or single-round-trip
   [Milestone 5](05-transactions-and-atomic-composition.md) database commits.

This milestone brings `DOCUMENT` into the Direct Data Plane alongside `TABLE`,
`KV`, `STREAM` and `QUEUE`, supplies the Document facet to the shared Station-free
client foundation already being built in [Milestone 9](09-client-foundation-and-language-apis.md),
and establishes the storage boundary for
[Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md)'s
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
   - **Verified Raw-Frame & Multi-Part Container Storage:** Retain immutable
     staged raw byte/text frames and multi-part container directories (such as
     `MIME` multipart bodies, `OPC`/`ZIP` package parts for `DOCX`/`XLSX`/`ODF`,
     and `PDF` `xref`/stream objects, verified by SHA-256 chunk coverage
     commitments and bounded by explicit decompression quotas) in `.tseg` blob
     pages so slices borrow directly from swizzled LeanStore/Umbra RAM/NVMe
     buffer slabs.

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
`5e00b53bfed8a552dc7306e1338394ec037ac9bb`, 2026-11-02.
This replaces the remaining-work assessment at `c8d060cb2` and its integration
at `f49a3da65`; C0–C8 remain the stable completion packages. The
[initial plan](#implementation-plan-for-initial-document-decoupling) and dated
delivery/evidence records retain their scope and attribution. Only merged source
is treated as available; work in other branches or worktrees is not a prerequisite.

The new basis includes M7 causal storage (#319), M6 workload SQL, automatic
Queue transfers and recovery qualification (#321/#333/#336), M8 connection
startup and performance work (#315/#325/#330), M10 historical interpretation
(#320), M12 retained results and owned staging (#318/#324/#328), M14 production
strings/predicate reuse (#316/#329), M16 parsing/construction (#317/#327), and
Board's local access, storage and independent computation inspection
(#332/#335/#338/#339/#340). Their installed profiles and remaining gates are
distinguished below. No runtime suite was rerun to create this plan.

**Outcome:** an application declares a Document object, applies causal or
versioned changes, reads exact accepted revisions and relational projections,
and recovers its original outcome after disconnect or restart without a Document
worker. A Station behavior uses that same data owner inside a transaction that
also settles its input and records outputs. M7 remains **In Progress** until
both journeys, the physical storage path and the affected consumer cutover pass.

### Delivered basis and remaining obligations

The [2026-10-30 component evidence](../history/qualification/storage.md#direct-document-protocol-succinct-algebra-tseg-shredding-and-documentpartition--2026-10-30)
records D0–D3 and the authority/graph portion of D4. The
[2026-11-01 causal storage evidence](../history/qualification/storage.md#integrated-causal-document-map-trees--2026-11-01)
adds evaluated map roots, disk reopen and authenticated value paging. Preserve
both records' source revisions and exclusions. The audit below describes the
new plan basis; the [partition guide](../../packages/zig/transit-storage/docs/document-partitions.md)
owns the component's current behavior. Component integration does not establish
an installed direct Document service.

| Boundary at the plan basis | Existing implementation | Work still required |
| --- | --- | --- |
| Installed Document lifecycle | [Public Documents](../handbook/reference/documents.md), `transit-station-document`, `DirectResource` and `NamedResource` still use native resource allocation and Station initialization/publication | Replace that lifecycle and every affected caller together; preserve state/input/reply atomicity |
| Neutral contracts (D0, partial C0) | [`DOCUMENT_V1`](../../contracts/DOCUMENT_V1.md), declarations/receipts and `DCHANGE1` causal-map changes bind full-width identities and mandatory definitions | Extend canonical operations to ordered trees, spans, conditional versioned updates, complete ancestry, staged parts, collection cuts and transaction bindings |
| Deterministic algebra (D1, partial C1) | [`LogicalChange`/`CausalTree`](../../packages/zig/transit-document/README.md) evaluate maps through a paged index; `SuccinctTree`, `SpanText` and `VersionedMerge` have separate component oracles. Installed `Model`/`codec` retain the old profile | Integrate ordered trees, list/span edits and versioned evaluation with bounded persistent readers/builders. Resident arrays and recursive trees do not prove paged growth; zero-allocation navigation does not prove constant time |
| Physical layout (D2, partial C2) | [`DocumentShredder.shredBatch`](../../packages/zig/transit-storage/src/DocumentShredder.zig) builds owned in-memory subcolumns, bitmaps, zone maps and residual topologies; `DocumentIndex` stores the integrated causal records in `.tseg` rows | Persist/reopen BP, spans and subcolumns through the shared segment writer/reader, bind all structural and codec descriptors, and execute queries against actual accepted segments |
| Durable owner (D3, partial C3) | [`DocumentPartition.applyCausal`](../../packages/zig/transit-storage/src/DocumentPartition.zig) derives map roots/counts and accepts through one fenced WAL append. Pinned path pages own up to 240 value bytes and enforce cumulative budgets/current rights. Opaque `applyMutation` cannot replace a logical root | Integrate the remaining logical profiles, BP/subcolumns, raw parts, logical checkpoints, collection scans and installed lifecycle. The opaque receipt seam is not an ingestion API; its whole-state reads are separate from logical value paging |
| Recovery and cursor keys | `open`/`recoverStep` replay bounded units (default 64 records, permitted 1–256), reuse per-record scratch and refuse operations until ready. A nonzero host-supplied `read_secret` is mandatory | Preserve these safeguards while adding logical pages and transaction records; prove bounded candidate construction, checkpoint validation and installed cold recovery. Root readiness is not an exhaustive scrub or zero-allocation claim; define installed key persistence/rotation |
| Two deduplication identities | Same-operation retries recover their receipt. Identical causal changes under another operation receive a receipt for the first revision without advancing the head | Preserve both identities through new layouts, checkpoints, archive/trim and transaction preparation. Changed bytes at either identity must still refuse |
| Catalog/authority (partial D4) | [`DocumentAuthority`](../../packages/zig/transit-catalog/src/DocumentAuthority.zig) supplies masks/bindings; `DirectStorageGraph` walks Document roots | Add the actual Document domain/profile/registrar, typed lifecycle and payload operations, signed node dispatch, original-token recovery and installed disclosure checks. The configured profile still has the six database/schema/Table/Stream/Queue/KV domains |
| Mixed transaction owner (D5 prerequisite) | `DirectTransaction`, `TransactionDirectory`, private state/log workspaces and `TransactionDecisionLog` now execute Table/KV/Stream/Queue composition. Installed schedules recover original mixed decisions and explicit paired Queue transfers | Documents still reject in `Participant.requireLocalState`, `Guard.requirePagedState`, `DirectCatalog` selection and decision preparation. Add a partition-aware Document cut/workspace/preparation path; removing rejection branches alone is insufficient |
| SQL, shared clients and installed consumers (D5) | M4 results, M6 declaration/workload settlement, M8 local dispatch/startup continuations, M9 Catalog/context/recovery, and M30 independent read-only inspection exist | Add direct Document dispatch, SQL lowering and queries; migrate Station/ABI/SDK/Board/examples under the current-v1 policy. Board persistence and M16 profile publication still require the new public owner |

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

The ordered storage increment now also reads parent/child/sibling, depth and
subtree boundaries from persisted BP chunks under an exact retained revision.
The neutral traversal uses a bounded ancestor stack; the partition owns chunk
access, bit/lookup budgets and current disclosure checks. This extends C2/C3's
structural-read path without changing accepted formats. It remains a linear
scan, with no persisted rank/select directory or constant-time navigation claim.
The [partition guide](../../packages/zig/transit-storage/docs/document-partitions.md#ordered-versioned-trees)
owns usage and limits. C1 merges, the remaining physical-layout gates and the
direct lifecycle/transaction/consumer work remain open.

The ordered candidate handoff also composes M16's MIME entity reader with the
same accepted residual/BP representation. It preserves duplicate header order,
unfolded field values, exact raw spans and a single binary body independently of
parser windows. This advances C2/C3's profile handoff without adding a transport
owner or persisting profile attestations. The
[candidate mapping](../../packages/zig/transit-document-profiles/README.md#ordered-storage-candidates)
owns its complete-frame input/output bounds; incremental staging, multipart
graphs, direct lifecycle and the C7 exchange/Station cutover remain open.

1. **Continue from the merged causal path.** Full-width map changes, derived
   acceptance, cross-operation causal deduplication and within-value paging are
   implemented. The next packet extends that path to persisted ordered/versioned
   trees and parts; it does not repeat the old plan's first map-storage increment.
2. **Make the next consumers concrete.** M16's ordered JSON/XML and compound
   commitments expose representation gaps that a causal map cannot cover. M30's
   saved drafts need conditional versioned edits, collection listing and accepted
   operation discovery. Specify these shared contracts now; no private parser
   store, Board write route or selectable second Document engine is authorized.
3. **Consume actual database progress.** Extend M6's existing mixed owner and
   preserve its newer clean core/SQL/storage-query evidence. Reuse M10 historical
   interpretation, M12 owned preparation roots and M14 production string kernels.
   Their passes do not qualify Document participation, retention or performance.
4. **Keep the runtime dependency exact.** M6 R7/R8 still own transactional Station
   and effect/delivery replacement. Develop the Document participant before that
   adapter, then qualify their composition. M20 Table branches, M16 offline
   parsers and M30 inspection do not close the public Document cutover gate.

### Milestone context and dependency handoffs

| Owner | Consume now | Dependency or boundary for M7 |
| --- | --- | --- |
| [M1–M3: lifecycle and local storage](03-live-storage-and-sql-cutover.md) | Stable object/definition identities, direct catalog names/dependencies, `LocalWal`/`LocalSegmentStore`, publication guards, retained graphs and local installation | Preserve original named-Document lifecycle/recovery coverage while replacing its mechanism. M3 remains independently In Progress; M7 does not close its other storage or latency gates |
| [M4: statement results](04-statement-results-and-consumption.md) | Implemented command/`ResultSet` distinction, bounded consumption and terminal observation | Use `transit-sql-results` and `transit-sql-client`; no Document-specific SQL result or recovery protocol |
| [M5: transactions](05-transactions-and-atomic-composition.md#selected-delivery-profile-and-exclusions) | Completed local serializable Table profile, common cuts, durable preparations/decisions, private workspaces and savepoints | Its completion excludes direct Document and log settlements. C5 supplies Document obligations to the same decision owner |
| [M6: streams, queues and runtime](06-streams-queues-and-durable-runtime.md#queue-settlement-sql-follow-up--2026-11-02) | Direct KV/logs and native mixed decisions; automatic terminal Queue transfers; SQL append/consume/claim/ACK/NACK and original-operation recovery. Selected clean core/SQL/storage-query lanes and unordered Queue cold recovery have recorded passes | Extend R5 with Document cuts/preparations. Renewal SQL, groups/waits/offset SQL, `STREAM_SLICE`, mixed SQL and complete resource/fault baselines remain open. R7/R8's real transactional Station/effect replacement gates C7; independent workload SQL does not supply atomic Document turns |
| [M8: gateway](08-gateway-architecture-and-protocol-ingress.md#connection-startup-continuations--2026-11-01) | Event-driven SQL recovery, typed local dispatch, node-cohosted execution, pure PG/MySQL command/startup continuations and host-owned TLS/credentials. Later startup/validator work has scoped measurements | Reuse host admission, output lifetimes and resumed-disclosure checks. Socket deadlines/scheduling, core-bounded workers, coarse remote SQL and Flight/Serving integration remain M8 work. Add no Document polling service or per-page HTTP orchestration |
| [M9: shared clients](09-client-foundation-and-language-apis.md#implemented-context-and-kv-recovery-increment--2026-11-01) | [`Catalog` and `Context`](../../packages/zig/transit-data-client/README.md), bounded data/control leases and admission waits, direct KV dispatch, frozen SQL submission and explicit `LocalRecoveryStore`/`SqlRecovery`/`KVRecovery` | Supply the minimal owned Document caller and compose its context facet; reuse the persist-before-send and original-outcome recovery boundary. Ordinary Catalog/log settlement, native principal coordination, aggregate accounting, managed handles and installed data-language APIs remain M9/M21 work; M7 cannot defer migration of existing affected consumers to them |
| [M10: historical interpretation](10-standards-and-catalogs.md#progress-pr-scope--2026-11-01) and [M11: indexes](11-indexing-and-access-paths.md) | Persisted interpretation, retained historical catalogs/SQL, distinct CP037 PAD SPACE/CP1047 NO PAD semantics and shared capability inspection; common-revision M10 closure remains open | Extend exact retained interpretation to Documents; Table historical SQL is not Document `AS OF`. Bind accepted collation/encoding descriptors without silently adding CP1047/ICU to the Document profile. M11 owns secondary indexes; M7 owns base tree/subcolumn access |
| [M12: dataflows](12-sql-and-dataflows.md#next-implementation-slice-owned-staging-and-finite-qualification) | Installed finite Table computations, immutable DFR1 results, transaction-owned candidate roots and abort collection; declaration/work-record cleanup remains open | Reuse neutral ownership/graph seams for Document candidates and preparations. Supply Document source/revision/change evidence; do not treat DFR1 as Document storage or enable continuous/multi-source Document activation through it |
| [M13: resource/performance](13-data-structures-and-performance.md), [M14: strings](14-vectorized-strings-and-search.md#encoded-predicate-reuse-increment--2026-11-01), [M15: compilation](15-data-centric-compilation-and-specialization.md) | Production lossless 16-byte Batch strings, safe external tails, allocation controls and shared per-column dictionary/FSST predicate traversal | Integrate `TSegReader`/`PhysicalCodecs` rather than the removed prototype evaluator. Preserve raw projection and ordered failures. Retained operator keys, full resource metering, durable search and AOT/adaptive compilation retain their own gates |
| [M16: profiles and exchanges](16-document-profiles-and-gateway-exchange-lifecycle.md#immediate-representation-gap-and-m7-acceptance-handoff) | Offline bounded JSON/XML readers and constructors, ordered events, raw offsets, compound commitment fixtures and local part verification | C0–C3 supply ordered/residual nodes, immutable parts and verified publication; causal maps cannot preserve duplicate JSON members, arrays, exact number lexemes or XML mixed content. M16 owns parsers, unpackers and exchange capture; no `STATION_EXCHANGE_V1` replacement in M7 |
| [M19: interactive assets and simulation](19-game-asset-pipelines-and-simulation-streaming.md) | Planned consumer of generic Document trees, container parts and immutable revision identities | Preserve those generic storage boundaries. Asset importers, cooking dataflows, GPU/engine adapters and simulation streaming remain M19 and its M16–M18 prerequisites; they add no prerequisite to this storage slice |
| [M20: branches](20-branches-merges-and-restore.md#local-table-branch-increment) | Durable immutable single-Table branches, operation-owned retained pins, bounded ancestry/manifest helpers and collection/disclosure checks | Begin Documents on branch one. Reuse pin-ownership and reachability patterns, while explicitly refusing Document branch operations. Versioned Document merge is not catalog branch merge; M20 owns multi-model branching and restore |
| [M22: formal correspondence](22-formal-semantics-and-correspondence.md), [M27: policy](27-control-and-policy-plane.md), [M28: published resources](28-published-resources-and-investigations.md) | Finite decision/workspace models, native grants, interpretation and current disclosure boundaries | Extend affected production replay/negative controls with the new participant; existing Table/log model checks do not prove Document atomicity. Preserve browser/application-migration gates; retained revisions are not investigation pins or a new policy authority |
| [M30: Board](30-board-reimplementation.md#local-connections-and-document-persistence-plan--2026-11-02) | Automatic local data access, reactive storage inspection and independent managed-computation reads are merged; saved workbook/preferences/connection Documents remain planned | Deliver versioned expected-revision updates, ordered cells/long text, bounded logical-document listing and accepted-operation lookup through C0–C4. Prove the non-browser journey before M30 L3/L4. Existing inspection stays read-only; application saves use a separate typed caller. Basic drafts do not require M28 retained-result publication |

The storage-to-caller path is **C0 → C1/C2 → C3 → C4 → C6**; each logical
profile crosses evaluation, disk persistence and recovery before its adapters.
C5 can develop after C0/C3 against M6 R5's delivered participant owners. C7 joins
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
delivered causal-map integration, add conditional versioned ordered trees next,
then finish causal sequence/span semantics and qualified three-way merges.
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

No C package is complete at this baseline. C0/C1/C3 include the merged causal-map
vertical path; C2 has component shredding/BP support and causal record segments,
not the target integrated layout. C4 has the authority/graph foundation only.
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

Specify canonical mutation bytes and state descriptors, typed path addressing
(including separator/escaping ambiguity), root/ordered-child/attribute semantics,
logical deletion, revision-parent sets and raw-frame/part coverage. A
`raw_span` coordinate alone is not proof that bytes exist or match their source.
Pin schema, merge profile, collation and interpretation in every retained root,
intent and result. Define the generic part directory's identity, reference,
cycle/depth and byte limits; format-specific unpacking remains M16.
Resolve the old evaluator's `u64` Document/replica identities versus the direct
contract's 16-byte identities without truncation or hashing away equality.
Freeze multi-parent revision ancestry and the meaning of `immutable_lineage`
before persisting versioned merges; the current optional `parent_revision` is
not a complete arbitrary ancestry contract. Separate expected accepted head,
merge base and candidate parents. Start versioned integration with conditional
create/replace/path-patch, then explicit three-way merge; a stale save must report
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
Reuse M12's neutral transaction-owned root protection where applicable; extend
the catalog/storage contract for standalone Document candidates. Record owner,
operation, definition, root inventory and creation fence before a collector can
observe staged bytes. Resolve or fence uncertain attachment before explicit
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

Persist an ordered residual representation before requiring path promotion.
Use M16 fixtures to prove duplicate JSON members, arrays, exact number lexemes
and XML attributes/mixed content survive reopen and reconstruction. Copy borrowed
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
proofs for changed consumers. Before pushing implementation, run affected
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

The next-PR scope below now has a component implementation: canonical `DORDER01`
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

This advances packets 1/2 without closing C0–C3. Profile attestations and compound
container graphs are not persisted by the generic tree; multi-request staging,
rank/select navigation, incremental patches, adaptive subcolumns, logical
checkpoints, causal lists/span edits and three-way merge remain open. Patches
currently rebuild the resulting tree and envelope within declared work budgets.
C4/C5 caller/transaction work and the coordinated C7 consumer replacement retain
their existing dependencies. M7 remains **In Progress**.

### First implementation changes

Implement these reviewable changes from the merged causal-map baseline,
preserving C0–C8 as the full completion checklist. Each storage packet includes
its own disk/recovery proof before dependent adapters. Storage and participant
work can land independently; public exposure and consumer replacement share the
coordinated release gate.

| Order | Change | Evidence needed to start the next dependent change |
| --- | --- | --- |
| 1 | C0 contracts and capability/removal inventory: ordered nodes, conditional versioned writes, ancestry/parts, staged ownership, discovery and partition-aware transaction cuts | Canonical positive/negative fixtures, explicit numeric workspace/page/request budgets and current-v1 rejection cases. Keep the existing causal path as a regression |
| 2 | C1–C3 persisted ordered residual/BP tree and versioned create/replace/path-patch; verified immutable raw parts using the M16 candidate interface | One-partition disk journey: ordered values and long text reopen exactly, stale expected head refuses, a lost reply recovers the same revision, late parser/hash failure publishes nothing, reads survive scratch reset and revocation |
| 3 | C1–C3 complete causal lists/span edits, three-way versioned merge and logical checkpoints; preserve map deduplication and original receipts | Accepted-set/merge oracles, deleted anchors, multibyte spans, merge-window resync, retained old reads and bounded disk recovery. Grow text/history past caches without raising cardinality limits |
| 4 | C2/C3 persist adaptive subcolumns, shared string kernels and physical maintenance | Shredded/residual equivalence under five states and admitted collations, actual pruning, cold reopen/compaction, verified parts and owned-candidate collection races; measured page/heap/byte bounds |
| 5 | C4 catalog/domain/bootstrap/native dispatch and owned typed caller, including collection listing and accepted-operation discovery; C5 in a separate review against the same qualified roots | Signed create/edit/list/read/recover without worker/courier; independent reader and concurrent conditional saves. Then Table + Document, multiple Documents/partitions, Queue ACK + Stream append share one original decision through faults |
| 6 | C6 selected SQL lifecycle/metadata and finite Fuze projections, using M4 results and M10 interpretation | Real compiler/service/console outcomes, empty/multi-batch/failed prefixes, unchanged retained cuts, current buffered disclosure and exact original recovery; no syntax claim from parser acceptance alone |
| 7 | C7 real transactional Station Document behavior and existing ABI/SDK/Board/example replacement when M6 R7/R8 handoffs pass | State, exact input lease, journal and reply/output intents commit together; replacement resolves the original decision without handler replay. Run actual installed consumers, preserving read-only inspection |
| 8 | C8 coordinated removal, final regeneration and common-revision qualification | All C0–C8/completion criteria, actual resource/performance and affected clean lanes, removal inventory and public documentation agree. M16/M30 can consume the qualified public owner; their remaining features keep their own gates |

**Selected ordered-storage PR scope:** finish the packet-1 contract subset required for
packet 2, then deliver that ordered/versioned disk path with its independent
fixtures. Target `DocumentOperation`/`DocumentRead`, the deterministic
`transit-document` reader/builder, `DocumentPartition`, segment/graph owners and
their tests. Pair it with M16's existing profile fixtures and a versioned
workbook-shaped fixture; do not add a Board route or executable Document SQL yet.
Conditional saves are an initial subset of the required versioned merge profile,
not a new profile tag or a reason to omit three-way merge.

After packet 2, bounded C4 lifecycle/caller and C5 participant development can
proceed while packets 3/4 finish; neither needs all of M6, M9 or M16 completed.
M6 can qualify a Table/KV transactional behavior independently. The Document
behavior then joins its exact input/output decision, and the public replacement
ships only after its consumer, storage and recovery gates pass. If that handoff
is unavailable, land qualified private components and keep the installed Station
Document owner and M7 status unchanged.

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

This earlier plan records the initial extraction and its original gates.
Use the [current completion sequence](#remaining-work-packages-and-gates) for new
implementation; its source audit accounts for subsequent D0–D4 components.

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
  [SDK coverage](21-service-and-sdk-coverage.md) expose idiomatic Station-free
  `Document` APIs and direct-plane ingress across target languages over this
  package boundary.
- [Standards and historical catalogs](10-standards-and-catalogs.md) and
  [indexing](11-indexing-and-access-paths.md) extend `AS OF` snapshot binding
  and secondary path/structural indexes over `DocumentPartition`.
- [First-class strings and vectorized search](14-vectorized-strings-and-search.md)
  and [Document type library and gateway exchange lifecycle](16-document-profiles-and-gateway-exchange-lifecycle.md)
  build 16-byte Umbra/German strings, `comptime` perfect hashing, vectorized
  Block-Max BM25 / structural `NEAR` search, the multi-format Document Type
  Library (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`) and unified gateway/connector
  exchange capture on top of `DocumentPartition`.
