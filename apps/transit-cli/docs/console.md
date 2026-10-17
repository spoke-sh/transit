# Transit console

`transit console` executes finite reads over catalog-routed general Tables or a
separately configured source. An interactive SELECT compiles SQL, acquires a
fresh leased snapshot and executes Fuze in the client. General Tables return
logical typed rows; the separate source profile returns verified Arrow batches.
Completion or cancellation releases the snapshot. An interactive SELECT writes
no durable query upload, execution progress or result publication.

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
authorized general Table catalog with an empty `items` Table. CREATE, ALTER,
DROP, INSERT, UPDATE, DELETE and SELECT use that catalog automatically.
The default endpoint is `http://127.0.0.1:19105`, and the
default installation is `./.transit`. The console never initializes the server.

```sh
transit console
transit console -c 'SELECT COUNT(*) FROM items'
transit console --format json -f queries.sql
```

## Host settings and reload

Use `SHOW ALL`, `SHOW ports.gateway` and the typed `transit_settings()` relation
to inspect the connected host. `SELECT transit_reload_conf()` validates and
reloads the pinned configuration source. Existing `.status` and `.resume` inspect
or reconcile its saved identity. `SET query.statement_timeout = '5s'` and
`RESET ALL` control this session within the captured administrator ceiling.
See [configuration](../../../docs/reference/configuration.md) and
[settings SQL](../../../docs/reference/sql/settings.md) for exact behavior.

Automatic local connections receive the installation's management binding and
recorded active endpoint. An explicit connection can supply `settings` with a
`binding` (`realm`, installation bytes and domain `object`) and private
`recovery_file`. It uses the same native caller/selected role as the catalog.
No management binding or grant is inferred from an arbitrary remote URL.
`.show` continues to describe local connection and presentation preferences.

## Startup preferences

The console merges settings in this order; later assignments win:

1. `/etc/transit/transitrc`
2. `~/.transitrc`
3. `./.transitrc`

Missing files are skipped; an unreadable or invalid file stops startup. Each file
is at most 64 KiB. Blank lines and `#` comment lines are ignored. Only `.mode`,
`.timer` and `.connect` settings are accepted; SQL and recovery operations cannot run at startup.
For example, a project `.transitrc` can contain:

```text
.mode table
.timer on
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

## Typed query parameters

Use `--parameters FILE` with `-c SQL` to bind one finite SELECT. For example,
save this scalar array as `parameters.json`:

```json
[{"unsigned":"3"}]
```

```sh
transit console --parameters parameters.json -c 'SELECT * FROM items LIMIT $1;'
```

In a terminal or script, `.execute query.json` runs one query object:

```json
{"sql":"SELECT * FROM items LIMIT $1","parameters":[{"unsigned":"3"}]}
```

The same file command works in either console execution mode. It executes a
finite query through the configured source, never a write or administrative
route. The flag requires `-c`; it cannot combine with `-f`. A script may contain
separate `.execute FILE` lines. Paths resolve against the working directory;
quoted dot-command paths support spaces. Startup rc files do not execute them.

Bindings use the [exact scalar codec](../../../contracts/SQL_PARAMETERS_V1.md):
wide integers are decimal strings, binary bytes and float bits use their existing
hex encodings, and scalar types are never coerced. The input file is at most
131072 bytes, SQL is at most 4096 bytes, and at most 65 exact scalar values bind the Boolean predicate and LIMIT grammar sites. Omitting `parameters` or using null in a query
object selects ordinary SQL; `[]` selects a template without placeholders.
The `--parameters` file must always contain an array. Named SQL
`PREPARE`/`EXECUTE` and parameters for captured file sources remain unsupported.

Template errors identify the parameter index and its original SQL use sites.
Conflicting repeated uses report both required types; a binding count mismatch
reports expected and supplied counts. Type and scalar-encoding failures include
the expected type and the exact supplied scalar. Integer widths remain exact;
decimal previews identify the coefficient and temporal previews name their
physical units. Text/binary previews show at most 32 bytes, escaped for terminal
safety with explicit truncation. These details come from the failing compilation and do not read stored
values. SQL locations use one-based lines and byte columns.

Values are owned for the current execution and are never SQL text substitution
or session defaults. Dot-command history records the file command, not its
contents. Compilation checks current source permission and budgets; execution
checks them independently. Durable recovery uses the saved ordinary bundle and
original signed command even if the input file changes or disappears. Use
`.resume` for uncertain saved work; `.execute` requests a new compilation.

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
profile: "catalog_v1"
url: "http://127.0.0.1:8301"
transport: "loopback"
seed_file: "caller.key"
catalog:
  scope:
    realm: 42
    resource: 7
    catalog: 1
  owner: 1
  principal: 1234
table_limits:
  requests: 10000
  rows: 10000
  result_bytes: 16777216
request_timeout_ms: 5000
format: "table"
execution: "interactive"
```

