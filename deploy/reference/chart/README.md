# Reference component chart

Transit is programmable, versioned data infrastructure. This chart packages one
realm's [server](../../../apps/transit-cli/docs/server.md#external-worker-composition),
persistent storage, optional [Board](../../../apps/transit-board/README.md),
runtime/framework controllers and Agent Substrate worker capacity.

The [reference proof](../../../deploy/reference/README.md) installs this chart and
qualifies controller/worker recovery, persistent storage, maintenance, and Board
isolation. The [Station example](../../../examples/station-ledger/docs/running.md)
uses three PID-scoped runtime controllers and separate framework controllers.
The chart packages one native v1 authority with bounded resident pages and
persistent catalogs. It does not configure authority replication or failover.

## Resources and values

Read [values.yaml](values.yaml) for defaults and [values.schema.json](values.schema.json)
for deployment-level validation. Application configuration remains owned by the
[server](../../../apps/transit-cli/docs/server.md) and [Board](../../../apps/transit-board/README.md)
and validated by their binaries; the chart does not duplicate those schemas.

| Component | Resources and configuration |
| --- | --- |
| `node` | One Recreate Deployment running `transit server --no-ui`, private ClusterIP Service, public server ConfigMap and retained installation PVC. `existingSecret` supplies the operator `root` seed; optional direct catalog credentials remain in this Secret. The server owns native authority, maintenance and delivery. |
| `ursula` | One Recreate Deployment, private Service, disk-WAL ConfigMap and retained PVC. Uses the official pinned image. Supply `persistence.existingClaim` to reuse storage; otherwise `size` and optional `storageClass` configure a new claim. |
| `board` | Optional Deployment, private Service and ConfigMap. Supply `image`, `existingSecret` containing the Transit `seed`, and `config` with realm, inspection principal and public origin. |
| `controller` | Optional one-PID Recreate Deployment with a PID-scoped Transit seed, projected provider/API tokens, public trust-bundle read permission and namespace-local worker-log access. Supply its packaged image and provider configuration. |
| `runtimeControllers` | Up to 15 additional PID-scoped controllers using the same deployment and credential boundary. Each requires a unique `nameOverride`, `config`, and `existingSecret`; supply its image. |
| `stationControllers` | Up to 15 framework observers/lifecycle controllers. Each requires a unique `nameOverride`, image, public-client `config`, and separate `existingSecret`. They receive no provider token or storage mount; egress is limited to Transit and DNS. |
| `workerPools` | Named version-specific pools; keep old capacity until a recorded workload switch has reconciled and a fresh activation is established. |
| `workerPool` | Optional Substrate WorkerPool. Supply `spec` and any workload selector labels. Requires the pinned Substrate CRD/controller already installed. |

Names default to `<release>-<component>` and can be overridden per component.
The server retains its generated service credentials and bootstrap receipts on the
node PVC, including when native history is stored in Ursula. Both volumes are
required for recovery. Native history trimming requires the explicit genesis
opt-in `node.config.external.allow_history_trim`; this does not enable application
expiry. Old `initialize`, `maintenance` and `delivery` values reject.

Additional controller names must be unique across both arrays and base components.
Their `config` is public configuration: signing credentials come from the
mounted Secret's `seed` key. Use separate recorded grants for each responsibility;
creating a Deployment does not grant access to a PID or state resource.
HTTP services listen on port 8080. The chart fixes listener/credential paths and
internal service URLs. Configure `node.config.external.ursula` with bucket,
journal and URL; with chart-managed Ursula its URL is supplied by the chart.
Disable `ursula.enabled` to use an external Ursula provider, or omit
`external.ursula` to use local disk. Set `sql.native.local: false` and
`applications: null` for this external-worker composition. Board requires the
chart's node. Config changes trigger replacement through a checksum; externally
rotated Secrets require an explicit rollout.

