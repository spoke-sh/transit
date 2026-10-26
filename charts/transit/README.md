# Transit Helm chart

Transit is programmable, versioned data infrastructure. This chart packages one
realm's native authority, persistent storage, optional maintenance,
[delivery](../../apps/transit-delivery/README.md), [Board](../../apps/transit-board/README.md),
runtime/framework controllers and Agent Substrate worker capacity.

The [reference proof](../../deploy/reference/README.md) installs this chart and
qualifies controller/worker recovery, persistent storage, maintenance, and Board
isolation. The [Station example](../../examples/station-ledger/docs/running.md)
uses three PID-scoped runtime controllers and separate framework controllers.
The chart packages one native v1 authority with bounded resident pages and
persistent catalogs. It does not configure authority replication or failover.

## Resources and values

Read [values.yaml](values.yaml) for defaults and [values.schema.json](values.schema.json)
for deployment-level validation. Application configuration remains owned by the
[node](../../apps/transit-node/README.md) and [Board](../../apps/transit-board/README.md)
and validated by their binaries; the chart does not duplicate those schemas.

| Component | Resources and configuration |
| --- | --- |
| `node` | One Recreate Deployment, private ClusterIP Service, JSON ConfigMap. Supply `node.image` and `node.config`, including the trusted public genesis. |
| `ursula` | One Recreate Deployment, private Service, disk-WAL ConfigMap and retained PVC. Uses the official pinned image. Supply `persistence.existingClaim` to reuse storage; otherwise `size` and optional `storageClass` configure a new claim. |
| `initialize` | Explicit one-time Job using the node image/config. Disabled by default and never an automatic Helm hook. |
| `maintenance` | Optional separate single-replica Deployment and ConfigMap. Supply `existingSecret` containing `seed` and `config.principal` with its recorded admin/effect grant. Uses the node image with `--maintain`. |
| `delivery` | Optional single-replica Recreate courier. Supply `image`, `existingSecret` with `seed`, `config.realm` and a dedicated `config.principal` granted delivery/send. Its signed exec probe reads status; it has no storage mount or Kubernetes token. |
| `board` | Optional Deployment, private Service and ConfigMap. Supply `image`, `existingSecret` containing the Transit `seed`, and `config` with realm, inspection principal and public origin. |
| `controller` | Optional one-PID Recreate Deployment with a PID-scoped Transit seed, projected provider/API tokens, public trust-bundle read permission and namespace-local worker-log access. Supply its packaged image and provider configuration. |
| `runtimeControllers` | Up to 15 additional PID-scoped controllers using the same deployment and credential boundary. Each requires a unique `nameOverride`, `config`, and `existingSecret`; supply its image. |
| `stationControllers` | Up to 15 framework observers/lifecycle controllers. Each requires a unique `nameOverride`, image, public-client `config`, and separate `existingSecret`. They receive no provider token or storage mount; egress is limited to Transit and DNS. |
| `workerPools` | Named version-specific pools; keep old capacity until a recorded workload switch has reconciled and a fresh activation is established. |
| `workerPool` | Optional Substrate WorkerPool. Supply `spec` and any workload selector labels. Requires the pinned Substrate CRD/controller already installed. |

Names default to `<release>-<component>` and can be overridden per component.
Maintenance leaves checkpoint trimming disabled by default. To enable it,
explicitly set `node.config.genesis.allow_history_trim: true` when initializing
the realm and `maintenance.config.checkpoint_every_records` to at least 2.
This does not enable application data expiry.

Additional controller names must be unique across both arrays and base components.
Their `config` is public configuration: signing credentials come from the
mounted Secret's `seed` key. Use separate recorded grants for each responsibility;
creating a Deployment does not grant access to a PID or state resource.
HTTP services listen on port 8080; the courier has no listener. The chart fixes listener/credential paths and
sets internal service URLs; disable Ursula and provide `node.config.ursula_url`
for an external backend. Board and delivery require the chart's node. Log level/format and
resource requests/limits are per component. Config changes trigger replacement
through a checksum; externally rotated Secrets require an explicit rollout.

For the native local owner, set `node.config.local_directory: /data/native`,
`ursula.enabled: false` and `maintenance.enabled: false`. The node and explicit
initializer mount the same retained PVC, configured by `node.persistence`.
`node.existingSecret` mounts credentials at `/secrets` in the node only; the
initializer receives no execution credential. Configure direct catalog registrar
and in-process maintenance key paths in `node.config`. An external maintenance
process cannot open the node's exclusive directory. Normal node replacement
recovers that directory; initialization remains an explicit separate phase.

For bounded hot storage with an external cold tier, set
`ursula.existingConfigSecret` to a separately created Secret containing
`ursula.toml`. The chart mounts it read-only instead of generating the default
no-cold-tier ConfigMap; it never reads or copies that Secret into Helm values or
release history. Supply the complete upstream configuration, including listener
`0.0.0.0:8080`, disk WAL at `/data/wal`, explicit hot/cache limits and snapshot/cold
backend settings. Preserve these settings during recovery. The deployment keeps
its PVC and readiness probe; credentials remain available only to Ursula.
The default profile is still disk WAL with inline snapshots and no cold tier.


Supply immutable service images built from the consuming project's release.
The reference builds and pushes its own images; this repository does not yet
publish Transit/Board release images. It uses the official Ursula image pinned
in [versions.json](../../deploy/reference/versions.json); the chart check guards
against a different default pin.

## Bootstrap and lifecycle

Choose an explicit Kubernetes context and namespace. Prepare a private values
file with the public genesis, node image, bucket/journal and any desired options.
Keep the root seed outside Helm. Generate its public key with `transit-admin public-key`
as described in the [CLI guide](../../apps/transit-admin/README.md). Create Board and
maintenance/delivery Secrets separately, and record their grants through the
signed Transit API before enabling those services. The chart creates no principals,
grants, example processes, Actor templates or runtime bindings.

