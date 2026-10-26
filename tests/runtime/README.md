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
| Document application behavior | [document/](document/) |
| Provider replacement and lost responses | [Upgrade schedule](deployment/runtime_upgrade.py) |

The [test module](../../tasks/test.just) and
[launcher modules](../../tasks/launchers.just) supply actual binaries and explicit
provider profiles. Repository Python entry points use the shared test launcher.
Installed SDK adapters live in [sdk/](../sdk/README.md); deterministic transition
models and schedules live in [verification](../verification/README.md).

External fault experiments have explicit [prerequisites and limits](../harness/fault-profiles.md).
A reproducible seed specifies workload/fault intent, not OS scheduling. Runtime
history remains execution authority; provider state and names cannot grant rights.
