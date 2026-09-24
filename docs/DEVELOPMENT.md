# Development

Install Nix with flakes and `nix-command`, then work from the repository root:

```sh
nix develop
just doctor
just check
```

`just board::install` installs locked frontend dependencies. `just build` builds
platform executables including the embedded Board. Use
`just launchers::local::up` for a persistent native system with Board and the
counter example, then `status`, `inspect`, `logs`, `send`, or `restart` in that
same task group. `down` preserves data; `reset` explicitly deletes a stopped
installation. The [launcher guide](../launchers/README.md) owns the workflow,
configuration and recovery limits.

`launchers::compose` exercises the same development scenario in containers.
`launchers::reference` owns Kubernetes/Substrate qualification. These steps
preserve protocol semantics while adding deployment-specific evidence; they do
not imply automatic data migration or equivalent runtime isolation.
The [examples](../examples/README.md) also provide disposable one-shot demos.
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
| Run and inspect a persistent local system or Compose stack | [Launchers](../launchers/README.md) |
| Set up or tear down Kubernetes/Substrate | [Reference runbook](../deploy/reference/README.md) |
| Contribute code or documentation | [Agent instructions](../AGENTS.md), [documentation ownership](README.md#where-documentation-lives) |

Board's Vite+/pnpm workspace is implemented. Use `just board::demo` to inspect a
running disposable realm, `just board::check` for frontend/contract checks, and
`just board::browser` for the real UI proof. [Board's app guide](../apps/board/README.md)
owns configuration, authentication and runnable commands.

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
