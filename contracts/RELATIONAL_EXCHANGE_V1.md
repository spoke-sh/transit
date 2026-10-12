# Relational query exchanges v1

This contract extends [relational execution](RELATIONAL_V1.md) with explicitly
placed source partitions under one growing Transit authority. Fuze owns routing
and segment validation; `transit-query` owns durable producer eligibility,
receiver acceptance, consumption and complete source coverage. Physical hosts
use current native identities, resource grants and ownership generations. There
is no automatic placement controller, distributed write authority, cross-realm
exchange, partial aggregate reassociation or broadcast operator in this profile.

## Identity and routing

An exchange has a nonzero caller-allocated ID, one immutable bound query, one or
two sources and a positive uint64 logical partition count. Multiplication of
source count by partition count must fit uint64. Every source uses every logical
partition, including empty partitions. The host registers pairs in partition,
then source order, one bounded native turn at a time. Each pair binds one logical
producer PID and its resource. Physical worker replacement preserves these IDs.
The receiver's resource must differ from producer resources. The caller must
allocate a fresh exchange ID for a different bound basis or topology.

Routing hashes `transit.relational.partition.v1\0` with SHA-256. Join inputs
append byte 1 and the join key. Single-source grouping/aggregation appends byte 2,
the uint8 group-key count and the declared key values; an ungrouped aggregate
therefore has one constant key. A plain single-source projection appends byte 3
and its stable row identity. A nullable key is byte 0, or byte 1 followed by signed
int64 little endian. Row identity is origin:uint64be, operation:uint64be,
ordinal:uint32be. Routing interprets digest bytes 0–7 as uint64 little endian and
takes the remainder modulo partition count. Aliases and column IDs are absent
from join-key bytes, so equal left/right keys colocate. NULL routing never changes
the rule that join NULLs do not match.

The bound fingerprint still includes the full prepared plan, exact schemas,
source cuts and budgets. Physical-plan epoch is evidence in the segment body;
it is neither authorization nor part of the logical deduplication key. Native
ownership generations fence producer writes. A delayed segment with an earlier
physical epoch remains eligible when its exact producer ledger entry exists.
Replacing a physical worker cannot reinterpret or drop recorded pending output.

## Wire and stored records

All new record magic values end in `1` and are followed by the mandatory 32-byte
current native definition. Missing or foreign definitions, trailing bytes,
invalid counters and noncanonical encodings reject. Record formats are additive;
existing publication formats retain their exact meanings. Publication domain 10
belongs to relational query exchanges; domain 6 remains connector exchange
capture. Publication digest, chunk verification and permanent record identity
follow [Station publication](STATION_PUBLICATION_V1.md).

`FXS1` / format `0x31535846` is:

| Field | Encoding |
| --- | --- |
| Magic, native definition, bound fingerprint | 4, 32, 32 bytes |
| Exchange, source | uint64le, uint8 |
| Partition count, partition, physical epoch, sequence | four uint64le |
| Terminal, row count | boolean byte, uint8 |
| Rows | zero to four rows |

Each row contains the 20-byte identity above and one nullable-int64 value per
schema column. Non-int64 unreferenced columns have NULL placeholders. Unused
resident vector positions must be NULL. Referenced int64 values obey schema
nullability. Rows are strictly increasing by stable identity within a segment
and, during consumption, across consecutive segments of one partition. Each row
must route to the declared partition. The row count is at most four. A zero-row
segment must be terminal. Sequence is zero-based and less than uint64 max.
Terminal segments may contain the last rows or be empty.

Control keys are 28 bytes: `00 78`, tag, exchange:uint64be, source:uint8,
partition:uint64be, sequence:uint64be. Tags are `h` for the receiver head (zero
suffix), `c` for a channel (zero sequence), `p` for producer eligibility, `a` for
receiver acceptance, `s` for the one reserved incoming segment (zero suffix), and
`b` for the producer quota record (zero suffix).
Row-index keys are 32 bytes: `00 78 72`, exchange:uint64be, source:uint8 and the
20-byte stable identity. All values remain within native's 256-byte bound.

