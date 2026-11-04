# Installed application scenarios

`just test::server-scenarios` runs a copied `transit` executable with its default
embedded node, SQL, application manager and Board, synchronous local durability
and automatic maintenance. It owns a fresh private installation and joins its
processes and HTTP listeners. The installation CI lane runs this check.
The separate [console latency gate](../console/gate.py) owns the early CI/release
SQL latency and process-resource check; these scenarios add computation and
effect lifecycle coverage to that baseline.

| Scenario | Independent checks |
| --- | --- |
| Persistent console | Empty/one-row reads, INSERT/UPDATE/DELETE, unchanged/zero-match counts, immediate fresh reads and retained restart |
| SQL → Dataflow → Table | Empty initial result, inserted/updated/deleted output, exact values and complete coverage, foreground console reads during refresh, settled revision and retirement |
| Webhook → Dataflow → HTTP → outcome | Authenticated inbound HTTP, stable SQL token deduplication, conflicting payload rejection, committed Table intent, real finite Station caller and HTTP connector, recorded outcome and SQL projection |
| Slow destination | Hold the actual HTTP response while another webhook is durably accepted and an independent console read completes; release and verify capture |
| Lost response and recovery | Destination accepts then disconnects; preserve `closed_unknown`, original call identity and one send; restart the installed node and read/replay with both HTTP listeners stopped |

The webhook listener is a finite **test application adapter**, not a new public
Transit route or SQL `SINK` declaration. It authenticates synthetic bodies with
an application HMAC and validates a bounded integer payload before using public
SQL. The fixture treats input rows as immutable and retains their event identities.
The Dataflow output Table
is the application's intent relation: its rows and completed revision are
published together by the existing managed owner. The explicit application
dispatcher binds each selected event to a provisioned finite caller/connector
pair. Their existing recorded call, request commitment and effect identity own
dispatch/recovery. Source ingestion and Dataflow computation do not use Station
turns. Root authority is used only by the fixture operator for provisioning,
ownership and inspection; the caller and connector use scoped identities and
the installed courier delivers their recorded outputs.

This is two finite exchanges, not a multi-exchange connector scheduler, arbitrary
webhook payload profile, transactional SQL sink, ordered change consumer or
incremental Dataflow implementation. The separate SQL outcome projection follows
the authoritative connector outcome; it is not atomic with remote execution.
The unknown case records its explicit phase rather than treating an absent HTTP
status as failure or retry permission. Duplicate delivery and result reads never
create another effect. The test does not claim external exactly-once delivery.
An explicit Dataflow refresh republishes the same event intents and recovers the
same application calls. Trigger identity follows the immutable event, not each
finite recomputation's revision number.

## Measurements and gates

The runner emits raw records under `.cache/performance/scenarios/`. Every sample
has an outcome, independent verification flag and external elapsed time. Console
samples also retain the actual console phase timings. Freshness is measured from
the first observation after source completion to verified output; it is not an
inferred WAL commit timestamp. Connector dispatch time includes the deliberately
blocked receiver and concurrent console check. Provisioning/preparation, startup
and retained restart are separate stages. Input-to-recorded-outcome spans include
the finite application's provisioning and any wait behind the first exchange.
They begin immediately before the inbound HTTP request and end after SQL verifies
the recorded outcome. CPU ticks include the owned installation
tree, including Board, but exclude the separately launched connector; counters unavailable at this boundary remain explicitly
unavailable. No zero-allocation or physical-sync-count claim follows from timing.
Transient refusals of fresh `SHOW DATAFLOW` observations consume the original
completion deadline and elapsed span and are counted in `observation_refusals`.
They do not authorize replaying a mutation or restarting a partially read result.
Courier output inspection discards its entire partial view on `QueryExpired`
and starts a fresh observation within the original deadline; effect samples
record these `delivery_restarts`. Pages from different cuts never establish
delivery completion together.

[`scenario_budgets.json`](scenario_budgets.json) supplies executable maximum
latency ceilings for the finite smoke workload. These generous regression guards
are not tail SLOs or the 10–100× improvement target. The existing operational
deadlines are unchanged. A late verified result remains in the evidence and
fails its budget. Failed, incomplete, duplicate and missing scenario samples
cannot pass the reporter. One or two samples cannot establish p95/p99.
The [control calibration](../../../docs/history/qualification/performance.md#installed-scenario-control-and-smoke-ceilings--2026-11-03)
records the unchanged runtime's complete three-cycle campaign and the failed
initial ceilings. Concurrent-read and observed-effect ceilings round up with at
least 25% headroom; the three Dataflow mutation cases share a 50-second ceiling
above their control's slowest successor. These bounds describe the current finite
profile, whose coordination costs remain substantial. The separate console gate
retains its existing tighter SQL regression limits.

For repeated measurements, build once from committed source, then run serially:

```sh
zig build transit example-station-http transit-station-http-worker -Doptimize=ReleaseSafe
python3 -B tests/runner/launch.py tests/performance/load/scenarios.py \
  --cli zig-out/bin/transit --http-caller zig-out/bin/example-station-http \
  --http-worker zig-out/bin/transit-station-http-worker --repeat 20 \
  --binary-revision "$(git rev-parse HEAD)"
python3 -B tests/runner/launch.py tests/performance/load/scenario_report.py \
  CANDIDATE.jsonl --control CONTROL.jsonl --maximum-ratio 1.25
```

`--scenario console` or `--scenario dataflow` selects a smaller diagnostic
workload; neither needs the HTTP binary arguments. `--budgets FILE` applies an
explicit budget for the selected scenario and repetition count. Match source
definitions, drivers, host, build mode, durability and cache conditions before
comparing. Changed definitions require a separately reviewed fresh-store
experiment; do not weaken comparison checks or open old stores with incompatible
binaries. Run uninstrumented timing controls separately from attribution and
heavy builds. Shared-host interference still limits causal conclusions.

The [installed managed/connection campaign](installed.md) retains its larger
finite and connection-pressure workloads. [Connector fault tests](../../runtime/README.md)
own the broader revocation, credential and process-death schedules. Passing this
scenario does not replace either suite.

The next performance work remains with the existing owners: reduce fresh-read
and write coordination in [M8](../../../docs/roadmap/08-gateway-architecture-and-protocol-ingress.md),
then qualify retained change consumption, incremental execution and governed
effect outboxes in [M12](../../../docs/roadmap/12-sql-and-dataflows.md), using
[M6's mixed transactions](../../../docs/roadmap/06-streams-queues-and-durable-runtime.md).
The finite adapter supplies a measurable journey for that work; it does not
establish a 10–100× speedup or replace those contracts.
