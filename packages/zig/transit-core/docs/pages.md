# Immutable page index

Status: M10 storage primitive in development. Exported as `transit_core.pages`;
the running v2/state-v1 authority and Station still use their legacy catalogs.
This implementation does not advertise a new public capability or migrate data.

The ordered copy-on-write tree stages immutable pages and returns a candidate
root. Only a future authoritative journal decision may publish that root with
process progress, principal sequence and outputs. A staged page is neither an
accepted turn nor a visible resource head. Failures can leave unreachable staging;
they do not change the caller's previously published root.

## Representation and access

Each versioned page is either an ordered leaf or a branch with child minima and
SHA-256 references. The hash covers a domain-separated canonical encoding.
Every read checks the expected digest, page shape and child height. Unknown
versions, malformed ordering, missing pages and corrupted bytes fail explicitly.
There is no missing-page-as-empty fallback.

`Tree(Store)` borrows a provider exposing `load(reference)` and
`stage(reference, page)`. The provider owns durable placement and cache policy;
core does not import provider APIs. `get`, `put`, `remove` and `scan` operate on
root references. A snapshot retains one immutable root instead of copying all
entries. Deleting a key creates a new version; older roots keep their values.

Bounds are per node or operation: four entries per leaf, five children per branch,
64 key bytes, 2,048 value bytes and eight returned entries per scan. Encoding is
limited to 24 KiB. Height is limited to 32 to bound recursion/work; that is an
explicit address-space guard, not a 32-row catalog. Metadata and identity
keyspaces can use the same index; their versioned public encodings remain a
separate integration obligation. The tree does not interpret application values.

Writes copy only the search path, splitting pages as needed. Deletion removes
empty subtrees and collapses a one-child root; internal one-child pages retain
their height. It does not yet rebalance sparse siblings. This can amplify storage
and lookup work after churn, which the growing-profile measurements must expose.
Continuation scans seek strictly after an opaque key; `scanFrom` supplies an
inclusive initial lower bound for catalog ranges. Both read one extra entry to
distinguish continuation from completion and return owned bytes at the supplied root.

## Persistence and publication obligations

A provider must confirm immutable page persistence before returning from staging,
or report an error/uncertainty. Cache eviction must never delete durable pages.
The authority must authenticate roots from its own committed history, recheck
current rights and lifetime on every read, and validate turn/view dependencies
before publication. Possession of a page digest confers no permission.

Required pages must survive checkpoint publication and journal trim. Garbage
collection requires retained roots, live views, recovery dependencies and staged
publication races to be accounted for. The current primitive provides **no page
deletion or GC authorization**. Unlimited retention remains the baseline.

The growable index alone does not solve the wider M10 migration: control catalogs,
principal IDs, state cursors, retained receipts/waits/results, service/client
capabilities, Station's handler reads, quota reserves and checkpoint roots still
need integration. Existing histories must remain readable by their explicit
legacy profile; they must not be reinterpreted as this page format.

## Typed catalog

`transit_core.catalog` adds owned, bounded typed records, namespace ranges and
versioned snapshot metadata over the same tree. Record keys contain a namespace,
two ordered 64-bit identities and an optional opaque suffix. Principals, PIDs,
mailbox positions, receipts and resource keys are addressed by value rather than
array offset. This is an internal representation; it does not widen the legacy
public protocol or ABI by implication.

Candidate catalogs are cheap root/count copies. Reads return owned records;
scans return at most eight records and a full-key cursor, which cannot cross the
requested namespace/identity range. Every parser has a 64 KiB workspace and each
encoded record is limited to 2,048 bytes. Larger logical objects need explicit
segments/references; loading the whole catalog into an allocator is not supported.
Those bounds apply to a record or operation, not total retained records.

A successful `put` or `remove` changes only the private candidate root. The caller
must validate permissions, dependencies and retention before using it and publish
all changes in one journal decision. Structural deletion grants no reclamation
permission. Catalog version/shape rejection is implemented; migration from legacy
checkpoints is not. Tests cover namespace isolation, 96 principals with identities
above 255, retained snapshots, pagination, count conservation, malformed/oversize
records and lost staging acknowledgement. Service integration remains in progress.

## Evidence

[Unit proofs](../src/pages_test.zig) check 256 keys beyond the legacy limit, lookup
and ordered pagination, updates/deletions, independently retained snapshots,
every staging-failure boundary, missing/corrupt pages, strict versioned encoding
and allocation failure cleanup. Their store is a deterministic in-memory fault
dependency, not a proof of bounded provider cache, disk persistence or production
scale. The [Ursula page proof](../../transit-backend-ursula/docs/pages.md) additionally
checks cold bounded caches and disk restart/checkpoint/trim. Integration with the
running authority remains required M10 evidence.
