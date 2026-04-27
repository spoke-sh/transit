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
- hosted cursor and materialization types such as `Cursor`, `CursorId`,
  `HostedMaterializationCheckpoint`, and `HostedMaterializationResume`

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

## Bounded Reads

Downstream readers that cannot receive a full stream in one response can page
through the same hosted boundary:

```rust
use transit_client::{Offset, StreamId, TransitClient};

let stream_id = StreamId::new("consumer.orders")?;
let mut next = Offset::new(0);

loop {
    let page = client.read_page(&stream_id, next, 128)?;
    for record in page.body().records() {
        // reduce record into downstream state
    }
    if !page.body().has_more() {
        break;
    }
    next = page.body().next_offset();
}
```

`read_page` and `tail_page` preserve the normal hosted response envelope:
request id correlation, acknowledgement durability, topology, and remote error
semantics are unchanged. The page body carries `next_offset` and `has_more` so
callers can continue without receiving complete stream history.

## Hosted Materialization

`transit-client` now exposes the hosted primitives a client-only materializer
needs when Transit runs as a separate daemon:

- durable hosted consumer cursors
- hosted materialization checkpoints bound to source-stream lineage
- hosted resume that replays only records after the checkpoint anchor

Typical hosted materializer flow:

```rust
use transit_client::{CursorId, LineageMetadata, Offset, StreamId, TransitClient};

let stream_id = StreamId::new("consumer.orders")?;
let materialization_id = "consumer.analytics/orders";
let cursor_id = CursorId::new("consumer.analytics/orders")?;

client.create_root(
    &stream_id,
    LineageMetadata::new(Some("consumer".into()), Some("bootstrap".into())),
)?;
client.append(&stream_id, br#"{"order_id":"order-1","status":"created"}"#)?;
client.append(&stream_id, br#"{"order_id":"order-1","status":"paid"}"#)?;

let checkpoint = client.materialize_checkpoint(
    &stream_id,
    materialization_id,
    br#"{"processed_records":2}"#.to_vec(),
)?;

client.create_cursor(
    &cursor_id,
    &stream_id,
    checkpoint.body().lineage_anchor().head_offset,
    LineageMetadata::new(Some("consumer".into()), Some("progress".into())),
)?;

client.append(&stream_id, br#"{"order_id":"order-1","status":"shipped"}"#)?;

let resumed = client.materialize_resume(checkpoint.body())?;
assert_eq!(resumed.replay_from().value(), 2);

for record in resumed.pending_records() {
    // reduce opaque state from authoritative replay
    let _ = record;
}

client.ack_cursor(
    &cursor_id,
    Offset::new(resumed.source_next_offset().value() - 1),
)?;
```

Hosted checkpoints are verification-bearing, not just saved offsets:

- `materialize_checkpoint(...)` binds opaque state to the current source-stream
  lineage checkpoint
- `get_materialization_checkpoint(...)` reloads the persisted hosted checkpoint
- `materialize_resume(...)` resumes from the stored anchor and returns only the
  pending records after that anchor
- `resume_materialization_cursor(...)` exposes the resume window itself when you
  want the replay cursor without fetching records immediately

Expected failure behavior is explicit:

- if the source stream no longer verifies against the checkpoint anchor, hosted
  resume fails
- if the checkpoint payload has been tampered with, hosted resume fails through
  the normal remote `invalid_request` surface
- if retained history has advanced past the checkpoint anchor, hosted resume
  fails instead of silently replaying from an unverifiable position

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
