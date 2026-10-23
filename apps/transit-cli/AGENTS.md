# Working on the Transit CLI

Follow the repository's root instructions and the
[CLI contract](../../contracts/TRANSIT_CLI_V1.md). Keep usage and behavior in the
[component guides](README.md) and [public CLI reference](../../docs/handbook/reference/cli.md).

## Command scope

The public command policy permits exactly two commands:

- `transit server` starts and supervises a local Transit installation.
- `transit console` provides interactive and batch SQL sessions through the
  shared SQL service, including its existing inspection and recovery controls.

## Output and documentation

`transit console --format table|json` controls SQL results on stdout. Errors
are human-readable on stderr. Server logging uses its configuration settings.

Command or option changes must update dispatch, help, consumers, tests and owning
docs together. Preserve accepted work and exact recovery identities when changing
an interface.
