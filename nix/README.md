# Development toolchain

[flake.nix](../flake.nix) supplies `just`, Zig 0.17 master through `zig-overlay`,
Ursula/`ursulactl` through `ursula-overlay`, Vite+ (`vp`), Node.js, pnpm, Python with PyYAML and PyArrow, Process Compose,
and Kubernetes tools. [flake.lock](../flake.lock) pins inputs; the Vite+ release
and checksums live in [vite-plus.nix](vite-plus.nix). Linux and macOS on x86_64
and aarch64 are configured; native checks on every platform are not claimed.

The M9 Arrow integration uses Zig `0.17.0-dev.2267+48abf1a34`, matching
the selected zarrow fork. The Zig overlay update is deliberate; Ursula and
general development-package pins remain unchanged.

## Current setup

Use Nix with `nix-command` and `flakes` enabled. Run commands from the repository
root:

```sh
nix develop
just doctor
just transit-board::install
just check
```

Or run a command without an interactive shell:

```sh
nix develop --command just doctor
nix develop --command just transit-board::install
nix develop --command just check
```

The repository's [.envrc](../.envrc) runs `use flake`, then `dotenv_if_exists .env`
for per-checkout development settings. Copy [.env.example](../.env.example) for
Board listener/origin settings; `.env` stays out of Git. Nix remains the source
of tool versions; direnv is optional and is not installed by this shell.

The plugin source and its Nix package definition are watched before `use flake`
so nix-direnv refreshes the packaged `kubectl transit` when either changes.
After a checked-in `.envrc` change, review it and run `direnv allow` to reload.
With plain `nix develop`, exit and reenter the shell to refresh packaged commands.

## Vite+

The shell includes a checksummed upstream `vp` binary and its matching JavaScript
toolchain, built by Nix from `nix/vite-plus/package-lock.json`. Native binaries
are patched for Nix on Linux. First use creates settings and shims in
`$PWD/.cache/vite-plus` as set when entering the shell, leaving the global Vite+
installation and shell profiles alone. Node.js and package-manager preferences
use the tools from Nix. Fetching/building the Nix shell requires network access
on a cold cache; Vite+ does not need to download its own toolchain on first use.

The npm manifest under `nix/` is internal tool packaging, separate from the
implemented Vite+/pnpm frontend workspace. Root manifests and the lockfile pin
project dependencies. Use `just transit-board::install` for the locked install,
`just transit-board::check` for validation, and `just transit-board::build` for
the embedded UI/API build. The [frontend guide](../apps/transit-board-web/README.md)
owns application workflow.

Use the Nix package definition to update the global CLI instead of `vp upgrade`,
which changes mutable installation state outside the pinned tool definition.

## Launcher tools

The persistent [local launcher](../launchers/README.md) uses Process Compose
1.110.0, selected by the existing nixpkgs lock, for OS process management and a
terminal UI. `just doctor` and the toolchain smoke check verify its executable.
Adding it does not update the Zig/Ursula pins. The Compose launcher separately
requires a user-managed Docker daemon and Compose v2 plugin.

## Kubernetes tools

The dev shell includes `kubectl`, Helm, `k9s`, Kind and the upstream `kubectl ate`
plugin on Linux and macOS. The shell also packages the repository's
[inspection-only `kubectl transit`](../apps/kubectl-transit/README.md). K3s is no
longer included: the reference is tested with Kind. The Kind CLI version and Substrate revision live alongside the node
image digest in [reference pins](../deploy/reference/versions.json).
[reference-tools.nix](reference-tools.nix) pins source and dependency hashes;
`kubectl-ate` uses Substrate's checked-in vendor tree and reports its base source
revision plus `transit-upgrade-v1`. The versioned
[CLI extension](ate-upgrade/README.md) exposes the pinned server's guarded
`UpdateActor` operation without changing the provider API. Its package tests
cover stale UID/template/version and lost-response retries. These packages use the existing Nix
Go 1.27 compiler; upstream runtime build scripts retain their own pinned toolchain.
No Zig, Ursula, Substrate, or node image upgrade is implied.

```sh
nix develop --command kind version
nix develop --command kubectl ate --version
nix develop --command kubectl plugin list
```

The shell selects `$CHECKOUT/.cache/reference/kubeconfig` through
[dev-environment.sh](dev-environment.sh), even before the reference exists.
After `just launchers::reference::up`, ordinary `kubectl get nodes`, `kubectl ate
get workers`, and `k9s` use that cluster. Entering the shell does not start it or
write/merge `~/.kube/config`. An absent reference config does not fall back to
personal clusters. Reference setup/teardown always use their own explicit path
and context, regardless of interactive overrides.

Set `REY_KUBECONFIG` to an absolute path to deliberately select another config.
With direnv, put it in ignored `.env`; `.envrc` reapplies the environment helper
after loading those settings. Plain `nix develop` does not load `.env`: export
`REY_KUBECONFIG` before entering it. Per-command `--kubeconfig` and `--context`
remain available. Reauthorize `.envrc` with `direnv allow` after reviewing changes,
or reenter `nix develop`. `just doctor` and Nix smoke checks stay offline.

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

The current cache key includes the cache group, runner OS/architecture, `flake.lock`,
Nix expressions, Vite+'s npm sources/lockfile, reference pins and the provider CLI
extension. Ordinary application/plugin edits reuse the heavy toolchain cache;
small packaged helpers rebuild locally. Toolchain changes can restore an older
cache as a starting point. A temporary Nix profile roots the lane's shell during
garbage collection. Successful preparation is saved on a cache miss even if a
later test fails; exact hits do not trigger another upload. Collection targets
zero unrooted store bytes, preserving the live closure rather than an arbitrary
build-store allowance. No cache-purge permission or external cache secret is
needed. The self-hosted reference workflow keeps its existing local store.