| Magic | Fields after definition; integers are little endian |
| --- | --- |
| `RXH1` | bound fingerprint; ten uint64 values: exchange, owner, resource, partitions, registered pairs, completed pairs, next publication record, retained charge, inflight bytes, inflight segments; retained-byte/credit-byte/credit-segment limits as three uint64; source-count, pending, closed bytes |
| `RXC1` | six uint64: producer PID, resource, consumed segments, accepted segments, highest sequence plus one, terminal sequence (uint64 max means absent); row cursor, complete, last-identity-present bytes; last identity, all zero when absent |
| `RXP1` | source:uint8, partition:uint64, sequence:uint64, exact 72-byte producer publication reference |
| `RXA1` | exact 72-byte producer reference, exact 72-byte receiver reference |
| `RXR1` | exact 72-byte receiver segment reference, row ordinal:uint8 |
| `RXB1` | bound fingerprint; six uint64: exchange, producer PID, resource, cumulative quota, charged bytes, last offered publication record; pending-reference-present byte; 72-byte pending publication reference, all zero when absent |

`RXH1`, `RXC1`, `RXP1`, `RXA1` and `RXR1` are respectively 175, 107, 125, 180 and
109 bytes. `RXB1` is 189 bytes. Every saved reference binds format, length and
publication digest.

## Acceptance, consumption and coverage

The authorized producer reserves its cumulative logical byte charge before
staging a complete segment privately. One pending exact publication reference
prevents competing segments from taking that reservation. Publication IDs
increase monotonically within a producer's exchange namespace. Only a later turn
records its `p` entry and sends the identified `RXP1` notice atomically. The host
retains that exact publication until durable receiver acceptance. A notice does
not itself establish eligibility, consumption or credit.

The receiver verifies the authenticated producer PID, fixed source/partition
binding and current rights to every query source. It reserves one incoming
segment at a time and charges its retained quota before copying; concurrent
channel registration cannot spend this reservation. It reopens the producer's
current resource, verifies its exact
eligibility record and publisher, and copies the verified segment into its own
publication through bounded turns. Acceptance atomically records the local and
remote references, advances channel/head counters and sends an acknowledgement.
The acknowledgement repeats the exact `RXP1` identity. A duplicate must have the
same original reference and returns the same acceptance without adding credit.
After acceptance, retries use the receiver copy and need no producer reread.

Acceptance within a channel is consecutive. A later notice arriving before a
missing sequence returns `blocked` without acceptance; the producer retains and
retries its exact notice. This avoids a credit deadlock in which accepted future
packets occupy all space needed by missing predecessors. Different channels can
be scheduled in any order. The host must service consumption as well as receipt.

Consumption inserts at most one row-index entry per turn. It advances that
channel's row cursor atomically with the entry, rejects duplicate source-row
identities, and releases segment/byte credit only after all rows are indexed.
The final row or an empty terminal segment also records partition completion.
Accepted bytes and deduplication evidence remain retained after consumption.

The source adapter refuses all execution until every required partition is
registered and has consumed its terminal segment, with no reserved/inflight
segment remaining. Each read uses one bounded native index page and one bounded
segment. The ordered index restores the original source identity order,
independent of routing, delivery, batch size or worker layout. The existing
finite executor then determines join coverage, bag multiplicity, group order
and the first ordered arithmetic error. A receiver does not combine partial
SUMs, publish early unmatched-left rows or infer empty coverage from silence.

## Budgets, authorization and failure

Hosts supply explicit resident, producer/receiver cumulative retained-byte, inflight-byte and
inflight-segment limits. Minimum byte limits accommodate the largest segment;
segment credit is positive. One staging record bounds active copying and fan-in,
independently of the durable partition count. Native paging bounds registry and
row-index reads. The cumulative charge conservatively includes segment bytes,
publication keys/descriptors, control records and four row-index entries per
segment. Producer charges include its eligibility records and publication
keys/descriptors. Charged reservations survive failed staging and neither
consumption nor publisher retirement returns retained-byte quota in this profile.
Accounting does not measure provider page/journal amplification; deployment
quotas govern that physical storage. The host budgets operator state separately
and must admit their combined allocation within the query's total budget.

All receiver and producer operations except own-resource closure require the
bound source adapter's current validation, including noncontributing sources.
Hosts register only the resource views needed by the current operation, and
source adapters add native current-view guards before acceptance. The receiver
adds a producer current-view guard while copying. Source pins, copied bytes,
placement and old successful access do not grant current disclosure rights.
Protocol checks do not prove that a worker computed honestly.

`blocked` is unaccepted, retryable pressure or sequence ordering. `progress`
preserves private staging/reservation. `accepted` and `duplicate` establish only
durable receiver ownership. `complete` describes consumed partition coverage.
Quota errors, missing/corrupt records, changed identities and denial cannot
truncate an answer or reset a source to latest. The host settles an uncertain
native proposal before issuing a fresh one. Fresh own-resource `close` remains
available after denial or pressure and rejects further execution while retaining
all evidence. Physical cleanup requires an explicit retention contract; default
retention remains unlimited.
