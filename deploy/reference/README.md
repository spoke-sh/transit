# Kubernetes and Substrate reference deployment

Owned local M1 recovery/isolation harness, using the versions and official Ursula
image digest in [versions.json](versions.json). The
[deployment design](../../docs/DEPLOYMENT.md) explains authority boundaries;
this runbook explains how to operate the proof. It is not a production installer.

Commands live under `just launchers::reference`; see the
[launcher guide](../../launchers/README.md) for persistent native and Compose
environments that precede this qualification step. Reference `down` deletes the
owned cluster and its workload volumes; unlike local/Compose `down`, it does
not preserve a running development realm for a later `up`.

## Prerequisites and lifecycle

The [reference deployment](../../docs/DEPLOYMENT.md) targets Kubernetes and Agent Substrate.
Its Linux x86_64 recovery harness requires a running Docker daemon, Nix, Git,
internet access for pinned images and upstream builds, and enough resources for
a local Substrate installation. It uses pinned Kind Kubernetes with Substrate's
required certificate feature gates and gVisor. K3s compatibility is not claimed.

```sh
nix develop
just transit-board::install
just launchers::reference::up
just launchers::reference::images
just launchers::reference::test
just launchers::reference::down
```

Setup creates a uniquely named cluster, local registry, and private kubeconfig
under ignored `.cache/reference/`. It never uses or changes the default context.
Teardown checks recorded Docker identities before deleting owned resources.
Run it after a failed setup/test too. Build caches and proof logs remain for
inspection. Proof directories are private and contain disposable test keys;
do not publish them. The harness compiles the pinned upstream Substrate tools
and runtime, builds Rey's static Zig images, and pulls the official Ursula
release by its [pinned digest](versions.json).

The recovery test installs [charts/transit](../../charts/transit/README.md) in an
isolated namespace, with explicit bootstrap and disk-backed Ursula storage. It
interrupts the controller after Actor creation, replaces a real worker pod, and
restarts Ursula. It checks PID/Actor continuity, fresh worker identity and
ownership generation, ordered state recovery, background expiry, authority
restart, and permanent termination. A separate gVisor probe checks raw Ursula
read/write/admin access, IP/Host spoofing, CONNECT tunnelling, provider APIs,
and absence of control/credential mounts, with a positive Transit reachability
check first. The probe image is test-only.

The manual [reference CI workflow](../../.github/workflows/reference.yml) uses these
commands and always attempts owned-resource cleanup. It requires a separately
registered `rey-reference` Linux x86_64 runner with Nix and Docker; repository
configuration does not provision one. Local execution is the evidence recorded
here, not a claim that the remote workflow has run. That workflow also runs the
separate physical-capacity proof. Evidence and limits are tracked in
[the test guide](../../tests/README.md).

Local unit/protocol tests should remain runnable without a cluster. Passing
those tests does not establish reference-runtime isolation or recovery behavior;
keep cluster checks and their prerequisites explicit. AX is not a dependency.

## Component configuration

The harness wires Board, an authority and separate maintenance process, disk Ursula,
Substrate, a runtime controller, and the counter example. Configuration belongs
to each executable:

- [Board](../../apps/transit-board/README.md): embedded UI/API, dedicated read grant, origin and session configuration.
- [transit-node](../../apps/transit-node/README.md): bootstrap, storage, HTTP, and maintenance.
- [transit-runtime-controller](../../apps/transit-runtime-controller/README.md): one PID, worker principal, and provider configuration.
- [example-counter](../../examples/counter/README.md): caller and fresh-key bootstrap.
- [Substrate adapter](../../packages/zig/transit-runtime-substrate/README.md): pinned CLI, template validation, and egress policy.

[charts/transit](../../charts/transit/README.md) owns the deployed service and
WorkerPool definitions. [reference_chart.py](../../tests/reference_chart.py)
supplies public values and stages storage, explicit initialization, then normal
recovery-only service startup. The workload fixture adds grants and Secrets
before enabling Board and maintenance. It keeps controller fault injection on
the host; the chart does not yet package a controller pod or Substrate itself.

[tests/reference.py](../../tests/reference.py) owns infrastructure setup;
[reference_workload.py](../../tests/reference_workload.py) owns provisioning and
fault injection. Keep version changes deliberate and rerun the recovery/isolation
proof. Ursula uses the official upstream image with explicit disk configuration,
not a separately compiled Nix image. Local Ursula binaries come from the overlay.

## Service diagnostics

The proof configures `LOG_FORMAT=json` and `LOG_LEVEL=info` for Board, node,
maintenance, the host runtime controller and the counter's Actor template.
Change the chart's per-component `logging` values for deployed services, and the
explicit environment entries for the host controller and Actor template. The
local/Compose `REY_*` configuration is not a reference installer API.
Read service stderr through `kubectl logs` with the owned kubeconfig/context,
and controller/provider diagnostics in the private proof directory. Substrate
worker logs remain accessible through its provider log interface; bootstrap
consumers recognize their machine record among diagnostic records.

The owned Kind cluster sets kubelet `containerLogMaxSize=5Mi` and
`containerLogMaxFiles=3`; the proof checks the effective kubelet configuration.
[Kubernetes rotation](https://kubernetes.io/docs/concepts/cluster-administration/logging/#log-rotation)
is periodic and can overshoot its target; `kubectl logs` exposes the current
file, not all rotated history. Pod deletion and cluster teardown remove local
diagnostics. This budget covers CRI container logs, not Substrate's separate
sandbox/log/snapshot storage or the harness's host files. Those retain their
provider/operator lifecycle; no global disk bound or telemetry backend is claimed.

Node ingress accepts validated trace parents only as diagnostic hints; Board's
public ingress still starts a local context. JSON events, metrics and context
have the same meanings as the native and Compose profiles. See
[telemetry](../../packages/zig/telemetry/README.md) for schema, privacy, rate limits
and loss behavior. Probe success is quiet at `info`; failures and lifecycle
changes remain visible independently of the durable protocol history.

## Board qualification

The reference images include the standalone `board` binary. The workload proof
starts it in a separate pod, observes same-PID/fresh-activation worker recovery,
and verifies expiry/state/retained boundaries after Ursula and authority restart.
Only Board's dedicated inspection seed and ingress access key are mounted; no
service-account token or storage/provider credentials are supplied.

Kind's default CNI does not enforce NetworkPolicy. The owned fixture installs
IPv4/IPv6 egress rules in the Board pod namespace from an init container with
NET_ADMIN, then runs Board and its test-only probe without that capability.
Allowed destinations are the Transit service, cluster DNS and local Board for
port-forwarding. A positive Transit check precedes explicit transport-denial
probes against raw Ursula and ready Substrate/Kubernetes endpoints. This proves
the declared fixture, not all CNIs; a deployment needs equivalent enforced policy.
See [the harness](../../tests/reference_board.py) and
[recorded evidence](../../tests/README.md#board-qualification).
