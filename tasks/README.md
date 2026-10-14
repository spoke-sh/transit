# Repository commands

Run commands from the repository root inside `nix develop`.

## Task interface

The root [justfile](../justfile) keeps common commands: `check`, `ci-clean`,
`fmt`, and `doctor`. Modules under `tasks/` own the grouped recipes:
[build](build.just), [launchers](launchers.just), [test](test.just),
[examples](examples.just), [contract](contract.just), [ci](ci.just),
[bindings](bindings.just), [transit-board](transit-board.just), and
[transit-docs](transit-docs.just).
Use double colons, for example `just launchers::reference::up` or `just examples::run counter`.
Space-separated module paths also work: `just build debug` is equivalent to
`just build::debug`.

`just` lists common commands and namespaces. `just launchers` lists environment
groups; `just launchers::local` or `just --list launchers local` lists one
environment's recipes. Most bare module commands list tasks; `just ci` is the
exception and runs the complete local suite. `just test` lists the test recipes; use
`just test::unit` to run unit tests. `just --list --list-submodules` shows the full
tree.

Each module explicitly sets the strict Bash shell and repository-root working
directory. Recipes work from repository subdirectories after entering the dev
shell. `just ci` uses the same timed task inventory as the hosted lanes;
reference deployment and physical-capacity tests remain explicit commands.

