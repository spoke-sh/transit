# Run Transit locally

This starts an isolated, application-capable local installation and queries an
empty Table. Use Linux x86_64 with Nix flakes enabled and this repository checked
out. The complete local bundle includes pinned Transit, Board, Ursula and MinIO;
Docker is not required for this path.

Run from the repository root. Choose unused ports 19101–19107 and a new
`.cache/docs-start` directory. Keep that directory to resume the installation.

## Build the local bundle

```sh
nix develop
mkdir -p .cache
nix build .#transit-local --out-link .cache/transit-local
```

This builds the current checkout with locked dependencies. Keep its Nix output
link while using the installation: startup requires the same artifact hashes.
Published versioned downloads and general Transit upgrades are not available; see
[deployment limits](../reference/deployment.md).

## Start with defaults

The local bundle supplies executable paths and default ports. With no
configuration file, the server uses `./.transit` for private state. Create a
working directory and deliberately initialize it:

```sh
mkdir .cache/docs-start
cd .cache/docs-start
../transit-local/bin/transit server --initialize
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

## Query from a second terminal

From the repository root:

```sh
cd .cache/docs-start
../transit-local/bin/transit console
```

In the console:

```text
.schema
SELECT COUNT(*) FROM items;
```

The initial Table has `id` and `value` int64 columns and no application rows.
The console assigns an identity, advances the upload and prints the verified
result: count zero. Enter `.quit` to disconnect. To run one query and exit:

```sh
../transit-local/bin/transit console -c 'SELECT COUNT(*) FROM items'
```

See the [console guide](../../apps/transit-cli/docs/console.md) for output and
recovery details, and the [SQL reference](../reference/sql.md) for admitted syntax.

## Stop and resume

Ctrl-C in the server terminal stops its owned children and preserves disk state.
In the server terminal, still in `.cache/docs-start`, resume with the same
configuration and artifacts:

```sh
../transit-local/bin/transit server
```

Do not add `--initialize` on restart. For a previously submitted query, use
`.resume`; it recovers the original query and prints its result.
If state or an artifact is missing, startup refuses to recreate its history.
Inspect the error and follow [server recovery](../../apps/transit-cli/docs/server.md#ownership-and-recovery).

Next, [install a separately compiled application](applications.md). Flight and
Board's query/operator workspaces require separate configuration.