The example is a configuration shape, not allocated identities or a grant.
Use the actual provisioned catalog IDs. Omitting `writes` creates a read-only
console configuration: SELECT, EXPLAIN, discovery and assistance use the catalog
without a write recovery file. Current permissions still decide each operation.
The catalog profile does not accept fixed `connection`/`workspace` fields or a
durable query `recovery_file`. Separately configured KV and Document queries use
`profile: unified_v1` with `connection` and `workspace` as described in the
[unified source guide](unified-query.md); those fields cannot be mixed with a
catalog route.
The timeout defaults to 5000 ms and must be 1–60000 ms.

`loopback` accepts literal `127.0.0.1` or `::1` HTTP endpoints. Remote connections
must select `tls_system` (HTTPS with system roots) or `tls_ca` (HTTPS with an
explicit `ca_file`). The latter uses only that trust bundle. Endpoint credentials,
query strings, fragments and path prefixes are rejected. The existing native
client verifies the peer and never follows redirects with signed requests.
Neither transport selection nor configuration grants native access.

## Finite relational queries

The catalog console runs one INNER/LEFT equijoin over two Tables, or groups a
single Table, through the shared Fuze relational plan. Referenced columns must
be BIGINT (int64); INTEGER is int32. Projection, COUNT(*), COUNT(column) and
ordered checked int64 SUM can be combined, with non-aggregate outputs listed
in GROUP BY. WHERE applies after the join. Output aliases must be distinct.

Enable this profile explicitly in the catalog connection:

```yaml
relational:
  consistency: per_resource_snapshot_vector
  budgets:
    resident_bytes: 16777216
    spill_bytes: 16777216
    result_bytes: 8388608
    output_rows: 1000
    work_steps: 100000
    source_pins: 2
  requests: 100000
  spill_work: 100000
```

Both SQL names resolve in the configured catalog. Their resource cut is shared;
the underlying Zig caller also accepts two explicit catalog routes in one realm.
Different resource cuts are independent, not an atomic or causal snapshot.
Every dependency requires current rights even when it contributes no rows.

```sql
SELECT l.category, COUNT(*) AS matches, SUM(r.amount) AS total
FROM orders AS l LEFT JOIN payments AS r ON l.id = r.order_id
GROUP BY l.category;
```

The Tables and columns in this example must already exist with BIGINT types.
`EXPLAIN` reports the proposed ordered scan/join and disk grouping using current
authorized metadata only. It opens no snapshot or spill, returns a null execution
basis, and rejects a metadata revision change during preparation. A later SELECT
captures its own basis. Private execution spill uses TMPDIR (otherwise `/tmp`), private file modes
and immediate unlinking. The operating system releases it on close or process
termination. Exhausted work/disk/memory/result limits fail explicitly and leave
any emitted prefix incomplete. JSON uses `relational_snapshot_v1`, prepared and
bound fingerprints, and a final `complete_coverage` record. The profile excludes
LIMIT, HAVING, arbitrary ORDER BY, DISTINCT, parameterized SQL, additional joins
and durable resumption. Existing single-source SELECT keeps its own profile.

## Writing Tables and catalogs

The catalog connection routes CREATE, ALTER, DROP, INSERT, UPDATE, DELETE and
interactive SELECT by Table name. Tables created in that catalog are immediately
available to the same console under current permissions. No per-Table writer or
query configuration is required. `.tables`, `SHOW TABLES`, `.schema` and `.sources`
list current catalog names; `DESCRIBE name` and `.schema name` inspect an actual
schema. Listings hold one bounded page at a time and reject changed revisions.

