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
does not add automatic Substrate binding or supervisor semantics. Reference
placement is still being qualified separately.
