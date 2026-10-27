# Package and contract execution boundaries

[Runner index](README.md) · [Native scopes](native-checks.md)

Every directory in `packages/zig/` has its own `build.zig` and `build.zig.zon`.
`just test packages-build` compiles each package's `check` target through that
manifest. `just test packages` executes each package's `test` target. These
commands check standalone dependency declarations; compiling a module through
the application's graph does not establish that its package builds independently.

`just test packages-build` uses one worker. `just test packages-build 2` selects
two; the explicit supported range is one to four. Each worker runs `zig build
check` in the owning package, preserving its dependencies and Zig's cache. This
compiles checks; it does not reuse previous test outcomes or start package tests.
The sequential `just test packages` command remains the execution owner.

The [package runner](packages.py) discovers every `packages/zig/*/build.zig`
and requires its manifest. It retains a unique check report and per-package
diagnostics under `.cache/checks/runs/`. Failure stops new work and cancels active
compiler process groups. Interruption joins those processes and leaves the run
incomplete. The [controls](test_packages.py) exercise actual concurrent child
processes, manifest omission, a compiler failure and cancellation.

Reports include worker count, affinity, elapsed time, per-package build-graph
durations and child CPU/I/O resource counters. The maximum child RSS is the
largest observed child value, not the sum of simultaneous resident memory; its
units are those of the host's `getrusage` (KiB on Linux, bytes on macOS). Block
counters are system observations, not an estimate of physical-device throughput.
Compare matching sources/toolchains and cache conditions before changing the
default. Extra concurrency can increase memory and disk pressure.

The root `test-components` scope registers 34 test executions, including 27
package owners, two client roots, examples, applications and private fixtures.
The count is not the number of packages. Imported dependency tests can also be
discovered by Zig; the table describes explicit registration, not an assertion
that all other dependency tests are absent.

## Package roots

Paths in this table are relative to `packages/zig/<owner>/`. The ordinary root
scope is `just check native components`. An em dash means that scope does not
explicitly register this package as a test root. Every row still has its own
standalone `check` and `test` targets. Read the named build file to see the exact
imports, options and extra compilation dependencies.

| Owner | Standalone test roots | Explicit root component registration | Boundary to account for |
| --- | --- | --- | --- |
| `telemetry` | `src/root.zig` | Same module | Bounded sinks, actual temporary output files and instrumentation failure |
| `transit-backend-local` | `src/root.zig` | Separate local catalog and native test roots | Local disk, reopen, retained authority and injected storage failures |
| `transit-backend-ursula` | `src/root.zig` | Same module | Provider adapter framing/cache/queue controls; real disk Ursula has separate process schedules |
| `transit-board-api` | `src/root.zig` | Same module | Read projections, disclosure and independent value interpretation |
| `transit-catalog` | `src/root.zig` | Same module | Definitions, policies, dependencies, local storage and recovery |
| `transit-client` | `src/root.zig`, `src/Abi.zig` | Both modules | Saved identities, owned native handles, real loopback peers and finite waits |
| `transit-config` | `src/root.zig` | — | Typed configuration, bounded inputs and registry rules |
| `transit-core` | `src/root.zig` | Same module | Deterministic signed authority and durable transition semantics |
| `transit-exchange` | `src/root.zig` | Same module | Capture, identity, progress and cleanup |
| `transit-flight` | `src/root.zig` | Same module | Flight framing and finite gateway contracts; real TLS/ADBC peers run separately |
| `transit-fuze` | `src/root.zig`, pinned compute module | Own module | Logical values, physical codecs, collations, execution and Arrow; `test::compute` executes the upstream compute root separately |
| `transit-grpc` | `src/root.zig` | Same module | Framing, bounded RPC and flow-control contracts |
| `transit-http-server` | `src/root.zig` | Same module | HTTP lifecycle, socket scheduling and timer behavior |
| `transit-mysql` | `src/root.zig` | — | MySQL frames, scalar admission and session state |
| `transit-observability` | `src/root.zig` | Same module | Stable instrumentation and bounded diagnostic projections |
| `transit-postgres` | `src/root.zig` | — | PostgreSQL frames, scalar admission and session state |
| `transit-protocol` | `src/root.zig` | Same module | Wire data, signed identities and compatibility rejection |
| `transit-query` | `src/root.zig`, `src/native_catalog_query_test.zig` | Own module only | Plans, bounded codecs, spill/workspace files; the catalog root adds durable authority/recovery assertions |
| `transit-runtime-substrate` | `src/root.zig` | Same module | Provider identity validation; deployment qualification is separate |
| `transit-serving` | `src/root.zig` | Same module | Admission, authorization and finite service recovery |
| `transit-serving-http` | `src/root.zig` | Same module | HTTP adapter ownership and service dispatch boundaries |
| `transit-sql` | `src/root.zig` | — | Session, account and accepted-operation recovery semantics |
| `transit-sql-client` | `src/root.zig` | — | Endpoint validation, actual rendezvous files, Unix sockets and ownership refusal |
| `transit-sql-protocol` | `src/root.zig` | — | Session messages, logical cells and authentication |
| `transit-station` | `src/root.zig` | Same module | Application turns, mailbox contracts and saved continuation |
| `transit-station-app` | `src/root.zig` | Same module | Definitions and recoverable application publication |
| `transit-station-bindings` | `src/Abi.zig` | Same module | Native handles, callbacks, definition checks and owned lifetimes |
| `transit-station-document` | `src/root.zig` | Same module | Document changes, merge and accepted read semantics |
| `transit-station-flight` | `src/root.zig` | Same module | Recorded Flight effects and finite adapter contracts |
| `transit-station-grpc` | `src/root.zig` | Same module | RPC publication and captured results |
| `transit-station-http` | `src/root.zig` | Same module | HTTP framing, effect scope and captured outcomes |
| `transit-storage` | `src/root.zig` | Same module | Real WAL/object/Table files, flush/reopen, compaction and injected I/O failures |
| `transit-tls` | `src/root.zig` | Same module | TLS chain and credential validation |
| `transit-tls-server` | `src/root.zig` | — | Pinned OpenSSL, managed trust files and foreign-chain rejection |

