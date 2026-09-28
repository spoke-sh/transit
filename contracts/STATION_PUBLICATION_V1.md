# Station immutable publication v1

Status: qualified growing Zig implementation; [M14 evidence](../tests/README.md#m14-immutable-publication). This is a Station
KV layout, not a new Transit command or language ABI. See the
[implementation guide](../packages/zig/transit-station/docs/publications.md).

## Identity and encoding

A record is identified by `(resource, namespace:u64, id:u64)`. Namespace and ID
are nonzero caller-assigned numbers, independent of PID/activation. They confer
no permission. IDs remain occupied after abandonment, retirement and cleanup.
Applications own allocation and any mapping to domain identities. This profile
does not transfer a resource's writer to another PID.

All keys are 23 bytes: `00 50`, namespace:u64be, tag:u8, id:u64be, index:u32be.
Tags are `b` (namespace budget, id/index zero), `r` (descriptor, index zero),
and `c` (chunk). Values use little-endian integers. Unknown versions, lengths,
enum tags, reserved bytes and inconsistent counters are errors.

| Record | Exact value |
| --- | --- |
| Budget, 32 bytes | `SPB1`, maximum record bytes:u32, maximum staged bytes:u64, maximum staged records:u32, reserved bytes:u64, reserved records:u32 |
| Descriptor, 104 bytes | `SPR1`, state:u8, reservation-held:u8, two zero bytes, application format:u32, content length:u32, written chunks:u32, collected chunks:u32, expected digest:32, current chain:32, publisher PID:u64, publication input:u64 |
| Chunk, 1–256 bytes | Exact opaque content, full 256 bytes except the final chunk |

States: staging=1, published=2, abandoned=3, retired=4. Application format is
nonzero and uninterpreted by Station. Chunks are numbered from zero with no gaps.
An empty record has no chunks. Its expected digest is the initial chain.
Maximum record bytes and staging records must be positive; maximum staged bytes
must cover one maximum record. The namespace's limits are immutable in v1.
Counters include abandoned records until cleanup completes. A descriptor's
publisher/input are zero before publication and preserved after retirement.

## Commitment

Let `H` be SHA-256, `LEn` an n-byte little-endian unsigned integer:

```
C0 = H("transit.station.publication.v1\0" || LE4(format) || LE4(length))
C(i+1) = H(01 || Ci || LE4(i) || LE2(chunk_length) || chunk_bytes)
```

The expected digest is the final chain. The `01` is one byte. This is a versioned
chunk-chain commitment, not the ordinary SHA-256 of the whole body. Canonical
chunk sizes prevent alternate segmentations. The independently generated
[fixture](../packages/zig/transit-station/src/fixtures/publication.json) uses
body byte `i = (37*i + 11) mod 256` for each declared length. The format and
length are committed; resource and record identity are supplied by the layout.

## Transitions and visibility

`begin` reserves the declared length and one slot before writing a staging
descriptor. It rejects oversize/capacity first; quota pressure never expires
existing work. Repeating the same ID/spec is a duplicate, different content is
an identity conflict, and terminal identities stay closed.

`append` writes the next canonical chunk and updated chain/counter together.
An earlier identical chunk is a duplicate; different bytes or gaps are errors.
`publish` requires all chunks and the expected commitment, releases staging
reservation and records published state/PID/input. It takes two mutations,
leaving two for an application head and correlation; outputs have their existing
independent turn budget. Earlier staging turns consume their own inputs only.
Publication, the final input and that turn's other writes/outputs have one
authority decision. Transport or staging acknowledgement is not publication.
Repeated publication returns duplicate and does not emit another output itself.

Multi-write helpers restore the prior private decision on failure. Read failures
remain sticky. If later application composition fails, discard the whole turn;
catching that error cannot make an incomplete application proposal acceptable.
All helpers use normal current resource grants, captured views and fenced writer
turns. Exact signed retry and fresh ownership after host loss remain mandatory.
The kernel does not verify application honesty or domain/CRDT validity.

## Reads and lifetime

`open` requires a published descriptor and returns an owned cursor naming the
resource, source revision, view or retained-version ID, namespace, record ID,
spec, next chunk and chain. Current-view reads reject private mutations. Each
`read` checks the exact source and descriptor and returns at most 256 bytes,
with either a continuation or verified completion. Empty completion still reads
the authorized descriptor. Missing/invalid chunks and a final digest mismatch
are errors. A provisional prefix is not a complete record. Cursors are trusted
local continuation state, not authenticated tokens for untrusted callers.

Every underlying read requires current authority. A cursor cannot extend a view
deadline or a resource's lifetime. Retained versions register commit dependencies
through the existing growing turn. Closing/revoking access may prevent further
reads without retroactively retracting bytes already copied under permission.

No automatic expiry or cleanup exists. `abandon` closes only staging records;
`retire` closes only published records. Terminal identities cannot reopen.
`collect` deletes at most two current chunks, updating durable progress in the
same turn. The last abandoned cleanup also releases its reservation, including
for empty records. Never delete the descriptor or namespace budget. Cleanup is
idempotent; failure before commit leaves progress unchanged. Logical deletion
does not erase provider bytes: retained historical roots can still read their
previous published record until released or made unavailable under the existing
resource policy. Applications must resolve current references before retirement;
v1 does not infer a dependency graph from opaque bytes.

## Immutable reference encoding

The additive `SPF1` reference is exactly 68 bytes: magic (4), resource (u64),
namespace (u64), record (u64), format (u32), length (u32), and digest (32).
Integers are little-endian. Resource is a nonzero protocol counter; namespace,
record and format are nonzero. Unknown magic, trailing bytes and truncation reject.
This encoding introduces no grant, lifetime extension or application acceptance.

`PublicationReference.read` copies a finite record into explicitly bounded caller
storage. It reopens current signed resource authority for every bounded group,
requires the same published spec and carries only the verified ordinal/hash chain
between cuts. Readers with `resource_read_batch` may acquire the descriptor and
at most seven 256-byte chunks in one authorized current read (the existing
eight-key bound). Other readers acquire one chunk at a time. The batch is
acquisition storage, never an authorization cache or a retained source version. It rechecks current availability after the final chunk, including
empty records. A failure invalidates the entire copied output. Applications still
own format validation, smaller size limits, original-call identity and any extra
policy/lifecycle checks. Historical `Publication` cursors retain their original
exact-cut behavior; this helper deliberately reads current availability.

## Capacity accounting

No total record-count array or whole-record materialization is used. Begin and
publish each use two reads/two writes; append uses two reads/two writes. A stream
step uses at most two reads and one 256-byte returned value. Cleanup uses at most
four reads/four mutations, including final quota release. Constant-size native
values/cursors and stack SHA-256 state do not grow with record or retained count.
`Digest.of` is an optional linear scan of already-owned input; incremental
`initial`/`next` permit bounded preparation without owning the whole body.

The u32 content length is an encoding ceiling, not a tested size guarantee.
Deployments select explicit smaller record/staging limits and resource quotas.
Staging limits are per namespace; a host must control namespace creation and
selection at its own ingress. They are not a substitute for resource-wide
capacity or a per-principal quota enforced by the authority.
Retained published bodies/tombstones are governed by resource capacity and
lifetime, separately from staging reservation. Logical key/value bytes for a
nonempty record are `length + 23*ceil(length/256) + 127`; namespace overhead is
55 bytes. Provider indexes, history, retained versions and journal overhead are
additional. M14 qualifies 64 KiB content and growing record counts; it does not
claim production throughput or arbitrary u32-sized records.
