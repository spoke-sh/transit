# Configuration Guide

`transit` should be easy to run locally and explicit to run in production. The same configuration model should support embedded and server deployments without inventing separate storage semantics.

## Configuration Locations

`transit` should resolve configuration in this order, with later entries taking priority:

1. `/etc/transit.toml`
2. `${XDG_CONFIG_HOME:-~/.config}/transit/transit.toml`
3. `./transit.toml`

Environment variables should override file-based settings where set.

`transit --config <path> ...` pins resolution to one explicit file before
applying any `TRANSIT_*` overrides. This repository also keeps a starter file
in `transit.toml.example`; a local `./transit.toml` is ignored by git.

## Expected Environment Overrides

- `TRANSIT_CONFIG`
- `TRANSIT_MODE`
- `TRANSIT_NODE_ID`
- `TRANSIT_NAMESPACE`
- `TRANSIT_DATA_DIR`
- `TRANSIT_CACHE_DIR`
- `TRANSIT_STORAGE_PROVIDER`
- `TRANSIT_OBJECT_BUCKET`
- `TRANSIT_OBJECT_PREFIX`
- `TRANSIT_OBJECT_ENDPOINT`
- `TRANSIT_DURABILITY`
- `TRANSIT_LISTEN_ADDR`
- `TRANSIT_LOG`

## Configuration Philosophy

Three rules should shape configuration:

1. Embedded and server mode share one storage model.
2. Durability policy must be explicit and comparable.
3. Tiered storage identity must be declared, not inferred.

## Effective Resolution Rules

Configuration should be easy to predict from the command line.

| Source | How it is selected | Typical use |
|--------|--------------------|-------------|
| default search path | runtime reads `/etc/transit.toml`, XDG config, then `./transit.toml` | local development and operator defaults |
| `--config <path>` | pins one file before applying env overrides | proof runs, CI, and explicit deployment bundles |
| `TRANSIT_*` overrides | applied after file resolution | containers, CI, and one-off operational overrides |

The practical rule is simple: file-based config establishes the intended deployment shape, and flags or `TRANSIT_*` variables are the smallest-possible override on top of that shape.

## Example Configuration

```toml
[node]
id = "dev-a"
mode = "server"
namespace = "local"
data_dir = ".transit/data"
cache_dir = ".transit/cache"

[storage]
provider = "filesystem"
bucket = ".transit/objects"
prefix = "dev-a"
durability = "local"
segment_target_bytes = 134217728
flush_bytes = 1048576
flush_interval_ms = 50
compression = "zstd"
checksum = "crc32c"
local_cache_bytes = 2147483648
prefetch_window_segments = 2

[streams]
max_record_bytes = 1048576
index_stride_bytes = 4096
local_head_min_segments = 2
branch_policy = "single-writer"

[server]
listen_addr = "127.0.0.1:7171"
advertise_addr = "127.0.0.1:7171"
max_connections = 1024
auth_mode = "none"

[telemetry]
log_level = "info"
metrics_namespace = "transit"
prometheus_addr = "127.0.0.1:9464"
slow_request_ms = 25
```

The checked-in [transit.toml.example](transit.toml.example) matches this local
filesystem-first shape.

## Hosted Tiered Server Example

When a hosted server is responsible for `tiered` durability, the configuration
should make the authority boundary explicit:

```toml
[node]
id = "prod-a"
mode = "server"
namespace = "hub-prod"
data_dir = "/var/lib/transit/work"
cache_dir = "/var/lib/transit/cache"

[storage]
provider = "s3"
bucket = "transit-prod"
prefix = "hub-prod/prod-a"
region = "us-west-2"
durability = "tiered"
local_cache_bytes = 2147483648
prefetch_window_segments = 2

[streams]
local_head_min_segments = 2

[server]
listen_addr = "0.0.0.0:7171"
advertise_addr = "transit.prod.example:7171"
auth_mode = "token"
```

In that shape, object storage is the long-term authority for rolled segments
and manifests, while `data_dir` and `cache_dir` remain warm working state that
can be rebuilt from the authoritative remote tier.

The published authority model now uses one explicit discovery rule instead of
implicitly treating a mutable manifest file as the only truth:

- immutable segment objects live under `streams/<id>/segments/...`
- immutable manifest snapshots live under `streams/<id>/manifests/...`
- the latest published snapshot is discovered through
  `streams/<id>/frontiers/latest.json`

That same namespace shape exists on the local filesystem backend under
`data_dir/published/...` and on remote object-store backends under the
configured object-store prefix. The mutable working plane remains local:

- `data_dir/streams/<id>/active.segment`
- `data_dir/streams/<id>/state.json`

The active head is a working file, not a published object-store snapshot.

The canonical hosted consumer endpoint and auth posture contract that sits on
top of these values is documented in [`HOSTED_CONSUMERS.md`](HOSTED_CONSUMERS.md).

## Deployment Profiles

These profiles describe the intended operating shapes and the current fidelity of each one.

