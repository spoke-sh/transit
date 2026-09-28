# Finite Flight example

The [gateway](../../apps/transit-flight-gateway/README.md) composes actual public
Table query hosts and shared finite serving policy. Each owned installation runs
PyArrow 23 and ADBC release 24's Flight SQL driver through verified TLS. The
workload checks 41 nullable full-width integer rows, empty results, count and
checked sum through Python, plus the independent C vtable/Arrow C Stream consumer.

```sh
nix develop
just transit-board::install
just test::flight
just test::flight-faults
just test::flight-outbound
just test::flight-placement compose
just test::flight-placement reference
```

Tasks enter the pinned `flight` tool environment. Native proofs need Docker for
the owned disk-backed Ursula store. Compose uses the checked-in
[topology](docker-compose.yaml) and static Zig images. Reference requires the
existing [reference infrastructure](../../deploy/reference/README.md): it creates
an isolated namespace, registers fresh source/requester Substrate activations,
grants/fences them through public Transit operations and confines gateway egress.
All placements keep the TLS edge on the operator host and require explicit CA
trust. Reference's courier is operator-hosted. These finite demonstrations remove
only their own processes, namespace/project, keys and storage on exit; they do
not update the persistent default launcher installation.

Placement recovery stops workers, gateway, node and disk store, then retrieves
the original ticket and explicitly retries its original request sequence. The
gateway must become reachable through the TLS edge before that read. A ready
pod alone does not establish readiness of its replacement port forward. No
readiness retry creates a new query. The fault proof additionally loses native
acceptance, replaces the gateway, revokes only entry reads after a returned batch,
retires request/source resources and exercises bounded concurrent/slow readers.

[nginx.conf.in](nginx.conf.in) is the bounded HTTP/2 TLS edge used by that proof.
It disables upstream retries and access logs. Deployment CA and hostname checks
are mandatory; [configuration](../../apps/transit-flight-gateway/docs/configuration.md)
describes deadlines, credentials and memory budgets.

The [compatibility matrix](../../packages/zig/transit-flight/docs/compatibility.md)
and [proof ledger](../../tests/README.md#m22-qualification) distinguish
executed combinations from unsupported sources, types and clients. Repeated SQL
with a new `x-transit-request-sequence` is a new query. Preserve the old sequence
and SQL/schema after uncertainty; a fresh access ticket can refer to the same
retained result without reexecution.
