# Local server

`transit serve` is an alias for `transit server`, with the same options and
recovery contract. The [Nix packages](../../../nix/README.md#transit-cli-packages)
supply the CLI and pinned native neighborhood artifacts.

`transit server --initialize` deliberately creates a private
installation and runs it in the foreground. Subsequent starts omit
`--initialize`. Version 3 starts and supervises a separate `transit-board` process
by default. Its frontend assets are bundled inside the Board executable. Add
`--no-ui` to either command name for a headless invocation. The Linux `local_table_v1` bootstrap, independent console and
process-recovery, interrupted bootstrap, gateway pressure and physical ENOSPC
proofs pass. Completed evidence belongs in the
[test guide](../../../tests/README.md). It is a trusted single-user placement,
with Kubernetes/Substrate remaining the reference isolation profile.

## Defaults and configuration

The installed local bundle runs without a configuration file. Defaults select
version 3, realm 1, an installation at `./.transit`, loopback ports 19101–19105
for cold storage, cold console, store, node and gateway, application management
on 19106, and Board on 19107. Application quotas are eight applications and 32
roles. For missing executable settings, lookup prepends the directory containing
the physical `transit` executable to the inherited `PATH`. The default names are
`minio`, `ursula`, `transit-node`, `transit-query-host` and `transit-board`.
For example, `./zig-out/bin/transit server` searches `zig-out/bin` first, then
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
version: 3
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

Version 3 requires a resolved `executables.board`, supplied by the bundle by default. Optional `board` settings default to
`{"port":19107,"public_origin":"http://127.0.0.1:19107"}`. Override the port for
multiple installations; omit the origin to derive it from that port, or specify
the exact matching loopback origin. Other origins reject in this local profile.
Board retains its exact Host/Origin checks. All configured ports, including
optional application management, must be distinct. Startup checks occupied
listeners before effects; `--no-ui` skips only Board's listener preflight.
Versions 2 and 3 default to application management on port 19106. Version 3
accepts `applications: null` to omit it; version 1 defaults to no management.

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

An empty `PATH` is supported. No shell, Python, `just`, Process Compose or source
checkout is used by the running installation. Child environments are explicit.
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
count automatically; `.resume` recovers the same query after interruption. Creating application data is outside this initial server profile.

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

The same gateway policy and ready fields apply to the version 2
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
courier, then gateway. Actual authorized source/requester inspection precedes
gateway readiness. SIGINT/SIGTERM stop in reverse order and join children. Each
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

Source, requester and courier polling starts at 100 ms and doubles on idle steps
up to one second, resetting on activity. New durable work may wait for that next
poll; interactive console SELECT executes directly over native snapshots.

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
| Authority | Genesis public root key, raw storage location | Eight decoded authority pages plus 16 immutable control records; 16 sockets, four data/two control requests, serialized engine work; 256 KiB native body/reply, two-second HTTP deadline |
| Maintenance | Separate admin/effect/delivery grant and raw storage location | One bounded scan/transition at a time, one-second idle interval, two-second operation deadline |
| Source | Fresh PID-scoped inspect/execute/publish grant; own resource and separate requester-resource read grant | Four MiB query workspace, one MiB adapter, four mutations per committed turn |
| Requester | Fresh PID-scoped inspect/execute/publish grant and own resource | Four MiB workspace, one active finite query/upload; retained history remains durable |
| Courier | Separate inspect/send/delivery grant | One bounded output page and one frozen delivery; recorded destinations remain authoritative |
| Gateway | No signing key or raw provider access | 16 sockets, four data plus two control requests, six exclusive upstream clients; 8 KiB headers, 256 KiB body/reply; one-second header and four-second whole-request deadlines |
| Board | Separate retained realm inspection-only key and explicit resource grants; no query/operator credential | Existing [Board limits](../../transit-board/README.md#bounds-and-observations); one child, bounded 256 KiB startup response |
| Console | Realm-scoped inspect/send caller key and two specific resource read grants | Its separate [console bounds](console.md) and optional private recovery file |

Each child has two independent 64 KiB in-memory log prefixes. After each prefix
fills, the drain continues and discards additional diagnostics; there is no
growing log file or stdout-dependent child progress. These logs are disposable
diagnostics, not durable receipts. Manager diagnostics contain role/error names,
not child payloads or credentials. Retention remains unlimited; query execution
budgets cap each request at 1,000 source pages, 128 segments and 1 MiB result data.
Provider heap targets are not hard RSS limits or an isolation guarantee.

The gateway forwards only native `/v3/query`, `/v3/command` and `/health` routes,
preserving the signed body and upstream response status. Node and gateway permit
64 sequential exchanges per connection; clients discard connections after 200 ms
idle, and the listener bounds idle waits to one second. Commands, health and
checked snapshot release/finish requests use
the control reserve; native authorization still decides every operation. Exact
configured Host is required, and browser Origin, Authorization and forwarded
identity headers reject. Transport failure remains uncertainty. The gateway is
a separate process without root/caller credentials in its configuration. All
roles share one OS user; this separation does not sandbox them from that user's
other files. Configure remote TLS at the deployment's ingress boundary.

Version 2 adds the [application manager](applications.md), a separate management listener and explicit active-app/role quotas. Version 1 retains the table-only neighborhood. Neither version permits an implicit pinned-neighborhood upgrade.


## Default Board and compatibility

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

Applications opt into resource inspection with declaration version 2 and an
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

Versions 1 and 2 remain headless configurations and require `--no-ui` with this
CLI. They cannot name Board settings or its executable. An installation created
by an older CLI retains its exact artifact/configuration hashes: neither this
flag nor changing the configuration version upgrades it. Keep such an installation on its
original pinned package/configuration. To adopt this profile, initialize a
separately named version-3 installation with the matching packaged artifacts;
there is no in-place history import or runtime upgrade in this profile. Once
created under version 3, all UI toggles use the same configuration and history.

Retain the `transit-local` Nix output with a profile or GC-rooted build link for
the lifetime of its installations. Its manifest includes Board and all native
providers; paths and executable hashes identify the selected bytes. Do not replace
individual pinned paths during ordinary restart. Runtime execution needs no
Node, Python, frontend dev server, source tree, Docker or ambient PATH lookup.
