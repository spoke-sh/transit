# Transit console

`transit console` executes finite reads over the
configured KV, Table or Document source. Each SELECT compiles SQL, acquires a
fresh leased snapshot and executes Fuze in the client, printing native Arrow
batches. Completion or cancellation releases the snapshot. No durable query
upload, execution progress or result publication is written by a SELECT.

`DESCRIBE items`, `SHOW TABLES` and `EXPLAIN SELECT ...` inspect the configured
source and proposed plans under current read access. They acquire no snapshot
and submit no query. JSON mode returns one `inspection` envelope; table mode
labels the configured scope, metadata revision, columns or logical plan. See
the [SQL inspection contract](../../../contracts/SQL_INSPECTION_V1.md).
Bare `transit console` uses the [local server](server.md)'s topology defaults,
including its `transit.yaml` discovery and `TRANSIT_` overrides. It reads allocated
resource identities from the existing installation and uses its scoped
`caller.seed`. No console configuration file is
generated or required for this connection. The local server also provisions an
authorized writer for `items`; INSERT, UPDATE and DELETE use it automatically.
The default endpoint is `http://127.0.0.1:19105`, and the
default installation is `./.transit`. The console never initializes the server.

```sh
transit console
transit console -c 'SELECT COUNT(*) FROM items'
transit console --format json -f queries.sql
```

## Startup preferences

The console merges settings in this order; later assignments win:

1. `/etc/transit/transitrc`
2. `~/.transitrc`
3. `./.transitrc`

Missing files are skipped; an unreadable or invalid file stops startup. Each file
is at most 64 KiB. Blank lines and `#` comment lines are ignored. Only `.mode`,
`.timing` and `.connect` settings are accepted; SQL and recovery operations cannot run at startup.
For example, a project `.transitrc` can contain:

```text
.mode table
.timing on
# Optional remote or separate connection:
# .connect connection.yaml
```

Paths in `.connect` resolve relative to the rc file that sets them. Quoted paths
are accepted. A later `.connect` replaces the entire connection-file reference;
credentials, identities and trust settings are never combined across connections.
`--init FILE` selects a single startup file instead of the hierarchy; `--no-rc`
skips all startup files. The two flags cannot be combined.

`TRANSIT_CONSOLE_CONFIG` overrides the rc connection, and `--config` overrides
that environment variable. An unset or empty variable has no effect. `--format`
overrides rc `.mode`, which overrides the connection file's `format` (default
`table`). `.show` prints effective connection and presentation settings and their
origins. Interactive `.connect PATH` closes the current connection and opens the
selected file; it refuses to leave unresolved work. It is not available in batch
input. Without a connection override, run the console in the server working
directory with the same topology configuration and environment. Missing or
incomplete installation state stops startup; credentials and allocated IDs
are never invented. A selected connection file supplies its own credential
references and does not depend on a local installation.

## Configuration and trust

