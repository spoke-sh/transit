# Development

## Current setup

Use Nix with `nix-command` and `flakes` enabled. Run commands from the repository
root:

```sh
nix develop
just doctor
just check
```

Or run a command without an interactive shell:

```sh
nix develop --command just doctor
nix develop --command just check
```

An existing `.envrc` can use `use flake` if you prefer direnv. Nix remains the
source of tool versions; direnv is optional and is not installed by this shell.

| Command | What it does today |
| --- | --- |
| `just` | Lists available recipes |
| `just doctor` | Prints tool versions, including Ursula and Kubernetes tooling, without contacting a cluster |
| `just check` | Checks Nix/Zig formatting, the toolchain smoke check, Zig unit tests, local Markdown links, and diff whitespace |
| `just fmt` | Formats Nix and Zig files |
| `just build` | Compiles implemented Zig executables |
| `just test` | Runs Zig unit/protocol tests without a service |
| `just test-packages` | Checks each library independently of root build orchestration |
| `just test-storage` | Launches isolated disk-backed Ursula, tests conditional writes and bounded reads, then kills/restarts it and verifies recovery |
| `just test-service` | Proves signed HTTP ingress, scoped/revoked reads, worker replacement and authority/storage restart on loopback |
| `nix flake check` | Evaluates outputs and runs Zig/TypeScript, Ursula, and Kubernetes CLI smoke checks without network access |

The root Zig build composes package tests and the storage proof. Integration
orchestration uses the Nix-provided Python 3, temporary directories, and loopback ports;
it never uses an existing Ursula deployment. Cluster deployment, frontend, and
application code remain implementation work. The experimental counter service,
worker, and CLI are described in the [service profile](../contracts/SERVICE_V1.md).
GitHub Actions runs the same local checks, storage proof, and service proof on
Linux; a workflow definition is not evidence of a
remote CI run. The Nix check runs Zig tests and builds a tiny TypeScript page through Vite+ from a clean
cache, verifying that first-use setup works without downloading another runtime.
It also checks the Ursula and Kubernetes tool CLIs. These checks verify binary
execution; stream persistence, cluster operation, and distributed recovery need
their own integration tests.

## Planned Zig package workflow

