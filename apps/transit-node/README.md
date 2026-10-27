# transit-node

The Transit authority executable composes [transit-core](../../packages/zig/transit-core/README.md),
the configured [local](../../packages/zig/transit-backend-local/README.md) or
[Ursula](../../packages/zig/transit-backend-ursula/README.md) storage backend, signed
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
| `POST /v1/payload` | Authenticated standalone byte publication, original verification and reads on the local owner |
| `POST /table/v1` | Signed direct Table operations when the local `table` owner is configured |
| `GET /health` | Refresh storage and report role readiness |

The [service contract](../../contracts/SERVICE_V1.md) owns envelopes, signature
domains, errors and transport bounds. The [native contract](../../contracts/TRANSIT_V1.md)
owns paged operations, authorization and exact retry. Current grants apply to
reads and receipt recovery; resource associations do not grant access.
Incompatible histories and saved operations reject under the
[hard-cutover policy](../../docs/handbook/reference/versioning.md).

The listener allows 16 connections, four ordinary requests, four notification
waits and two reserved control requests, with 64 sequential exchanges per
connection. Each admitted request owns an execution lane with its own engine,
provider state and bounded caches. Immutable reads and preparation overlap;
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

With Ursula storage, run `--maintain` separately for authorized lifetime,
collection and checkpoint work. With local storage, the `maintenance` setting
runs lifecycle scans, accepted-floor trimming and configured automatic Table
flushing inside the node's exclusive owner; a separate `--maintain` process rejects. Local immutable objects remain
retained. The local launcher selects this backend. Configured Table operations
use the separate direct Table owner; native process, KV and Document state retain
their paged native commit boundary. The
[courier](../transit-delivery/README.md) delivers committed outputs via
the public client. The [runtime controller](../transit-runtime-controller/README.md)
reconciles physical placement through Substrate. Workers need neither Ursula
credentials nor provider access.

`LocalCatalogPolicy` connects the internal direct catalog component to the same
native role graph, credential checks and resource lifetime fence. It verifies
the original caller's signed request context and the registered domain bindings;
it supplies no new grant store. `LocalCatalogRunner` resumes explicit CREATE execution through the
existing native registration ledger. It prepares each native step, checks the
original caller again, then commits only against that checked native head.
Inspection does not run this helper. `just test::local-catalog` exercises this
composition with real signed native changes and local disk storage.

`LocalTableService` dispatches the [signed direct Table contract](../../contracts/DIRECT_TABLE_V1.md)
inside that owner. The composition test drives declaration admission/execution,
binary row writes, retained reads and release through its serialized envelopes.
The dispatcher checks current rights after buffering the response; a concurrent
revocation suppresses disclosure. The local `table` setting exposes this dispatcher
at `/table/v1`. The local launcher configures this owner for its default Tables;
the shared SQL session, captured queries and direct catalog SDK adapters use
the same signed direct operations. The [catalog caller guide](../../packages/zig/transit-catalog/README.md)
describes the typed operations and host boundary; the [SDK reference](../../docs/handbook/reference/sdks.md)
owns language coverage.

`LocalTableHost` validates the complete catalog history before readiness and
retains one owned root/chain value across its request lanes. Each request checks
that accepted boundary, current directory roots and any newer records before
using the catalog. The value holds no grants or response buffers; signed native
authorization and final disclosure checks remain current. Object-scoped requests
and automatic flushing also reuse up to 64 validated Table root/chain hints,
rechecking the accepted boundary and newer history on every open. Lock-stripe
collisions evict volatile hints; they do not limit durable Table count or release
pins. A failed request clears its Table hint. Replacement repeats full recovery.
See the [catalog recovery guide](../../packages/zig/transit-catalog/docs/direct-catalog.md#bounds-and-remaining-integration)
for the immutable-history assumption and failure boundaries.

Command signatures do not encrypt traffic or authenticate response transport.
Use an authenticated TLS boundary outside a trusted private network, and keep
raw storage/provider APIs inaccessible to workloads. [Security](../../docs/handbook/reference/security.md)
owns these assumptions; the [proof ledger](../../docs/history/qualification/README.md) records executed
checks and their limits.