Use `.help CREATE TABLE`, `.help ALTER TABLE`, `.help DROP TABLE`, `.help INSERT`,
`.help UPDATE` and `.help DELETE` for offline syntax help. A configured route does
not grant access: native grants and separate catalog inspect/create/read/insert/
update/delete/alter/drop policies apply when each operation runs.

Enable writes on that same catalog connection with:

```yaml
writes:
  recovery_file: "console-writes.json"
```

The catalog principal must match the signing credential. Paths resolve relative
to the connection file. One credential lock serializes local write-capable
consoles. `.info` reads current catalog configuration and policy; it does not
report a fixed Table schema as the catalog's scope.

Completion obtains fresh authorized metadata and uses the general Table parsers
for syntax and typed continuations. It supports 255-byte names and escapes quoted
identifiers. Source search retains one catalog page and returns at most eight
suggestions after at most 128 pages; narrow the prefix when the bounded search
has no matching item. Metadata can change while editing: the console reacquires
and validates the suggestion before inserting it. A changed revision or revoked
inspection permission discards the suggestion; completion never applies SQL.
For relational SQL in the configured catalog, completion resolves both Table
aliases and offers only int64 columns. An unqualified position inserts a quoted
alias and column; a qualified position completes only that alias. Ambiguous
predicate names do not receive guessed operators. JOIN, GROUP BY and aggregate
highlighting comes from the same parser used for execution. These suggestions
do not enable a relational connection or execute the draft.

```sql
CREATE TABLE people (
    id INTEGER PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    active BOOLEAN DEFAULT TRUE,
    salary DECIMAL(18, 2)
);
INSERT INTO people (id, name, salary) VALUES (1, 'Ada', 125000.00);
SELECT id, name, salary FROM people;
UPDATE people SET name = 'Ada Lovelace' WHERE id = 1;
ALTER TABLE people ADD COLUMN email VARCHAR(320);
ALTER TABLE people RENAME COLUMN name TO full_name;
DELETE FROM people WHERE id = 1;
DROP TABLE people;
```

Schemas admit up to 128 named columns and the logical types defined by the
[Table schema contract](../../../contracts/TABLE_SCHEMA_V1.md). Omitted
nullability means nullable; a declared primary key implies NOT NULL. Without a
primary key, internal stable row identities preserve duplicate rows. INTEGER is
int32; INT64 and BIGINT are int64. VARCHAR(n) counts Unicode scalars. Decimal and
temporal parameters, nested constructors and valid key types have explicit
contracts; unsupported aliases and constraints reject before submission.

INSERT accepts 1–1024 literal rows, ordered or named columns, omitted defaults,
DEFAULT and NULL within the SQL/intent budgets. UPDATE uses typed constant or
DEFAULT assignments. UPDATE and DELETE use the selected finite predicate grammar;
an exact primary-key predicate takes the point path. Multi-row statements publish
atomically. Matched and changed counts come from the committed result, including
zero matches and unchanged updates. ALTER supports the selected rename, column,
default, nullability and exact-conversion operations. DROP uses RESTRICT and
retains original recovery evidence. See the [DDL](../../../contracts/TABLE_DDL_V1.md)
and [DML](../../../contracts/TABLE_DML_V1.md) contracts for exact bounds.

General Table SELECT currently uses `execution: interactive` and typed SQL
constants. Parameterized and durable query execution use their separately
qualified source profiles. EXPLAIN captures and releases a schema-bound snapshot,
compiles the proposed plan and executes no rows. A later SELECT captures its own
basis. Text results format logical values directly; neutral JSON preserves exact
types, wide integers, decimal coefficients, temporal values and nested cells.
JSON emits a `table_snapshot_v1` schema header, incomplete row envelopes and a
final completion envelope with source/plan commitments and exact row counters.
Every preceding row remains an incomplete prefix if execution fails.

