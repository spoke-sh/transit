# Repository commands

Run commands from the repository root inside `nix develop`.

## Task interface

The root [justfile](../justfile) keeps common commands: `build`, `check`, `ci`,
`fmt`, and `doctor`. Modules under `tasks/` own the grouped recipes:
[reference](reference.just), [test](test.just),
[examples](examples.just), and [contract](contract.just).
Use double colons, for example `just reference::up` or `just examples::run counter`.

`just` lists common commands and namespaces. `just reference` or
`just --list reference` lists that namespace's recipes; bare module commands only
list tasks. In particular, `just test` lists the test recipes; use
`just test::unit` to run unit tests. `just --list --list-submodules` shows the full
tree.

Each module explicitly sets the strict Bash shell and repository-root working
directory. Recipes work from repository subdirectories after entering the dev
shell. `just ci` composes checks through module dependencies;
reference deployment and physical-capacity tests remain explicit commands.

| Command | What it does today |
| --- | --- |
| `just` | Lists available recipes |
| `just doctor` | Prints tool versions, including Ursula and Kubernetes tooling, without contacting a cluster |
| `just check` | Checks Nix/Zig formatting, the toolchain smoke check, Zig unit tests, generated public-contract drift, local Markdown links, and diff whitespace |
| `just ci` | Runs foundation, standalone package, disk recovery, service, and independent Zig caller checks in the same development shell |
| `just fmt` | Formats Nix and Zig files |
| `just build` | Installs platform executables: node, runtime controller and CLI |
| `just examples::build` | Installs `example-counter` and `example-byte-log` |
| `just examples::run counter`, `just examples::run byte-log` | Provisions disposable disk Ursula and an authority, runs the real example, and verifies its committed state |
| `just test::unit` | Runs Zig unit/protocol tests without a service |
| `just test::packages` | Checks each library independently of root build orchestration |
| `just test::storage` | Launches isolated disk-backed Ursula, tests conditional writes and bounded reads, then kills/restarts it and verifies recovery |
| `just test::service` | Proves signed HTTP ingress, scoped/revoked reads, worker replacement and authority/storage restart on loopback |
| `just test::callers` | Runs the actual counter and byte-log example binaries through the public client against the same node, including dropped commit responses, stale owners and restart recovery |
| `just contract::generate`, `just contract::check` | Regenerates or checks the language-neutral JSON Schema derived from public Zig types |
| `just test::capacity` | Linux/Docker proof of real disk pressure, reserved control progress, checkpoint/trim and restart on an owned ext4 image |
| `just reference::up`, `just reference::images`, `just reference::test`, `just reference::down` | Sets up, builds, tests and removes the owned Kubernetes/Substrate reference deployment |
| `nix flake check` | Evaluates outputs and runs Zig/TypeScript, Ursula, and Kubernetes CLI smoke checks without network access |

Keep root recipes for common entry points and put specific workflows in the
corresponding module. Add runnable work, not placeholder success.

For prerequisites, proof boundaries, and troubleshooting, use the
[test guide](../tests/README.md), [reference runbook](../deploy/reference/README.md),
[toolchain guide](../nix/README.md), or [examples](../examples/README.md).

`just test::inspection` exercises the signed, bounded public read surface against
isolated disk-backed Ursula.
