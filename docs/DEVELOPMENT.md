# Development

Install Nix with flakes and `nix-command`, then work from the repository root:

```sh
nix develop
just doctor
just check
```

`just build` builds platform executables. To try an application, run
`just examples::run counter` or `just examples::run byte-log`; each launcher owns
fresh local disk-backed infrastructure. See the [examples](../examples/README.md).
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
| Set up or tear down Kubernetes/Substrate | [Reference runbook](../deploy/reference/README.md) |
| Contribute code or documentation | [Agent instructions](../AGENTS.md), [documentation ownership](README.md#where-documentation-lives) |

## Package workflow

Each implemented Zig library owns `build.zig`, `build.zig.zon`, direct dependencies,
and an exported module. Local dependencies allow coordinated monorepo changes;
consumers use module interfaces, not sibling source imports. The root build
composes those packages; `just test::packages` checks them independently.
Package READMEs give focused commands and integration requirements.

All packages use the Nix-pinned compiler. External dependencies belong to their
consumer's manifest with immutable revision/hash pins. Libraries become static
or shared artifacts only when needed; independent releases and stable public
APIs remain future work. Frontend tooling will live in a separate Vite+/pnpm
workspace, connected through language-neutral contracts.

## Verification

Run `just check` for formatting, tooling, unit tests, schema drift, and local
Markdown links. Run `just ci` for the local package/storage/service/caller suite.
Reference-cluster and physical-capacity proofs have explicit extra prerequisites;
passing local checks does not establish those deployment guarantees. Choose
additional proofs from the [test guide](../tests/README.md) for the boundary you
change, and record failures against their owning design.
