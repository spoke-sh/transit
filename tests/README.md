# Validation and milestone evidence

This directory owns conformance harnesses, fault injection, test-only executors,
and proof results. Application examples live under [examples](../examples/README.md);
tests launch those real binaries rather than a separate implementation of their
logic. The [conformance design](../docs/CONFORMANCE.md) owns the required adversarial
scenarios. Results below describe the recorded bounded milestone profiles, not
a claim that all commands are rerun on every documentation change.

## Running checks

M7 evidence is recorded in [the state proof](#m7-state-resources). The ordinary
suite includes the public state API and real resource-backed Zig caller.

M9 proofs include `just test::arrow` (independent PyArrow validation
of Fuze IPC, including nulls, empty results and wide integers) and
`just test::client-abi` (a generated C header, real authority calls, canonical
signatures, receipt loss, fresh-host retry, revocation and malformed input).
The [Fuze integration notes](../packages/zig/transit-fuze/docs/integration.md) and
[client binding guide](../packages/zig/transit-client/docs/bindings.md) record
their limits. `just test::station` launches the real Zig Station ledger/requester
and courier, proving private state/call commits, lost receipts, fresh ownership,
worker plus store recovery, authenticated replies, scoped registry/supervision,
timers, poison-input blocking and opted-in lifetime expiry/reclamation.
The [M9 evidence](#m9-station-bindings-and-tables) below distinguishes native
language qualification from reference worker qualification.

Enter `nix develop` and run `just transit-board::install` at the repository root. `just ci` runs the ordinary local
suite. Capacity and reference proofs have extra prerequisites and are separate.

`just check` includes Board contract/validator drift and frontend formatting,
lint, types and unit tests, even for changes made only to shared Zig types or
frontend Markdown. Regenerate deliberately with `just transit-board::generate`;
use `just fmt` to fix formatting.

Before pushing committed work, run `just ci-clean`. It refuses uncommitted source
changes, clones the exact HEAD into a temporary directory, installs the locked
frontend dependencies, and runs the same core/experience/bindings task inventory as hosted CI. It inherits the
Nix store and global compiler caches, but no checkout build outputs, launcher
state, dotenv file or `node_modules`. Successful runs remove the temporary clone;
timing/completion evidence survives under `.cache/ci/clean/`;
failed runs retain it for diagnosis and print its location. The local launcher proof must use its
selected artifacts; a binary left in the developer's `zig-out` cannot mask an
undeclared dependency. Compose explicitly builds a native caller for its
host-side stale-credential check. The browser proof remains a separate
`just transit-board::browser` step, as it is in hosted CI; neither command
qualifies the separate reference or physical-capacity profiles.

Use `just ci::complete` or `just ci-clean --complete` to include Chromium in the
same invocation after `just transit-board::browser-install`. `just test::unit`
only runs library/protocol tests; `just test::build` separately compiles the
application and probe entry points formerly hidden in that unit target. Core CI
runs both and retains standalone package checks.

| Evidence | What it proves |
| --- | --- |
| `just check`, `just test::packages` | Independent package composition; signed requests/current grants; one conditional successor; ordered input, invalid proposals and blocked failures; runtime fencing; bounded clocks, settlement, closure and outboxes; shared valid/invalid JSON traces and bounded view encoding |
| `just test::callers`, `just contract::check` | Runnable counter and byte-log examples use the same generic node; opaque bytes, state revisions, atomic outputs, denied effects, lost commit responses, ownership replacement and restart recovery; generated schema matches public types |
| `just test::storage` | Disk WAL SIGKILL/restart; competing authorities, lost receipts and revoked grants; 100 inputs beyond the 16-record window; checkpoint/trim with pending effect/outbox/control evidence; live authority catch-up; immutable payload deletion after a lost receipt; native long-poll/offset continuation |
| `just test::state` | Signed KV/association reads, current independent grants, immutable read views, exact retry, two Zig caller activations, disk recovery, and clock-independent opted-in background reclamation |
| `just test::service` | Real signed ingress/read revocation/key renewal, request deadlines and paused-worker fencing; Python/Zig wire vectors; actual-clock background expiry/trim; synthetic external I/O with paused dispatch, late results, unknown closure and no replay sends; background payload deletion preserving default-retention bytes |
| `just test::capacity` | Real ENOSPC on an owned ext4 image; release of preallocated control space; closed admissions, preserved/drained backlog, revocation/expiry/closure/checkpoint and restart; completed maintenance issues no further storage mutations |
| `just test::deployments` | Rendered/linted Transit Helm chart; explicit bootstrap, existing credential references, retained/reused PVCs, private services and network policies; unsupported values fail before deployment |
| `just launchers::reference::infra-up`, `just launchers::reference::images`, `just launchers::reference::test` | Real provider setup; controller crash after creation; backlog wakeup, killed worker and fresh activation; Ursula/authority pod restart; opted-in expiry; blocked overflow stops replacement; gVisor egress/credential bypass denials |
| `just test::runtime-upgrade`, `just launchers::reference::test-launcher` | Fenced same-PID workload changes, provider response loss, complete persistent reference startup, isolated service updates and state-preserving stop/start |

The capacity proof uses a finite allocation and a measured physical reserve;
online expansion and arbitrary write amplification are not promised. Retention
policies are immutable in M1. Checkpoint/trim requires quiescent or explicitly
cancelled mailboxes; pending effect/outbox metadata survives in the checkpoint.
Payload deletion is limited to closed standalone bytes with explicit opt-in and
an unlimited-lifetime owner. Unsupported finite body/dependency contracts fail
before admission. Full compaction, live dependency graphs and backup import
remain later work.

The trusted Linux time source reports synchronization/error bounds; acceptance
uses a validated sample at the compared journal tail, not physical append time.
An authorized external send may occur after closure; its result cannot reopen
Transit. Ursula cursors are cache tokens separate from read positions. The client
model is fixed and continuation verified; the server documentation mismatch is
tracked in [Ursula #317](https://github.com/tonbo-io/ursula/issues/317). This profile
uses verified record positions/offsets and never reuses physical names.
A rolled-back whole-store backup is not an authorized live restore.

Hosted CI runs `just ci::core`, `just ci::experience` and `just ci::bindings`
in parallel, then `just ci::browser` in the experience lane. Locally, `just ci`
loads the pinned bindings tools, runs all three sequentially and records timings
in `.cache/ci/`. The
[toolchain guide](../nix/README.md#ci-lanes) explains cache ownership and the
smaller experience shell. A weekly/on-demand dedicated runner workflow exposes the
reference and physical-capacity proofs. Local runs supply the current runtime
evidence. A passing hosted end-to-end timing and native validation on the other M0
platforms still require their own runners/runs.

Integration tests use Nix-provided Python, temporary directories, and loopback
ports with their own disk Ursula; they never use an existing deployment.
Toolchain smoke checks verify binary execution and first-use Vite+ setup, not
cluster conformance. See the [command reference](../tasks/README.md) for all tasks.

On Linux, `just test::service` limits the harness and its child processes to one
available CPU. This exercises deadline cancellation without spare async workers,
including slow ingress, stalled protocol responses and maintenance storage I/O.
The affinity change is confined to the test process tree; compilation and the
parent shell retain their existing CPU allocation.

The Station ABI portion of `just bindings::native` / `just bindings::test` also
runs on one CPU on Linux, restoring affinity before the remaining language
matrix. It exercises back-to-back exact raw-client retries and Station polling
with bounded native pools. Client unit tests inject unavailable concurrency at
either scheduling slot: transient contention recovers, persistent contention
hits the original deadline, and transport failure is never retried. Those
deterministic tests run in `just test::unit` and therefore `just check`.

The synthetic effect harness sets `NO_COLOR=1` for captured child logs so exact
error checks work under interactive and forced-color builds too. Its rejection
checks also verify the durable effect state, mailbox counts, and remote sends.

## Kubernetes tooling qualification

`just test::dev-environment` proves that the shell selects the checkout-local
reference config before creation and after removal, honors an explicit override
from a subdirectory, and leaves a personal config untouched.
`just test::kubectl-transit` runs the real Zig executable against a fake kubectl
boundary, without credentials or a cluster. It checks selectors, explicit context
and kubeconfig forwarding, native JSON, invalid flags, read failures, empty and
ambiguous resources, output bounds, a hanging child after both pipes close,
and SIGINT/SIGTERM cleanup for log following and Board forwarding.
The fake child publishes its readiness PID by atomic rename after installing
signal handlers, so the parent cannot mistake an empty file for readiness.
Discovery tests cover aligned columns across namespace lengths, exact
namespace/release selection, useful empty-selection diagnostics, and rejection
of control characters or oversized human-table fields without partial output.

The plugin's [runbook](../apps/kubectl-transit/README.md) and
[full plan](../docs/roadmap/M5.md) define its inspection-only scope.
Toolchain smoke checks verify Kind and both kubectl plugins offline.

`just launchers::reference::test-plugin` passed on Linux x86_64 against the
already-running owned Kind reference. It renders the real chart with overridden
names into a uniquely created namespace, uses an inert node Deployment plus a
CoreDNS HTTP health responder in place of Board, and verifies native discovery,
status/workload views, prefixed logs, configured origin, real port-forward traffic
and listener shutdown after interruption. The fixture proves Kubernetes wiring,
not Transit read authorization or execution. Cleanup verifies the namespace
UID before deleting only test resources. Existing reference workloads are not
restarted. Plain `kubectl get nodes` and packaged `kubectl ate get workers` also
succeeded through the environment's default reference kubeconfig.

`just check`, `just doctor`, the offline proofs and chart validation passed;
`nix flake check --all-systems --no-build` evaluated all configured systems. Native
macOS execution and complete reference recovery after these tooling changes
remain separate qualification; a successful inspection is not a recovery proof.

## Launcher qualification

Stable topology lives in root [process-compose.yaml](../process-compose.yaml),
[docker-compose.yaml](../docker-compose.yaml) and
[charts/transit](../charts/transit/README.md). Integration proofs consume these
files directly; generated private files contain only installation-specific
values, service configuration and provisioning material. The reference proof
installs/upgrades the chart, including its WorkerPool and optional Board and
maintenance resources. Provider setup and adversarial fault injection stay in
the harness.

`just launchers::local::test` and `just launchers::compose::test` exercise the
real launchers in uniquely named installations, with disk-backed Ursula and
the actual node, maintenance process, counter and Board. Both passed on Linux
x86_64. The native proof is part of `just ci`; Compose remains an explicit
Docker-dependent check. The proof checks:

- Direct Board access and the inspection-only upstream principal; private
  credential files and secret-free status/log output.
- Seed inputs admitted once, same-ID send retries returning the same receipt,
  conflicting retry rejection, and resumption after a lost operator receipt.
- Pending input surviving caller replacement, same PID with a fresh generation,
  and rejection of the old caller's actual credentials.
- Full stop/start with unchanged state, realm and keys; independent storage,
  node and Board restarts; no fresh bootstrap when established WAL is missing.
- Refusal to reset running resources, adopt an occupied port or running
  installation, or reactivate a permanently retired PID.
- Reconfigure an existing Board listener/public origin without resetting its
  realm or keys; probe through the correct Host header without public DNS.
  Remote HTTP requires explicit development opt-in; wrong Host/Origin still
  fails while direct reads succeed without a Board credential. Ursula/Transit keep loopback publication.
  Native Board must become ready in Process Compose and stay alive beyond the
  original 30-second probe-failure window.
- Local and Compose foreground startup stream service output and manager/container
  exits; a killed Board stays diagnosable across status calls. Other terminals can send and
  restart while `up` is attached. Ctrl-C, termination during startup, and failed
  recovery stop only the owned services and preserve the installation's data.
  Compose also checks detached startup and that a delayed foreground cleanup
  leaves a newer replacement stack running after another terminal's `down`/`up`.

Successful proofs stop/remove only their owned resources and delete their test
state. Failed proofs preserve private evidence for inspection after cleanup.
These tests establish development workflow behavior, not Substrate isolation,
clock accuracy, finite-capacity reserves, remote Docker support, or production
deployment safety. Compose uses ordinary bridges with loopback publication;
native code runs as the developer. See [launcher limits](../launchers/README.md).

Initial checks caught premature local readiness using a previous activation's
config, Docker internal networks suppressing host port publication, private build
output permissions preventing non-root execution, and a Board config mount
colliding with its executable path. Readiness now requires fresh worker config;
images place executable files under `/bin` with explicit executable permissions.

## Incremental development and workload upgrades

The local/Compose launcher proofs also build candidates without touching running
services, verify no-op updates and selected-version restart, interrupt an apply
and resume its saved target, replace Board alone, and update the counter without
replaying committed inputs. Foreground logs remain attached across replacement.
Native candidates use a different optimization build; image candidates add a
unique image label around the real executable. This proves deployment identity
and recovery mechanics, not compatibility of arbitrary edited application code.

Core tests exercise the public `runtime_upgrade` transition: scoped grants,
stale revisions/workloads, incompatible declared code/state revisions, retirement
and the work cutoff. Pending input/turn permits/effects survive the transition;
old owners and reused worker identities cannot activate or commit. Disk tests
checkpoint and trim with an unresolved upgrade, recover it, and reconcile
provider suspension after retirement without reviving execution. The optional
binding marker is omitted when absent to preserve existing checkpoint bytes.

`just test::runtime-upgrade` uses the real node/controller with a fake provider
CLI boundary. It rejects stale controllers and replacement Actor UIDs, then
simulates a completed template switch whose response is lost. A fresh controller
observes the target without switching it again. `--check` leaves protocol and
provider state unchanged. The Nix-packaged CLI extension separately tests
UID/template/suspension validation and version conflicts.

`just launchers::reference::test-launcher` uses a newly owned namespace on the
existing reference cluster. It provisions the complete stack, changes Board
without replacing the node/Ursula/maintenance/controller pods, removes an old
Board viewer-key Secret field while preserving its Transit seed, verifies direct
inspection without a viewer credential, admits input while
the Actor is suspended, and deploys a different counter image through the real
guarded Substrate API. PID and Actor UID remain stable; worker UID and activation
generation change. The queued input commits once. Authority restart and full
application stop/start preserve state, followed by owned-resource cleanup.

Qualification found that private build contexts could give the controller's Nix
store directory mode `0700`. Image assembly now sets directory/file permissions
explicitly, and controller readiness exercises the packaged provider CLI instead
of assuming a running container is functional. Reference cleanup verifies saved
template identities before deletion; Substrate refuses to delete a nonempty
atespace. Application `down` also waits for the prior worker to disappear before
another start may request a fresh activation.

The real reference upgrade and cleanup proof passed on 2026-09-24, alongside the
local suite, Compose launcher proof and focused protocol/provider/chart proofs
on Linux x86_64. These checks do not rerun or replace the separate
M1 capacity and adversarial isolation qualification. The persistent reference
launcher uses the default Kind CNI and does not claim the additional Board
firewall confinement supplied by that isolated proof.

## Service and reference evidence

`just test::service` exercises actual signed HTTP ingress, PID-scoped reads,
key rotation/revocation, slow-body deadlines, and paused/replacement workers
against disk-backed Ursula. Authority and storage restart preserve state and
revocations. This loopback proof does not establish deployment network isolation;
see the [service profile](../contracts/SERVICE_V2.md).

`just launchers::reference::test` runs the fixed counter via the pinned Substrate gVisor
runtime on an owned Kind cluster. A controller crash after Actor creation is
reconciled without a duplicate resource; killing the real worker preserves the
PID/Actor and rotates worker identity and ownership. Ursula and authority pod
restarts preserve state, and separate maintenance expires an opted-in process.
The sandbox probe first reaches Transit, then verifies denied raw Ursula
read/write/admin access, direct IP access, CONNECT tunnelling, and Substrate and
Kubernetes APIs. Host spoofing reaches only Transit's fixed NotFound handler.
Known credential/control mounts are absent or inaccessible. These claims cover
the configured fixed images, private trusted cluster network and pinned runtime;
they do not establish arbitrary native-handler determinism or protection against
privileged administrators. Public ingress TLS and broader runtime support remain
outside this reference slice.

## Failed application turns

Caller-reported counter overflow records a blocked head input and fences its
owner. Unit tests reject failure reports that change state or emit outputs;
signed-service tests preserve pending input across restart and permit explicit
termination. The counter worker also reports malformed application bytes as a
blocked failure. Transit does not verify the caller's arithmetic or failure claim.
Runtime reconciliation uses that durable failure to stop replacement; its cluster test also checks a
stable generation after shutdown. This bounds retries of the fixed reviewed
handler; arbitrary plugin execution and general Station restart policies remain
outside this profile.

## Capacity and deletion evidence

The [bounded capacity profile](../packages/zig/transit-core/docs/authority.md#finite-admission-and-control-capacity) has a
real ext4/ENOSPC proof in `just test::capacity`. Closed admissions survive restart;
accepted input is preserved, and releasing only a preallocated reserve enables
revocation, opted-in expiry, unknown closure, backlog completion and checkpoint/
trim. The recorded bounds and measured amplification apply to the specified
single-node fixture, not arbitrary disk writers, topologies or unlimited faults.

Immutable standalone payload tests add whole-stream deletion through the pinned
client. Owner/PID and current grants fence retirement; publication, explicit
deletion opt-in and permanent owner retirement are prerequisites. Disk restart
after DELETE but before outcome recording recovers from a tombstone in the
separate control checkpoint. Background service maintenance completes deletion
while preserving default-retention bytes. Late publication cannot reopen a
retired payload. This profile rejects finite owners and live dependencies;
unresolved creation cannot be mistaken for safe deletion or retried blindly.

## Authority, effects, and outbox evidence

Implemented evidence: `just test::unit` exercises request signatures, realm/PID grants,
key replacement, retry identity, ownership, stale state revisions, ordered input, and
retirement. `just test::storage` repeats competing transitions, revocation, lost
receipts, and replay across a real Ursula SIGKILL/restart, with a 100-message
backlog and a 16-record read window. Application logic is absent from the
authority and its replay path.
Further SIGKILL boundaries exercise checkpoint publication before trim, retried
trim, and recovery after prefix removal with new pending input in the tail.
Effect tests additionally prove intent validation, revocation racing dispatch,
authenticated observations, and one mailbox admission per result. Disk restart
and prefix removal preserve unknown attempts; late evidence after caller
termination cannot revive application execution. No external I/O is invoked.
The separate service proof now adds actual I/O through a trusted Zig synthetic
executor: successful result admission, pause after authorization, late response,
and executor death after remote acceptance. A fixture records exactly four
requests across these schedules; fresh executors and checkpoint/trim/restart
cause no additional sends. Closed attempts reject late outcomes, including when
the authorized executor starts its request after closure. This demonstrates the
external limit, not remote cancellation or a general HTTP connector.
Closure tests exercise both winners of the result/closure race, lost
acknowledgements, and unauthorized closure. Real disk restart and trim preserve
closed unknown outcomes and reject late observations even while the caller lives.
Outbox tests cover ordered routes, partial fan-out, denied/expired destinations,
revocation racing delivery, and cancellation of undelivered outputs. Disk restart
and prefix removal preserve pending payloads; a lost delivery receipt cannot
admit the same output twice. Replay verifies explicit admission metadata so
denied deliveries cannot masquerade as mailbox messages.
These are local single-node results, not the Kubernetes/Substrate isolation proof.

## Time and maintenance evidence

The time interface and finite-policy transitions now have executable proofs:
missing/uncertain time, rollback, delayed maintenance, permit recovery, deadline
closure, and observation-budget exhaustion. A disk-backed fixture settles a
preauthorized turn after its work cutoff, then expires its PID and trims history;
restart preserves both retirement and the time high-water mark. Time is controlled
in this fixture. `just test::service` additionally exercises Linux's synchronized
clock and a separate maintenance process: opted-in expiry, explicit cancellation
of unfinished input, checkpoint/trim while ingress remains live, and permanent
retirement after authority/storage restart. It requires the host clock to report
an error bound within two seconds; the fixture explicitly permits that bound
because a synchronized host can exceed one second between NTP polls. Controlled
clock tests retain exact rejection boundaries. Other platforms exercise explicit
retirement and cleanup without claiming a supported finite-time source.
The [deadline investigation](../packages/zig/transit-core/docs/authority.md#deadline-enforcement)
defines the tested acceptance-time and closure contract. A physical
storage-write cutoff at the earlier work deadline is no longer the target.

## Extending the proof

The M1 mechanisms above now have concrete implementations and adversarial
results. Extending them to general behaviors, connectors or another storage/
runtime profile requires preserving these contracts and adding its own evidence.
A failed proof requires revising the owning design, not relabeling a weaker
implementation as conformant. The client cursor-model bug and separate upstream
documentation mismatch are recorded in the [backend README](../packages/zig/transit-backend-ursula/docs/upstream.md#client-integration-surface). The corrected
client proof verifies offset-plus-cursor and record-plus-cursor continuation;
Transit's journal reads use record positions.

## Independent caller evidence

`just test::callers` launches the actual `example-counter` and `example-byte-log`
binaries, each importing only `transit-client`. Application-independent Zig
probes perform rejected proposals and state assertions; Python injects faults.
The counter is shared with the service and reference proofs. No test driver
executes a separate copy of application logic.
The same node binary accepts both, records opaque state and atomic outputs,
rejects stale revisions/skipped inputs/unauthorized effects, and recovers through
authority and disk Ursula restart. A proxy drops successful commit responses and
injects malformed unavailable responses on reads and commit retries;
retrying the identical pending request returns the original receipt. Replaced
activations fail locally and at signed ingress. Recovery verification does not
execute either application. `just contract::check` checks that the committed
binding schema exactly matches the public types; shared fixtures check signing.

## Physical capacity profile

The capacity proof requires Linux Docker with privileged-container support and
at least 2 GiB of free disk for its temporary regular image file. It uses pinned
Nix filesystem tools and the official Ursula image; it formats no host block
device. Its mount/loop device belongs to the owned container, which is removed
after the proof. It runs in the opt-in reference CI workflow, not hosted `just ci`.

`just test::capacity` proves the `N=256` profile against the pinned official
Ursula image on an owned 2 GiB ext4 filesystem, with a physically allocated
1 GiB reserve file. It fills only that filesystem, observes real `ENOSPC` and
Ursula's disk-pressure write rejection, and releases only the reserve. The filler
stays in place while Transit revokes a grant, expires an opted-in PID, closes an
unknown attempt, drains the unlimited PID's accepted backlog, and checkpoints
and trims. SIGKILL/restart preserves retirement, closure, and closed admissions.

The fixture uses 251 post-ceiling records. The v2 run grew WAL allocation by
176,128 bytes during control recovery; current measurements are emitted by the
recipe. The conservative bound
was 3,905 records (31,989,760 bytes plus a checkpoint) in M1;
the [M8 proof](#m8-runtime-readiness) records the current expanded bound. The 1 GiB physical reserve is
a tested envelope for this configuration/schedule, not a universal filesystem
or Ursula write-amplification guarantee. The fixture asserts control growth
stays below 128 MiB and free space remains above the 32 MiB resume threshold.
Keep one maintenance writer and bounded authority concurrency; unbounded crash
loops, unrelated disk writers, disk loss, other topologies and larger allocations
need separate qualification. An absent/exhausted reserve fails closed and needs
operator capacity recovery; it does not create expiry permission.

Completed maintenance now verifies the existing checkpoint/floor before writing.
After restart the adapter uses only GET/HEAD for that already completed intent;
it does not repeatedly publish or trim. Ursula can still change its internal WAL
during reads/recovery, so raw WAL equality is not a valid no-mutation assertion.
The fixture records adapter HTTP methods and stores measurements in the ignored
`.cache/capacity-evidence.json`.

The [core capacity contract](../packages/zig/transit-core/docs/authority.md#finite-admission-and-control-capacity)
defines the admission ceiling, permitted drain work, and accepted-record bound.

## Recording new evidence

Record tested pins, topology, failure boundary, authoritative operation point,
input schedule, and durable outcomes. A workflow definition is not evidence of
a remote run. The [reference runbook](../deploy/reference/README.md) records its
runner requirements and owned-resource cleanup. Keep synthetic endpoints, test
keys, transcripts, and private proof files out of Git.

Benchmarks record compiler/tool versions, hardware, dataset, concurrency,
durability settings, and p50/p95/p99 latency together with throughput and memory.
A failed proof requires revising the owning design, not weakening its label.

## Public inspection

`just test::inspection` checks scoped discovery, signed queries, fixed pages, cut
expiry, revocation, and disk recovery through the node and public client. Core
unit tests inject final-tail and trim races, test bounded sparse scans, and verify
that scoped outbox/history projections do not disclose hidden endpoints.

## Board qualification

`just transit-board::check` checks exact Zig/OpenAPI regeneration, generated TypeScript and
standalone validator drift, strict TypeScript, Vite+ formatting/lint and unit tests.
`just transit-board::test` runs Zig ingress tests and `tests/board.py` against disk-backed
Ursula. A copy of the Board binary runs alone in an empty directory with an empty
executable search path, serving embedded assets and the exact OpenAPI artifact.
An independent Python consumer follows process/output/effect evidence; generated
JS validators consume actual Zig responses and reject malformed identities/data.

The API proof checks current grants, scoped lists and edges, unsafe deployment
principals, missing API/asset routes, Host/Origin/forwarded-header rejection,
direct reads without viewer credentials, no cookies or session/mutation/proxy routes,
closed-unknown effects, blocked inputs, history cut/trim gaps and storage restart.
Core tests deterministically inject revocation/tail and physical-trim races.
Board projection tests reject mixed-resource pages before they could overflow
the 32-edge budget. Revoked Transit grants reject reads even with old Board
cookies or arbitrary bearer headers; these headers stay out of diagnostics.
The initial local load run (Linux x86_64, pinned tools) completed five control
writes during 25 refresh requests; the maximum observed latency was 43 ms.
Requests exceeding Board's 10 upstream reads/second admission rate were rejected.
A slow incomplete Board request also left the authority available. This is a
bounded reference measurement, not a throughput/fairness or latency guarantee.

`just transit-board::browser-install` and `just transit-board::browser` run pinned Chromium against
that same real binary/API. Checks cover direct access, typed runtime validation, nested
routes/lazy assets, arrivals/departures and uncertainty, keyboard focus through
polling, escaped opaque payloads and authorized state-resource views, denial clearing and connection retry,
and absence of Board cookies or browser storage. Axe checks the journey against WCAG A/AA;
this does not replace a full assistive-technology audit. Local screenshots/traces
remain ignored under `.cache/`. Remote TLS termination and identity federation
are outside this private/loopback profile.

The Kubernetes/Substrate run on 2026-09-23 passed using the pinned images/tools.
Board observed PID 1 at generation 2, then the same PID at generation 4 with a
new worker incarnation. After disk Ursula and node replacement it still exposed
state `1153`; it also exposed permanently expired PID 48. Retained history began
at position 52 after checkpoint/physical trim; inspection reported
`prefix_reclaimed`, and later PID 1 termination remained visible. This preserved
the existing M1 controller-crash, worker-recovery, expiry and gVisor isolation
proof. Local evidence is in ignored `.cache/reference/proof-d585cab0/evidence.json`;
its enclosing directory contains private disposable keys and must not be published.

Board ran as a non-root, read-only-filesystem pod without a service-account token,
using only a dedicated inspect grant. A second unprivileged container in that
pod's network namespace first reached Transit, then received transport denials
for raw Ursula service/pod/admin endpoints and actual Substrate/Kubernetes API
addresses. The default Kind CNI does not enforce NetworkPolicy: the owned proof
uses an init-container firewall, permitting Transit, DNS and loopback Board
port-forwarding. Production clusters need equivalent enforced egress policy;
the fixture is not a portable NetworkPolicy conformance claim. The cluster and
registry were removed through the ownership-checking teardown command.

Qualification caught and corrected three assumptions: HTTP header views cannot
be accessed after Zig's body reader changes state; Kubernetes port-forwarding
needs a loopback exception inside the confined pod; and Substrate's headless API
service must resolve to a ready EndpointSlice address for a valid denial probe.
The probe rejects DNS errors/timeouts as evidence of egress denial, so an invalid
target cannot produce a passing isolation result.

## Service instrumentation qualification

`just test::telemetry` tests the real bounded stderr writer on one CPU (Linux):
10,000 completions with logging disabled, drained, stalled and closed pipes.
Every completion reaches local metrics despite log drops; stdout remains JSON.
The initial debug build measured 0.12–0.42 seconds total per scenario, including
100 ms of deliberate wait and up to 200 ms flushing; emission was 9–74 ms.
These are measured proof results, not throughput targets or arbitrary I/O guarantees.

`just transit-board::test` also asserts fixed routes, request/timeout outcomes, ignored
public trace headers, quiet successful probes and credential/query redaction in
real service logs. See [telemetry](../packages/zig/telemetry/README.md) for limits.

`just test::observability` follows a real Board request through the public client
and node, checking distinct correlated spans, existing receipt retries, revoked
reads, duplicate/untrusted trace headers and absence of credentials/state.
No raw storage dependency is introduced into Board and no durable schema changes.

Storage/recovery spans are checked as children of the actual authority request.
The existing disk, service, maintenance and caller proofs run with instrumentation
active. Maintenance deadline checks inspect the structured error field. The
bootstrap proof separates stdout and stderr to verify the machine interface,
while the provider reader continues to identify bootstrap records in combined logs.
The stalled-writer proof shrinks its Linux pipe to 4 KiB and asserts the writer
is actually blocked before shutdown; it cannot pass merely by fitting all logs
into the OS buffer.

The observability proof also runs the real node on one CPU with unread stderr:
after filling its 4 KiB pipe, an incomplete HTTP request still hits the 800 ms
deadline, and a signed input plus exact retry still returns one durable receipt.
This qualifies control progress under diagnostic pressure, not just logger exit.
Replay and retries are observed as recovery or receipts; no metric claims they
are fresh commits. No protocol, signature, or durable-history schema changed.
The caller proxy proof drops a response after a real commit, then injects a
malformed 503. Both attempts remain `uncertain`; only the exact successful retry
reports `receipt`. Each attempt has a distinct span linked to the same proposal.
A focused invariant test preserves a known receipt when the response write fails
and checks that a new service instance resets its local counters.

`just launchers::local::test` and `just launchers::compose::test` passed with JSON
request records and saved per-service settings across restart. The native proof
checks visible foreground Board logs, manager-log rotation through three cycles,
two bounded backups and configured child-log rotation. Compose checks each
service's environment and Docker log budget. Native copy/truncate can lose
diagnostics and overshoot between checks; it is not a filesystem quota.

The Kubernetes/Substrate observability run passed the existing controller-crash,
worker replacement, disk Ursula/authority recovery, expiry and isolation proof.
It also checked JSON events from Board, Transit, maintenance and the controller,
and the effective kubelet rotation settings (5 MiB, three files). Evidence is
in ignored `.cache/reference/proof-7f71fb4c/evidence.json`; its enclosing directory
contains private test keys. Provider-owned log/snapshot stores and host proof
files are outside the CRI log budget.

Qualification exposed a packaging assumption: a Zig artifact reused from a
private launcher cache can have mode `0700`. Reference image assembly now sets
published executable modes explicitly to `0755`, so the non-root container user
can execute them. The controller-crash fixture now waits for the structured
`created` progress observation; continuous controller stdout is no longer used
as a diagnostic interface. `--once` retains its single machine-readable result.

## M7 state resources

The bounded [state v1 profile](../contracts/STATE_V1.md) is qualified through
`just ci`, `just transit-board::browser`, `just launchers::compose::test` and
`just launchers::reference::test-launcher` on x86_64 Linux (2026-09-24).
`just test::capacity` also passes with the expanded 3,917-record control reserve: real
ENOSPC, control progress, checkpoint/trim and disk restart. Focused
state, unit and disk proofs were rerun after final authorization/recovery fixes.

Coverage includes:

- Core adversarial tests: atomic mutations/input/outputs/effects; uncertain
  receipts and competing revisions; stale ownership; association CAS; writer
  exclusivity and shared snapshot reads; hidden metadata/value permissions;
  revocation before commits, reads and receipt disclosure; required/optional
  expiry; full read-view capacity and reserved retirement/reclamation progress.
- [state.zig](state.zig), included in `just test::storage`: real disk Ursula,
  competing conditional appends, abandoned private preparations, lost receipts,
  SIGKILL/restart, durable view recovery, checkpoint publication/trim, and 32 live
  keys beyond the eight-entry page and 16-record replay buffer. It preserves
  unchanged values, deletes/recreates a key, permanently retires required
  dependents and reclaims opted-in data. Receipt permissions survive checkpoint
  recovery even after their view-opening records are trimmed.
- [state_api.py](state_api.py), `just test::state`: the real HTTP/CLI boundary and
  counter executable; metadata/value grants, exact view revisions, pagination,
  changed cuts, state retention across two activations and unchanged legacy
  inline bytes. A clockless realm proves zero-age opted-in background cleanup
  and maintainer restart without rediscovering or resurrecting removed data.
- Board service/browser proofs: no application lens/configuration/API field;
  generic resource and association pages, explicit hex entry reads, independent
  disclosure permissions and filtered relationships. Existing effect, journey,
  stale-observation, safe-rendering and accessibility checks continue to pass.
- Local, Compose and reference launcher proofs: new installations provision a
  required KV resource; worker replacement, compatible same-PID upgrades, queued
  inputs, authority/storage recovery and stop/start preserve its data. Existing
  manifests retain inline-state behavior; this is not an automatic migration.

On the pinned x86_64 Linux Debug profile, fixed structure sizes are 158,560 bytes
for the complete catalog (four resources, four captured views and receipt rights),
364,848 bytes for core state, 17,224 bytes for one captured view, 7,800 bytes for
one public state page and 67,688 bytes for the Ursula replay store. These are
layout measurements, not total RSS or throughput claims. Parsing, candidate
copies and serialized I/O need additional bounded memory. Maximum record and
checkpoint tests retain the 8 KiB / 1 MiB limits.

The first larger catalog exhausted Debug stack frames in checkpoint verification.
The selected profile remains four resource identities / 32 live keys each;
large checkpoint fields now parse into allocated storage and the backend returns
an owned parsed checkpoint. The service and storage recovery proofs exercise
that path with default stack sizes. No stack-limit override hides the failure.
Simultaneous launcher builds also exposed shared frontend-output deletion;
embedded Board builds now use separate temporary output directories.

M7 does not prove an unbounded KV index, per-key TTL, writer transfer, multiple
resources in one transaction, online migration, arbitrary native determinism,
or global distributed transactions. History trimming still requires quiescent
or explicitly cancelled mailboxes and every resource's opt-in/minimum age.
Resource identity/tombstone evidence is retained permanently within the bounded
realm profile. Expiry can make data unavailable while unlimited history keeps
its bytes; it never promises erasure of external copies.

## M8 runtime readiness

M8 supplies the generic runtime prerequisites for Station. Qualification passed
on x86_64 Linux on 2026-09-24 with the pinned toolchain, including the full CI,
browser, physical-capacity, three-launcher and Substrate isolation suites. Focused
controller/caller checks and foundation checks were rerun after the recovery fixes.
Its contracts are
[authenticated inputs](../contracts/TRANSIT_V2.md),
[scoped delivery](../contracts/SERVICE_V2.md),
[catalog collection](../contracts/CATALOG_V1.md) and
[lifecycle controls](../contracts/LIFECYCLE_V1.md).

| Proof | Evidence and command |
| --- | --- |
| Authenticated origin | Core checks authority-derived external/process/effect envelopes, replay mutation rejection and retained origin after collection. Shared `inputs-v1.json` and canonical signed command fixtures are validated by `just check`. |
| Actual caller exchange | `just test::callers` runs the counter and byte-log executables with `transit-delivery`, drops/malforms acknowledgements, checks exact retries and restarts the courier. Scoped delivery reads expose counts/sequence, not application payload. Core tests cover destination scope, revocation and terminal denial. Delayed counter activation stays within the bootstrap log bound even at debug verbosity. |
| Sustained working catalogs | Unit and disk proofs allocate 257 outputs/effects and 65 process/resource identities while collecting eligible entries, exceeding the previous lifetime ceilings. Pending outputs, uncertain attempts, live dependencies and default unlimited retention remain protected; old IDs/results/owners cannot revive. |
| Lifecycle recovery | Core tests cover lost creation/resource acknowledgements, missing required associations, scoped administration, exact failed-input retry, stale generations, suspension bounds and provider-stop/activation fencing. `tests/readiness.zig` restarts during initialization, completes it after recovery, checkpoints a blocked input, retries that head and expires a suspended process after trim/recovery. |
| Disk/capacity | `just test::storage` runs readiness with disk Ursula, SIGKILL, checkpoint and prefix trim. `just test::capacity` fills an owned ext4 image: at admission ceiling 256, the reserve bound is **4385 records**, with control progress and restart verified. This replaces the pre-M8 reserve estimate for the current binary. |
| Deployment | `tests/readiness_client.zig` imports the public client only. Local, Compose and reference launcher tests run it against real services: queue an output while delivery is stopped, restart courier and node, reject an identical externally submitted forged reply, accept the process-origin reply and inspect generic Board evidence. The harness never delivers that output. Reference qualification also queues input
during a bounded logical suspension, confirms provider stop, replaces worker
capacity and resumes the same PID/Actor with a fresh activation. Automatic pool
recycling is outside the controller's current rights and this proof. |
| Inspection | Core history queries preserve retained events for collected PIDs without inventing mailbox disposition. Board exposes lifecycle actions, initialization/suspension bounds and a collection warning. Generated OpenAPI/validators, API tests and the real browser suite check the shared surface. |

Run `just ci`, `just transit-board::browser`, `just test::capacity`,
`just launchers::compose::test` and `just launchers::reference::test-launcher`.
The existing `just launchers::reference::images` / `just launchers::reference::test`
proof additionally checks controller/worker loss, persistent authority/storage
restart, expiry, poison-input shutdown and actual sandbox/Board bypass rejection.
Its diagnostic check covers every remaining signing seed after removal of Board
viewer keys. Pod readiness is distinct from host-forward availability; the Zig
readiness caller retries unavailable reads without treating them as progress.
Launcher qualification uses separately owned installations and retains failure
evidence; it must not upgrade a developer's existing live realm implicitly.

The measured disk-proof structures on x86_64 Linux are: state catalog 158560 bytes,
core state 433472 bytes, captured view 17224 bytes, state page 7800 bytes and backend
store 68968 bytes. These are type sizes, not total process RSS. Catalog capacities
remain 64 concurrent processes, 128 effects, 256 outputs, four resources, four
views and 16 principals. Collection is opt-in; unlimited default history can grow
on disk. Automatic collection conservatively waits for delivered inputs to be
consumed; explicit collection can prove a retained self-contained origin earlier.
Whole-realm checkpoints require quiescence. No production throughput, recovery-time,
HA, distributed retention or principal reclamation claim follows from these proofs.
Station owns durable wait/correlation layouts, child policies, timers,
lifecycle watches, restart budgets and versioned framework descriptors.

## M9 Station, bindings and Tables

The final implementation at `1462041` passed `just ci-clean` with no inherited
checkout build outputs. All target languages passed in that run. Embedded Board
passed its five Chromium checks; the Station local, Compose and Substrate
profiles passed their separate recovery/upgrade proofs. `just doctor` and
Actionlint also passed. This records local qualification, not a hosted CI speed
measurement or validation of other operating systems/architectures.

The Linux x86_64 profile uses the locked Zig 0.17 compiler, the pinned
`rupurt/zarrow` and `rupurt/zarrow-compute` forks, disk Ursula, and the real public
authority/courier. Framework logic remains in Zig; no language-specific server
route or second authoritative task/state store is introduced.

| Proof | Evidence |
| --- | --- |
| `just test::station` | Three behavior roles, two-Table atomic turns, exact retry after receipt loss, worker/store restart, source-authenticated calls/replies, captured Arrow publication/consumer restart, service-policy revocation, registry rebind with the original PID retained, timed waits/late-result closure, poison-head supervision and independent lifecycle control |
| `just test::station` lifetime schedule | Required PID-owned Table state survives recovery; suspension beyond a dependency is rejected; opted-in expiry permanently rejects activation and permits background reclamation, including after authority restart |
| `just bindings::native` | C/C++/Python real callers; shared ABI exact frozen request recovery after every handle is lost; failed-turn rollback, stale/revoked/retired callers, wide correlations, malformed native-port input, asynchronous cancellation and owned cleanup |
| `just bindings::native` materialization schedule | Duplicate source admission/commit, update/delete, physical checkpoint/trim, reinsertion in the tail, disk/node restart and an independent Arrow aggregate over only current rows |
| `nix develop .#bindings --command just bindings::test` | C, C++, Rust, Python, Node, Java, .NET, Erlang and Elixir each run service and requester roles across language pairs; fresh hosts resume captured results; exact `9007199254740993` values survive Arrow; managed/port tests cover bounded input, busy handles, host/caller loss, responsive schedulers and cancellation/cleanup |
| `just test::unit`, `just test::packages`, `just test::arrow` | Private batch rollback, capacity and schema checks, all admitted Arrow types/null/empty/overflow behavior, C Data/C Stream release ownership, exact source basis and no enabled rewrites, cancelled queries, maximum 672-byte captured reply, malformed/duplicate/missing fragments and no prefix completion |
| `just transit-board::test`, `just transit-board::browser` | Versioned framework metadata with source PID/resource/key/revisions; unknown versions fall back safely; no application-state decoder |
| `just launchers::local::test-station`, `just launchers::compose::test-station`, `just launchers::reference::test-station` | Same three-process scenario, scoped service roles, registry/call/Arrow exchange, Board provenance, worker recovery, compatible upgrades of all three workers with PIDs/state retained, no-op updates and persistent stop/start |

The reference proof additionally kills an actual Substrate worker pod, verifies
a fresh activation/key while retaining the Actor UID, and upgrades versioned
worker templates through the recorded protocol. It uses the shared Helm chart
with three separate PID-scoped runtime controllers and two framework controllers.
Failed launcher runs retain their own installation; successful ones remove only
their own application resources. The shared infrastructure is not destroyed.

The ordinary CI inventory includes the local Station proof and full language
matrix. Docker Compose and reference proofs require Docker/the provider fixture
and run in the opt-in reference workflow or as explicit qualification commands.
No hosted run-time improvement is
claimed from local measurements; the CI lanes report their individual task times.

Qualification is deliberately finite: four realm resources, 32 entries per
resource, four mutations/outputs per turn, one mutated resource and at most
672 captured IPC bytes. Execution pulls one synchronous batch into bounded
buffers; it has no queued pipeline or parallel in-flight operators. Slow remote
consumption is durable mailbox/result state, not a live Arrow task. No optimizer
rewrite is enabled. Unlimited retention is the default and does not evict old
waits/results when capacity fills. See the [Table guide](../packages/zig/transit-station/docs/tables.md).

Only Zig workers are qualified on Substrate. Client support does not establish
foreign-VM isolation, public SDK releases or non-Linux portability. Logical
supervisor retry also cannot guarantee fresh provider placement; the
[example runbook](../examples/station-ledger/docs/running.md#recovery-and-incremental-work)
records the required operator recovery when Substrate reuses an old pod.
Continuous queries, multi-resource transactions, SQL, Documents and remote
Flight/ADBC remain later milestones.

## M10 verification and scale foundations

The [verification guide](verification/README.md) owns the versioned inventory,
bound audit and generated transition harness. `just test::properties` checks the
real Zig authority against an independent mailbox/fencing/retry projection,
including replay after every step and bounded failure minimization. The initial
21-trace corpus/generation run passed 826 boundaries in 8.46 seconds on this host.
That measures the harness, not service throughput or exhaustive exploration.

M10 is in progress. The first CI changes separate library unit tests from
application/probe builds, avoid duplicate feature-push/PR runs, and select
runtime checks conservatively. `tests/ci_runner.py` exercises actual Git rename/
delete selection, missing revisions, failure propagation and all combinations
of aggregate-gate results. Unknown/shared changes remain full; only foundational
prose-only PRs omit runtime lanes. Main, release tags and merge queues run full.

`just ci::complete` includes Chromium, and `just ci-clean --complete` uses that
inventory on committed HEAD. Each lane records required tasks, completion and
revision beside task timings; successful clean runs preserve these outside the
disposable checkout. These improvements do not establish a hosted speed target,
complete the growing-state implementation or qualify massive scale.

The initial M10 model also passed 30,140 states with a four-transition journal
bound and replayed all four removed-guard counterexamples against Zig. The first
CI optimization commit (`b9dd595`) passed `just ci-clean --complete`, including
all language bindings and five Chromium checks; timing and completion metadata
survive under `.cache/ci/clean/b9dd595faade-transit-ci-7c3pzmzd/`.

`just test::pages` qualifies the immutable page primitive with disk-backed Ursula,
cold bounded caches, old roots, unpublished staging and root-only checkpoint/trim.
The [adapter guide](../packages/zig/transit-backend-ursula/docs/pages.md) describes
measurement fields and their limits. These roots do not yet replace the running
authority's bounded catalogs. Unit checks also compare randomly ordered updates
and deletion against an independent map and preserve old roots after lost staging
acknowledgements.

The initial [growing authority tests](../packages/zig/transit-core/docs/growing.md)
also cross the legacy process/principal catalogs and retain historical receipts
in immutable pages. They qualify the implemented control transitions against an
injected conditional journal, including lost acknowledgements and stale prepared
roots. State checks also publish rows, input progress and outputs together,
reject staged partial proposals and fence expired required dependencies. Signed
read checks cover bounded current/captured pages, current permissions, stale
ownership/cuts, expiry and hidden association filtering. These engine checks
use injected storage; delivery/settlement, service/client/Station integration and
control reserves still need evidence. The running system continues to use v2.
