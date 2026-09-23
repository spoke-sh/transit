# Deployment and runtime boundary

Status: Kubernetes with Agent Substrate is the selected reference architecture
and recommended execution target. The dev shell supplies `kubectl`, `k9s`, and
Linux-only `k3s`; see [development](DEVELOPMENT.md#kubernetes-and-substrate).
Deployment manifests, a Substrate pin, and the runtime adapter remain in progress.
The experimental kernel now records opaque runtime bindings, operation
intents/observations, and atomic key/generation activation. Unit and disk proofs
cover stale binding/worker rejection and retirement across checkpoint/trim;
this is not yet provider integration evidence. See the
[implemented profile](../contracts/TRANSIT_V1.md#runtime-bindings-and-activation).
The [Substrate runtime profile](../contracts/RUNTIME_SUBSTRATE_V1.md) describes the
implemented reconciler, pinned CLI transport, fresh-key bootstrap, and provider
identity checks. Its reference cluster proof is being exercised; startup alone
is not recovery or isolation evidence.

## Reference architecture

Kubernetes manages the infrastructure that hosts Rey, persistent Ursula, and
Agent Substrate. Substrate supplies sandbox execution and worker lifecycle.
Rey's runtime adapter translates Transit's committed lifecycle intent into those
operations and records observations back into the protocol. Process execution
authority stays in the durable history.

Substrate separates an **Actor**, addressed by `(atespace, name)`, from its
current Worker/pod. The Actor is the unit of suspension and resumption and can
move between workers. An atespace is not a Kubernetes namespace; ActorTemplates
are managed through Substrate's API rather than as Kubernetes objects. See its
[glossary](https://github.com/agent-substrate/substrate/blob/main/docs/glossary.md).
This makes a Substrate Actor a useful hosting resource for a Transit process,
while leaving their identities and authorities distinct.

| Boundary | Responsibility |
| --- | --- |
| Transit | PID lifecycle, ordered mailbox, committed state/progress, ownership generations, and effect authority |
| Runtime adapter | Durable PID-to-provider bindings; reconciliation of lifecycle intents, provider operations, and observations |
| Agent Substrate | Sandbox placement, worker assignment, activation, suspension, and snapshot lifecycle |
| Kubernetes | Infrastructure capacity, pods, and supporting cluster resources |

Rey should use Substrate's placement and sandbox lifecycle machinery. Its own
controller determines which logical processes need execution and reconciles
their bindings; it need not duplicate Substrate's worker scheduler. See the
upstream [architecture](https://github.com/agent-substrate/substrate/blob/main/docs/architecture.md)
and [resource API](https://github.com/agent-substrate/substrate/blob/main/docs/api-guide.md).
These are integration references, not evidence of Rey compatibility.

The initial reference topology should include:

- Persistent Ursula and a private protocol admission/commit boundary.
- Zig kernel services and runtime reconcilers with narrowly scoped credentials.
- Substrate worker pools and templates hosting Transit process execution.
- Connector workers with distinct effect and secret capabilities.
- Rebuildable inspection views and failure/lag metrics.

Kernel/control services and Ursula need not themselves be sandboxed as
application processes.

## Bootstrap and disaster recovery

The deployment must supply trusted identity roots and a fixed bootstrap location
for the realm's durable control catalog. Idempotent initialization records realm
genesis, initial grants, process/stream allocation, and control-resource mappings.
An ordinary restart recovers those records before serving applications; it must
not interpret an unreachable store as an empty installation or mint new PIDs
for unresolved spawn requests. Application registries are downstream of this
bootstrap, not a dependency required to discover it.

System authorities need an explicit lifecycle outside application suspension
and retention defaults. Recover policy revisions, ownership generations,
retirement facts, and pending maintenance from validated durable state; never
reset them from an old worker image or an empty cache. Protect bootstrap/control
records with separate administrative grants and retention rules described in
[SECURITY.md](SECURITY.md) and [RETENTION.md](RETENTION.md).

Restoring an old backup is different from replacing a worker against current
storage. The backup may predate revocation, process expiry, or an externally
completed effect. M1 does not support automatic live restore from rolled-back
history. M4 must prove an explicit procedure that fences the old deployment,
establishes a new recovery generation/trust state, and reconciles external work
before activation. A clone used for inspection is read-only; a new live import
needs explicit identity and effect lineage. Neither may redispatch old attempts
or revive retired identities just because the backup contains them.

## Runtime bindings

The proposed mapping is:

```mermaid
flowchart LR
    Name[Optional registered name] --> PID[Transit PID]
    PID --> Binding[Durable runtime binding]
    Binding --> Actor[Substrate Actor: atespace and name]
    Actor --> Worker[Current Worker / pod]
```

The registry answers which logical process a name denotes. The runtime binding
answers where that process is hosted. Substrate resolves the current physical
worker. Message admission continues to address the PID when placement changes.

Proposed binding fields, with exact schemas to be established in M1:

| Field | Purpose |
| --- | --- |
| PID | Fully scoped logical process identity |
| Binding identity and revision | Identify the hosting association and reject stale updates |
| Provider kind and runtime instance | Distinguish Substrate or another adapter and the specific installation/cluster |
| Provider resource reference | Identify the resource in its provider scope, including incarnation/UID where available so name reuse cannot adopt an unrelated resource |
| Workload version | Identify immutable image/template and code/schema versions compatible with process history |

Desired association and validated provider observations are recorded separately,
with operation IDs and revisions connecting them. Provider-specific fields live
in adapter contracts; the core protocol handles opaque references. A resource
name alone is insufficient when a provider allows deletion and recreation. If
there is no immutable resource ID, the adapter must prove equivalent incarnation
tracking and reconciliation or reject the ambiguous resource.

Begin with **one Transit process per Substrate Actor**, retaining that Actor
across multiple activations. A new ownership generation does not require a new
Substrate Actor. Worker replacement, suspension, migration, or provider resource
replacement preserves the PID; logical termination retires it. Binding revision,
provider incarnation, and activation generation are separate dimensions. An
active provider resource or matching binding never grants commit authority.

Later, one sandbox may host multiple Transit processes if each retains its own
PID, mailbox, and ownership. Those processes would share a failure, suspension,
snapshot, and isolation boundary. Multiplexing therefore requires explicit
lifecycle and isolation policy; independent process identities do not promise
independent sandbox isolation.

## Why AX is excluded

AX introduces a task store and controller work queue backed by Redis, as described
in its [design](https://github.com/google/ax/blob/main/DESIGN.md). Rey will own
those execution semantics through the kernel protocol and durable streams.
Adopting AX would introduce another source of task authority to reconcile, so
it is excluded from the architecture.

Substrate and Kubernetes may keep their own infrastructure and sandbox state.
That operational state is legitimate within their boundary; it must not become
the authority for Rey message acceptance, completed turns, or effect eligibility.

## Reconciliation and recovery

Runtime reconcilers consume committed lifecycle intent and mailbox readiness.
They may derive ready queues or indexes for efficient scheduling, but recovery
must rebuild them from durable history. A lost notification must not strand an
inactive process with accepted work. Specify the stream-to-activation bridge;
do not assume Substrate automatically watches Ursula.

The initial activation path must establish these observable boundaries:

1. Admit the message durably to a live PID's mailbox.
2. Reconcile its backlog and lifecycle policy into recorded activation intent
   and a runtime binding. Notifications accelerate this step; backlog scans
   recover lost wakeups.
3. Create or resume the provider resource through a recorded operation, then
   reconcile its observed resource identity and binding revision.
4. Validate current ownership, lifetime eligibility, and the durable recovery
   basis before allowing the worker to consume the mailbox and commit under
   its activation reference.

All providers, including Substrate's automatic wake/resume path, obey the
application's [process/mailbox lifetime contract](RETENTION.md). Reject requested
suspension outside the validated resumption bound. A late wakeup for an expired
PID cannot authorize execution, even if the provider successfully restores its
sandbox. Runtime cleanup follows the terminal record as a separate operation;
provider activity does not renew the lifetime.

Provider create/resume/suspend/destroy calls are external effects. Use stable
operation identities and recorded intents/results. Where an API lacks an
idempotency key, query and reconcile existing resources before retrying. A
controller crash after creation but before recording the result must recover
or adopt the intended resource without producing duplicate authorized executors.
There is no assumed transaction spanning Ursula and a provider API.

Worker loss triggers recorded recovery and a fenced replacement activation of
the same PID. Binding replacement or migration must reconcile pending provider
operations and invalidate stale authority before work can commit at the new
location. Suspending or stopping a sandbox alone proves neither fencing nor
logical process termination.

Treat sandbox snapshots as execution caches tied to PID, binding revision, code
version, history position, and activation reference. Restored code may run with
old memory and credentials before a resume handshake completes. The trusted
commit and dispatch authorization boundaries must reject that stale authority
regardless of workload cooperation. Revalidate against current history and rebuild stale
state; restored files cannot roll back newer records or redispatch a completed
effect. Reconcile in-flight effects under their recovery policy.

## Isolation

Authentication and protocol permissions follow [SECURITY.md](SECURITY.md).
Authenticate service-to-service traffic and bind worker identity to the granted
PID/activation. Kubernetes service accounts/RBAC and Substrate identity are
provider mechanisms, not permission to perform Transit operations. Keep runtime
control, storage administration, effect dispatch, and application credentials
separate; restored credentials must pass current ownership and policy checks.

Substrate currently documents authentication without authorization/RBAC. Its
control credentials therefore belong only to trusted controllers/operators,
with network and credential boundaries preventing workload access. This is an
M1 integration gate, not a feature to assume from atespace naming. See
[upstream authentication](https://github.com/agent-substrate/substrate/blob/main/docs/authentication.md).

Application workers may reach only the protocol surfaces and capabilities they
need. They must not reach raw Ursula write/admin APIs, runtime control APIs, or
arbitrary external services. Connector workers receive separately scoped egress
and secret access. Runtime observations become validated records before they
change process execution state.

Substrate documents an egress policy path; validate it against the selected
revision and sandbox mode rather than assuming all isolation requirements are
already satisfied. See [egress traffic](https://github.com/agent-substrate/substrate/blob/main/docs/egress-traffic.md).
M1 must also establish the deterministic handler boundary described in
[TRANSIT.md](TRANSIT.md); network isolation alone does not constrain clocks or
arbitrary native-code state changes.

Use a fixed reviewed workload image in M1. Pin code, configuration, and schema
identity in activation grants. Untrusted native plugins or multiple differently
privileged processes in one sandbox require a separately proved isolation
boundary; shared Zig address space cannot provide it.

## First milestone and portability

Kubernetes deployment and worker-failure recovery belong in M1. Pin and exercise
the Substrate baseline as part of the minimal reference slice, with reproducible
cluster setup and prerequisites. Upstream is in early development and marks
parts of its design as aspirational; record observed behavior and integration
gaps alongside tests. See [upstream status](https://github.com/agent-substrate/substrate#status-and-compatibility).

Kernel envelopes use logical identities and protocol versions. Kubernetes
resource names, cloud credentials, sandbox snapshots, and provider APIs remain
inside adapters. Every deployment architecture needs an explicit runtime binding
and the same conformance contract: scoped resource identity, reconciled lifecycle
operations, activation ownership, effect isolation, durable observations, and
recovery from history. Provider state may help locate a worker; it cannot replace
Transit's authority for whether work was accepted or completed.

Sandbox snapshot support is an optional optimization. Another provider can
cold-start workers and reconstruct state from sufficient history or a durable
protocol checkpoint plus retained tail, preserving the same PID/mailbox lifetime
semantics. Required protocol checkpoints are independent of provider memory
snapshots. Keep a lightweight local adapter for development and conformance with
explicit isolation limitations; reference cluster conformance remains required.

Separate worker/pod recovery from loss of storage disks, hosts, or a region.
The first reference deployment proves its documented failure boundary. Broader
availability, backups, and multi-cloud operations need their own evidence;
portability does not imply those deployments already exist.
