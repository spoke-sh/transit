# Growing Station query capture — v2 design

Status: the `GrowingQuery` capture slice is under M10 qualification. The
publication/receiver codecs below (`QueryDelivery`, `QueryRecords`) are
implemented and unit-tested against an in-memory authority fixture; no
end-to-end growing-query capability is advertised. A growing `GenServer`
still rejects `result_chunk`/`result_complete`/`result_ack` frames with
`error.UnsupportedGrowingQuery` unless a host explicitly supplies a
`QueryDelivery.Context` (bounded workspace and cancellation flag) — this is a
deliberate opt-in, not an oversight; only the `test::growing-query` proof
harness does so today, to qualify publication/receipt under real disk
Ursula/node restart. It builds
on [growing Station](STATION_GROWING.md), [retained read versions](READ_VERSIONS_V1.md)
and [incremental Fuze](FUZE_STREAM_V1.md). It does not reinterpret the finite
Station v1 result layout or enable growing results in foreign ABIs.

## Identity and source

A query starts from an authenticated Station call. Its result ID is the service's
input position; destination and correlation come from the authenticated source
and frame. A point index binds `(peer PID, correlation)` to that result forever
unless an application explicitly selects a qualified reclamation policy. Reusing
a correlation cannot create a second result. No scan of all completed calls is
required. The caller's durable wait continues to name the service PID.

Start atomically records job identity, typed plan, initial progress and the peer
index, retains the committed source revision, and emits a self-continuation.
This consumes the four-mutation budget; it cannot be combined with unrelated
writes or initial behavior creation. A Table source excludes private writes.
Job and result data use the same associated resource as the service's Tables in
this first profile. Cross-resource transactions are not introduced.

The plan and source schema/basis are durable, not a promise to rerun whatever
query a replacement binary happens to contain. A worker rejects unsupported
plan, progress or segment versions. It reopens the recorded version and rebuilds
the Table cursor from committed progress; it never substitutes current rows.

## Bounded capture and sealing

Each continuation reads a bounded source page and runs one Fuze step. A segment
is a complete independent Arrow IPC stream, at most 8192 bytes in this initial
operation profile. A query may have many segments. Aggregate and global-limit
state belongs to the whole query. Counters use checked arithmetic.

If a segment exceeds one proposal's mutation budget, consecutive turns stage
bounded fragments and staging progress. A resumed worker recomputes that one
step from its immutable source and checks identical candidate progress, byte
count, row count and digest before appending fragments. It does not rerun already
sealed source pages. Partial staging is never a sealed segment or complete result.

A separate seal turn verifies the staged bytes, records the segment manifest,
advances source/engine progress and result totals, and closes the staging record
in one authority decision. It declares the retained read dependency even when
resuming staged bytes. The final seal records query completion and releases the
source in the same proposal. Release preserves terminal evidence; it does not
delete captured results or prove physical erasure.

Every segment manifest binds result ID, consecutive ordinal, bytes, rows and
digest. A domain-separated chain over the ordered manifests binds the complete
result's segment, byte and row totals. It detects missing, duplicated, reordered
or modified evidence; it does not prove honest application computation.

## Publication and consumption

Capture, publication and acknowledgement are separate durable states. Publication
uses only sealed captured bytes, without reopening released source rows. Bounded
continuations send framed fragments, segment seals and finally the complete-result
manifest. Their durable publication cursor commits with outputs. Lost replies use
the ordinary exact-proposal reconciliation path; worker replacement reads the
committed cursor before sending further outputs.

The receiver authenticates the source against its recorded wait. It persists
fragments with bounded receive progress, verifies each complete segment's bytes,
Arrow schema and row count, and advances the ordered chain. Identical duplicates
are inert; conflicting or out-of-order evidence cannot establish completion.
Only a final manifest matching all received totals and chain closes the wait and
produces acknowledgement. An empty result still carries Arrow schema. Consumers
iterate verified segments; no API allocates all result bytes or byte-concatenates
separate IPC streams and labels them one stream.

Acknowledgement records peer acceptance. It never grants deletion. Slow consumers
retain durable work, rather than keeping a native Arrow task or stack alive.

## Flow control

This is the first concrete instance of [FLOW_CONTROL.md](../docs/FLOW_CONTROL.md)'s
application-admission-credit pattern; that document owns the general shape and
its distinction from transport flow control, this section owns this protocol's
specific unit and open decisions.

The implemented sender paces itself: `publishing` writes at most three
fragments per authority turn before recording its cursor and self-casting a
continuation. This bounds each proposal to the ordinary four-mutation budget;
it is not a signal from the destination that it is ready for more. No frame
today carries receiver-issued credit, and the receiver has no way to slow a
sender that is otherwise authorized and within policy.