Before any send, the console saves immutable canonical intent in a private
`.intent-<digest>` file beside the recovery JSON. The JSON is at most 32 KiB and
contains only the original identity, intent commitment and exact signed progress;
large request bodies are not rewritten at every upload step. Both file and parent
directory are synchronized. Opening recovery checks exact bytes, current contract
definition, key, scope and signed-command binding before any transport operation.
Missing or incompatible fields reject; orphan intent files are never adopted.
Keep these files private: the intent contains original caller-supplied values.

A native receipt proves admission only. The console observes processing and the
original terminal outcome before reporting success. JSON uses `table_operation`
with decimal-string operation/object identities and matched/changed counts, plus
separate outcome and input diagnostics. A rejected continuation never replaces an
already accepted operation's result.

Current read/preparation failures retry temporary unavailability after 50 ms and
an explicitly identified stale resource revision after 1 ms, under one five-minute
deadline. Captured query reads, submission and persistence are outside this loop.
Other conflicts, denial and malformed replies stop. Submission is attempted once;
a failed send preserves the exact prepared identity for explicit reconciliation.

Opening recovery never resubmits. `.status` observes under current rights without
preparing or sending commands. `.resume` reconciles the original signed request
and continues its saved operation. `.cancel` first reconciles uncertain input,
then requests cancellation of that operation or upload. Applied work stays
applied. Ctrl-C and disconnecting stop the caller without undoing accepted work.
Recovery commands refer to the saved write until another completed command
replaces it. Never repeat SQL after uncertainty: that creates a different operation.
Unresolved work blocks new writes, reads and connection switching; inspection and
help remain available. Persistence failure stops before any successor send.

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
Submitted SQL and dot commands retain their syntax highlighting in terminal
scrollback above their results, with continuation prompts for multiline input.
The transcript uses stderr so redirected stdout contains results only. An
unfinished multiline draft uses a continuation prompt until its terminating
semicolon.
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
| `.help [SQL\|INSERT\|UPDATE\|DELETE\|CREATE TABLE\|ALTER TABLE\|DROP TABLE]` | Offline SQL help, route configuration and commands |
| `.tables` | Catalog tables when configured, otherwise the query source |
| `.sources`, `.schema` | Current catalog names, or the separately configured query source |
| `.schema NAME` | Current catalog Table schema; `.schema writer` lists the catalog |
| `.mode table\|json` | Result presentation |
| `.timer on\|off` | Set query wall-time reporting (off by default) |
| `.show` | Aligned text showing effective console settings and origins |
| `.connect PATH` | Switch connection in an interactive session |
| `.status`, `.info` | Saved write/query status, or query result evidence |
| `.resume [ID]` | Recover the saved write; in durable query mode, recover the saved query or selected query ID |
| `.cancel` | Reconcile saved input and request cancellation of a pending Table operation/upload or durable query |
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

Table mode is the default. General Table cells use logical types with an explicit
`... [truncated]` marker after the 256-byte preview budget; JSON retains their
complete typed representation. General Table output streams through a 16 KiB
buffer; escaping and repeated projections do not impose another fixed row-size
limit. The query's explicit result budget still applies to canonical typed bytes.
An interrupted or failed write can leave an incomplete JSON line; only the
verified final marker establishes completion. The separate query-source profile renders its
verified Arrow batch directly, with
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

`.timer on` reports monotonic elapsed milliseconds to stderr after each SQL or
`.resume` attempt, including failed attempts. The timing line is the final output
for the command, after results, errors, recovery guidance and cancellation messages,
before the next prompt. Measurements finish before diagnostic presentation.
The total includes preparation,
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
`submit` measures native send acknowledgements. Table mutation completion uses
bounded authorized notification waits instead of fixed sleeps after pending
results. Wait capacity exhaustion falls back to ordinary reads with bounded
backoff; unavailable observations retain their original deadline and saved
command. `wait` includes processed-input
observations and polling sleeps; `fetch` reads rejection and terminal outcome
records. `persist` includes every atomic recovery-file replacement and file/directory
sync throughout the operation, and `render` writes the final presentation.
An admission acknowledgement alone is not a completed mutation. These phases
partition client wall time; worker and storage work can occur during several of them.
Sub-millisecond work can display as zero. Timing does not change JSON stdout or
query recovery, and `.timer off` disables it. Missing, invalid or extra arguments
print `Usage: .timer on|off` to stderr without changing the setting. Interactive
input returns to the prompt; batch input stops with exit status 1. Use `.show` to
inspect the current setting. Interactive connection changes
retain the current mode and timing preference.

