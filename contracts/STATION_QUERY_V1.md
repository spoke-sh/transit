# Station query capture v1

`Query` captures results in bounded immutable segments. `QueryDelivery`
and `QueryRecords` define publication, delivery and acknowledgement. Enable
result frames by supplying a `QueryDelivery.Context` with a bounded workspace
and cancellation flag. Without it, `GenServer` rejects
`result_chunk`/`result_complete`/`result_ack` with `error.UnsupportedQuery`.
The growing C/port ABI owns that context when configured with `query_results: true`.
Public language runners use the same shared implementation. This contract builds
on [Station](STATION_V1.md), [retained read versions](READ_VERSIONS_V1.md)
and [query v1](UNIFIED_QUERY_V1.md). The native contract definition fences
incompatible stored results and foreign ABI consumers.

## Identity and source

A query starts from an authenticated Station call. Its result ID is the service's
input position; destination and correlation come from the authenticated source
and frame. A point index binds `(peer PID, correlation)` to that result forever
unless an application explicitly selects a supported reclamation policy. Reusing
a correlation cannot create a second result. No scan of all completed calls is
required. The caller's durable wait continues to name the service PID.

Start atomically records job identity, typed plan, initial progress and the peer
index, retains the committed source revision, and emits a self-continuation.
This consumes the four-mutation budget; it cannot be combined with unrelated
writes or initial behavior creation. A Table source excludes private writes.
Job and result data use the same associated resource as the service's Tables in
this first profile. Cross-resource transactions are not introduced.

The plan uses the canonical `FZP1` encoding and fits one 256-byte native value.
The source declaration/basis and nested Arrow cells use the same definition as
all other query clients. The engine workspace is 4 MiB; each Table page has at
most eight rows. Count output is uint64, and sum is checked int64.

The plan and source schema/basis are durable, not a promise to rerun whatever
query a replacement binary happens to contain. A worker rejects unsupported
plan, progress or segment versions. It reopens the recorded version and rebuilds
the Table cursor from the committed job cursor; it never substitutes current rows.

## Bounded capture and sealing

Each continuation reads a bounded source page and runs one Fuze step. A segment
is a complete independent Arrow IPC stream, at most 8192 bytes in this
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

This is the first concrete instance of [FLOW_CONTROL.md](../docs/reference/streams.md)'s
application-admission-credit pattern; that document owns the general shape and
its distinction from transport flow control, this section owns this protocol's
specific unit and implementation.

