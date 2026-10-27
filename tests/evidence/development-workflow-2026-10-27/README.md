# Development workflow calibration

These automatic reports retain the comparison basis for CI cost budgets and the
package-compilation worker count beyond ordinary CI artifact retention. The
[runner owner](../../runner/AGENTS.md) maintains these references when recalibrating
the workflow. They are observations, never inputs that can make a correctness
check pass. Current commands belong in the [runner guide](../../runner/README.md).

| Record | Source and scope |
| --- | --- |
| [Comparison cost](comparison-cost.json) | Successful ordinary/browser run [40441691526](https://github.com/spoke-sh/transit/actions/runs/40441691526), source `40e70d202`; partial dependency-cache reuse. The reporter source is recorded separately. |
| [Warm 1](warm-1-cost.json), [warm 2](warm-2-cost.json), [warm 3](warm-3-cost.json) | Three successful full ordinary/browser runs at `93503e966`; all configured GitHub caches restore matching keys. |
| [Warm task/resource records](warm-1/core.meta.json) | One full task/metadata set under `warm-1/`; SDK task records under `warm-2/` and `warm-3/` retain the full comparison range. `comparison/` holds the baseline's core, growth and both SDK task records. |
| [SDK shell steps](sdk-shell-steps.json) | Extracted Actions API steps for both SDK jobs in the comparison, three warm samples and final cold run; original timestamps/outcomes plus derived durations. This explicitly transformed record excludes cache transfer and other setup. |
| [Cold cost](cold-cost.json), [SDK tasks](cold/bindings-1.json), [SDK metadata](cold/bindings-1.meta.json), [browser tasks](cold/browser.json), [browser metadata](cold/browser.meta.json) | Successful full run [40465924045](https://github.com/spoke-sh/transit/actions/runs/40465924045) at `ab7150250`, GitHub dependency restores disabled. The two task subsets retain the final provider-listener and browser controls. |
| [Failed cold attempt](cold-restart-failed-cost.json) | `722ae22df`, run 40459344495: Rust's Ursula restart fails; the report remains inconclusive and cannot calibrate a passing budget. Retained to distinguish the unsuccessful attempt from its corrected replacement. |
| [Fast checks](fast-checks.json) | Committed-source clean run at `49546a3f4`, all 39 groups; recorded check time excludes clone/development-shell setup. |
| [One package worker](packages-one-worker.json), [two package workers](packages-two-workers.json) | All 34 standalone package manifests at clean `8333fdfcd`, fresh workspaces restricted to CPUs 0–3, existing Nix store and Zig dependency cache. |

Runner reports are copied byte-for-byte. The separate SDK shell-step extract
is the explicitly described transformation above. Source revisions, original
outcomes, toolchain identities, commands and measurement limits retain their
original meaning. Per-command diagnostic logs remain in the originating ignored
artifacts; these selected summary reports do not provide a complete log archive.
The package comparison is one sequential pair, not a cold-cache or variance study.
Its largest child RSS is not aggregate peak memory. CI cost sums job wall time,
not a billed price. Failed and incomplete runs cannot calibrate a passing budget.

The cost reports retain `budget_met: false`: collection predates the matching
103-task budget. Each record's original run conclusion and cost observations remain
unchanged. The qualification account explains calibration separately. Inventory
identities bind ordered task ownership and lane allocation, including browser;
they do not claim identical internal test instructions across sources.

The [qualification account](../../../docs/history/qualification/verification.md#test-ownership-and-development-workflow--2026-10-27)
explains the comparison and calibration. [SHA256SUMS.txt](SHA256SUMS.txt) records
the retained JSON bytes. From this directory, run `sha256sum --check SHA256SUMS.txt`
to verify their integrity; that check does not execute the original scenarios.
