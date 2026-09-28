# Pre-Station project review

Reviewed 2026-09-24 against implementation commit `96db8a9` and the documentation
corrections accompanying this review. This is a source/contract/test-coverage
review of M0–M7, not a production security certification or a new milestone.
[Roadmap](../roadmap/README.md) · [Station entry gates](../roadmap/M9.md#entry-gates)

This is the historical M7 review. [M8](../roadmap/M8.md) implements the generic
origin, delivery, lifecycle and catalog-readiness recommendations below; see its
[qualification evidence](../../tests/README.md#m8-runtime-readiness) for current
behavior. Remaining framework policies and scaling limits still apply.

## Assessment

The architecture has a coherent authority boundary: applications compute through
the public client; core validates deterministic transitions; one conditional
realm-journal append decides acceptance; adapters supply storage and placement.
Board consumes authorized public evidence and no longer decodes application state.
The associated-resource model fits that boundary without introducing another
state authority.

M7 is sufficient to start Station's design and first implementation slice. It is
not evidence that a general GenServer runtime can be implemented as callback
wrappers alone. The gaps below require public contracts, service ownership, and
failure proofs in M8 runtime readiness and M9 Station before claiming its programming interface complete.

## Review coverage

| Boundary examined | Implementation and existing evidence | Assessment |
| --- | --- | --- |
| Public contracts and dependency direction | [Protocol](../../packages/zig/transit-protocol/README.md), [client](../../packages/zig/transit-client/README.md), [core](../../packages/zig/transit-core/README.md), package manifests | Caller/core separation is real; no application handler dependency in the node. Schema generation is not a complete future language SDK. |
| Authentication and authority | `authenticate`, `authorize`, `duplicate`, `prepare`, `commit` in [core](../../packages/zig/transit-core/src/root.zig); [unit proofs](../../packages/zig/transit-core/src/tests.zig) | Current grants, principal sequence and CAS fence transitions. Handler-facing origin and framework-specific rights remain incomplete. |
| Atomic resource state and reads | [Resource transitions](../../packages/zig/transit-core/src/resources.zig), [reads](../../packages/zig/transit-core/src/resource_read.zig), [resource proofs](../../packages/zig/transit-core/src/resources_test.zig) | One-resource mutations share the turn decision. Read grants and snapshot expiry are explicit. Trusted provisioning is narrower than an initialization barrier. |
| Retention and recovery | [Backend](../../packages/zig/transit-backend-ursula/docs/storage.md), [disk proof](../../tests/state.zig), [maintenance](../../apps/transit-node/Maintenance.zig) | Checkpoint/replay, required-state expiry and reclamation have bounded proofs. Whole-realm quiescence and permanent catalogs limit long-running use. |
| Delivery and effects | `applyTurn`/`deliver`/`observe` in core; [outbox](../../tests/outbox.zig), [effect proof](../../tests/effect_io.py) | Legal delivery and closure are proved; no deployed general delivery loop, timer service, or HTTP connector follows from those tests. |
| Runtime and development | [Controller](../../apps/transit-runtime-controller/README.md), [provisioning](../../launchers/common.py), [upgrade proof](../../tests/reference_launcher.py) | Same-PID recovery and compatible upgrades are distinct from logical replacement. Current controller scope is one PID; local/Compose trust differs from Substrate isolation. |
| Inspection and operations | [Board](../../apps/transit-board/README.md), [frontend](../../apps/transit-board-web/README.md), [telemetry](../../packages/zig/telemetry/README.md) | Private shared inspection, raw-value permission boundaries, explicit cuts, and lossy diagnostics are documented. Framework descriptors and progress guarantees are future work. |
| Roadmap and evidence ownership | [M7](../roadmap/M7.md), [M9](../roadmap/M9.md), [proof guide](../../tests/README.md) | Corrected completion wording to match the chosen bounded mechanism; new gates belong to upcoming work, not retroactive milestone follow-ons. |

## Authenticated inputs and framework permissions

**Priority: before authenticated Station request/reply or registries.**
The authority records authenticated requests and source outboxes, but public
[`Input`](../../packages/zig/transit-protocol/src/root.zig) contains only
`position` and `value`. The node's view projection and
[`Session.receive`](../../packages/zig/transit-client/src/Session.zig) do not
carry the external principal, source PID/turn, or effect/attempt identity to the
handler. Correlation or a claimed sender inside `Value` cannot authenticate a
reply. General inspection is also unsuitable as a substitute: it has different
permissions and filters cross-PID evidence.

Add a versioned, authority-derived input-origin envelope with minimal disclosure.
Distinguish external admission, committed process output and connector outcome.
Test forged replies, another process using the same correlation ID, revoked
sources and source PIDs the receiver cannot inspect. Preserve the evidence across
checkpoint recovery and language-neutral fixtures.

Lifecycle/resource administration and root-only grant changes are also distinct
from behavior execution. Station cannot initialize arbitrary child resources or
manage grants with only an execute credential. Define a trusted provisioning/
lifecycle service or a bounded delegation protocol, with durable intents and
least privilege. Do not put the root key in every GenServer. Framework-level
registry policy must validate authenticated origins independently of send rights.

## Delivery and lifecycle services

**Priority: before a runnable multi-process Station example.**
A committed outbox becomes destination input only when an authorized caller
submits `deliver`. The existing proofs do this explicitly.
[Maintenance](../../apps/transit-node/Maintenance.zig) handles expiry, views,
reclamation and checkpoints; the runtime controller handles Substrate lifecycle.
Neither runs a general outbox pump. There is no framework timer service or
durable lifecycle subscription feeding supervisor mailboxes.

Assign these responsibilities explicitly. Persist operation identities, reconcile
lost receipts, preserve route order and record terminal delivery outcomes.
Qualify a running system in which killing the courier/controller and losing
notifications cannot strand accepted work. Timer and lifecycle evidence must be
authenticated inputs; an in-memory callback or polling sample is not a durable
notification. Service readiness must describe this progress role separately from
HTTP health and execution ownership.

## Initialization and supervised failure

**Priority: before promising recoverable GenServer initialization or restart.**
Spawn has no declaration of required associations or initializing lifecycle.
Core checks dependencies that are installed; an empty association set is valid.
[Launcher provisioning](../../launchers/common.py) creates the resource and
association before activation under one trusted operator workflow. Its resource
starts empty; the counter defines its own initial value. That is the actual M7
proof, not atomic spawn/initialize/activate or arbitrary schema initialization.

Station needs a recoverable initialization protocol: record intended child and
resource identities, recover each receipt, mark initialization completion, and
prevent ordinary behavior handling until then. Exercise crashes between every
step, including failed initialization with already allocated lifetime slots.

A recorded failed turn blocks the head input and clears ownership. `executable`
rejects subsequent ownership of that PID; no clear-failure command exists.
Station must specify which retries happen before recording this block and what
policy can follow it. Same-PID worker recovery, an authorized future unblock, and
termination/new-PID replacement are different operations. Independent resources
outlive a retired writer but have no writer-transfer operation, so replacement
cannot silently inherit their write authority or old mailbox work.

## Capacity and progress under pressure

**Priority: choose a supported Station topology before promising continuous service.**
The protocol has 64 lifetime process slots, 128 lifetime effect slots, 256 lifetime
outbox slots, and 16 principal slots. M7 adds four lifetime resource identities,
32 live keys per resource, and four active views per realm. These are fixed
catalogs; completing an output/effect or retiring a PID/resource does not free
its identity slot. Checkpointing retains this evidence. See
[public limits](../../packages/zig/transit-protocol/src/root.zig) and
[state limits](../../packages/zig/transit-protocol/src/State.zig).

A 32-key map can update its existing keys repeatedly. A service exchanging
messages cannot run indefinitely when every send consumes an unreclaimed outbox
slot. A supervisor and registry also consume resources alongside user processes;
child replacement consumes new PID/resource identities. Raising constants alone
increases checkpoint/candidate memory without solving evidence reclamation.

Budget the first framework topology and test repeated calls/replacements to its
actual bound. Supporting indefinite operation needs safe reclamation/rejection
floors or another explicit capacity design, not identity reuse. Report capacity
and view exhaustion as backpressure. The finite-admission reserve forbids new
view opens and new outputs/effects; it protects bounded control progress, not
completion of every queued stateful request. A blocked application may require
operator action; quota pressure still cannot authorize silent cancellation.

## State layout, retry ownership, and retention

**Priority: before fixing the Station handler API.**
Only one resource can be mutated by a turn. Put application data and framework
waiting/correlation records in the same resource when they must commit together,
with explicit key/schema ownership and mutation budgets. Otherwise use a
message protocol with separate commits. A Table abstraction cannot promise a
transaction across behavior, registry and supervisor resources.

[`Pending`](../../packages/zig/transit-client/src/Session.zig) owns exact signed
retry bytes in memory. It does not persist them or coordinate sessions sharing a
principal. Opening a resource view is itself a sequenced mutation, and even
unlimited-lifetime resource turns need finite views and trusted time. Specify
what Station recovers after a crash between open, computation, append and receipt;
when a proposal can be recomputed; and how denial, expiry and uncertainty differ.
Do not silently refresh an uncertain turn's read basis or renew a deadline.

Whole-realm checkpoint/trim requires quiescent mailboxes and every applicable
policy's opt-in/minimum age. An unlimited resource can pin the realm's history;
a continuously busy process can prevent checkpoint progress. Read buffers are
bounded, but recovery and `nextInput` can scan retained history. Bounded RAM does
not promise bounded restart time. Measure long-running, mixed-retention workloads
before promising lookup or recovery targets, and plan checkpointing that can
preserve pending work if continuous operation needs it.

## Inspection, compatibility, and operations

**Priority: preserve these limits while adding framework features.**

- Board is a shared private reader, with no viewer identity. Future controls
  need attributable authorization and retry identities; read-only network access
  cannot automatically become mutation authority.
- Pagination expires on any realm journal change, even for captured state-view
  pages. Background view opens/closes and unrelated work can disrupt browsing.
  Qualify multiple active behaviors with Board before promising navigable long
  histories; any snapshot pagination extension needs bounded retention and
  current-policy revalidation.
- Framework lenses need explicit versioned descriptors and authorized evidence.
  Numeric code tags and application payload shapes cannot identify GenServers.
  Source/target visibility and framework metadata/value permissions need fixtures.
- Compatible image updates declare the same application contract; they are not
  schema migration. M7 preserves old inline realms but cannot downgrade a realm
  containing state operations to an older authority. Define a release/contract
  compatibility matrix before independent package releases or non-Zig SDKs.
- Clock-backed state turns currently qualify Linux synchronized time. Other
  platforms fail required clock use closed. One realm journal, sequential ingress
  and one configured PID per runtime controller remain deployment constraints.
  Worker recovery is not HA, disk-loss recovery, or safe activation from an old backup.
- Diagnostics are bounded logs/local metrics/context, not an OTLP exporter or
  complete progress monitor. Add capacity, blocked-work and recovery observations
  with explicit freshness/cardinality as services acquire those responsibilities.

## Documentation corrections and next milestones

This pass makes Transit the root documentation subject and Rey the intended
consumer. Existing repository/artifact/signature names retain their compatibility
meaning. Detailed node/Board operations, caller workflows and Ursula mappings
now live in nested component guides. Foundational docs link to those owners.
Stale planned-state wording, durable-staging claims, initialization overclaims,
and outdated application-lens references are corrected.

[M8 runtime readiness](../roadmap/M8.md) owns the generic runtime prerequisites;
[M9 Station](../roadmap/M9.md#entry-gates) owns behavior policies and subscriptions.
[M15](../roadmap/M15.md) must additionally specify large-body references,
transcript/secret permissions, capture completeness and bounded external retry;
the immutable payload proof is not that dependency model. [M24](../roadmap/M24.md)
needs measured recovery/scaling, portable runtime conformance, distributed
retention and explicit live-restore/migration procedures. If an expansion needs
its own delivery milestone, insert it into the linear roadmap before its consumer.

The most useful additional discipline is to **trace each guarantee to evidence**.
Each guarantee
names its public contract, enforcing code, adversarial test, tested topology and
unsupported cases. Extend the existing conformance table and test guide rather
than creating a second status ledger. A checked milestone box must describe the
mechanism actually proved; a planned abstraction or successful smoke test cannot
stand in for that evidence.

## Validation boundary

The existing M7 proof guide records the previous Linux CI, browser, Compose,
Substrate, disk-interruption and physical-capacity runs. This review re-read the
implementation and tests; those integration runs are not new results of this pass.
Validation passed: `nix develop --command just check`, including Nix evaluation/
smoke checks, Zig formatting/unit tests, generated protocol schema and local
Markdown links. Only the current x86_64 Linux system was checked by Nix; other
platform qualification remains open.
No live launcher installation or upstream dependency is changed by this review.