The sender still paces itself within one turn — `publishing` writes at most
three fragments per authority turn before recording its cursor and
self-casting a continuation, bounding each proposal to the ordinary
four-mutation budget — but that alone no longer governs how far ahead of the
destination it may run. Receiver-issued `GQG1` credit, quantized in whole
segments (the protocol's existing atomic, digested, sealed unit), does: the
destination grants credit only for segments it has itself durably sealed
(`transfer.segments` at seal time, never merely received bytes), and
`publishing` will not start a segment more than `credit_window` (2) ordinals
past the last credit the sender has observed (`QueryRecords.credit_window`).
A `GQG1` grant is authenticated against the job's recorded destination,
rejected if it ever regresses, inert if repeated or received after
publication completes, and — when it advances stored credit — immediately
self-casts a continuation so a blocked sender resumes without waiting for an
unrelated turn. [`Delivery.tla`](../tests/verification/models/Delivery.tla)
checks this abstractly (`WindowBound`, `CreditSound`, `NoPrematureAck`); the
implementation is tested in-memory (`query_growing_test.zig`, including a
forged-peer rejection and an exact count of one grant per sealed segment) and
against real disk Ursula/node restart (`test::query`'s `publish`/
`deliver` phases, which now exercise the gate under real asynchronous delay).

Credit is scoped per result, not pooled across a destination's concurrently
published results — the simplest choice given `Job`/`Transfer` are already
per-result records, and the one this document's own multiplexing question
([FLOW_CONTROL.md](../docs/reference/streams.md)) leaves
open for a future peer-pooled scheme if one destination's several concurrent
results need shared fairness. `credit_window`'s value is a fixed, reviewed
constant, not adaptive or negotiated, matching this design's stated preference
for a TigerBeetle-style pipeline cap over an HTTP/2- or TCP-style tuned window.

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

## Host configuration and recovery

Hosts opt into result delivery with the bounded context described above.
The [query host](../apps/transit-query-host/README.md) composes source and requester
workers for [public Table queries](UNIFIED_QUERY_V1.md). Staging, sealing and
publication retain exact operation identities across caller, worker and storage
restarts. Recovery resumes those operations; it does not prepare a new query.
Current authorization still applies to publication and reads.

`just test::query` exercises disk-backed recovery. The
[test guide](../tests/README.md) records fault schedules, independent Arrow
decoding and client/deployment coverage. Component tests additionally check
duplicate, conflicting and missing fragments and acknowledgement without deletion.

## Capture layout

Capture uses reserved keys `00 Q <tag:u8>
<result:u64be> <ordinal:u64be> <fragment:u16be>` (21 bytes). Tags `j`, `p`, `e`
and `s` identify the job, compact plan, engine progress and current stage with
zero ordinal/fragment. Tag `i` uses peer PID and correlation in the two u64
positions for a point index; its value is the result ID as u64le. Tags `m` and
`f` identify sealed segment manifests and raw fragments. Total key count grows
with retained results; no fixed array bounds that cardinality.

All value integers are little endian. `GQJ1` job values are 117 bytes: result,
destination, correlation (u64 each), Table ID (u32), retained source PID/input
(u64 each)/slot (u8), policy revision (u64), phase (u8), captured byte total (u64),
chain (32 bytes), publication segment (u64), byte offset (u16), Table cursor
presence (0/1) and after-key (i64, zero when absent). Phases are
capturing=1, captured=2, published=3, acknowledged=4, cancelled=5, denied=6;
the publication fields/phases are populated by the delivery layout below.

`GQS1` segment manifests are 55 bytes: result and ordinal (u64 each), bytes
(u16), rows (u8), SHA-256 (32 bytes). The chain starts with 32 zero bytes. Each
seal hashes `transit.station.query.segments.v1` followed by a zero byte, the
prior chain and the exact encoded manifest. `GQT1` staging records are 236 bytes:
175-byte `FZS1` candidate progress, 55-byte `GQS1` candidate manifest, and u16
written bytes. Fragment values hold at most 221 raw bytes. Three fragment writes
plus one stage write fit the four-mutation budget; a seal writes manifest,
progress, job and stage tombstone atomically. The tombstone closes transient
staging metadata; accepted fragment/history evidence is not physically erased.

`GQC1` capture continuations are 22-byte Station cast payloads: result and
expected source-page ordinal (u64 each), staged byte count (u16). Only an
authenticated self-origin is accepted. Older page/byte positions are inert;
future positions reject. The committed stage and engine progress determine the
next token, so duplicate continuations cannot advance a second chain of work.

## Delivery layout

Publication reuses the job's stored `send_segment`/`send_offset` cursor and
sends framed fragments, a segment seal, and finally the complete-result
manifest; nothing here reopens released source rows. `GQX1` `Transfer` is one
encoding used by both ends for independent bookkeeping: the sender keys its
own copy `u <result>` (tracking what it has sent, checked against its own PID)
and the receiver keys its copy `r <correlation>` (tracking what it has
received, checked against the authenticated peer) — the two are never the same
durable record, and a `Transfer`'s `result`/`source` fields mean "my job" or
"the peer's reported job" depending which key reads it. Fragments accumulate
under key `d`; sealed segments are re-keyed under `v` once a `Segment`
manifest is durably verified on receipt.

`GQF1` result fragments are Station cast/`result_chunk` payloads, header plus
raw bytes, at most `Frame.max_payload` (243) total: result and segment ordinal
(u64 each), byte offset within the segment (u16), then up to 221 raw bytes.
Offset must land on a `fragment_bytes` (221) boundary and `offset + len` must
not exceed one segment (8192 bytes); a value failing either is rejected before
being written, not merely before being read back.

`GQP1` publication continuations are 22-byte Station cast payloads sharing
`GQC1`'s layout under a distinct magic: result, segment ordinal (u64 each),
byte offset already sent (u16). Only an authenticated self-origin is accepted,
identically to capture continuations.

`GQX1` result transfers are 110 bytes: result and source PID (u64 each),
accumulated segments/bytes/rows (u64 each), chain (32 bytes), current fragment
receive offset (u16), accumulated Arrow schema fingerprint (32 bytes, from
`Unified.Inspect.segment`, independent of source identity or cell values). `segments =
0` requires bytes/rows/chain/schema to be their zero value; `rows` must fit
the accumulated `segments` at `max_rows` (8) per segment.

`GQM1` complete-result manifests are 241 bytes: result, destination, correlation
(u64 each), Table ID (u32), policy revision (u64), basis source kind (u8, Table=2),
resource/revision (u64 each), source declaration and schema fingerprints (32 bytes
each), plan fingerprint (32 bytes),
segments/bytes/rows totals (u64 each), chain (32 bytes), Arrow schema
fingerprint (32 bytes). `check(transfer)` requires the receiver's accumulated
`Transfer` to exactly match every total, the chain and the schema, with no
fragment still pending, before a wait can close.

Every segment is independently validated by `Unified.Inspect.segment` against
the current nested cell schema and all row/cell/state bounds. Its logical schema
fingerprint is independent of source identity and cell values. Primitive result
layouts are rejected. Arrow allocations, including decompression, remain within
the caller's bounded workspace; the sender emits uncompressed IPC.

`GQG1` result credit is a 20-byte cast payload, sent receiver-to-sender rather
than self-cast: result (u64), durably granted segment count (u64). The sender
retains the last value it has observed under key tag `g`, independent of and
never mutating its own send cursor (`Job.send_segment`/`send_offset`); see
[Flow control](#flow-control) above.

## Wire tag catalog

Every durable value and cast/call payload in this design is prefixed by a
four-byte ASCII magic tag naming its exact encoding, checked on decode.
Frame kinds themselves stay `STN1` (`STATION_V1.md`); the tags below are typed
payloads carried inside a `cast`, or durable values keyed by `QueryRecords.key`.
This table is the single place to check before adding a fifth kind — the
encode/decode functions above remain the source of truth for byte layout.

| Tag | Type | Carried as |
| --- | --- | --- |
| `GQJ1` | `Job` | durable value, key tag `j` |
| `GQS1` | `Segment` | durable value, key tags `m` (sealed) and inside `GQT1` |
| `GQT1` | `Stage` | durable value, key tag `s` |
| `GQC1` | `Continuation` | Station `cast` payload (capture self-continuation) |
| `GQX1` | `Transfer` | durable value, key tags `u` (sender copy) and `r` (receiver copy) |
| `GQM1` | `Manifest` | durable value (key tag `z`) and `result_complete` payload |
| `GQF1` | `Fragment` | `result_chunk` payload (raw bytes) |
| `GQP1` | `Publication` | Station `cast` payload (publication self-continuation) |
| `GQG1` | `Credit` | durable value, key tag `g` (sender copy only) and `cast` payload (receiver-to-sender grant) |

`QueryRecords.key`'s own one-byte tags (`j p e s i m f v r z g`, distinct from
the four-byte magics above) select which durable record a key addresses; they
are documented alongside the layout sections above, not repeated here.
