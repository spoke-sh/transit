# Transit CLI v1

This contract defines CLI commands, local server lifecycle and console recovery.
The [CLI guide](../apps/transit-cli/README.md) lists commands and usage.
The local server runs on Linux x86_64.

## Command and compatibility boundary

`transit server [--config PATH] [--no-ui]` runs one local installation in the
foreground. `transit console [--config PATH] [--format table|json]` opens an
explicit-submit terminal session; `-c SQL`, `-f FILE` and stdin run batch input.
`transit migrate <plan|inspect|apply|status|resume|verify> [OPTIONS]` plans,
applies, resumes and verifies ordered application schema and data migrations
over the SQL session without reading `.transitrc` startup files.
These are the only public commands. `--help` and `--version` need no configuration,
credentials, running installation or network. Unknown commands/options, repeated
options, positional leftovers and incompatible versions fail before effects.
Version output is `Transit <semver> (git <revision>; CLI contract 1)` followed
by a newline. The revision is the full build-source commit, with `-dirty` for
modified source, or `unknown` when provenance is unavailable. It identifies the
artifact, not remote capabilities or protocol compatibility. See the
[versioning policy](../docs/handbook/reference/versioning.md#software-releases).

Server configuration overlays built-in defaults with one selected file, then
typed environment values. With no explicit `--config`, the first existing
`./transit.yaml`, `$XDG_CONFIG_HOME/transit.yaml` (default `~/.config/transit.yaml`)
or `/etc/transit/transit.yaml` is selected. `TRANSIT_CONFIG` selects an explicit
file when `--config` is absent; an explicit missing file rejects.
Missing all files leaves defaults intact; an unreadable or invalid selected file
fails without fallback. Objects merge recursively; lists and scalars replace.
`TRANSIT_` uses uppercase schema names and `__` for nested paths; a single `_`
is literal. More specific variables win over whole-object JSON. Unknown settings
and invalid values reject. `TRANSIT_CONSOLE_CONFIG` is reserved for the console.
The [server guide](../apps/transit-cli/docs/server.md#defaults-and-configuration)
defines the default profile, data-only YAML subset, JSON and parsing bounds.

The console discovers a server-owned SQL session endpoint. Server configuration
and environment precedence select the installation path; its digest selects a
nonsecret rendezvous under `$XDG_RUNTIME_DIR/transit`, or the owner-checked
`/tmp/transit-<uid>` fallback. The Linux Unix socket authenticates the peer UID.
The console reads no installation record or signing seed and holds no credential
or recovery lock. Separate consoles have independent sessions. It never
initializes or repairs server state. Explicit connection YAML selects an HTTP/TLS
endpoint, account, database and optional source, with peer, loopback trust or
SCRAM authentication. Remote access needs no server files or database-wire port.
The [SQL session contract](SQL_SESSION_V1.md) owns authentication, bounded
carriage, handles, admission tokens, current authorization and recovery.
Console rc settings merge system `/etc/transit/transitrc`, home `~/.transitrc`
and project `./.transitrc`, in that order. Only `.connect PATH`, `.mode` and `.timer`
settings are allowed; no startup SQL or durable operations execute. Missing
files skip; other failures stop. `--init FILE` replaces discovery and `--no-rc`
disables it. They are mutually exclusive. Rc connection paths resolve against
the defining rc file; later paths replace the whole connection reference.
`TRANSIT_CONSOLE_CONFIG` overrides rc selection and explicit `--config` wins.
`--format` overrides rc mode, then the connection's format, then table mode.

Connection files use versioned YAML by default, at most 64 KiB. Explicit `.json`
files remain supported. Machine responses, bootstrap and recovery records retain
neutral JSON formats. `.transitrc` contains dot-command startup settings.
Paths within them resolve against their file. Credentials, native IDs and trust
settings never merge across connections. Private keys are referenced by files,
never command arguments. Diagnostics name fields or roles without printing
configuration values, request bodies or credentials.
The [public CLI reference](../docs/handbook/reference/cli.md#output-philosophy-explain-locate-guide)
owns the human-output conventions: one specific explanation, with a location
or next step when useful. Known option errors name the option; unknown arguments
use positions without echoing their values. Configuration decoding reports the
file and parser location; semantic validation names fields. Known reasons use
plain language, while untranslated failures retain their identifiers. Exhausted
restarts remain distinct from the underlying role failure. Root help lists `server` and `console`; each command has offline `--help`. Supplied arguments remain strictly validated during help. Human wording and implementation error names
are not a versioned machine schema. Recovery advice preserves saved identity and
never treats uncertainty as proof of rejection.

`transit migrate` maps outcomes to deterministic exit statuses: `0` for
`planned`, `inspected`, `applied`, `already_satisfied` and `verified`; `1` for
step execution failure; `2` for invalid invocation, configuration or target
identity mismatch; `3` for schema drift, checksum mismatch or concurrent runner
claim conflict; `4` for uncertain/pending step outcome; and `5` for
post-migration verification failure. See [Application schema and data migration v1](MIGRATION_V1.md).

Successful help, version, ordinary disconnect and joined server shutdown return
0; invalid invocation/configuration returns 2; runtime failure returns 1. A
console interrupted during SQL stops its current request and returns to an empty
terminal prompt. Interactive reads use independently admitted cancellation and
release the service-owned snapshot. Accepted Table, configuration and captured
operations remain recoverable; interrupting presentation does not undo them.
Ctrl-C requests cancellation of the current statement where supported and checks
its original outcome within a one-second cleanup budget. Cancellation cannot
undo completion. Batch interruption returns 130; unconfirmed outcomes remain
explicit errors without exposing operation identities. Server SIGINT/SIGTERM initiate joined
shutdown. Machine records go to stdout and diagnostics to stderr; JSON mode has
no banner or prompt. Broken stdout ends presentation without deleting accepted
work.

`transit-admin`, `kubectl-transit` and launcher tools retain their own configuration
and protocols. They are separate executables, not `transit` commands.

## Explicit SQL bindings

`transit console -c SQL --parameters FILE` supplies an ordered JSON array of
exact typed scalars. The flag requires `-c`. `.execute FILE` reads the shared
`{sql, parameters?}` request shape. Omitted/null parameters select ordinary SQL;
an explicit array supplies bindings. The service describes the prepared types,
and the client encodes descriptor-bound logical values without SQL substitution.
Native catalog/source profiles enforce their own parameter and statement limits.
Files resolve against the working directory and are bounded to 131072 bytes;
the input reader admits at most 65 scalars and 4096 SQL bytes. Unknown/duplicate
fields and malformed scalar representations reject. Source templates retain the
[parameter contract](SQL_PARAMETERS_V1.md), including their smaller admitted
placeholder profile; catalog parameters use the shared Table compiler.

After admission, changing or deleting an input file cannot change the original
work. The console never recompiles or resubmits SQL automatically. Bindings are
not session defaults and parameter values are not added to dot-command history.

## Local server and recovery

The initial service neighborhood is a growing authority over disk-backed Ursula,
bounded maintenance, a delivery courier, a separately activated combined Table
query/writer owner and requester, and a public native-protocol gateway. The initial
source is an empty declared int64 Table; a functioning installation need not
contain example data.
Its initial mutation policy explicitly permits INSERT/UPDATE/DELETE for the local
caller. The manager submits the configuration-bound initializer, retains its
exact admission receipt, and waits for the courier-delivered second initialization
turn and exact ready configuration before exposing the gateway. Query inspection
remains a separate readiness gate. Restart preserves current mutation policy;
revocation never triggers reinitialization or renewed permissions. Query-only
local installations belong to an incompatible shared definition and reject
without conversion or reset.
Version-1 server configuration enables Board by default with its own retained
inspection-only key and explicit resource grants. `--no-ui` disables its process
and listener for one invocation without changing configuration or history.
Unsupported configuration versions reject; pinned artifact identities forbid
implicit upgrades. Effect connectors remain unsupported optional
roles. Board readiness, configuration and compatibility belong to the
[server guide](../apps/transit-cli/docs/server.md#default-board-and-compatibility).

The configuration names its installation directory. Missing or null role
executable settings select the node, query host, SQL gateway and Board compiled
into `transit`; Board's frontend assets are embedded. The supervisor starts each
role in a separate process using private dispatch arguments, outside the public
command interface. Explicit paths select matching standalone role executables.
There is no adjacent-binary or PATH discovery. Each retained role artifact hash
binds the shared definition, role name, embedded/external invocation mode and
executable bytes. A changed mode or artifact rejects before activation.
The persistent installation records a random installation identity, format and
artifact identities, realm/root public key, storage locations, role identities,
credential references and accepted provisioning receipts. Dependency checking
happens before provisioning. Published release bundles are not available; a shell,
Python, `just`, Process Compose and a source checkout are not runtime dependencies
of the server. The default local profile uses the node's exclusive local WAL and
immutable object owner; it does not start Ursula or MinIO. Explicit Ursula
deployments use the pinned upstream provider and its S3 cold storage configuration.
Role limits and exact artifact
versions belong in the [server guide](../apps/transit-cli/docs/server.md).

Startup initializes a missing or genuinely empty installation directory by
publishing a complete private installation record before starting services.
`startup.require_existing: true` refuses both cases before creation; its default
is false. A populated directory always requires its recorded installation and
storage. Files, symbolic links, unrecognized contents, missing or malformed
records and incompatible definitions fail without replacement or reset.
The sibling OS lock serializes inspection, creation and recovery. Creation
assembles private files in a sibling directory, synchronizes them, removes only
an empty destination directory and publishes with a nonreplacing rename followed
by parent-directory sync. New contents appearing before publication cause a
refusal. Unpublished staging directories contain no accepted work and are never
adopted. Use a directory within a mounted volume rather than its mount point.
There is no destructive reset, storage replacement, generation rollback or
deletion of a stale activation marker.
An interrupted initial creation resumes through its persisted bootstrap intent
and exact receipts. First initialization must be distinguished from a completed
installation whose storage has disappeared. A recorded monotonic authority
position detects rollback below that observation; it is not a disaster-recovery
or global latest-history oracle.

One OS lock spans management of the installation. Startup refuses another
manager or conflicting listener before starting dependent roles. OS children
and durable Transit PIDs remain distinct. Dependency-ordered startup waits for
actual role readiness within finite deadlines. Roles have bounded logs and
restart budgets/backoff. Loss of required storage or authority withdraws gateway
readiness and stops dependent workers before recovering the same durable history.
Exhausted recovery fails the installation visibly and reaps its owned children.

With local SQL enabled, the human `server.ready` announcement additionally
requires the initialized, currently bound local account and published console
rendezvous. `server.core_ready` can announce core availability earlier. The JSON
core ready record and SQL status remain separate observations; a SQL failure does
not remove the core administration path or authorize renewed grants.

Every growing worker replacement acquires a fresh exact generation. The local
catalog/query workers rotate their keys. SQL account workers retain their
enrolled identities and require current grants; replacement never regrants them.
Persist the intended public registration, grant changes and expected ownership
before submission. Flush any pending signed operation byte-for-byte before
preparing another. Record its receipt before deriving dependent identities.
Reissue foreign resource grants separately from associations. After manager loss,
identify and reap surviving owned children before activation; never attach to
an unrelated PID based only on its number. A child starting or returning a health
response grants no native authority. Provider snapshot reuse is outside v1.

The Linux implementation prevents surviving service activations with kernel
parent-death SIGKILL and a post-arming parent check before exec. Each child has
its own process group. After manager loss, a new manager still requires the
installation lock and free listeners; it never attaches to an old OS process.
This selected local-placement mechanism does not imply a portable runtime adapter.

Normal stop preserves history and joins all children. Log backpressure cannot
stall ownership or shutdown. Publish each role's maximum request size, resident
buffers, active work, logs, timeout and restart budget alongside the implementation.
Unlimited history is not an unlimited resident queue. Quota pressure does not
authorize deleting accepted work or expiring a process.

## Gateway and credentials

The initial gateway binds loopback. It forwards the supported public native
protocol routes with bounded bodies, replies, concurrency and deadlines. It
preserves the caller's signed bytes and response status; it does not hold a root
or shared query signing key. An upstream native denial remains a denial.
Health/readiness is distinct from query completion. Unknown routes and forwarded
identity headers do not supply alternate authority. Separate control capacity
must remain available when data requests stall.

The local gateway accepts the exact `127.0.0.1:<port>` and `localhost:<port>`
authorities by default. Server configuration may add up to eight explicit
`gateway_allowed_hosts` authorities, each bounded to 200 bytes with a required
port. Hostnames compare case insensitively; ports compare exactly. Unknown names,
wildcards and malformed or duplicate Host headers reject. Matching never resolves
DNS and never treats arbitrary loopback-resolving names as trusted. This policy
does not change the listener's bind address, Origin/identity-header checks or
native authorization. It is covered by the installation's configuration identity.
Operational server events use the shared telemetry-v1 envelope with
`logging.format` (`text` by default or `json`) and `logging.level` (`info` by
default). These settings require restart and follow the conventional
`TRANSIT_LOGGING__FORMAT` / `TRANSIT_LOGGING__LEVEL` overrides. They configure
operational stderr logs. Command and input errors are human-readable on stderr;
there is no global diagnostics-format option.
TTY stdout does not receive readiness JSON; readable readiness and endpoint
events appear on stderr. Non-TTY stdout retains one JSON readiness record per
successful startup/recovery cycle, even when logging is off. SQL readiness is
reported separately and does not weaken the existing core/Board readiness gates.

The ready JSON record includes `gateway_url` and the effective `allowed_hosts`
alongside the installation path, after the complete neighborhood reaches readiness.

The console signs under its configured identity and uses the gateway as its
native authority endpoint. A remote endpoint requires an explicitly selected
TLS/trust profile; unsupported transport configurations fail before credentials
are used. Board's private shared viewer/query identity is not remote console
authentication. Native services sharing one OS user are a trusted placement,
not a sandbox or the Substrate isolation profile. Root, worker, courier, query
and optional inspection credentials have distinct owners and native grants.

## Terminal and public operations

The selected console executes the existing finite v1 KV/Table/Document query
profile, plus bounded writes through explicit writer/catalog routes. Source
discovery describes the configured source; catalog SHOW TABLES and DESCRIBE use
the separately configured catalog. Complete statements compile through Fuze
before native submission. Reference-only SQL, continuous queries and unsupported
forms fail without partial lowering. Application definitions retain their independent
compiler/publication boundary; accepting a declaration as grammar does not make
it executable at a query endpoint.

Interactive SQL submits on Enter after a semicolon outside literals and nested
comments. `-c SQL` runs one statement with an optional semicolon; `-f FILE` and
stdin stream semicolon-delimited statements and dot command lines. A complete
final statement runs at EOF; an unclosed literal/comment fails. `-c` and `-f`
are mutually exclusive and do not read stdin. Batch execution stops on the first
error. Dot commands start an empty input statement; slash commands are rejected.
TTY editing supports movement, deletion, multiline vertical navigation before
history, direct Ctrl-P/Ctrl-N recall, Ctrl-R search, completion and bounded undo.
Tab opens completion or accepts a displayed suggestion/history match; acceptance
never submits. Esc and Ctrl-G dismiss suggestions or restore the original draft
and cursor from search; they leave ordinary draft text unchanged. Ctrl-C clears
the entire unsubmitted draft in every editing mode.
Ctrl-Z, Ctrl-_ and Ctrl-X Ctrl-U undo draft/query edits, including clearing.
The combined volatile journal retains 128 groups and 256 KiB of snapshot bytes;
submission resets it and access loss erases protected copies. Search folds ASCII
case and whitespace runs and skips duplicate command text, preserving original
bytes for preview and insertion. Entering search copies the entire current draft
into the filter and previews its newest match; an empty draft opens an empty
filter. Repeated Ctrl-R searches older matches. Ctrl-U clears only the filter.
Canceling search discards filter edits: a filter typed from an empty prompt
returns to an empty draft. Accepting a match installs it as draft text, preserved
by Esc and undoable to the saved draft. Incomplete Enter inserts at the cursor.
Draft newlines render as separate rows with continuation text aligned after the
primary prompt. Long lines wrap within the display width, and a bounded viewport
keeps the cursor visible when a draft exceeds the terminal height. Clearing or
submitting a draft removes its entire editable display before further output.
Submitted SQL and dot commands retain the draft's token colors in scrollback.
SQL keywords, aggregate functions and types are cyan; table/column names,
qualifiers and aliases use the default foreground, including quoted identifiers
and contextual words in name positions. Strings, Boolean literals and literal
NULL are green, numbers and parameters magenta, and comments dim. Punctuation
and dot-command arguments are plain. Classification uses production parser roles
with lexical colors for incomplete, malformed and reference-only syntax; it
does not imply validation, binding or execution support. Redacted diagnostic
excerpts retain original token roles through masking and clipping, with masked
bytes plain.
Console diagnostics highlight error labels, identifiers, categories, coordinates,
carets and correction commands on terminal stderr. Nonempty `NO_COLOR` or
`TERM=dumb` disables color; redirected stderr is plain even with
`CLICOLOR_FORCE`. Color does not change text, redaction, caret alignment, result
stdout or timing-footer order.
Search acceptance returns the match to the editor; submitting requires another
Enter. SQL and dot-command submissions append to `$HOME/.transit_history` as
newline-delimited JSON strings with owner-only file permissions. Batch and startup
input are excluded. Bounded disk scans preserve multiline text and do not cap
retained entry count; malformed or incomplete records are skipped. File failures
warn and fall back to eight session commands. History contains editable text,
not execution identity or recovery authority. The
[console guide](../apps/transit-cli/docs/console.md#input-commands-and-results)
defines search keys, local-file handling and limits.

Interactive `.edit` accepts no arguments and loads the latest SQL history entry,
including failed SQL, while skipping dot commands. With no SQL it opens an empty
file. `$EDITOR` selects a program and optional quoted/escaped arguments without
shell expansion, bounded to 4096 bytes and 64 arguments. An unset/empty value
rejects. The editor gets a private temporary `.sql` file and foreground terminal
control; the console keeps the session alive while waiting. An editor that
detaches must be configured to wait for the file to close.

After a successful editor exit, a write or atomic replacement of that file
selects one fresh SQL submission. Saving identical text still selects execution;
closing without a save, an empty file, or editor failure does not. Saves do not
execute while the editor remains open. The saved file must be regular, valid
UTF-8 SQL within the 4096-byte terminal budget; dot commands reject and a trailing
semicolon is optional. The console restores terminal ownership/modes and removes
its temporary directory on completion or handled interruption. Save observation
failure rejects rather than guessing. SQL is recorded before execution and uses
the ordinary session, current authorization and a new admission token; this is
not exact recovery of a prior request.

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

`.show` emits aligned text independently of query output format. `.connect` is
terminal-only and replaces temporary session state. Unknown commands and
arguments reject as a whole. SELECT uses a fresh leased snapshot; connection
files accept no execution-mode selector. Durable captured execution remains a
native service capability. Catalog DDL/DML and configuration reload keep their
service-owned acceptance and recovery semantics.

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

Closing a connection, expiring a session, changing clients or restarting the
service invalidates temporary handles, while accepted operations remain durable.
Reconnection never silently reopens a result snapshot. Current authorization gates
metadata, every fetched batch (including retries), operation status and results.

JSON output starts with `profile: sql_result_v1`, logical schema, observation and
`complete_coverage: false`. Typed row envelopes follow. A verified final record
contains `complete_coverage: true`, `rows`, `displayed_rows` and the same observation.
Counts and other integers of 64 bits or wider use decimal strings. Typed cells
preserve wide integers, float bits, nested values and all five cell states.
Command output has a `completion` envelope with typed kind, outcome, applicable
counts and owner attribution. Unresolved writes carry their original correlation
in an `unresolved` envelope; they are not success or rejection.

Table output uses one header and fixed column widths for the logical result.
Sampling owns at most 32 rows within 256 KiB; cells use escaped previews, with
visible truncation and widths of at most 80 bytes. Remaining rows stream without
accumulating the result. Connection setting `display_rows` is null by default
(unlimited display) or a positive unsigned 32-bit row limit. Reaching that limit
closes the reader without draining it. An incomplete display reports its displayed
count, the limit and any already verified completion separately; it never prints
a successful coverage footer. Exact-limit exhaustion with known completion is
complete. Output failure, interruption and missing terminal evidence leave an
incomplete prefix and a nonzero exit status; an intentional display limit is a
successful local presentation choice with explicitly incomplete coverage.

Submission, settlement and consumption belong to the shared SQL client. Its
operation wait checks a 270-second budget; transport, execution, memory and output
deadlines remain independent. The [console guide](../apps/transit-cli/docs/console.md)
owns configuration examples and presentation limits.

Timing is off by default. `.timer on` reports monotonic wall milliseconds after
SQL attempts, including failures, to stderr. The timing line follows
all result and diagnostic output for that command, including cancellation messages,
and precedes the next interactive prompt. Diagnostic presentation is outside the
measured interval. The total and preparation,
compilation, submission/advancement, wait, fetch/verification, render/output and
persistence phases describe client-observed work, not engine-only execution.
Sub-millisecond phases can report zero. Reporting does not change result stdout
or recovery. `.timer off` disables it. Missing, invalid or extra arguments emit
`Usage: .timer on|off` on stderr, leave the setting unchanged, and return to the
interactive prompt; batch input stops with exit status 1. `.show` includes the
current setting. Mode and timing
survive an interactive connection change.

Admission and verified completion remain distinct. Source-binding changes reject mismatched recovery rather than redirecting original
work; restoring the exact binding permits authorized recovery. Current denial clears
protected metadata, editor recall/search history and result cursors for that
connection; already saved local command history and emitted terminal bytes remain
on the user's machine. Recovery preserves accepted identity through errors.

## Shared incomplete-input assistance

The native grammar owner supplies a versioned bounded assistance result for a
UTF-8 statement plus byte cursor. Board converts its UTF-16 selection to validated
UTF-8 offsets; the terminal uses the same native result. Each result carries
the exact input generation, replacement range, executable capability profile
and current authorized source contract. Required typed `coverage` distinguishes
`complete` from `limited`; `status` distinguishes `ready`, `inside_text` and
`unsupported`. Empty limited scans do not prove absence, and one item does not
prove uniqueness unless coverage is complete. The owner resolves the active
statement around the cursor without discarding its suffix. Acquisition retains
eight ranked candidates and scans at most 128 catalog pages; it never samples
row values. Settings assistance uses the actual configuration route. The current
shared definition rejects missing coverage/status fields.

The terminal keeps one cancellable metadata borrower and one latest draft.
Opening starts acquisition immediately, with no opening delay or loading
placeholder. Same-token edits filter the disclosed shortlist synchronously;
background acquisition follows 75 ms of idle editing and is limited to one second
or the smaller connection budget. Local static vocabulary updates synchronously.
An idle menu retains its candidates, selection and detail page without periodic
acquisition. A retained preview requires the same lexical token context and
unchanged surrounding text, including the suffix. It does not establish current
coverage or insertion evidence. An empty preview is hidden until the current
response establishes the result. Selection follows candidate spelling and kind
through filtering and replacement of the list.
At the end of a fully typed keyword that is the sole complete grammar match,
console assistance advances to the next token using a zero-width cursor range.
Thus `CREATE` offers `TABLE`; partial and interior words keep their replacement
range. Identifiers and limited results never establish this keyword transition.
An initial Tab with one complete match validates and inserts without rendering
a menu. Shift-Tab explicitly opens suggestions, including a single match.
It joins cancelled I/O before reusing the session client. Acceptance re-acquires
current evidence and compares generation, cursor/range, profile, source, contract,
resource revision and policy revision before one atomic text replacement.
The shared completion edit helper separates adjacent word, quoted-identifier,
number and string tokens at replacement boundaries. It preserves existing
whitespace and punctuation, including qualifier dots and closing parentheses.
Accepting `ALL` after `SHOW` therefore produces `SHOW ALL`; completing a partial
word adds no unconditional trailing space. The edit includes any required
separators in the 4 KiB statement limit and one undo group. Its cursor follows
the candidate, before any separator inserted ahead of retained suffix text.
Validation keeps an already displayed menu visible. A unique automatic
insertion remains hidden during validation; losing uniqueness displays the
current choices without insertion. Tab/Enter during refresh does not queue an
insertion. Changed metadata refreshes suggestions without replaying acceptance. Static dot
vocabulary completes locally. PgUp/PgDn exposes clipped selected-item details.

Assistance grants no access and does not compile,
submit or execute a candidate on acceptance.

Candidates distinguish keywords, source/column identifiers and supported meta
command arguments. Their grammar context respects strings, comments, qualified
and quoted names; type-specific constructions exclude unsupported operations.
Stable ranking and filtering precede the result bound. A response for a changed
input, catalog, principal or denied source is discarded. At most one request and
one bounded result exist per editor; there is no global metadata cache or hidden
catalog acquisition. Complete-statement validation remains authoritative.

Independent fixtures must cover valid prefixes, incomplete tokens, suffixes,
unsupported forms, quote/comment boundaries, Unicode offsets and stale/denied
metadata in both Board and the real terminal. Report cold/warm latency and
resident bounds for those fixtures. The catalog of complete SQL drafts remains
a separate API and does not satisfy this cursor-assistance contract.

### Console write routes and recovery

The SQL service supplies enrolled account/database bindings. CREATE/ALTER/DROP
and INSERT/UPDATE/DELETE share the Table compiler and database runtime used by
PostgreSQL and MySQL. Configuration never grants rights. Native and catalog
permissions are checked independently; query access does not imply mutation
access. Each recovery tick advances one original Table operation from the
Catalog's paged pending directory. Independent read sessions do not own recovery.

The Catalog retains complete frozen intents, original token bindings and progress;
the data owner retains its commit outcome. A reply lost after admission is recovered by its
original token, including from a new session. Retrying SQL with a new token creates
new work. Cancellation does not undo published mutations, and quota pressure does
not delete accepted work. The [SQL session contract](SQL_SESSION_V1.md) and
[database gateway contract](SQL_GATEWAY_V1.md) define the durable boundaries.

## Configured local database access

The installed bundle fingerprints its SQL gateway even when disabled. Nullable
`sql.postgres` and `sql.mysql` settings independently select loopback listeners.
The default `sql.native.local: true` starts the shared SQL service and provisions
its local peer account once. With local native access disabled, no native HTTP
listener, no wire listener and no retained enrollment, startup creates no SQL-only
identity, credential, operation history or process. Listener/account/TLS settings require
restart and use the shared configuration registry and environment precedence.

SQL enrollment checkpoints a definition-bound installation identity, exact
pending root requests and completed receipts before deriving dependent work.
Each SQL account uses one scoped database principal. Catalog records own its
activation fence, operation history and snapshot recovery. Application and SQL setup serialize unresolved root work;
public administration uses a separate explicitly privileged principal. Account
role and catalog bindings remain immutable. Public authorization preparation and
apply explicitly publish login binding and data access. Ordinary startup does
not restore revoked credentials or grants.

The administrator's selected root role governs policy changes; catalog name
resolution separately requires database CONNECT and schema USAGE. A generated
`catalog-access.json` proposes those discovery rights for explicit preparation
and apply. Refreshing its policy basis never applies the proposal.

Credential enrollment does not establish database access. Initialization waits
for explicit CONNECT and schema USAGE grants without exhausting the startup
failure budget or blocking another account's enrollment. Runtime startup
publishes a strictly increasing Catalog activation generation. Core readiness and SQL readiness are independent; the
ready record links the atomically published SQL status file. That file carries
states, actual accepting ports, public CA path and per-account control profiles,
never passwords or signing keys. Missing or invalid listener trust cannot grant
admission or prevent listener-free recovery of previously accepted operations.

Disable/remove stops new admission after restart while preserving enrolled
identities, original bindings, Catalog records and pending controls. Retained
unsettled accounts continue under their current rights; removed accounts with
pending writes or snapshot cleanup retain recovery. Settled removed accounts
need no resident worker. Fixed setup receipt arrays describe only finite
setup stages. Account-history scans page through one retained record at a time;
active/recovering accounts have an explicit deployment quota.

Managed trust is checkpointed before PEM publication. Supplied trust must have a
valid matching key/leaf, a verified chain to the advertised CA, TLS server usage
and localhost/127.0.0.1 SANs. A salted password verifier is established once from
an explicit private file. Later password rotation uses the existing signed-control
profile's credential operation, independently from data privileges and account
identity. The [local SQL guide](../apps/transit-cli/docs/sql.md) owns configuration,
client commands, bounds and recovery usage; the [gateway contract](SQL_GATEWAY_V1.md)
owns wire semantics and retained operation evidence.
