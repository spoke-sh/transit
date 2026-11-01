# transit-document

Deterministic structured Document changes, observed-remove conflicts and ordered
list/text traversal, exported as `transit_document`. This package has no runtime
dependencies. Persistence, current authorization and accepted publication belong
to the caller of its immutable-index interface.

`Model` and `codec` own the existing canonical change profile described in the
[Document contract](../../../contracts/STATION_DOCUMENT_V1.md#identity-and-changes).
`Document(Index)` evaluates that profile over an owner-supplied ordered index.
`apply` returns a private candidate; publishing its root is a separate decision.
Failure leaves the input snapshot unchanged, although an index may have staged
unreachable objects. The owner must retain or disposition those objects safely.

The index supplies owned bounded `Key`, `Value` and `Entry` types, an optional
validated root, and immutable `get`, `next` and `put` operations against an
explicit source/store. Ordered keys use unsigned byte order. `next` excludes its
continuation key; read errors must not become absent keys or end-of-input. Reads
must remain bound to the selected root. `put` returns a new candidate index and
cannot publish or mutate an earlier root. Pending builder lifetimes must cover
the complete evaluation and be finalized before storing a snapshot.

The current profile retains eight operations per change, eight unresolved
assignments per register, 64-byte field names and 96-byte inline scalar values.
Text is an ordered sequence of Unicode scalar elements. Extraction does not
change wire bytes or implement larger scalars, new merge profiles, succinct
trees, or database admission. The [Station service](../transit-station-document/README.md)
uses this same evaluator with its current publication and acceptance boundary.
The independent [`DocumentIndex`](../transit-storage/docs/document-index.md)
adapter stages private candidates in direct `.tseg` storage; it supplies no
database acceptance or installed caller route.

For the direct [Document contract](../../../contracts/DOCUMENT_V1.md), this
package also exports:

- [`SuccinctTree`](src/SuccinctTree.zig): $2N$-bit Balanced Parentheses (`BP`)
  succinct tree bitvector (`SBPT0001`) with two-level `@popCount` rank/select
  and excess summaries supporting zero-allocation `parent`, `firstChild`,
  `nextSibling`, `subtreeSize`, `depth`, `isAncestor`, `within`, and `lca`
  navigation.
- [`SpanText`](src/SpanText.zig): span-based collaborative UTF-8 text supporting
  arbitrary-length contiguous spans beyond 96 bytes, interior span splitting,
  range tombstones, 24-permutation causal convergence, and step/byte-bounded
  sequence reads.
- [`VersionedMerge`](src/VersionedMerge.zig): five-state cell algebra (`value`,
  `null_value`, `missing`, `type_error`, `conflict`), raw-frame provenance
  anchors, commutative three-way structural merges (`mergeThreeWay`), path
  evaluation, and `SuccinctTree` lowering.

`zig build test` in the pinned development shell exercises the change codec and
merge rules against an independent append-only index fixture, including all 24
concurrent delivery permutations, candidate failure, detached descendants,
deleted anchors and original duplicate revisions. Station's own tests exercise
its real immutable-index adapter and service recovery. These are separate
boundaries; the volatile fixture establishes no disk durability.

`LogicalChange` and `CausalTree(Index)` supply the integrated causal map-tree
storage slice. Changes borrow request bytes and use full 128-bit document/replica
identities, operation ordinals and length-delimited fields/values. The evaluator
stores assignment evidence, active registers and chunked names/values through an
immutable index supplied by its owner. It has no Station, clock, authorization or
I/O dependency. It returns private state; the storage partition decides acceptance.
See the [canonical format and limits](../../../contracts/DOCUMENT_V1.md#integrated-causal-map-tree-storage-slice).
The installed `Model`/`Document` evaluator remains the existing Station contract;
this addition does not migrate its callers or claim BP/subcolumn integration.
