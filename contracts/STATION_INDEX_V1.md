# Station immutable index v1

Status: implemented immutable index used by Documents. Component/private-turn
and Document service/disk evidence are recorded in the [proof ledger](../tests/README.md).
This is a Station library format, not a kernel command or grant. It supplies an
immutable ordered index over [Publication](STATION_PUBLICATION_V1.md); Document
acceptance, causal validation, retained roots and current authorization remain
with its consumer. No production compatibility claim is made yet.

A tree uses one resource and Publication namespace. Each node is an immutable
record identified by its nonzero u64 record ID plus exact Publication spec. A
reference includes level, minimum key and subtree entry count. A zero root means
an empty tree. Keys are nonempty byte strings of at most 128 bytes; values are at
most 256 bytes. Ordering is unsigned lexicographic. Leaves and branches contain
at most eight entries/children. A branch stores each child's minimum key, count,
level and immutable record spec. All descendants have the advertised level.
Nodes have at most 32 levels; this is a representation/operation bound independent
of total retained node count. Node records are at most 4096 bytes.

The canonical node envelope is `SIX1`, level:u8, count:u8, followed by entries.
A leaf entry is key_length:u16, key, value_length:u16, value. A branch entry is
key_length:u16, minimum_key, record_id:u64, format:u32, length:u32, digest:32 bytes,
subtree_entries:u64. Integers are little endian. Keys are strictly increasing;
counts and record identities are nonzero. Extra bytes, unknown versions, invalid
levels/lengths and inconsistent reference metadata reject explicitly. Publication
format is `0x53495801` and its chunk chain covers these exact bytes.

Updates copy only the bounded path to a leaf, split a full node deterministically
and return a new root. Previously published roots retain their original content.
A write sink allocates permanent unique record IDs and publishes each node before
returning its reference. These individual publications do **not** accept a
Document change. The consumer must atomically publish its validated final root,
input progress and outputs through the ordinary fenced turn. An interrupted
candidate is recoverable staging or explicitly reclaimable unreachable work;
capacity failure cannot silently discard previously accepted roots.

Point lookup and strict-successor scans use bounded nodes/paths; callers choose
a bounded output page. They must not load the entire tree or treat an empty
page/error as proof of missing history. Every load validates the reference and
publication commitment through an authorized current or retained source.
References are never bearer grants. Retaining/releasing a root, retiring a
Document and deciding whether a node is still reachable are consumer obligations;
this library never infers permission to trim or delete nodes.

Publication read/staging adapters keep an implementation cache of eight
node bodies (32 KiB plus metadata), independent of total retained history. Each
hit reopens the current authorized descriptor and verifies its exact commitment;
changing the source basis or namespace clears it. Cached bytes cannot authorize a
read after revocation/retirement or preserve a closed Document revision. The
index wire format is unchanged.
