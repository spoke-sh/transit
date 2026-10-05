# Immutable page index

The native v1 authority uses `transit_core.pages` and its typed catalog. These
internal v1 formats belong to the current contract definition and reject
incompatible storage. There is no legacy profile or automatic conversion.

The ordered copy-on-write tree stages immutable pages and returns a candidate
root. Only an authoritative journal decision may publish that root with
process progress, principal sequence and outputs. A staged page is neither an
accepted turn nor a visible resource head. Failures can leave unreachable staging;
they do not change the caller's previously published root.

## Representation and access

Each versioned page is either an ordered leaf or a branch with child minima and
SHA-256 references. Page/catalog format v1 includes an opaque 16-byte storage locator
beside each digest. Core never interprets that address; the adapter verifies its
mapping. The hash covers a domain-separated canonical encoding, including child
locators. Unsupported page/catalog versions are rejected explicitly. Their layout is
separate from the native service envelope.
Every read checks the expected digest, page shape and child height. Unknown
versions, malformed ordering, missing pages and corrupted bytes fail explicitly.
There is no missing-page-as-empty fallback.

Pages use canonical binary encoding: `TPG1`, one-byte height and count, then
exactly the occupied entries. A leaf entry contains a one-byte key length,
little-endian two-byte value length and those bytes. A branch entry contains a
one-byte minimum-key length, key bytes, 32-byte digest and 16-byte opaque locator.
Height zero selects leaves; positive height selects branches. Counts, key/value
bounds, ordering, height and exact end-of-input are validated. Missing entries,
trailing bytes, old JSON pages and unknown magic reject. Decoding allocates no
parser arena and returns an owned page. The worst-case encodings fit the unchanged
24 KiB byte budget; a resident page object occupies 16,952 bytes on the measured
64-bit target. Cache and sibling-stage budgets still count pages, so deployments
must account for this object size independently of retained data size.

`Tree(Store)` borrows a provider exposing `load(reference)` and
`stage(reference, page)`, which returns the persisted reference with its locator.
Core checks that staging preserved the content digest. The provider owns durable placement and cache policy;
core does not import provider APIs. `get`, `put`, `remove`, `mutate` and `scan` operate on
root references. A snapshot retains one immutable root instead of copying all
entries. Deleting a key creates a new version; older roots keep their values.

Bounds are per node or operation: eight entries per leaf, 32 children per branch,
64 key bytes, 2,048 value bytes and eight returned entries per scan. Encoding is
limited to 24 KiB. Height is limited to 32 to bound recursion/work; that is an
explicit address-space guard, not a 32-row catalog. Metadata and identity
keyspaces can use the same index; their versioned public encodings remain a
separate integration obligation. The tree does not interpret application values.

Single writes copy the search path, splitting pages as needed. `mutate` validates
at most eight distinct keys before staging and rewrites each affected path once.
It preserves unaffected child references and avoids staging no-op updates.
Batch splits distribute entries and children evenly across the new pages. This
leaves space on both sides for subsequent inserts, including descending keys;
filling one sibling first can otherwise grow a nearly full spine on every split.
Existing immutable roots keep their original shape and remain readable. Balancing
new splits does not rebuild old roots or change their encoding.
When a mutation adds child pages, the tree first merges adjacent siblings whose
combined contents fit one page. It reads two siblings at a time, only within
the bounded child list of the affected branch. This can absorb growth into
sparse neighbors before splitting a parent, including a formerly full spine
at the height guard. Merging stages new immutable pages and preserves retained
roots; staging failure or lost acknowledgement does not publish a candidate.
When the provider supports `stageMany`, sibling pages are staged as a bounded
group. Independent leaf rewrites below the same parent share a staging buffer
of at most eight pages, including splits; the buffer flushes before building
their parent. It lives only at the leaf frontier, not on every recursive ancestor
frame, and does not grow with the private write set or retained cardinality.
Destinations remain private until every locator in that batch is verified.
Otherwise the same tree uses individual staging calls. Every returned
reference is checked against its expected digest before becoming a candidate. Deletion removes
empty subtrees and collapses a one-child root; internal one-child pages retain
their height. It does not yet rebalance sparse siblings. This can amplify storage
and lookup work after churn, which the growing-profile measurements must expose.

