# Local server

`transit serve` is an alias for `transit server`, with the same options and
recovery contract. Commands assume the complete local bundle is installed with
`transit` on `PATH`; see the [quickstart](../../../docs/guides/quickstart.md).
The bundle supplies the CLI and matching native neighborhood artifacts.

`transit server --initialize` deliberately creates a private
installation and runs it in the foreground. Subsequent starts omit
`--initialize`. Version 1 starts and supervises a separate `transit-board` process
by default. Its frontend assets are bundled inside the Board executable. Add
`--no-ui` to either command name for a headless invocation. The server runs on
Linux x86_64 in a trusted single-user placement. Kubernetes/Substrate remains
the reference isolation profile. Executed recovery and capacity evidence belongs
in the [test guide](../../../tests/README.md).

## Defaults and configuration

The installed local bundle runs without a configuration file. Defaults select
version 1, realm 1, an installation at `./.transit`, loopback ports 19101–19105
for cold storage, cold console, store, node and gateway, application management
on 19106, and Board on 19107. Application quotas are eight applications and 32
roles. For missing executable settings, lookup prepends the directory containing
the physical `transit` executable to the inherited `PATH`. The default names are
`minio`, `ursula`, `transit-node`, `transit-query-host` and `transit-board`.
Running `transit server` searches that executable’s directory first, then
`PATH`. Symlink invocation uses the resolved executable directory. A missing
provider must be installed there or available on `PATH`; lookup reports its
name. Explicit `executables` paths override lookup. The effective search is
bounded to a 64 KiB `PATH` and 256 entries.

The local bundle places all dependencies in its `bin` directory, so it needs no
ambient tools. A manifest is still provided for downstream consumers, but server
startup does not read it. Resolved absolute executable paths and hashes are
recorded before starting children; restart retains the same identity checks.

With no `--config`, the server selects the **first existing** file:

1. `./transit.yaml`
2. `~/transit.yaml`
3. `/etc/transit/transit.yaml`

It does not merge these files. A selected file's read or validation error stops
startup. `--config FILE` selects exactly that file and disables discovery. If no
file exists, built-in defaults apply. The selected file overlays defaults:
nested mappings merge, scalars and lists replace. Partial customization is enough:

```yaml
ports:
  gateway: 10000
board:
  port: 10001
```

Environment values override the selected file and defaults. Names start with
`TRANSIT_`, use uppercase field names, and separate nested fields with `__`.
A single underscore stays part of the field name:

```sh
TRANSIT_PORTS__GATEWAY=10000 transit server --initialize
TRANSIT_BOARD__PORT=10001 transit server --initialize
```

These commands illustrate separate new installations; restarts must retain their
original effective values. `TRANSIT_REALM` sets `realm`, and
`TRANSIT_APPLICATIONS__MAX_ROLES` sets `applications.max_roles`. Strings and paths
are literal values; numbers, booleans, lists and objects use JSON syntax. More
specific nested variables override a whole-object variable regardless of
environment iteration order. Lists replace as a unit. Unknown settings and
invalid types reject; values are never printed. `TRANSIT_CONSOLE_CONFIG` is
reserved for the console and ignored by the server. Explicit invocation flags
such as `--no-ui` and `--initialize` remain command-line actions, not YAML settings.
The local profile has no configurable bind host or top-level `port`; its actual
port fields are under `ports`, `applications` and `board`.

Files are at most 64 KiB. JSON files use the `.json` extension; YAML accepts block
mappings, scalar sequences, plain/single-quoted strings and JSON-encoded quoted
strings or flow values. It rejects duplicate/unknown keys, anchors, aliases,
tags, merge keys and multiline scalars. Nesting is limited to 16 levels; block
entries and JSON tokens are bounded to 2048 per parsed input. YAML flow values
must use JSON syntax and have no trailing comment. This is a data-only subset,
not a general YAML processor. `TRANSIT_` input has a combined 64 KiB limit.

Explicit relative paths resolve against the selected file, or the working
directory if no file is selected. The default installation always remains
`./.transit` in the working directory. `--initialize` still deliberately creates
the installation; an ordinary `transit server` restarts it and never recreates
missing retained state. Changing effective configuration after initialization
is refused by the same installation identity checks.

