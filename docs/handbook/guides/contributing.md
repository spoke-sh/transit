# Contributing

This guide is for contributors building and checking the repository. Application
users can start with [Run Transit locally](quickstart.md); documentation
contributors use the [site guide](../README.md).

Prepare the checkout with the [development toolchain guide](../../../nix/README.md),
then use the [repository task reference](../../../tasks/README.md) for builds,
locked dependency installation and checks. The toolchain pins the compiler and
frontend dependencies; build dependent packages from the same checkout.

For persistent development systems, the
[launcher overview](launchers.md) compares local, Compose and reference placements.
Their [repository runbook](../../../launchers/README.md) owns setup, commands,
configuration and recovery. New resource-backed installations require Linux and
a synchronized trusted clock. Toolchain support for other platforms is separate
from these runtime requirements.

Incompatible protocol definitions require an explicit cutover. Automatic history
or signature conversion is not implemented; preserve existing recovery material.

## Shared documentation

Start changes from the [data model](../reference/data-model.md): what can an
application describe, what operation applies it, and what evidence shows the
result? Identify the owning definition, source/dependency basis, authorization,
execution lifetime and failure behavior. A worker or transport is an
implementation choice within those contracts.

Use the same definition and lifecycle operations across SQL, SDK and visual
interfaces. Preserve the distinction between validation, publication, activation
and completion; a declaration accepted by a compiler may have no executable
adapter. The [current capability map](../reference/data-model.md#declarations-and-current-interfaces)
identifies those gaps. Custom workers extend the supported data operations.

Follow the [versioning and hard-cutover policy](../reference/versioning.md) for
Transit-owned contracts. Before 1.0, replace the current v1 definition and remove
superseded paths, updating all consumers and proof fixtures in the same cutover.
Do not add a parallel compatibility implementation or claim that an unchanged
v1 label makes incompatible builds safe to combine.

Start from the same [public architecture](../reference/architecture.md),
[glossary](../reference/glossary.md) and topic reference that an application user
reads. Update behavior, limits, recovery and useful rationale there with code.
Use exact component/wire owners for API details and the proof ledger for measured
claims. Planning history must not be the only explanation of a current rule.
Follow the [ownership guide](../../README.md#where-documentation-lives).

## Documentation site

Edit the owning Markdown, not a copy in the frontend. The
[site guide](../README.md) owns preview and validation commands.
Site checks cover strict types, generated API rendering, published command
conventions and a production build with broken-link checks. Browser proofs
exercise both root and prefixed hosting.

## Guides by responsibility

| Task | Guide |
| --- | --- |
| Install, inspect, or update tools; understand CI caching | [Development toolchain](../../../nix/README.md) |
| Browse common and namespaced commands | [Task reference](../../../tasks/README.md) |
| Use a library or configure a service | [Component map](../reference/components.md) |
| Change public types or generate bindings | [transit-protocol](../../../packages/zig/transit-protocol/README.md) |
| Run proofs and interpret their limits | [Tests](../../../tests/README.md) |
| Run, inspect and update local, Compose or reference installations | [Launchers](../../../launchers/README.md) |
| Set up or tear down Kubernetes/Substrate | [Reference runbook](../../../deploy/reference/README.md) |
| Contribute code or documentation | [Agent instructions](../../../AGENTS.md), [documentation ownership](../../README.md#where-documentation-lives) |

## Source layout

`apps/` contains runtime entry points; `packages/` contains the shared libraries
needed to build Transit. Board and its TypeScript browser libraries stay there.
`sdks/<language>/` contains consumer APIs, language packaging and installation
guides. SDKs may depend on shared packages; runtime apps and packages must not
depend on SDKs. Documentation catalogs can reference SDK Markdown sources.

The shared Zig client, Station and native binding bridge remain in `packages/zig/`.
The [Zig SDK](../../../sdks/zig/README.md) exports their existing modules to consumers.
Examples exercise SDK entry points. The root build composes both examples and
runtime targets; packaged runtime builds explicitly disable SDK examples and
exclude SDK source. The [SDK tooling guide](../../../sdks/README.md) names the boundary
and isolated-consumer checks.

## Package workflow

Each Zig library owns `build.zig`, `build.zig.zon`, direct dependencies and an
exported module. Local dependencies allow coordinated monorepo changes;
consumers use module interfaces, not sibling source imports. The root build
composes those packages. The [task reference](../../../tasks/README.md) distinguishes
standalone package compilation, shared unit execution and focused engine proofs.
Package READMEs give integration requirements.

External dependencies belong to their consumer’s manifest with immutable
revision/hash pins. Libraries become static or shared artifacts only when
needed. Independent package releases are not available. Board frontend tooling
lives in a Vite+/pnpm workspace, connected through generated OpenAPI and shared
Transit contracts. [Board’s app guide](../../../apps/transit-board/README.md) owns
configuration, private access boundaries and focused validation.

## Verification

Run the repository checks for formatting, tooling, unit tests, contract drift,
frontend lint/types/tests and Markdown links. Before pushing committed changes,
run the clean-checkout suite to expose dependencies hidden by workspace build
outputs. The [task reference](../../../tasks/README.md) owns these commands.
Reference-cluster and physical-capacity proofs have explicit extra prerequisites;
passing local checks does not establish those deployment guarantees. Choose
additional proofs from the [test guide](../../../tests/README.md) for the boundary
you change, and record executed outcomes and remaining limits there.
