# M2 follow-up — persistent reference and incremental development

[Roadmap](README.md)

Status: proposed implementation plan. The existing launchers do not yet provide
the update interface below. This work joins the persistent reference application
launcher with an explicit development loop for all three profiles.

## Outcome

`up` gives a developer a usable Transit installation: authority, durable Ursula,
maintenance, Board and an example process. Reference additionally includes the
real Substrate controller and sandboxed application execution. Its infrastructure
and application persist independently of the recovery tests.

Editing code must not require deleting the installation, rebuilding external
infrastructure, or rerunning a fault-injection test. Developers can identify
what was built, what was selected for deployment, and what is actually running.
Preserve realm/PID, mailbox, state, credentials and storage across supported
updates. Unsupported state or protocol migrations fail explicitly.

## Current gaps

- Local `build` writes shared `zig-out` paths used by the manager. A subsequent
  restart can pick up those bytes implicitly, and another installation can be
  affected by the same checkout build.
- Compose `up` builds all application images under mutable per-project tags.
  Its `build` task only builds host tools; `restart` restarts existing containers
  and does not deploy a new image or apply changed configuration.
- Reference `up` installs Kind/Substrate infrastructure. Only the recovery test
  provisions Transit, under a proof namespace. The test stops host controllers
  and tunnels after terminating its example PID; its cluster resources remain
  until teardown. There is no persistent application update path.
- The M1 runtime contract pins a PID's workload identity. A new Substrate image
  or template cannot be substituted with Helm or a provider restart alone.

## Common command meanings

The proposed interface is the same under `just launchers::local`, `compose`,
and `reference`. Service names are roles (`board`, `node`, `maintenance`,
`counter`, and reference `controller`), distinct from artifact names.

| Task | Intended behavior |
| --- | --- |
| `up` | Create once or start the saved installation; establish the complete usable system without invoking recovery tests |
| `build [SERVICE...]` | Build candidate artifacts for this target; leave running services and their selected versions unchanged |
| `update [SERVICE...]` | Build candidates, validate a deployment plan, apply only affected compatible changes, and verify readiness |
| `update --no-build [SERVICE...]` | Apply an already-built, explicitly identified candidate set |
| `restart SERVICE` | Restart the currently selected artifact/configuration; record fresh execution ownership where required |
| `status` | Report selected and observed artifact/config revisions, service state and protocol inspection availability |
| `watch [SERVICE...]` | Later opt-in automation calling the same update path after debouncing source changes |
| `down` | Stop application execution and services while retaining their state and credentials |
| `reset` | Explicitly destroy a stopped disposable application installation |

Examples of the intended development loop (not yet runnable):

```sh
just launchers::local::update board
just launchers::compose::update board
just launchers::reference::update board
```

Omitting service names selects the application's supported service set; report
the affected services before applying it. Build failure changes no running
service. Identical artifacts and configuration produce an update no-op. Failed
readiness leaves a visible failed/pending update with diagnostics; never report
success merely because a process started or Helm returned a release revision.

Reference cluster destruction needs a separately named infrastructure operation.
The current destructive `reference down` must be migrated explicitly, including
CI cleanup and documentation. Application stop/start cannot delete PVCs or mint
a replacement realm. Foreground attachment and signal handling must preserve
the existing local/Compose behavior; reference attachment/stop semantics must
be documented and tested as part of the persistent launcher.

## Build once, deploy identified artifacts

Use a small shared build layer for target architecture, optimization, dependency
selection and artifact metadata. Zig and Vite+ own source dependency tracking;
the launcher should not try to infer transitive imports with file globs.

Build only the requested artifact graph. Board frontend changes rebuild the
static assets and their embedding executable. Node and maintenance share the
node executable, so report and coordinate that affected group. Runtime-controller
code changes rebuild its image and retain the separately pinned provider CLI.
External Ursula, Kind and Substrate versions change only through their explicit
pins; ordinary application updates do not rebuild or upgrade them.

Identify native artifacts by their bytes and container artifacts by image ID or
registry digest. Include target, optimization, toolchain/dependency pins, and
source revision/dirty-worktree provenance for diagnosis. A Git commit alone is
not a sufficient build key during development. Write manifests atomically after
successful builds and retain previous artifacts while they are selected or
needed to diagnose an incomplete update.

Separate the candidate build manifest from each installation's selected and
observed deployment state. This metadata describes infrastructure, not Transit
execution authority. It contains no signing seeds, access keys or payloads.
Interrupted updates reconcile actual process/container/pod identities with the
saved operation before retrying; stale metadata cannot authorize replacement.

## Apply per environment

| Profile | Application build | Apply mechanism |
| --- | --- | --- |
| Local / Process Compose | Native Zig executables, including embedded Board | Stage immutable artifacts per installation; switch selected paths and replace affected processes through the manager |
| Docker Compose | Static binaries for the Docker engine architecture, packaged as images | Select identified images and recreate affected services with Compose; preserve bind-mounted WAL and keys |
| Reference | Static application images for cluster architecture | Push only changed artifacts to the owned registry, select digests in Helm values, and wait for changed workloads |

Local services must stop depending on shared mutable `zig-out` outputs. Snapshot
effective configuration for a restart; loading a new `.env` value is an update.
Use the pinned Process Compose project's update mechanism for topology changes
only after proving its service replacement behavior. Manager changes that need
a wider restart must state that impact instead of silently ignoring the edit.

