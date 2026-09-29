# Run Transit locally

This starts an isolated, application-capable local installation and queries an
empty Table. Use Linux x86_64 with Nix flakes enabled and this repository checked
out. The complete local bundle includes pinned Transit, Ursula and MinIO;
Docker is not required for this path. Other platforms and public installers are
not qualified by this guide.

Run from the repository root. Choose unused ports 19101–19106 and a new
`.cache/docs-start` directory. Keep that directory to resume the installation.

## Build the local bundle

```sh
nix develop
mkdir -p .cache
nix build .#transit-local --out-link .cache/transit-local
```

This builds the current checkout with locked dependencies. Keep its Nix output
link while using the installation: startup requires the same artifact hashes.
Published versioned downloads and compatible Transit upgrades remain
[publication work](../internal/roadmap/M27.md).

## Create explicit configuration

The following writes configuration only; it does not start a service or create
authority. `mkdir` refuses an existing directory so a repeated walkthrough cannot
overwrite a running installation's configuration.

```sh
mkdir .cache/docs-start
python3 - <<'PY'
import json
from pathlib import Path
bundle = Path('.cache/transit-local').resolve()
configuration = {
    'version': 2,
    'installation': './installation',
    'realm': 73,
    'ports': {'cold': 19101, 'cold_console': 19102, 'store': 19103,
              'node': 19104, 'gateway': 19105},
    'executables': json.loads((bundle / 'share/transit/local-executables.json').read_text()),
    'applications': {'port': 19106, 'max_applications': 8, 'max_roles': 32},
}
Path('.cache/docs-start/server.json').write_text(json.dumps(configuration, indent=2) + '\n')
PY
.cache/transit-local/bin/transit serve --config .cache/docs-start/server.json --initialize
```

Wait for the JSON ready record. It names the generated `console_config` and
`management_config`. All listeners bind loopback; this is a trusted single-user
installation, not an OS sandbox. Credentials and data stay in the installation
directory. The [server guide](../../apps/transit-cli/docs/server.md) explains
quotas, required free disk space and configuration compatibility.

## Query from a second terminal

From the repository root:

```sh
.cache/transit-local/bin/transit console \
  --config .cache/docs-start/installation/console.json
```

In the console:

```text
/schema
/new 1
SELECT COUNT(*) FROM items;
/status
```

The initial Table has `id` and `value` int64 columns and no application rows.
If upload is waiting for admitted input, use `/advance`. Repeat `/status` until
it reports verified completion, then use `/next` to read the result: count zero.
A receipt alone does not mean the query finished. Enter `/quit` to disconnect.
See the [console guide](../../apps/transit-cli/docs/console.md) for output and
recovery details, and the [SQL reference](../reference/sql.md) for admitted syntax.

## Stop and resume

Ctrl-C in the server terminal stops its owned children and preserves disk state.
Resume with the same configuration and artifacts:

```sh
.cache/transit-local/bin/transit serve --config .cache/docs-start/server.json
```

Do not add `--initialize` on restart. For a previously submitted query, use
`/resume 1`; choose a new unused namespace only for intentionally new work.
If state or an artifact is missing, startup refuses to recreate its history.
Inspect the error and follow [server recovery](../../apps/transit-cli/docs/server.md#ownership-and-recovery).

Next, [install a separately compiled application](applications.md). The local
server does not include Board or Flight; those have separately configured hosts.
