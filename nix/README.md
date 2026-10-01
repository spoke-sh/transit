# Development toolchain

[flake.nix](../flake.nix) supplies `just`, Zig 0.17 master through `zig-overlay`,
Ursula/`ursulactl` through `ursula-overlay`, Vite+ (`vp`), Node.js, pnpm, Python with PyYAML and PyArrow, Process Compose,
OpenSSL for independent signed/TLS peers, and Kubernetes tools. [flake.lock](../flake.lock) pins inputs; the Vite+ release
and checksums live in [vite-plus.nix](vite-plus.nix). Linux and macOS on x86_64
and aarch64 are configured; native checks on every platform are not claimed.

The M9 Arrow integration uses Zig `0.17.0-dev.2267+48abf1a34`, matching
the selected zarrow fork. The Zig overlay update is deliberate; Ursula and
general development-package pins remain unchanged.

M19 explicitly includes the existing locked nixpkgs OpenSSL in the default shell
and toolchain check. This removes the serving peer's dependency on an ambient
system executable; no lockfile input revision changes are required.
The optional `nix develop .#serving` shell adds nginx from that same locked nixpkgs
input for the real serving TLS/capacity proofs. It does not add those tasks to
ordinary hosted lanes. The qualified local proxy currently reports nginx 1.30.5.

## Current setup

