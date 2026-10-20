# transit-node

The Transit authority executable composes [transit-core](../../packages/zig/transit-core/README.md),
the [Ursula backend](../../packages/zig/transit-backend-ursula/README.md), signed
HTTP ingress and a trusted clock. It validates and commits protocol operations;
application handlers run in callers.

## Build and run

From the repository root in `nix develop`:

```sh
just build::debug apps
zig-out/bin/transit-node CONFIG.json
```

Use the [persistent launchers](../../launchers/README.md), [examples](../../examples/README.md)
or [Kubernetes runbook](../../deploy/reference/README.md) for a complete setup.
The [configuration guide](docs/growing.md) owns fields, operation budgets and
maintenance. [Operations](docs/operations.md) explains bootstrap, clocks and
diagnostics. `profile` is `native_v1`, including when omitted.

## Service boundaries

| Surface | Meaning |
| --- | --- |
| `POST /v1/command` | Signed mutation or reconciliation of an accepted receipt |
| `POST /v1/query` | Signed process, delivery, inspection, resource and snapshot reads |
| `GET /health` | Refresh storage and report role readiness |

The [service contract](../../contracts/SERVICE_V1.md) owns envelopes, signature
domains, errors and transport bounds. The [native contract](../../contracts/TRANSIT_V1.md)
owns paged operations, authorization and exact retry. Current grants apply to
reads and receipt recovery; resource associations do not grant access.
Incompatible histories and saved operations reject under the
[hard-cutover policy](../../docs/reference/versioning.md).

The listener allows 16 connections, four ordinary requests, four notification
waits and two reserved control requests, with 64 sequential exchanges per
connection. Each admitted request owns an execution lane with its own engine,
provider client and bounded caches. Immutable reads and preparation overlap;
conditional journal append serializes accepted successors. A competing
publication can return `Conflict`; uncertain outcomes still require the original
request identity. This does not create independent write shards or establish
per-principal fairness.

A read whose final authority cut races a publication may repeat the same signed
selector at most eight times. Each attempt rechecks signature, current rights and
source identity; sustained contention still returns `Conflict`. Expired cuts,
revocation and other rejections return immediately. A mutation that loses an
ordinary publication CAS can likewise reprepare the exact signed identity and
body at most eight times, revalidating every current grant, generation, sequence
and expected resource revision. Transport/storage uncertainty returns to the
caller without an implicit retry. Hosts use `Client.contended` to distinguish an ordinary conflict
from expiry, fencing or a conflicting request identity, while retaining exact
pending commands through their own bounded scheduling policy.

Run `--maintain` separately for authorized lifetime, collection and checkpoint
work. The [courier](../transit-delivery/README.md) delivers committed outputs via
the public client. The [runtime controller](../transit-runtime-controller/README.md)
reconciles physical placement through Substrate. Workers need neither Ursula
credentials nor provider access.

Command signatures do not encrypt traffic or authenticate response transport.
Use an authenticated TLS boundary outside a trusted private network, and keep
raw storage/provider APIs inaccessible to workloads. [Security](../../docs/reference/security.md)
owns these assumptions; the [proof ledger](../../tests/README.md) records executed
checks and their limits.
