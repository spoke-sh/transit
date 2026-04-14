# transit-client

Canonical Rust client surface for hosted `transit` consumers.

Downstream Rust repos should import hosted consumer operations and response
types from this crate instead of:

- copying a private hosted Transit client into another repo
- reaching into `transit-core::server` to assemble a second public consumer
  boundary
- treating embedded local engine types as the authority for hosted workloads

## Import Surface

This crate publishes three parts of the hosted consumer boundary:

- `TransitClient` for hosted append, read, branch, merge, lineage, and tail
  operations
- stream input types such as `StreamId`, `Offset`, `StreamPosition`,
  `LineageMetadata`, and `MergeSpec`
- hosted response and error types such as `RemoteAcknowledged<T>`,
  `RemoteAcknowledgement`, `RemoteErrorResponse`, `RemoteErrorCode`, and
  `RemoteTailSessionState`

Typical downstream imports should look like:

```rust
use transit_client::{
    LineageMetadata, MergeSpec, Offset, RemoteAcknowledged, RemoteErrorCode,
    StreamId, StreamPosition, TailSessionId, TransitClient,
};
```

## Contract Rules

- preserve `request_id` literally across wrapper boundaries
- preserve `ack.durability` and `ack.topology` literally
- preserve remote error `code` values literally
- keep schema, policy, and reducer meaning outside Transit
- do not re-open embedded local Transit storage as a second authority for the
  same hosted workload

The upstream hard-cutover proof path for deleting duplicate local runtime or
private hosted client ownership is documented in
[`../../DIRECT_CUTOVER.md`](../../DIRECT_CUTOVER.md).
