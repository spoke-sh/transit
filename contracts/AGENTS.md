# Working on contracts

Start with the [interface map](../docs/handbook/reference/interfaces.md), the
owning contract and its generator/source types. This directory owns exact wire,
schema, ABI and neutral fixture definitions. Public guides explain supported
operations; parser acceptance and a model theorem do not enable an interface.

Follow the [versioning policy](../docs/handbook/reference/versioning.md): Transit
has one current v1 definition before 1.0. Incompatible changes replace that
definition and update all consumers, generated resources, saved-work rejection
checks and signing fixtures together. Do not add fallback decoders, old-profile
aliases or a current-definition default when reading persisted artifacts.

Regenerate reflected schemas from their owning types using
[contract tasks](../tasks/contract.just); do not edit generated copies as another
authority. Preserve independent fixture/oracle checks. Reference SQL grammar,
Lean rewrite proofs and executable Zig semantics have distinct owners in the
[SQL guide](sql/README.md).

Inside `nix develop`, use `just check contracts` for generated schemas and
fixtures. Its TypeScript validator needs the pinned client compiler; setup and
clean commands are in the [tooling guide](../tests/runner/README.md).
Run affected caller/compatibility and model checks as well. `just check fast`
does not compile these exporters, and a contract check alone does not qualify
runtime execution or every language adapter.