| Command | What it does today |
| --- | --- |
| `just` | Lists available recipes |
| `just doctor` | Prints tool versions, including Ursula and Kubernetes tooling, without contacting a cluster |
| `just check` | Checks Nix/Zig formatting, tooling, Zig unit tests, Transit/Board contract drift, frontend formatting/lint/types/tests, local Markdown links, and diff whitespace; install locked frontend dependencies first |
| `just ci` | Loads the pinned bindings shell and runs foundation, package, recovery, Board/frontend, local launcher and language checks |
| `just ci::core`, `just ci::experience`, `just ci::bindings`, `just ci::browser` | Run individual hosted lanes with task timings; select the matching shell, and install the browser before its proof |
| `just ci::growth`, `just ci::launchers` | Run the growing-state and launcher/build-smoke lanes from the same inventory |
| `just ci::cost RUN_ID` | Collect a completed hosted run's setup/check/cache cost and compare it with the declared CI budgets; requires authenticated `gh` |
| `just ci-clean` | Requires committed changes; clones HEAD into a temporary directory, installs locked frontend dependencies and runs the `just ci` inventory without existing workspace outputs |
| `just ci-clean --lane NAME` | Runs one inventory lane in its own clean checkout; complete ordinary qualification needs all five lane reports at the same committed revision |
| `just bindings::query-failures` | Verify installed typed query-failure callbacks, lost receipts and duplicate suppression after replacement; build language artifacts first; select an adapter family with `--family` |
| `just bindings::node-check` | Builds the raw Node client declarations/runtime exports, then checks Station types and host scope/runner units; no pre-existing SDK build is required |
| `just fmt` | Formats Nix, Zig and frontend source/Markdown; contract regeneration stays explicit |
| `just build` | Lists Zig build profiles |
| `just build::debug`, `just build::release-safe`, `just build::release-fast`, `just build::release-small` | Builds platform executables and embedded Board with the selected optimization profile; accepts Zig steps/options |
| `just examples::build` | Installs `example-counter` and `example-byte-log` |
| `just examples::run counter`, `just examples::run byte-log` | Provisions disposable disk Ursula and an authority, runs the real example, and verifies its committed state |
| `just transit-board::install`, `just transit-board::demo` | Install locked frontend dependencies and inspect a disposable counter realm |
| `just transit-board::build`, `just transit-board::run CONFIG` | Build the embedded binary and run a provisioned installation |
| `just transit-board::generate`, `just transit-board::contract`, `just transit-board::check` | Generate/check OpenAPI and browser models, then validate frontend formatting/lint/types/tests |
| `just transit-board::fmt` | Formats frontend source and Markdown using the same Vite+ configuration as the checks |
| `just transit-board::test`, `just transit-board::browser-install`, `just transit-board::browser` | Qualify the real API and install/run the pinned browser proof |
| `just launchers::local::up`, `status`, `inspect`, `logs SERVICE`, `attach` | Run a persistent native system with foreground logs and Ctrl-C shutdown; `up --detach` starts in the background, `logs manager` shows lifecycle/probe evidence |
| `just launchers::compose::up`, `status`, `inspect`, `logs SERVICE` | Run the same scenario in Docker containers with foreground logs and Ctrl-C shutdown; `up --detach` starts in the background |
| `just launchers::local::send VALUE [REQUEST_ID]`, `restart SERVICE` | Admit example input through signed ingress or replace a service; Compose has the same tasks |
| `just launchers::local::down`, `reset` | Stop while preserving data, or explicitly delete a stopped installation; Compose has the same tasks |
| `just launchers::local::test`, `just launchers::compose::test` | Qualify persistence, duplicate-safe provisioning, fresh ownership and missing-store refusal in isolated installations |
| `just transit-board::query-test`, `just transit-board::query-browser` | Qualify the optional growing query API and real Canvas/Browse workspace, exact integers and live revocation |
| `just test::public-query` | Exercise the real query shell/hosts, exact retry, fenced recovery and current authorization over disk Ursula |
| `just test::named-relational` | Check independent named-query records, separate publication/authorization/activation and captured/maintained native recovery on disk |
| `just test::grpc-control` | Focus finite work expiry and bounded closure with an active blocked RPC; also included in `test::grpc-faults` |
| `just test::sql-wire-contracts` | Check bounded PostgreSQL/MySQL framing, cycle admission, scalar type admission and SCRAM against independent credential derivation; included in core CI |
| `just test::sql-wire-reference`, `just test::sql-wire-tls` | Use the pinned SQL-wire shell to qualify upstream driver exchanges and the standalone Zig TLS transport |
| `just test::sql-gateway` | Exercise signed gateway controls and coordinator recovery through native owners on disk-backed Ursula; included in growth CI |
| `just test::sql-wire-gateway` | Exercise the real TLS gateway with pinned PostgreSQL/MySQL CLI, C and Python clients, signed controls, socket faults and fenced restart; included in growth CI |
| `just test::flight` | Qualify native TLS Flight SQL through pinned PyArrow and ADBC Python/C consumers |
| `just test::flight-outbound` | Record a TLS Flight effect through the RPC worker and replay typed Arrow after node/store loss with the peer stopped |
| `just test::unified-query` | Run signed v1 source/requester recovery fixtures; optionally select a source with `-Dunified-source=kv`, `table` or `document` |
| `just test::server` | Exercise the native local server and independent console, with disk providers, fresh worker activations and owned process failures |
| `just test::cli-diagnostics` | Check real CLI errors, argument/file/field/listener coordinates, next steps, privacy and stdout/stderr separation without starting services; included in `just check` |
| `just test::diagnostic-inventory` | Detect changes to qualified outcome types, error declarations/returns, literal causes, propagation, imports and grammar; excludes dependency caches |
| `just test::diagnostic-mappings` | Require reviewed stable compiler codes and explicit boundary exceptions independently of inventory recording; owning executable cases run through `test::unit` |
| `just test::diagnostic-outcomes` | Execute retained outcome mappings, fact provenance and exact recovery actions against reviewed expectations. |
| `just test::console-history` | Check real PTY reverse search, SQL/dot-command persistence, concurrent consoles, malformed records and file-failure fallback; included in `just check` |
| `just test::console-latency [--single --resident-pages N --worker-interval-ms N]` | Measure idle CPU and empty-Table SQL with frozen ReleaseSafe executables and isolated disk providers; optional cache/polling controls, no latency threshold |
| `just test::server-board`, `just test::server-board-package` | Qualify default embedded Board, explicit headless operation, retained inspection grants, recovery and the Nix downstream manifest |
| `just test::server-faults` | Add interrupted provisioning, native gateway denial/capacity and negative provider-rollback checks |
| `just test::server-capacity` | Fill a newly allocated ext4 image to real ENOSPC, preserve accepted query identity and recover the same installation |
| `just test::unified-codec` | Check independent v1 bundles and nested Arrow through the native library and local port |
| `just test::unified-counts [-Dunified-source=kv -Dunified-sdk=python,node,...]` | Extend the signed query rig with partial COUNT progress, exact saved upload retry, worker/node/store restart, current denial, cancellation and installed manifest counters; add `-Dunified-shell=true` for actual SQL-shell COUNT recovery; SDK artifacts must already be built |
| `just bindings::connector-preparation` | Preserve accepted HTTP/gRPC preparation failures after lost failure-input receipts, corrected configuration, worker/node/store restart and retirement; installed Python evidence reads require current grants and dispatch nothing |
| `just bindings::unified-codecs` | Build all ten SDKs and verify installed codec consumers against independent default/named bundles and Arrow; no service or recovery claim |
| `just bindings::unified-compound` | Build all ten SDKs and run filtering Boolean programs through installed callers and the SQL shell across KV, Table and Document, including exact retry, disk restart, current denial and retirement |
| `just test::document` | Qualify Document change/checkpoint publication, exact retries, current-policy reads and bounded cleanup through worker/node/store loss |
| `just test::publication` | Qualify 64 KiB immutable records, bounded staging/cleanup, exact retry and worker/node/store recovery |
| `just test::unit` | Runs Zig unit/protocol tests without a service |
| `just test::build` | Compiles application/probe entry points separately from unit tests; included in core CI |
| `just test::sql` | Compare Zig/ANTLR/PostgreSQL ASTs, durable plan encodings and independently decoded paged Arrow results |
| `just test::declarative-benchmark [--rows N --samples N --output PATH]` | Verify and measure synthetic declarative components; report all TPC-C/E/H/DS workload blockers; see [benchmark tooling](../tests/benchmarks/README.md) |
| `just test::sql-benchmark [--samples N --output PATH]` | Record pure ReleaseSafe compiler and paged count/sum costs with raw samples and binary provenance |
| `just test::table-query-writer [--sdk LANGUAGE ...]` | Exercise separate catalog initialization/delegation, lost receipts and disk recovery, retained query cuts across same-namespace Table mutations, and independent query/write policies; optionally use installed catalog SDKs |
| `just test::catalog [--sdk python\|node\|rust\|ruby ...]` | Prove atomic named Table creation, shared Zig/C ABI/native-port/CLI callers, supplied-host initialization/creation receipt recovery after disk restart, conditional policy/disposition outcomes, fresh ownership and current native grants |
| `just test::relational-maintenance` | Prove complete Table-history bases, independent finite/delta agreement, exact resume and disk/cold-store recovery under bounded resident storage |
| `just test::relational-exchanges` | Compare explicit producer layouts with the independent oracle through bounded native exchanges, exact receipt recovery, worker replacement and maintained publication on disk |
| `just test::relational-capacity` | Fill an owned ext4 image to real ENOSPC during captured and exchange work; release a physical reserve and recover the exact query/checkpoint before completing the oracle result |
| `just test::catalog-growth` | Create 65 additional Tables on disk with eight resident pages; check nine ordered metadata pages, changed cursors, current disclosure rights and node/store restart; larger counts use `test::catalog --grow N` |
| `just bindings::catalog-python` | Build/install Python wheels outside the checkout; prove typed sync/async catalog controls, exact creation recovery and current denial, plus value/response/cancellation checks |
| `just bindings::catalog-node` | Build/install TypeScript packages outside the checkout; validate generated boundaries, bigint values, exact saved catalog recovery and current denial |
| `just bindings::relational-node`, `just bindings::relational-python` | Build/install interactive relational callers outside the checkout; compare exact plans and rows with Zig across one/two-resource routes, repeated pages, current denial, host loss and ordered overflow |
| `just transit-board::relational-browser` | Run the real relational Board API and browser against disk Ursula; prove explicit execution, a lost open response, browser reload without rerun, exact coverage and current denial |
| `just bindings::catalog-rust` | Build/install Rust crates outside the checkout; verify exclusive caller borrows, full-width values, malformed receipt uncertainty and saved catalog recovery |
| `just bindings::catalog-ruby` | Build/install Ruby gems outside the checkout; verify frozen values, saved catalog recovery, malformed-child uncertainty and joined cancellation |
| `just bindings::catalog-c` | Build/install C11/C++17 packages; verify owned values, copied-owner rejection, exact saved catalog recovery and current denial |
| `just bindings::catalog-java` | Build/install Java JARs; verify immutable values, exact catalog recovery, uncertain replies and joined native-port cancellation |
| `just bindings::catalog-dotnet` | Build/install .NET NuGets; verify immutable values, exact catalog recovery, strict receipt decoding and joined native ABI read cancellation |
| `just bindings::catalog-beam` | Build/install Erlang/Elixir OTP applications; verify immutable values, exact catalog recovery, malformed replies and joined waiting-process loss |
| `just test::sql-grammar`, `just test::sql-rewrites` | Regenerate the SQL reference parser, compare covered PostgreSQL ASTs, and type-check named Lean proofs with pinned optional tools |
| `just test::table-ddl-sql` | Compare general Table DDL with independent aliases, defaults, keys, schema bytes and selected evolution semantics |
| `just test::table-dml-sql` | Compare general Table DML with independent PostgreSQL/ANTLR ASTs and exact typed intent bytes; no native admission claim |
| `just test::model [--tail N]` | Checks the finite TLA+ model, removed guards and concrete Zig counterexample schedules |
| `just test::codecs [--fuzz=1000]` | Runs bounded signed JSON/frame corpora and allocation checks; optionally explores with LLVM fuzz coverage |
| `just test::mutations` | Uses isolated committed clones to verify detection of omitted Zig guards |
| `just test::scheduler-simulation`, `just test::scheduler-simulation-mutations` | Schedule shared Session/courier calls with request/reply loss, ownership, trusted time and mutation controls |
| `just test::domain-simulation`, `just test::domain-simulation-mutations` | Replay bounded Document, Exchange, refresh, runtime and catalog contract schedules and qualify their assertions with real-code mutations |
| `just test::vortex [--seed N --rounds N]` | Inject external network/process faults into owned node, worker, courier and disk Ursula; preserve histories and cleanup evidence |
| `just test::vortex-profile sdk\|application\|query\|reactive\|discovery` | Qualify selected external hosts/lifecycles, or run the separate expanded discovery campaign with retained stage outcomes and finite limits |
| `just test::resource-simulation-smoke`, `just test::resource-simulation [--seeds N --exhaustive]` | Replay saved page faults or enumerate numbered staging/read/publication/trim interruptions with an independent resource oracle |
| `just test::resource-simulation-mutations` | Detect omitted resource writes and input progress in isolated committed core mutants |
| `just test::properties [--seeds N --steps N]` | Runs saved and generated authority schedules; failures retain a minimized replay trace |
| `just test::simulation [--seeds N --steps N]` | Runs multi-process authority/delivery schedules, independent recovery comparisons and bounded progress with identical replay |
| `just test::simulation-mutations` | Checks committed-source delivery-order/provenance mutants in isolated clones |
| `just test::growing-quota` | Checks service/Station admission refusal, retained backlog and reserve exhaustion across disk restart |
| `just test::growing-capacity` | Uses an owned Docker/ext4 fixture to qualify growing pages, ENOSPC, physical reserve release and control/recovery progress |
| `just test::pages [--keys N --cache N --layout packed\|closed]` | Checks immutable page roots through disk restart and checkpoint/trim with a bounded cache; records measurements |
| `just test::pages-cold [--keys N --cache N]` | Linux x86_64: repeats the page proof with pinned native MinIO and measures both providers |
| `just test::growing [--rows N --cold-s3]` | Proves v1 growing-authority atomic publication, retained reads/receipts and restart/checkpoint/trim against disk Ursula; service integration remains separate |
| `just test::growing-load` | Measures independently offered public v1 requests, queueing, revocation latency, exact retries, state drain and restart |
| `just test::scale [--repeat N]` | Runs the declared repeated growth/load matrix with disk Ursula and pinned native MinIO; retains each sample |
| `just test::growing-service` | Qualifies the explicit v1 node/client profile, bounded state access and uncertain reply recovery on one CPU using ReleaseSafe binaries |
| `just test::node-recovery` | Qualifies read-only retained startup through provider connection loss and unavailability, finite exhaustion, and denied/missing/genesis rejection |
| `just test::query [--finish-pages N]` | Focuses query capture, sealing, publication and partial-consumption recovery using ReleaseSafe binaries; included in the growing service proof |
| `just test::growing-station` | Focuses growing Station calls, retained Table sources and recovery; also included in the full growing service proof |
| `just ci::select BASE [HEAD]` | Previews conservative PR qualification selection |
| `just ci::complete`, `just ci-clean --complete` | Includes installed Chromium in ordinary local or clean-checkout qualification |
| `nix develop .#bindings -c just bindings::sdk-interop` | Builds public SDK/example artifacts, installs external consumers and qualifies ten different-language counter/query pairs; writes a local timing record |
| `just test::packages` | Runs each library’s standalone test suite for focused package work |
| `just test::serving-counter` | Typed counter queue, frozen deltas, lost turns, overflow and output-budget rollback |
| `just test::serving`, `just test::serving-tls`, `just test::serving-capacity` | Signed application admission/recovery, actual nginx termination and bounded concurrent gateway reads; focused M19 proofs |
| `just test::packages-build` | Compiles those test suites through each package’s own manifest; CI executes shared tests once through root unit checks |
| `just test::fuze-types`, `just test::fuze-sources` | Independent logical type and CSV/JSONL fixtures, exact codecs, frozen discovery, budgets, allocation and denial/cancellation checks |
| `just test::table-schema` | Independent Table schema bytes, stable column identities, typed defaults, nullable omission and row constraints |
| `just test::relational-sql` | Compare selected JOIN/GROUP BY syntax and Boolean instruction order across production Zig, independent ANTLR and PostgreSQL ASTs; included in `test::sql` |
| `just test::relational` | Relational plan/basis validation, bounded executor against independent NULL/ordered-overflow fixtures, identity bytes and finite Python/SQLite comparison; native source and disk proofs run separately |
| `just test::file-query` | Real CSV/JSONL file/stdin/gzip queries, independent exact results, quotas, cancellation, immutable capture and bounded process memory |
| `just test::file-benchmark --output PATH` | Pinned DuckDB file/discovery/execution comparison matrix in the benchmarks shell; raw reports and explicit metric scopes |
| `just test::logical-codec`, `just bindings::logical-test` | Exact logical native/port codecs and installed Python/TypeScript owners, generated recursive schemas, hashes and Arrow |
| `just test::logical-arrow` | Independent PyArrow interpretation of rich logical types, all five states, exact metadata, bounded batches and failed prefixes |
| `just test::compute` | Runs the pinned Arrow compute dependency’s additional tests with Fuze’s configuration |
| `just test::dev-environment`, `just test::kubectl-transit` | Verify checkout kubeconfig isolation and the plugin CLI, query limits, origin checks and signal handling offline; included in `ci` |
| `just test::deployments` | Renders/lints the Transit Helm chart and checks bootstrap, credential, storage and network boundaries without a cluster; included in `ci` |
| `just test::telemetry` | Checks bounded log emission and independent metrics with disabled, drained, stalled and closed sinks on one CPU |
| `just test::observability` | Proves real Board/client/node correlation, privacy, receipt semantics and Transit progress with a blocked log pipe |
| `just test::storage` | Launches isolated disk-backed Ursula, tests conditional writes and bounded reads, then kills/restarts it and verifies recovery |
| `just test::service` | Proves signed HTTP ingress, scoped/revoked reads, worker replacement and authority/storage restart on loopback |
| `just test::callers` | Runs the actual counter and byte-log example binaries through the public client against the same node, including dropped commit responses, stale owners and restart recovery |
| `just contract::generate`, `just contract::check` | Regenerates or checks the language-neutral JSON Schema derived from public Zig types |
| `just test::capacity` | Linux/Docker proof of real disk pressure, reserved control progress, checkpoint/trim and restart on an owned ext4 image |
| `just launchers::reference::up`, `status`, `inspect`, `update`, `restart`, `down` | Runs and updates a persistent Kubernetes/Substrate Transit application; down preserves its data |
| `just launchers::reference::infra-up`, `images`, `test`, `infra-down` | Sets up, builds, tests and destroys the separately owned reference infrastructure |
| `just launchers::local::build [SERVICE...]`, `update [SERVICE...]` | Build candidates or deploy compatible changes; Compose/reference expose the same interface |
| `just test::runtime-upgrade` | Proves provider-switch fencing and recovery after a lost provider response |
| `just launchers::reference::test-plugin` | Check discovery, logs and live forwarding using isolated chart-labelled resources on an existing reference cluster |
| `nix flake check` | Evaluates outputs and runs Zig/TypeScript, Ursula, and Kubernetes CLI smoke checks without network access |

