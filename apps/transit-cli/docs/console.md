# Transit console

`transit console` opens an independent SQL session in the server's shared SQL
runtime. Multiple consoles, PostgreSQL connections and MySQL connections share
account coordination and current authorization. SQL compilation, snapshots,
query execution and accepted-operation recovery belong to the service. The
console renders results and owns terminal preferences and history.

```sh
transit server
# In one or more other terminals in the same working directory:
transit console
transit console -c 'SELECT COUNT(*) FROM items'
transit console --format json -f queries.sql
```

Automatic local discovery uses the installation **path**, resolved from the
server settings convention, to select a nonsecret rendezvous record in
`$XDG_RUNTIME_DIR/transit` or `/tmp/transit-<uid>`. The console does not read
`installation.json`, signing seeds or a recovery file. The private Unix socket
checks the peer UID and maps it to the once-provisioned `local` account. Only
the service holds its ownership lock. The server must already be ready.

For remote access, configure the server's native HTTP/TLS listener and use a
connection file. PostgreSQL and MySQL listeners are independently optional.
See [SQL placement](sql.md) and the [session contract](../../../contracts/SQL_SESSION_V1.md).

## Configuration and trust

Connection files use YAML; explicit `.json` files are also accepted. Unknown
and duplicate fields reject. Paths resolve relative to the connection file.
An example remote connection is:

```yaml
version: 1
endpoint: https://database.example:19109
account: developer
database: transit
authentication: scram
password_file: ./sql-password
ca_file: ./database-ca.pem
request_timeout_ms: 30000
format: table
display_rows: null
```

```sh
transit console --config connection.yaml
```

Omit `ca_file` to use system roots. HTTPS verifies the peer; redirects are
refused. Passwords stay in referenced files and the SCRAM exchange does not send
the password. An explicit `http://127.0.0.1:PORT` endpoint requires
`authentication: trust` and a server configured for loopback trust. Unix
endpoints have the form `unix:/absolute/path` and require `authentication: peer`.
Trust selection does not grant database permissions. Client files contain no
kernel principal, worker, catalog, signing seed or recovery path.

`source: NAME` selects a service-configured KV, Document or Table source binding.
The service checks the account, database, source caller and current source
policy. See [source declarations](../../../packages/zig/transit-sql/docs/sources.md).
Catalog and configured-source SELECT use interactive snapshots. There is no
console execution-mode setting. Captured queries remain a native service API
capability, separate from the console's SQL session workflow.

## Startup preferences

The console merges settings in this order; later assignments win:

1. `/etc/transit/transitrc`
2. `~/.transitrc`
3. `./.transitrc`

Missing files are skipped; an unreadable or invalid file stops startup. Each file
is at most 64 KiB. Blank lines and `#` comment lines are ignored. Only `.mode`,
`.timer` and `.connect` settings are accepted; SQL cannot run at startup.
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
selected file; accepted operations remain owned by the service. It is not available in batch
input. Without a connection override, run the console in the server working
directory with the same topology configuration and environment. A missing or stale rendezvous record stops startup; the console does not initialize a server. A selected connection file supplies an endpoint and SQL authentication references and does not depend on a local installation.

## Host settings and reload

`SHOW ALL`, `SHOW ports.gateway` and `transit_settings()` inspect the connected
server. `SELECT transit_reload_conf()` validates and reloads its pinned source
with its captured startup environment. The service records the original reload
identity. The console waits for that request and reports its outcome without
reading a newly changed file as a replacement request. A partial application is reported
as partial, never as success. Configuration operations cannot be cancelled.

`SET query.statement_timeout = '5s'`, `RESET query.statement_timeout` and
`RESET ALL` affect only this session within its captured administrator ceiling.
See [configuration](../../../docs/handbook/reference/configuration.md) and
[settings SQL](../../../docs/handbook/reference/sql/settings.md).

## Typed query parameters