A complete YAML configuration can override these defaults:

```yaml
version: 1
installation: "./local-transit"
realm: 73
gateway_allowed_hosts: []
admission_ceiling: 65536
control_reserve: 4096
ports:
  cold: 19101
  cold_console: 19102
  store: 19103
  node: 19104
  gateway: 19105
executables:
  minio: "/absolute/path/to/minio"
  ursula: "/absolute/path/to/ursula"
  node: "/absolute/path/to/transit-node"
  query_host: "/absolute/path/to/transit-query-host"
  board: "/absolute/path/to/transit-board"
```

Configuration rejects unknown fields and incompatible versions; ports must be distinct and above 1023. All
listeners bind `127.0.0.1`. The parent of `installation` must exist. Connectors,
remote listeners and alternate source definitions remain unsupported.

Version 1 requires a resolved `executables.board`, supplied by the bundle by default. Optional `board` settings default to
`{"port":19107,"public_origin":"http://127.0.0.1:19107"}`. Override the port for
multiple installations; omit the origin to derive it from that port, or specify
the exact matching loopback origin. Other origins reject in this local profile.
Board retains its exact Host/Origin checks. All configured ports, including
optional application management, must be distinct. Startup checks occupied
listeners before effects; `--no-ui` skips only Board's listener preflight.
Version 1 defaults to application management on port 19106 and
accepts `applications: null` to omit it.

The native admission ceiling defaults to 65,536 journal positions, with 4,096
additional control positions. The selected profile accepts ceilings from 128
through 65,536 and reserves from zero through 65,536. These immutable genesis
quotas limit accepted obligations; they do not expire retained history. Restart
cannot reopen exhausted admission. Physical disk headroom must be provisioned
separately; Ursula stops admitting writes below 64 MiB free and resumes above
128 MiB. Neither physical pressure nor reserve exhaustion authorizes data loss.

The selected dependency set is the matching Transit CLI/node/query-host/Board build,
pinned Ursula 0.5.1 and MinIO RELEASE.2025-09-07T16-13-09Z. The proof extracts the
native MinIO binary from its pinned fixture image. Docker is proof setup, not a
server runtime dependency. Source builds supply this complete dependency set;
there is no published release bundle or general runtime upgrade path. The server
hashes every configured executable and itself with bounded streaming reads before provisioning; ordinary
startup requires the same hashes and normalized configuration. It currently
refuses artifact/configuration changes; this is not an upgrade mechanism.

After resolving the CLI, the complete local bundle needs no ambient tools.
The running installation uses no shell, Python, task runner, Process Compose or
source checkout. Child environments are explicit.
MinIO receives a private service home under `provider-home` and an explicit
certificate directory, without inheriting the operator's home or credentials.
Its browser is disabled; the separate cold-console port remains reserved.

When the complete neighborhood is ready, stdout emits one JSON record naming
`installation`, optional `management_config` (a YAML file), `gateway_url`, the effective
`allowed_hosts`, `board_url` and `ui`. For example,
port 19105 reports `gateway_url: "http://127.0.0.1:19105"` and
`allowed_hosts: ["127.0.0.1:19105", "localhost:19105"]`. The URL is the native
protocol gateway; use `/health` for a readiness check.
`ui` is `"ready"` only after authorized Board atlas inspection; headless
invocations report `"disabled"` and `board_url: null`. Recovery emits a fresh
ready record after the replacement neighborhood passes its checks. Open an independent
terminal in the same working directory with the same topology configuration and
environment. The console derives its connection from the local installation;
the server does not generate a console configuration file:

```sh
transit console
```

The initial authorized source is `items(id int64, value int64)`, with no example
rows. `.schema` describes it. `SELECT COUNT(*) FROM items;` prints the verified
count automatically. The server provisions the combined Table query/writer owner
and explicitly grants the local caller INSERT, UPDATE and DELETE policy. Bare
`transit console` derives both routes and its private `console-writes.json`
recovery path from the installation. For example:

