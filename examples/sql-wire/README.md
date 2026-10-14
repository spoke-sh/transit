# Database wire deployment

The SQL gateway serves verified PostgreSQL and MySQL TLS over one explicitly
provisioned Table catalog. This example runs the actual Zig gateway, Catalog
host, native authority and disk-backed Ursula. PostgreSQL/Psycopg and Oracle
MySQL Connector/Python exercise prepared values, all six wire types, NULL-capable
metadata and committed row counts. Both protocols read the same Table.

From this checkout's pinned developer environment:

```sh
just test::sql-wire-placement compose
just test::sql-wire-placement reference
```

The reference command requires the owned Kubernetes/Substrate infrastructure
and runtime image described in the [reference runbook](../../deploy/reference/README.md).
The runner creates and removes its own namespace and resources; it does not adopt
another application's namespace. Compose publishes database and readiness ports
on random IPv4 loopback ports. The reference runner uses private Services and
loopback port forwards. Each run generates a temporary localhost certificate and
private fixture credentials. Those credentials are examples, not installation
defaults.

The gateway image carries the pinned Nix OpenSSL runtime closure. It runs as a
non-root process with a read-only root, bounded CPU/memory, dropped capabilities
and no storage credentials. Its configuration mounts only the selected account
keys, verifier and TLS certificate/key. The operator key remains outside the
service. Compose isolates storage on a separate internal network. The reference
gateway has no service-account token; an init container constrains egress to the
authority and cluster DNS, then an independent probe verifies denial of storage,
Kubernetes, Substrate and public endpoints. The Catalog host runs in Substrate
with its own native activation and authority-only egress policy.

Activation markers reside on a persistent private bind mount in Compose and a
ReadWriteOnce PVC in Kubernetes. Spill is separate and disposable. After checking
the initial rows, the runner stops the gateway, Catalog host, courier, node and
store. It recovers the same durable storage, establishes fresh native ownership
generations and starts replacement executors. The clients verify the retained
row before applying another mutation. A readiness probe, PVC or pod identity
never grants native ownership.

The [gateway guide](../../apps/transit-sql-gateway/docs/configuration.md) owns
configuration, initialization, signed controls, quota and drain semantics. The
[wire contract](../../contracts/SQL_GATEWAY_V1.md) owns the supported SQL and
protocol profile. The [proof ledger](../../tests/README.md#database-wire-gateway)
distinguishes executed local, driver, fault and deployment checks. This example
does not provide automatic provider-managed gateway activation, arbitrary
cluster support, transactions, ORM metadata or an external load balancer.
