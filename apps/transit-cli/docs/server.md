# Local server

`transit serve` is an alias for `transit server`, with the same options and
recovery contract. The [Nix packages](../../../nix/README.md#transit-cli-packages)
supply the CLI and pinned native neighborhood artifacts.

`transit server --config server.json --initialize` deliberately creates a private
installation and runs it in the foreground. Subsequent starts omit
`--initialize`. The Linux `local_table_v1` bootstrap, independent console and
process-recovery, interrupted bootstrap, gateway pressure and physical ENOSPC
proofs pass. Completed evidence belongs in the
[test guide](../../../tests/README.md). It is a trusted single-user placement,
with Kubernetes/Substrate remaining the reference isolation profile.

## Explicit configuration

```json
{
  "version": 1,
  "installation": "./local-transit",
  "realm": 73,
  "admission_ceiling": 65536,
  "control_reserve": 4096,
  "ports": {
    "cold": 19101,
    "cold_console": 19102,
    "store": 19103,
    "node": 19104,
    "gateway": 19105
  },
  "executables": {
    "minio": "/absolute/path/to/minio",
    "ursula": "/absolute/path/to/ursula",
    "node": "/absolute/path/to/transit-node",
    "query_host": "/absolute/path/to/transit-query-host"
  }
}
```

JSON rejects unknown fields and incompatible versions. Paths resolve against
the explicit configuration file; ports must be distinct and above 1023. All
listeners bind `127.0.0.1`. The parent of `installation` must exist. Board,
connectors, remote listeners and alternate source definitions are unsupported
in this profile and cannot be enabled by adding unchecked fields.

The native admission ceiling defaults to 65,536 journal positions, with 4,096
additional control positions. The selected profile accepts ceilings from 128
through 65,536 and reserves from zero through 65,536. These immutable genesis
quotas limit accepted obligations; they do not expire retained history. Restart
cannot reopen exhausted admission. Physical disk headroom must be provisioned
separately; Ursula stops admitting writes below 64 MiB free and resumes above
128 MiB. Neither physical pressure nor reserve exhaustion authorizes data loss.

The selected dependency set is the matching Transit CLI/node/query-host build,
pinned Ursula 0.5.1 and MinIO RELEASE.2025-09-07T16-13-09Z. The proof extracts the
native MinIO binary from its pinned fixture image. Docker is proof setup, not a
server runtime dependency. M25 owns distributing and verifying that complete
artifact set, including upstream licenses. The server hashes every configured
executable and itself with bounded streaming reads before provisioning; ordinary
startup requires the same hashes and normalized configuration. It currently
refuses artifact/configuration changes; this is not an upgrade mechanism.

An empty `PATH` is supported. No shell, Python, `just`, Process Compose or source
checkout is used by the running installation. Child environments are explicit.
MinIO receives a private service home under `provider-home` and an explicit
certificate directory, without inheriting the operator's home or credentials.
Its browser is disabled; the separate cold-console port remains reserved.

When the complete neighborhood is ready, stdout emits one JSON record naming
`console_config`. Open an independent terminal with:

```sh
transit console --config local-transit/console.json
```

The initial authorized source is `items(id int64, value int64)`, with no example
rows. `/schema` describes it; `/new 1` selects a fresh query namespace, and
`SELECT COUNT(*) FROM items;` submits a finite
query. `/advance`, `/status` and `/next` retain the console's admission/result
distinctions. Creating application data is outside this initial server profile.

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

Once genesis has been observed, recovery never enables node bootstrap or creates
a replacement cold bucket. Missing storage markers and an authority position
below the recorded observation fail closed. Corruption, an unavailable provider
or quota pressure never triggers deletion, expiry or a reset. This observed
position is not a global latest-history oracle. Snapshot restore, distributed
ownership and disaster recovery remain M26.

## Roles, credentials and bounds

| Role | Native authority / private inputs | Resident and work bounds |
| --- | --- | --- |
| Manager | Root key; provisioning and scoped caller key for initial casts | One 64 KiB installation record, one frozen request, eight children, 64 KiB streaming artifact hash buffer |
| MinIO | Local provider credential only | Two Go scheduler threads, 256 MiB Go soft heap target; independent provider, no Transit authority |
| Ursula | Disk WAL and local cold credential | One Raft group, two cores, 8 MiB hot data and 8 MiB cold read cache; 8 MiB uncommitted Raft payload cap, 64 live-read waiters per core, 512 MiB RSS admission threshold |
| Authority | Genesis public root key, raw storage location | Eight decoded authority pages, sequential requests, 256 KiB native body/reply contract, two-second HTTP deadline |
| Maintenance | Separate admin/effect/delivery grant and raw storage location | One bounded scan/transition at a time, one-second idle interval, two-second operation deadline |
| Source | Fresh PID-scoped inspect/execute/publish grant; own resource and separate requester-resource read grant | Four MiB query workspace, one MiB adapter, four mutations per committed turn |
| Requester | Fresh PID-scoped inspect/execute/publish grant and own resource | Four MiB workspace, one active finite query/upload; retained history remains durable |
| Courier | Separate inspect/send/delivery grant | One bounded output page and one frozen delivery; recorded destinations remain authoritative |
| Gateway | No signing key or raw provider access | Eight sockets, four data requests plus two control requests; 8 KiB headers, 256 KiB body/reply; 500 ms header and four-second whole-request deadlines |
| Console | Realm-scoped inspect/send caller key and two specific resource read grants | Its separate [console bounds](console.md) and optional private recovery file |

Each child has two independent 64 KiB in-memory log prefixes. After each prefix
fills, the drain continues and discards additional diagnostics; there is no
growing log file or stdout-dependent child progress. These logs are disposable
diagnostics, not durable receipts. Manager diagnostics contain role/error names,
not child payloads or credentials. Retention remains unlimited; query execution
budgets cap each request at 1,000 source pages, 128 segments and 1 MiB result data.
Provider heap targets are not hard RSS limits or an isolation guarantee.

The gateway forwards only native `/v3/query`, `/v3/command` and `/health` routes,
preserving the signed body and upstream response status. Commands and health use
the control reserve; native authorization still decides every operation. Exact
loopback Host is required, and browser Origin, Authorization and forwarded
identity headers reject. Transport failure remains uncertainty. The gateway is
a separate process without root/caller credentials in its configuration. All
roles share one OS user; this separation does not sandbox them from that user's
other files. Remote TLS belongs to an explicitly qualified deployment boundary.
