# Immutable block codec and index contract v1

This contract defines [public block types](../packages/zig/transit-protocol/src/Blocks.zig)
and the [private immutable index](../packages/zig/transit-core/src/blocks.zig).
Constructing a descriptor, staging bytes or obtaining an index root does not
grant authority to publish a resource successor or disclose its values. The
owning authority supplies current authorization and a captured source basis.

## Identity and bounds

A `Spec` contains a decoded byte length and a 32-byte SHA-256 digest. The digest
input is the ASCII string `transit.immutable.block.v1`, one NUL byte, then the
complete block bytes. Empty blocks are valid. A block contains at most 65,536
bytes; keys use the native opaque 1–32-byte key contract.

A publication batch contains at most 16 distinct keys and 131,072 decoded body
bytes. Its fixed descriptor array has a populated prefix followed by nulls.
Each descriptor contains a key and either a `Spec` or null for deletion. The
body concatenates the non-null values in descriptor order; deletion consumes
no body bytes. Neither absent values nor empty blocks are deletion. Duplicate
keys, holes, over-budget lengths, missing bytes, trailing bytes and digest
mismatches reject the entire batch before staging starts.

The small metadata mutation budget, block record budget and block byte budget
are different quantities. No bound here limits a resource's retained total
cardinality. The index uses immutable paged nodes and a command-bounded private
candidate; its resident work does not contain the complete resource.

## Canonical bytes

JSON bodies use standard padded base64, with no whitespace, URL-safe alphabet,
missing padding or nonzero unused padding bits. The maximum encoded string is
174,764 characters. The public body owns its decoded bytes after parser disposal.
Length and unused-buffer validation prevent uninitialized storage from being
encoded. Descriptors use the shared JSON field, integer and fixed-array rules.

The independent vector `00 ff 80` has base64 body `AP+A` and digest
`bfe1ba4ab1f4f755de79b2375ea09a59c7bab2689b46b10745b8ec05729ec761`.
The logical digest excludes provider names, offsets, placement and ownership.
It proves content identity, not permission or availability.

## Index and publication

An index root owns a set of key/reference/revision records. A reference carries
the logical descriptor and an opaque backend location. Provider coordinates
stay below the resource boundary. The backend verifies durable complete bytes
before returning a reference that can be included in a candidate.

Publication checks the whole batch, stages complete values and constructs an
immutable successor index. It returns no successor after any block or page
staging failure, missing acknowledgement or malformed reference. Successful
staging alone does not accept the candidate. The composing authority must bind
that root to its state/input/output transition and conditional successor check.

Changing or deleting a key creates a new root. Old roots retain their original
values, revisions and byte references. Sharing a root does not imply lifetime
ownership by the resource from which it was copied: each accepted owner must
retain an explicit root edge. Opaque application values are not implicit edges.

Reads use an exact index root and at most one native page of keys or metadata.
Missing-key slots preserve input order. A data read admits at most 131,072 bytes
and verifies every acquired block against its descriptor before returning it.
Missing or corrupt data is an error, never an empty value. Failure clears the
private output body. The host revalidates current authority before disclosure;
cached bytes and logical digests do not cache permission.

Logical deletion does not physically erase bytes. Physical collection requires
the complete owning root set and a publication fence; it is not an index method.
Default unlimited retention is unchanged by this codec.

## Native resource ownership and reads

`turn.blocks` and `turn_with_versions.turn.blocks` bind the descriptors. A
`CommandEnvelope` carries an optional owned `blocks` body alongside `request`
and `signature`. The signature hashes the logical request, including descriptors;
the body is verified against those descriptors. It never enters the authority
journal record. A known exact receipt reconciles without restaging; fresh work
with nonempty values requires its complete body. Frozen pending operations retain
both parts. Missing/foreign definitions reject before execution or stored-root
interpretation.

For fresh work, missing, mismatched or malformed body bytes reject with
`InvalidBlockBody` before any provider write. This caller rejection is distinct
from missing or corrupt bytes already referenced by stored state, which prevent
successful availability or disclosure.

The containing turn requires its current writable view and resource revision.
Its successor catalog owns the separate block-index root and records
`Resource.block_entries` independently of the small `entries` count. Metadata,
block root, input progress, outputs and read-version changes share one conditional
acceptance. A stale candidate conflicts; no partial data becomes visible.

`block_entries` reads at most eight keys from `source.resource {id, revision}`,
`source.view`, or `source.version {id, generation}`. The response identifies the
exact resource and optional captured view/version. `snapshot_read.blocks` uses
its snapshot's same catalog cut and final current-authorization validation.
Ordinary `/v1/query` returns descriptors; `/v1/blocks` additionally returns a
canonical body in populated-result order. Missing-key slots consume no bytes.
With no keys, `block_entries` is a metadata-only ordered scan of at most eight
records, optionally after an opaque key. Its `next` cursor advances within the
same qualified source; only null means completion. `/v1/blocks` requires point
keys, so scanning cannot accidentally materialize eight maximum-size values.
Both paths require current inspection/read access. Snapshot renewal happens only
after successful validation. Source identity is never a permission cache.

Explicit opted-in resource reclamation can detach its current block root after
its version/view gates pass. Retained historical roots still own their bytes.
This logical operation alone does not erase physical storage.

## Backend framing and evidence

The Ursula adapter encodes a block record as `TBK1` followed by its raw bytes,
then wraps it in a canonical base64 JSON string for record-coordinate transport.
Page frames and block frames are distinct. Reads verify the exact coordinate,
complete record framing, byte count, content digest and canonical envelope.
Staging reads the record back before returning its reference. A lost append
reply is not silently retried or treated as a usable locator.

Protocol units use the independent vector and malformed/over-budget inputs.
Core schedules check old roots, missing/corrupt bytes, byte-stage failure and
page acknowledgement loss. `just test::block-storage` runs the real disk
adapter with a full-size batch and one resident metadata page, provider kill and
restart, missing replies and corrupted readback. Executed results and their
limits belong in [the proof ledger](../tests/README.md).
