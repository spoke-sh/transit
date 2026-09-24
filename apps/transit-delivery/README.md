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

Each step reads signed `/v2/delivery` status, then submits `deliver_next`. Core
selects the lowest pending output ID in that principal's destination scope and
atomically records delivery or a terminal denial/retirement/expiry. Route order
and current destination send grants are checked at acceptance. No application
payload is disclosed to the courier. Removing send rights permits recording
terminal denials; removing delivery rights stops the service.

The signed mutation has no changing selection parameters. Its principal/sequence
identifies one durable decision; uncertain transport results retry those exact
bytes. After process loss, current sequence plus pending outboxes reconstruct the
next operation. A delayed pre-crash request either matches that same identity or
is already behind the receipt horizon. Identical replicas are safe but add no
ordering/throughput guarantee; use one courier per configured scope initially.
There is no local retry database to synchronize or recover.

`--check` validates current signed access and authoritative status without writing.
It proves connectivity/credentials, not delivery throughput or a drained backlog.
`--once` attempts one step and exits; a transport failure can leave its result
uncertain. Normal mode retries transport/storage failures with the configured
interval; access loss and definitive unexpected rejection exit unsuccessfully.
Shutdown can interrupt a request; restart reconciles through the same protocol.
No shutdown path cancels or discards pending outputs.

`transit.delivery.step` reports progress, rejection and failures with realm and
bounded telemetry context; idle scans are debug. The signed status returns pending
count, authoritative position and principal sequence, without payloads. A scope
whose oldest output needs unavailable trusted time can stall that courier; clock
health and scope partitioning remain operational concerns.

`just test::callers` runs real Zig applications with this service, drops receipts,
checks byte-identical retries and restarts it. Core tests prove scope restrictions,
revocation and terminal denial. Launcher integration belongs to
[M8 qualification](../../docs/roadmap/M8.md).
