# Repository commands

Run commands from the repository root inside `nix develop`.

## Task interface

The root [justfile](../justfile) keeps common commands: `check`, `ci-clean`,
`fmt`, and `doctor`. Modules under `tasks/` own the grouped recipes:
[build](build.just), [launchers](launchers.just), [test](test.just),
[examples](examples.just), [contract](contract.just), [ci](ci.just),
[bindings](bindings.just), and [transit-board](transit-board.just).
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
| `just ci-clean` | Requires committed changes; clones HEAD into a temporary directory, installs locked frontend dependencies and runs `just ci` without existing workspace outputs |
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
| `just test::unit` | Runs Zig unit/protocol tests without a service |
| `just test::build` | Compiles application/probe entry points separately from unit tests; included in core CI |
| `just test::model [--tail N]` | Checks the finite TLA+ model, removed guards and concrete Zig counterexample schedules |
| `just test::codecs [--fuzz=1000]` | Runs bounded signed JSON/frame corpora and allocation checks; optionally explores with LLVM fuzz coverage |
| `just test::mutations` | Uses isolated committed clones to verify detection of omitted Zig guards |
| `just test::properties [--seeds N --steps N]` | Runs saved and generated authority schedules; failures retain a minimized replay trace |
| `just test::growing-quota` | Checks service/Station admission refusal, retained backlog and reserve exhaustion across disk restart |
| `just test::growing-capacity` | Uses an owned Docker/ext4 fixture to qualify growing pages, ENOSPC, physical reserve release and control/recovery progress |
| `just test::pages [--keys N --cache N --layout packed\|closed]` | Checks immutable page roots through disk restart and checkpoint/trim with a bounded cache; records measurements |
| `just test::pages-cold [--keys N --cache N]` | Linux/Docker: repeats the page proof with an owned persistent S3-compatible cold store and measures both providers |
| `just test::growing [--rows N --cold-s3]` | Proves v3 growing-authority atomic publication, retained reads/receipts and restart/checkpoint/trim against disk Ursula; service integration remains separate |
| `just test::growing-load` | Measures independently offered public v3 requests, queueing, revocation latency, exact retries, state drain and restart |
| `just test::scale [--repeat N]` | Runs the declared repeated growth/load matrix with disk Ursula and an owned Docker cold store; retains each sample |
| `just test::growing-service` | Qualifies the explicit v3 node/client profile, bounded state access and uncertain reply recovery on one CPU |
| `just test::growing-station` | Focuses growing Station calls, retained Table sources and recovery; also included in the full growing service proof |
| `just ci::select BASE [HEAD]` | Previews conservative PR qualification selection |
| `just ci::complete`, `just ci-clean --complete` | Includes installed Chromium in ordinary local or clean-checkout qualification |
| `nix develop .#bindings -c just bindings::sdk-interop` | Builds public SDK/example artifacts, installs external consumers and qualifies ten different-language counter/query pairs; writes a local timing record |
| `just test::packages` | Runs each library’s standalone test suite for focused package work |
| `just test::packages-build` | Compiles those test suites through each package’s own manifest; CI executes shared tests once through root unit checks |
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

Keep root recipes for common entry points and put specific workflows in the
corresponding module. Add runnable work, not placeholder success.

For prerequisites, proof boundaries, and troubleshooting, use the
[test guide](../tests/README.md), [reference runbook](../deploy/reference/README.md),
[launcher guide](../launchers/README.md),
[toolchain guide](../nix/README.md), or [examples](../examples/README.md).

`just test::inspection` exercises the signed, bounded public read surface against
isolated disk-backed Ursula.

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