Use `--parameters FILE` with `-c SQL`, or `.execute FILE` with a JSON query object:

```json
{"sql":"SELECT * FROM items LIMIT $1","parameters":[{"unsigned":"3"}]}
```

The parameter-only file contains the array. Values use the
[exact scalar codec](../../../contracts/SQL_PARAMETERS_V1.md): integers are decimal
strings, binary and floating-point bits retain their canonical encodings. Values
are bound to the prepared type; they are never text substitution. The service
prepares against currently authorized metadata, validates before execution, and
rejects changed schemas. Up to 65 scalar bindings and 131072 input-file bytes
are accepted. Source bindings currently require non-null scalar parameters.
Changing or deleting an input file cannot change already accepted work.
Executing the SQL again requests new work.

## Finite relational queries

The selected catalog admits a bounded INNER/LEFT equijoin over two Tables or a
grouped single-Table query. Referenced columns use BIGINT/INT64. Projection,
COUNT and ordered checked int64 SUM follow the
[relational query profile](../../../docs/handbook/reference/queries.md). Resource cuts are
an explicit vector of independent retained Table snapshots. Repeated aliases
share one Table pin; separate Tables have no common atomic frontier.
Current rights apply to every dependency, including empty inputs. The service
owns private spill and bounded execution; closing a read releases its resources.
Parameterized relational SQL, additional joins and captured relational resumption
are outside this profile.

## Writing Tables and catalogs

The selected account/database maps to a service-owned catalog. CREATE, ALTER,
DROP, INSERT, UPDATE and DELETE use that catalog under their separate current
rights; clients do not enable writes by adding a file path. `.tables`,
`SHOW TABLES`, `DESCRIBE name` and `.schema name` inspect current authorized metadata.
EXPLAIN prepares a plan from metadata and executes no rows or snapshot scan.

```sql
CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200) NOT NULL);
INSERT INTO people (id, name) VALUES (1, 'Ada');
SELECT * FROM people;
UPDATE people SET name = 'Ada Lovelace' WHERE id = 1;
ALTER TABLE people ADD COLUMN email VARCHAR(320);
DELETE FROM people WHERE id = 1;
DROP TABLE people;
```

Schemas support up to 128 named logical columns. INTEGER means int32; BIGINT
means int64. VARCHAR limits Unicode scalars. Wide integers, decimals, temporal
values and nested types retain the [Table schema contract](../../../contracts/TABLE_SCHEMA_V1.md).
INSERT accepts 1–1024 literal rows within its statement and intent budgets.
Multi-row publication is atomic. Matched and changed counts come from the owner.
The [DDL](../../../contracts/TABLE_DDL_V1.md) and
[DML](../../../contracts/TABLE_DML_V1.md) contracts define the admitted operations.
Transactions, COPY and continuous queries are not session capabilities.

## Input, commands and results

Interactive SQL submits on Enter after a semicolon outside literals and nested
comments. Paste stays in the draft until Enter. `-c SQL` executes one statement;
`-f FILE` and redirected stdin execute streaming scripts. Batch input stops at
the first error. Dot commands occupy their own line. Prompts, timing and errors
use stderr; SQL results use stdout.

`--format table|json` and `.mode table|json` select SQL result presentation.
Errors remain human-readable on stderr.

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

The console reports statement completion and authoritative matched/changed
counts. Accepted statements emit a JSON `completion` object with `outcome`,
`matched`, `changed` and `pending_restart`; direct session completions retain
`kind`, `matched` and `changed`. No operation token or workflow phase is printed.
Rejected, cancelled, partial and unconfirmed outcomes are errors, not successful
completion records. The current accepted-operation response has no SQL command
tag, so its human output uses “Statement completed” rather than guessing a
statement kind from SQL text.