```sql
INSERT INTO items (id, value) VALUES (1, 100);
SELECT * FROM items;
UPDATE items SET value = 101 WHERE id = 1;
DELETE FROM items WHERE id = 1;
```

These writes retain the [bounded Table mutation syntax](console.md#writing-tables-and-catalogs).
SELECT opens a fresh snapshot; `.status` and `.resume` observe and recover a saved
write after interruption. CREATE TABLE requires a separate catalog connection.
The caller retains native inspect/send and resource read grants; only the fenced
Table owner commits row changes under its separate current mutation policy.

## Local names and SSH tunnels

The gateway accepts `127.0.0.1:<gateway-port>` and `localhost:<gateway-port>` as
HTTP Host authorities by default. Hostname comparison is case insensitive; the
port must match exactly. Both of these requests work with the example above:

```sh
curl http://127.0.0.1:19105/health
curl http://localhost:19105/health
```

An SSH tunnel forwarding the same local port preserves these authorities:

```sh
ssh -N -L 19105:127.0.0.1:19105 user@server
```

For a different local port or a developer hostname, add the exact authority to
the public server configuration **before initializing the installation**:

```json
"gateway_allowed_hosts": ["localhost:29105", "127.0.0.1:29105", "transit.local.test:19105"]
```

Then `ssh -N -L 29105:127.0.0.1:19105 user@server` supports
`curl http://localhost:29105/health`. For an existing installation whose policy
does not include the forwarded port, send its original accepted Host explicitly:
`curl -H 'Host: 127.0.0.1:19105' http://localhost:29105/health`.

The optional list adds at most eight authorities of at most 200 ASCII bytes each.
Each entry requires a DNS-style hostname, IPv4 literal or bracketed IPv6 literal,
followed by a decimal port from 1–65535 without leading zeroes. Wildcards, URLs,
userinfo, empty DNS labels, trailing dots and IPv6 zone identifiers reject.
Entries authorize exact names and ports, without suffix matching or DNS lookups.
Choose names whose resolution you control. Adding an authority does not create
a DNS entry, bind another port/interface, enable IPv6 listening or change the
console's transport policy. The gateway continues to bind IPv4 loopback only.

Unknown authorities and malformed/duplicate Host headers reject. Origin,
Authorization and forwarded-identity headers remain forbidden in this native
gateway profile; accepting a local name does not enable browser access or confer
native permissions. Application-serving Origin policies remain separate.

The same gateway policy and ready fields apply to the version 1
[application installation profile](applications.md). Its separate management
listener retains its numeric loopback authority; `gateway_allowed_hosts` applies
only to the native protocol gateway.

The list is part of the normalized installation configuration. Changing it after
initialization is refused, as are changed runtime binaries. This enhancement
applies to installations initialized with the new runtime; it does not upgrade
older installations or permit editing their private identity records.

## Ownership and recovery

The installation has a random identity, private credential files, artifact and
configuration hashes, accepted provisioning receipts and a monotonic observed
authority position. A sibling OS lock serializes initialization and management.
Initial files are assembled in a private sibling directory and renamed into
place before any provider or native operation starts. A leftover `.creating-*`
directory contains no accepted native work and is never automatically adopted.

Every provisioning request is signed and fsynced before dispatch. Its exact
pending representation survives interruption. A receipt is recorded before its
position supplies a PID or resource identity. An installation-record write
failure stops management; it cannot authorize another operation from volatile
progress. Ordinary startup resolves frozen operations before preparing fresh
ones. Worker registration records contain public keys only; each physical
replacement creates its own fresh in-memory key, receives scoped grants and an
exact ownership generation. Foreign resource access is granted separately from
the source's optional requester association. Activation markers are never removed.

The server starts MinIO, disk Ursula, authority, maintenance, source, requester,
courier, then gateway. The combined Table owner initializes in two durable turns;
the courier delivers its recorded self continuation. The server checks the exact
ready configuration and authorized source/requester inspection before gateway
readiness. Recorded initialization is not repeated on restart, and revoked
mutation rights are not restored. SIGINT/SIGTERM stop in reverse order and join
children. Each
child starts in a distinct process group through a Linux parent-death trampoline;
the trampoline arms SIGKILL and checks the expected parent before exec. Killing
the manager therefore kills its owned service processes. The next manager
preflights every listener and never adopts a process by PID number or port.

The manager checks child exits every 100 ms and observes authority every second.
An exited role or failed authority observation withdraws the gateway and stops
dependents before restarting the same history. Gateway health is a sampled
availability observation, not a query completion or ownership guarantee. One invocation permits three
restarts after the initial attempt, with 250/500/750 ms backoff. Registration has
a 10-second deadline; provider/authority/gateway readiness has 30 seconds per
role; initialized query inspection has 60 seconds. Native operations have a
two-second attempt deadline. Shutdown gives each child one second for SIGTERM,
then kills its group and joins it. These are physical lifecycle bounds, not
extensions of accepted operation lifetimes.

Source, requester and courier idle intervals start at 100 ms and double up to
one second, resetting on activity. Idle receives wait for bounded authorized
process/output notifications, then revalidate current state. Timeouts reconcile
missed and other-node publications; unavailable waits use the bounded interval.
Interactive console SELECT executes directly over native snapshots.

Once genesis has been observed, recovery never enables node bootstrap or creates
a replacement cold bucket. Missing storage markers and an authority position
below the recorded observation fail closed. Corruption, an unavailable provider
or quota pressure never triggers deletion, expiry or a reset. This observed
position is not a global latest-history oracle. Snapshot restore, distributed
ownership and live disaster recovery are outside this profile.

## Roles, credentials and bounds

| Role | Native authority / private inputs | Resident and work bounds |
| --- | --- | --- |
| Manager | Root key; provisioning and scoped caller key for initial casts | One 64 KiB installation record, one frozen request, nine children, 64 KiB streaming artifact hash buffer |
| MinIO | Local provider credential only | Two Go scheduler threads, 256 MiB Go soft heap target; independent provider, no Transit authority |
| Ursula | Disk WAL and local cold credential | One Raft group, two cores, 8 MiB hot data and 8 MiB cold read cache; 8 MiB uncommitted Raft payload cap, 64 live-read waiters per core, 512 MiB RSS admission threshold |
| Authority | Genesis public root key, raw storage location | Eight decoded authority pages plus 16 immutable control records; 16 sockets, four data/two control/four wait requests, serialized engine work; 256 KiB native body/reply, two-second HTTP deadline |
| Maintenance | Separate admin/effect/delivery grant and raw storage location | One bounded scan/transition at a time, one-second idle interval, two-second operation deadline |
| Source / Table writer | Fresh PID-scoped inspect/execute/publish grant; own resource and separate requester-resource read grant | Four MiB query workspace, one MiB adapter, four mutations per committed turn |
| Requester | Fresh PID-scoped inspect/execute/publish grant and own resource | Four MiB workspace, one active finite query/upload; retained history remains durable |
| Courier | Separate inspect/send/delivery grant | One bounded output page and one frozen delivery; recorded destinations remain authoritative |
| Gateway | No signing key or raw provider access | 16 sockets, four data/two control/four wait requests, six ordinary and four wait upstream clients; 8 KiB headers, 256 KiB body/reply; one-second header and four-second whole-request deadlines |
| Board | Separate retained realm inspection-only key and explicit resource grants; no query/operator credential | Existing [Board limits](../../transit-board/README.md#bounds-and-observations); one child, bounded 256 KiB startup response |
| Console | Realm-scoped inspect/send caller key, two specific resource read grants and separate Table INSERT/UPDATE/DELETE policy | Its separate [console bounds](console.md), private write recovery file and credential lock |

Each child has two independent 64 KiB in-memory log prefixes. After each prefix
fills, the drain continues and discards additional diagnostics; there is no
growing log file or stdout-dependent child progress. These logs are disposable
diagnostics, not durable receipts. Manager diagnostics contain role/error names,
not child payloads or credentials. Retention remains unlimited; query execution
budgets cap each request at 1,000 source pages, 128 segments and 1 MiB result data.
Provider heap targets are not hard RSS limits or an isolation guarantee.
Gateway transport diagnostics omit ordinary idle closes and idle expiry.
`HttpRequestDeadline` identifies expiry after request dispatch; it does not
establish whether the authority accepted the request. Preserve the exact saved
request and reconcile through the caller's recovery interface.

The gateway forwards only native `/v1/query`, `/v1/command` and `/health` routes,
preserving the signed body and upstream response status. Node and gateway permit
64 sequential exchanges per connection; clients discard connections after 200 ms
since an exchange started, and the listener bounds idle header waits to one second. Commands, health and
checked snapshot release/finish requests use
the control reserve; native authorization still decides every operation. Exact
configured Host is required, and browser Origin, Authorization and forwarded
identity headers reject. Transport failure remains uncertainty. The gateway is
a separate process without root/caller credentials in its configuration. All
roles share one OS user; this separation does not sandbox them from that user's
other files. Configure remote TLS at the deployment's ingress boundary.

The [application manager](applications.md) has a separate management listener and
explicit active-app/role quotas. Set `applications: null` for a Table-only
neighborhood. Pinned neighborhood artifacts cannot be upgraded implicitly.


## Default Board and compatibility

The current shared contract definition covers local combined Table ownership.
Earlier query-only installation records, authority histories and saved commands
are incompatible and reject before use. Retain their matching binaries and
recovery files to finish pending work. A new installation requires a deliberately
separate directory; startup never converts or resets existing state. See the
[hard-cutover policy](../../../docs/reference/versioning.md).

Open the printed `board_url`. Every caller that can reach this loopback listener
shares its inspection scope; there is no viewer login. Board cannot borrow the
console or installer signing sequence. Query and operator workspaces remain
separate opt-in contracts and are not enabled by this server profile.

```sh
transit server --config transit.yaml --initialize
# After stopping, resume headlessly, then enable Board again:
transit serve --config transit.yaml --no-ui
transit serve --config transit.yaml
```

For headless first initialization add `--no-ui --initialize`. The installation
still pins Board's executable/settings and creates its private seed; first UI
enablement records principal creation and the built-in source/requester resource
grants using the retained exact-operation journal. Disabling UI preserves that
seed, realm, application history, accepted work and receipts. A pending accepted
provisioning operation is reconciled even when restarting headlessly. Re-enabling
never renews a completed grant. Revoked resources disappear from Board; revoking
its principal fails UI-enabled startup until an explicit authorized policy repair.

Applications opt into resource inspection with declaration version 1 and an
explicit `inspection` list; see [application inspection](applications.md#board-inspection).
Board's growing profile uses a realm-wide process inspector with individually
filtered resources. Process metadata is shared across this trusted local realm;
resource association or installation alone does not authorize resource contents.
The manager grants declared inspection once and retains its receipts, including
when applications were installed before first UI enablement.

Board starts after the native gateway, with a 30-second readiness window and a
four-second bounded atlas attempt. Readiness checks the real Board atlas and its
current inspection identity. Ongoing one-second observations use that identity
and HTTP health without competing with viewer atlas throttling. Board exits or
upstream outages stop dependents and enter the existing three-restart budget;
invalid responses or unsafe/revoked principals fail visibly. Shutdown joins Board
and parent death kills it with the same Linux mechanism as other owned roles.
Default startup never silently falls back to headless operation.

The server accepts the current version-1 configuration and installation records.
An incompatible record, artifact or configuration hash rejects before startup.
Initialize a separately named installation with matching packaged artifacts for
a hard cutover; no in-place history conversion is provided. `--no-ui` and later
UI re-enablement use the same compatible installation and retained history.

Retain the installed local bundle for the lifetime of its installations.
The [source installation guide](../../../nix/README.md#transit-cli-packages)
explains package retention. Its manifest includes Board and all native
providers; paths and executable hashes identify the selected bytes. Do not replace
individual pinned paths during ordinary restart. Runtime execution needs no
Node, Python, frontend dev server, source tree, Docker or ambient PATH lookup.
