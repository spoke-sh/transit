# transit-client

Canonical Rust client surface for hosted `transit` consumers.

Downstream Rust repos should import hosted consumer operations and response
types from this crate instead of:

- copying a private hosted Transit client into another repo
- reaching into `transit-core::server` to assemble a second public consumer
  boundary
- keeping a repo-local compatibility wrapper once this crate has replaced it
- treating embedded local engine types as the authority for hosted workloads

## Import Surface

This crate publishes three parts of the hosted consumer boundary:

- `TransitClient` for hosted append, batch append, read, projection read,
  branch, merge, lineage, and tail operations
- stream input types such as `StreamId`, `Offset`, `StreamPosition`,
  `LineageMetadata`, and `MergeSpec`
- projection consumer types such as `ProjectionReadRequest`,
  `ProjectionReadOutcome<V>`, and `ProjectionReadConsumer`
- hosted response and error types such as `RemoteAcknowledged<T>`,
  `RemoteAcknowledgement`, `RemoteBatchAppendOutcome`,
  `RemoteErrorResponse`, `RemoteErrorCode`, and `RemoteTailSessionState`
- exported hosted batch limits `APPEND_BATCH_MAX_RECORDS` and
  `APPEND_BATCH_MAX_BYTES`

Typical downstream imports should look like:

```rust
use transit_client::{
    APPEND_BATCH_MAX_BYTES, APPEND_BATCH_MAX_RECORDS, LineageMetadata,
    MergeSpec, Offset, ProjectionReadConsumer, ProjectionReadRequest,
    RemoteAcknowledged, RemoteBatchAppendOutcome, RemoteErrorCode, StreamId,
    StreamPosition, TailSessionId, TransitClient,
};
```

Batch append stays inside the normal hosted protocol surface:

```rust
let batch = client.append_batch(
    &StreamId::new("consumer.orders")?,
    [b"record-1".as_slice(), b"record-2".as_slice()],
)?;

assert_eq!(batch.body().record_count(), 2);
assert_eq!(batch.body().first_position().offset.value(), 0);
assert_eq!(batch.body().last_position().offset.value(), 1);
```

## Batch Append Limits And Failures

Hosted batch append is intentionally limited and the crate re-exports the
supported limits so downstream producers can enforce them before calling the
server:

- `APPEND_BATCH_MAX_RECORDS`: maximum records accepted in one hosted batch
- `APPEND_BATCH_MAX_BYTES`: maximum total payload bytes accepted in one hosted
  batch

Failure behavior is explicit:

- an empty batch fails with hosted `invalid_request`
- a batch above `APPEND_BATCH_MAX_RECORDS` fails with hosted `invalid_request`
- a batch above `APPEND_BATCH_MAX_BYTES` fails with hosted `invalid_request`
- successful batch append still commits ordinary per-record offsets, replay, and
  tail behavior; consumers continue to observe individual Transit records

## Hosted I/O Timeouts

Hosted transport defaults remain explicit at 1000ms on both the server and
client sides. Downstream Rust clients can raise the client-side timeout without
changing the hosted acknowledgement or error envelopes:

```rust
use std::time::Duration;
use transit_client::{StreamId, TransitClient};

let client = TransitClient::new("127.0.0.1:7171".parse()?)
    .with_io_timeout(Duration::from_secs(5));

let replay = client.read(&StreamId::new("consumer.orders")?)?;
```

This is transport tuning only:

- `request_id` correlation stays literal
- `ack.durability` and `ack.topology` stay literal
- append, replay, batch append, and tail semantics do not change

Projection reads stay replay-driven. `transit-client` publishes the helper, but
the caller still owns reducer logic and payload meaning:

```rust
struct ConsumerProjection;

impl ProjectionReadConsumer for ConsumerProjection {
    type View = std::collections::BTreeMap<String, String>;

    fn initial_view(&self) -> Self::View {
        std::collections::BTreeMap::new()
    }

    fn reduce_view(
        &self,
        view: &mut Self::View,
        position: &transit_client::StreamPosition,
        payload: &[u8],
    ) -> anyhow::Result<()> {
        let _ = position;
        let key = format!("record-{}", view.len());
        view.insert(key, String::from_utf8(payload.to_vec())?);
        Ok(())
    }
}

let projection = client.read_projection(
    ProjectionReadRequest::new(StreamId::new("consumer.projection")?),
    ConsumerProjection,
)?;
```

## Contract Rules

- preserve `request_id` literally across wrapper boundaries
- preserve `ack.durability` and `ack.topology` literally
- preserve remote error `code` values literally
- keep projection reads replay-driven and rebuildable from authoritative history
- keep schema, policy, and reducer meaning outside Transit
- do not re-open embedded local Transit storage as a second authority for the
  same hosted workload

The upstream hard-cutover proof path for deleting duplicate local runtime or
private hosted client ownership is documented in
[`../../DIRECT_CUTOVER.md`](../../DIRECT_CUTOVER.md).
