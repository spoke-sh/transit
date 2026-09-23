# Roadmap

Status: Transit-first plan. Milestones are ordered by dependency, not calendar
commitments. The bounded M1 reference profile is implemented and verified;
checked items are supported by the commands and limits below. M2 is next.

## M0 — Foundations

Scope: repository guidance, planning, and pinned development tools.

- [x] README, agent guidance, scope, architecture, and technical design documents.
- [x] Nix shell with just, Zig 0.17 master, Vite+, Ursula, and `ursulactl`.
- [x] Kubernetes tools in the shell: `kubectl`, `k9s`, and Linux-only `k3s`.
- [x] Select `ursula-zig`, the kernel/framework boundary, and Kubernetes/Substrate
  as the reference deployment architecture.
- [x] Name Transit and Station, establish the glossary, and plan library/executable
  decomposition without scaffolding packages.
- [x] Establish processes/PIDs beneath GenServer, scoped name registries, and
  the durable runtime-binding boundary with Substrate.
- [x] Define application opt-in retention, coupled process/mailbox lifetimes,
  and the distinction between logical expiry, compaction, and reclamation.
- [x] Assign authentication/authorization and trust boundaries; identify
  adversarial conformance scenarios and unresolved M1 design gates.
- [ ] Verify shell and foundation commands on every declared target platform.

The shell and offline smoke check pass on `x86_64-linux`. All four configured
systems evaluate; native builds on aarch64 Linux and both macOS architectures
still need runners. These are tooling checks, not kernel conformance evidence.

## M1 — Transit sequence enforcement and Kubernetes recovery

Scope: one minimal Transit process with a durable mailbox, running in the reference
Kubernetes environment. Prove the kernel's protocol before building applications.

### Design gates before expanding the slice

M1 is proof work as well as implementation. Start with one security realm,
explicit test/service principals, minimal grants, fixed workload code, and a
synthetic effect executor. Keep Kubernetes/Substrate and worker failure within
M1; this boundary does not defer them to a later milestone.

| Gate | Decision and evidence required |
| --- | --- |
| Durable authority | Select framing, authoritative reads, conditional append/coordination, and recovery of uncertain operations; prove one accepted successor despite competing authorities |
| Identity and policy | Select credential validation, principal/realm mapping, grant representation, and revocation ordering; prove impersonation and stale-policy rejection |
| Handler execution | Select the isolation/determinism mechanism and resource limits; state which code is trusted and prove the advertised enforcement |
| Time and dispatch | Define work cutoffs, bounded settlement/reconciliation, clock error bounds, and acceptance/closure ordering; prove late-result rejection without claiming cancellation of possibly in-flight work |
| Bootstrap and capacity | Define realm/control catalog recovery, idempotent spawn, and reserved control/maintenance capacity under full-store conditions |

Do not build Station or real external-effect integrations on an unproved gate.
Track evidence using [CONFORMANCE.md](CONFORMANCE.md); documentation agreement
does not mark these gates complete.

### Exit criteria

The supported M1 profile is intentionally small: one realm, reviewed scalar
workload, bounded catalogs, one-node disk-backed Ursula, and the pinned
Linux/Kind/Substrate gVisor reference. The [protocol](../contracts/TRANSIT_V1.md),
[service](../contracts/SERVICE_V1.md), and [runtime](../contracts/RUNTIME_SUBSTRATE_V1.md)
profiles define the exact contracts and limits. Requirements below are satisfied
within that profile, not for arbitrary native handlers, public ingress or
multi-node storage.

| Evidence | What it proves |
| --- | --- |
| `just check`, `just test-packages` | Independent package composition; signed requests/current grants; one conditional successor; ordered input, invalid proposals and blocked failures; runtime fencing; bounded clocks, settlement, closure and outboxes; shared valid/invalid JSON traces and bounded view encoding |
| `just test-storage` | Disk WAL SIGKILL/restart; competing authorities, lost receipts and revoked grants; 100 inputs beyond the 16-record window; checkpoint/trim with pending effect/outbox/control evidence; live authority catch-up; immutable payload deletion after a lost receipt; native long-poll/offset continuation |
| `just test-service` | Real signed ingress/read revocation/key renewal, request deadlines and paused-worker fencing; Python/Zig wire vectors; actual-clock background expiry/trim; synthetic external I/O with paused dispatch, late results, unknown closure and no replay sends; background payload deletion preserving default-retention bytes |
| `just test-capacity` | Real ENOSPC on an owned ext4 image; release of preallocated control space; closed admissions, preserved/drained backlog, revocation/expiry/closure/checkpoint and restart; completed maintenance issues no further storage mutations |
| `just reference-up`, `just reference-images`, `just reference-test` | Real provider setup; controller crash after creation; backlog wakeup, killed worker and fresh activation; Ursula/authority pod restart; opted-in expiry; blocked overflow stops replacement; gVisor egress/credential bypass denials |

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

