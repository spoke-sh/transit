# Transit CLI v1

Status: selected implementation contract for [M24](../docs/roadmap/M24.md),
not qualification evidence. The [CLI guide](../apps/transit-cli/README.md) records
which commands actually exist. Native placement initially targets Linux x86_64.

## Command and compatibility boundary

`transit server --config PATH [--initialize]` runs one local installation in the
foreground. `transit console --config PATH [--format table|json]` opens an
explicit-submit terminal session. `--help` and `--version` need no configuration,
credentials, running installation or network. Unknown commands/options, repeated
options, positional leftovers and incompatible versions fail before effects.
Version output identifies the executable and command-contract version; it is
not a promise about remote capabilities or a release tag.

Configuration is a strict versioned JSON file, at most 64 KiB. Explicit command
options override corresponding file options; there is no implicit environment,
current-directory, home-directory, launcher-state or credential discovery.
Paths resolve relative to the configuration file. Private keys are referenced by
files and never accepted as command arguments. Diagnostics name the failing
field or role without printing configuration, request bodies or credentials.

Successful help, version, ordinary disconnect and joined server shutdown return
0; invalid invocation/configuration returns 2; runtime failure returns 1. A
console interrupted while waiting disconnects with 130 without inventing durable
cancellation. Server SIGINT/SIGTERM initiate joined shutdown. Machine records go
to stdout and diagnostics to stderr; JSON mode has no banner or prompt. Broken
stdout ends the local session without cancelling accepted work.

`query`, `query-v2`, `rey-cli`, `kubectl-transit` and the existing launcher commands
retain their separate configuration and behavior. No alias silently changes a
single-line shell into a multiline console, adopts a launcher installation or
converts a v2 authority into the growing profile. No removal is selected in M24.

## Local server and recovery

The initial service neighborhood is a growing authority over disk-backed Ursula,
bounded maintenance, a delivery courier, a separately activated query source and
requester, and a public native-protocol gateway. The initial source is an empty
declared int64 Table; a functioning installation need not contain example data.
Board and effect connectors are opt-in roles with independently scoped keys;
unsupported optional configurations reject rather than starting partial roles.

The configuration names its installation directory and executable dependencies.
The persistent installation records a random installation identity, format and
artifact identities, realm/root public key, storage locations, role identities,
credential references and accepted provisioning receipts. Dependency checking
happens before provisioning. M25 owns distributing these artifacts; a shell,
Python, `just`, Process Compose and a source checkout are not runtime dependencies
of the server. Ursula remains the pinned upstream binary.

The selected local profile also runs an explicitly supplied native MinIO binary:
pinned Ursula provides S3 cold storage, with no filesystem cold backend. Keeping
the provider separate preserves its bounded hot/cache profile without introducing
a new storage engine into the CLI. M25 must distribute this dependency and its
license alongside the selected Transit artifacts. Role limits and exact artifact
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

SQL submits on a semicolon outside quoted strings/identifiers and nested comments.
Multiline and pasted input share this scanner. A slash command is recognized
only at the beginning of an otherwise empty input statement; slashes and
semicolons in strings/comments stay SQL. EOF with a nonempty unterminated statement
reports incomplete input and does not submit it. TTY editing supports movement,
deletion, bounded in-memory history, completion accept/dismiss/undo, resize and
Ctrl-C draft clearing. No history persists automatically; secret/private literals
and rows are not written to a history file.

`/help`, `/info`, `/tables` (alias `/sources`), `/schema`, `/status`, `/next`,
`/resume ID`, `/cancel`, `/retry`, `/format table|json` and `/quit` retain their
owning query semantics. V2 additionally exposes explicit fresh namespace,
upload advance and recovery export/import. `/resume` selects an identity without
resubmitting it. `/retry` resends frozen uncertain bytes; `/cancel` is an explicit
durable operation. Disconnecting, pausing input or clearing a draft never cancels.
Unknown commands/arguments reject as a whole. Output escapes terminal controls
and preserves full-width integers, binary and distinct nested cell states.

One session retains one prepared request, one finite compiled bundle and one
result cursor. Result rendering uses complete verified coverage and a current
visible-page reread; admission, incomplete delivery and verified completion are
different labels. Loss or change of a source binding cannot remove status,
exact retry or cancellation for the original operation. Current denial clears
protected metadata, editor history and results; previously emitted terminal
bytes cannot be recalled. Explicit recovery files contain no private key and
are validated against the configured realm/principal/requester before use.

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
resident bounds for those fixtures. M23's catalog of complete SQL drafts remains
a separate API and does not satisfy this cursor-assistance contract.
