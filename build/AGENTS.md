# Working on build composition

Read the [build index](README.md), [test rules](../tests/AGENTS.md) and
[toolchain rules](../nix/AGENTS.md). Keep runtime implementations in packages and
scenario semantics in their test domains. This directory connects build inputs.

Declare each shared fixture's direct imports in `test_modules.zig`. Reuse the
same module for shared type identity; do not duplicate a module to work around an
import error. Supply actual package modules from the composing build. Preserve
target, optimization profile and all required fixture inputs.

When moving a source, update its registration, callers, manifest and source
selection together. Compile affected probes, run their real parent schedules,
then qualify committed source. A parsed graph or successful compile does not
prove runtime behavior. Source-selection changes also require the runtime
boundary checks described in the toolchain rules.
