# Working on the Transit CLI

Follow the repository's root instructions and the
[CLI contract](../../contracts/TRANSIT_CLI_V1.md). Keep usage and behavior in the
[component guides](README.md) and [public CLI reference](../../docs/handbook/reference/cli.md).

## Command scope

The public command policy permits exactly two commands:

- `transit server` starts and supervises a local Transit installation.
- `transit console` provides interactive and batch SQL sessions through the
  shared SQL service. Statement execution and recovery belong to shared owners.

## Statement results and future console work

Follow the root [statement/result-set direction](../../AGENTS.md#sql-statements-and-result-sets-future-implementation-direction).
The target console consumes shared command completions and logical result sets;
submission/settlement, cursor ownership and cancellation belong in the shared
SQL client and service, not a parallel console execution framework. This is
future architecture; help and usability changes need not implement it first.

Render each logical result coherently across fetch batches. A transport batch
must not create a new table, reset column layout or add an empty table at EOF.
Use explicit row/byte limits for display buffering, keep JSON consumption
streaming, and distinguish display truncation from incomplete query execution.
Only verified terminal evidence permits a successful completion footer.

Keep interim adapters to current APIs small. Preserve typed values, useful SQL
errors, exact write outcomes and uncertainty without making operation tokens,
phases or recovery commands part of the target interactive workflow. Do not
solve this boundary by adding more dot commands or inferring outcomes from SQL
text. Future result-set work must update its shared owners and consumers together.

## Output and documentation

`transit console --format table|json` controls SQL results on stdout. Errors
are human-readable on stderr. Server logging uses its configuration settings.

Command or option changes must update dispatch, help, consumers, tests and owning
docs together. Preserve accepted work and exact recovery identities when changing
an interface.
