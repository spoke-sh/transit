# Transit Helm chart

[Transit](../../docs/TRANSIT.md) is the streaming runtime subsystem. This chart
packages its current single-realm deployment: a node, disk-backed Ursula,
optional maintenance, optional [Board](../../apps/board/README.md), and optional
Agent Substrate worker capacity. Rey is the containing monorepo and application
context; it is not the chart's name.

The [reference proof](../../deploy/reference/README.md) installs this chart and
qualifies controller/worker recovery, persistent storage, maintenance, and Board
isolation. This is the experimental M1/M2 profile, not an HA production installer.

## Resources and values

Read [values.yaml](values.yaml) for defaults and [values.schema.json](values.schema.json)
for deployment-level validation. Application configuration remains owned by the
[node](../../apps/transit-node/README.md) and [Board](../../apps/board/README.md)
and validated by their binaries; the chart does not duplicate those schemas.

| Component | Resources and configuration |
| --- | --- |
| `node` | One Recreate Deployment, private ClusterIP Service, JSON ConfigMap. Supply `node.image` and `node.config`, including the trusted public genesis. |
| `ursula` | One Recreate Deployment, private Service, disk-WAL ConfigMap and retained PVC. Uses the official pinned image. Supply `persistence.existingClaim` to reuse storage; otherwise `size` and optional `storageClass` configure a new claim. |
| `initialize` | Explicit one-time Job using the node image/config. Disabled by default and never an automatic Helm hook. |
| `maintenance` | Optional separate single-replica Deployment and ConfigMap. Supply `existingSecret` containing `seed` and `config.principal` with its recorded admin/effect grant. Uses the node image with `--maintain`. |
| `board` | Optional Deployment, private Service and ConfigMap. Supply `image`, `existingSecret` containing `seed` and `access`, and `config` with realm, inspection principal and public origin. |
| `workerPool` | Optional Substrate WorkerPool. Supply `spec` and any workload selector labels. Requires the pinned Substrate CRD/controller already installed. |

Names default to `<release>-<component>` and can be overridden per component.
All services listen on port 8080. The chart fixes listener/credential paths and
sets internal service URLs; disable Ursula and provide `node.config.ursula_url`
for an external backend. Board requires the chart's node. Log level/format and
resource requests/limits are per component. Config changes trigger replacement
through a checksum; externally rotated Secrets require an explicit rollout.

Supply immutable service images built from the consuming project's release.
The reference builds and pushes its own images; this repository does not yet
publish Transit/Board release images. It uses the official Ursula image pinned
in [versions.json](../../deploy/reference/versions.json); the chart check guards
against a different default pin.

## Bootstrap and lifecycle

Choose an explicit Kubernetes context and namespace. Prepare a private values
file with the public genesis, node image, bucket/journal and any desired options.
Keep the root seed outside Helm. Generate its public key with `rey-cli public-key`
as described in the [CLI guide](../../apps/rey-cli/README.md). Create Board and
maintenance Secrets separately, and record their grants through the signed
Transit API before enabling either service. The chart creates no principals,
grants, example processes, Actor templates or runtime bindings.

With `TRANSIT_CONTEXT`, `TRANSIT_NAMESPACE` and `TRANSIT_VALUES` pointing to that
context, namespace and values file, install a **new** realm in three phases:

```sh
# Wait for storage before bootstrap. Keep Board and maintenance disabled.
helm upgrade --install transit charts/transit \
  --kube-context "$TRANSIT_CONTEXT" -n "$TRANSIT_NAMESPACE" --create-namespace \
  -f "$TRANSIT_VALUES" --set node.enabled=false,initialize.enabled=false,board.enabled=false,maintenance.enabled=false --wait

# Deliberately initialize once; the job fails rather than hiding a failure.
helm upgrade transit charts/transit \
  --kube-context "$TRANSIT_CONTEXT" -n "$TRANSIT_NAMESPACE" \
  -f "$TRANSIT_VALUES" --set node.enabled=false,initialize.enabled=true,board.enabled=false,maintenance.enabled=false --wait --wait-for-jobs

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

Services run without a service-account token, as non-root, with a read-only root
filesystem and dropped capabilities. Credentials are read-only mounts from
existing Secrets; never put private seeds or Board access keys in Helm values,
ConfigMaps, extra-container arguments or release history. The initializer needs
only public genesis. Maintenance and Board receive distinct credentials.

Default NetworkPolicies restrict Ursula ingress to node, maintenance and
initialization pods, and Board egress to Transit and cluster DNS. They require
an enforcing CNI; rendered policy alone does not establish isolation. Review DNS
selectors for your cluster and enforce equivalent restrictions around external
Ursula. Node/controller services are trusted control infrastructure. Services
are ClusterIP-only; TLS ingress, browser access, and authentication provisioning
remain deployment responsibilities. No public ingress or telemetry collector is
installed. A Board health probe preserves the configured public Host.

The Kind reference supplies `board.extraInitContainers` and `extraContainers`
for enforced pod-namespace egress and denial probes because its CNI does not
enforce NetworkPolicy. These are explicit test-fixture extensions, empty by
default. Do not copy their privileged network initializer into a different
architecture without reviewing its boundary.

Substrate itself is installed separately from its pinned upstream source.
The reference runs `transit-runtime-controller` on the host with an explicit
kubeconfig/provider tool and kills it to test reconciliation. This chart does
not yet package that controller as a pod, install provider-wide RBAC, or turn
`example-counter` into a required runtime component. WorkerPool capacity alone
does not authorize or launch a Transit process; Actor templates, grants and
recorded bindings remain necessary. See [deployment](../../docs/DEPLOYMENT.md).

## Validation

```sh
just test::deployments
# With Linux/Docker and the reference prerequisites:
just launchers::reference::up
just launchers::reference::images
just launchers::reference::test
just launchers::reference::down
```

The first command renders and lints representative values, checks credential,
bootstrap, storage and network boundaries, and rejects unsupported configuration.
It runs in `just ci`. The reference uses the checked-in chart for real resources;
its Python fixture supplies values, credentials, protocol operations and faults.
