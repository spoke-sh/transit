# M2 follow-up — Board and Transit observability

[Roadmap](README.md) · [M2](M2.md) · [Observability design](../OBSERVABILITY.md)

Status: implemented and qualified on Linux x86_64. Board request visibility,
bounded common primitives, node/client correlation, dependency/caller signals
and local/Compose/Kubernetes-Substrate qualification are complete.
The completed M2 inspection profile retains its documented qualification.

## Outcome and scope

An operator running `just launchers::local::up` can see Board requests, follow
their Transit calls, distinguish service failure from protocol rejection, and
understand why execution or maintenance stopped progressing. The same event
meanings carry into Compose and Kubernetes/Substrate. Transit is diagnosable
without Board, and Board owns its service instrumentation.

Implement logs, bounded metric instruments and short trace/context hooks before
adding remote export. This work introduces no collector/backend, public metrics
endpoint, operator controls, new task store, or change to execution authority.
Full dashboards, browser telemetry and Station/connector-specific signals follow
their respective implementation scope.

## Design gates before shared plumbing

| Gate | Concrete result required |
| --- | --- |
| Ownership and dependencies | Board and Transit call-site designs demonstrate the common interface. Reserve `transit-observability` for Transit vocabulary; choose any neutral shared package's name and manifest only after showing its consumers. Core retains its deterministic boundary. |
| Signal contract | Define versioned event fields, finite outcome/error categories, timestamp/duration semantics, metric units/reset/freshness and span boundaries. Distinguish transport completion from known durable outcomes. Document unknowns explicitly. |
| Resource budget | Choose numeric limits for records, queues, spans, series, writer concurrency and flush; specify drop/coalescing policy and finite launcher log rotation. Measure baseline overhead and control/deadline progress with a stalled sink on one CPU. |
| Trust and configuration | Specify allowlisted data, remote context policy, per-service verbosity/format, service identity and configuration precedence. Preserve machine stdout. Inspect supported OpenTelemetry conventions and pin the selected schema revision. |

These gates are implementation tasks, not permission to add speculative packages
or claim an exporter is supported. Put exact contracts/configuration with the
owning code and record design changes in [OBSERVABILITY.md](../OBSERVABILITY.md).

## Implementation sequence and logical commits

1. **Board request visibility.** Establish the gates above against concrete
   Board and Transit call sites. Implement the minimum bounded sink/interface
   and Board HTTP lifecycle instrumentation. Cover API/static requests, auth
   and session outcomes, upstream failures, malformed requests, timeout and
   disconnect; preserve probe and polling noise policy. Human output is useful
   in foreground launchers and JSON has a tested schema. No request/body secrets.
2. **Transit ingress and client correlation.** Add the Transit-specific package
   where shared events warrant it. Instrument node requests and client attempts,
   propagate bounded validated context, and expose separate transport/protocol
   outcomes. Add metric snapshots and short span consumers for tests. Prove
   signature/receipt/retry compatibility and no Board dependency. Distinguish
   fresh commits from previous receipts where supported; otherwise omit the
   stronger metric rather than invent a duplicate-tracking authority.
3. **Execution and dependency progress.** Instrument maintenance, storage,
   runtime reconciliation and the real Zig callers/CLI. Cover recovery, fencing,
   blocked work, deadlines, checkpoint/trim/deletion and uncertain operations.
   Prefer changes and bounded summaries over every idle iteration or replayed
   record. Expose only gauges with evidence and freshness; record startup,
   shutdown and recoverable failures without corrupting bootstrap/one-shot output.
4. **Launcher and deployment qualification.** Wire documented per-service
   configuration into local, Compose and reference profiles; implement finite
   log storage and preserve lifecycle/error visibility through restart/rotation.
   Verify that service logs and manager/provider diagnostics remain attributable.
   Update component READMEs and proof evidence with runnable commands and limits.

Keep each step reviewable and leave its focused checks passing. The first step
delivers visible navigation logs; it does not imply the later signal coverage is
already implemented. Remote OpenTelemetry export is a separately scoped follow-up.

## Acceptance and adversarial evidence

| Scenario | Required evidence |
| --- | --- |
| Board navigation and API inspection | Useful request logs contain route, local response/transport outcome and elapsed time. A Board-to-Transit call has distinct correlated observations; startup and health failures remain visible. |
| Invalid authentication, forged trace headers or secret-bearing input | Bounded handling, no authority inherited from context, no credential/payload/query leakage or log injection, and finite error/route categories. |
| Client timeout/disconnect after a commit; response write failure | Transport failure does not become a fabricated protocol rejection or rollback. Completion logging accounts for joined cancellation and does not race a live handler. |
| Duplicate submission, retry, recovery and replay | Attempts and previous receipts remain distinguishable from fresh durable work; counters/traces do not claim fresh execution or external dispatch during replay. |
| Stalled/full/closed sink, telemetry disabled, or one-CPU runner | Bounded memory/CPU/flush, visible drop accounting when possible, control and deadline progress, unchanged durable results and no recursive logger failure. |
| Request floods, arbitrary routes/IDs, long history or repeated failures | Stable metric cardinality, bounded logs/spans/queue work, coalescing and finite disk retention; error diagnostics retain a useful budget under noise. |
| Storage outage, expiry, stale ownership or uncertain provider result | Named failure boundaries and supported progress measurements explain the issue without inferring expiry, cancellation or new authority from telemetry. |
| Service restart, crash, probe failure and log rotation | Instance identity and counter resets are visible; manager diagnostics survive normal use, machine stdout stays parseable and retained logs follow the configured budget. |

- [x] Board HTTP instrumentation and Transit-specific instrumentation have clear
  ownership, public interfaces, manifests and dependency checks where applicable.
- [x] Tests cover logs, metric values/reset behavior and span relationships;
  disabled or lost telemetry cannot affect protocol decisions or control progress.
- [x] The scenarios above pass against real service/caller binaries, including
  running Transit without Board and Board with only its public client access.
- [x] Local, Compose and reference profiles expose the same event meanings and
  declare differences in provider signals, buffering, persistence and limits.
- [x] Documentation distinguishes implemented instruments from deferred export;
  protected telemetry has a finite resource and retention policy.

Use `just check` plus affected `transit-board::test`, `test::service`, `test::callers`,
`test::storage` and `test::inspection` proofs as each surface changes. Extend the
existing launcher proofs for log visibility, rotation and failure behavior; run
Compose/reference qualification when their configuration or runtime coverage
changes. Record actual commands, measurements and remaining limits in
[tests/README.md](../../tests/README.md), without claiming unrun deployment proofs.

Implemented contracts live in [telemetry](../../packages/zig/telemetry/README.md),
[transit-observability](../../packages/zig/transit-observability/README.md), and
the instrumented components. Qualification includes the actual node with a full
unread log pipe on one CPU, real Board/client/node span relationships, local and
Compose restart/log configuration, and the Kubernetes/Substrate recovery and
isolation proof. [Recorded evidence](../../tests/README.md#service-instrumentation-qualification)
includes overhead measurements and the packaging issue exposed by qualification.

The supported profile has local aggregate metrics and short correlated span
records, not remote distributed-trace storage. Receipts do not identify fresh
commits, so no fresh-commit counter is claimed. Shutdown bounds require cancelable
I/O (proved with the pinned Linux pipe implementation); abrupt exits may lose
records. Rotation budgets can overshoot between checks and do not cover every
external provider store. Other host platforms, a collector/exporter, public
scraping, browser telemetry and Station/connector-specific instruments remain
outside this completed profile.
