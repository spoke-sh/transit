# Run Transit locally

Start a local installation, define a task dataset, then inspect and change it
from independent SQL sessions. The server supplies the catalog and execution
services for this walkthrough. Use Linux x86_64 with `transit` available on
`PATH` in both terminals. This single executable includes the node, query host,
SQL gateway and Board with its frontend assets. Native storage runs inside the node;
no external storage service or Docker is required at runtime.
Check that the command is available:

```sh
transit --version
```

The [source installation guide](../../../nix/README.md#transit-cli-packages) covers
building and installing the bundle. Published versioned downloads and general
Transit upgrades are not available. Keep the installed bundle for the lifetime
of the installation: startup requires the same artifact hashes. See
[deployment limits](../reference/deployment.md).

Choose unused ports 19101–19108 and a new `.cache/docs-start` directory under
your working directory. Keep that directory to resume the installation.

## Start with defaults

The executable supplies its runtime roles and default ports. With no
configuration file, the server uses `./.transit` for private state. Create a
working directory and start the server; it initializes new state automatically:

```sh
mkdir -p .cache/docs-start
cd .cache/docs-start
transit server
```

Optional `transit.yaml` settings overlay these defaults. Discovery selects the
first file in the working directory, home directory or `/etc/transit`; see the
[configuration hierarchy](../../../apps/transit-cli/docs/server.md#defaults-and-configuration).
For this walkthrough, use the defaults and keep ports 19101–19108 available.

Wait for the readable `server.ready` and `board.ready` log events, then open the
Board endpoint shown (`http://127.0.0.1:19107` with defaults). Redirected or piped
stdout retains a JSON ready record for scripts; operational logs go to stderr.
Wait for SQL to report that listeners are accepting connections before opening
a console. Core readiness and SQL readiness are separate observations.
All listeners bind loopback; this is a trusted single-user
installation, not an OS sandbox. Credentials and data stay in the installation
directory. The [server guide](../../../apps/transit-cli/docs/server.md) explains
quotas, required free disk space and configuration compatibility.

Add `--no-ui` to run headlessly. This stops Board for that invocation while
preserving its identity and grants; restart without the flag to enable it again.
Board provides shared inspection only. Application resource access requires an
explicit [inspection declaration](../../../apps/transit-cli/docs/applications.md#board-inspection).

## Read and write from a second terminal

From the same parent working directory used above:

```sh
cd .cache/docs-start
transit console
```

## Define your data

Create a Table for tasks. The schema declares a unique task ID, a required title
and a completion flag whose default is false:

```sql
CREATE TABLE tasks (
    id BIGINT PRIMARY KEY,
    title TEXT NOT NULL,
    done BOOLEAN DEFAULT FALSE
);
SHOW TABLES;
DESCRIBE tasks;
```

The local connection has an authorized catalog and Table writer. `SHOW TABLES`
includes the new `tasks` Table alongside the supplied `items` Table. `DESCRIBE`
returns its published definition. Creation does not insert any task rows.
The [Table reference](../reference/tables.md) explains schemas, keys, defaults
and the distinction between a Table's identity and its name.

## Write rows and compute an answer

Omit `done` to use its declared default:

```sql
INSERT INTO tasks (id, title) VALUES
    (1, 'Review the data model'),
    (2, 'Explore query results');
SELECT id, title, done FROM tasks;
SELECT COUNT(*) FROM tasks WHERE done = FALSE;
```

The rows have `done = false` and the count is **2**. Each successful mutation
reports its applied outcome. Each SELECT reads a fresh snapshot; row order is
not specified by these queries. A complete result answers the query for that
snapshot. It does not establish an automatically maintained view.

## Observe a change from another session

Leave the first console open. In another terminal, enter the same
`.cache/docs-start` directory and open another `transit console`. In that session:

```sql
UPDATE tasks SET done = TRUE WHERE id = 1;
SELECT COUNT(*) FROM tasks WHERE done = FALSE;
```

The count is now **1**. Run that SELECT again in the first console: its new
snapshot also sees one unfinished task. The sessions have independent cursors;
the server owns mutation recovery. Neither console locks a client recovery file.

## Evolve the schema and inspect the result

Add a priority with a default for existing and future rows:

```sql
ALTER TABLE tasks ADD COLUMN priority BIGINT DEFAULT 1;
DESCRIBE tasks;
SELECT id, title, done, priority FROM tasks;
```

Both rows now have priority **1**. Transit validates and publishes the complete
schema/data successor before new reads see it. A reader already holding an older
snapshot retains its original schema and data until that read ends.
[ALTER TABLE](../reference/sql/alter-table.md) describes supported changes and
their failure behavior.

Enter `.quit` to disconnect. To inspect the data without an interactive console:

```sh
transit console -c 'SELECT COUNT(*) FROM tasks WHERE done = FALSE'
```

The answer is still **1**. Keep the dataset for the restart below. If you repeat
this tutorial in the same installation, inspect the existing Table before
creating or inserting again. Reissuing a statement creates a new operation;
an uncertain earlier write needs recovery, not repetition.

See the [console guide](../../../apps/transit-cli/docs/console.md) for output,
remote HTTP/TLS connections and recovery, and the [SQL reference](../reference/sql.md)
for admitted statements. Role and grant changes use the separate
[administration interface](../../../packages/zig/transit-client/docs/authorization.md).

## Stop and resume

Ctrl-C in the server terminal stops its owned children and preserves disk state.
In the server terminal, still in `.cache/docs-start`, resume with the same
configuration and artifacts:

```sh
transit server
```

The console checks an interrupted write's original outcome internally. If it
cannot confirm completion, it reports uncertainty; repeating SQL may apply the
change twice. Stopping the server does not undo accepted writes.
Interactive SELECT statements run again against a fresh snapshot.
If an existing installation contains missing state or a changed artifact,
startup refuses to recreate its history. Set `startup.require_existing: true`
to also refuse a completely missing or empty installation directory.
Inspect the error and follow [server recovery](../../../apps/transit-cli/docs/server.md#ownership-and-recovery).

Reconnect and run the final count again to observe the retained task data.
You have defined data, computed an answer, changed its schema and observed its
accepted state across sessions and a server restart.

Continue with the [data model](../reference/data-model.md) for computation
lifetimes, permissions, retention and progress. You can also
[connect with psql or mysql](../../../apps/transit-cli/docs/sql.md) to the same
authorized catalog. Database listeners are independently opt-in; default startup
opens neither SQL port. Flight requires its own configuration.

When your application needs custom transformation or coordination, follow
[build an application](applications.md) to install a separately compiled worker.