Docker Compose's [restart](https://docs.docker.com/reference/cli/docker/compose/restart/)
does not apply changed configuration. Its
[up](https://docs.docker.com/reference/cli/docker/compose/up/) operation recreates
services whose image/configuration changed while retaining mounted volumes.
Targeted updates use that reconciliation path, with launcher-owned credential
rotation and readiness checks around application replacement.

An attached session must keep following replacement services. Its cleanup must
recognize updates belonging to its installation session while still refusing to
stop an unrelated later `down`/`up` session. Container-ID equality alone no longer
distinguishes those cases once updates intentionally replace containers.

Reference service upgrades use the checked-in chart, explicit configuration
checksums and immutable image references. Preserve the one-writer/Recreate
constraints for authority, maintenance and controller; do not promise rolling
availability. Keep bootstrap disabled on updates. A rollback of images is not a
rollback of protocol history, schema changes, or completed external effects.

## Persistent reference application

- Keep owned cluster/provider infrastructure separate from named application
  installations and disposable proof namespaces. Reuse the existing owned cluster
  after validating identity and pins; do not recreate it for application updates.
- Extend the chart to host the runtime controller with the pinned `kubectl ate`
  executable, explicit provider credentials/RBAC and its scoped Transit identity.
  No dependency on a host controller terminal, and no worker access to those
  credentials. Do not mount an administrator's personal kubeconfig into a pod.
- Persist bootstrap identity and exact outstanding provisioning requests. Reuse
  public client operations for grants, spawn and activation; unavailable history
  must never be interpreted as permission to initialize again.
- Provision Board's origin and access consistently with local/Compose settings,
  including remote development. Opening a tunnel alone cannot change Board's
  Host/Origin checks; record a usable ingress/forwarding configuration explicitly.
- Stop and resume application execution through recorded runtime intent before
  stopping infrastructure services. Preserve the PID and recovery basis. Counter
  termination, fixture expiry and worker fault injection belong only to tests.
- Recovery tests retain their isolated realms/resources and explicit cleanup.
  They cannot target the persistent application implicitly.

## Application-code upgrade gate

Changing a service binary and changing the code assigned to a durable process
are different operations. The current
[runtime contract](../../contracts/RUNTIME_SUBSTRATE_V1.md) rejects workload and
provider association changes, and Substrate templates are immutable. Silently
changing a template, deleting/recreating a bound Actor, or granting ownership to
an unrecorded image would bypass that contract.

Same-PID workload upgrades are included in this pass. Until the transition is
implemented and proved, reference updates must refuse changed bound workload
identities before mutating resources. A new
demo process is a new PID, not an upgrade, and must never silently replace the
process named by admitted messages.

A same-PID upgrade needs a recorded old/new workload transition, revision checks,
fencing, caller-declared state compatibility, safe provider reconciliation and
fresh activation. It must define unfinished turns, admitted messages, committed
outputs and effects, expiry during upgrade, rollback limitations and recovery
after every external-operation boundary. Old activations and stale controllers
must remain unable to authorize the previous version. Prove provider support
against the pinned implementation before choosing Actor/template mechanics.

The pinned Substrate server's `UpdateActor` supports switching a suspended Actor
between compatible templates, guarded by resource UID/version; its own end-to-end
fixture verifies DATA restoration under the new template. Preserve the Actor UID
and use a new immutable template. Its current CLI lacks `update actor`, so the
adapter needs a narrowly scoped, versioned CLI extension without changing the
upstream server API. Identify any packaged client patch explicitly. A new
version-specific WorkerPool provides a fresh pod incarnation under the existing
activation contract; do not relax fencing merely to reuse a physical worker.

The first upgrade preserves the caller's declared application/state contract
(`code`) and opaque committed state; it performs no state conversion. Require a
stopped, reconciled old activation, record old/new workload identities before
provider mutation, and reconcile template switching before requesting a fresh
activation. Stale controllers must refuse the changed workload. Pending inputs,
committed outputs and effect reconciliation retain their identities and policies;
no upgrade may redispatch an effect or extend process lifetime. Failed-process
repair and arbitrary state/schema migrations need their own contracts.

## Delivery and qualification

1. Establish these command meanings and the same-PID upgrade contract.
2. Add identified build artifacts and targeted build steps shared by profiles.
3. Implement local and Compose update paths, then qualify interruption, no-op
   builds, failure reporting, state preservation and foreground log continuity.
4. Add persistent reference provisioning/controller packaging and the same
   service update interface; keep recovery proofs separate and runnable.
5. Implement workload upgrades through public protocol, client,
   adapter and controller contracts with dedicated crash/fencing proofs.
6. Add optional source watching after manual updates are reliable. Frontend HMR
   is a separate dev-server mode with an explicit authenticated API/origin setup;
   embedded Board remains the packaged deployment path in every profile.

Acceptance includes editing Board without restarting Ursula or the counter;
recovering the same process/history across supported service updates; rejecting
unsupported image/state migrations before mutation; reporting partial deployment
failure; and retaining isolation between named installations and test fixtures.
Do not infer state-schema compatibility from a successful build or healthy pod.
