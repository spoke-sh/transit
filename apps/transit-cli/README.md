# transit-cli

The local server starts and supervises a separate `transit-board`
process by default in version-1 local installations, with `--no-ui` for headless operation. See the
[server guide](docs/server.md#default-board-and-compatibility) for grants and compatibility.

The `transit` executable provides the local `server`, interactive/batch `console`,
explicit signed query shell, saved Table mutation commands and catalog operations. Existing `rey-cli`
administration commands remain separate.

The [server/console contract](../../contracts/TRANSIT_CLI_V1.md) defines commands,
configuration and recovery. Shared parser and
cursor assistance lives in Fuze/query packages. The [console guide](docs/console.md)
covers versioned configuration, terminal editing, trust and exact recovery.
The [local server guide](docs/server.md) describes the implemented supervisor,
private native gateway and selected dependency/credential profile. Focused recovery,
gateway pressure, physical capacity and clean-checkout qualification are recorded in the [proof ledger](../../tests/README.md). The explicit query shell uses dot commands.
The local gateway supports [localhost and explicit tunnel aliases](docs/server.md#local-names-and-ssh-tunnels)
and reports its URL and accepted authorities in the ready record.

The [public CLI reference](../../docs/reference/cli.md#output-philosophy-explain-locate-guide)
defines concise errors, useful coordinates, recovery guidance, streams and exit
statuses. Use `transit server --help`, `transit console --help` or application
operation help such as `transit app install --help` for supported options and
configuration guidance. `just test::cli-diagnostics` checks the real executable's
invocation and configuration failures without starting an installation.
Put `--diagnostics=json` before the command for structured stderr errors; result
stdout keeps its command-specific format. See the
[structured error reference](../../docs/reference/cli.md#structured-errors).

Bare `transit console` derives its connection from the local installation without
a generated configuration file. Server, explicit connection and management
configuration use YAML by default; `.transitrc` remains a DuckDB-style startup
file containing dot commands.

The console runs `-c 'SELECT COUNT(*) FROM items'`, `-f queries.sql` or interactive
SQL with automatic query progress and verified results. The local connection
also executes INSERT/UPDATE/DELETE against `items` without extra configuration.
Separate connections require writer routes; compatible CREATE TABLE requires
an explicitly configured catalog;
`.help INSERT` and `.help CREATE TABLE` explain syntax, configuration and
recovery inside the shell. Its `.transitrc` hierarchy
configures `.connect` and `.mode`; server `transit.yaml` settings overlay the
installed bundle's defaults. See the linked component guides for precedence,
limits and recovery.

## Local file queries

`transit file-query` executes finite SQL over captured CSV/JSONL files or stdin,
with explicit, sampled, full or raw schemas. The [file-query guide](docs/file-query.md)
defines exact values, checked gzip, temporary disk quotas and completion records.
It uses local OS access and creates no durable Transit job.

## Explicit catalog operations

`transit catalog` compiles `CREATE TABLE` offline, saves signed initialization,
creation and conditional policy commands, and explicitly submits and observes
them. The [catalog guide](docs/catalog.md) defines typed inputs, private artifacts,
current authority and exact saved recovery through the shared catalog caller.

## Explicit Table mutations

`transit mutate` compiles bounded SQL, saves exact prepared commands to new
private files, and explicitly submits and observes them through an authorized
Table writer. Only `submit` dispatches. The [mutation guide](docs/mutations.md)
defines connection fields, commands, bounds and recovery after unknown outcomes.
This uses the same mutation owner as the Zig client and ten language SDKs.

## Explicit durable queries

`transit query query.json` runs the finite KV/Table/Document SQL shell. Its
[guide](docs/unified-query.md) defines the source declaration, bounded upload,
namespace selection, exact retry and owned nested results. The configuration
contains `url`, `seed_file`, `connection`, `workspace`, and optional
`request_timeout_ms` (default 5000; 1–60000). Provision the source/requester
[query hosts](../transit-query-host/README.md) and their grants first.

SQL compiles against the configured source and budgets before admission.
`.new ID` selects a fresh namespace; `.resume ID` observes retained work without
rerunning it. `.bundle` and `.pending` export exact recovery material;
`.restore-bundle`, `.restore` and `.retry` recover it. `.advance` continues only
a committed upload, `.status` observes completion and `.next` verifies one page.
Cancellation, retirement and collection are explicit commands. Disconnecting
does not cancel accepted durable work.

The default console instead uses fresh interactive snapshot sessions. See
[console behavior](docs/console.md) for session lifetime and cancellation, and
[local applications](docs/applications.md) for installation and replacement.

Script and piped-input failures identify their source, one-based statement number,
zero-based statement-start byte offset and one-based line/byte column. SQL carets
use absolute input lines and columns, including skipped comments and UTF-8 bytes.
The diagnostic reports how many prior commands completed; SQL and dot commands
each count once, while blank lines/comments do not. Earlier effects remain
committed. SQL embedded in `.execute` input retains its own local coordinates;
the enclosing script command is reported separately. Paths are bounded and
escaped before terminal rendering. These diagnostics go to stderr.
