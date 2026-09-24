# Kubernetes and Substrate reference deployment

Owned local M1 recovery/isolation harness, using the versions and official Ursula
image digest in [versions.json](versions.json). The
[deployment design](../../docs/DEPLOYMENT.md) explains authority boundaries;
this runbook explains how to operate the proof. It is not a production installer.

## Prerequisites and lifecycle

The [reference deployment](../../docs/DEPLOYMENT.md) targets Kubernetes and Agent Substrate.
Its Linux x86_64 recovery harness requires a running Docker daemon, Nix, Git,
internet access for pinned images and upstream builds, and enough resources for
a local Substrate installation. It uses pinned Kind Kubernetes with Substrate's
required certificate feature gates and gVisor. K3s compatibility is not claimed.

```sh
nix develop
just board::install
just reference::up
just reference::images
just reference::test
just reference::down
```

Setup creates a uniquely named cluster, local registry, and private kubeconfig
under ignored `.cache/reference/`. It never uses or changes the default context.
Teardown checks recorded Docker identities before deleting owned resources.
Run it after a failed setup/test too. Build caches and proof logs remain for
inspection. Proof directories are private and contain disposable test keys;
do not publish them. The harness compiles the pinned upstream Substrate tools
and runtime, builds Rey's static Zig images, and pulls the official Ursula
release by its [pinned digest](versions.json).

The recovery test creates an isolated namespace and disk-backed Ursula volume,
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

- [Board](../../apps/board/README.md): embedded UI/API, dedicated read grant, origin and session configuration.
- [transit-node](../../apps/transit-node/README.md): bootstrap, storage, HTTP, and maintenance.
- [transit-runtime-controller](../../apps/transit-runtime-controller/README.md): one PID, worker principal, and provider configuration.
- [example-counter](../../examples/counter/README.md): caller and fresh-key bootstrap.
- [Substrate adapter](../../packages/zig/transit-runtime-substrate/README.md): pinned CLI, template validation, and egress policy.

[tests/reference.py](../../tests/reference.py) owns orchestration and fault
injection. Keep version changes deliberate and rerun the recovery/isolation
proof. Ursula uses the official upstream image with explicit disk configuration,
not a separately compiled Nix image. Local Ursula binaries come from the overlay.

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
