# Development

Install Nix with flakes and `nix-command`, then work from the repository root:

```sh
nix develop
just doctor
just check
```

`just transit-board::install` installs locked frontend dependencies. `just build` lists
the Zig optimization profiles; `just build::debug` builds platform executables
including the embedded Board. Use `just build::release-safe` for an optimized
build with safety checks; see the [build profiles](../tasks/README.md#build-profiles)
for other modes, component selection and output paths. Use
`just launchers::local::up` for a persistent native system with Board and the
counter example, then `status`, `inspect`, `logs`, `send`, `update`, or `restart` in that
same task group. `down` preserves data; `reset` explicitly deletes a stopped
installation. The [launcher guide](../launchers/README.md) owns the workflow,
configuration and recovery limits.

`launchers::compose` exercises the same development scenario in containers.
`launchers::reference` provides a persistent Kubernetes/Substrate installation
and separate qualification tasks. All three profiles distinguish candidate
`build`, deployment `update`, and selected-version `restart`. These steps
preserve protocol semantics while adding deployment-specific evidence; they do
not imply automatic data migration or equivalent runtime isolation.
The [examples](../examples/README.md) also provide disposable one-shot demos.
Per-checkout `.env` settings loaded by `.envrc` configure Board's listen address,
port and browser origin, including remote LAN development. See the
[configuration guide](../launchers/README.md#local-development-configuration).
Protocol v2 requires a fresh development realm; automatic migration of v1
histories and signatures is not implemented.

## Guides by responsibility

| Task | Guide |
| --- | --- |
| Install, inspect, or update tools; understand CI caching | [Nix toolchain](../nix/README.md) |
| Browse common and namespaced commands | [Task reference](../tasks/README.md) |
| Use a library or configure a service | [Component map](ARCHITECTURE.md#planned-monorepo-decomposition) |
| Change public types or generate bindings | [transit-protocol](../packages/zig/transit-protocol/README.md) |
| Run proofs and interpret their limits | [Tests](../tests/README.md) |
| Run, inspect and update local, Compose or reference installations | [Launchers](../launchers/README.md) |
| Set up or tear down Kubernetes/Substrate | [Reference runbook](../deploy/reference/README.md) |
| Contribute code or documentation | [Agent instructions](../AGENTS.md), [documentation ownership](README.md#where-documentation-lives) |

Board's Vite+/pnpm workspace is implemented. Use `just transit-board::demo` to inspect a
running disposable realm, `just transit-board::check` for frontend/contract checks, and
`just transit-board::browser` for the real UI proof. [Board's app guide](../apps/transit-board/README.md)
owns configuration, private access boundaries and runnable commands.

## Package workflow

Each implemented Zig library owns `build.zig`, `build.zig.zon`, direct dependencies,
and an exported module. Local dependencies allow coordinated monorepo changes;
consumers use module interfaces, not sibling source imports. The root build
composes those packages; `just test::packages` checks them independently.
Package READMEs give focused commands and integration requirements.

All packages use the Nix-pinned compiler. External dependencies belong to their
consumer's manifest with immutable revision/hash pins. Libraries become static
or shared artifacts only when needed; independent releases and stable public
APIs remain future work. Board frontend tooling lives in a Vite+/pnpm
workspace, connected through generated OpenAPI and shared Transit contracts.

## Verification

Run `just check` for formatting, tooling, unit tests, schema drift, and local
Markdown links. Run `just ci` for the local package/storage/service/caller suite.
Reference-cluster and physical-capacity proofs have explicit extra prerequisites;
passing local checks does not establish those deployment guarantees. Choose
additional proofs from the [test guide](../tests/README.md) for the boundary you
change, and record failures against their owning design.