- [x] Introduce the Transit library, Ursula adapter, and minimum executable
  composition from the [decomposition plan](ARCHITECTURE.md#planned-monorepo-decomposition),
  with direct package dependencies and focused/root build checks.
- [x] Define versioned records and valid/invalid sequence fixtures covering
  scoped PIDs, lifecycle, admission, activation ownership, turn commits, and
  effect authorization.
- [x] Authenticate ingress, workers, and controllers; enforce action/resource
  grants and current read permissions. Prove forged principal/PID/realm rejection,
  revoked grants, credential renewal, and authenticated attempt observations.
- [x] Recover realm genesis, policy state, and the control catalog before
  application activation. Prove idempotent spawn across lost acknowledgements
  without depending on the Station registry or recreating missing history.
- [x] Prove that worker recovery preserves a PID/mailbox and logical termination
  retires the PID permanently. Define pending-work disposition and prove that
  spawning a replacement cannot silently inherit accepted messages or effects.
- [x] Record effective retention policies with unlimited defaults and explicit
  application opt-in. Define authoritative time, deadline error bounds, policy
  changes, and quota/admission behavior; reject unsupported lifetime guarantees.
- [x] Enforce work cutoffs at admission, activation, turn and dispatch
  authorization; permit only explicitly bounded preauthorized settlement. Prove
  irreversible final closure and retirement, including
  uncollected bytes, stale snapshots, delayed expiry workers, clock/failover cases,
  and storage outages distinguished from expiry. No same-PID empty-mailbox
  restart is allowed.
- [x] Record connector reconciliation rights and finite windows/budgets. Prove
  that result/closure races have one winner, closed attempts reject late results,
  and unknown closure authorizes neither retry nor caller revival. Preserve the
  rejection evidence across checkpoint, trim, restart, and old receipts.
- [x] Pin `ursula-zig` by revision/hash, wire its `ursula` module, and validate
  create/append/catch-up/live reads against the pinned Ursula server.
- [x] Configure persistent Ursula storage and reproducible cluster/service
  lifecycle commands. Record the exact durability and recovery boundary.
- [x] Pin a Kubernetes/Substrate baseline and deploy the minimal Zig process via
  a runtime adapter. Prove activation from recorded backlog and recovery after
  worker loss, using one PID per Substrate Actor across activations. Document
  scoped provider identity, binding revisions, and platform prerequisites.
- [x] Recover lost wakeups and interrupted provider operations, including a
  controller crash after resource creation but before recording its outcome.
  Reconcile the intended resource without duplicate authorized activations.
- [x] Implement and prove serialized admission/ownership/commit authority,
  including authority restart, conflicting writers, and stale-owner rejection.
- [x] Process an ordered mailbox larger than the worker's read window with
  bounded RAM; prove duplicate admission and overload behavior. Reserve capacity
  for control/maintenance progress and inject full-store failures.
- [x] Commit input progress, state, and pending outputs recoverably; demonstrate
  crash recovery across delivery and bookkeeping boundaries. Prove source order
  per destination, partial fan-out, and denied/expired delivery outcomes.
- [x] Publish and validate a durable recovery checkpoint before trimming history.
  Recover from checkpoint plus retained tail with pending work/control evidence
  intact. Prove that a short completed-history window need not expire a live PID.
- [x] Verify Ursula checkpoint/retention/delete operations and client support;
  recover interrupted maintenance from recorded intent. Preserve retirement
  evidence outside deleted payloads and distinguish logical removal from GC.
- [x] Reject invalid sequences and attempted direct-write/effect bypass. Specify
  and test the handler isolation boundary, using a synthetic effect executor.
  Bound failing-handler retries and retain a visible input disposition. Test a
  worker paused after dispatch authorization without blindly retrying its attempt.
- [x] Kill and replace a worker, restart Ursula, restore an old activation, and
  rebuild process state from history without executing effects during replay.
  Prove stale execution is fenced even before a restored worker cooperates
  with its resume handshake.
- [x] Prove workload isolation from Substrate control credentials and raw Ursula
  read/write/admin APIs on the selected baseline. Provider authentication or
  bucket/atespace naming alone does not satisfy the security contract.
- [x] Expose actual build, conformance, deployment, and recovery checks through
  `just` and CI, with limitations recorded alongside results.

## M2 — Station GenServer, supervision, and registries

Scope: the Station Zig library and behavior workers expressing Transit's proven
kernel primitives.

Exit criteria:

- [ ] Provide a GenServer behavior with initialization, sequential handlers,
  durable state, sends, and correlated request/reply on a Transit process/PID.
  Demonstrate that the process primitive also works without a GenServer behavior.
- [ ] Implement a minimal scoped registry with explicit scope lifetime and
  durable register/unregister/conditional-rebind operations. Prove recovery,
  conflicting registration rejection, and support for unnamed processes.
- [ ] Record resolved PID/revision before delivery; test name rebinding and
  termination races with retries and late replies, without redirecting them.
- [ ] Persist waiting state; route replies, timeout observations, and lifecycle
  notifications through mailboxes without holding a turn open for external I/O.
- [ ] Expose retention contracts and bounded suspension. Reject a resumption
  request beyond required mailbox/resource lifetime; report permanent expiry
  separately from retryable activation failure. Prove that supervision stops
  retrying expired PIDs and that replacement requires an explicit new spawn.
- [ ] Demonstrate workload-scoped temporary streams surviving worker recovery
  and retiring after logical owner termination/expiry with dependencies resolved.
- [ ] Implement supervision with durable child identities, restart policy, and
  restart limits. Distinguish same-PID recovery from termination/new-PID spawn;
  prove supervisor and child recovery without duplicate children. Lifecycle
  observations distinguish process termination from activation loss.
- [ ] Provide bounded poison-message handling, authenticated replies and
  explicit cancellation/timeout outcomes; demonstrate a blocked process remains
  inspectable and lifecycle control does not depend on its handler returning.
- [ ] Demonstrate multiple processes exchanging messages across workers, preserving
  each mailbox's order and recovering pending deliveries.
- [ ] Provide a small runnable non-trading example and trace inspection commands.

## M3 — HTTP connector and exchange transcripts

Scope: an HTTP connector library and fetch-worker executable using Station to
request HTTP work through durable streams.

Exit criteria:

- [ ] Define request/response text and byte-body framing, interpolation rules,
  and exchange-group membership/completion manifests.
- [ ] Record literal requests, variable provenance, and secret references;
  resolve secrets only in authorized fetch workers and record capture omissions.
- [ ] Record per-attempt request/response data, failures, timing, and completion;
  stream large bodies through bounded buffers.
- [ ] Authorize dispatch only from committed intents; record redirects and
  retries as distinct attempts with stable effect correlation.
- [ ] Prove destination/secret scope across DNS, proxying, and redirects; reject
  forged attempt results and unauthorized transcript/body access. Exercise
  revocation races against the dispatch boundary defined in [SECURITY.md](SECURITY.md).
- [ ] Preserve caller PID and effect identity through activation replacement;
  reconcile late outcomes after caller termination without delivering them to
  a new process registered under the same name.
- [ ] Validate caller/exchange retention compatibility; expire transcript access
  explicitly, retain required unknown-outcome evidence, and reclaim group
  members without dangling live references or replay-triggered HTTP requests.
- [ ] Demonstrate timeout, partial response, cancellation races, and worker loss
  after send but before outcome recording, including unknown-outcome handling.
- [ ] Replay the caller from a transcript with no network requests or secret
  resolution; distinguish replay from explicitly authorized new execution.
- [ ] Deliver a GenServer-based connector example on the reference deployment.

## M4 — Clustered execution and portability

Scope: extend the reference slice to distributed supervision and lifecycle
management, while preserving a portable protocol.

Exit criteria:

- [ ] Exercise Substrate suspend/resume, worker migration, and stale snapshots
  against kernel ownership and history validation.
- [ ] Recover runtime-controller state and wakeups from backlog after controller
  failure; test ownership transfer during partitions and worker-pool changes.
- [ ] Prove cluster-scoped registry uniqueness, conditional rebinding, and
  lookup consistency during partitions; unavailable mutation authority fails
  closed. Rebuild lookup projections from recorded registry history.
- [ ] Extend M1/M3 sandbox, credential, and egress proofs across the supported
  cluster topologies and provider revisions.
- [ ] Define and test runtime-adapter conformance independently of Kubernetes
  resource types; prove a lightweight local adapter can preserve PID, mailbox,
  fencing, and recovery semantics without provider snapshot support.
- [ ] Evaluate whether multiplexing processes within a sandbox is useful;
  document shared failure, suspension, snapshot, and isolation consequences
  before extending the initial one-process-per-Substrate-Actor mapping.
- [ ] Extend retention conformance to keyed compaction, tombstone cleanup,
  consumer watermarks/pins, retry horizons, and lagging-consumer resynchronization.
  Prove no resurrection from old snapshots or replay, and bounded GC resources.
- [ ] Document backup/restore, post-termination retention, and code/schema
  migration with tested procedures, preserving policy, expiry, and deletion
  generations. Fence old deployments and reconcile external effects before
  allowing any restored history to authorize new live work.
- [ ] Measure representative mailbox, turn, effect, and recovery workloads;
  establish latency/throughput targets from those measurements.

## Application milestones after the foundation

Use the evidence above to scope trading, LLM/tool connectors, richer agent
frameworks, and an operator frontend. These are intended consumers of the
primitives, with their own requirements and acceptance criteria. A paper-trading
loop is not a prerequisite or the current roadmap's destination. Live trading
requires a separately scoped venue, risk, reconciliation, and operational design.
