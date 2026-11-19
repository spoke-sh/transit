# Working on the Transit CLI

Follow the repository's root instructions and the
[CLI contract](../../contracts/TRANSIT_CLI_V1.md). Keep usage and behavior in the
[component guides](README.md) and [public CLI reference](../../docs/handbook/reference/cli.md).

## Command scope

The public command policy permits exactly three commands:

- `transit server` starts and supervises a local Transit installation.
- `transit console` provides interactive and batch SQL sessions through the
  shared SQL service. Statement execution and recovery belong to shared owners.
- `transit migrate` plans, inspects, applies, resumes and verifies ordered
  application schema and data migrations through the shared SQL service and
  `DirectMigration` ledger without reading `.transitrc` startup files.

Source compilation and suite orchestration live in the separate transitc repository.
Transit supplies only the compiled-case native test host.

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

Format command `--help` consistently with `transit server` and `transit console`:

- Start with one short sentence describing the command, then a blank line.
- Keep `Usage: transit COMMAND ...` on one line, with options inline. Use
  `[OPTIONS]` for a compact synopsis when needed; do not manually wrap it across
  continuation lines.
- Follow with a blank line and `Options:`. List every supported option, including
  `--help`, on its own line with two-space indentation, literal flags and value
  placeholders, and aligned descriptions separated by at least two spaces.
- Keep descriptions concise. Put defaults, allowed values and repeatability
  beside the relevant option. Use `Show this help` for `--help`.
- End after the options list with a newline. Keep workflow explanations,
  guarantees, prerequisites and detailed option-combination rules in the owning
  guides; do not append prose sections below the list. Root command listings and
  action-based commands may include `Commands:` or `Actions:` before `Options:`.
- Verify the real executable's help output, including successful exit status and
  stdout/stderr separation, after editing help text.

Keep normal output and diagnostics concise and actionable, following the
[public output conventions](../../docs/handbook/reference/cli.md#output-philosophy-explain-locate-guide).
Errors name the problem once, adding a location or next step only when useful;
do not dump the full help text for routine invocation errors. Successful help
and version output go to stdout without requiring configuration or a server.

`transit console --format table|json` controls SQL results on stdout. Errors
are human-readable on stderr. Server logging uses its configuration settings.

Command or option changes must update dispatch, help, consumers, tests and owning
docs together. Preserve accepted work and exact recovery identities when changing
an interface.
