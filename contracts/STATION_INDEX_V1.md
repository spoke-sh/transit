# Station immutable index v1

This Station library format supplies an
immutable ordered index over [Publication](STATION_PUBLICATION_V1.md); Document
acceptance, causal validation, retained roots and current authorization remain
with its consumer. Index references grant no access by themselves.

A tree uses one resource and Publication namespace. Each node is an immutable
record identified by its nonzero u64 record ID plus exact Publication spec. A
reference includes level, minimum key and subtree entry count. A zero root means
an empty tree. Keys are nonempty byte strings of at most 128 bytes; values are at
most 256 bytes. Ordering is unsigned lexicographic. Leaves and branches contain
at most eight entries/children. A branch stores each child's minimum key, count,
level and immutable record spec. All descendants have the advertised level.
Nodes have at most 32 levels; this is a representation/operation bound independent
of total retained node count. Node records are at most 4096 bytes.

The canonical node envelope is `SIX1`, encoding:u8, decoded_length:u16 and
body. Integers are little endian. Encoding 0 stores the body directly. Encoding
1 divides the decoded body into consecutive groups of at most eight bytes:
a one-byte mask marks nonzero positions, low bit first, followed by exactly
those nonzero bytes in position order. Bits beyond a final short group must be
zero, and a present byte cannot be zero. Choose masks only when their complete
payload is shorter than the direct body; ties use encoding 0. Both encoded
records and decoded bodies remain bounded by 4096 bytes (the body allows 4089).
There are no dictionaries or back references. Encoding/decoding does linear
bounded work without heap allocation.

The decoded body is level:u8, count:u8, followed by entries. Each entry starts
with prefix_length:u8, suffix_length:u8 and the key suffix. The prefix is the
maximal common prefix with the preceding complete key; the first key uses zero.
Reconstructed keys retain the 128-byte bound. A leaf then stores value_length:u16
and value. A branch then stores record_id:u64, format:u32, length:u32, digest:32
bytes and subtree_entries:u64. Compression preserves every identity, value and
commitment byte; it never shortens cryptographic commitments.

Keys are strictly increasing; counts and record identities are nonzero. Extra
bytes, unknown encodings, noncanonical masks/prefixes/representation choices,
invalid levels/lengths and inconsistent reference metadata reject explicitly.
Publication format is `0x53495801` and its chunk chain covers the exact encoded
envelope, not a separately inferred decoded commitment. The shared current-v1
definition covers this replacement; the former positional node envelope has no
fallback decoder.

Updates copy only the bounded path to a leaf, split a full node deterministically
and return a new root. Previously published roots retain their original content.
A write sink allocates unique record IDs and makes saved nodes readable through
the same source during candidate construction. The Publication sink stores nodes
durably; a bounded private overlay may defer storage until its final reachable
set is known. Every reachable page must be available by final head publication.
These individual page operations do **not** accept a
Document or Table change. The consumer must atomically publish its validated final root,
input progress and outputs through the ordinary fenced turn. An interrupted
candidate is recoverable staging or explicitly reclaimable unreachable work;
capacity failure cannot silently discard previously accepted roots.

Removal copies only the selected path, prunes empty branches and collapses
single-child paths at the root. Missing keys return the same root without new
nodes. Removal produces an empty root after the last entry; it never deletes
records referenced by earlier roots. The format and retained-root rules are
identical for insertion and removal.

Point lookup and strict-successor scans use bounded nodes/paths; callers choose
a bounded output page. They must not load the entire tree or treat an empty
page/error as proof of missing history. Every load validates the reference and
publication commitment through an authorized current or retained source.
References are never bearer grants. Retaining/releasing a root, retiring a
Document and deciding whether a node is still reachable are consumer obligations;
this library never infers permission to trim or delete nodes.

`inspect` returns one verified bounded node for a consumer walking candidate
references. It performs the same reference, count and commitment validation as
lookup. It cannot bypass source authorization or prove a root is retained.

Publication read/staging adapters keep an implementation cache of eight
node bodies (32 KiB plus metadata), independent of total retained history. Each
hit reopens the current authorized descriptor and verifies its exact commitment;
changing the source basis or namespace clears it. Cached bytes cannot authorize a
read after revocation/retirement or preserve a closed Document revision. Cached bodies use the current canonical node envelope.
