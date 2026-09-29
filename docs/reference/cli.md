# Transit CLI reference

`transit` starts a local server, manages installed applications and opens signed
query sessions. It is separate from the retained `rey-cli` administration utility
and `kubectl-transit` runtime tooling. Build it with `zig build transit` in the
pinned development shell, or use the [Nix local bundle](../guides/quickstart.md).

## Commands

```text
transit --help
transit --version
transit serve [--config FILE] [--initialize] [--no-ui]
transit server [--config FILE] [--initialize] [--no-ui]
transit console [--config FILE] [--format table|json] [-c SQL | -f FILE] [--init FILE | --no-rc]
transit query FILE
transit query-v2 FILE
transit app install --config FILE --file DECLARATION --operation ID
transit app replace --config FILE --file REPLACEMENT --operation ID
transit app retry --config FILE --operation ID
transit app status --config FILE --application NAME [--after INDEX]
transit app connect --config FILE --application NAME --caller NAME [--output FILE]
```

| Command | Input and outcome |
| --- | --- |
| `serve`, `server` | Aliases. Run the local supervisor in the foreground; `--initialize` creates a new installation. Version 3 starts Board by default; `--no-ui` runs headlessly |
| `console` | Interactive and batch finite SQL, automatic query identity/progress/results, terminal assistance and saved recovery |
| `query` | Compatibility: original single-line Table v1 shell and positional configuration |
| `query-v2` | Compatibility: single-line KV/Table/Document shell with positional configuration and explicit recovery exports |
| `app install` | Freeze/sign a declaration under an operation ID; accepted management intent is separate from installed/ready/domain state |
| `app replace` | Conditional role replacement using `expected_revision`; stable durable IDs and current permissions remain |
| `app retry` | Retry the original frozen management request after uncertainty |
| `app status` | Read sampled deployment state and bounded receipt pages; pass the prior `next` as `--after` |
| `app connect` | Export a named caller connection, with a seed-file reference rather than an installer/root key |

The installed server starts from defaults and overlays the first existing
`./transit.yaml`, `~/transit.yaml` or `/etc/transit/transit.yaml`; `--config`
selects exactly one file instead. `TRANSIT_` variables override typed properties,
using `__` for nesting. No matching file means defaults; a bad selected file
fails without fallback. Initialization remains explicit.

The console derives its connection from the local server topology and retained
installation; no generated console configuration file is needed. Defaults use
`./.transit` and `http://127.0.0.1:19105`.
It merges `/etc/transit/transitrc`, `~/.transitrc` and `./.transitrc`.
Only `.connect PATH`, `.mode table|json` and `.timing on|off` settings are allowed there.
`--init FILE` replaces that hierarchy; `--no-rc` skips it.
`TRANSIT_CONSOLE_CONFIG` overrides the rc connection and `--config` overrides
that variable. `--format` overrides rc presentation settings. Connection files
use YAML by default, with explicit JSON compatibility; credentials and identities
are never merged between them. The rc files remain DuckDB-style dot-command scripts.

## Output philosophy: explain, locate, guide

Errors name the problem once. A location or next step appears when it helps
resolve that problem. Routine option errors usually take one line; missing
required input can add the minimum invocation. Full option lists belong in help.

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

### Help hierarchy

Bare `transit` and `transit --help` list commands with short descriptions.
`transit app --help` lists application operations. Command help, including
`transit app install --help` and each other application operation, shows its
supported options, defaults and configuration guide. `server` is the canonical
name in server help; `serve` is listed as an alias.

Help requires no configuration file, credentials, network or running server.
It skips required-option checks but still rejects malformed supplied arguments,
unknown options and duplicates. Help and version output exit successfully on
stdout. The query shells accept their existing standalone `--help` invocation.
Configuration links in help name repository guides; installed bundles need not
contain those relative paths. The CLI has no `--verbose` option.

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

Invocation diagnostics cover `server`/`serve`, `console`, `app` subcommands and
both query shells. File decoding coordinates cover server, console and application
management configuration. Server/console startup adds validated field coordinates,
listener failures and recovery advice. Other failures retain the useful command or
file context and an explanation or untranslated error identifier; the CLI does
not claim a more specific cause than it can establish. Query-shell configuration and in-session result formats
retain their separate contracts.

### Next steps preserve evidence

