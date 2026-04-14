//! Canonical Rust client surface for hosted `transit` consumers.
//!
//! Downstream Rust repos should prefer importing hosted request, response, and
//! stream vocabulary from `transit-client` rather than reaching into
//! `transit-core::server` directly or re-defining a second hosted client
//! contract locally.
//!
//! `TransitClient` is the thin operation wrapper. The crate root also
//! re-exports the kernel input types and the hosted response/error vocabulary
//! needed for append, read, branch, lineage, and tail operations.

mod client;

pub use transit_core::kernel::{
    LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset, StreamDescriptor, StreamId,
    StreamLineage, StreamPosition,
};
pub use transit_core::server::{
    RemoteAcknowledged, RemoteAcknowledgement, RemoteAppendOutcome, RemoteClientError,
    RemoteDeletedStreamOutcome, RemoteErrorCode, RemoteErrorResponse, RemoteLineageOutcome,
    RemoteReadOutcome, RemoteRecord, RemoteStreamListOutcome, RemoteStreamStatus,
    RemoteStreamSummary, RemoteTailBatch, RemoteTailSessionCancelled, RemoteTailSessionOpened,
    RemoteTailSessionState, RemoteTopology, RequestId, TailSessionId,
};

pub use client::{ClientResult, TransitClient};
