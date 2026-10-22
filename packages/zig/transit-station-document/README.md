# transit-station-document

`JsonValues.Reference` provides the neutral JSON form of an accepted reference;
wide identities/revisions use checked decimal strings. It delegates validation
to `Client.Reference`. Query and language binding conversions share this type.

Zig Station Document changes, structured merge and collaborative plain text for
[Documents](../../../docs/reference/documents.md). Depends directly on `transit-station` for
immutable publication/indexes; it does not depend on effect connectors.

The [neutral v1 contract](../../../contracts/STATION_DOCUMENT_V1.md) fixes stable
replica/operation identities, canonical changes, observed-remove map conflicts,
list/text ordering and bounded accepted-state reads. The
[model design](../../../docs/reference/documents.md) records the choices and limits.

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
within the unchanged mutation budget. Incremental checkpoint tests preserve
unlimited history, advance opted-in epochs/floors only at final publication,
reject stale edits and recycled counters, and reclaim rejected/retired intervals.
The disk-backed `just test::document` additionally qualifies real worker/node/
store loss, exact retry, current-policy reads and bounded cleanup with a one-page
authority cache. See [proof evidence](../../../tests/README.md#m17-qualification).
All ten public SDKs now pass the installed Document change/read recovery schedule.
The real two-client local remote-submission proof, Board API/browser checks and
isolated Compose/reference placement proofs pass.

`Request`, `Caller` and `Remote` now provide [authenticated submission and
original reply routing](docs/remote.md). Component tests qualify admission,
recovery and final acceptance within the unchanged four-mutation budget;
the two-client disk proof additionally qualifies actual worker/node/store loss
and original correlated replies. The placement guide records the additional
[Compose/reference boundaries](../../../examples/station-document/docs/placement.md).

`Client` provides current-policy descriptions, typed path/sequence reads, accepted
tail changes and resynchronization independently of writer ownership. Its SDR1
reference fixes resource, Document, epoch, type revision and accepted revision.
Each response names the actual resource cut; old references never bypass the
current history floor or retirement. Public language wrappers expose these reads
and scoped writer jobs through the shared Zig binding.
