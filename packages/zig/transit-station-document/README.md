# transit-station-document

Zig Station Document changes, structured merge and collaborative plain text for
[M17](../../../docs/roadmap/M17.md). Depends directly on `transit-station` for
immutable publication/indexes; it does not depend on effect connectors.

The [neutral v1 contract](../../../contracts/STATION_DOCUMENT_V1.md) fixes stable
replica/operation identities, canonical changes, observed-remove map conflicts,
list/text ordering and bounded accepted-state reads. The
[model design](../../../docs/DOCUMENTS.md) records the choices and limits.

`Change` owns up to eight operations. `codec.encode/decode` validate its neutral
format; `Document.apply(store, change)` returns a candidate snapshot and original
acceptance revision for duplicates. Callers must bind successful candidates in a
fenced final turn. Applying to an immutable index does not itself accept work or
grant execution rights. Partial or rejected candidates leave the input snapshot
unchanged; unreachable nodes require explicit disposition.

`Document.field/path` return owned bounded registers with missing, null, scalar,
object and conflict states. `sequenceStep` performs one bounded traversal
transition and returns an item, progress continuation or end. Keep its exact
snapshot and bound transitions per page. Inline strings/binary are limited to
96 bytes; growing editable text uses one Unicode scalar per stable element.
There is no normalization, grapheme indexing, move/reparent or external CRDT
format compatibility. Eight unresolved assignments per field are an explicit
quota, not an expiry mechanism.

Run `nix develop --command sh -c 'cd packages/zig/transit-station-document && zig build test'`.
The [durable service guide](docs/service.md) describes recorded jobs, atomic head
acceptance, current-policy reads, resynchronization and rejected-job cleanup.

Component tests cover 24 concurrent delivery permutations, duplicates, nested
delete/edit races, text and list ordering, conflict resolution, missing/null/type
errors, full-width integers, Unicode, source denial, storage failure and text
spanning thousands of index entries. Private-turn tests also reconstruct every staging step and verify final acceptance
within the unchanged mutation budget. These are component proofs: disk recovery,
checkpoint/compaction, all public SDKs, Board and placement proofs remain open.
