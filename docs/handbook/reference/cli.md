# Transit CLI reference

`transit server` runs a local installation. `transit console` opens server-managed
SQL sessions for queries, Table DDL/DML and catalog operations.
`transit-admin` and `kubectl-transit` are separate administration and runtime
tools. Commands assume `transit` is on `PATH`.
Use the [local quickstart](../guides/quickstart.md) for prerequisites and startup.

## Commands

```text
transit --help
transit --version
transit server [--config FILE] [--no-ui]
transit console [--config FILE] [--format table|json] [-c SQL | -f FILE] [--init FILE | --no-rc]
```

| Command | Input and outcome |
| --- | --- |
| `server` | Run the local supervisor in the foreground. Missing or empty installation directories are initialized automatically. The local profile starts Board by default; `--no-ui` runs headlessly |
| `console` | Independent local/remote SQL sessions, interactive and batch results, terminal assistance and service-owned operation recovery |

The installed server starts from defaults and overlays the first existing
`./transit.yaml`, `$XDG_CONFIG_HOME/transit.yaml` (default `~/.config/transit.yaml`) or `/etc/transit/transit.yaml`; `--config`
selects exactly one file instead. `TRANSIT_CONFIG` selects an explicit file when
`--config` is absent. `TRANSIT_` variables override typed properties,
using `__` for nesting. No matching file means defaults; a bad selected file
fails without fallback. Configuration files are bounded to 64 KiB, 96 nested
containers and 65,536 syntax nodes; logical schemas retain their own depth,
node and name budgets. Server startup initializes missing or empty state unless
`startup.require_existing: true` is configured.

