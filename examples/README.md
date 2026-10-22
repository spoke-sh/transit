# Runnable Transit applications

Start with the [dataset quickstart](../docs/handbook/guides/quickstart.md) to define,
query and evolve a Table through the running server. These examples then show
how to extend Transit's data lifecycle with custom transformations, collaborative
edits, coordination and recorded effects through the public client or Station.
Each directory keeps its entry point and application handler together; no example
is required to run the authority.

The public [workload gallery](../docs/handbook/guides/workload-examples.md) connects these
applications to inspection, telemetry, coordination, research, shared context
and enrichment, with source excerpts across SQL, Python, TypeScript, Rust and Zig.

| Example | Binary | Application behavior |
| --- | --- | --- |
| [Work items](work-items/README.md) | `transit-work-items` | Two-column application with bounded, verified data migration and native disk recovery; generated UI/placements pending |
| [Counter](counter/README.md) | `example-counter` | Add decimal-text integers with checked arithmetic |
| [Byte log](byte-log/README.md) | `example-byte-log` | Concatenate opaque input bytes into bounded state |
| [Station ledger](station-ledger/README.md) | `example-station-ledger` | Three behaviors with Tables, durable calls, Arrow queries, registry and supervision |
| [HTTP caller](station-http/README.md) | `example-station-http` | Immutable request, separate effect worker, correlated outcome and bounded replay |
| [RPC caller](station-grpc/README.md) | `example-station-grpc` | Pinned descriptor, finite protobuf batch, separate effect worker and captured replay |
| [Collaborative Document](station-document/README.md) | `example-station-document` | Two independent structured/text editors, fenced writer, conflicts and resynchronization |
| [State query](state-query/README.md) | `example-state-query` | Finite SQL, persisted original intent, exact signed retry and bounded nested result pages |
| [Signed HTTP service](serving/README.md) | `transit-serving-example` | Two gateways, durable admission, scoped results and fresh worker/disk recovery |
| [Finite Flight](flight/README.md) | `transit-flight-gateway` / `transit-query-host` | TLS Flight SQL with independent PyArrow/ADBC consumers, exact admission retry and physical recovery |
| [Database wire](sql-wire/README.md) | `transit-sql-gateway` / `transit-query-host` | PostgreSQL/MySQL TLS, typed prepared reads/writes and fenced physical recovery |
| [Language callers](station-sdk/README.md) | Per-language examples | Shared Station behavior/Table API across C/C++, Rust, Python, Node, Java, .NET and BEAM |

The [public SDK examples](station-sdk/README.md) share counter/query payload
formats and fixtures. Their owning guides and the proof ledger describe the
implemented language profiles and installed-consumer coverage.

The [Station running guide](station-ledger/docs/running.md) starts a persistent
installation with Board in local, Compose or reference mode. The smaller examples
below expose the raw Transit caller loop without Station.

From the repository root:

```sh
nix develop
just examples::run counter
just examples::run byte-log
```

Each command builds the platform and example binaries, then [local.py](local.py)
starts a fresh disk-backed Ursula and `transit-node` on loopback ports. It creates
random private keys, provisions a PID with a scoped caller grant and ownership,
sends two inputs, runs the actual Zig application, and reads back committed state.
The expected results are `12` and `hello world`. The launcher removes its own
processes, temporary keys and storage on exit; it never connects to an existing
realm or cluster. Python only provisions the demo—the Zig examples execute all
application turns.

For a system that stays up with Board and preserves state across restarts, use
`just launchers::local::up` or `just launchers::compose::up`. The
[launcher guide](../launchers/README.md) owns that workflow; these disposable
examples remain useful for short, isolated demonstrations.

To use an existing development authority, build the examples and supply the
configuration described in their READMEs:

```sh
just examples::build
zig-out/bin/example-counter counter.json
zig-out/bin/example-byte-log byte-log.json
```

`just build::debug apps` installs platform commands (`transit-node`, `transit-runtime-controller`,
`transit-admin`). `just examples::build` installs the Zig example applications. The root
Zig build supplies the counter/byte-log dependency, `transit-client`; no example
imports `transit-core`, Ursula or a deployment provider.

Both examples poll one process, retain the same signed pending request when a
response is uncertain, and stop on stale ownership or a recorded handler failure.
`--once CONFIG.json` commits one input and prints its receipt; an empty mailbox
returns `NoPendingInput`. A finite process first obtains its turn permit. A
transport outage can keep a pending operation retrying; `--once` does not impose
a whole-program deadline or establish that an interrupted commit was rejected.

Optional `publish_to` records an output containing the new state in the same turn.
It requires `publish` permission on the source PID. Delivery is a separate
operation performed by an authorized courier/controller; the examples do not
deliver their own outboxes or execute external effects.

The small execution loops are intentionally visible in each example. Shared
public client operations live in `transit-client`; the ledger shows how Station
builds the higher-level programming interface on those operations.

## How the examples are tested

`just test::callers` launches these same binaries. Fault orchestration and protocol
assertions live under [tests](../tests/callers.py), with an application-independent
[Zig probe](../tests/client_probe.zig). The proof drops commit responses and injects
malformed unavailable replies, checks identical retries and receipts, verifies
atomic output delivery, rejects stale
revisions/owners and unauthorized effects, and restarts disk Ursula and the node.
The probe never performs a successful application turn.

The counter additionally supplies the workload for `just test::service` and the
Kubernetes/Substrate reference proof. See the [client guide](../packages/zig/transit-client/README.md)
and [command reference](../tasks/README.md).
