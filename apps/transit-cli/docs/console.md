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
execution: interactive
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
`execution: captured` submits finite source SELECT through the durable query
owner; it requires a selected source. Ordinary catalog SELECT uses interactive
snapshots. Settings and Table writes keep their respective owners in either mode.

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
selected file; accepted operations remain owned by the service. It is not available in batch
input. Without a connection override, run the console in the server working
directory with the same topology configuration and environment. A missing or stale rendezvous record stops startup; the console does not initialize a server. A selected connection file supplies an endpoint and SQL authentication references and does not depend on a local installation.

## Host settings and reload

`SHOW ALL`, `SHOW ports.gateway` and `transit_settings()` inspect the connected
server. `SELECT transit_reload_conf()` validates and reloads its pinned source
with its captured startup environment. The service records the original reload
identity. Reconnection and `.resume` observe or continue that identity without
reading a newly changed file as a new request. A partial application is reported
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
Captured execution freezes the bound bundle; changing or deleting the input
file cannot change accepted work. Use `.resume` for recovery; executing SQL again
requests new work.

## Finite relational queries

The selected catalog admits a bounded INNER/LEFT equijoin over two Tables or a
grouped single-Table query. Referenced columns use BIGINT/INT64. Projection,
COUNT and ordered checked int64 SUM follow the
[relational query profile](../../../docs/handbook/reference/queries.md). Resource cuts are
an explicit per-resource snapshot vector, not an atomic cross-resource snapshot.
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
| `.help [SQL\|SETTINGS\|INSERT\|UPDATE\|DELETE\|CREATE TABLE\|ALTER TABLE\|DROP TABLE]` | Offline syntax help |
| `.tables`, `.schema [NAME]` | Table inventory or named schema |
| `.sources`, `.info` | Current account/database and authorized source bindings |
| `.mode table\|json`, `.timer on\|off`, `.show` | Presentation preferences and their origins |
| `.execute FILE` | Execute a typed query object |
| `.edit` | Edit the latest SQL in `$EDITOR`; save and close to submit |
| `.connect PATH` | Open a new independent connection in a terminal |
| `.status [all\|KIND:ID\|token:HEX]` | Observe current authorized retained operations |
| `.resume [KIND:ID\|token:HEX]` | Reconcile the original accepted operation |
| `.cancel [KIND:ID\|token:HEX]` | Request cancellation through its owner |
| `.quit`, EOF | Close this session |

`KIND` is `table`, `configuration` or `captured`. A bare numeric ID selects a
Table operation. Without an argument, controls use the last observed identity;
`.status` in a fresh console lists the account's authorized operations in bounded
pages. It does not submit work. A captured operation can be observed from another
session; fetching its result requires selecting its original source binding.

JSON emits a `sql_session_v1` schema header even for an empty result, one typed
`row` envelope at a time, then a final `complete_coverage` record with exact row
count and source basis. Missing, null, type error, conflict and ordinary values
remain distinct. Integers and decimal coefficients remain exact. Only the final
marker proves complete coverage; interruption leaves an incomplete prefix.
Table mode uses escaped, bounded cell previews. The console releases each batch
before fetching the next and never accumulates an entire result.

`.timer on` reports client-observed submission, waiting, fetching and rendering
time. It is not a server engine or pure network measurement. `.show` prints aligned
text preferences even in JSON mode.

## Terminal editing and history

The editor supports cursor movement, Home/End, deletion, Ctrl-U, undo, multiline
input and bracketed paste. Ctrl-C clears an unsubmitted draft. Up/Down recalls
commands. Ctrl-R searches history; Enter accepts a match for editing and does
not execute it. Completion requests authorized metadata from the service;
acceptance checks that the draft and source basis still match. Typing, history
search and completion do not submit SQL or apply administrative changes.

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
token. Use `.resume` with the original identity to recover accepted work.

## SQL errors

The service reports SQLSTATE, an error code and structured compiler evidence when
available. Syntax and binding failures occur before admission. Compiler locations
use statement-relative byte offsets; details derive from the failing compilation,
without extra stored-value reads. Errors render this evidence as human-readable text on stderr.

Transport failure does not establish whether a write was accepted. The console
prints its original request token on uncertainty. Inspect that token or list
operations after reconnecting; repeating the SQL allocates a new token and can
create new work. Denial, changed credentials and changed definitions remain
separate from transient availability failures.

## Exact recovery and bounds

The service durably binds each admission token to instance, account, database,
source, SQL, typed parameters and execution mode. Reusing a token with different
input rejects. Repeating the same accepted request finds its original operation
before compilation. Table intents, configuration requests and captured query
bundles remain with their respective durable owners. Recovery reuses published
signed steps; it never reconstructs accepted work from SQL.

A session is an expiring handle, not a durable operation. Each session has at
most 32 prepared statements and one active result cursor. Fetching the last batch
again returns that batch under current rights. Acknowledging it advances the
existing iterator; invalid sequencing closes the cursor. Session expiry or service
restart invalidates interactive cursors. Open a new session to inspect accepted
operations; starting a new SELECT captures a new snapshot.

Native messages are limited to 4 MiB; batches carry at most 32 rows and 1 MiB of
canonical cells. SQL API input is at most 64 KiB; the console editor and source
compiler retain their 4096-byte statement bound. `request_timeout_ms` is
1–270000 ms. Idle consoles renew their lease. Service account/session,
authentication, execution and operation quotas are explicit settings.

Ctrl-C stops the current wait and asks the service to stop its active read.
Accepted mutations survive connection loss; `.cancel` explicitly addresses the
original operation. Cancellation does not undo published data or revoke output
already displayed. Captured results can be read again after reconnecting, which
can repeat previously displayed rows. Output writes have a two-second deadline.
None of these limits expires accepted history. Executed verification and its
limits are recorded in the [proof ledger](../../../tests/README.md).
