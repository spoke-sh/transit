# Immutable ordered indexes

`ImmutableIndex` provides paged immutable materialization over
[Publication](publications.md). The [v1 format](../../../../contracts/STATION_INDEX_V1.md)
fixes ordered node encoding and immutable references. It does not implement CRDTs,
Document acceptance, permissions, checkpoints or automatic reclamation.

An index value owns an optional root reference. `get` returns one owned value;
`next` returns the first owned key/value strictly after a supplied key. Preserve
the same root while paging and choose an explicit output limit. `put` returns a
new index, copying only its changed path. Old roots remain readable. Identical
replacement returns the existing root without writing nodes. Empty values are
valid; missing keys return null. Consumers represent tombstones explicitly and
rebuild under their own compaction policy; the index does not erase history.

`remove` copies the selected key's path, prunes empty branches and collapses
single-child root paths. Missing keys retain the same root and allocate no new
nodes. Older roots remain readable. Failed candidate writes never modify the
accepted root; the composing owner retains publication and cleanup authority.

Keys are 1–128 bytes, values 0–256 bytes, fanout eight and levels 0–31. Serialized
nodes never exceed 4096 bytes. Traversal has no heap allocation; bounded recursive frames hold nodes/paths,
independently of the number of retained nodes and roots. Publication adapters
cache at most eight verified 4096-byte node bodies for the exact source basis.
Every cache hit still opens the publication descriptor through its source and
checks lifecycle and commitment. Callers using snapshot byte caches must check
current permission and Document availability before disclosure. Changing resource
cut or namespace invalidates cached bodies; no permission, Document head or
history availability is cached. An index source must provide `load(reference,
buffer)` and a writer must also provide `save(spec, bytes) -> unique_id`. Every
read verifies the node's Publication commitment, level, minimum key and entry
count. Malformed nodes and missing/unavailable sources are errors, never an empty
result. Valid tree construction is a framework responsibility; the kernel does
not prove application computations honest.

`Reader(Source)` adapts a currently authorized or retained Publication source.
It reads bounded chunks under that source and never invents a fresh read view.
Sources may implement `prefetch(keys)` to acquire up to eight known Publication
chunk keys together. The cache still passes every chunk through Publication
verification before accepting the node body. This changes neither the immutable
format nor the root's availability and permission requirements. The interactive
query adapter uses signed snapshot point batches and rechecks current source
policy before disclosing results.
Consumers also check whether the particular root/Document remains available;
possessing an immutable reference alone grants neither access nor retention.

`Staging` adapts a growing private turn. The consumer first durably reserves a
nonzero, exclusive record interval and freezes the candidate's starting root and
changes. On each new turn, reconstruct `Staging` with that same interval and
recompute the bounded candidate. Previously published nodes validate and reuse
those exact identities. At the first unfinished node, it prepares one ordinary
Publication begin/append/publish operation and returns `IndexStaging`. Handle
that result by committing **staging progress only** and scheduling another turn.
Discard the turn for any other error. Do not persist a partly computed new root
or continue reading after private staging writes.

Once construction returns successfully, its nodes were already published before
that turn. The consumer can validate its complete change and atomically bind the
new root in its accepted head with input progress and outputs. Root publication
and acceptance are separate from individual node publication. Host replacement
requires fresh Transit ownership and the recorded candidate; local counters or
files cannot select replacement identities. Exact signed uncertainty retains the
normal Station recovery rules.

Candidate failure may leave unreachable published nodes. The owning job must
track its reserved interval and disposition, bound active candidate work and
explicitly reclaim unreachable records only after checking retained roots.
Storage pressure never authorizes cleanup. Reusing a staged ID with different
content fails as `IndexCandidateChanged`; retired/abandoned IDs remain closed.

The standalone Station tests qualify 1024 permuted keys, replacement and old-root
reads, strict ordered continuation, full-size keys/values, duplicate writes,
failed path copying, corrupted references and read denial. A private-turn proof
stages 24 accepted roots through the real Publication functions, repeatedly
reconstructs the candidate, enforces four-mutation turns and rejects changed
content. This is component evidence; the M17 Document service, disk recovery,
causal merge and SDK/placement proofs remain separate work.
