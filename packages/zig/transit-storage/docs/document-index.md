# Document candidate storage

`DocumentIndex` supplies the immutable ordered-index interface consumed by
[`transit-document`](../../transit-document/README.md). It stages private causal
records in binary key/value columns in shared `.tseg` segments, with paged
`TreeStore` locators and `OrderedKeyIndex` full-key ordering. It has no Station
imports, actor calls, public endpoint or accepted-head authority. The installed
[Document service](../../transit-station-document/README.md) continues to own its
existing acceptance and caller lifecycle.

## Identity and ownership

A `Store` is scoped to one Document ID, epoch and type revision. Its owner
serializes access and checks current authorization before reads or mutations.
`begin(base, index_byte_limit)` returns a private index for evaluating changes.
`Document(Index).apply` returns a candidate state. The owner passes that state's
index to `seal`, then replaces the pending index with the returned immutable
index before retaining the candidate state.

Sealing consumes the workspace on success or failure. `abort` invalidates its
handles without deleting objects. Pending prefixes can be read during evaluation;
only the latest prefix can be mutated or sealed. Handles cannot cross stores or
survive a later workspace. A failed change must be aborted; its partially staged
records are never an accepted prefix. Copied sealed roots continue to select
their original records after subsequent candidates are built.

A nonempty root requires the shared definition, exact identity, record-directory
root, ordered-directory root and entry count. Restoring a missing or foreign
definition must not default to the current build. A descriptor is neither an
accepted revision nor a durable retention pin. The evaluator's revision and
duplicate-change records are provisional until the owning transaction accepts
the complete candidate.

## Budgets and storage

The current record profile preserves 128-byte keys and 256-byte values used by
the bounded Document evaluator. Those are causal-record limits; the component
does not add larger logical scalar values or succinct tree topology.

| Budget | Default | Scope |
| --- | --- | --- |
| Pending records | 128 | Appended puts per candidate, including repeated keys; configurable from 1 to 4,096 |
| Encoded segment | 64 KiB | One `.tseg` per nonempty candidate; configurable up to the shared 16 MiB segment limit |
| Scratch | 1 MiB | Reused fixed buffer for segment construction and decoding |
| Resident index pages | 8 | Shared `TreeStore` cache; zero disables caching |
| Encoded index work | Required at `begin` | Private directory mutations, independent of segment bytes and provider quotas |

Resident allocations are made at store initialization: pending records, one
decoded segment, aligned encoded/scratch buffers and the index cache. Collection
cardinality is independent of these budgets. Only the last put for each key
updates the directories; full keys establish equality and ordering, never a
hash alone. A segment is content-verified on load, decoded into bounded owned
records, and reused for cache hits. Cold index-page loading and provider I/O
retain their own allocation behavior. A full pending buffer, segment/scratch
exhaustion and provider allocation failure remain distinct errors. A small
budget can refuse an otherwise valid change or a retained segment read.

The object namespace is `document-segment/<sha256>.tseg`; directory pages use
the shared `data-index/` namespace. Successful immutable staging confirms only
candidate bytes. Failure may leave unreachable objects. This component performs
no deletion, expiry, checkpoint publication or background collection.

## Runtime integration obligations

Before exposing these candidates through a database service, the owner must
provide catalog identity and admission, current scoped authorization, fenced
transaction decisions, original operation receipts, accepted revision lookup,
recovery and retained-root traversal. That traversal must include both directory
graphs and all reachable segments, plus private work, snapshots and other
retention dependencies. Do not place these roots in an existing collector's
scope without that integration. Neither successful staging nor an object-store
conditional write substitutes for the transaction decision. Station input
settlement and outputs require the same atomic decision as the Document change.

## Executable checks

In the pinned shell, run `zig build test -Dtest-filter="Document tseg"` from
`packages/zig/transit-storage`. The
[component checks](../src/document_index_test.zig) exercise disk reopen from
caller-retained descriptors, original duplicate revisions, conflict resolution,
growth beyond an eight-record buffer and one-page cache, historical roots,
candidate invalidation, staging-budget failures, provider allocation failure,
foreign definitions, missing/corrupt segments and allocation-free warmed point
reads. Reopening immutable objects is distinct from accepted-head recovery;
these checks do not establish an installed direct Document service or a
transaction/collection protocol.