This is a known, explicitly scoped gap, not a silent one. The intended
direction — recorded here as design, matching the rest of this document's
convention — is receiver-driven credit quantized in whole segments, the
protocol's existing atomic, digested, sealed unit: the destination grants
credit only for segments it has durably stored, and the sender may not run
more than a small fixed window of segments ahead of the credit it has last
observed. [`Delivery.tla`](../tests/verification/models/Delivery.tla) checks
this abstractly (`WindowBound`, `CreditSound`, `NoPrematureAck`); wiring an
actual receiver-issued grant frame, choosing the window size, and deciding
whether credit is per-result or pooled per-destination-peer remain
unimplemented. Until then, publication depends only on local self-pacing and
authorization/policy, not on destination readiness.

## Policy, lifetimes and failure

The service explicitly authorizes a peer/table through a revisioned framework
policy. Start records that revision. Each capture/publication continuation checks
the current policy; revocation or a changed revision stops further disclosure and
records denial. Already delivered bytes cannot be retracted. Transit independently
enforces current state/execute grants and process/resource lifetimes.

Source-dependent proposals declare the retained version. Revocation, expiry,
release or missing pages cannot be converted into empty rows or a successful
prefix. Read failures poison the private proposal. A failed read cannot be caught
and followed by publication from that same turn. The owner may explicitly close
the job in a fresh authorized proposal, before attempting source reads; this
records cancellation/abandonment, not successful completion. It needs no source
version read and stages release of an unfinished source. Access to the job's
current resource is still required; in this first shared-resource profile, losing
that resource's read grant also prevents reading/closing the job through this
helper. Replacement ownership is
required when the prior activation/view is no longer usable. Permanent process
expiry still takes precedence; this library cannot promise that a dead process
will deliver a final reply.

Peer cancellation is an authenticated ordered observation and uses the peer/
correlation index. Local host cancellation before a step returns no proposal;
it does not cancel a committed job. Closed receiver waits never reopen for late
fragments, completion or ordinary replies. Uncertain mutation outcomes retain
their exact signed request until reconciliation or fenced replacement.

## Qualification gates

Codecs and bounded capture are implemented; enabling result frames in the
growing GenServer by default remains gated on the qualification below, not on
missing code. `test::growing-query` now covers interruption during staging,
seal and publication (exact retry of a lost publish/receive reply, cancellation
while a submit is uncertain) and node/caller replacement, against real disk
Ursula. `query_growing_test.zig` independently covers duplicate/conflicting/
missing fragments and terminal acknowledgement without deletion, in-memory.
Still open: independent Arrow decoding of captured results beyond 32
rows/672 bytes; global-limit/aggregate continuity; provider (not just node)
replacement during publication; current-policy and grant changes taking effect
mid-publication; and explicit close after source loss racing delivery. Keep
legacy service, foreign ABI and finite-result proofs. This design does not yet
pass those remaining gates, and nothing enables it in a production host.

## Capture layout

The development capture implementation uses reserved keys `00 Q <tag:u8>
<result:u64be> <ordinal:u64be> <fragment:u16be>` (21 bytes). Tags `j`, `p`, `e`
and `s` identify the job, compact plan, engine progress and current stage with
zero ordinal/fragment. Tag `i` uses peer PID and correlation in the two u64
positions for a point index; its value is the result ID as u64le. Tags `m` and
`f` identify sealed segment manifests and raw fragments. Total key count grows
with retained results; no fixed array bounds that cardinality.

All value integers are little endian. `GQJ2` job values are 108 bytes: result,
destination, correlation (u64 each), Table ID (u32), retained source PID/input
(u64 each)/slot (u8), policy revision (u64), phase (u8), captured byte total (u64),
chain (32 bytes), publication segment (u64) and byte offset (u16). Phases are
capturing=1, captured=2, published=3, acknowledged=4, cancelled=5, denied=6;
the publication fields/phases are populated by the delivery layout below.

`GQS2` segment manifests are 55 bytes: result and ordinal (u64 each), bytes
(u16), rows (u8), SHA-256 (32 bytes). The chain starts with 32 zero bytes. Each
seal hashes `transit.station.query.segments.v2` followed by a zero byte, the
prior chain and the exact encoded manifest. `GQT2` staging records are 204 bytes:
143-byte `FZS1` candidate progress, 55-byte `GQS2` candidate manifest, and u16
written bytes. Fragment values hold at most 221 raw bytes. Three fragment writes
plus one stage write fit the four-mutation budget; a seal writes manifest,
progress, job and stage tombstone atomically. The tombstone closes transient
staging metadata; accepted fragment/history evidence is not physically erased.

`GQC2` capture continuations are 22-byte Station cast payloads: result and
expected source-page ordinal (u64 each), staged byte count (u16). Only an
authenticated self-origin is accepted. Older page/byte positions are inert;
future positions reject. The committed stage and engine progress determine the
next token, so duplicate continuations cannot advance a second chain of work.