| Profile | Core keys | Typical commands | Current status |
|---------|-----------|------------------|----------------|
| local embedded proof | `[node].mode = "embedded"`, local filesystem `[storage]`, `[storage].durability = "local"` | `transit proof local-engine`, `transit status` | fully wired |
| local single-node server | `[node].mode = "server"`, `[server].listen_addr`, local filesystem `[storage]` | `transit server run`, `transit streams`, `transit produce`, `transit consume` | fully wired for the local/filesystem path |
| hosted tiered server | object-store-backed `[storage]`, explicit namespace, hosted `[server]` endpoint | `transit server run`, `transit storage probe`, tiered-engine and warm-cache proofs | bootstrap now validates authored object-store authority and binds the hosted server path; remote-tier acknowledgement truth remains an explicit contract boundary |
| clustered failover and quorum | `[replication]` plus `quorum` durability and shared consensus root | controlled-failover and chaos-failover proofs | shared-engine behavior is proven; general operator packaging is still evolving |

## CLI Surface And Config Resolution

The current CLI should resolve defaults predictably from the effective config.

| Surface | Defaults from config | Primary explicit overrides |
|---------|----------------------|----------------------------|
| `transit status` and local proof commands | `[node].data_dir` | `--root` |
| `transit storage probe` | `[node].data_dir`, `[node].cache_dir`, and `[storage]` | `--config`, `TRANSIT_*` |
| `transit server run` | `[node].data_dir`, `[server].listen_addr`, and related server fields | `--root`, `--listen-addr`, `--serve-for-ms` |
| `transit streams`, `transit produce`, `transit consume` | `[server].listen_addr` | `--server-addr` |
| proof-specific generated roots | explicit proof arguments | explicit `--root` or proof fixture config |

This split is intentional: local-engine commands resolve one filesystem-backed root, while remote operator commands resolve the server endpoint they should talk to.

## Core Sections

### `[node]`

Identity and local layout for one embedded runtime or server node.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `id` | String | hostname-derived | Stable node identity used in manifests and telemetry. |
| `mode` | String | `"embedded"` | Runtime mode: `embedded` or `server`. |
| `namespace` | String | `"default"` | Logical namespace for streams and manifests. |
| `data_dir` | String | `".transit/data"` | Local durable data root. |
| `cache_dir` | String | `".transit/cache"` | Local cache for remote segments and indexes. |

### `[storage]`

Storage configuration defines how local and remote persistence interact.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `provider` | String | `"filesystem"` | Object-store backend: `filesystem`, `s3`, `gcs`, `azure`. |
| `bucket` | String | `".transit/objects"` | Bucket, container, or filesystem root for immutable objects. |
| `prefix` | String | `""` | Prefix used to isolate one namespace or environment. |
| `endpoint` | String | `null` | Optional custom endpoint for S3-compatible stores. |
| `region` | String | `null` | Backend region when relevant. |
| `durability` | String | `"local"` | Append acknowledgment mode: `memory`, `local`, `replicated`, `quorum`, `tiered`. |
| `segment_target_bytes` | Integer | `134217728` | Target immutable segment size. |
| `flush_bytes` | Integer | `1048576` | Flush threshold for the active segment. |
| `flush_interval_ms` | Integer | `50` | Maximum time before the active segment is flushed. |
| `compression` | String | `"zstd"` | Immutable segment compression codec for sealed rolled segments: `zstd` or `none`. The active head stays uncompressed. |
| `checksum` | String | `"crc32c"` | Segment checksum algorithm. |
| `local_cache_bytes` | Integer | `2147483648` | Maximum local cache footprint for remote segments. |
| `prefetch_window_segments` | Integer | `2` | Number of remote segments to prefetch on sequential replay. |

`durability` is central:

- `memory`: tests and benchmarks only
- `local`: record is durable on local storage before ack
- `replicated`: record is not acknowledged until the configured publication path is durable
- `quorum`: record is not acknowledged until the configured peer majority has confirmed receipt
- `tiered`: record is not acknowledged until the required remote tier state is durable

For hosted consumers, this configured durability is the authored target
contract. The server must surface `ack.durability` as the guarantee it
actually reached for that response, not as a stronger label copied from
`transit.toml`. Downstream wrappers should preserve the literal acknowledgement
label instead of collapsing it into product-local commit-state vocabulary.

For hosted `tiered` deployments, the configuration contract should be read in
two groups.

Object-store authority inputs:

- `[storage].provider`, `[storage].bucket`, `[storage].prefix`, and optional
  `[storage].endpoint` or `[storage].region` identify the authoritative remote
  tier that stores rolled segments and manifests
- `[storage].durability = "tiered"` means the server must not claim remote-tier
  safety until that shared object-store publication path has actually completed
- `[node].namespace` scopes those manifests and stream identifiers without
  creating a server-only storage model

Warm-cache and working-set inputs:

- `[node].data_dir` is the local writable head and restart working area used by
  the shared engine
- `[node].cache_dir` is the replaceable cache for hydrated remote segments,
  indexes, and similar local acceleration state
