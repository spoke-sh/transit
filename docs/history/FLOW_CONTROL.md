# Flow control

Engineering background and historical design. Use [Streams and delivery](../handbook/reference/streams.md)
for the current public explanation shared by users, developers and agents.
Consult this record for rationale and proposals; it does not extend a qualified profile.

Use explicit application credit when a producer can outpace durable acceptance.
The [query delivery contract](../../contracts/STATION_QUERY_V1.md#flow-control) is
the implemented example. Socket backpressure alone does not prove a receiver
has durably stored application work.

Status: one concrete instance is implemented —
[growing result delivery](../../contracts/STATION_QUERY_V1.md#flow-control),
checked abstractly by [`Delivery.tla`](../../tests/verification/models/Delivery.tla)
and qualified both in-memory and against real disk Ursula/node restart. Every
other reference below is prose scope, not a proved contract: connector
capture admission ([GRPC.md](GRPC.md#streaming-authority-and-backpressure),
[CONNECTORS.md](CONNECTORS.md)) states the same requirement without yet
defining a credit protocol for it. This document names the shared pattern and
its boundaries so each new instance reuses one vocabulary instead of
rediscovering the distinction below.

## Two different things share the name

"Flow control" means two things in this codebase, deliberately kept separate.

**Transport flow control** regulates how much unacknowledged data may be
outstanding on a wire: TCP's window, QUIC's per-stream/connection limits,
HTTP/2's frame-level credit that gRPC inherits. This lives entirely in the
[transport tier](CONNECTORS.md#transport-connector-and-integration) — a
selected library's concern, not something Transit implements or reimplements.
It is real and necessary, and it proves nothing about the receiving
application: [GRPC.md](GRPC.md#streaming-authority-and-backpressure) already
states this plainly — "receiving flow-control credit or completing a transport
write is not evidence of durable remote admission." A connection can accept
bytes onto the wire while the process on the other end has not durably stored
anything yet.

**Application admission credit** is what this document actually specifies:
Transit's own control over how far a sender may run ahead of what the
*receiver has durably stored*, independent of whatever the transport allows.
This is the thing every connector and every Station-to-Station delivery
protocol needs, and the thing that was actually missing — not a faster wire,
a bound tied to durable acceptance.

Congestion control (estimating shared network capacity, e.g. AIMD, BBR) is
out of scope for both. Transit's own protocols run between trusted or
semi-trusted internal peers, not across an open, contended network; whatever
congestion control applies is the transport/library's job, not a concern this
document or its instances take a position on.

## The pattern

Every instance of application admission credit in this codebase (or specified
for one) follows the same shape:

- **Quantized to the protocol's own natural durable unit** — never raw bytes.
  Growing result delivery uses the segment (already the atomic thing that gets
  digested, sealed and independently verified); a connector would use the
  captured message/attempt (already the atomic thing a durable receipt names).
  A byte-level window invents a second unit with no existing meaning in the
  protocol; reusing the unit that's already durable and verified is what makes
  the credit check meaningful rather than cosmetic.
- **Receiver-issued, not sender-self-paced.** Self-pacing (a sender doing a
  bounded amount of work per turn/proposal, e.g. growing delivery's current
  three-fragments-per-turn cap) bounds one proposal's cost; it says nothing
  about whether the destination is keeping up, and it is not a substitute for
  credit. A receiver only grants credit for units it has already durably
  stored — never merely enqueued, accepted onto a socket, or observed on the
  wire.
- **Grant observation is its own, separately lossy step.** A credit grant is
  an ordinary message and can be lost, delayed or reordered exactly like any
  other; a sender's enabled-to-send state depends on the credit it has
  actually observed, not on what the receiver most recently issued. Collapsing
  "granted" and "observed" into one step hides exactly the asynchrony a real
  network introduces.
- **A small fixed window**, not an adaptively tuned one, is the right default
  absent evidence otherwise. TigerBeetle's fixed pipeline-depth cap on
  in-flight prepares is the closer model for an internal, deterministic
  protocol than HTTP/2 or TCP's adaptive windows: no negotiation,
  no tuning surface, one reviewed constant. Once a window constant is chosen
  for any instance, classify and review it the same way
  [`limits.json`](../../tests/verification/limits.json) already treats every
  other operation bound, rather than leaving it a bare literal.

`Delivery.tla`'s four invariants are this pattern stated formally, generic to
any instance: `WindowBound` (the sender never outruns observed credit by more
than the window), `CreditSound` (the receiver never grants credit ahead of
what it has durably stored), `NoPrematureAck` (completion never precedes full
receipt), and ordered acceptance by construction. A future connector-admission
credit model should be expected to state the same four shapes against its own
units, not invent new ones.

## Where this applies today

[Growing result delivery](../../contracts/STATION_QUERY_V1.md#flow-control) is
the only implemented instance: segment-quantized, receiver-driven, a fixed
two-segment window, its grant frame (`GQG2`) authenticated, non-regressing and
resume-triggering. Credit is scoped per result, not pooled across a
destination's concurrent results — the simplest choice available, and the one
that document leaves open to revisit if a destination's fairness across
several concurrent results ever needs it.

Connector capture admission is scoped in prose only:
[CONNECTORS.md](CONNECTORS.md) requires bounded worker buffers for streamed
HTTP bodies, and [GRPC.md](GRPC.md#streaming-authority-and-backpressure)
requires bounding live calls, queues, bytes and capture work independently in
each direction of a bidirectional stream. Neither yet names a credit unit or a
grant frame; when M16 specifies gRPC's streaming authority,
it should instantiate this pattern (the captured message/attempt as the unit)
rather than inventing a separate scheme. Multiplexing several effects or
several growing-query destinations over one connection raises the same
per-stream-vs-pooled question this document leaves open for both instances;
resolve it once, not per connector.