After a lost write response, the shared client checks the original request
within a bounded deadline. It never submits the SQL again. A temporary authority
timeout during a status read continues observation within that same deadline.
If the original session expired, a separate authenticated observation session can check that
request against the same instance and account. This does not restore the user's
session or its settings; further SQL requires reconnection. A timeout, missing
observation or failed authorization cannot establish that a write failed.
Unconfirmed outcomes explicitly warn that running the statement again may apply
changes twice.

JSON emits a `sql_result_v1` header with schema and observation even for an empty
result, one typed `row` envelope at a time, then verified `complete_coverage`,
`rows` and `displayed_rows`. Counts and other 64-bit or wider integers are decimal
strings. Missing, null, type error, conflict and ordinary values remain distinct;
integer values and decimal coefficients remain exact. A missing final marker or
`complete_coverage: false` means the output is a prefix.

Table mode uses one header and fixed column widths across the entire result. It
samples at most 32 rows within 256 KiB, uses escaped cell previews with visible
truncation, and streams the remaining rows. Columns are at most 80 bytes wide.
The connection's optional `display_rows` is null by default, or a positive 32-bit
row limit. A limit closes the reader without draining it and prints incomplete
coverage, the displayed count and any already known result count separately. It
returns success for that intentional display choice. Only verified exhaustion
prints complete coverage; failure or interruption returns nonzero.

Command JSON contains `completion` with typed kind/outcome, applicable
`counts.matched`/`counts.changed` and original operation attribution. An unresolved
write instead contains `unresolved` with its original correlation; the human
console does not require a separate job workflow to obtain a statement outcome.
The shared client owns settlement, batching and cleanup. The console does not
accumulate the full result or treat a fetch batch as a separate table.

`.timer on` reports client-observed submission, waiting, fetching and rendering
time. It is not a server engine or pure network measurement. `.show` prints aligned
text preferences even in JSON mode.

## Terminal editing and history

Enter submits SQL ending in a semicolon or a dot command. Otherwise it inserts
a newline at the cursor. Continuation rows align with the first row's SQL:

```text
transit> SELECT *
    ...> FROM items;
```

Long lines wrap within the terminal width. A viewport keeps the cursor visible
in tall drafts. Up/Down moves between display rows before recalling history at
the first/last row; Ctrl-P/Ctrl-N recalls history from any row. Home/End and
Ctrl-A/Ctrl-E move to the draft boundaries. Ctrl-U deletes before the cursor.
Bracketed paste preserves newlines, normalizes CRLF and never submits.

| Key | Draft | Suggestions | History search |
| --- | --- | --- | --- |
| Tab | Request completion; insert a proven unique match | Accept selection | Accept match for editing |
| Enter | Submit or insert newline | Accept current selection; wait during refresh, or dismiss if no list is visible | Accept match for editing |
| Up/Down | Move rows, then browse history | Select previous/next item | Select older/newer match |
| Shift-Tab | Open suggestions without insertion | Select previous item | No action |
| Ctrl-R | Search using the current draft | Search using the current draft | Find older match |
| Esc | Leave draft unchanged | Dismiss suggestions | Restore original draft and cursor |
| Ctrl-C | Clear draft | Clear draft and suggestions | Clear search and original draft |
| Ctrl-G | Keep draft | Dismiss suggestions | Restore original draft and cursor |
| Ctrl-Z / Ctrl-_ | Undo | Undo and close suggestions | Undo query editing |

Ctrl-X then Ctrl-U also undoes. Ctrl-Space requests completion when the terminal
delivers NUL; Tab is the primary binding. The raw editor consumes Ctrl-Z rather
than suspending. External editors retain their own key bindings. A bare Esc is
recognized after 50 ms; started escape sequences have a 250 ms inter-byte budget.
Unknown/truncated control sequences do not clear the draft. Terminal or SSH
interception can prevent a shortcut from reaching Transit.

