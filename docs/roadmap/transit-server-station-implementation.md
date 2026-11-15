# Server ownership of Station services and controller removal

[Milestone 3](03-live-storage-and-sql-cutover.md#p7--deliver-the-single-executable-local-profile)
· **Status: In Progress** · 2026-11-14

Make `transit server` advance declared Station timers and supervisor retry
intents, then remove `transit-station-controller` from executable builds,
deployments and future release publications. Applications retain their durable
waits, child policies and accepted work; operators run the service through the
server and inspect whether its registered obligations are progressing.

**Planning source basis:** `caaf43a2b`, after the admin and delivery executable
removals. Implementation is committed through `b05f6f640` on
`plan/server-station-controller-ownership`. The [server guide](../../apps/transit-cli/docs/server.md#station-services)
and [application guide](../../apps/transit-cli/docs/applications.md) own the current
interfaces. The delivery sequence and acceptance matrix below preserve the plan;
they do not establish qualification. The [executed account](../history/qualification/deployment.md#server-ownership-of-station-services--2026-11-14)
records passing checks and the unresolved clean installation/UI gate.
It follows the [delivery ownership plan](transit-server-delivery-implementation.md)
and leaves the broader [Station transaction cutover](station-transaction-implementation.md)
with Milestone 6. Milestone statuses and earlier proof claims remain unchanged.

## Delivered scope and remaining qualification

The registration/current-v1 cutover, server ownership, Local/Compose/reference
migrations, and executable/publication removal are implemented. Local
applications register explicit services in their signed declaration. External
workers use `station.file`; the first authenticated manifest is frozen across
retained restart. Separate observer and lifecycle credentials preserve the
framework boundary. Provider retry still requires confirmed stop and fresh
placement supplied by the deployment.

The full clean installation/UI lane remains open because managed Table atomic
work refuses `ClockUnavailable`. Each constituent task has a separate passing
result, but that does not establish a complete clean-lane pass. The remaining runtime and release checks, including console latency, pass;
exact results belong to the linked executed account. No live migration
from an old controller, live manifest update, or new provider authority is
introduced.

## Outcome and scope

Keep `station.Controller` as the framework owner. Compose its observer and
lifecycle roles inside the `transit` executable, supervised by `transit server`
with separate credentials and one active sequencer per mutation identity.
Use the existing public client operations; the kernel, direct database and SQL
execution must acquire no Station dependency from this work.

Cover both trusted local application hosting and the external-worker server
profile used by Local, Compose and Kubernetes/Substrate launchers. Internal
subprocesses may remain separate for credential and failure containment. Their
role selection, configuration, startup, recovery and shutdown belong to the
server; there is no replacement public daemon or controller command.

Preserve ordinary application workers and `transit-runtime-controller`. The latter
reconciles Substrate placement and provider bootstrap; Station records logical
retry/stop intent through native operations. This change does not move workers
into the database, grant provider access to Station services, introduce a global
application registry, implement high availability, or replace timers with Queues.
Existing historical GHCR versions and versioned installation bundles remain
available; deleting published history is a separate administrative action.

## Responsibilities and integration gap at the planning baseline

The standalone [entry point](https://github.com/spoke-sh/transit/blob/caaf43a2b/apps/transit-station-controller/main.zig) is a
configuration, clock and polling wrapper around
[Controller](../../packages/zig/transit-station/src/Controller.zig).

| Owner | Responsibility at the planning baseline | Boundary to preserve |
| --- | --- | --- |
| Observer mode | Read durable waits and child subscriptions; send authenticated timeout and lifecycle observations | Trusted wall-clock evidence and current send/inspect/resource-read rights; workers validate the recorded observer identity |
| [Waiting](../../packages/zig/transit-station/src/Waiting.zig) | Close a wait once through reply, timeout or cancellation in admitted mailbox order | A delayed timer is not a hard expiry clock; closure cannot undo accepted peer work |
| [Supervisor](../../packages/zig/transit-station/src/Supervisor.zig) | Record child policy, bounded attempts, backoff and retry intent | Application state owns policy; a controller does not invent retries or replace retired PIDs |
| Lifecycle mode | Apply a recorded retry against the exact generation and failure record | Separate child-scoped admin/inspect identity and explicit resource grants; provider stop must be confirmed first |
| [Runtime controller](../../apps/transit-runtime-controller/README.md) | Reconcile physical placement and fresh activation | Provider state does not grant execution authority |

At the planning baseline, the server's [embedded roles](../../apps/transit-cli/RuntimeRole.zig)
and [supervision loop](../../apps/transit-cli/server/Server.zig) did not include
these Station services. The [Station launcher](../../launchers/station_example.py)
provisioned their identities, grants and watch configurations. Each controller
accepted one to four explicit watches, with no automatic realm-wide Station
discovery. Its seen cache suppressed duplicate observations but owned no durable
waiting or child state. The implemented server retains explicit watch registration
and the same framework authority boundary.

Removing publication alone would have left those deployments without timer
observations and supervised retry progress. The implementation adds server
ownership of registration, credentials and lifecycle, and migrates those consumers.

## Contract decisions before runtime changes

The owners are the [CLI/server contract](../../contracts/TRANSIT_CLI_V1.md),
[application installation contract](../../contracts/APPLICATION_INSTALLATION_V1.md),
[Station contract](../../contracts/STATION_V1.md),
[service authorization](../../contracts/SERVICE_V1.md),
[native protocol](../../contracts/TRANSIT_V1.md),
[lifecycle controls](../../contracts/LIFECYCLE_V1.md) and
[provider contract](../../contracts/RUNTIME_SUBSTRATE_V1.md).
Publish implemented behavior in their public references with each delivery slice.

### Registration and bootstrap

Define one typed registration model owned by the server installation layer.
It identifies the installation/realm, stable registration identity and revision,
mode, principal/credential reference, watched writer PID and resource, optional
child restriction and bounded polling/request settings. Configuration expresses
desired service scope; only current native grants authorize reads or actions.
Do not decode opaque application configuration to guess subscriptions.

For local installed applications, extend the existing declaration and bootstrap
contracts with explicit Station service requirements and observer bindings.
Resolve named roles/resources to their recorded native identities. Provision
service identities through the existing exact-operation journal before handlers
can create waits or child records referring to those observers. Application
workers receive identity references, never controller signing credentials.
Installing another application must register its declared services without a
manual daemon launch. Worker replacement alone cannot change service scope.

For external workers, use an explicit server configuration reference to a typed
registration manifest, accepted into the retained installation journal. The implementation uses
`station.file`, the same service validator and the same process owner as local
application registration. The launcher may
produce the manifest after native provisioning; it must not own the service loop.
The first authenticated manifest is frozen by its canonical digest in the
installation. Additions, changes and removal reject on restart. Live updates are
outside this implementation; they require a separately defined update contract.
Private credential file references remain deployment-owned and must be retained.

The reference deployment starts authority before watched PIDs/resources exist.
Preserve that bootstrap order: establish native authority, provision application
identities, accept service registrations, verify current access, then release
dependent application activation. Initial authority readiness must be distinct
from Station service readiness. Restart of an installation with accepted
registrations cannot claim those services ready while their manifest, credential
or recovery evidence is missing.

### Authority and original outcomes

Keep observer send/inspect rights separate from lifecycle admin/inspect rights;
scope lifecycle administration to the child and grant watched resource reads
explicitly. An association supplies no implicit permission. Never use the root,
courier or application-worker credential for the controller loop. Persist initial
provisioning requests and receipts once; restart checks current grants and never
restores a revoked grant.

Retain one serialized request sequence per principal. Pending requests keep their
exact signed bytes through transport uncertainty. After role loss, reconcile
current authoritative state before preparing another operation. Repeated timeout
or failure observations may be admitted after loss; the existing mailbox
transitions must still close a wait once and charge a retry once. An accepted
administrative retry is recognized through its changed generation and original
failure, not inferred from a process exit or replayed as new work.

Provider-bound retry must retain the sequence: recorded retry intent, requested
stop, confirmed stopped binding, native retry, fresh provider activation. Pending
or unknown placement, stale generations, suspension, expiry and permanent
retirement remain distinct. A service cannot manufacture readiness or restart a
retired PID to make an obligation appear fulfilled.

### Compatibility and retained installations

Keep existing Station wait/child encodings and native operations unless a concrete
contract defect requires a separate change. Extending canonical application
declarations, bootstrap or persisted installation records may still be an
incompatible change. Resolve that classification before implementation and apply
the [current-v1 cutover policy](../handbook/reference/versioning.md), including the
shared definition identifier, schemas, signing fixtures and foreign/missing
definition rejection where required. Never default an old persisted record to the
new service interpretation or bypass runtime artifact pins.

The default delivery target is a newly provisioned, matching installation plus
retained restart of that installation. Existing installations remain pinned to
their original artifacts until a supported transition is qualified. If transferring
an existing controller identity into server ownership is included, require a
recorded handoff: quiesce the old sequencer, resolve its pending operation, preserve
the observer principal referenced by durable records, validate current grants,
then activate exactly one replacement owner. Missing handoff evidence rejects;
copying keys or changing image tags is insufficient. This decision must be explicit
before removing a deployment's old service configuration.

### Bounded progress and observable readiness

Keep paged resource reads and independent cursors; restart expired read
continuations without stitching revisions. Preserve the current per-controller
watch bound initially. Bound active controllers, requests, pending operations,
scan work, retry/backoff and shutdown through explicit deployment budgets.
Growing registrations must use retained records with bounded activation; do not
turn the current four-watch limit into a global application-cardinality limit or
load all retained waits into memory.

Readiness must check current signed identity, watched-resource access and required
child inspection, including while idle. A successful access check establishes
service availability, not completed timers or an empty retry backlog. Expose
registration, readiness, last completed scan and blocked/failure state through
the existing server status/diagnostic owners, separately from durable application
outcomes. Clock failure, revoked access, unavailable storage and exhausted restart
budgets must be visible. Withdraw affected service/application readiness while
preserving the meaning of native and SQL status. Join owned work on shutdown.

## Implementation sequence

### 1 Define the registration and readiness contract

Resolve the proposed local/external registration surfaces, mutation authority,
bootstrap order, deployment budgets and compatibility/handoff policy above.
Update typed owners, generated schemas/fixtures and public explanations together.
Add rejection coverage for wrong realm/writer/resource, incompatible definitions,
duplicate registration identities, conflicting revisions and missing credentials.

**Exit:** one reviewable model explains who registers services, how workers learn
observer identities and what acceptance, readiness and failure mean in each profile.

### 2 Embed the roles and prove server ownership

Factor the small runner into a reusable module with explicit direct dependencies;
retain framework behavior in `transit-station`. Compose it through the existing
private role dispatch and supervisor. Add retained service identities, exact
provisioning/recovery records, credential-specific child execution, health checks
and finite restart/shutdown handling. Audit process capacity and admission budgets
instead of increasing a fixed array to stand in for registration lifecycle work.

Extend the installed-server proof to use one copied `transit` executable with no
sibling controller binary or usable ambient PATH. Keep application artifacts
explicit. Run real waits and supervisor failures through server-owned continuous
services; a test invoking the old controller with `--once` is insufficient.

**Exit:** both modes progress and recover under the server; startup without any
Station registrations preserves ordinary database/SQL behavior.

### 3 Move applications and deployment profiles

Migrate the local application declaration/bootstrap path and the Station example's
Local and Compose launchers. Remove independently managed observer/lifecycle
processes and artifact selections after their replacement is exercised. The server
retains local application credentials and records; external deployments retain the
manifest and referenced private credentials.

Migrate the reference launcher/chart's `stationControllers` composition into the
server registration path. Preserve `runtimeControllers`, provider credentials,
worker sandbox isolation and stop-before-retry ordering. Exercise real Substrate
placement and server/controller interruption before deleting its Station
deployments. Update launcher status, logs, restart, down and artifact-replacement
workflows to address the server-owned services without exposing private dispatch.

**Exit:** local, Compose and reference profiles run Station without a separate
Station-controller deployment, with evidence for each actual storage/placement.

### 4 Remove build and publication consumers

| Owner | Required change |
| --- | --- |
| [Runtime build](../../build/runtime.zig), [check build](../../build/checks.zig), [test tasks](../../tasks/test.just) | Delete the executable/install target, artifact context and old controller arguments; retain the embedded role module |
| [Station integration](../../tests/runtime/station/station.py), [service scenarios](../../tests/runtime/station/station_services.py) | Exercise the owned server lifecycle and preserve independent assertions; retain focused library units without a replacement public test daemon |
| [Station launcher](../../launchers/station_example.py), [local runner](../../launchers/local.py), [reference runner](../../launchers/station_reference.py), [Compose](../../examples/station-ledger/docker-compose.yaml), [local topology](../../examples/station-ledger/process-compose.yaml) | Remove service/image/binary selections and standalone restart/log paths after step 3 |
| [Reference chart](../../deploy/reference/chart/README.md), [controller templates](../../deploy/reference/chart/templates/additional-controllers.yaml), [deployment tests](../../tests/interfaces/deployment/deployments.py) | Remove Station controller workloads, obsolete values/secrets/network policies and their assertions; preserve runtime controller placement |
| [Nix runtime](../../nix/transit.nix), [release inventory](../../tasks/package_release.py) | Stop compiling and archiving the standalone executable on both supported Linux architectures |
| [Image construction](../../tasks/release_images.py), [publisher](../../tasks/publish_release.py), [channel owner](../../tasks/release_channel.py), [publication tests](../../tests/runner/test_publication.py) | Verify the reduced image inventory and promotion prerequisites; no alias image or renamed replacement |
| [Installer](../../install.sh), [release tests](../../tests/runner/test_release.py), [Homebrew generation](../../tasks/release_brew.py) | Remove only obsolete installer-owned links after successful installation; preserve old bundles, unrelated entries and failed-install rollback |
| [Standalone app](https://github.com/spoke-sh/transit/blob/caaf43a2b/apps/transit-station-controller/README.md), [components](../handbook/reference/components.md), [Station services](../../packages/zig/transit-station/docs/services.md), [build guide](../../build/README.md) | Delete the app and move live usage links to the server/service owners; preserve historical explanations with immutable source links where needed |

Audit executable creation, invocation and generated manifests, beyond string
absence. Update the [suite inventory](../../tests/runner/suite.json) and
[fast checks](../../tests/runner/checks.json) when task ownership changes. Verify
the runtime builds without test/example sources. Future archives/images must
contain no `transit-station-controller`; this does not delete past publications.

**Exit:** no current product build, deployment, test runner or publication requires
the retired executable, and all replacement lifecycle proofs still execute.

## Acceptance matrix

| Scenario | Required observation |
| --- | --- |
| Server without Station declarations | Default and headless startup, SQL and existing delivery/maintenance remain functional; no speculative application scanning |
| Fresh and later local application installation | Observer identity is bound before dependent initialization; declared services activate without a separate command |
| External staged provisioning and restart | Authority can bootstrap before watches exist; accepted service obligations survive restart and gate their own readiness |
| Timeout across worker, service and manager loss | Original correlation/deadline/observer survive; late or duplicate evidence cannot reopen a wait or invoke its callback twice |
| Failed child and backoff | Supervisor retains policy and attempt count; only recorded intent permits retry; the same failed head input is preserved |
| Lost/malformed administrative acknowledgement | Exact pending request or authoritative recovery establishes the original result; replacement never charges a second retry |
| Observer/lifecycle revocation while active or idle | Current access fails visibly; service and manager restart do not restore grants; identities cannot substitute for one another |
| Provider stop, unknown placement and stale failure | Retry waits for confirmed stop and exact generation/failure; fresh activation uses the runtime controller |
| Exhausted retries, suspension and permanent retirement | Distinct inspectable outcomes; no silent discard, automatic PID replacement or resurrection |
| Concurrent resource changes and many retained records | Complete paged scans reach records beyond the first page; stale cursors restart safely; active memory and work remain bounded |
| Clock/storage failure and admission pressure | Explicit unavailable/blocked observations and bounded retry; no expiry, skipped work or fabricated success |
| Graceful stop, SIGKILL and restart-budget exhaustion | Owned children terminate/join; original data and registration evidence remain recoverable; no competing sequencer |
| Missing, changed or incompatible registration/artifact | Startup/update rejects before dependent execution; no silent adoption, observer reassignment or empty reset |
| Release installation and image inventory | Both architecture manifests omit the artifact; the installed single executable serves real timers/retries; obsolete managed links retire safely |

## Validation and review gates

Treat steps 1–2 as the contract/server review unit, step 3 as deployment migration
units, and step 4 as final removal. Deployment work depends on the server proof;
final artifact removal depends on all supported consumers having moved. Each
intermediate change must retain executable checks for its actual inventory.

For every PR, including the plan-only PR if opened, run the required baseline
against final contents:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

For implementation, select the affected real suites through the
[task owners](../../tasks/README.md): `test::station`,
`test::server-single-executable`, `test::server`, `test::server-faults`,
`test::server-applications`, `test::server-application-faults`,
`test::runtime-upgrade`, `test::deployments`, and
`launchers::local::test-station`, `launchers::compose::test-station`,
`launchers::reference::test-station`. Preserve their failure assertions when
migrating harnesses. Contract/generated-bootstrap changes additionally require
`just check contracts` and affected binding/SDK consumers.

Server/build/startup changes require `just test console-latency-gate` in the pinned
`ci-experience` shell and `just test server-sql-types`. The predecessor delivery
plan records an unresolved aggregate latency gate on its candidate and control;
retain that evidence, rerun the required gate, and do not treat an inherited
failure as a pass or waive it when opening/updating an implementation PR.

Release changes require the static release build, `test::release`,
`test::release-install`, `test::standalone-chart`, image construction and existing
publication/installer negative controls. Check x86_64 and aarch64 inventories;
record live execution only for architectures actually exercised. Registry writes
and channel promotion are not implied by validation.

Before pushing implementation/test-infrastructure changes, run affected
`just ci clean --lane NAME` gates against committed HEAD. Initial lanes are
`core`, `installation-ui` and `launchers`; changed contracts/bootstrap may add SDK
lanes according to `suite.json`. Compose/reference/provider checks remain separate
external tasks. Missing infrastructure leaves those gates incomplete.

Record source, artifact, storage and topology identities with executed outcomes
in the owning [qualification history](../history/qualification/README.md).
Promote current service registration, credentials, readiness and recovery behavior
into the server, Station, deployment and application guides as each slice lands.
Completion requires the acceptance matrix and removal inventory to be satisfied;
it establishes neither the broader Station transaction cutover nor distributed
recovery or arbitrary controller replication.
