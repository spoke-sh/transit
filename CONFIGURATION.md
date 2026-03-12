# Configuration Guide

`transit` should be easy to run locally and explicit to run in production. The same configuration model should support embedded and server deployments without inventing separate storage semantics.

## Configuration Locations

`transit` should resolve configuration in this order, with later entries taking priority:

1. `/etc/transit.toml`
2. `${XDG_CONFIG_HOME:-~/.config}/transit/transit.toml`
3. `./transit.toml`

Environment variables should override file-based settings where set.

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
| `bucket` | String | `""` | Bucket, container, or filesystem root for immutable objects. |
| `prefix` | String | `""` | Prefix used to isolate one namespace or environment. |
| `endpoint` | String | `null` | Optional custom endpoint for S3-compatible stores. |
| `region` | String | `null` | Backend region when relevant. |
| `durability` | String | `"local"` | Append acknowledgment mode: `memory`, `local`, `tiered`. |
| `segment_target_bytes` | Integer | `134217728` | Target immutable segment size. |
| `flush_bytes` | Integer | `1048576` | Flush threshold for the active segment. |
| `flush_interval_ms` | Integer | `50` | Maximum time before the active segment is flushed. |
| `compression` | String | `"zstd"` | Segment compression codec. |
| `checksum` | String | `"crc32c"` | Segment checksum algorithm. |
| `local_cache_bytes` | Integer | `2147483648` | Maximum local cache footprint for remote segments. |
| `prefetch_window_segments` | Integer | `2` | Number of remote segments to prefetch on sequential replay. |

`durability` is central:

- `memory`: tests and benchmarks only
- `local`: record is durable on local storage before ack
- `tiered`: record is not acknowledged until the required remote tier state is durable

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

### `[replication]`

Replication is deferred scope, but the config surface should be explicit once introduced.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `mode` | String | `"single-node"` | Initial deployment model. |
| `sync_quorum` | Integer | `1` | Number of nodes required for future replicated ack. |
| `peer_urls` | Array | `[]` | Planned peer list for future replicated topologies. |

Until replication exists, `single-node` should remain the only supported value.

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

Configuration should make guarantees clearer, not hide them.