Completion uses production grammar and currently authorized metadata for the
statement around the cursor, including suffix sources and aliases. Static dot
commands, `.help`, `.mode` and `.timer` complete locally; `.schema` uses the
service. A list has at most eight candidates, displayed below the unchanged
prompt. The menu and selection stay stable while idle. Editing within the same
token filters the visible list immediately while fresh suggestions arrive in
the background; a selected candidate stays selected if it still matches.
Moving to another context hides unrelated candidates. PgUp/PgDn pages through the selected
candidate's full spelling and details when clipped. A limited result says so;
a single candidate inserts automatically only with complete matching coverage.
Tab keeps that insertion's validation quiet, without flashing a one-item menu.
Shift-Tab still opens suggestions for inspection. Typing into an open menu
filters candidates; insertion requires Tab or Enter.
No automatic semicolon or generated statement is added.

At the end of a fully typed, unambiguous grammar keyword, completion offers the
next token: `CREATE` followed by Tab becomes `CREATE TABLE`. Partial words still
complete in place: `CRE` becomes `CREATE`. A cursor inside a word replaces the
whole word, including its suffix. Quoted names remain identifier completions.

Acceptance inserts a missing separator between adjacent words, identifiers or
literal values: selecting `ALL` after `SHOW` produces `SHOW ALL`. Completing
`SH` to `SHOW` adds no trailing space. Existing spaces, tabs, newlines, quoting
and punctuation remain intact, including qualified names such as `i."id"`.
The cursor follows the candidate, before any separator added ahead of a suffix.
The candidate and its separators form one undoable edit and share the 4 KiB
statement limit.

Opening completion starts acquisition immediately and shows real suggestions
as soon as they arrive, with no loading placeholder or opening delay. Local
dot-command suggestions update immediately. Metadata acquisition has one active
request and one latest draft; background refresh waits for 75 ms of idle editing
and times out after one second (or the smaller connection timeout).
Typing, clearing and dismissing remain available during acquisition. Acceptance
rechecks the current source, profile, revisions and authorization through the
service while keeping an already displayed list visible. Tab/Enter during a refresh does not queue
an insertion. A changed basis refreshes the list without accepting a replacement.
Unsupported context, literal/comment context, no matches and unavailable
service have separate messages. Completion never samples row values or executes
SQL. Enter/Tab acceptance consumes that key; execution requires another Enter.

Ctrl-R seeds the history filter with the whole current draft, including multiline
content, and immediately previews the newest match. An empty draft opens an empty
filter. Further Ctrl-R presses find older matches using the same filter; Ctrl-U
clears the filter without changing the saved draft.
History search matches literal substrings with ASCII case folding and collapsed
whitespace runs, so a single-line query can match multiline SQL. Previews retain
original spelling and newlines. Navigation skips duplicate text. Esc or Ctrl-G
restores the saved draft and cursor, even after changing the filter. A filter
typed after entering search from an empty prompt is discarded on cancellation.
Tab or Enter accepts the selected history entry into the draft; Esc then leaves
that accepted text intact, and undo restores the prior draft. Ctrl-C clears the
search and original draft; undo restores the original, not an unaccepted preview.
Browsing history also preserves the original draft
when moving past the newest entry.

Undo retains at most 128 edit groups and 256 KiB of snapshot bytes shared by the
draft and search query. Typing/deletion runs group between boundaries; paste,
completion, accepted history and clearing are atomic edits. Old groups are
evicted when either budget is reached. Submission resets undo; access loss
clears protected drafts, undo, search and assistance. Undo is volatile and does
not change persisted command history.

Interactive submissions append to `$HOME/.transit_history` as owner-only JSON
lines under a short lock. Concurrent consoles preserve each other's entries.
History contains command text, not results, passwords or signed recovery records.
Batch input and unsubmitted drafts do not enter history. Reads scan bounded
blocks; invalid records are skipped. File failure warns and retains eight recent
commands in memory. Previously saved history and disclosed output cannot be
recalled after revocation.

### External editor

