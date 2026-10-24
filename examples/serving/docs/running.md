# Running the signed service

Enter the pinned project environment and run the owned fixture for the desired
placement:

```sh
nix develop
just test::serving
just examples::serving-compose
just examples::serving-reference
```

The first command runs native processes with a local directory containing native
history and direct Table logs/objects. Compose builds static
images from the checked-out sources and isolates client traffic from storage.
The reference command requires the existing Kind/Substrate infrastructure and
matching runtime image described in the [reference launcher guide](../../../launchers/README.md#run-the-reference-installation).
It creates a new `transit-serving-*` namespace, a separate worker pool and a
persistent volume for the native and direct Table owners. It never adopts or updates the default installation.
The physical fixtures also start isolated Ursula and pinned native MinIO targets
for storage-network denial probes. Those targets do not store this example's
Table or native history. Caller/gateway egress probes include their exact
endpoints; those processes grant no Transit access.
Each command runs the demonstration and recovery assertions, then removes only
its own processes, containers, namespace and temporary credentials.

The examples provision an administrator, authenticated timer observer, two Station
owners, a separately read-authorized gateway and an explicit service caller.
They create the counter Table through the direct catalog client, wait for
authorized discovery, then initialize the ingress and application privately before
publishing the service binding and listeners. The initializer has an ordinary LOGIN owner role. Reactive callers
receive native CONNECT, USAGE and SELECT grants, with creator-scoped defaults
applied when the Table is published. The application worker receives SET-only
membership in the owner role. The physical recovery schedule stops delivery
before accepting its test call. The Table is a non-trading integer counter; there
are no external effects or callback destinations.

The fixtures configure a native admission ceiling of 50,000 positions with 2,000
reserved for control/recovery, in addition to the service's active-operation and
per-caller limits. Capacity pressure refuses work and never expires history.
These are demonstration budgets; deployment operators must size disk storage
and explicit admission headroom for their own retained workload.

Two independent gateways expose the same service. The caller prepares and retains
one signed native send, races it through both gateways, and saves its ingress
receipt. The runner stops before outbox delivery, replaces physical workers,
gateways and node while preserving its local files, then retries the original bytes and resumes
public outbox delivery. It checks the exact once-only counter result, unchanged
recovery after publication retirement, and denial after current policy revocation.
The [proof ledger](../../../tests/README.md) records the executed profiles and
costs. Evidence from the earlier actor Table owner does not qualify this direct
Table configuration; each physical placement must be run against the current artifacts.

Compose workers preserve activation markers and receive a fresh ownership
generation on replacement. Substrate workers generate fresh in-memory keys and
emit public bootstrap registrations. The trusted operator attributes each
registration to the selected Actor, checks its realm/principal/PID/generation,
reissues native and resource grants, and records exact ownership. Old keys,
generations, snapshots and socket state cannot authorize replacement execution.
This is operator placement, not automatic growing-profile runtime reconciliation.

Both physical examples use the pinned [TLS terminator](termination.md) on the
operator host. Its private backend is the isolated Docker bridge or a Kubernetes
port-forward; the latter also remains within the trusted operator boundary.
Gateways hold read credentials in private files/Secrets and cannot own a process.
The reference gateway pod installs egress rules before startup and independently
probes that authority is reachable while storage, cold storage, the public
network, Kubernetes and Substrate APIs are denied. No service-account token is
mounted. Substrate workers retain their existing authority-only egress policy.

For a custom deployment, build `transit-serving-example` and supply its
[configuration](../README.md). Persist the owning Station resource and native
caller identity; retain prepared signed commands before sending. A 202 response
means ingress acceptance only. Poll authorized status/result reads for the durable
application outcome. On interruption retry the exact request; do not create a new
operation or signing sequence to hide uncertainty. Retirement, explicit cancel,
finite expiry and socket failure remain separate outcomes.