Fuze also exposes `test-relational` with `src/RelationalExecution.zig` as an
independent root and its linked vector kernels. Query exposes `test-unit` and
`test-catalog-query` separately. These additional focused targets are not aliases
for one another. The complete package suite and the root native aggregate must
not be described as equivalent. Package `check` targets can compile exporters as
well as test roots; compilation never proves their runtime assertions.

The process-fault, provider and installed-consumer owners remain in
[suite.json](suite.json). Local SIGKILL schedules, real Ursula, TLS/SQL/Flight
peers, Docker/Kubernetes profiles and browser sessions are separate qualification
boundaries. A component's use of files or sockets does not establish those claims.

## Exporter and validator overlap

An equivalent validation requires the same source/definition, compiler profile,
generator executable and arguments, validator command/arguments, working directory
and expected fixtures. Sharing a schema name or input file is insufficient.
The current compiled contract graph builds nine exporters once per invocation;
the check runner passes their immutable paths to 18 independent checks.

| Overlap | Exact relationship | Execution decision |
| --- | --- | --- |
| `bindings::check` and the core contract profile | Client exporter → `packages/zig/transit-client/generate.py`; Station exporter → `packages/zig/transit-station-bindings/generate.py`; `bindings/generate.py`, all without `--write` | Retain the small repeated validations so the standalone bindings lane remains self-contained. Zig reuses matching compilations; a prior test result is never reused. |
| Work-items in compiled contracts and native fixtures | Both invoke `tests/runtime/application/work_items_contract.py` without arguments through the launcher | Retain the independent contract and native-fixture entry points. This is duplicate validation, not a second assertion family or evidence of broader coverage. |
| Protocol-derived contracts | The protocol exporter supplies native schema, `--diagnostic`, `--data-lifecycle` and `--index-lifecycle` to different validators | Share compilation, retain all four generated outputs and their validators. |
| Installation schema and fixture | One installation exporter runs with no arguments and with `--fixture`; different validators consume the outputs | Retain both; schema drift and canonical fixture bytes are distinct checks. |
| SQL session schema and fixtures | `contracts.py --schema` consumes the compiled exporter; `contracts.py` checks independent fixtures without generator input | Retain both and preserve the standalone contract command. |
| Native installation, migration, draft and signing checks | Native fixtures call separate application/migration/draft/signing validators; their inputs and assertions differ from schema generation | Retain all. Similar names do not establish duplication. |
| Logical schema, native/port codecs and installed codecs | Reflection, independent native/host byte/value vectors and language-owned installed values | Retain each boundary; shared ABI code does not prove language adaptation. |

This audit identifies retained overlap rather than claiming it has disappeared.
Task timings and exact generator/validator stages are recorded by the runner.
Any future consolidation must preserve the independently runnable scopes and
prove their required execution through the task inventory.