`.edit` opens the latest SQL statement from history in `$EDITOR`, including SQL
that failed. It skips dot commands and opens an empty file if there is no SQL
history. The command is interactive-only and accepts no arguments.

Set `EDITOR` to a program and optional arguments, for example `vi` or
`code --wait`. Single/double quotes and backslash escapes support arguments with
spaces; shell expansion and pipelines are not evaluated. An unset or empty
`EDITOR` reports an error. Editors must wait for the file to be closed before
their process exits. The console keeps its SQL session alive during editing.

Saving and closing submits the saved statement once, even if its contents are
unchanged. In Vim, `:q` without a save does nothing; `:wq` submits. Saving while
the editor remains open does not execute SQL. A failed editor, an empty saved
file or closing without saving submits nothing. Writes and atomic replacements
of the temporary SQL file count as saves; writes to swap or backup files do not.

The file contains one SQL statement, with an optional trailing semicolon, within
the existing 4096-byte terminal limit. Dot commands and invalid UTF-8/control
bytes reject. The console creates a private directory and file under `$TMPDIR`
(default `/tmp`) and removes them when editing ends. Edited SQL enters history
before execution, so failed edits remain available to the next `.edit`.
Execution uses current session settings and permissions and creates a new request
identity. Editing and submitting SQL is a new execution, including after an
uncertain outcome.

## SQL errors

The service reports SQLSTATE, an error code and structured compiler evidence when
available. Syntax and binding failures occur before admission. Compiler locations
use statement-relative byte offsets; details derive from the failing compilation,
without extra stored-value reads. Errors render this evidence as human-readable text on stderr.

Transport failure does not establish whether a write was accepted. The console
checks its original request internally and reports an unconfirmed outcome when
it cannot establish the result. Denial, changed credentials and changed server
identity do not authorize another execution.

## Session lifetime and bounds

Each connection retains 16 MiB of reusable formatting storage and a separate
256 KiB sample window. The window copies rows under an exclusive lease so later
fetches cannot overwrite sampled values; the lease ends after the initial table
rows are rendered. Formatting capacity includes unused space and allocator
overhead and is reused across statements. Exhaustion fails the current display
without claiming complete coverage. These reserves are separate from the shared
client's statement and transport storage; they do not increase native message,
batch or per-result limits. I/O workers and request task storage are admitted
once for the console lifetime.

A session is an expiring handle, not a durable operation. Each session has at
most 32 prepared statements and one active result cursor. Fetching the last batch
again returns that batch under current rights. Acknowledging it advances the
existing iterator; invalid sequencing closes the cursor. Session expiry or service
restart invalidates interactive cursors. Starting a new SELECT captures a new snapshot; a lost cursor is not reopened
automatically.

Native messages are limited to 4 MiB; batches carry at most 32 rows and 1 MiB of
canonical cells. SQL API input is at most 64 KiB; the console editor and source
compiler retain their 4096-byte statement bound. `request_timeout_ms` is
1–270000 ms. Uncertain initial submissions use the remaining request budget;
known accepted statements are observed for at most 270 seconds from submission.
Polling and reconnection do not reset those deadlines. Idle consoles renew their lease. Service account/session,
authentication, execution and operation quotas are explicit settings.

Ctrl-C requests interruption of the current statement and discards remaining
statements in the submitted draft. Read cancellation releases the active cursor.
For a write, the client requests cancellation of the original accepted request
where supported and checks whether completion won the race. A completed write
remains completed. Configuration reload cannot be cancelled. Cleanup waits at
most one second; a second Ctrl-C ends statement settlement immediately.
Unconfirmed cancellation reports an unknown outcome, never rollback. Batch
interruption stops subsequent input and exits 130. Partial row output has no
successful completion marker.
Output writes have a two-second deadline.
None of these limits expires accepted history. Executed verification and its
limits are recorded in the [proof ledger](../../../docs/history/qualification/README.md).
