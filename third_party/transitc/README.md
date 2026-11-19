# transitc

The offline Transit language compiler. It composes typed `.transit` modules,
verifies emitted SQL, resolves exact dependencies and publishes SQL/provenance or
migration proposals. Runtime execution remains in [Transit](https://github.com/spoke-sh/transit).

Consumers can use the packaged executable without installing a Zig toolchain:

```sh
nix build .#transitc
./result/bin/transitc --version
nix run .#transitc -- --help
```

The flake exports `packages.<system>.transitc` and `packages.<system>.default`
for x86_64/aarch64 Linux and Darwin. Downstream flakes should pin this repository
to an exact commit and consume that package output. Zig is a build dependency;
it is not included in the executable's runtime closure.

## Develop

```sh
nix develop
zig build
zig build run -- build --help
just check
just test
just test-integration
```

The flake pins the same Zig **0.17.0-dev.2267+48abf1a34** toolchain and Nix inputs
as the source repository, including its Linux loader fixes. See
[toolchain notes](nix/README.md). An optional `.envrc` supports direnv.
The default shell also provides the upstream `transit` executable pinned to
`e7434306334e3692c6f3e123cba0d278fa412196`, plus Python for integration tests.
No sibling checkout is required. The upstream package is a development/test
dependency; it is not part of the packaged transitc executable's runtime closure.

```sh
nix develop .#docs --command just docs-install
nix develop .#docs --command just docs-dev
```

Open `http://localhost:3000/transitc/`. Run `just docs-check` in either shell to
typecheck and build the handbook. `nix flake check` builds and smoke-checks the CLI
and runs the [upstream integration suite](tests/integration/README.md) in a sandbox.
The suites distinguish the frozen upstream baseline, exact semantic parity,
independent grammar/type verification and workspace failure controls.

## Layout

```text
apps/transitc-cli/          executable and command-line integration
packages/transitc-compiler/ pure bounded compiler and test products
packages/transitc-workspace/ source capture, dependencies, reports and artifacts
contracts/                 source contract, independent grammar and corpus
docs/handbook/             Docusaurus guides, reference, and internals
docs/roadmap/              extraction milestones and acceptance criteria
nix/                      pinned toolchain support
tests/integration/        upstream compiler/runtime fixtures and checks
```

The [package map](packages/README.md) records shared ownership, exact dependency
pins and the embedded-consumer boundary. [Attribution](NOTICE.md) records the
source revision and intentional identity differences.

Start with the [documentation index](docs/README.md),
[contributor guide](CONTRIBUTING.md), and [extraction roadmap](docs/roadmap/README.md).
