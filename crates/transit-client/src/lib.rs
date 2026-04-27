//! Canonical Rust client surface for hosted `transit` consumers.
//!
//! Downstream Rust repos should prefer importing hosted request, response, and
//! stream vocabulary from `transit-client` rather than reaching into
//! `transit-core::server` directly or re-defining a second hosted client
//! contract locally.
//!
//! `TransitClient` is the thin operation wrapper. The crate root also
//! re-exports the kernel input types and the hosted response/error vocabulary
//! needed for append, batch append, read, branch, lineage, and tail
//! operations.

mod client;
mod projection;

pub use transit_core::cursor::CursorAck;
pub use transit_core::kernel::{
    Cursor, CursorId, LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset,
    StreamDescriptor, StreamId, StreamLineage, StreamPosition, StreamRetentionPolicy,
};
pub use transit_core::materialization::{
    HostedMaterializationCheckpoint, HostedMaterializationResumeCursor,
};
pub use transit_core::server::{
    APPEND_BATCH_MAX_BYTES, APPEND_BATCH_MAX_RECORDS, RemoteAcknowledged, RemoteAcknowledgement,
    RemoteAppendOutcome, RemoteBatchAppendOutcome, RemoteClientError, RemoteCursorDeletedOutcome,
    RemoteDeletedStreamOutcome, RemoteErrorCode, RemoteErrorResponse, RemoteLineageOutcome,
    RemoteMaterializationCheckpointDeletedOutcome, RemoteReadOutcome, RemoteReadPageOutcome,
    RemoteRecord, RemoteStreamListOutcome, RemoteStreamStatus, RemoteStreamSummary,
    RemoteTailBatch, RemoteTailSessionCancelled, RemoteTailSessionOpened, RemoteTailSessionState,
    RemoteTopology, RequestId, TailSessionId,
};

pub use client::{ClientResult, HostedMaterializationResume, TransitClient};
pub use projection::{ProjectionReadConsumer, ProjectionReadOutcome, ProjectionReadRequest};