The console resolves the installation path (default `./.transit`) to a nonsecret
runtime rendezvous and opens the SQL service's private Unix socket. It does not
read `installation.json`, signing seeds or a client recovery file. Remote consoles
use an explicit [SQL session connection](../../../apps/transit-cli/docs/console.md#configuration-and-trust).
It merges `/etc/transit/transitrc`, `~/.transitrc` and `./.transitrc`.
Only `.connect PATH`, `.mode table|json` and `.timer on|off` settings are allowed there.
`--init FILE` replaces that hierarchy; `--no-rc` skips it.
`TRANSIT_CONSOLE_CONFIG` overrides the rc connection and `--config` overrides
that variable. `--format` overrides rc presentation settings. Connection files
use YAML by default, with explicit JSON compatibility; credentials and identities
are never merged between them. The rc files remain DuckDB-style dot-command scripts.

## Output philosophy: explain, locate, guide

Errors name the problem once. A location or next step appears when it helps
resolve that problem. Routine option errors usually take one line; missing
required input can add the minimum invocation. Full option lists belong in help.

Console guidance stays in the console: errors point to `.help`, statement help
such as `.help CREATE TABLE`, or inspection commands such as `.schema`, `.sources`
and `.show`. Console output does not refer users to documentation pages or
repository paths.

A correction that fits in the error needs no additional guidance:

```text
error: --format must be table or json
```

File and field coordinates appear beside the problem, for example:

```text
error: invalid JSON in "server.json":12:5
error: "server.json": ports.gateway and ports.node must be different
```

These are separate example failures. Parser coordinates identify the detection
point, not necessarily the start of an offending value. Known filesystem reasons
use plain language, such as "file not found" or "permission denied". Unmapped
failures retain their error identifier for investigation without requiring a
repeat attempt. Restart-budget exhaustion remains distinct from the underlying
role failure. Routine errors omit redundant implementation codes and labeled
`at`, `cause`, `next` and `help` fields.

`PATH` denotes a file path. A diagnostic never initializes an installation
or submits an operation.

### Result formatting and errors

`transit console --format table|json` selects SQL results on stdout. Errors and
timing remain human-readable on stderr, including invocation and configuration
failures before a session opens. Server operational logs use `logging.format`
and `logging.level` in server configuration.

### Help hierarchy

Bare `transit` and `transit --help` list `server` and `console`.
`transit server --help` and `transit console --help` show their options and defaults.
Help requires no configuration, credentials, network or running server. It
still rejects malformed supplied arguments, unknown options and duplicates.
Help and version output exit successfully on stdout. Console `.help` provides
statement and session assistance. The CLI has no verbosity or diagnostics switch.

### Coordinates that lead to the problem

| Failure | Coordinate and interpretation |
| --- | --- |
| Missing, repeated, unsupported or invalid known option | The recognized option name and its requirement. Supplied argument values are omitted. |
| Unknown or misplaced argument | Its argument position and the relevant command help. Position 1 is the first argument after the executable; arbitrary argument text is omitted. |
| Configuration file cannot be opened | The selected file path and known filesystem reason, or an untranslated error identifier |
| Configuration JSON cannot be decoded | File and one-based `line:column` at the parser's detection point; columns count bytes. This can be the end of an object for a missing field, not the start of the offending value. Missing required struct fields also name the schema path when available. |
| Invalid server or console setting | Configuration file and named field; conflicting ports name both fields. Semantic checks do not invent line numbers. |
| Configured executable cannot be located or validated | Configuration file and `executables` field |
| Listener cannot be bound | Configuration file, port field and exact loopback address/port |
| Server role cannot reach readiness | Installation path, role and underlying failure; check that role's configured executable, port and storage permissions before restarting |

Invocation diagnostics cover `server` and `console`. File decoding coordinates
cover their configuration and SQL inputs. Startup adds validated field
coordinates, listener failures and recovery advice. Other failures retain useful
command or file context and an explanation or error identifier.

### Next steps preserve evidence

Advice names the option, supported value, file, field or inspection step that
can resolve the failure. Missing configuration points to `--config` and a minimal
invocation; a bad format lists `table` and `json`; a port conflict identifies the
listener.
Unknown failures retain their identifiers; include the diagnostic and executable
version when reporting them. Diagnostic wording and underlying error names are
human interfaces, not a stable machine schema.

Recovery advice respects durable identity. The shared client checks an uncertain statement through its original identity;
unresolved outcomes remain explicit. It does not imply rejection,
suggest fresh SQL as a retry, or recommend deleting history. A server identity
mismatch asks for the recorded configuration and matching executables. Use the same server command
for first startup and restarts. Set
`startup.require_existing: true` to refuse a missing or empty installation.

### Streams, privacy and limits

Top-level failures write diagnostics to stderr and leave stdout available for
machine records. Help/version write to stdout and exit 0. Invocation and
server/console configuration errors exit 2; runtime failures exit 1;
an interrupted batch query exits 130 after resolved cancellation. Ctrl-C during
interactive SQL returns to the prompt. Console results use stdout; console errors,
including query failures, use stderr. Prompts and human diagnostic prose stay off machine stdout.

Diagnostics show coordinates without dumping command arguments, configuration
bodies, credentials, SQL or result payloads. Displayed file paths are limited to
256 input bytes, with an explicit `...` suffix when truncated. Quotes,
backslashes, control bytes and non-ASCII bytes are escaped, including invalid
UTF-8, so paths cannot control the terminal. Console diagnostics add color when
stderr is a terminal, unless `NO_COLOR` is nonempty or `TERM=dumb`. Redirected
diagnostics remain plain text. Output needs no color, terminal width or
interactive prompt to be understood. A file path is a
reference, not permission to disclose its contents.

## Console commands

The interactive console submits a statement on Enter after its semicolon.
Before that semicolon, Enter continues on a new display row aligned with the
SQL after `transit> `. Multiline drafts, including pasted and recalled SQL,
retain their line breaks; long lines wrap within the terminal width.
`-c` accepts one statement without a final semicolon; `-f` and stdin stream a
script and accept a complete final statement at EOF. Batch execution stops on
the first error. Dot commands start an empty draft and end at newline; slash
commands are unsupported. Completion never submits.

| Command | Purpose |
| --- | --- |
| `.connect FILE` | Open a new independent connection in a terminal |
| `.edit` | Edit the latest SQL in `$EDITOR`; save and close to submit |
| `.execute FILE` | Execute a typed JSON query object |
| `.help [--all] [TOPIC]` | List commands or show focused help |
| `.info` | Current account/database and authorized source bindings |
| `.mode table\|json` | Select SQL result presentation |
| `.quit`, EOF | Close this session |
| `.schema [TABLE]` | Show table columns, or list available tables |
| `.show` | Presentation preferences and their origins |
| `.sources` | Alias for `.info` |
| `.tables` | List available tables |
| `.timer on\|off` | Enable or disable query timing |

`.help` prints an alphabetical command index with one description per line.
`.help --all` expands those same entries with arguments, notes and examples.
`.help edit` and `.help .EDIT` show the same focused command help. Topics are
case-insensitive; `.help sql`, `.help settings` and `.help shortcuts` cover SQL,
configuration and terminal keys. Statement topics such as `.help INSERT` and
`.help ALTER TABLE` describe only the selected statement. Help always prints
text, including in JSON result mode, and submits no SQL.

In the interactive editor, Tab requests grammar/catalog completion and accepts
selected suggestions or history matches. The menu keeps its selection while
idle. Typing within the same token filters it immediately, with fresh suggestions
arriving in the background. Opening starts immediately; acquisition and validation
show no loading placeholders. Catalog suggestions recheck metadata and
authorization before insertion. Acceptance never executes
a statement.
Esc clears the whole unsubmitted draft; Ctrl-G dismisses suggestions or restores
the original draft from Ctrl-R search. Ctrl-Z undoes ordinary edits, paste,
completion and clearing. Up/Down moves between multiline rows before browsing
history; Ctrl-P/Ctrl-N always browses history. The
[terminal key map and limits](../../../apps/transit-cli/docs/console.md#terminal-editing-and-history)
cover search matching, bounded undo, metadata refresh and terminal key delivery.

SELECT uses a fresh leased snapshot in the shared SQL service. Table writes and
configuration reloads remain owned by the service. The console waits for their
outcome and exposes no operation-management commands. The
[console guide](../../../apps/transit-cli/docs/console.md#input-commands-and-results)
defines result presentation and source selection.

`.edit` is interactive-only, skips dot commands in history and opens a blank
file when no SQL is available. Configure `$EDITOR`, including a wait argument
for editors such as `code --wait`. Saving and closing submits once even when
the SQL is unchanged; closing without a save does nothing. In Vim, `:wq`
submits and `:q` without a save does not. An editor failure or empty saved file
submits nothing. The [external editor guide](../../../apps/transit-cli/docs/console.md#external-editor)
defines temporary files, argument parsing and the statement limit. This is a
fresh SQL submission under current rights, including after an uncertain outcome.

## Configuration, output and recovery

Use [server configuration](../../../apps/transit-cli/docs/server.md),
[console configuration](../../../apps/transit-cli/docs/console.md) for exact
fields, paths and bounds. Configuration alone never creates a grant.

Console JSON output keeps prompts and diagnostics off stdout. Full-width
integers remain decimal strings; binary stays hex and cell-state distinctions
are explicit. Each result page is bounded; the console does not accumulate
all rows. Previously displayed output cannot be recalled after revocation.

For `console`, normal disconnect/help exits 0, invalid invocation/configuration
exits 2, and runtime or piped-command failure exits 1. Batch interruption exits
130 and stops subsequent input. Ctrl-C clears a draft or requests interruption
of the current statement. Cancellation cannot undo a completed write; a lost
response can leave its outcome unconfirmed. Session expiry releases temporary
cursors without expiring accepted history.

The console reports statement completion and authoritative matched/changed
counts. Accepted statements emit a JSON `completion` object with `outcome`,
`matched`, `changed` and `pending_restart`; direct session completions retain
`kind`, `matched` and `changed`. No operation token or workflow phase is printed.
Rejected, cancelled, partial and unconfirmed outcomes are errors, not successful
completion records. The current accepted-operation response has no SQL command
tag, so its human output uses “Statement completed” rather than guessing a
statement kind from SQL text.

After a lost write response, the shared client checks the original request
within a bounded deadline. It never submits the SQL again. If the original
session expired, a separate authenticated observation session can check that
request against the same instance and account. This does not restore the user's
session or its settings; further SQL requires reconnection. A timeout, missing
observation or failed authorization cannot establish that a write failed.
Unconfirmed outcomes explicitly warn that running the statement again may apply
changes twice.

An interactive result cannot resume after loss of its logical session. The
[SQL session reference](sql-sessions.md) and
[console guide](../../../apps/transit-cli/docs/console.md#session-lifetime-and-bounds)
define these lifetimes and bounds.