The Linux terminal supports Left/Right, Home/End (also Ctrl-A/Ctrl-E), Backspace,
Delete, Ctrl-U, command history with Up/Down, and Ctrl-C draft clearing.
Ctrl-R opens reverse history search. Type a case-sensitive substring to find the
newest matching SQL statement or dot command; Ctrl-R again finds an older match.
Backspace edits the search. Enter or Tab returns a match to the editable prompt;
press Enter again to submit it. Escape or Ctrl-G restores the original draft,
and Ctrl-C clears the draft and search without waiting for another keystroke,
including when the terminal discards pending input. A search with no match shows `(no match)`.
Up/Down also recalls older/newer commands and restores the draft when moving
past the newest entry.

Interactive submissions, including dot commands and commands that fail, are
appended immediately to `$HOME/.transit_history`. The console creates the file
with owner-only permissions (`0600`) and preserves multiline SQL and Unicode as
one JSON string per line. History is shared across connections and console
restarts. Concurrent consoles append under a short file lock without replacing
each other's entries. Blank input, unsubmitted drafts, startup files and batch
input do not enter history. The file contains command text and arguments, not
query results or signed recovery records; recalling a command does not retry
accepted work. Use `.resume` for exact saved recovery.

History is not automatically truncated. Reads scan bounded blocks on disk, so
older entries remain searchable without loading the whole file into memory.
Malformed, oversized, control-bearing or incomplete records are skipped without
rewriting the file. If the home directory or writable regular history file is
unavailable, or an append fails (including a busy lock), the console warns on
stderr and keeps the most recent eight session commands in memory. Appends wait
up to 250 ms for another console's lock. Symlinks are
not followed. Remove or edit the file while consoles are closed to clear saved
history.

The horizontally scrolling, highlighted draft renders newline, Unicode
and control bytes as visible escapes; the underlying SQL remains unchanged.
SQL keywords, aggregate functions and type names use cyan. Unquoted names and
double-quoted identifiers use the terminal's default foreground, including
table names, columns, qualifiers and aliases. Classification follows the
production parser: `value` is plain in `SELECT value FROM items` and cyan after
`IS` in `WHERE value IS VALUE`. The same distinction applies to contextual
words such as `UPDATE`, `EXPLAIN`, `UINT64` and `FLOAT64`. Single-quoted strings,
Boolean literals and literal `NULL` use green; numbers and `$n` parameters use
magenta; comments use dim text. Operators, punctuation and `*` stay plain.
Dot command names use cyan and their arguments stay plain.

Drafts, submitted SQL and diagnostic excerpts share these roles. Diagnostics
retain the original roles through redaction and clipping; masked bytes stay
plain. Each statement is classified locally within the 4,096-byte input bound,
without catalog access. Incomplete or malformed SQL keeps the roles established
before the error, then uses reserved-word and lexical colors for the remaining
text. Reference-only statement families use lexical colors. Highlighting does
not establish validity, name resolution or execution support.
Diagnostics emphasize the error label and identifier, category, location and
caret, and highlight SQL vocabulary and dot commands in corrective guidance.
Color uses stderr's terminal status independently of the result format; redirected
stderr stays plain. Set a nonempty `NO_COLOR` or `TERM=dumb` to disable color in
both drafts and output. All diagnostic text and coordinates remain available
without color, and timing stays after the complete diagnostic.
The display responds to terminal resize and restores the original terminal
attributes on normal and handled-signal exit.

Ctrl-Space opens shared [cursor assistance](../../../contracts/QUERY_ASSISTANCE_V1.md).
Up/Down chooses a candidate, Tab/Enter accepts it, Escape dismisses it and Ctrl-Z
undoes the acceptance. Acceptance rechecks current metadata. Input queued while
a metadata read waits discards the older response. An idle result expires after
five seconds. Observed denial clears draft, undo, recall/search history, completion
and result cursor for that connection; frozen recovery intent remains separate.
Previously saved local history and terminal output remain on the user's machine.
History grants no access; every submitted command checks current authorization.

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

