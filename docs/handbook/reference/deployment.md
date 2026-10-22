# Deployment and recovery

Choose a deployment for its lifecycle and isolation requirements.
Kubernetes with Agent Substrate is the reference runtime. Local and Compose
profiles are useful development environments; they do not provide equivalent
worker isolation. Distributed recovery across authorities is unsupported.

| Entry point | Intended use | Guide |
| --- | --- | --- |
| `transit server` | Trusted local service neighborhood, application manager and supervised Board | [Server](../../../apps/transit-cli/docs/server.md), [applications](../../../apps/transit-cli/docs/applications.md) |
| Local launcher | Persistent native development stack with Board and example workload | [Launchers](../../../launchers/README.md) |
| Compose launcher | Containerized development and integration testing | [Launchers](../../../launchers/README.md) |
| Reference launcher/chart | Kubernetes/Substrate infrastructure and persistent application | [Reference runbook](../../../deploy/reference/README.md), [Helm chart](../../../charts/transit/README.md) |

## Initialize and restart deliberately

Initialize a fresh installation explicitly. Its private records bind identity,
credentials, selected artifacts, configuration and recovery state. Ordinary
restart reuses that installation and recovers current authority before serving
work. An unreachable store is not an empty one. Missing history, wrong ownership
or incompatible configuration must fail visibly rather than mint new identities.

For the local CLI, the ready record exposes generated connection configuration,
gateway URL and allowed Host authorities only after the neighborhood is ready.
That readiness does not imply a query or application command has completed.
Default native gateway authorities include numeric loopback and `localhost`
at the configured port. Explicit aliases support alternate tunnel ports without
changing the listener or browser policy; configure them before initialization.

Version 3 starts Board by default; `--no-ui` disables it for one invocation.
Versions 1 and 2 retain their headless configuration and require `--no-ui` with
the current CLI. Use existing pinned installations with their original artifacts;
changing the configuration version does not upgrade retained history.
Compatible application-worker replacement is separate from changing
pinned neighborhood binaries. Stop/start, build/update and destructive reset have
different meanings. Follow the owning guide; a package upgrade alone cannot
initialize authority or migrate data.

## Physical execution and durable ownership

A runtime binding maps a logical PID to provider identity. Substrate manages
sandbox placement and worker lifecycle; the controller reconciles committed
intent through the public client and adapter. The initial mapping uses one
Transit PID per Substrate Actor across worker replacements.

PID, provider incarnation, pod and ownership generation remain distinct. A worker
restart requires fresh eligible ownership. Provider names, restored snapshots or
successful pod creation cannot grant execution rights or revive a retired PID.
Logical Station supervision and physical process management remain separate.

For an unbound PID, the typed Zig client supports
[recorded manual replacement](../../../packages/zig/transit-client/docs/worker-handoff.md)
under one authority. One trusted manager persists exact phase records and signed
requests, quiesces the writer, verifies its complete application resource,
conditionally fences it, revalidates dependencies and rotates its credential.
The selected profile requires one writer-owned application resource and no
outstanding finite turn permit. Missing manager records or corrupt checkpoints
stop recovery. Provider-bound PIDs retain the controller's separate lifecycle.

Applications have no raw Ursula credentials. Board uses public read surfaces and
a private viewer boundary. Connector workers hold only their scoped effect/secret
capabilities. Local same-user processes are trusted code, not a sandbox.

## Outages and disaster recovery

Recover ordinary crashes against current durable storage using the same identities
and exact unresolved operations. Storage unavailability, missing history and
terminal expiry are different diagnoses. Stop new work if the current authority
or required recovery basis cannot be established.

An old backup may predate revocation, retirement or a completed remote effect.
Automatic live restore from rolled-back history is unsupported. Broader disaster
recovery needs explicit fencing, new recovery/trust generations and external
reconciliation; cloning for inspection cannot quietly become live execution.

Finite admission/control reserves retain capacity for control operations under
pressure. They do not allocate disk or drain all accepted application work. See
[retention](retention.md) and [observability](observability.md) for capacity and
diagnostic interpretation. A SIGKILL/restart proof is not a host power-loss proof.

The [runtime contract](../../../contracts/RUNTIME_SUBSTRATE_V1.md),
[adapter](../../../packages/zig/transit-runtime-substrate/README.md) and
[controller](../../../apps/transit-runtime-controller/README.md) own exact provider
operations. Use the chart from this checkout; public release channels and
deployment on other cluster runtimes are unsupported.