Rey will contain multiple Zig library and executable packages following the
[architecture's decomposition](ARCHITECTURE.md#planned-monorepo-decomposition).
Transit and `transit-ursula` implement this package structure; the remaining
packages are a build plan. Run `just test-packages` for their standalone checks.

- Give each implemented package a `build.zig` and `build.zig.zon` declaring its
  own direct dependencies. Reusable libraries expose documented modules and
  focused tests; executables own entry points that compose those modules.
- Use local package dependencies inside the monorepo so a single change can
  update Transit, Station, adapters, and their consumers together. Keep imports
  behind package interfaces instead of reaching into another package's source.
- Add root Zig build orchestration for aggregate and focused package checks.
  Expose working tasks through `just`, retaining the ability to check one package
  in the workspace. Define exact target names as the first packages land.
- Keep all packages on the Nix-pinned Zig compiler. Pin external Zig dependencies
  by revision and package hash in the package that directly consumes them;
  review upgrades and resulting consumer checks together.
- Treat a library as an importable Zig module. Produce static/shared artifacts
  when a consumer needs them; executable and container packaging is separate.
- Keep frontend dependencies in the Vite+/pnpm workspace. Language-neutral
  schemas and fixtures under `contracts/` define the shared wire boundary.

M1 should introduce only the Transit, Ursula/runtime adapter, and executable
pieces needed by its proof. Station and connector packages follow their milestones.
Publication, independent package releases, and stable external APIs can be scoped
when there are consumers that need them.

## Ursula

The dev shell provides Ursula 0.5.1 and its matching `ursulactl` operations CLI
through [ursula-overlay](https://github.com/rupurt/ursula-overlay). The overlay
shares Rey's pinned nixpkgs and brings its own pinned Rust build toolchain;
no separate Rust installation is needed. A cold Nix build may take time to
download dependencies and compile the server and CLI.

```sh
nix develop --command ursula --help
nix develop --command ursulactl --version
```

Entering the shell does not start a server. `just test-storage` owns a temporary
disk-backed service and exercises four startup/crash phases. Persistent developer
service and cluster lifecycle commands remain separate M1 work.

### Zig client dependency

[ursula-zig](https://github.com/rupurt/ursula-zig) is the selected application
library. The planned `transit-ursula` package owns the `ursula_zig` dependency in
its `build.zig.zon`, pinned to an immutable revision URL and Zig package hash
when M1 adds the backend build. The upstream client exports the `ursula` module;
see its
[build integration](https://github.com/rupurt/ursula-zig/blob/8cfd68b275022c2de8572bce3608157b95ba13d7/docs/usage.md).
The adapter now pins that revision and its Zig package hash; `just build` and
`just test-storage` compile and exercise the consuming backend. The Git URL avoids
a tarball-root handling failure observed in this pinned compiler's build fetch.

The reviewed client revision `8cfd68b275022c2de8572bce3608157b95ba13d7` declares
Zig `0.17.0-dev.2251+1175a3e99` as its minimum version, matching Rey's pinned
compiler. Its Zig and Ursula overlay revisions also match Rey's current pins.
These are metadata checks; M1 must build the consuming backend and verify it
against the server. See the client
[package metadata](https://github.com/rupurt/ursula-zig/blob/8cfd68b275022c2de8572bce3608157b95ba13d7/build.zig.zon)
and [toolchain pins](https://github.com/rupurt/ursula-zig/blob/8cfd68b275022c2de8572bce3608157b95ba13d7/flake.lock).

Updating `ursula-overlay` changes the server tools; update the Zig source
dependency separately. Check client/compiler/server compatibility and rerun the
backend integration and recovery checks as they become available.

## Vite+

The shell includes a checksummed upstream `vp` binary and its matching JavaScript
toolchain, built by Nix from `nix/vite-plus/package-lock.json`. Native binaries
are patched for Nix on Linux. First use creates settings and shims in
`$PWD/.cache/vite-plus` as set when entering the shell, leaving the global Vite+
installation and shell profiles alone. Node.js and package-manager preferences
use the tools from Nix. Fetching/building the Nix shell requires network access
on a cold cache; Vite+ does not need to download its own toolchain on first use.

The npm manifest under `nix/` is internal tool packaging, not the frontend
workspace. When the frontend is scaffolded, pin
`vite-plus` in `package.json`, choose/pin the pnpm version, commit the workspace
and lockfile, and use `vp install --frozen-lockfile` in CI. Use the project-local
toolchain for builds and checks. See the upstream
[global CLI](https://viteplus.dev/guide/global-cli) and
[package management](https://viteplus.dev/guide/install) documentation.

The intended frontend workflow, once it is scaffolded, is `vp install`, `vp dev`,
`vp check`, `vp test`, and `vp build`. Those are not yet Rey application commands.
Use the Nix package definition to update the CLI instead of `vp upgrade`, which
changes mutable installation state outside the pinned tool definition.

## Kubernetes and Substrate

The dev shell includes `kubectl` and `k9s` on Linux and macOS, with `k3s` included
on Linux. Their versions are pinned through the existing nixpkgs input in
`flake.lock`. K3s runs on Linux; macOS development can use a Linux VM or remote
cluster. See the [K3s requirements](https://docs.k3s.io/installation/requirements).

```sh
nix develop --command kubectl version --client
nix develop --command k9s version --short
# Linux only:
nix develop --command k3s --version
```

Entering the shell supplies tools without starting a cluster or changing
kubeconfig. `just doctor` and the toolchain smoke check run only local version
commands for these tools.

The [reference deployment](DEPLOYMENT.md) targets Kubernetes and Agent Substrate
from the first executable milestone. Substrate, deployment manifests, and cluster
lifecycle commands remain M1 work. That milestone will pin and validate the
reference runtime combination, provide reproducible setup, and expose worker
failure and protocol conformance checks through `just`. Tool availability alone
does not establish K3s/Substrate compatibility.

Local unit/protocol tests should remain runnable without a cluster. Passing
those tests does not establish reference-runtime isolation or recovery behavior;
keep cluster checks and their prerequisites explicit. AX is not a dependency.

## Updating tools

```sh
# Update the Zig overlay intentionally, then inspect the lockfile diff.
nix flake update zig-overlay

# Update the Ursula server and operations CLI together.
nix flake update ursula-overlay

# Update general development packages, including Kubernetes tools, separately.
nix flake update nixpkgs

# Enter the new shell and verify it.
nix develop --command just doctor
nix develop --command just check
```

The overlay's `master` attribute moves; the committed `flake.lock` freezes its
revision. The flake asserts a `0.17.*` compiler so a later master release cannot
silently change the language target. A version assertion failure requires a
deliberate compiler migration or a suitable overlay revision.

For Vite+, update the version and all four platform hashes in
`nix/vite-plus.nix` from the selected upstream release and `vp-checksums.txt`.
Update the version/dependency in `nix/vite-plus/package.json`, regenerate its
internal lockfile using `npm install --package-lock-only --ignore-scripts
--prefix nix/vite-plus`, and refresh `npmDepsHash` in the Nix derivation. npm is
used here solely for Nix's `buildNpmPackage`; use `vp` for frontend dependencies.
Run `just check` to exercise first-use setup and compilation. Evaluate all target
systems and build/smoke-test on native runners as they become available.

Nix flakes in Git repositories only include tracked files. When adding flake
sources, include them in Git before using `nix develop`. `git add --intent-to-add`
on the specific new source files makes them visible to Nix without staging their
contents.

## Validation as implementation grows

Use valid/invalid protocol traces, deterministic handler tests, and shared
TypeScript/Zig contract fixtures. Exercise the real persistence boundary in
integration tests for turn commits, mailbox delivery, and effect capture.
Use [CONFORMANCE.md](CONFORMANCE.md) to track adversarial evidence, with separate
assertions for authenticated authority, protocol legality, state recovery,
deterministic re-execution, and external effects. Current tooling checks provide
none of those runtime guarantees.
Include Kubernetes worker replacement, stale-owner rejection, lost wakeups,
interrupted provider operations, and replay with effect dispatch disabled.
Verify PID continuity across recovery, permanent retirement on termination,
registry rebinding with pending messages/replies, and runtime binding recovery.
Include opted-in process/mailbox expiry, suspension bounds, late activation,
checkpoint recovery after history trimming, and interrupted deletion/GC. Test
logical expiry even when bytes remain and distinguish it from storage outages.
Use recorded/fake time to exercise deadlines and clock/failover policy; runtime
integration must prove enforcement independently of background timer delivery.
Reference-runtime conformance must test attempted bypass of protocol writes
and effect capabilities, including restored code using stale authority before
a resume handshake.

Benchmarks record compiler/tool versions, hardware, dataset, concurrency,
durability settings, and p50/p95/p99 latency together with throughput and memory.
Keep correctness/recovery validation distinct from performance measurements.