Error guidance uses `.help SQL`, statement help such as `.help CREATE TABLE`,
and console inspection commands such as `.schema` and `.sources`. Console output
does not direct users to documentation pages or repository paths. Coordinates count
UTF-8 bytes, starting at one; script locations include the statement's absolute
file position and the number of previously completed commands. The caret follows the escaped
display. At most 120 source bytes around the failure are shown. Literal values,
quoted identifiers and comments are masked, including unfinished tokens. These
excerpts appear in local stderr diagnostics, not telemetry or result stdout.

Binding errors separately identify the failing source, column or qualifier and
its scope. Expected/supplied types and a bounded escaped caller-supplied value
explain type mismatches. Text and binary previews contain at most 32 bytes and
mark truncation. A derived-table error names the derived scope; the compiler
does not suggest inaccessible catalog names or reread stored values for detail.
`SHOW SOURCES`, `SHOW SINKS` and `SHOW CONNECTIONS` report their unsupported
execution route locally, even when the configured authority is unavailable.

The categories distinguish syntax errors, unsupported constructs, exceeded
bounds, source/type binding failures, grammar-only families and operations
unavailable on the query interface. Grammar-family recognition alone does not
validate the submitted syntax. `INSERT`, `UPDATE` and `DELETE` use an explicitly
authorized catalog configured in `catalog`. CREATE, ALTER and DROP use
the same catalog and their own current permissions. Missing
routes point to `.help INSERT` or `.help CREATE TABLE`; grammar-only forms are
identified without claiming executable support.

Failed compilation creates no query identity, acquires no query snapshot and
sends no mutation. Inspection and durable compilation can read current authorized
metadata. Runtime failures can follow admission or partial output; follow their
recovery guidance and retain the original saved identity. A syntax correction is
not a reason to replace unresolved durable work with a new request.

Use `transit --diagnostics=json console ...` for the shared diagnostic envelope
on stderr, independently of `--format table|json` result output. Terminal Table
rejections have no resume or cancel action. Duplicate keys identify their columns,
escaped values and original INSERT row or immutable source row identity. Failed
ALTER validation identifies the column, value and expected type. Execution value
previews contain at most 64 bytes with explicit truncation. Current catalog read
permission gates stored-row identity and value disclosure; denied facts are
marked `withheld`. Original INSERT input remains inspectable without that read
permission. Missing evidence is explicitly `unrecorded`; the console never
rereads a different Table to explain an earlier failure.

Rejected inputs retain their native input identity separately
from any overall mutation outcome. Unresolved saved writes identify the original
operation, preserve a validated native error category when available, and support
exact reconciliation. A 503 remains an uncertain outcome, including a capacity
response; the console does not automatically resend it.
The [CLI reference](../../../docs/reference/cli.md#structured-errors) specifies
source coordinates, timing records and stream boundaries.

General Table header errors retain their original SQL positions before any
catalog lookup. EXPLAIN diagnostics use positions in the complete EXPLAIN
statement, including its prefix and intervening comments or whitespace.

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
Dot command lines are limited to 64 KiB in batch input. TTY history scans one
4096-byte command at a time, with a 24 KiB encoded-record buffer and a 4 KiB read
buffer. The editor retains eight session commands for file-failure fallback,
one undo draft, one recall draft and one search term. Completion retains at most eight
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


Confirmed durable query failures show the saved query identity, stable
`query.<code>`, admission/execution stage and any measured page, segment or
result-byte limit. `.status` reads the same recorded evidence. Terminal rejection
and denial suggest correcting the problem before a new query; they do not offer
`.resume` as a way to change the saved result. JSON status retains the structured
`failure` object with exact decimal-string counters. An unresolved send still
requires recovery of its original signed intent.

Script source paths retain their byte identity. When a filesystem path is not
UTF-8, diagnostics mark it as an escaped byte path and encode nonprintable bytes
as `\xhh`; this does not prevent executing the readable script. Paths are
bounded to 512 displayed bytes with explicit truncation. Statement offsets and
byte-column coordinates continue to refer to the original SQL bytes.