- `[storage].local_cache_bytes`, `[storage].prefetch_window_segments`, and
  `[streams].local_head_min_segments` control how much history stays warm
  locally without changing what is authoritative

Those groups do not define two durability worlds. They describe one shared
manifest and lineage model with different roles: object storage is the
authority for acknowledged `tiered` history, and the filesystem stays a warm
cache plus working set.

`compression` is a storage-layer control:

- it applies only when the active head rolls into an immutable segment
- the active writable head remains uncompressed for the hot append path
- replay, restore, and hosted reads transparently decode compressed segments back
  into ordinary Transit records
- `byte_length` tracks the stored compressed footprint, while segment metadata also
  preserves the uncompressed canonical size

`checksum` should stay scoped to fast corruption detection for sealed segments. Future cryptographic digests, manifest roots, and checkpoint signing should be configured separately instead of overloading one field with unrelated guarantees.

### `[streams]`

Stream-level defaults and safety limits.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `max_record_bytes` | Integer | `1048576` | Hard limit for a single record payload plus metadata. |
| `index_stride_bytes` | Integer | `4096` | Byte interval between index checkpoints inside a segment. |
| `local_head_min_segments` | Integer | `2` | Minimum recent segments kept locally even after tiering. |
| `branch_policy` | String | `"single-writer"` | Initial concurrency model for branch heads. |
| `allow_branch_from_non_head` | Boolean | `true` | Whether branches may be created from historical offsets. |

### `[server]`

Network-facing settings for daemon mode.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `listen_addr` | String | `"127.0.0.1:7171"` | Bind address for the server. |
| `advertise_addr` | String | same as `listen_addr` | Address returned to clients or peers. |
| `max_connections` | Integer | `1024` | Maximum concurrent client connections. |
| `request_body_limit_bytes` | Integer | `8388608` | Maximum request size accepted by the server. |
| `auth_mode` | String | `"none"` | Planned auth mode: `none`, `token`, `mtls`. |

The current CLI now resolves `transit.toml` plus `TRANSIT_*` overrides at
runtime. Commands that operate on one local engine root default to
`[node].data_dir` when `--root` is omitted, and `transit server run` defaults
`--root` plus `--listen-addr` from `[node].data_dir` and `[server].listen_addr`.

The current runtime still enforces only the `local` guarantee class from
configuration:

- `transit storage probe` verifies `[node].data_dir`, `[node].cache_dir`, and
  the authored object-store authority bootstrap path, then reports the
  effective guarantee plus an explicit non-claim when hosted/tiered semantics
  are configured but not yet part of the acknowledgement contract
- `transit server run` validates the authored object-store provider during
  startup and binds the shared hosted server path without rewriting
  `transit.toml` back to `local`
- hosted runtime bootstrap acceptance is not the same thing as a truthful
  remote-tier acknowledgement claim; append and recovery paths must still prove
  when `tiered` is actually satisfied

As the hosted authority contract expands, server startup should continue to
hydrate and publish the same manifests, segments, and lineage descriptors that
embedded restore already uses. The server owns credentials and operator policy,
not a separate durability semantic.

For hosted consumers, read these fields with three explicit rules:

- `listen_addr` is the local bind address, not automatically the published
  consumer target
- `advertise_addr` is the canonical consumer-facing endpoint when operators
  publish one
- `auth_mode` declares the hosted access posture, but `token` and `mtls` remain
  explicit non-claims until the runtime enforces them on the wire

### `[replication]`

Replication and failover settings for clustered deployments.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `mode` | String | `"single-node"` | Deployment model: `single-node` or `cluster`. |
| `node_id` | String | null | Unique identity for this node (overrides `[node].id`). |
| `consensus_root` | String | null | Object-store path used for shared leases and elections. |
| `lease_duration_secs` | Integer | `10` | TTL for the primary lease. |
| `election_poll_interval_ms` | Integer | `1000` | How often the `ElectionMonitor` checks lease health. |
| `quorum_size` | Integer | `1` | Number of nodes required for `quorum` durability. |

`durability` mode `quorum` depends on these settings to discover peers and calculate the required majority.

### `[telemetry]`

Telemetry must expose enough context to compare benchmark and production behavior.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `log_level` | String | `"info"` | Standard logger verbosity. |
| `metrics_namespace` | String | `"transit"` | Prefix used for metrics output. |
| `prometheus_addr` | String | `null` | Optional bind address for metrics export. |
| `tracing_json` | Boolean | `false` | Emit structured JSON traces. |
| `slow_request_ms` | Integer | `25` | Threshold for slow-request warnings. |

## Configuration Discipline

When new behavior is added:

- document the configuration key before or with the code change
- describe whether it affects durability, lineage, storage layout, or benchmark scope
- avoid mode-specific settings that create separate semantics for embedded and server use
- keep fast checksums distinct from cryptographic integrity settings so performance and proof claims remain comparable

Configuration should make guarantees clearer, not hide them.