Connection files use YAML by default; explicit `.json` files remain supported.
The same [bounded YAML subset](server.md#defaults-and-configuration) applies,
with a 64 KiB limit. Unknown/duplicate fields,
unsupported versions and invalid endpoints reject before native operations.
Paths resolve relative to this file. Private signing keys stay in referenced
files. The default `execution: interactive` needs no recovery file. Select
`execution: durable` with a `recovery_file` to retain exact signed query intent
and recover captured results after disconnection. That explicit mode retains
its serialized caller and recovery-file locks.

```yaml
version: 1
profile: "unified_v1"
url: "http://127.0.0.1:8301"
transport: "loopback"
seed_file: "caller.key"
connection:
  realm: 42
  principal: 1234
  source: 1
  resource: 7
  requester: 2
  requests: 8
workspace:
  name: "items"
  source:
    version: 1
    resource: 7
    source:
      table:
        id: 1
        names: ["id", "value"]
        value_type: "int64"
  limits:
    pages: "1000"
    segments: "100"
    result_bytes: "1048576"
request_timeout_ms: 5000
format: "table"
execution: "interactive"
```

The example is a configuration shape, not allocated identities or a grant.
Use the actual provisioned IDs and source contract. Table names, KV decoders
and Document projections follow the [unified source guide](unified-query.md).
The timeout defaults to 5000 ms and must be 1–60000 ms.

`loopback` accepts literal `127.0.0.1` or `::1` HTTP endpoints. Remote connections
must select `tls_system` (HTTPS with system roots) or `tls_ca` (HTTPS with an
explicit `ca_file`). The latter uses only that trust bundle. Endpoint credentials,
query strings, fragments and path prefixes are rejected. The existing native
client verifies the peer and never follows redirects with signed requests.
Neither transport selection nor configuration grants native access.

## Writing Tables and catalogs

Use `.help INSERT`, `.help UPDATE`, `.help DELETE` and `.help CREATE TABLE` to
learn the supported SQL and configuration without network access. `.help` reports
whether each route is configured; authority is checked when executing it. Both
interactive and durable query modes support writes. Bare local-server connections
supply both query and Table writer routes for `items`, using the installation's
allocated identities and scoped caller credential. Write recovery lives in
`console-writes.json` inside the installation. Opening the console loads saved
work without resubmitting it; use `.status` and `.resume` after interruption.
The credential lock permits one write-capable console per local caller seed.
Server restart preserves current mutation policy, including revocation.

For a separately configured connection, add explicit routes to its YAML using
provisioned identities. Selecting a connection file replaces the automatic local
connection; omitted write routes remain unavailable. Catalog creation always
requires a separately provisioned catalog route:

```yaml
writes:
  recovery_file: "console-writes.json"
  table:
    name: "items"
    connection:
      realm: 42
      principal: 1234
      writer: 1
      resource: 7
      table: 1
  catalog:
    scope:
      realm: 42
      resource: 9
      catalog: 1
    owner: 3
    principal: 1234
```

Either route may be omitted. Realm and principal must match the console's
credential; the named writer/catalog must already expose its respective public
operation. Native grants and separate current mutation or catalog create/inspect
policy are required. Query permissions do not grant writes. The write recovery
path must differ from the query recovery path; paths resolve relative to the
connection file. A credential lock serializes local consoles using writes.

```sql
INSERT INTO items (id, value) VALUES (1, 100);
UPDATE items SET value = 101 WHERE id = 1;
DELETE FROM items WHERE id = 1;
CREATE TABLE readings (id INT64 NOT NULL, value INT64 NULL);
```

INSERT requires both columns and one to three literal rows. UPDATE/DELETE require
primary-key equality. CREATE TABLE accepts exactly two columns with explicit
nullability: a non-null int64 key and a nullable int64, boolean, UTF-8 or binary
value. Creation publishes the empty Table descriptor and catalog definition.
It does not configure a query source, choose a Table writer or grant permissions.
SELECT continues to use the configured query workspace. With a catalog configured,
SHOW TABLES and `.tables` stream its bounded metadata pages; DESCRIBE resolves
catalog names. `.schema` continues to describe the query source. If the catalog
changes between pages, discard the partial listing and run it again.

The console saves the original typed request and each exact signed command before
submission in a private file (0600, at most 32 KiB). The mandatory current contract
definition, public key and route identities are checked before recovery; no keys
or result rows are saved. Recovery is canonical JSON: retain its original bytes;
do not edit or reformat it. Missing nested compatibility fields reject. Atomic file replacement synchronizes both file and
parent directory. A native receipt proves admission only. The console observes
processed input and its rejection before advancing an upload, and prints affected
rows only after the writer's terminal applied result. JSON uses `mutation` or
`creation` envelopes; full-width operation identities are decimal strings.

Opening the console never resubmits saved work. `.status` observes under current
rights; `.resume` reconciles the original signed request and continues its saved
operation. Ctrl-C stops waiting, preserves the operation and discards the remaining
submitted batch; disconnecting does not undo a write. `.cancel` first reconciles
any uncertain mutation input, then requests cancellation. It cannot undo an
applied mutation, and CREATE TABLE has no cancellation operation. Recovery commands
refer to the last saved write until replaced by another write or durable query.
An explicit `.resume ID` selects a durable query only after pending writes finish.
Do not repeat SQL after uncertainty: it creates a new operation. Unresolved work
blocks new writes, queries and connection switching; inspection/help remain usable.
If recovery persistence fails, execution stops before sending a successor.

## Input, commands and results

```text
.tables
SELECT id, value
FROM items LIMIT 8;
.mode json
.show
.quit
```

Interactive SQL submits on Enter after a semicolon outside literals and nested
comments. Bracketed paste stays in the draft until Enter. Dot commands start an
empty statement and end at newline/Enter. Slash commands are unsupported.
Submitted statements stay visible in terminal scrollback above their results,
with continuation prompts for multiline input. The transcript uses stderr so
redirected stdout contains results only. An unfinished multiline draft uses a
continuation prompt until its terminating semicolon.
Typing or accepting completion never submits. Unsupported SQL fails before a
query identity is allocated or any mutation is sent.

`-c SQL` runs one statement and exits; its final semicolon is optional. `-f FILE`
executes a script, and redirected stdin uses the same streaming script reader.
Scripts accept dot commands on their own lines and SQL separated by semicolons.
A final complete statement runs at EOF without a semicolon; an unclosed literal
or comment fails. `-c` and `-f` are mutually exclusive and never read stdin.
Batch execution stops at the first failure; interactive execution reports the
error and returns to the prompt when recovery permits.

| Command | Purpose |
| --- | --- |
| `.help [SQL\|INSERT\|UPDATE\|DELETE\|CREATE TABLE]` | Offline SQL help, route configuration and commands |
| `.tables` | Catalog tables when configured, otherwise the query source |
| `.sources`, `.schema` | Currently authorized query source and schema |
| `.mode table\|json` | Result presentation |
| `.timing on\|off` | Set query wall-time reporting (off by default) |
| `.show` | Aligned text showing effective console settings and origins |
| `.connect PATH` | Switch connection in an interactive session |
| `.status`, `.info` | Saved write/query status, or query result evidence |
| `.resume [ID]` | Recover the saved write; in durable query mode, recover the saved query or selected query ID |
| `.cancel` | Request cancellation of a saved Table mutation or durable query; CREATE TABLE cannot be cancelled |
| `.quit`, EOF | Exit; active interactive execution is canceled |

There is no `.new`, `.retry`, `.advance` or `.next` in the console. Normal SQL
performs that bookkeeping. The compatibility `query` and `query` shells keep
their separate explicit protocols, with dot commands; they are not advertised in
root help. See the [v1 shell guide](unified-query.md) for that interface.

`.show` always prints one setting per line with right-aligned names and aligned
colons, including in JSON result mode. Automatic connection selection appears
as `(automatic)`; an explicit connection shows its file path. For example:

```text
transit> .show
       connection: (automatic)
connection_source: local installation
              url: http://127.0.0.1:19105
           format: table
    format_source: connection configuration
           timing: off
    timing_source: default
```

Timing displays as `on` or `off`. The source rows identify the effective rc file,
environment variable, command-line option or interactive command. Paths and other
text escape control characters.
Inspection does not change settings, submit or retry a query, or change query
result formatting. A script containing `.show` includes these text rows on stdout
even when its SQL results use JSON envelopes.

Table mode is the default. It renders the verified Arrow batch directly, with
box borders, column names and native types, right-aligned numbers and a row total.
Strings are quoted and escaped so literal `"NULL"`, null, missing, type errors and
conflicts stay distinguishable; binary values use hex. Each bounded page has its
own headings and widths. JSON mode
emits one lossless `interactive_v1` envelope per line, with session identity,
source basis, ordinal, columns, typed cells and complete-coverage evidence.
Durable mode retains its captured-result manifest envelope. Integers remain decimal
strings, binary stays hex, floats preserve bits and missing/null/type-error/
conflict states remain distinct. Pages are verified through the shared query
client and read under current grants. Rows are released after each page; the
console never accumulates the whole result. Prompts and diagnostics use stderr.

`.timing on` reports monotonic elapsed milliseconds to stderr after each SQL or
`.resume` attempt, including failed attempts. The total includes preparation,
compilation, snapshot acquisition, fetching/executing pages, rendering/output
and release. Interactive timing reports `compile`, `open`, `fetch`, `render`
and `release`. Compilation uses the configured declaration without I/O; opening
acquires a fresh snapshot and validates current source policy and schema.
Fetch includes Fuze execution and current authorization before disclosure. With
combined native reads, the final fetch also releases the snapshot, so the
separate `release` phase can be zero. In durable mode, submission includes the native
upload protocol and its checkpoints: begin the upload, send plan parts, seal the
bundle and submit it, waiting for requester processing between steps. The wait
phase includes source-worker execution, durable result publication and delivery
of the completion to the requester. These are client-observed phases rather than
pure network or engine execution time.
For Table mutations and catalog writes, `compile` measures local lowering;
`prepare` includes current metadata, identity checks and signing each command.
`submit` measures native send acknowledgements. `wait` includes processed-input
observations and polling sleeps; `fetch` reads rejection and terminal outcome
records. `persist` includes every atomic recovery-file replacement and file/directory
sync throughout the operation, and `render` writes the final presentation.
An admission acknowledgement alone is not a completed mutation. These phases
partition client wall time; worker and storage work can occur during several of them.
Sub-millisecond work can display as zero. Timing does not change JSON stdout or
query recovery, and `.timing off` disables it. Missing, invalid or extra arguments
print `Usage: .timing on|off` to stderr without changing the setting. Interactive
input returns to the prompt; batch input stops with exit status 1. Use `.show` to
inspect the current setting. Interactive connection changes
retain the current mode and timing preference.

The Linux terminal supports Left/Right, Home/End (also Ctrl-A/Ctrl-E), Backspace,
Delete, Ctrl-U, eight-entry SQL history with Up/Down, and Ctrl-C draft clearing.
Dot commands and recovery arguments never enter history. No history is written
to disk. The horizontally scrolling, highlighted draft renders newline, Unicode
and control bytes as visible escapes; the underlying SQL remains unchanged.
The display responds to terminal resize and restores the original terminal
attributes on normal and handled-signal exit.

Ctrl-Space opens shared [cursor assistance](../../../contracts/QUERY_ASSISTANCE_V1.md).
Up/Down chooses a candidate, Tab/Enter accepts it, Escape dismisses it and Ctrl-Z
undoes the acceptance. Acceptance rechecks current metadata. Input queued while
a metadata read waits discards the older response. An idle result expires after
five seconds. Observed denial clears draft, undo, history, completion and result
cursor; frozen recovery intent remains separate. Previous terminal output was
already disclosed and cannot be recalled.

Ctrl-C during SQL stops result presentation, reports cancellation on stderr and
returns to an empty prompt where another query can run. Remaining statements in
the submitted draft are discarded. Ctrl-C at the prompt clears only the draft.
In the default interactive execution mode, it stops local evaluation and attempts
to release the leased snapshot; failed cleanup falls back to lease expiry.

In durable execution mode, Ctrl-C during SQL or `.resume` requests recorded
cancellation of that query. The console reconciles any frozen signed request before sending
the cancellation; it does not finish uploading the remaining plan. It observes
the requester disposition and release of its active upload slot before clearing
the saved query. It reports the outcome on stderr and returns to an empty prompt,
where another query can run.

Repeated Ctrl-C during cancellation is coalesced; SIGTERM still disconnects.
If execution already completed, the message says so and stops any remaining result
display without cancelling the completed query. A previously printed prefix is
not full result coverage; interruption does not print a successful total or a
final complete page. Already disclosed output cannot be recalled. Cancellation
closes the requester wait and withdraws its request publication; source workers
observe closure between bounded turns, and a turn already running may finish.
It does not undo completed computation or delete retained history.

If cancellation cannot be confirmed, the console reports the failure and retains
the original query and exact pending operation. Use `.status` and `.cancel` to
reconcile it; new SQL cannot replace unresolved work. Persistence failure ends
the session. Native operations settle within their configured request bounds;
each frozen-input settlement and the active-slot cleanup wait checks a 30-second
budget between operations. Cancellation never bypasses current authorization.

Normal disconnect/help exits 0; invalid invocation/configuration exits 2;
runtime or batch command failure exits 1. SIGINT during batch SQL or `.resume`
attempts the same cancellation and exits 130 on a resolved outcome; durable
cancellation failure exits 1. Interrupting a metadata command or idle piped input
disconnects with 130. SIGTERM and broken stdout also disconnect. Interactive
execution stops and releases its snapshot; durable accepted work survives these
disconnects. Killed interactive clients leave only bounded lease bookkeeping:
60 seconds between reads, with a five-minute hard lifetime. The authority admits
at most 64 active snapshots, eight per principal. Tokens do not survive authority
restart. The `query` and `query` shells retain their explicit cancellation and
recovery protocols. Cancellation cannot undo completed work or a disclosed prefix.

## SQL errors

SQL errors explain the failed stage and the supported next step. For example:

```text
transit> SELECT;
error: SQL parse error [syntax] (InvalidSqlSyntax) at line 1, column 7: expected an identifier
  SELECT;
        ^--- error here
```

The following guidance points to the supported SQL reference. Coordinates count
UTF-8 bytes within the submitted statement, starting at one; script coordinates
are relative to each statement, not the whole file. The caret follows the escaped
display. At most 120 source bytes around the failure are shown. Literal values,
quoted identifiers and comments are masked, including unfinished tokens. These
excerpts appear in local stderr diagnostics, not telemetry or result stdout.

The categories distinguish syntax errors, unsupported constructs, exceeded
bounds, source/type binding failures, grammar-only families and operations
unavailable on the query interface. Grammar-family recognition alone does not
validate the submitted syntax. `INSERT`, `UPDATE` and `DELETE` use an explicitly
authorized Table writer configured in `writes.table`. INSERT also requires
explicit column names. Compatible CREATE TABLE uses `writes.catalog`. Missing
routes point to `.help INSERT` or `.help CREATE TABLE`; grammar-only forms are
identified without claiming executable support.

Failed compilation creates no query identity, acquires no query snapshot and
sends no mutation. Inspection and durable compilation can read current authorized
metadata. Runtime failures can follow admission or partial output; follow their
recovery guidance and retain the original saved identity. A syntax correction is
not a reason to replace unresolved durable work with a new request.

## Exact recovery and bounds

The recovery behavior below applies to `execution: durable`. Interactive queries
start fresh after reconnecting and do not create or load recovery records. Their
source adapter workspace is bounded to 1 MiB per page, with a 64-entry snapshot
cache and fixed Arrow buffers. A visible prefix is incomplete until its terminal
frame or row footer; failures never turn it into a successful result.

The recovery record is at most 128 KiB and binds the realm, principal, requester,
request resource and caller public key. It contains query literals and signed
intent, never private keys or result rows. Companion locks serialize managers of
the recovery file and of the same local credential file; copied credentials used
by other clients are outside that local lock boundary.

The console writes a 0600 temporary file, synchronizes it, atomically replaces
the record and synchronizes the parent directory before sending a frozen
request. It records a received receipt before preparing a successor. A failed
persistence step stops submission. Opening a session only loads saved state;
it does not retry. New SQL refuses to replace unresolved work.

After a disconnect that preserves saved work, reconnect with the same configuration
and use `.resume`.
It reconciles the original signed request and upload, waits for completion and
rereads the result from its beginning. It never creates a new query as a retry.
This can repeat rows already displayed before the interruption. `.resume ID`
selects an existing query only when the session has no unresolved work. Native
reads and cancellation retain current authorization, including after source
binding changes. Previously emitted output cannot be recalled after revocation.

One session retains one 16 KiB bundle, one signed request and one result cursor.
SQL and TTY drafts are at most 4096 UTF-8 bytes; script input is streamed.
Dot command lines are limited to 64 KiB. TTY history holds at most eight
4096-byte statements and one undo draft. Completion retains at most eight
candidates, one current read and one result. Each result page uses a fixed 1 MiB
presentation buffer released after writing. There is no background query queue.

Waiting for query completion checks a five-minute budget between native operations. Each upload
advance has its own 30-second deadline and at most 132 steps; a current native
operation may settle after the outer budget expires. Transport attempts use
`request_timeout_ms`. Completed results stream under the finite result-page limits and per-request
deadlines; the completion-wait budget does not cut off their presentation.
Output writes have a two-second deadline and join on failure. Timeout preserves the saved query for `.resume`; none of these local
bounds expires accepted work or promises external cancellation.

The console proofs exercise Table, KV and Document workers with disk Ursula,
pipes, a controlling PTY and explicit TLS trust. Commands and executed outcomes
belong in the [proof ledger](../../../tests/README.md).

Small canonical Table mutations fit one direct writer command. Larger requests
use bounded upload, seal and apply commands. Each prepared send is saved before
submission; `.resume` reconciles the original bytes after an uncertain response.
`.cancel` first reconciles a pending send and cannot undo a committed direct
mutation. Saved requests and installations require the current shared definition;
a definition mismatch rejects before execution and never resets existing data.
