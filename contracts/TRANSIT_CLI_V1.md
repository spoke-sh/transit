# Transit CLI v1

This contract defines CLI commands, local server lifecycle and console recovery.
The [CLI guide](../apps/transit-cli/README.md) lists commands and usage.
The local server runs on Linux x86_64.

## Command and compatibility boundary

`transit server [--config PATH] [--initialize] [--no-ui]` runs one local installation in the
foreground; `serve` is an equivalent alias. `transit console [--config PATH] [--format table|json]` opens an
explicit-submit terminal session; `-c SQL`, `-f FILE` and stdin run batch input. `--help` and `--version` need no configuration,
credentials, running installation or network. Unknown commands/options, repeated
options, positional leftovers and incompatible versions fail before effects.
Version output identifies the executable and command-contract version; it is
not a promise about remote capabilities or a release tag.

Server configuration overlays built-in defaults with one selected file, then
typed environment values. With no explicit `--config`, the first existing
`./transit.yaml`, `~/transit.yaml` or `/etc/transit/transit.yaml` is selected.
Missing all files leaves defaults intact; an unreadable or invalid selected file
fails without fallback. Objects merge recursively; lists and scalars replace.
`TRANSIT_` uses uppercase schema names and `__` for nested paths; a single `_`
is literal. More specific variables win over whole-object JSON. Unknown settings
and invalid values reject. `TRANSIT_CONSOLE_CONFIG` is reserved for the console.
The [server guide](../apps/transit-cli/docs/server.md#defaults-and-configuration)
defines the default profile, data-only YAML subset, JSON and parsing bounds.

The console derives its default connection from the local server's topology
settings and retained installation record. Server discovery and environment
precedence select the same installation, realm and gateway; built-in defaults
use `./.transit` and `http://127.0.0.1:19105`. Allocated IDs and the scoped caller
credential come from that installation, with a default private recovery record.
There is no generated console configuration file, and the console never
initializes or repairs server state. Incomplete installation records reject.
Console rc settings merge system `/etc/transit/transitrc`, home `~/.transitrc`
and project `./.transitrc`, in that order. Only `.connect PATH`, `.mode` and `.timing`
settings are allowed; no startup SQL or durable operations execute. Missing
files skip; other failures stop. `--init FILE` replaces discovery and `--no-rc`
disables it. They are mutually exclusive. Rc connection paths resolve against
the defining rc file; later paths replace the whole connection reference.
`TRANSIT_CONSOLE_CONFIG` overrides rc selection and explicit `--config` wins.
`--format` overrides rc mode, then the connection's format, then table mode.

Connection and management files use versioned YAML by default, at most 64 KiB.
Explicit `.json` files remain supported. Application declarations and replacement
files accept the same YAML subset; exported connection files use YAML unless
the output path ends in `.json`. Machine responses, bootstrap and recovery
records retain their neutral JSON formats. `.transitrc` remains a dot-command
startup script modeled after `.duckdbrc`, not a YAML configuration.
Paths within them resolve against their file. Credentials, native IDs and trust
settings never merge across connections. Private keys are referenced by files,
never command arguments. Diagnostics name fields or roles without printing
configuration values, request bodies or credentials.
The [public CLI reference](../docs/reference/cli.md#output-philosophy-explain-locate-guide)
owns the human-output conventions: one specific explanation, with a location
or next step when useful. Known option errors name the option; unknown arguments
use positions without echoing their values. Configuration decoding reports the
file and parser location; semantic validation names fields. Known reasons use
plain language, while untranslated failures retain their identifiers. Exhausted
restarts remain distinct from the underlying role failure. Root and application
group help list commands; each command, including application operations, has
offline `--help`. Supplied arguments remain strictly validated during help. Human wording and implementation error names
are not a versioned machine schema. Recovery advice preserves saved identity and
never treats uncertainty as proof of rejection.

Successful help, version, ordinary disconnect and joined server shutdown return
0; invalid invocation/configuration returns 2; runtime failure returns 1. A
console interrupted during SQL or `.resume` cancels execution and returns to an
empty terminal prompt. Interactive execution stops local evaluation and releases
its leased snapshot; durable execution requests recorded query cancellation. Batch interruption exits 130 after a
resolved outcome, or 1 if cancellation fails. Interrupting metadata or idle batch
input disconnects with 130 without cancellation. Server SIGINT/SIGTERM initiate joined shutdown. Machine records go
to stdout and diagnostics to stderr; JSON mode has no banner or prompt. Broken
stdout ends the local session and releases an interactive snapshot; durable
accepted work remains recoverable.

`query`, `rey-cli`, `kubectl-transit` and the existing launcher commands
retain their separate configuration and protocols. The query shell uses dot
commands and are omitted from the primary command list. No alias silently changes a
single-line shell into a multiline console, adopts a launcher installation or
changes a connection's authority or installs an application. These separate commands remain supported.

## Explicit SQL bindings

`transit console -c SQL --parameters FILE` executes one finite SELECT with an
ordered JSON array of the existing exact query scalars. The flag requires `-c`;
it cannot select a script, startup command, inspection or write route. The
ordinary `-c` path retains its existing behavior when the flag is absent.

Both the console and `transit query` shell accept `.execute FILE`. The JSON file
has the shared workspace compilation shape `{sql, parameters?}`. Omitted/null
parameters select ordinary SQL; an explicit empty array selects a template with
no placeholders. The query shell requires its ordinary `.new ID` selection.
The console uses the configured interactive or durable execution mode. These
explicit query inputs do not route administrative or mutation statements.

Files resolve against the process working directory and are bounded to 131072
bytes. Parsed SQL and scalars belong to the current execution arena; at most
three bindings and 4096 SQL bytes reach the shared compiler. Duplicate/unknown
fields and malformed scalar representations reject. Comparison operands require
exact types; LIMIT requires uint64. The [parameter contract](SQL_PARAMETERS_V1.md)
defines the canonical scalar encodings and grammar sites. Values are never
substituted into SQL text. Input files are new compilation requests, not saved
prepared templates, source snapshots or recovery records.

Compilation and execution preserve current access and budget checks. Durable
admission checkpoints the ordinary bundle and signed operation before dispatch.
After an unknown outcome, `.resume`, `.restore-bundle` and `.retry` use that
original evidence without reopening input files or rebinding values. A changed
or deleted parameter file cannot change the accepted query. No bindings persist
as session defaults, and query values are not added to dot-command history.

## Local file queries

`transit file-query --format csv|jsonl -c SQL [OPTIONS] FILE...` explicitly
acquires local paths/stdin into quota-limited, private unlinked disk captures on
Linux x86_64. It checks single-member gzip headers/checksums when `--gzip` is
selected. Local OS access supplies authority; the command does not send native
commands, create a durable job or refetch during replay. Discovery freezes exact
content, options, schema and evidence before any result record. Fuze owns shared
SQL lowering, typed conversion, predicate and aggregate semantics.

The [file-query guide](../apps/transit-cli/docs/file-query.md) owns exact flags,
logical schema JSON, quotas, format limits and output records. Stdout is a
versioned JSON-lines stream with schema/binding/plan evidence, provisional rows
and a terminal completion record. Missing completion or a failed exit invalidates
the prefix. Full input validation continues past LIMIT/projection. Exact integers,
decimals and five states use the neutral logical codec; no host-float rounding is
permitted. No saved configuration or native protocol compatibility field changes.
SIGINT/SIGTERM return 130 after local capture cleanup; broken output returns 1.

## Explicit catalog commands

`transit catalog` composes the shared [catalog caller](DECLARATIVE_CATALOG_V1.md).
`capabilities` and scoped `compile` are offline. `describe` reads current metadata;
`prepare-initialize`, `prepare-create` and `prepare-policy` save signed commands
without dispatch. `submit` alone sends the exact saved command. `observe` reads
its input processing, `disposition` reads control/rejected-input outcomes, and
`status` reads the original creation receipt. Admission and processing do not
establish Table publication. Current native and catalog rights remain independent.

Compilation/preparation require new private output files with file/directory sync
and no replacement. Later calls validate typed compiled fields against their
canonical bytes. Prepared input restores the original signed string under the
current definition. Unknown outcomes retain the same artifact for exact retry;
no replacement preparation, automatic dispatch or implicit provisioning occurs.
The [catalog guide](../apps/transit-cli/docs/catalog.md) owns configuration,
command syntax, input envelopes, numeric bounds and recovery examples.

## Explicit mutation commands

`transit mutate` uses the shared [Table mutation contract](TABLE_MUTATION_V1.md).
`capabilities` is offline; `describe` reads currently authorized metadata.
`compile` saves a request/reference, `next` prepares one upload stage and
`prepare --control apply|cancel` prepares an explicit control. These operations
do not send native commands. `submit` sends an exact saved command; `observe`
and `rejection` inspect its admitted input, while `status` reads the durable
request outcome. Admission and application remain distinct.

Compilation and preparation require a new private output file. Atomic creation,
file synchronization and directory synchronization precede successful output;
existing paths are refused. Submission validates the saved definition, target
and signature through the shared client. An unknown outcome retains the original
file for exact retry; there is no automatic retry or sequence coordination.
Current grants and writer policy still apply. Terminal cancellation cannot undo
an applied result. The [mutation guide](../apps/transit-cli/docs/mutations.md)
owns exact flags, configuration and artifact bounds. These commands require their
own mutation connection; query permissions do not authorize writes.

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

The configuration names its installation directory and executable dependencies.
The persistent installation records a random installation identity, format and
artifact identities, realm/root public key, storage locations, role identities,
credential references and accepted provisioning receipts. Dependency checking
happens before provisioning. Published release bundles are not available; a shell,
Python, `just`, Process Compose and a source checkout are not runtime dependencies
of the server. Ursula remains the pinned upstream binary.

The selected local profile also runs an explicitly supplied native MinIO binary:
pinned Ursula provides S3 cold storage, with no filesystem cold backend. Keeping
the provider separate preserves its bounded hot/cache profile without introducing
a new storage engine into the CLI. The source-built local bundle includes this
dependency; distribution must retain its license alongside the selected Transit
artifacts. Role limits and exact artifact
versions belong in the [server guide](../apps/transit-cli/docs/server.md).

`--initialize` deliberately creates a new installation, refusing an existing
initialized directory. Ordinary startup requires the recorded installation and
storage. There is no automatic initialization, destructive reset, storage
replacement, generation rollback or deletion of a stale activation marker.
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

Every growing worker replacement uses a fresh key and an exact generation.
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
TTY editing supports movement, deletion, Up/Down recall, Ctrl-R reverse substring
history search, completion accept/dismiss/undo, resize and Ctrl-C draft clearing.
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

The console exposes `.help`, `.info`, `.tables`, `.sources`, `.schema`, `.status`,
`.resume [ID]`, `.cancel`, `.mode table|json`, `.timing on|off`, `.show`, `.connect PATH` and `.quit`.
`.show` emits one setting per line on stdout, with right-aligned names, aligned
colons and escaped text values, independently of the query result format.
Automatic connection selection is `(automatic)`; boolean settings use `on`/`off`.
It reports effective settings and their origins without changing settings,
submitting queries or retrying saved work.
`.connect` is terminal-only and refuses to abandon unresolved work. Unknown
commands/arguments reject as a whole. Default interactive SQL uses a fresh leased
snapshot and local evaluation, as defined by [interactive queries](INTERACTIVE_QUERY_V1.md).
The upload and recovery behavior below applies to `execution: durable`.
Durable SQL compiles before identity
allocation, selects a nonzero unused random identity within the exact protocol
counter range, persists its intent, advances the native upload and prints
verified complete results one page at a time. It never substitutes new SQL for
a retry. `.new`, `.retry` and manual upload/result controls are not exposed.

Automatic SQL requires an explicit `recovery_file` setting; generated local
connections supply it. The private record stores the query bundle, exact signed
pending request, admission and cursor, not keys or rows. It binds the configured
realm/principal/requester/request resource and caller public key. Atomic replacement
and synchronization precede dispatch and successor preparation. Persistence failure
stops submission. Locks serialize recovery-file owners and users of the same local
credential file. This does not coordinate copied credentials in other clients.

Opening a session loads recovery without dispatch. `.resume` reconciles that
same signed intent and upload, waits and reads results from the beginning;
previously printed rows may repeat. `.resume ID` selects an existing query only
when no unresolved operation would be displaced. `.cancel` is an explicit native
cancellation request; its admission does not promise completed cancellation.
Ctrl-C during SQL or `.resume` settles only the frozen operation before preparing
native cancellation. Repeated Ctrl-C coalesces during cleanup; SIGTERM still
disconnects. The console observes the requester disposition and active-slot
release before clearing saved intent and returning to an empty prompt. It
discards remaining statements in the submitted draft. Cancellation closes the
requester wait and withdraws the request publication; source work observes closure
between bounded turns. A turn already in progress may finish. If completion won,
the console reports completed execution with interrupted presentation, without
claiming to undo the query. An incomplete prefix does not acquire a final coverage
marker or row total through cancellation; output already emitted stays disclosed.
Unconfirmed cancellation retains the original query and frozen operation, reports
the failure, and prevents new SQL from replacing unresolved work. Persistence
failure ends the session. Frozen-input settlement and active-slot cleanup each
check a 30-second budget between bounded native operations. Current grants still
apply. Ordinary disconnect, draft clearing, timeout, SIGTERM and output failure
do not cancel accepted work. Compatibility query shells keep their own contracts.

One session retains one prepared request, finite compiled bundle and result cursor.
Each result page uses complete verified coverage and a current authorized reread.
JSON output emits lossless page envelopes. Default table output consumes the
verified native Arrow batch, shows column names/types and right-aligns numbers.
Each bounded page has its own box borders and column widths. Table output quotes
strings, escapes controls and preserves full-width integers and distinct cell
states; binary values use hex and floats use decimal. JSON retains float bits.
Results are not accumulated in memory. Waiting for completion checks a five-minute budget
between native operations; upload advances and transport attempts retain their
own finite deadlines and may settle after that budget. Output writes have a
two-second deadline. Completed results stream under finite page limits and
per-request deadlines, without the completion-wait budget. Bounds and supported source types belong in the
[console guide](../apps/transit-cli/docs/console.md).

Timing is off by default. `.timing on` reports monotonic wall milliseconds after
SQL and resume attempts, including failures, to stderr. The timing line follows
all result and diagnostic output for that command, including cancellation messages,
and precedes the next interactive prompt. Diagnostic presentation is outside the
measured interval. The total and preparation,
compilation, submission/advancement, wait, fetch/verification, render/output and
persistence phases describe client-observed work, not engine-only execution.
Sub-millisecond phases can report zero. Reporting does not change result stdout
or recovery. `.timing off` disables it. Missing, invalid or extra arguments emit
`Usage: .timing on|off` on stderr, leave the setting unchanged, and return to the
interactive prompt; batch input stops with exit status 1. `.show` includes the
current setting. Mode and timing
survive an interactive connection change.

Admission and verified completion remain distinct. Source-binding changes cannot
remove inspection or exact recovery for original work. Current denial clears
protected metadata, editor recall/search history and result cursors for that
connection; already saved local command history and emitted terminal bytes remain
on the user's machine. Recovery preserves accepted identity through errors.

## Shared incomplete-input assistance

The native grammar owner supplies a versioned bounded assistance result for a
UTF-8 statement plus byte cursor. Board converts its UTF-16 selection to validated
UTF-8 offsets; the terminal uses the same native result. Each result carries
the exact input generation, replacement range, executable capability profile
and current authorized source contract. It grants no access and does not compile,
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

An optional `writes` object contains `recovery_file` and at least one of `table`
(name plus TableMutationClient connection) or `catalog` (Catalog.Client connection).
Both use the console's transport and credential, with matching realm/principal.
The file is distinct from query recovery. The automatic local connection supplies
the `items` Table route from allocated installation identities and uses
`console-writes.json` in the installation directory. It uses the existing
credential lock, recovery validation and explicit resume behavior. Explicit
connection files supply their own routes; catalog creation is not configured by
the local default. No route or configuration grants rights.
Supported mutations and compatible CREATE TABLE use their owning clients;
`.help` and SQL topics explain both present and absent routes without native I/O.

Write recovery is a separate JSON record, bounded to 32768 bytes. Required fields
are version 1, current `definition`, public `key`, optional `table` connection and
`name`, optional `catalog` connection, optional `operation`, `complete` and
`cancelling`. A mutation owns namespace, typed request, optional prepared command
and its optional admitted input; creation owns its typed request, prepared command
and optional input. The definition, key, connections and prepared request binding
are validated before native I/O. Exact canonical JSON equality rejects omitted
nested compatibility fields, alternate formatting and unknown fields; a missing
field cannot acquire a native type's convenience default. Writes use
atomic 0600 replacement with file and parent synchronization; a persistence error
stops further execution. Opening never submits. Each exact signed command is
saved before sending; receipt position remains paired with it through processed
observation and rejection checks. Terminal outcomes are read under current rights.

`.status` observes the saved write, `.resume` reconciles it, and `.cancel` requests
mutation cancellation after reconciling its pending send. Interruptions preserve
work; neither interruption nor cancellation undoes applied rows. CREATE TABLE has
no cancellation operation. Unresolved writes block replacement work and connection
switching. A new durable query replaces completed write recovery only after SQL
compilation. Query recovery keeps its own format and lifecycle.
