# Query placement and recovery

The example runner reuses the connector/Document physical tooling for static
images, owned storage, Helm resources and Substrate identity checks. Query
binaries import only the public query package. They have no connector, provider
or storage implementation dependency.

Local runs execute the real query source/requester/courier, finite SQL caller,
node and disk Ursula. The fault schedule loses an accepted upload acknowledgement,
restarts the caller with its frozen intent, and rejects a changed SQL recovery
configuration. It also interrupts segment staging and recovers source/requester
under fresh recorded ownership after node/store loss. Current source retirement
must deny a previously completed result.

Compose places source, requester, courier and caller in separate containers on a
private client network. Each mounts only its own credential/configuration and
recovery directory. Only Transit joins the storage network. Services use static
Zig binaries, read-only roots, dropped capabilities and explicit process, CPU and
memory limits. The network probe checks authority reachability and denies Ursula,
MinIO and external TCP access.

Reference places the source and requester as separate Substrate/gVisor actors.
Each generates an ephemeral key, emits a public registration and waits for its
exact configured ownership generation. The operator validates actor, template
and worker identities, grants that key its PID and resource scope, then records
fresh ownership. Source request-resource association and independent read rights
remain required. The caller and courier run in the trusted operator process with
separate non-root credentials; they do not gain worker execution rights. This
profile does not add automatic growing runtime bindings or a query controller.

The reference probe checks the same storage/external targets plus Kubernetes and
Substrate control APIs. The source's actual physical worker is killed after a
committed intermediate segment, then both logical query hosts recover with new
keys and generations. Source pin and call identity survive. Node/store recovery
holds Deployments at zero until the disk service is ready; an early Kubernetes
replacement cannot race the recovery schedule. Ursula's private configuration
comes from a Secret, outside Helm values and ConfigMaps. Namespace deletion checks
its recorded UID. All runs preserve the original logical query and verify final
coverage, released source versions and permanent source retirement.

These tasks are finite recovery/isolation proofs, not production launchers,
throughput benchmarks or host/region-loss guarantees. Document setup may be much
slower because it seeds accepted changes through the public Document service.
The proof ledger records each measured profile; no source/profile combination is
qualified by another combination's result.