Use the [development shell](#entering-the-development-shell) for source work or
the following packages for downstream applications.

## Transit CLI packages

`nix build .#transit` builds the native `transit`, `transit-node` and
`transit-query-host` and embedded `transit-board` executables together. Board
assets build offline from the locked frontend dependency store using Vite+ and
the exact package-manager version declared in `package.json`. The runtime closure
does not include the frontend toolchain. Compilation uses fixed-output source
downloads for the three external Zig dependencies, verifies their Zig package
identities and builds with an offline system package directory. No ambient Zig
package cache or source checkout artifact is required.

On Linux x86_64, `nix build .#transit-local` adds the pinned Ursula and MinIO
providers to the closure. It places all executables together in `bin/`, so
`transit server` finds dependencies beside itself before searching `PATH`. It
also exposes a JSON executable map
in `share/transit/local-executables.json` (including `board`); downstream flakes can also use the
`transit`, `ursula` and `minio` passthru packages to construct explicit server
configuration. It does not initialize storage or start processes during a build
or shell entry. Run `transit server --initialize` once, then `transit server` to resume.
Optional `transit.yaml` settings overlay the version-3 defaults;
Board is enabled by default, with `--no-ui` for headless use. Retain the package
output through a Nix profile or build-link GC root while installations use its
pinned paths; see the [server guide](../apps/transit-cli/docs/server.md).

To prepare the bundle for the public quickstart, run from the repository root:

```sh
mkdir -p .cache
nix build .#transit-local --out-link .cache/transit-local
export PATH="$PWD/.cache/transit-local/bin:$PATH"
transit --version
```

Add that same absolute `bin` directory to `PATH` in each terminal used by the
quickstart. Keep the build link while installations use it; do not rebuild it
in place to change a running installation's selected artifacts. Continue with
[Run Transit locally](../docs/guides/quickstart.md).

MinIO is built from the source of release `2025-09-07T16-13-09Z`, matching the
existing fixture's release because the historical binary/image distribution is
unavailable. [minio.nix](minio.nix) owns this shared source/hash definition. On Linux
x86_64, the default and bindings CI shells include that same executable for owned
disk/S3 fixtures; they no longer extract or start the unavailable historical image.
`nix build .#minio` exposes the provider independently of the local bundle. The
existing source, vendor hash and lockfile inputs are unchanged.
This package selects the trusted local development profile, not a
production object-storage release. No Docker daemon is required. Full release
distribution and compatible runtime upgrades remain separate work.

The CLI is exported for the four declared Unix systems; the complete local
bundle selects Linux x86_64. Evaluation does not qualify the other platforms.

## Entering the development shell

For documentation-only work, `nix develop .#docs` supplies the same pinned Node,
Vite+, pnpm, Git and `just` without Zig or provider tools. Run
`just transit-docs::install` then `just transit-docs::dev` or
`just transit-docs::check`. This shell introduces no new Nix input versions;
`pnpm-lock.yaml` owns the pinned Docusaurus/Mermaid dependency graph. The normal
development shell still supplies everything needed for application examples.

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

## SDK qualification tools

M11's Python packaging/type checks add `build`, setuptools, wheel, pip and mypy
to the developer and bindings CI shells. The bindings shell also adds Ruby
3.4.9 / RubyGems 3.7.2 for the new SDK target. These packages come from the
existing `flake.lock` nixpkgs revision; no Zig, Ursula or lock revision changes
are needed. `just doctor`, Ruby JSON/full-width integer loading and Python tool
imports are checked separately from SDK conformance. Pinning a runtime alone
does not qualify its language adapter. The selected Python tools are build 1.4.4,
setuptools 80.10.1, wheel 0.46.1 and mypy 1.20.1.

M16's independent RPC peers add grpcio 1.80.0, Python protobuf 7.34.1, h2 4.3.0
and protoc 34.1 to the default and bindings shells. They use the existing locked
nixpkgs revision; `flake.lock`, Zig and Ursula remain deliberately unchanged.
`just doctor`, imports and descriptor generation pass locally. These foreign
libraries are test peers and generators; the Transit RPC runtime remains Zig.

M22's `nix develop .#flight` adds the upstream ADBC Flight SQL driver and manager
1.12.0 (Apache ADBC release 24) beside the already pinned PyArrow 23.0.0.
[flight-tools.nix](flight-tools.nix) pins exact wheel URLs/hashes and patches
their native libraries for Linux x86_64/Python 3.13. Other platforms are not
selected for this independent client profile. The existing nixpkgs lock, Zig and
Ursula revisions remain unchanged. Importing these tools is preparation evidence;
it does not qualify a Flight gateway or its C ABI interoperability.

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

Disposable GitHub-hosted runners remove the image's unused Android and .NET
installations before restoring the Nix cache or preparing the shell; consumed
SDKs come from the pinned shell. Exact cache hits also need room for extraction:
the bindings restore in run `36796408660` exhausted disk before the previous
cleanup step could execute.
The first explicit cold run (`36196325993`) exhausted disk while copying the
freshly built Ursula binary in the bindings lane. Its failure is inconclusive,
not a cache-miss qualification. The cleanup step is excluded from user-managed
runners and records filesystem space before and after removal. The same run
completed core in 28m45s, leaving little margin in the ordinary 30-minute job
deadline. Explicit cold calibration gets a 45-minute job deadline; ordinary
feedback budgets and task coverage are unchanged.

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
or Kubernetes tools and without PyArrow. Its Python environment includes PyYAML
and `jsonschema` for the Board query contract checks. The bindings shell's Python
environment includes those same validators. Both use the existing locked nixpkgs
input; no compiler, provider or lockfile revision changes are required.
Its previously measured environment closure is
1.2 GiB. Experience/launchers share one Nix cache, core/growth share another,
and bindings owns the third; each group has one writer. Successful preparation is rooted
before collection, and a miss saves only the live closure. Small changes to the
packaged inspection plugin or environment helper can rebuild without uploading
the store. Exact cache hits do not upload again. Cache keys deliberately change
for heavy toolchain/pin updates; the first new-key run pays that upload cost.
New lane caches can fall back to the previous shared cache for their first run,
so the split itself does not force rebuilding Ursula from Rust source.

The bindings lane uses `nix develop .#ci-bindings`: the native tools, PyArrow and
foreign SDKs and pinned native MinIO, without Kubernetes/provider management tools.
Its previously measured environment closure was 6.1 GiB before adding native MinIO.
Those SDKs are cached only in this lane; it installs only the Node
binding's workspace dependencies. This keeps new language qualification from
expanding the other lanes or serializing their checks.

Execution caps account for the expanded task inventories: growth has 90 minutes,
experience (including browser proofs) 60 minutes and bindings 180 minutes. Core
and launchers retain 30 minutes, or 45 for explicit cold calibration. These are
finite failure limits, not measured feedback budgets. The earlier warm/cold
budget records remain historical; a larger cap does not qualify a slower run or
change any accepted operation's deadline.

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

The accepted warm feedback budget is under fifteen minutes, based on the
12m37s five-lane run; under ten remains an improvement target, five a stretch.
[CI budgets](../tests/verification/ci-budgets.json) also track provisional runner
and restore costs; `just ci::cost RUN_ID` collects completed hosted evidence.
Manual `cache_mode=cold` runs disable GitHub dependency restores/saves while
retaining upstream Nix substitutes. The recorded fourteen-minute source build
consumes almost the entire warm feedback budget before application checks;
dependency-cache misses need a separately calibrated rebuild budget. A faster runner or prebuilt pinned dependency
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
The separate weekly/manual fault workflow expands model/property exploration and
runs actual guard mutations through `just test::vortex-profile discovery`. It
restores the ordinary core Nix cache without adding another cache writer. Its
exploration stage/job limits are distinct from ordinary CI feedback budgets;
the [harness guide](../tests/verification/README.md#external-fault-testing) owns
the commands, limits and failure reporting.
The separate dedicated reference workflow runs weekly and on demand; absent
runner capacity is outstanding evidence, not a passing deployment proof.

M12 adds optional `sql-tools`, exported from `flake.nix` and selected by
`just test::sql-grammar` / `just test::sql-rewrites`. ANTLR 4.13.2, Lean 4.29.1
and pglast 7.13 (`libpg_query`, PostgreSQL 17.7) use the existing nixpkgs lock;
no unrelated lock entries or Zig pins change. Version assertions make upgrades
explicit. The bindings CI shell roots these tools; the ordinary shell and Fuze
runtime do not include them. The checked corpus and limits live in
[contracts/sql](../contracts/sql/README.md). This expands the bindings closure;
M10's old hosted timing samples do not qualify its current cost.

The optional `nix develop .#serving` shell adds pinned nginx for the HTTP/reactive
TLS proof. The default locked Python environment includes `jsonschema` for M20's
offline OpenAPI 3.2.1 / AsyncAPI 3.0 structure, example and trace checks. Official
schema artifacts and hashes live in `tests/fixtures/reactive`; generator output
comes from the public serving types. This uses the existing Nixpkgs lock, without
a separate network package installation or an implicit input revision update.
