# 28. Release distribution

[Roadmap](README.md) · **Status:** Planned

Publish a qualified tagged revision with one artifact/compatibility manifest.
Existing [Nix packages](../../nix/README.md) and
[source onboarding](../handbook/guides/quickstart.md) are the baseline, not a release pipeline.

Consume the qualified [operations and upgrade procedures](17-operations-and-recovery.md).
This milestone packages and verifies their installation experience; operational
recovery, compatibility and conversion semantics remain with that owner.

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
   [direct-client, Station and mixed programming models](26-programming-model.md).
   An ordinary data-client installation must not require the optional Station
   runner artifact; each release advertises its actual operation/language matrix.
5. Publish matching handbook/specifications and test installed startup, SQL access,
   the first-dataset walkthrough, declared computation and policy inspection,
   application installation and compatible worker replacement. State the released
   object kinds and lifecycle capabilities explicitly; an installed server alone
   does not complete onboarding.
   Include the qualified [Board workbench](22-board-reimplementation.md) and
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
[qualification evidence](27-qualification-and-benchmarks.md). Explain fresh
installation versus incompatible upgrade, preserve revocations and reject
mismatches before execution. Application revisions remain separate from runtime
upgrades.
