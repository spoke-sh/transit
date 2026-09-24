# Development toolchain

[flake.nix](../flake.nix) supplies `just`, Zig 0.17 master through `zig-overlay`,
Ursula/`ursulactl` through `ursula-overlay`, Vite+ (`vp`), Node.js, pnpm, Python with PyYAML, Process Compose,
and Kubernetes tools. [flake.lock](../flake.lock) pins inputs; the Vite+ release
and checksums live in [vite-plus.nix](vite-plus.nix). Linux and macOS on x86_64
and aarch64 are configured; native checks on every platform are not claimed.

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

The repository's [.envrc](../.envrc) runs `use flake`, then `dotenv_if_exists .env`
for per-checkout development settings. Copy [.env.example](../.env.example) for
Board listener/origin settings; `.env` stays out of Git. Nix remains the source
of tool versions; direnv is optional and is not installed by this shell.

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

## Launcher tools

The persistent [local launcher](../launchers/README.md) uses Process Compose
1.110.0, selected by the existing nixpkgs lock, for OS process management and a
terminal UI. `just doctor` and the toolchain smoke check verify its executable.
Adding it does not update the Zig/Ursula pins. The Compose launcher separately
requires a user-managed Docker daemon and Compose v2 plugin.

## Kubernetes tools

The dev shell includes `kubectl`, Helm and `k9s` on Linux and macOS, with `k3s` included
on Linux. Their versions are pinned through the existing nixpkgs input in
`flake.lock`. K3s runs on Linux; macOS development can use a Linux VM or remote
cluster. See the [K3s requirements](https://docs.k3s.io/installation/requirements).

```sh
nix develop --command kubectl version --client
nix develop --command helm version --short
nix develop --command k9s version --short
# Linux only:
nix develop --command k3s --version
```

Entering the shell supplies tools without starting a cluster or changing
kubeconfig. `just doctor` and the toolchain smoke check run only local version
commands for these tools.

The [reference runbook](../deploy/reference/README.md) owns cluster setup.
Helm 3.20.2 and PyYAML come from the existing nixpkgs pin; the chart proof uses
them to render, lint and inspect [charts/transit](../charts/transit/README.md).
[Backend notes](../packages/zig/transit-backend-ursula/README.md) own Ursula's disk
configuration and the separately pinned Zig client dependency.

## CI caching

The hosted workflow caches the Nix store using the approach described in
[Speeding up CI with Nix](https://simonshine.dk/articles/speeding-up-ci-with-nix/).
The [baseline run](https://github.com/rupurt/rey/actions/runs/35809573509) spent
16m32s in its first shell/check step: roughly 14 minutes building Ursula and
`ursulactl` from Rust source. Installing Nix took only four seconds. We keep that
installer and cache the pinned overlay outputs rather than changing tools.

The cache key includes runner OS/architecture, `flake.lock`, Nix expressions,
and Vite+'s npm sources/lockfile. Source-only changes reuse the same toolchain
cache; toolchain changes can restore an older cache as a starting point. An
explicit temporary Nix profile protects the shell during garbage collection,
and successful preparation is saved even if a later protocol test fails. The
6 GiB GC target accommodates the locally measured ~5 GiB build closure; it is
not a hard size bound. No cache-purge permission or external cache secret is
needed. The self-hosted reference workflow keeps using its existing local store.

All checks still run via `just ci`. The first cache miss still builds the pinned
toolchain. The [first measured warm run](https://github.com/rupurt/rey/actions/runs/35815675439)
restored the cache in 1m32s and prepared the shell in eight seconds, with no
Ursula rebuild. Its service test exposed a deadline bug under limited CPU
availability, so it is not a passing end-to-end timing. Compare the separate
restore, preparation, checks, and save step timings on subsequent runs.

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

## Board frontend workspace

The application workspace pins Vite+ 0.3.3 to match the Nix toolchain, with strict
TypeScript, React and TanStack Router dependencies in `pnpm-lock.yaml`. Install
with `just transit-board::install`; use `vp` for dependency operations. The pinned Vite+
package uses the `@voidzero-dev/vite-plus-core` alias and upstream Vitest 4.1.11;
its alias version triggers a pnpm peer-version warning, qualified by actual
frontend build/check/test and browser proofs. No Nix toolchain pins were changed.
The [Board frontend guide](../apps/transit-board-web/README.md) owns application workflows.
CI installs the frozen lock before `just ci` and runs the pinned Chromium proof.