With `TRANSIT_CONTEXT`, `TRANSIT_NAMESPACE` and `TRANSIT_VALUES` pointing to that
context, namespace and values file, install a **new** realm in three phases:

```sh
# Wait for storage before bootstrap. Keep Board and maintenance disabled.
helm upgrade --install transit charts/transit \
  --kube-context "$TRANSIT_CONTEXT" -n "$TRANSIT_NAMESPACE" --create-namespace \
  -f "$TRANSIT_VALUES" --set node.enabled=false,initialize.enabled=false,board.enabled=false,maintenance.enabled=false,delivery.enabled=false --wait

# Deliberately initialize once; the job fails rather than hiding a failure.
helm upgrade transit charts/transit \
  --kube-context "$TRANSIT_CONTEXT" -n "$TRANSIT_NAMESPACE" \
  -f "$TRANSIT_VALUES" --set node.enabled=false,initialize.enabled=true,board.enabled=false,maintenance.enabled=false,delivery.enabled=false --wait --wait-for-jobs

# Normal service startup and all subsequent upgrades use recovery only.
helm upgrade transit charts/transit \
  --kube-context "$TRANSIT_CONTEXT" -n "$TRANSIT_NAMESPACE" \
  -f "$TRANSIT_VALUES" --set node.enabled=true,initialize.enabled=false --wait
```

Set `initialize.enabled: false` in the maintained values file. Restarting a pod
or applying normal values never initializes missing history. Do not rerun the
bootstrap phase as a recovery tactic. The chart refuses simultaneous initializer
and node/maintenance startup. A failed Job remains inspectable; investigate it
before deliberately replacing it. There is no automatic destructive rollback.

Uninstall preserves a chart-created PVC through Helm's `keep` annotation.
Deleting its namespace, underlying disk, or the claim itself is still destructive.
To reinstall, explicitly reference the retained claim and use the original
public genesis and recovery configuration. Do not bootstrap or substitute a new
root. This retention is an infrastructure safeguard, not a backup/disaster-recovery
procedure or a Transit process-retention policy.

## Security and runtime boundary

Services run as non-root with a read-only root filesystem and dropped
capabilities. Ordinary services receive no service-account token; the optional
controller receives the explicitly projected tokens described below. Credentials
are read-only mounts from existing Secrets; never put private seeds in Helm values,
ConfigMaps, extra-container arguments or release history. The initializer needs
only public genesis. Maintenance and Board receive distinct credentials.

Default NetworkPolicies restrict Ursula ingress to node, maintenance and
initialization pods, and Board egress to Transit and cluster DNS. They require
an enforcing CNI; rendered policy alone does not establish isolation. Review DNS
selectors for your cluster and enforce equivalent restrictions around external
Ursula. Node/controller services are trusted control infrastructure. Services
are ClusterIP-only. Board has no viewer key/session layer: every reachable
caller shares its configured read scope. Network admission, any authenticated
ingress, and TLS termination remain deployment responsibilities. No public ingress or telemetry collector is
installed. A Board health probe preserves the configured public Host.

The Kind reference supplies `board.extraInitContainers` and `extraContainers`
for enforced pod-namespace egress and denial probes because its CNI does not
enforce NetworkPolicy. These are explicit test-fixture extensions, empty by
default. Do not copy their privileged network initializer into a different
architecture without reviewing its boundary.

Substrate itself is installed separately from its pinned upstream source.
The isolated recovery proof runs `transit-runtime-controller` on the host so
it can interrupt provider reconciliation. The persistent reference launcher
uses this chart's optional in-cluster controller with projected credentials.
Neither profile makes `example-counter` a required runtime component. WorkerPool
capacity alone does not authorize or launch a Transit process; Actor templates, grants and
recorded bindings remain necessary. See [deployment](../../docs/handbook/reference/deployment.md).

## Validation

```sh
just test::deployments
# With Linux/Docker and the reference prerequisites:
just launchers::reference::infra-up
just launchers::reference::images
just launchers::reference::test
just launchers::reference::test-station
just launchers::reference::infra-down
```

The first command renders and lints representative values, checks credential,
bootstrap, storage and network boundaries, and rejects unsupported configuration.
It runs in `just ci all`. The reference uses the checked-in chart for real resources;
its Python fixture supplies values, credentials, protocol operations and faults.

## Persistent reference controller

The [reference launcher](../../launchers/README.md) provisions the controller's
Transit grants and mounts only its own signing seed. The image includes the
[pinned provider CLI](../../nix/ate-upgrade/README.md). Its kubeconfig names the
cluster API and projected token/CA paths; it contains no administrator token or
personal kubeconfig. A separate rotating audience-bound token authenticates
direct calls to Substrate. Kubernetes RBAC permits only `pods/log` reads in this
installation's namespace and listing public ClusterTrustBundles.

The pinned Substrate API authenticates callers without per-Actor authorization.
The controller remains trusted for provider administration; atespace naming is
not an authorization boundary. Those credentials are never mounted in workers
or Board. The controller's separate Transit grant is scoped to its PID.

`running: false` scales the application Deployments to zero and retains their
configuration and PVC. Record a stopped runtime intent and reconcile the Actor
before applying it; Helm cannot fence a Transit activation. WorkerPool replicas
are separately set to zero by the launcher after that reconciliation. For a
workload version change, use the [recorded upgrade protocol](../../contracts/RUNTIME_SUBSTRATE_V1.md#same-pid-workload-changes);
changing an image in Helm is not sufficient authorization.
