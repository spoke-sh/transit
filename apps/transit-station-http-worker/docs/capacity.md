# Finite HTTP capacity and recovery

This worksheet describes the current M15 executable. These are per-operation
and per-exchange limits, not limits on the number of retained exchanges. The
growing store pages durable history; the worker never materializes that history.

| Budget | Implemented limit / accounting |
| --- | --- |
| Live executor | One configured exchange per OS invocation, one authorized send |
| Request body | 65,536 bytes, buffered in this finite worker |
| Request metadata and rendered head | At most 8,192 bytes each |
| Capture segment | Up to 8,192 bytes; transport emits 4,096-byte segments |
| Durable capture | 262,144 bytes and 256 segments, including any one pending segment reservation |
| Publication staging | One segment reservation per exchange namespace |
| Publication chunk | 256 bytes; at most 32 chunks in one worker segment |
| Credential bindings | At most 16; at most 4,096 bytes per resolved value |
| Explicit trust bundle | At most 1 MiB; its digest is frozen before dispatch |
| Network deadline | Endpoint timeout at most 300,000 ms, capped by the original reconciliation deadline |
| Followups | Explicit root attempt budget, including the original; no refunds or renewed deadline |
| Turn | One writable resource, four mutations, four outputs; private failure rolls back |
| Replay | One bounded part per read, current permission and availability rechecked |
| Cleanup invocation | Default 64, maximum 128 bounded steps; restart from durable progress |

The endpoint's request/response byte limits can be lower than these caps. Raising
an endpoint limit does not widen the executable's request buffer, exchange byte
limit or segment count. Capture may stop incomplete before a peer finishes when
any limit is exhausted. Remote application is then uncertain; neither a prefix
nor capacity exhaustion authorizes retry or deletion.

For `B` captured bytes spread over `S` segments, publication needs at most
`ceil(B / 256) + S - 1` nonempty chunk keys, plus `S` publication descriptors and
`S` coverage members. Empty segments still need descriptors and coverage. At the
current byte/segment caps this gives at most 1,279 chunk keys, 256 descriptors and
256 members, plus fixed exchange, namespace, route, settlement, lineage and
dependency records. A pending segment uses the remaining byte/segment budget;
it has a publication reservation/chunks but no sealed coverage member yet.
This counts current logical keys only. It excludes retained versions, outbox,
mailbox, signed receipts, journal entries, page copy-on-write, WAL and snapshots.
It is not a physical storage-size formula.

Each segment takes a begin turn, one turn per chunk and a seal turn. The worker
also records its self-ticks, execution permits and state views. Reads and lost
transport responses do not become extra accepted commands when the exact signed
request is retried. Admission, caller publication, settlement, dependencies,
delivery and later cleanup require additional positions. Use signed capabilities
to monitor the actual authority position and remaining admission headroom.

## Admission and emergency headroom

The growing kernel exposes optional `admission_ceiling` and `control_reserve` in
genesis. They are deployment quotas, independent of retention. Their exact
behavior and the executed 96-position/96-reserve, 2 GiB filesystem proof are in
the [authority guide](../../../packages/zig/transit-core/docs/authority.md#growing-profile-an-explicit-control-reserve-not-a-derived-one).
The kernel does not preallocate storage on the operator's behalf.

Reserve enough **ordinary admission** for all admitted work before dispatching.
The kernel reserve permits effect closure and other defined control commands;
it does not admit new self-ticks, new views, capture publication or correlated
reply outputs. Thus a connector may have a terminal kernel decision while its
framework settlement/capture remains unfinished. Preserve those records and
holds. Do not treat a 4,096-position reserve as a guarantee that arbitrary
connector cleanup or all accepted application work can finish.

For the measured disk/S3 worker/API/browser schedule, fifteen sends and seven
remote applications retained 106,209,530 object-store bytes in 966 cold objects
with an 8 MiB hot bound, no retention opt-in and no increased store limit. It took
477.68 seconds excluding compilation. A former hot-only 64 MiB fixture exhausted
its capacity. This is measured evidence for that schedule, not a maximum for
arbitrary histories or an admission formula. WAL, snapshots, temporary build
outputs and diagnostic logs need separate physical budgets. Hosted CI costs for
the expanded connector inventory remain unmeasured.

## Recovery decisions

| Durable evidence | Fresh worker action |
| --- | --- |
| Incomplete caller publication | Resume with identical metadata/body commitments |
| Preparing exchange, no intent | Resume identical preparation or explicitly abandon without claiming remote cancellation |
| Pending effect, complete frozen request | Recheck current endpoint/credential/resource scope, then authorize one send |
| Authorized effect after worker loss | Close unknown; never repeat the send |
| Complete capture, observation uncertain | Retry the exact authority request or recover and settle from durable evidence |
| Kernel terminal, reply not published | Resume framework settlement and fixed-destination publication |
| Caller/name replaced | Keep the original recorded destination; name lookup cannot redirect a late result |
| Retired group with remaining bytes | Refuse replay and resume bounded reclamation after required holds are released |

Read revocation, caller disposal, group retirement and physical cleanup are
different operations. A linked child protects its ancestors until it settles or
is explicitly abandoned before intent. Replay uses neither credentials nor a
live endpoint. Operating-system process loss, stale ownership or an expired
reconciliation deadline cannot establish that a remote side effect did not run.
