# transit-cli

`transit server` starts and supervises a local Transit installation.
`transit console` opens interactive or batch SQL sessions for queries, Table
DDL/DML and catalog operations through the shared SQL service.

The `transit` executable contains the node, query host, SQL gateway and Board,
including its frontend assets. The local server starts these roles as separate
processes from the same executable. Board runs by default, with `--no-ui` for
headless operation. See the
[server guide](docs/server.md#default-board-and-compatibility) for grants and compatibility.

The `transit-admin` administration utility remains separate.

The [server/console contract](../../contracts/TRANSIT_CLI_V1.md) defines commands,
configuration and recovery. Shared parser and
cursor assistance lives in Fuze/query packages. The [console guide](docs/console.md)
covers versioned configuration, terminal editing, trust and statement outcomes.
The [local server guide](docs/server.md) describes the implemented supervisor,
private native gateway and selected dependency/credential profile. Focused recovery,
gateway pressure, physical capacity and clean-checkout qualification are recorded in the [proof ledger](../../docs/history/qualification/README.md). The console uses dot commands.
The local gateway supports [localhost and explicit tunnel aliases](docs/server.md#local-names-and-ssh-tunnels)
and reports its URL and accepted authorities in the ready record.

The [public CLI reference](../../docs/handbook/reference/cli.md#output-philosophy-explain-locate-guide)
defines concise errors, useful coordinates, recovery guidance, streams and exit
statuses. Use `transit server --help` and `transit console --help` for supported
options and configuration guidance. `just test::cli-diagnostics` checks the real executable's
invocation and configuration failures without starting an installation.
`transit console --format json` selects JSON SQL results on stdout. Errors and
timing are human-readable on stderr. Server logging uses its configuration settings.

Bare `transit console` discovers a local peer-authenticated SQL session without
reading private installation files. Multiple consoles share the service and have
independent settings and cursors. Explicit connection YAML also supports remote
HTTP/TLS sessions. Server and explicit connection
configuration use YAML by default; `.transitrc` remains a DuckDB-style startup
file containing dot commands.

Interactive `.edit` opens the latest SQL, including failed SQL, in `$EDITOR`.
Save and close to submit it, even without text changes; close without saving
to cancel. See [external editing](docs/console.md#external-editor).

The console runs `-c 'SELECT COUNT(*) FROM items'`, `-f queries.sql` or interactive
SQL with automatic query progress and verified results. The local connection
also executes INSERT/UPDATE/DELETE against `items` without extra configuration.
CREATE/ALTER/DROP and typed DML share the configured general catalog; new
Tables are discoverable and queryable through that catalog. Connections select
an enrolled account and database, or an authorized service-owned source binding;
`.help INSERT` and `.help CREATE TABLE` explain syntax, configuration and
statement behavior inside the shell. `.help` lists commands, `.help --all`
expands their instructions, and `.help shortcuts` lists terminal keys.
Its `.transitrc` hierarchy
configures `.connect`, `.mode` and `.timer`; server `transit.yaml` settings overlay the
installed bundle's defaults. See the linked component guides for precedence,
limits and recovery.

Terminal interaction decisions belong to [EditorState.zig](EditorState.zig):
draft/history snapshots, completion acceptance and exclusive client ownership
transition without I/O. [Terminal.zig](Terminal.zig) decodes keys, performs the
requested effects and renders the result. `just test::console-history` exercises
that adapter through real terminals; native unit tests check the state owner.
`just test::console-model` checks a bounded TLA+ model and replays every exported
edge against the same Zig reducer. See the
[interaction mechanism](../../docs/handbook/internals/service-interfaces.md#console-interaction-transitions)
for ownership, proof scope and remaining integration assumptions.

The [local PostgreSQL/MySQL guide](docs/sql.md) covers opt-in listeners, explicit
account enrollment, verified TLS, grants and retained-operation recovery.

Script and piped-input failures identify their source, one-based statement number,
zero-based statement-start byte offset and one-based line/byte column. SQL carets
use absolute input lines and columns, including skipped comments and UTF-8 bytes.
The diagnostic reports how many prior commands completed; SQL and dot commands
each count once, while blank lines/comments do not. Earlier effects remain
committed. SQL embedded in `.execute` input retains its own local coordinates;
the enclosing script command is reported separately. Paths are bounded and
escaped before terminal rendering. These diagnostics go to stderr.
