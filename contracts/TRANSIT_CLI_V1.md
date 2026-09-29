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
and project `./.transitrc`, in that order. Only `.connect PATH` and `.mode`
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
console interrupted while waiting disconnects with 130 without inventing durable
cancellation. Server SIGINT/SIGTERM initiate joined shutdown. Machine records go
to stdout and diagnostics to stderr; JSON mode has no banner or prompt. Broken
stdout ends the local session without cancelling accepted work.

`query`, `query-v2`, `rey-cli`, `kubectl-transit` and the existing launcher commands
retain their separate configuration and protocols. The query shells use dot
commands and are omitted from the primary command list. No alias silently changes a
single-line shell into a multiline console, adopts a launcher installation or
converts a v2 authority into the growing profile. These separate commands remain supported.

## Local server and recovery

The initial service neighborhood is a growing authority over disk-backed Ursula,
bounded maintenance, a delivery courier, a separately activated query source and
requester, and a public native-protocol gateway. The initial source is an empty
declared int64 Table; a functioning installation need not contain example data.
Version-3 server configuration enables Board by default with its own retained
inspection-only key and explicit resource grants. `--no-ui` disables its process
and listener for one invocation without changing configuration or history. Older
configuration versions require this headless option; pinned artifact identities
still forbid implicit upgrades. Effect connectors remain unsupported optional
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

The selected console executes the existing finite v2 KV/Table/Document query
profile. Source discovery describes only the configured, currently authorized
source. Complete statements compile through Fuze before any native submission.
Administrative/reference SQL, writes, continuous queries and unsupported forms
fail without partial lowering. Application definitions retain their independent
compiler/publication boundary; accepting a declaration as grammar does not make
it executable at a query endpoint.

Interactive SQL submits on Enter after a semicolon outside literals and nested
comments. `-c SQL` runs one statement with an optional semicolon; `-f FILE` and
stdin stream semicolon-delimited statements and dot command lines. A complete
final statement runs at EOF; an unclosed literal/comment fails. `-c` and `-f`
are mutually exclusive and do not read stdin. Batch execution stops on the first
error. Dot commands start an empty input statement; slash commands are rejected.
TTY editing supports movement, deletion, bounded in-memory history, completion
accept/dismiss/undo, resize and Ctrl-C draft clearing. History is not persisted.

The console exposes `.help`, `.info`, `.tables`, `.sources`, `.schema`, `.status`,
`.resume [ID]`, `.cancel`, `.mode table|json`, `.show`, `.connect PATH` and `.quit`.
`.show` emits one setting per line on stdout, with right-aligned names, aligned
colons and escaped text values, independently of the query result format.
Automatic connection selection is `(automatic)`; boolean settings use `on`/`off`.
It reports effective settings and their origins without changing settings,
submitting queries or retrying saved work.
`.connect` is terminal-only and refuses to abandon unresolved work. Unknown
commands/arguments reject as a whole. Normal SQL compiles before identity
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
Disconnecting, clearing a draft, timeout and SIGINT never cancel accepted work.

One session retains one prepared request, finite compiled bundle and result cursor.
Each result page uses complete verified coverage and a current authorized reread.
JSON output emits lossless page envelopes; table output escapes controls and
preserves full-width integers, binary, float bits and distinct cell states.
Results are not accumulated in memory. Waiting for completion checks a five-minute budget
between native operations; upload advances and transport attempts retain their
own finite deadlines and may settle after that budget. Output writes have a
two-second deadline. Completed results stream under finite page limits and
per-request deadlines, without the completion-wait budget. Bounds and supported source types belong in the
[console guide](../apps/transit-cli/docs/console.md).

Admission and verified completion remain distinct. Source-binding changes cannot
remove inspection or exact recovery for original work. Current denial clears
protected metadata, editor history and result cursors; previously emitted terminal
bytes cannot be recalled. Recovery preserves accepted identity through errors.

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
