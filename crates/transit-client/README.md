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

- `TransitClient` for hosted append, read, projection read, branch, merge,
  lineage, and tail operations
- stream input types such as `StreamId`, `Offset`, `StreamPosition`,
  `LineageMetadata`, and `MergeSpec`
- projection consumer types such as `ProjectionReadRequest`,
  `ProjectionReadOutcome<V>`, and `ProjectionReadConsumer`
- hosted response and error types such as `RemoteAcknowledged<T>`,
  `RemoteAcknowledgement`, `RemoteErrorResponse`, `RemoteErrorCode`, and
  `RemoteTailSessionState`

Typical downstream imports should look like:

```rust
use transit_client::{
    LineageMetadata, MergeSpec, Offset, ProjectionReadConsumer,
    ProjectionReadRequest, RemoteAcknowledged, RemoteErrorCode, StreamId,
    StreamPosition, TailSessionId, TransitClient,
};
```

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
