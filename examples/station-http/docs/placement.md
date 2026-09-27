# Placement and isolation

`just examples::http` runs native processes with random scoped protocol keys.
`just examples::http-compose` builds static ReleaseSafe Zig images and runs the
same finite application in an owned Docker Compose project. Both use disk Ursula,
explicit fresh ownership, a distinct delivery identity and the same signed CLI
provisioning. Neither touches a running launcher installation.

The checked-in [Compose topology](../docker-compose.yaml) defines three internal
networks and separate mounts:

| Role | Network access | Files |
| --- | --- | --- |
| Caller | Transit client network | Its own seed, immutable body and configuration, read-only |
| Connector | Client and synthetic effect networks | Its scoped seed, versioned credential, CA/configuration read-only; separate activation markers writable |
| Node | Client and storage networks | Node configuration containing public genesis identity only |
| Ursula | Storage network | Store configuration and writable owned WAL |
| Synthetic peer | Effect network | Its own TLS key, fixture secret, configuration and request-count evidence |
| Operator/delivery | Host to private bridge addresses | Separate administrative and delivery seeds |

Containers drop all capabilities, disallow privilege escalation, use read-only
root filesystems and have explicit 2-CPU, 512 MiB and 256-PID limits. The peer is an
independent Python fixture packaged from the pinned Nix closure; the caller and
connector contain only their Zig binaries. Ursula uses the existing pinned image.
No package installation, ambient proxy, or internet access is needed at runtime.

The caller-network probe can reach Transit but cannot open TCP connections to
the peer, Ursula or an external numeric address. The actual connector completes
the TLS request. Callers cannot spawn processes through their scoped protocol
identity. Application containers receive no operator seed, Ursula configuration,
provider credentials or Docker socket. No ports are published: the host operator
uses private bridge addresses, including on Docker versions that disable port
publication for internal-only networks. This profile is qualified on Linux with
a local Docker daemon; remote daemons and Docker Desktop bridge routing are not
qualified.

Each finite invocation gets fresh recorded ownership. The schedule replaces the
caller after submission and proves it returns the same saved call, then restarts
node and store and replays the response after stopping the peer and deleting the
connector credential. The Compose schedule passes in **19.40 seconds** with cached
image preparation; initial compilation/image construction costs are additional.
The native debug schedule passes in **26.81 seconds** excluding compilation.
These measurements are local and do not qualify hosted CI costs.

The task removes only its generated Compose project, temporary state and keys on
exit. Reusable image/build caches remain under `.cache/http-example`. Process
replacement is a trusted operator action over the public growing protocol; this
does not add automatic Substrate binding or supervisor semantics.

## Reference placement

Run `just examples::http-reference` from the Nix environment after
`just launchers reference up` has prepared the owned cluster and pinned runtime
image. The task checks that the saved runtime revision and registry identity
match that infrastructure. It never updates the default installation. The
current profile requires Linux x86_64 and a local Docker daemon.

The existing Transit Helm chart creates a disposable namespace with disk Ursula,
a growing node and a two-worker Substrate pool. A Zig caller runs inside gVisor
with an egress policy allowing only that namespace's Transit authority. It has no
mounted key: each cold start emits a fresh public registration and waits for the
configured exact generation. The operator verifies Actor UID, template UID and
worker assignment before granting that key resource access and Transit ownership.
Provider attribution is an operator input, never execution authority by itself.

The trusted Zig connector runs as a nonroot Kubernetes pod with separate scoped
key/credential/CA Secret mounts and an ephemeral activation directory. A privileged
init step receives only `NET_ADMIN` to install pod-network rules allowing the
node, pinned synthetic peer and cluster DNS. The connector drops all capabilities,
has a read-only root, no service account token and a 1-CPU/512-MiB limit. These
explicit rules are needed because the reference Kind CNI does not enforce
NetworkPolicy. They are a local proof topology, not a general deployment policy.

The real gVisor caller probe reaches Transit and cannot reach the peer, raw Ursula,
Kubernetes/Substrate APIs or an external numeric address. The connector's network
probe reaches Transit and rejects raw storage, both APIs and external egress;
the actual worker subsequently completes TLS to the pinned peer. No caller or
connector receives operator/provider credentials. Host port forwards are owned
by the proof and replaced after node/store pod loss.

The schedule deletes the actual caller worker pod after durable publication,
waits for provider capacity, installs fresh Transit ownership, and requires the
replacement to report the same saved call. It then receives the response, restarts
node/store, removes the credential, stops the peer deployment and replays through
another fresh caller. It checks exactly one remote send and the response digest.
Growing automatic runtime bindings, transferable live connections and automatic
supervision remain unsupported. Logs attach physical timestamps; those timestamps
are excluded when comparing the application result.

Cleanup checks the namespace UID, suspends/deletes owned Actors/templates and
removes only the generated atespace/namespace. A cleanup failure remains visible;
it never authorizes deletion of a different installation. Reusable images stay in
the existing local registry/build cache. Initial image preparation and provider
capacity waits contribute to this task's measured duration.

The complete reference schedule passes in **192.85 seconds** before cleanup.
Namespace/atespace cleanup then completed successfully. The accompanying native
bootstrap regression passes in **29.45 seconds** and Compose in **86.48 seconds**
including changed-image preparation while other proofs ran. These remain local
measurements; they do not establish a hosted feedback budget.