Advice names the option, supported value, file, field or inspection step that
can resolve the failure. Missing configuration points to `--config` and a minimal
invocation; a bad format lists `table` and `json`; a port conflict identifies the
listener.
Unknown failures retain their identifiers; include the diagnostic and executable
version when reporting them. Diagnostic wording and underlying error names are
human interfaces, not a stable machine schema.

Recovery advice respects durable identity. An uncertain operation calls for
inspection or retry of its saved signed intent. It does not imply rejection,
suggest fresh SQL as a retry, or recommend deleting history. A server identity
mismatch asks for the recorded configuration and matching executables. The
`--initialize` option is only for deliberately creating an installation; ordinary
restarts omit it.

### Streams, privacy and limits

Top-level failures write diagnostics to stderr and leave stdout available for
machine records. Help/version write to stdout and exit 0. Invocation and
server/console/management configuration errors exit 2; runtime failures exit 1;
an interrupted batch query exits 130 after resolved cancellation. Ctrl-C during
interactive SQL returns to the prompt. Console results use stdout; console errors,
including query failures, use stderr. Prompts and human diagnostic prose stay off machine stdout.

Diagnostics show coordinates without dumping command arguments, configuration
bodies, credentials, SQL or result payloads. Displayed file paths are limited to
256 input bytes, with an explicit `...` suffix when truncated. Quotes,
backslashes, control bytes and non-ASCII bytes are escaped, including invalid
UTF-8, so paths cannot control the terminal. Output is plain text and needs no
color, terminal width or interactive prompt to be understood. A file path is a
reference, not permission to disclose its contents.

## Console commands

The interactive console submits a statement on Enter after its semicolon.
`-c` accepts one statement without a final semicolon; `-f` and stdin stream a
script and accept a complete final statement at EOF. Batch execution stops on
the first error. Dot commands start an empty draft and end at newline; slash
commands are unsupported. Completion never submits.

| Command | Meaning |
| --- | --- |
| `.help` | Show available commands |
| `.sources`, `.tables`, `.schema` | Inspect the authorized source and schema |
| `.mode table\|json` | Select result presentation |
| `.timing on\|off` | Report query phase wall times to stderr; off by default |
| `.connect PATH` | Switch connection in a terminal, after resolving outstanding work |
| `.show` | Effective settings and their origins as aligned text, including in JSON result mode |
| `.status`, `.info` | Saved query status or evidence |
| `.resume [ID]` | Recover the saved or selected existing query and print results |
| `.cancel` | Request durable cancellation of the saved query |
| `.quit`, EOF | Disconnect; accepted work persists |

SQL automatically chooses a fresh identity, records exact intent, advances its
upload and prints verified results. `.new`, `.retry`, `.advance`, `.next` and
manual recovery exports are not console commands. `query` and `query-v2` remain
callable compatibility shells with their own explicit protocols and dot commands;
root help advertises `console` as the query interface.

## Configuration, output and recovery

Use [server configuration](../../apps/transit-cli/docs/server.md),
[application installation](../../apps/transit-cli/docs/applications.md),
[console configuration](../../apps/transit-cli/docs/console.md) and
[v2 source configuration](../../apps/transit-cli/docs/unified-query.md) for exact
fields, paths and bounds. Configuration alone never creates a grant.

Console JSON output keeps prompts and diagnostics off stdout. Full-width
integers remain decimal strings; binary stays hex and cell-state distinctions
are explicit. Each result page is bounded; the console does not accumulate
all rows. Previously displayed output cannot be recalled after revocation.

For `console`, normal disconnect/help exits 0, invalid invocation/configuration
exits 2, and runtime or any piped-command failure exits 1. Ctrl-C during SQL or
`.resume` requests cancellation using the original query identity and returns to
the interactive prompt after bounded settlement and cleanup. Repeated Ctrl-C is
coalesced. Batch input exits 130 on a resolved outcome, or 1 if cancellation fails.
Completed execution is reported separately from interrupted result display;
unconfirmed cancellation retains saved intent for `.status` and `.cancel`.
Ordinary disconnect, SIGTERM and metadata interruption do not submit cancellation;
metadata or idle batch interruption exits 130. The [console guide](../../apps/transit-cli/docs/console.md#input-commands-and-results)
defines completion races, cleanup bounds and recovery. Automatic queries require a configured recovery file, explicitly retaining private
query text and exact intent. Server-generated connections supply this setting.
Use `.resume` after a disconnect with saved work; it reconciles the same operation and prints its
result from the beginning, possibly repeating previously displayed rows. New SQL
refuses to replace unresolved work.