## Delivery layout

Publication reuses the job's stored `send_segment`/`send_offset` cursor and
sends framed fragments, a segment seal, and finally the complete-result
manifest; nothing here reopens released source rows. `GQX2` `Transfer` is one
encoding used by both ends for independent bookkeeping: the sender keys its
own copy `u <result>` (tracking what it has sent, checked against its own PID)
and the receiver keys its copy `r <correlation>` (tracking what it has
received, checked against the authenticated peer) — the two are never the same
durable record, and a `Transfer`'s `result`/`source` fields mean "my job" or
"the peer's reported job" depending which key reads it. Fragments accumulate
under key `d`; sealed segments are re-keyed under `v` once a `Segment`
manifest is durably verified on receipt.

`GQF2` result fragments are Station cast/`result_chunk` payloads, header plus
raw bytes, at most `Frame.max_payload` (243) total: result and segment ordinal
(u64 each), byte offset within the segment (u16), then up to 221 raw bytes.
Offset must land on a `fragment_bytes` (221) boundary and `offset + len` must
not exceed one segment (8192 bytes); a value failing either is rejected before
being written, not merely before being read back.

`GQP2` publication continuations are 22-byte Station cast payloads sharing
`GQC2`'s layout under a distinct magic: result, segment ordinal (u64 each),
byte offset already sent (u16). Only an authenticated self-origin is accepted,
identically to capture continuations.

`GQX2` result transfers are 110 bytes: result and source PID (u64 each),
accumulated segments/bytes/rows (u64 each), chain (32 bytes), current fragment
receive offset (u16), accumulated Arrow schema fingerprint (32 bytes, from
`Inspect.segment`, independent of source identity or cell values). `segments =
0` requires bytes/rows/chain/schema to be their zero value; `rows` must fit
the accumulated `segments` at `max_rows` (32) per segment.

`GQM2` complete-result manifests are 208 bytes: result, destination, correlation
(u64 each), Table ID (u32), policy revision (u64), basis resource/revision
(u64 each) and schema fingerprint (32 bytes), plan fingerprint (32 bytes),
segments/bytes/rows totals (u64 each), chain (32 bytes), Arrow schema
fingerprint (32 bytes). `check(transfer)` requires the receiver's accumulated
`Transfer` to exactly match every total, the chain and the schema, with no
fragment still pending, before a wait can close.

Every segment is independently validated by `Inspect.segment` (`transit-fuze`)
against the model's row/cell/column bounds before its schema fingerprint enters
the chain — this is the boundary an untrusted or buggy peer's bytes cross, not
an internal trust assumption. `Inspect.segment` does not special-case Arrow
`BodyCompression`; a compressed record batch decodes transparently through the
same call and is accepted like any other, bounded only by the caller's
workspace allocator. Compression is out of scope for this milestone by
decision, not oversight: `segment_bytes` (8192) already caps the wire payload
tightly against the model's row/cell ceilings (32 rows × 220-byte cells × 2
columns encodes to at most 7,848 bytes), so IPC-level compression buys little
here and only adds attacker-controlled decompression amplification. Rejecting
`compression != null` explicitly in `Inspect.segment`, rather than relying on
the caller's workspace bound alone, is the cheap follow-up if a future profile
still declines to support it.

## Wire tag catalog

Every durable value and cast/call payload in this design is prefixed by a
four-byte ASCII magic tag naming its exact encoding, checked on decode.
Frame kinds themselves stay `STN1` (`STATION_V1.md`); the tags below are typed
payloads carried inside a `cast`, or durable values keyed by `QueryRecords.key`.
This table is the single place to check before adding a fifth kind — the
encode/decode functions above remain the source of truth for byte layout.

| Tag | Type | Carried as |
| --- | --- | --- |
| `GQJ2` | `Job` | durable value, key tag `j` |
| `GQS2` | `Segment` | durable value, key tags `m` (sealed) and inside `GQT2` |
| `GQT2` | `Stage` | durable value, key tag `s` |
| `GQC2` | `Continuation` | Station `cast` payload (capture self-continuation) |
| `GQX2` | `Transfer` | durable value, key tags `u` (sender copy) and `r` (receiver copy) |
| `GQM2` | `Manifest` | durable value (key tag `z`) and `result_complete` payload |
| `GQF2` | `Fragment` | `result_chunk` payload (raw bytes) |
| `GQP2` | `Publication` | Station `cast` payload (publication self-continuation) |
| `SQC1` | legacy capture continuation | Station `cast` payload (finite `Query.zig`) |

`QueryRecords.key`'s own one-byte tags (`j p e s i m f v r z`, distinct from the
four-byte magics above) select which durable record a key addresses; they are
documented alongside the layout sections above, not repeated here.