The growing service and focused query recipes select ReleaseSafe explicitly,
retaining runtime safety checks with the same fault schedules, deadlines and
resident bounds. `test::growing-service-release` selects that same profile.
Use `zig build test-growing-service -Doptimize=Debug` or
`zig build test-query -Doptimize=Debug` to reproduce those integration schedules
in Debug. Unit tests retain their default Debug build.

`just ci::cost RUN_ID` compares ordinary-suite budgets only when every ordinary
lane appears exactly once and completes successfully with available cache evidence.
Missing or duplicate lanes leave the result inconclusive; measured job timings
and restored bytes remain available. A successful selected profile does not
qualify the ordinary-suite budget.

The bindings job has a 240-minute execution cap. The [recorded task durations](../tests/verification/results/m46-clean-task-coverage-2026-10-07.json)
total about 184 minutes across clean checkouts, separately from hosted setup.
This cap includes toolchain setup and leaves room for the complete matrix. Individual
proof deadlines and the separately recorded feedback budgets remain unchanged.

The growing query fixture allows 600 seconds for complete result delivery over
physical disk and 180 seconds for each other phase. Delivery includes hundreds
of durable paged turns; the proof records actual phase times and verifies the
complete original result. These fixture limits do not define runtime latency
guarantees or change the separate performance regression budgets.

