# Run Transit locally

Start an isolated, application-capable local installation, then read and write
its Table. Use Linux x86_64 with the complete local bundle installed and
`transit` available on `PATH` in both terminals. The bundle includes matching
Transit, Board, the SQL gateway, Ursula and MinIO executables; Docker is not required at runtime.
Check that the command is available:

```sh
transit --version
```

The [source installation guide](../../nix/README.md#transit-cli-packages) covers
building and installing the bundle. Published versioned downloads and general
Transit upgrades are not available. Keep the installed bundle for the lifetime
of the installation: startup requires the same artifact hashes. See
[deployment limits](../reference/deployment.md).

Choose unused ports 19101–19107 and a new `.cache/docs-start` directory under
your working directory. Keep that directory to resume the installation.

## Start with defaults

The local bundle supplies executable paths and default ports. With no
configuration file, the server uses `./.transit` for private state. Create a
working directory and deliberately initialize it:

```sh
mkdir -p .cache/docs-start
cd .cache/docs-start
transit server --initialize
```

Optional `transit.yaml` settings overlay these defaults. Discovery selects the
first file in the working directory, home directory or `/etc/transit`; see the
[configuration hierarchy](../../apps/transit-cli/docs/server.md#defaults-and-configuration).
For this walkthrough, use the defaults and keep ports 19101–19107 available.

Wait for the JSON ready record. It names the installation,
`management_config` and `board_url`. Open `board_url` to inspect the installation.
All listeners bind loopback; this is a trusted single-user
installation, not an OS sandbox. Credentials and data stay in the installation
directory. The [server guide](../../apps/transit-cli/docs/server.md) explains
quotas, required free disk space and configuration compatibility.

Add `--no-ui` to run headlessly. This stops Board for that invocation while
preserving its identity and grants; restart without the flag to enable it again.
Board provides shared inspection only. Application resource access requires an
explicit [inspection declaration](../../apps/transit-cli/docs/applications.md#board-inspection).

## Read and write from a second terminal

From the same parent working directory used above:

```sh
cd .cache/docs-start
transit console
```

In the console:

```text
.schema
INSERT INTO items (id, value) VALUES (1, 100);
SELECT * FROM items;
UPDATE items SET value = 101 WHERE id = 1;
SELECT * FROM items;
DELETE FROM items WHERE id = 1;
SELECT COUNT(*) FROM items;
```

The initial Table has `id` and `value` int64 columns and no application rows.
The local connection includes an authorized Table writer. Each mutation prints
its applied row count; SELECT reads a fresh snapshot. The final count is zero
after deleting the row. Enter `.quit` to disconnect. To run one query and exit:

```sh
transit console -c 'SELECT COUNT(*) FROM items'
```

See the [console guide](../../apps/transit-cli/docs/console.md) for output and
recovery details, and the [SQL reference](../reference/sql.md) for admitted syntax.

## Stop and resume

Ctrl-C in the server terminal stops its owned children and preserves disk state.
In the server terminal, still in `.cache/docs-start`, resume with the same
configuration and artifacts:

```sh
transit server
```

Do not add `--initialize` on restart. After an interrupted write, use `.status`
and `.resume` to recover the original operation; repeating SQL creates new work.
Interactive SELECT statements run again against a fresh snapshot.
If state or an artifact is missing, startup refuses to recreate its history.
Inspect the error and follow [server recovery](../../apps/transit-cli/docs/server.md#ownership-and-recovery).

Next, [connect with psql or mysql](../../apps/transit-cli/docs/sql.md) or
[install a separately compiled application](applications.md). Database listeners
are independently opt-in; the default startup opens neither SQL port. Flight
requires its own configuration.
