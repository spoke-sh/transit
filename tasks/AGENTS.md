# Working on task commands

Start with the [task index](README.md), the owning module and the
[test index](../tests/README.md). These files define the shared contributor and
CI command interface; they do not define another implementation or policy owner.

## Command organization

- A module's default task lists its commands. `just check` and `just ci` are
  navigation commands, not implicit validation or long-running qualification.
- Put related actions underneath their module: `just check fast`, `just check
  core`, `just check all`, `just ci all`, `just ci clean --lane formal`.
  The equivalent `module::task` syntax remains available to machine callers.
- Extend an existing module before adding a new root command. Do not add compound
  top-level forms such as `check-fast`, `check-core` or `ci-clean`, or aliases that
  merely duplicate a module command. Root discovery, formatting and tool-version
  commands retain their existing purposes.
- Each module sets its strict Bash shell and repository-root working directory.
  Forward user arguments as an argument list with positional arguments; do not
  interpolate them into shell code. Keep commands usable from subdirectories.

## Validation scopes and evidence

The fast check runs formatting, tooling, independent Python oracles and links.
Compiled contracts, package tests, real services, disk/recovery checks, frontend
builds and full CI have explicit owners. A fast or selected-lane pass is not full
qualification. Module defaults and dry runs cannot count as executed checks.

Use the [check inventory](../tests/tooling/checks.json) and
[CI inventory](../tests/verification/suite.json), keeping hosted/local selection
consistent. Preserve failure exit codes, uncertainty and incomplete execution in
timing records. Keep generation, validation, preparation and build costs distinct;
do not skip existing assertions or shrink a proof merely to improve its timing.

When moving or renaming tasks, update executable callers, CI catalogs and current
documentation in the same change. Preserve historical commands and their original
outcomes in archived evidence. Avoid compatibility wrappers for superseded tasks.
Run the affected runner regressions and real checks, including committed-source
clean qualification where build or fixture behavior changes. Record which scope
ran and what remains unverified. Keep this file instructional, not a run diary.
