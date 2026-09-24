# Repository commands

Run commands from the repository root inside `nix develop`.

## Task interface

The root [justfile](../justfile) keeps common commands: `check`, `ci`,
`fmt`, and `doctor`. Modules under `tasks/` own the grouped recipes:
[build](build.just), [launchers](launchers.just), [test](test.just),
[examples](examples.just), [contract](contract.just), and [board](board.just).
Use double colons, for example `just launchers::reference::up` or `just examples::run counter`.
Space-separated module paths also work: `just build debug` is equivalent to
`just build::debug`.

`just` lists common commands and namespaces. `just launchers` lists environment
groups; `just launchers::local` or `just --list launchers local` lists one
environment's recipes. Bare module commands only
list tasks. In particular, `just test` lists the test recipes; use
`just test::unit` to run unit tests. `just --list --list-submodules` shows the full
tree.

Each module explicitly sets the strict Bash shell and repository-root working
directory. Recipes work from repository subdirectories after entering the dev
shell. `just ci` composes checks through module dependencies;
reference deployment and physical-capacity tests remain explicit commands.

| Command | What it does today |
| --- | --- |
| `just` | Lists available recipes |
| `just doctor` | Prints tool versions, including Ursula and Kubernetes tooling, without contacting a cluster |
| `just check` | Checks Nix/Zig formatting, the toolchain smoke check, Zig unit tests, generated public-contract drift, local Markdown links, and diff whitespace |
| `just ci` | Runs foundation, package, telemetry, recovery, caller, inspection, Board API/frontend and local launcher checks in the same development shell |
| `just fmt` | Formats Nix and Zig files |
| `just build` | Lists Zig build profiles |
| `just build::debug`, `just build::release-safe`, `just build::release-fast`, `just build::release-small` | Builds platform executables and embedded Board with the selected optimization profile; accepts Zig steps/options |
| `just examples::build` | Installs `example-counter` and `example-byte-log` |
| `just examples::run counter`, `just examples::run byte-log` | Provisions disposable disk Ursula and an authority, runs the real example, and verifies its committed state |
| `just board::install`, `just board::demo` | Install locked frontend dependencies and inspect a disposable counter realm |
| `just board::build`, `just board::run CONFIG` | Build the embedded binary and run a provisioned installation |
| `just board::generate`, `just board::contract`, `just board::check` | Generate/check OpenAPI and browser models, then validate frontend formatting/lint/types/tests |
| `just board::test`, `just board::browser-install`, `just board::browser` | Qualify the real API and install/run the pinned browser proof |
| `just launchers::local::up`, `status`, `inspect`, `logs SERVICE`, `attach` | Run a persistent native system with foreground logs and Ctrl-C shutdown; `up --detach` starts in the background, `logs manager` shows lifecycle/probe evidence |
| `just launchers::compose::up`, `status`, `inspect`, `logs SERVICE` | Run the same scenario in Docker containers |
| `just launchers::local::send VALUE [REQUEST_ID]`, `restart SERVICE` | Admit example input through signed ingress or replace a service; Compose has the same tasks |
| `just launchers::local::down`, `reset` | Stop while preserving data, or explicitly delete a stopped installation; Compose has the same tasks |
| `just launchers::local::test`, `just launchers::compose::test` | Qualify persistence, duplicate-safe provisioning, fresh ownership and missing-store refusal in isolated installations |
| `just test::unit` | Runs Zig unit/protocol tests without a service |
| `just test::packages` | Checks each library independently of root build orchestration |
| `just test::deployments` | Renders/lints the Transit Helm chart and checks bootstrap, credential, storage and network boundaries without a cluster; included in `ci` |
| `just test::telemetry` | Checks bounded log emission and independent metrics with disabled, drained, stalled and closed sinks on one CPU |
| `just test::observability` | Proves real Board/client/node correlation, privacy, receipt semantics and Transit progress with a blocked log pipe |
| `just test::storage` | Launches isolated disk-backed Ursula, tests conditional writes and bounded reads, then kills/restarts it and verifies recovery |
| `just test::service` | Proves signed HTTP ingress, scoped/revoked reads, worker replacement and authority/storage restart on loopback |
| `just test::callers` | Runs the actual counter and byte-log example binaries through the public client against the same node, including dropped commit responses, stale owners and restart recovery |
| `just contract::generate`, `just contract::check` | Regenerates or checks the language-neutral JSON Schema derived from public Zig types |
| `just test::capacity` | Linux/Docker proof of real disk pressure, reserved control progress, checkpoint/trim and restart on an owned ext4 image |
| `just launchers::reference::up`, `just launchers::reference::images`, `just launchers::reference::test`, `just launchers::reference::down` | Sets up, builds, tests and removes the owned Kubernetes/Substrate reference deployment |
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
installs `transit-node`, `transit-runtime-controller`, `rey-cli`, and Board with
its embedded UI into `zig-out/bin`. Install frontend dependencies first with
`just board::install`. Zig caches each optimization mode separately, but the
default installation directory is shared: the most recent build replaces those
binaries. Use `--prefix` to keep separate outputs.

Arguments after the profile pass directly to `zig build`, preserving quoting:

```sh
just build::debug apps                 # Platform commands without the Board UI
just build::release-safe examples      # The example callers
just build::release-safe apps examples board --prefix zig-out/release-safe
just build::release-small apps -Dtarget=x86_64-linux-musl
```

These profiles select Zig optimization. Board's frontend still uses its Vite+
build pipeline in every mode. Launcher, example and Board workflows retain
their own build defaults; choosing a profile here does not change a subsequent
launcher's build mode or its configured binary paths.
