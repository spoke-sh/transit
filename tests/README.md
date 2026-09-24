# Validation and milestone evidence

This directory owns conformance harnesses, fault injection, test-only executors,
and proof results. Application examples live under [examples](../examples/README.md);
tests launch those real binaries rather than a separate implementation of their
logic. The [conformance design](../docs/CONFORMANCE.md) owns the required adversarial
scenarios. Results below describe the recorded bounded M1 proof, not a claim that
all commands have been rerun on every documentation change.

## Running checks

Enter `nix develop` and run `just board::install` at the repository root. `just ci` runs the ordinary local
suite. Capacity and reference proofs have extra prerequisites and are separate.

| Evidence | What it proves |
| --- | --- |
| `just check`, `just test::packages` | Independent package composition; signed requests/current grants; one conditional successor; ordered input, invalid proposals and blocked failures; runtime fencing; bounded clocks, settlement, closure and outboxes; shared valid/invalid JSON traces and bounded view encoding |
| `just test::callers`, `just contract::check` | Runnable counter and byte-log examples use the same generic node; opaque bytes, state revisions, atomic outputs, denied effects, lost commit responses, ownership replacement and restart recovery; generated schema matches public types |
| `just test::storage` | Disk WAL SIGKILL/restart; competing authorities, lost receipts and revoked grants; 100 inputs beyond the 16-record window; checkpoint/trim with pending effect/outbox/control evidence; live authority catch-up; immutable payload deletion after a lost receipt; native long-poll/offset continuation |
| `just test::service` | Real signed ingress/read revocation/key renewal, request deadlines and paused-worker fencing; Python/Zig wire vectors; actual-clock background expiry/trim; synthetic external I/O with paused dispatch, late results, unknown closure and no replay sends; background payload deletion preserving default-retention bytes |
| `just test::capacity` | Real ENOSPC on an owned ext4 image; release of preallocated control space; closed admissions, preserved/drained backlog, revocation/expiry/closure/checkpoint and restart; completed maintenance issues no further storage mutations |
| `just launchers::reference::up`, `just launchers::reference::images`, `just launchers::reference::test` | Real provider setup; controller crash after creation; backlog wakeup, killed worker and fresh activation; Ursula/authority pod restart; opted-in expiry; blocked overflow stops replacement; gVisor egress/credential bypass denials |

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

Hosted CI runs `just ci`; an opt-in dedicated runner workflow exposes the
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

The synthetic effect harness sets `NO_COLOR=1` for captured child logs so exact
error checks work under interactive and forced-color builds too. Its rejection
checks also verify the durable effect state, mailbox counts, and remote sends.

## Launcher qualification

`just launchers::local::test` and `just launchers::compose::test` exercise the
real launchers in uniquely named installations, with disk-backed Ursula and
the actual node, maintenance process, counter and Board. Both passed on Linux
x86_64. The native proof is part of `just ci`; Compose remains an explicit
Docker-dependent check. The proof checks:

- Board authentication and the inspection-only upstream principal; private
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
  Remote HTTP requires explicit development opt-in; wrong Host/Origin and
  unauthenticated reads still fail. Ursula/Transit keep loopback publication.
  Native Board must become ready in Process Compose and stay alive beyond the
  original 30-second probe-failure window.
- Native foreground startup streams service output and manager exits; a killed
  Board stays diagnosable across status calls. Other terminals can send and
  restart while `up` is attached. Ctrl-C, termination during startup, and failed
  recovery stop only the owned manager and preserve the installation's data.

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

The [bounded capacity profile](../packages/zig/transit-core/README.md#finite-admission-and-control-capacity) has a
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
The [deadline investigation](../packages/zig/transit-core/README.md#deadline-enforcement)
defines the tested acceptance-time and closure contract. A physical
storage-write cutoff at the earlier work deadline is no longer the target.

## Extending the proof

The M1 mechanisms above now have concrete implementations and adversarial
results. Extending them to general behaviors, connectors or another storage/
runtime profile requires preserving these contracts and adding its own evidence.
A failed proof requires revising the owning design, not relabeling a weaker
implementation as conformant. The client cursor-model bug and separate upstream
documentation mismatch are recorded in the [backend README](../packages/zig/transit-backend-ursula/README.md#client-integration-surface). The corrected
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
recipe. The conservative current bound
is 3,905 records (31,989,760 bytes plus a checkpoint). The 1 GiB physical reserve is
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

The [core capacity contract](../packages/zig/transit-core/README.md#finite-admission-and-control-capacity)
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

`just board::check` checks exact Zig/OpenAPI regeneration, generated TypeScript and
standalone validator drift, strict TypeScript, Vite+ formatting/lint and unit tests.
`just board::test` runs Zig ingress tests and `tests/board.py` against disk-backed
Ursula. A copy of the Board binary runs alone in an empty directory with an empty
executable search path, serving embedded assets and the exact OpenAPI artifact.
An independent Python consumer follows process/output/effect evidence; generated
JS validators consume actual Zig responses and reject malformed identities/data.

The API proof checks current grants, scoped lists and edges, unsafe deployment
principals, missing API/asset routes, Host/Origin/forwarded-header rejection,
HttpOnly cookies, key rotation, session expiry/logout, no mutation/proxy routes,
closed-unknown effects, blocked inputs, history cut/trim gaps and storage restart.
Core tests deterministically inject revocation/tail and physical-trim races.
Board projection tests reject mixed-resource pages before they could overflow
the 32-edge budget, and session-capacity tests forbid eviction to admit a new viewer.
The initial local load run (Linux x86_64, pinned tools) completed five control
writes during 25 refresh requests; the maximum observed latency was 43 ms.
Requests exceeding Board's 10 upstream reads/second admission rate were rejected.
A slow incomplete Board request also left the authority available. This is a
bounded reference measurement, not a throughput/fairness or latency guarantee.

`just board::browser-install` and `just board::browser` run pinned Chromium against
that same real binary/API. Checks cover login, typed runtime validation, nested
routes/lazy assets, arrivals/departures and uncertainty, keyboard focus through
polling, escaped payloads/lens fallback, denial/logout clearing and absence of
credentials in URLs/browser storage. Axe checks the journey against WCAG A/AA;
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

`just board::test` also asserts fixed routes, request/timeout outcomes, ignored
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
