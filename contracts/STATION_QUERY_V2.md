# Growing Station query capture — v2 design

Status: the `GrowingQuery` capture slice is under M10 qualification. The
publication/receiver protocol below remains design; no end-to-end growing-query
capability is advertised. It builds
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

Implement codecs and bounded capture before enabling result frames in the
growing GenServer. Qualify independent Arrow decoding of captured results beyond
32 rows/672 bytes; global-limit/aggregate continuity; interruption during staging,
seal and publication; consumer/caller/node/provider replacement; current-policy
and grant changes; explicit close after source loss; duplicate/conflicting/missing
fragments; and terminal acknowledgement without deletion. Keep legacy service,
foreign ABI and finite-result proofs. This design does not pass those gates.

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
publication fields/phases are reserved for the subsequent integration.

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
