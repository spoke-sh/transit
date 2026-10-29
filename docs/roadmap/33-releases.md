# 33. Release distribution

[Roadmap](README.md) · **Status:** In Progress

Publish a qualified tagged revision with one artifact/compatibility manifest.
Existing [Nix packages](../../nix/README.md) and
[source onboarding](../handbook/guides/quickstart.md) are the baseline, not a release pipeline.

Consume the qualified [operations and upgrade procedures](22-operations-and-recovery.md).
This milestone packages and verifies their installation experience; operational
recovery, compatibility and conversion semantics remain with that owner.

## Delivered foundation

- Server and console help end after their options; component guides retain the
  configuration and operating instructions.
- One `VERSION` baseline (`0.0.1`) aligns runtime, SDK and package metadata.
  The CLI embeds Git provenance; Nix passes its source revision explicitly.
  CI checks package consistency and exact clean release tags. See the
  [release policy](../handbook/reference/versioning.md#software-releases).

- Tag automation builds the static Linux x86_64 bundle and per-executable images,
  packages the existing Helm chart, and gates GitHub Releases/GHCR publication on
  ordinary CI plus installed/container checks. PR/manual runs only build.
  The repository installer checks downloads before selecting a versioned prefix.
  See the [distribution reference](../handbook/reference/distribution.md).

- Distribution automation also builds Linux ARM64 executables on a native runner,
  installs downloaded archives without Nix, and checks embedded Board assets,
  inspection, SQL and retained restart. The curl installer supports a verified
  offline download directory. Post-publication checks exercise anonymous Release,
  image and chart downloads.
- GitHub Release SDK archives cover the nine language packaging families and a
  Zig source dependency closure. ReleaseSafe native bindings target Linux x86_64 and ARM64
  with glibc 2.28; their loader/dependency checks reject Nix linkage. The workflow
  runs existing installed raw/Station consumers, plus the archived Zig
  application's installation, interruption and compatible replacement schedule.
  Public language registries are deferred by the repository owner.
- The artifact assembly includes a source-pinned handbook/specification archive
  and a generated Linux Homebrew formula with exact executable archive hashes.
  The Homebrew gate installs the actual candidate and exercises its runtime.

These are executable publication gates, not a record that every new job has
passed or that a public release exists. First publication and the new platform,
SDK and installer matrix must complete before closing their acceptance items.

- Nightly distribution uses a source-bound prerelease identity, per-language
  package version mappings, the shared publication matrix, and an explicit
  installer channel. The channel advances only after anonymous checks pass;
  immutable tags and assets are retained. Executed hosted publication remains
  a separate acceptance requirement.
- Native Linux x86_64 and ARM64 jobs build and exercise every SDK family and
  container image. Assembly verifies both image closures and publishes one OCI
  index per executable; installed and anonymous checks run on both architectures.
- Downloaded release executables run Board's catalog/result API schedule and a
  native Chromium onboarding gate on both Linux architectures. These reuse the
  workbench's explicit catalog/SQL connections, bounded previews and temporary
  workbook scenarios. Runtime and frontend assets come from the release archive;
  source-built Board checks remain separate. The added jobs still require
  successful hosted execution before this onboarding item is qualified.
- Installed native downloads also run the existing controlling-terminal and
  editor interaction scenarios. A supervisor-death schedule joins its children,
  restarts against retained disk data and checks accepted rows and activation
  fencing. Successful execution of these additional platform gates remains
  required; registering them does not qualify a release.

## Remaining dependencies

- Qualify and publish the first tagged release, including anonymous registry
  visibility. Preserve any failed or incomplete hosted result in the PR handoff.
- macOS requires replacements for Linux terminal/inotify handling, parent-death
  supervision and the synchronized authority clock. Windows additionally needs
  its process, terminal and native I/O integration. Packaging cannot remove those
  runtime safety requirements. Linux ARM64 SDK and container jobs are part of the distribution matrix;
  successful native hosted execution remains required before advertising that release set.
- Board catalog discovery, dataset previews and temporary workbooks are
  implemented; the release workflow now exercises them from installed packages.
  Saved/shared workbooks and governed review still depend on the remaining
  [workbench scope](27-board-reimplementation.md), and cannot yet complete those
  capability-dependent onboarding criteria.
- Installed MCP business-resource/App checks depend on
  [the planned MCP service](28-mcp-service-and-apps.md). There is no endpoint
  or App package to distribute yet.

Static/component checks and a running server do not complete the milestone's
remaining capability-dependent onboarding matrix.

## Desktop implementation follow-ups

Nightly publication and Linux ARM64 distribution land first. Desktop ports are
separate changes, in this order:

1. Define and test platform owners for parent/child lifetime, trusted clock
   sampling, terminal input, editor save detection, private files and durable
   replacement. Preserve uncertainty bounds and failure/recovery gates; a precise
   wall-clock timestamp alone does not establish a bounded time sample.
2. Port macOS ARM64, then Intel. Qualify native startup, SQL, retained restart,
   abrupt supervisor loss, interactive console/editor behavior and installed SDK
   consumers before adding archives and Homebrew selection to publication.
3. Port Windows x64, then ARM64. Supply target OpenSSL dependencies, process job
   containment, console/signal handling and private/durable filesystem operations;
   qualify the same runtime and SDK schedules before adding archives and a
   checksummed PowerShell installer.

Initial cross-compilation found a Windows stderr-handle initializer that is now
resolved at runtime. Further Windows work includes private spill-file creation
and target TLS libraries. macOS ARM64 SDK fixtures cross-compile with the pinned
compiler; this does not qualify execution, native packaging or the local server.
These probes do not add desktop targets to the supported distribution matrix.

## Delivery sequence

1. Inventory executables, libraries, SDKs, contracts, embedded assets and deployment
   packages with owners, dependencies, notices and supported OS/architecture.
   External Ursula/Substrate artifacts retain their identities.
2. Build archives, checksums, provenance and manifests for GitHub Releases. Pin
   exact contract/ABI identifiers; shared v1 labels do not prove compatibility.
3. Publish version-pinned Nix outputs, a verified HTTPS installer, Homebrew,
   Docker/OCI and Helm packages where qualified. Define cache trust, registry
   ownership and failure/rollback policy.
4. Package SDKs/libraries with generated resources and native dependency closure.
   Test consumers outside the checkout, including the qualified
   [direct-client, Station and mixed programming models](31-programming-model.md).
   An ordinary data-client installation must not require the optional Station
   runner artifact; each release advertises its actual operation/language matrix.
5. Publish matching handbook/specifications and test installed startup, SQL access,
   the first-dataset walkthrough, declared computation and policy inspection,
   application installation and compatible worker replacement. State the released
   object kinds and lifecycle capabilities explicitly; an installed server alone
   does not complete onboarding.
   Include the qualified [Board workbench](27-board-reimplementation.md) and
   its embedded assets: exercise catalog discovery, bounded preview, a saved
   workbook and configured review capabilities from the installed package
   without checkout assets, a frontend development server or CDN dependencies.
6. Package the qualified MCP endpoint and App assets with their shared contracts,
   identity configuration and exact host/extension support matrix. Exercise one
   published business resource from an installed agent host without repository
   state. Preserve the public `transit server` / `transit console` command boundary;
   any separately justified stdio bridge has an explicit packaging owner.

## Release gate

Tag automation qualifies before publishing. Partial publication is visible and
retryable without replacing immutable artifacts. Installed commands work at the
documented prefixes without development-shell state.

Require matching artifacts, platform smoke tests, notices and the selected
[qualification evidence](32-qualification-and-benchmarks.md). Explain fresh
installation versus incompatible upgrade, preserve revocations and reject
mismatches before execution. Application revisions remain separate from runtime
upgrades.