`getMany` reads at most eight keys at one immutable root and returns their values
in caller order. It groups requests by child so shared paths are loaded once per
batch. The pending work list partitions the requested keys and holds at most
eight references; traversal holds one decoded page and eight owned result values,
without a recursive stack of ancestor pages. Invalid keys reject before page I/O;
an unavailable or corrupt selected page fails the whole observation. It stages
no pages and does not retain permission decisions. Native `read_entries` uses
this traversal after its existing current scope, grant, lifetime and revision
checks, and preserves the final authority-tail fence.

Continuation scans seek strictly after an opaque key; `scanFrom` supplies an
inclusive initial lower bound for catalog ranges. `scanRange` also takes an
exclusive upper bound, so catalog namespace scans avoid unrelated leaves. Scans
read one extra in-range entry to
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

The authority's growing profile owns process/resource validation, admission,
quotas and atomic root publication. Batching pages grants no new mutation or
retention rights. Incompatible histories cannot be opened by the current authority.

## Typed catalog

`transit_core.catalog` adds owned, bounded typed records, namespace ranges and
versioned snapshot metadata over the same tree. Record keys contain a namespace,
two ordered 64-bit identities and an optional opaque suffix. Principals, PIDs,
mailbox positions, receipts and resource keys are addressed by value rather than
array offset. Public wire identities and ABI ownership remain governed by their own contracts.

Candidate catalogs are cheap root/count copies. Reads return owned records;
scans return at most eight records and a full-key cursor, which cannot cross the
requested namespace/identity range. Every parser has a 64 KiB workspace and each
encoded record is limited to 2,048 bytes. Larger logical objects need explicit
segments/references; loading the whole catalog into an allocator is not supported.
Those bounds apply to a record or operation, not total retained records.

A successful `put` or `remove` changes only the private candidate root. The caller
must validate permissions, dependencies and retention before using it and publish
all changes in one journal decision. Structural deletion grants no reclamation
permission. Catalog version/shape rejection is implemented; automatic migration from superseded
checkpoints is unavailable. Tests cover namespace isolation, 96 principals with identities
above 255, retained snapshots, pagination, count conservation, malformed/oversize
records and lost staging acknowledgement. The node composes this catalog through the backend package.

Catalog `mutate` validates the complete bounded batch before reading pages. It
uses `getMany` at the original immutable root to distinguish insertion, replacement,
deletion and absent-key deletion when calculating the candidate record count.
Those observations share search paths, own at most eight values, and live only
for this call. A failed read, checked count calculation or page stage leaves both
the candidate root and record count unchanged. Only the authority's later commit
can publish the candidate; batching does not cache permissions or add write rights.

## Evidence

[Unit proofs](../src/pages_test.zig) check 256 retained keys, lookup
and ordered pagination, updates/deletions, independently retained snapshots,
every staging-failure boundary, missing/corrupt pages, strict versioned encoding
and allocation failure cleanup. Their store is a deterministic in-memory fault
dependency, not a proof of bounded provider cache, disk persistence or production
scale. The [Ursula page proof](../../transit-backend-ursula/docs/pages.md) additionally
checks cold bounded caches and disk restart/checkpoint/trim. Integration with the
native authority and Station has separate executable schedules and recorded
results in the [proof ledger](../../../../tests/README.md).

## Complete command candidates

Send, view open/close, delivery and turn preparation collect their complete
catalog write set before staging. Point reads include pending replacements and
deletions. These commands perform no scans over pending changes; such a scan
fails explicitly instead of reading an earlier cut. Other commands retain their
existing immediate private staging.

The private budget is derived from native turn limits: three records per closed
view, one per row plus resource metadata, six per output, three for an effect,
one process, two retry records, and six per retained-version change. This is 71
records, independent of retained rows or realm size. Repeated changes to a key
replace its pending value. The page builder shares affected paths across this
complete set; provider append batches remain bounded to eight pages. Page
geometry, encoded bytes, read pages and native mutation limits are unchanged.

Only the completed snapshot is eligible for conditional journal publication.
Failed validation stages no candidate pages. Staging failure can leave immutable
orphan bytes but preserves the prior snapshot. A competing publication still
invalidates the proposal; pending memory never grants authority. The catalog
unit proof compares against individual writes, retains old roots, and injects
acknowledgement loss at every staging point.
