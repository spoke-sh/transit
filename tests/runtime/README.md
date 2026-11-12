# Application runtime checks

These suites cover Station execution, application lifecycle, delivery, effects
and provider reconciliation. Direct data storage and query execution have their
own owners. Read the [Station reference](../../docs/handbook/reference/station.md)
and [contribution instructions](AGENTS.md).

| Boundary | Drivers |
| --- | --- |
| Application publication, activation and real binaries | [application/](application/), [callers](application/callers.py), [work-items](application/work_items.py) |
| Station turns, supervision, quota and lifetime | [station/](station/), [services](station/station_services.py), [lifetime](station/station_lifetime.py) |
| Delivery readiness and physical fault schedules | [Readiness](delivery/courier_readiness.py), [Vortex](delivery/vortex.py), [receipt-loss control](delivery/vortex_proxy.py) |
| Recorded HTTP/gRPC effects and outcomes | [effects/](effects/), [HTTP worker](effects/http_worker.py), [gRPC worker](effects/grpc_worker.py) |
| Document publication, conflicts, tombstones and retained revisions | [Crash schedule](document/document.py), `just test::document-local` (local WAL/objects), `just test::document` (disk Ursula) |
| Provider replacement and lost responses | [Upgrade schedule](deployment/runtime_upgrade.py) |
| Core authority, effects and readiness over Ursula | [Native core](core/), [effect proofs](effects/effects.zig), [outbox](delivery/outbox.zig) |

The [test module](../../tasks/test.just) and
[launcher modules](../../tasks/launchers.just) supply actual binaries and explicit
provider profiles. Repository Python entry points use the shared test launcher.
Installed SDK adapters live in [sdk/](../sdk/README.md); deterministic transition
models and schedules live in [verification](../verification/README.md).

External fault experiments have explicit [prerequisites and limits](../harness/fault-profiles.md).
A reproducible seed specifies workload/fault intent, not OS scheduling. Runtime
history remains execution authority; provider state and names cannot grant rights.

## Private transactional Station

`just test station-transaction` builds the private Station composition and runs
[transactional.zig](station/transactional.zig) against an installed local node.
The [driver](station/transactional.py) independently checks interruption markers,
SIGKILL exit statuses, immutable saved declarations, replacement with a fresh principal/key for each actor, and retained restart
readback. The normal suite runs all registered cases;
`TRANSIT_STATION_TRANSACTION_CASES` selects a diagnostic subset and reports
`complete = false` unless the full inventory ran. Subsets do not qualify the suite.

The 128-byte and separate 1 KiB/six-key cases use a real detached body, Table
read-your-writes, direct KV, an input Queue ACK, a replay Stream and an output
Queue. Fault points cover pending publication, BEGIN, claim, input retention,
cut acquisition, handler dispatch, draft retention, statement staging/execution,
decision and progress cleanup. Failed/caught reads, exceptions, capacity and stop
have separate cases. A takeover after handler completion proves that the old
worker cannot publish despite its still-live input lease. Each recovery uses the original pending transaction and
asserts zero handler invocations. These are process-failure schedules, not
power-loss or distributed authority qualification.