The first cache miss still builds the pinned toolchain. The
[first measured warm run](https://github.com/rupurt/rey/actions/runs/35815675439)
restored the cache in 1m32s and prepared the shell in eight seconds, with no
Ursula rebuild. Its service test exposed a deadline bug under limited CPU
availability, so it is not a passing end-to-end timing. Compare the separate
restore, preparation, checks, and save step timings on subsequent runs.

### CI lanes

The [pre-split run](https://github.com/rupurt/rey/actions/runs/36073815381)
took 18m29s: restore/save used 2m28s, the checks used 14m22s, and native launcher
qualification accounted for 5m39s of those checks. The later three-lane
[baseline](https://github.com/rupurt/rey/actions/runs/36181871580) took 17m42s
and 40m11s of aggregate job time. Five concurrent lanes now separate
`just ci::core` (foundation/library/protocol), `just ci::growth` (Arrow, pages
and growing authority/service), `just ci::experience` (frontend, observability,
Board and native Station), `just ci::launchers` (build smoke and native counter),
and `just ci::bindings` (native boundary and languages). Chromium follows
experience as `just ci::browser`. `just ci` runs all five inventories sequentially
in the pinned bindings shell; `just check` uses the ordinary developer tools.

The experience lane uses `nix develop .#ci-experience`, a shell without provider
or Kubernetes tools and without PyArrow. Its measured environment closure is
1.2 GiB. Experience/launchers share one Nix cache, core/growth share another,
and bindings owns the third; each group has one writer. Successful preparation is rooted
before collection, and a miss saves only the live closure. Small changes to the
packaged inspection plugin or environment helper can rebuild without uploading
the store. Exact cache hits do not upload again. Cache keys deliberately change
for heavy toolchain/pin updates; the first new-key run pays that upload cost.
New lane caches can fall back to the previous shared cache for their first run,
so the split itself does not force rebuilding Ursula from Rust source.

The bindings lane uses `nix develop .#ci-bindings`: the native tools, PyArrow and
foreign SDKs, without Kubernetes/provider tools. Its environment closure measures
6.1 GiB. Those SDKs are cached only in this lane; it installs only the Node
binding's workspace dependencies. This keeps new language qualification from
expanding the other lanes or serializing their checks.

All lanes reuse a compiler/dependency cache keyed by the locked toolchain and
Zig manifests. Only bindings writes it, including the C++ standard library.
It holds fetched packages and global compiler
objects, excluding checkout objects, launchers, credentials and the Git archive
transport cache. This avoids caching the tens of gigabytes accumulated by local
Debug/ReleaseSafe builds. No application tests are skipped on a cache hit.

CI runs for PRs, main pushes, version tags, merge queues and manual dispatch.
Feature branch pushes no longer duplicate the PR run. A cheap planning job checks
documentation and selects full qualification unless a PR changes only root
README/AGENTS or Markdown under `docs/`. Contract/component docs, unknown paths,
renames from code, and shared infrastructure select every lane. Missing Git
revisions fail planning; main/tags/merge queues/manual runs are always full.
Use `just ci::select BASE [HEAD]` to inspect the same selection locally.

The workflow cancels superseded runs on the same branch/PR and retains the old
`foundation-and-protocol` required-check name as an aggregate gate. Each task's
duration and status goes to the Actions summary and `.cache/ci/*.json` locally.
Completion metadata records the revision and required task inventory separately;
an interrupted result list cannot stand in for a complete proof. The aggregate
requires successful planning and every selected lane; only explicit docs-only
exclusion permits skipped runtime jobs. `just ci::complete` adds Chromium to the
ordinary suite, and `just ci-clean --complete` runs it on a clean committed clone.
Install the pinned browser first. Clean runs preserve timing/completion evidence
outside successful temporary clones in `.cache/ci/clean/`.
`just check` runs Actionlint so workflow syntax is checked before CI. Hosted
wall time and total runner time must be measured after deployment; local timings
and smaller closures alone do not establish the final speedup.

The feedback target is under ten minutes, with five minutes as a stretch.
[CI budgets](../tests/verification/ci-budgets.json) also track provisional runner
and restore costs; `just ci::cost RUN_ID` collects completed hosted evidence.
Manual `cache_mode=cold` runs disable GitHub dependency restores/saves while
retaining upstream Nix substitutes. The recorded fourteen-minute source build
already exceeds the feedback target on a dependency-cache miss; lane balancing
alone cannot qualify that case. A faster runner or prebuilt pinned dependency
closure needs measured qualification. `TRANSIT_CI_RUNNER` can select a configured
runner; it defaults to `ubuntu-24.04` and does not provision a paid runner.

## Updating tools

When changing Kind or Substrate, update the reference pins and corresponding
source/vendor hashes in `reference-tools.nix` together. Build both packages,
verify the CLI revision, and rerun the reference recovery proof before claiming
compatibility. `nix build .#kind .#kubectl-ate` builds the packaged tools directly.

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

## Formal verification tools

`just test::model` uses TLA+/TLC from the existing nixpkgs lock (1.7.4); it
is rooted in the bindings CI shell alongside Java, without expanding the core
or frontend shell. The small model runs in ordinary bindings qualification.
Weekly CI expands model/property exploration and runs actual guard mutations.
The separate dedicated reference workflow runs weekly and on demand; absent
runner capacity is outstanding evidence, not a passing deployment proof.
