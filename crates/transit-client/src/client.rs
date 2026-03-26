use std::net::SocketAddr;

use transit_core::kernel::{LineageMetadata, MergeSpec, StreamId, StreamPosition};
use transit_core::server::{
    RemoteAcknowledged, RemoteAppendOutcome, RemoteClient, RemoteClientError, RemoteReadOutcome,
    RemoteStreamStatus,
};

pub type ClientResult<T> = std::result::Result<T, RemoteClientError>;

/// Thin Rust wrapper over the shared remote protocol client.
#[derive(Debug, Clone)]
pub struct TransitClient {
    inner: RemoteClient,
}

impl TransitClient {
    pub fn new(server_addr: SocketAddr) -> Self {
        Self {
            inner: RemoteClient::new(server_addr),
        }
    }

    pub fn create_root(
        &self,
        stream_id: &StreamId,
        metadata: LineageMetadata,
    ) -> ClientResult<RemoteAcknowledged<RemoteStreamStatus>> {
        self.inner.create_root(stream_id, metadata)
    }

    pub fn append(
        &self,
        stream_id: &StreamId,
        payload: impl AsRef<[u8]>,
    ) -> ClientResult<RemoteAcknowledged<RemoteAppendOutcome>> {
        self.inner.append(stream_id, payload)
    }

    pub fn read(
        &self,
        stream_id: &StreamId,
    ) -> ClientResult<RemoteAcknowledged<RemoteReadOutcome>> {
        self.inner.read(stream_id)
    }

    pub fn create_branch(
        &self,
        stream_id: &StreamId,
        parent: StreamPosition,
        metadata: LineageMetadata,
    ) -> ClientResult<RemoteAcknowledged<RemoteStreamStatus>> {
        self.inner.create_branch(stream_id, parent, metadata)
    }

    pub fn create_merge(
        &self,
        stream_id: &StreamId,
        merge: MergeSpec,
    ) -> ClientResult<RemoteAcknowledged<RemoteStreamStatus>> {
        self.inner.create_merge(stream_id, merge)
    }
}
