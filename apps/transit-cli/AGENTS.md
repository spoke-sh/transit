# Working on the Transit CLI

Follow the repository's root instructions and the
[CLI contract](../../contracts/TRANSIT_CLI_V1.md). Keep usage and behavior in the
[component guides](README.md) and [public CLI reference](../../docs/handbook/reference/cli.md).

## Command scope

The public command policy permits exactly two commands:

- `transit server` starts and supervises a local Transit installation.
- `transit console` provides interactive and batch SQL sessions through the
  shared SQL service, including its existing inspection and recovery controls.

Keep this boundary deliberate. Do not add other top-level commands, command
groups, aliases or a second query shell. Root `--help` and `--version` are
informational options. Private supervisor child entrypoints are implementation
details and must stay out of the public interface.

Existing extra routes (`app`, `auth`, `catalog`, `file-query`, `query` and the
`serve` alias) do not establish a precedent for expanding the CLI. Do not move
them under `transit console` as subcommands or dot commands to meet the two-command
limit. The console already owns its SQL session workflow; it must not become a
container for unrelated tools.

Place new capabilities with their owning service or library. Expose operations
through the console only when they belong to its shared SQL/session contract.
Reuse that contract's validation, authorization and recovery semantics; do not
invent executable SQL for unsupported operations or add another authority.

## Output and documentation

Keep result presentation, error rendering and server logging distinct in their
documentation. `transit console --format table|json` currently controls SQL
results on stdout. The existing global `--diagnostics=json` controls structured
errors on stderr and must precede the command; it is not a verbosity or debug
logging switch. Do not add global options merely to expose library internals.

Document implemented behavior accurately while the extra routes remain. A
policy change alone does not remove a command or change output. Any command or
option removal must update dispatch, help, consumers, tests and owning docs
together, following the repository's current-v1 cutover policy. Preserve accepted
work and exact recovery identities when changing an interface.
