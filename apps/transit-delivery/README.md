# transit-delivery

A Zig service that advances committed process outboxes through the public
`transit-client`. It has no storage credentials, handler code, provider access or
second task queue. Core remains the delivery authority.

```sh
zig build transit-delivery
zig-out/bin/transit-delivery courier.json
zig-out/bin/transit-delivery courier.json --check
zig-out/bin/transit-delivery courier.json --once
```

The configuration contains `url`, `realm`, non-root `principal`, and `seed_file`.
Optional `interval_ms` defaults to 100; `request_timeout_ms` defaults to 5000.
Both must be 1–60000. The seed file contains a private 32-byte hex Ed25519 seed.
Provision a **dedicated principal** with delivery (128) and send (4) capabilities,
optionally scoped to one destination PID. Do not share its mutation sequence with
other kinds of operation. General inspection, execution and admin are unnecessary.

The executable calls the shared `transit-client.delivery.step` function.
Each step reads `kind: { delivery: {} }` through `/v1/query`, then submits
`command: { deliver: OUTPUT_ID }` through `/v1/command`. The read selects the
lowest pending output in the caller's destination scope without disclosing its
payload. Core atomically records delivery or terminal denial/retirement/expiry.
Route order and current destination send grants are checked at acceptance.
Removing send rights permits recording denials; removing delivery rights stops
the service.

An uncertain exchange retains and retries the exact signed operation, including
its selected output. After process loss, the next signed observation reconstructs
work from current sequence and pending outputs. A delayed competing decision is
fenced by principal sequence; resolved outputs cannot be delivered twice. Use a
dedicated sequencer for each principal. The courier has no local retry database.

`--check` validates current signed access and authoritative status without writing.
It proves connectivity/credentials, not delivery throughput or a drained backlog.
`--once` attempts one step and exits; a transport failure can leave its result
uncertain. Normal mode retries transport/storage failures with the configured
interval; access loss and definitive unexpected rejection exit unsuccessfully.
Shutdown can interrupt a request; restart reconciles through the same protocol.
No shutdown path cancels or discards pending outputs.

`transit.delivery.step` reports progress, rejection and failures with realm and
bounded telemetry context; idle scans are debug. The signed response identifies the next pending output, authority position and
principal sequence. A scope whose oldest output needs unavailable trusted time
can stall; clock health and scope partitioning remain operational concerns.

Inspect it with `transit-admin query SEED QUERY URL`, where QUERY contains
`{"realm":42,"principal":5,"kind":{"delivery":{}}}`. This read consumes no
mutation sequence. The [service contract](../../contracts/SERVICE_V1.md) owns its
bounds and authorization; the [proof ledger](../../tests/README.md) records
courier, restart and exact-retry checks.