For direct Table storage, select local disk and provide `node.table` plus
`node.config.external.table_file: /config/table.json`. The server retains the
first accepted Table configuration and refuses its disappearance or replacement.
The registrar credential path is `/secrets/registrar`. The node PVC retains both
the server installation and local native/Table history. Ursula does not implement
this direct Table hosting profile. Application workers and their provider
controllers retain their independent credentials and placement.

For bounded hot storage with an external cold tier, set
`ursula.existingConfigSecret` to a separately created Secret containing
`ursula.toml`. The chart mounts it read-only instead of generating the default
no-cold-tier ConfigMap; it never reads or copies that Secret into Helm values or
release history. Supply the complete upstream configuration, including listener
`0.0.0.0:8080`, disk WAL at `/data/wal`, explicit hot/cache limits and snapshot/cold
backend settings. Preserve these settings during recovery. The deployment keeps
its PVC and readiness probe; credentials remain available only to Ursula.
The default profile is still disk WAL with inline snapshots and no cold tier.


Supply immutable service images from a matching source or published release.
The [distribution reference](../../../docs/handbook/reference/distribution.md) lists
available component images. This reference chart is not published. The reference launcher
continues to build its own images; the runtime controller additionally needs its
pinned provider CLI. The chart uses the official Ursula image pinned
in [versions.json](../../../deploy/reference/versions.json); the chart check guards
against a different default pin.

## Bootstrap and lifecycle

Choose an explicit Kubernetes context and namespace. Prepare public server
configuration and immutable images in values. Create the node Secret separately
with its `root` seed, then reference it with `node.existingSecret`; private seeds
never belong in Helm values. The [reference launcher](../../../launchers/README.md)
manages this sequence and provisions application grants through the public API.
The server alone creates its internal maintenance and courier grants, retaining
the original signed provisioning requests and receipts across interruption.

```sh
helm upgrade --install transit deploy/reference/chart \
  --kube-context "$TRANSIT_CONTEXT" -n "$TRANSIT_NAMESPACE" --create-namespace \
  -f "$TRANSIT_VALUES" --wait
```

A new absent installation is bootstrapped once. A retained installation always
opens its recorded history; missing history is an error, never permission to
initialize a replacement realm. Native `/health` stays unavailable until the
server verifies required signed courier access and starts its owned roles. An
empty delivery backlog is not a readiness requirement. Current permission loss
withdraws readiness; restart never restores a revoked grant.

Component-era launcher installations and old chart values reject. Preserve their
original binaries, credentials and volumes for recovery with the matching build;
this cutover does not adopt their directories or rewrite their accepted work.

Uninstall preserves a chart-created PVC through Helm's `keep` annotation.
Deleting its namespace, underlying disk, or the claim itself is still destructive.
To reinstall, explicitly reference the retained claim and use the original
server configuration, credentials and recovery identity. Do not bootstrap or substitute a new
root. This retention is an infrastructure safeguard, not a backup/disaster-recovery
procedure or a Transit process-retention policy.

## Security and runtime boundary

Services run as non-root with a read-only root filesystem and dropped
capabilities. Ordinary services receive no service-account token; the optional
controller receives the explicitly projected tokens described below. Credentials
are read-only mounts from existing Secrets; never put private seeds in Helm values,
ConfigMaps, extra-container arguments or release history. Server-owned maintenance
and delivery identities and the external Board identity have distinct grants.

Default NetworkPolicies restrict Ursula ingress to the server pod, and Board egress to Transit and cluster DNS. They require
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
recorded bindings remain necessary. See [deployment](../../../docs/handbook/reference/deployment.md).

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

The [reference launcher](../../../launchers/README.md) provisions the controller's
Transit grants and mounts only its own signing seed. The image includes the
[pinned provider CLI](../../../nix/ate-upgrade/README.md). Its kubeconfig names the
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
workload version change, use the [recorded upgrade protocol](../../../contracts/RUNTIME_SUBSTRATE_V1.md#same-pid-workload-changes);
changing an image in Helm is not sufficient authorization.
