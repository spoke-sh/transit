# transit-bitmap

Shared allocation-free Roaring array, bitmap and run containers for bounded
segment state. One container covers 65,536 low offsets; a future owning paged
directory selects containers for larger sets. This is a container primitive,
not a complete bitmap directory, `.tdel` migration or Queue `.tack` store.

`Container` owns a 64-byte-aligned 8 KiB bitset and a cardinality counter. Reuse
it as scratch for insert/remove, union, intersection, iteration and decoding.
No operation takes an allocator, opens storage or acquires permission.
`encode` writes to a caller-owned output buffer of at most 8,204 bytes.
`View.parse` validates borrowed immutable bytes; `contains` and iteration retain
no additional allocation. The caller keeps those bytes alive and unchanged.
Invalid decoding leaves the mutable container unchanged. Encode/decode reject
input or output buffers that overlap the mutable container before changing bytes.

The internal canonical `RBC1` encoding has a 12-byte header: magic, one-byte kind
(`array=1`, `bitmap=2`, `run=3`), three zero reserved bytes and a little-endian
u32 cardinality. Array bodies contain sorted unique little-endian u16 offsets;
bitmap bodies contain 1,024 little-endian u64 words. Run bodies contain a u32
run count and sorted `(start: u16, length_minus_one: u16)` pairs. Adjacent runs
must merge. The writer selects the shortest body, preferring array then run on
ties. The reader checks counts, ordering, ranges, exact length and canonical
representation. This is not upstream portable Roaring serialization.

An enclosing storage format must supply its mandatory Transit definition,
segment/range identity and integrity checks. `RBC1` bytes alone establish none
of those facts. Current `.tdel` readers and writers retain their existing format;
their eventual migration requires one coordinated current-v1 cutover.

Inside `nix develop`, run `zig build test` in this directory. Tests cover
independent byte vectors, sparse/dense/full containers, algebra against an
independent membership oracle, malformed/truncated/noncanonical inputs and a
100,000-operation mutation corpus. The root native component test graph includes
these tests; standalone package checks compile the package through its own
manifest. These checks provide no disk durability or Queue-runtime evidence.
