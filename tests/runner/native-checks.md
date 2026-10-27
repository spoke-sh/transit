# Native check scopes

[Runner index](README.md) · [Build registration](../../build/README.md)

`just check native` executes the complete root native check graph. It includes
filesystem work, child processes and injected failures. Use a focused scope while
iterating; the ordinary core lane retains the complete aggregate.

| Command | Registered scope | Execution boundary |
| --- | --- | --- |
| `just check native components` | Compiled package, application and private operation-driver tests | In-process tests, including real local files, spill files, disk reopen, loopback peers and injected storage errors; this is not an in-memory-only profile |
| `just check native fixtures` | Independent declaration/protocol validators and native/port value codecs | Python oracles, compiled codecs and actual host subprocesses; no installed Transit deployment |
| `just check native faults` | Local WAL/object/collection process-death schedules and CLI lifecycle tests | Owned child processes, physical filesystem operations, process termination, publication/recovery and fake-child lifecycle controls |
| `just check native` | All three scopes | Every dependency from the former root test aggregate |

These commands run through the [check runner](checks.py). Each invocation retains
its source identity, original exit status, bounded diagnostic output and completion
record automatically. An unknown scope fails before a build. `just check` itself
lists tasks.

## Find the assertions

The executable grouping is in [checks.zig](../../build/checks.zig). The complete
aggregate depends on all three groups; focused execution does not remove a check
from ordinary CI.

| Native owner | Assertions and I/O to account for |
| --- | --- |
| Protocol, core, client and runtime substrate | Signed requests, authority transitions, uncertainty, ABI ownership and provider identity; client ownership tests start loopback HTTP peers and timers; public provider deployment has separate schedules |
| Catalog, storage and local backend | Definition/policy, WAL/object/Table acceptance, retained roots and actual local filesystem recovery; local node policy is included |
| Query and Fuze | Plans, values, collations, snapshots, Arrow and bounded execution; query spill tests create real files |
| Station, Document and exchange | Application turns, associations, durable continuation, effects and capture semantics |
| HTTP, gRPC, Flight, TLS and serving | Package-level framing, lifecycle and finite adapter behavior; actual remote peers remain interface tasks |
| Board API, telemetry and observability | Read disclosure, stable diagnostics and bounded instrumentation; telemetry tests create temporary sink files |
| Example counter and work-items | Application-owned state/declaration behavior through their actual modules |
| Private operation driver and file diagnostics | Public operation composition and independent diagnostic projections |
| CLI lifecycle and SQL gateway | CLI filesystem/child lifecycle and gateway-local parsing/execution boundaries |

The fixture scope contains the work-item, installation, migration, draft, signing,
unified-source, relational-record, named-record, exchange, worker-handoff,
Document, gRPC and exchange-failure validators, plus the native/port codec oracle.
The fault scope owns [local collection](../storage/local/local_native_collection_faults.py),
[object publication](../storage/local/local_objects.py),
[WAL/object crashes](../storage/local/local_storage_faults.py) and
[CLI lifecycle tests](../../apps/transit-cli/LifecycleTests.zig).

Package manifests remain a separate boundary. `just test packages-build` compiles
every library through its own manifest; `just test packages` executes each
package's complete local target, including additional roots declared by that
package. Neither target is an alias for the root aggregate. Inspect the package's
build file and instructions before selecting a narrower test filter.

Real Ursula, installed SDKs, browser sessions, reference deployments, capacity
faults, formal models and deterministic simulation keep their existing owners in
the [suite inventory](suite.json). These native scopes do not replace them.
