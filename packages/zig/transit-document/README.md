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

`zig build test` in the pinned development shell exercises the change codec and
merge rules against an independent append-only index fixture, including all 24
concurrent delivery permutations, candidate failure, detached descendants,
deleted anchors and original duplicate revisions. Station's own tests exercise
its real immutable-index adapter and service recovery. These are separate
boundaries; the volatile fixture establishes no disk durability.