Clean checkouts and their owned `TMPDIR` default to `/var/tmp`, outside Nix's
temporary shell directory and the often memory-backed `/tmp`. SDK consumer
builds and storage fixtures share that run's disk-backed scratch directory.
They can consume over 10 GiB before cleanup.
`just ci-clean --work-root /short/path` selects a persistent parent; keep it short
for the native launchers' Unix sockets. Failed-run timing/log evidence is retained;
a failed or space-exhausted run does not satisfy the clean gate.

Keep root recipes for common entry points and put specific workflows in the
corresponding module. Add runnable work, not placeholder success.

For prerequisites, proof boundaries, and troubleshooting, use the
[test guide](../tests/README.md), [reference runbook](../deploy/reference/README.md),
[launcher guide](../launchers/README.md),
[toolchain guide](../nix/README.md), or [examples](../examples/README.md).

`just test::inspection` exercises the signed, bounded public read surface against
isolated disk-backed Ursula.

For repeated installed Rust runner destruction, use
`nix develop .#bindings --command just bindings::rust-lifetime 256`.
The focused task accepts 1–1024 fresh malformed-input cases (default 128);
ordinary Rust SDK qualification also checks retained native code mappings.
The consumer is installed once and exercised in independent disk-backed fixtures
of at most 32 cases. Each fixture verifies its history before joined cleanup;
the test does not increase storage quotas or reset accepted work within a history.
Use an owned disk-backed `TMPDIR` for large consumer builds, as the clean suite
does. See the [proof ledger](../tests/README.md#rust-native-lifetime-investigation--2026-09-30).

## Public documentation

`just transit-docs::install` installs locked workspace dependencies; the existing
Board install recipe also includes the site. `just transit-docs::dev` starts the
Docusaurus development server on loopback. `build` produces static output and
`serve` previews it. `just transit-docs::check` runs strict types, Vite+ checks,
source/reference tests and a production build that rejects broken links and
anchors; it is included in `just check` and the experience lane.

`just transit-docs::browser-install` installs Chromium. Then run
`just transit-docs::browser` to exercise desktop/mobile navigation, generated
API downloads, local search, Internals, diagrams and accessibility. Use
`TRANSIT_DOCS_BASE_URL=/handbook/` to qualify hosting below a path. See the
[site guide](../apps/transit-docs/README.md) for source ownership and hosting.

## Build profiles

The [build module](build.just) exposes Zig's four optimization modes:

| Command | Pinned Zig option | Purpose | Runtime safety checks |
| --- | --- | --- | --- |
| `just build::debug` | `-Doptimize=debug` | Development and debugging | Enabled |
| `just build::release-safe` | `-Doptimize=safe` | Optimized execution with safety checks | Enabled |
| `just build::release-fast` | `-Doptimize=fast` | Optimize for speed | Disabled by default |
| `just build::release-small` | `-Doptimize=small` | Optimize for executable size | Disabled by default |

Bare `just build` lists these choices. With no further arguments, each profile
installs `transit-node`, `transit-runtime-controller`, `rey-cli`, `kubectl-transit`, and `transit-board` with
its embedded UI into `zig-out/bin`. Install frontend dependencies first with
`just transit-board::install`. Zig caches each optimization mode separately, but the
default installation directory is shared: the most recent build replaces those
binaries. Use `--prefix` to keep separate outputs.

Arguments after the profile pass directly to `zig build`, preserving quoting:

```sh
just build::debug apps                 # Platform commands without the Board UI
just build::release-safe examples      # The example callers
just build::release-safe apps examples transit-board --prefix zig-out/release-safe
just build::release-small apps -Dtarget=x86_64-linux-musl
```

These profiles select Zig optimization. Board's frontend still uses its Vite+
build pipeline in every mode. Launcher, example and Board workflows retain
their own build defaults; choosing a profile here does not change a subsequent
launcher's build mode or its configured binary paths.

M20 adds `just test::reactive` for independent signed TLS SSE/WebSocket native
recovery peers, `just test::reactive-browser` for actual Chromium/WebCrypto,
`just test::reactive-limits` for capacity/cursor/expiry schedules,
`just test::reactive-placement compose` and `just test::reactive-placement reference`
for owned physical recovery, and `just test::reactive-descriptions` for generated OpenAPI 3.2.1
and AsyncAPI 3.0 drift plus pinned offline validation. These are focused proofs;
they do not expand the measured M10 hosted PR lane budget.

`embed_web.py` builds a named frontend with Vite+ in an isolated temporary output
and emits a Zig module containing at most 128 files / 8 MiB. Board passes its
OpenAPI file as an optional third argument; the counter application uses the same
asset builder without importing Board. Real binaries embed the resulting closed
asset set and need no JavaScript server at runtime.

M21 adds `just test::reactive-client` for the shared private host contract,
`just test::reactive-refresh` for the durable finite requester, and
`just test::reactive-views` / `just test::reactive-views-lifecycle` for actual
Board/counter browser consumers. `just test::reactive-views-placement compose`
and `just test::reactive-views-placement reference` add owned physical recovery.
The complete browser CI lane includes the M20 browser peer and M21 consumers;
physical placements remain explicit external proofs.

`just test::grpc-server` qualifies the bounded inbound transport independently of
M16 outbound calls. `just test::flight-metadata` checks pinned protobuf drift and
standard metadata IPC with PyArrow. Both run in the ordinary growth CI lane;
full Flight/ADBC qualification remains separate.

M22 adds `just test::flight` for TLS PyArrow and pinned ADBC C/Python clients,
`just test::flight-faults` for current-read revocation, retained-result recovery,
concurrency and bounded slow clients, and `just test::flight-outbound` for recorded
RPC capture and network-free replay. `just test::flight-placement compose` and
`just test::flight-placement reference` exercise owned physical installations.
The manual [Flight workflow](../.github/workflows/flight.yml) runs native and
Compose qualification and retains timing logs. It is outside the measured PR
budget; no hosted timing is claimed until that workflow executes.


M23 adds `just test::application-grammar`, `just test::application` and
`just test::application-browser` for the independent declarative compiler,
signed native publication restart boundary, and actual embedded editor with
operator admission and recovery. These are focused tasks outside ordinary PR
lanes; the browser task requires the existing installed Chromium.

`just test::work-items` exercises bounded application-owned Table migration and
fresh-key disk recovery. `just test::work-items-browser` composes the standalone
generated frontend, separate publication/data/requester owners, schema switch,
saved exact query recovery and browser access revocation. Both are focused M23
qualifications; they do not expand the measured hosted PR lanes.
