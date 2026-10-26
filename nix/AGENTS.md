# Working on build inputs and toolchains

Start with the [toolchain guide](README.md), `flake.nix`, `flake.lock` and the
owning derivation. Keep source selection in [build-sources.nix](build-sources.nix)
and preserve the runtime's independence from SDK source. Build inputs are not
another runtime behavior or contract owner.

Separate dependency manifests, frontend assets and native source. Preserve all
consumed schemas, generated resources, fixtures and build scripts. Do not skip
missing inputs or make a build pass by conditionally omitting a target. Retained
proof observations differ from executable fixtures and live benchmark budgets.
Changes to relevant inputs must invalidate their outputs; unrelated navigation
and records must not invalidate package builds.

Use the locked tools in `nix develop`, run `just doctor` for toolchain changes,
and make version/hash updates deliberately. Do not change pins or fixed-output
hashes just to avoid investigating a failed build. A warm store path is not
evidence that a changed dependency fetch can reproduce its pinned output.

For source-selection or runtime packaging changes, run
`just bindings::runtime-boundary` from committed source. It checks invalidation,
preserved manifests, the actual offline native/runtime builds and executable
entry points. Run affected fixture/launcher checks when their inputs change.
Report the scope, cache conditions and omitted qualification explicitly.
