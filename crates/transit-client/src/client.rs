use std::net::SocketAddr;

use transit_core::kernel::{LineageMetadata, MergeSpec, Offset, StreamId, StreamPosition};
use transit_core::server::{
    RemoteAcknowledged, RemoteAppendOutcome, RemoteClient, RemoteClientError, RemoteLineageOutcome,
    RemoteReadOutcome, RemoteStreamStatus, RemoteTailBatch, RemoteTailSessionCancelled,
    RemoteTailSessionOpened, TailSessionId,
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

    pub fn lineage(
        &self,
        stream_id: &StreamId,
    ) -> ClientResult<RemoteAcknowledged<RemoteLineageOutcome>> {
        self.inner.inspect_lineage(stream_id)
    }

    pub fn tail_open(
        &self,
        stream_id: &StreamId,
        from_offset: Offset,
        initial_credit: u64,
    ) -> ClientResult<RemoteAcknowledged<RemoteTailSessionOpened>> {
        self.inner
            .open_tail_session(stream_id, from_offset, initial_credit)
    }

    pub fn poll(
        &self,
        session_id: &TailSessionId,
        credit: u64,
    ) -> ClientResult<RemoteAcknowledged<RemoteTailBatch>> {
        self.inner.poll_tail_session(session_id, credit)
    }

    pub fn grant_credit(
        &self,
        session_id: &TailSessionId,
        credit: u64,
    ) -> ClientResult<RemoteAcknowledged<RemoteTailBatch>> {
        self.poll(session_id, credit)
    }

    pub fn cancel(
        &self,
        session_id: &TailSessionId,
    ) -> ClientResult<RemoteAcknowledged<RemoteTailSessionCancelled>> {
        self.inner.cancel_tail_session(session_id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    use transit_core::engine::LocalEngineConfig;
    use transit_core::kernel::{MergePolicy, MergePolicyKind, StreamLineage};
    use transit_core::server::{
        RemoteClientError, RemoteErrorCode, RemoteTailSessionState, RemoteTopology, ServerConfig,
        ServerHandle,
    };

    fn tail_test_client() -> (tempfile::TempDir, ServerHandle, TransitClient, StreamId) {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(
                temp_dir.path(),
                transit_core::membership::NodeId::new("test-node"),
            ),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let client = TransitClient::new(server.local_addr());
        let stream_id = StreamId::new("client.tail.root").expect("stream id");

        client
            .create_root(
                &stream_id,
                LineageMetadata::new(Some("client".into()), Some("tail-tests".into())),
            )
            .expect("create root");

        (temp_dir, server, client, stream_id)
    }

    fn lineage_test_client() -> (tempfile::TempDir, ServerHandle, TransitClient, StreamId) {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(
                temp_dir.path(),
                transit_core::membership::NodeId::new("test-node"),
            )
            .with_segment_max_records(8)
            .expect("config"),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let client = TransitClient::new(server.local_addr());
        let stream_id = StreamId::new("client.lineage.root").expect("stream id");

        client
            .create_root(
                &stream_id,
                LineageMetadata::new(Some("client".into()), Some("lineage-tests".into())),
            )
            .expect("create root");

        (temp_dir, server, client, stream_id)
    }

    #[test]
    fn tail_open_opens_a_tail_session_with_initial_credit() {
        let (_temp_dir, server, client, stream_id) = tail_test_client();

        client.append(&stream_id, b"first").expect("append first");

        let opened = client
            .tail_open(&stream_id, Offset::new(0), 1)
            .expect("open tail");

        assert_eq!(opened.ack().durability(), "local");
        assert_eq!(opened.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(opened.body().stream_id(), &stream_id);
        assert_eq!(opened.body().requested_credit(), 1);
        assert_eq!(opened.body().delivered_credit(), 1);
        assert_eq!(opened.body().records().len(), 1);
        assert_eq!(opened.body().records()[0].payload(), b"first".as_slice());
        assert_eq!(opened.body().state(), RemoteTailSessionState::Active);
        assert!(opened.body().session_id().as_str().starts_with("tail-"));

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn tail_poll_grant_credit_and_cancel_follow_server_session_lifecycle() {
        let (_temp_dir, server, client, stream_id) = tail_test_client();

        client.append(&stream_id, b"first").expect("append first");
        client.append(&stream_id, b"second").expect("append second");
        client.append(&stream_id, b"third").expect("append third");

        let opened = client
            .tail_open(&stream_id, Offset::new(0), 1)
            .expect("open tail");
        let session_id = opened.body().session_id().clone();

        let second_batch = client
            .grant_credit(&session_id, 1)
            .expect("grant credit for second batch");
        let third_batch = client.poll(&session_id, 1).expect("poll third batch");
        let waiting_batch = client.poll(&session_id, 1).expect("poll awaiting batch");
        let cancelled = client.cancel(&session_id).expect("cancel tail session");

        assert_eq!(second_batch.body().records().len(), 1);
        assert_eq!(
            second_batch.body().records()[0].payload(),
            b"second".as_slice()
        );
        assert_eq!(second_batch.body().delivered_credit(), 1);
        assert_eq!(third_batch.body().records().len(), 1);
        assert_eq!(
            third_batch.body().records()[0].payload(),
            b"third".as_slice()
        );
        assert_eq!(waiting_batch.body().records().len(), 0);
        assert_eq!(
            waiting_batch.body().state(),
            RemoteTailSessionState::AwaitingRecords
        );
        assert_eq!(cancelled.body().session_id(), &session_id);
        assert_eq!(cancelled.body().state(), RemoteTailSessionState::Cancelled);

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn tail_surfaces_server_backpressure_and_missing_session_errors() {
        let (_temp_dir, server, client, stream_id) = tail_test_client();

        let opened = client
            .tail_open(&stream_id, Offset::new(0), 1)
            .expect("open tail");
        let session_id = opened.body().session_id().clone();

        let excessive_credit = client
            .grant_credit(&session_id, 300)
            .expect_err("credit above max should fail");
        match excessive_credit {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::InvalidRequest);
                assert!(error.message().contains("exceeds max"));
            }
            other => panic!("expected invalid_request for excessive credit, got {other:?}"),
        }

        client.cancel(&session_id).expect("cancel session");
        let missing_poll = client
            .poll(&session_id, 1)
            .expect_err("poll after cancel should fail");
        match missing_poll {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::NotFound);
                assert!(error.message().contains("tail session"));
            }
            other => panic!("expected tail session not_found, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn lineage_returns_branch_and_merge_relationships() {
        let (_temp_dir, server, client, root_stream) = lineage_test_client();
        let branch_a = StreamId::new("client.lineage.retry").expect("branch a");
        let branch_b = StreamId::new("client.lineage.critique").expect("branch b");
        let merge_stream = StreamId::new("client.lineage.merge").expect("merge stream");

        client.append(&root_stream, b"seed").expect("append seed");
        client
            .create_branch(
                &branch_a,
                StreamPosition::new(root_stream.clone(), Offset::new(0)),
                LineageMetadata::new(Some("agent.retry".into()), Some("explore".into())),
            )
            .expect("create branch a");
        client
            .create_branch(
                &branch_b,
                StreamPosition::new(root_stream.clone(), Offset::new(0)),
                LineageMetadata::new(Some("agent.critique".into()), Some("explore".into())),
            )
            .expect("create branch b");
        client.append(&branch_a, b"retry").expect("append branch a");
        client
            .append(&branch_b, b"critique")
            .expect("append branch b");

        let merge_spec = MergeSpec::new(
            vec![
                StreamPosition::new(branch_a.clone(), Offset::new(1)),
                StreamPosition::new(branch_b.clone(), Offset::new(1)),
            ],
            Some(StreamPosition::new(root_stream.clone(), Offset::new(0))),
            MergePolicy::new(MergePolicyKind::Recursive).with_metadata("resolver", "judge-v1"),
            LineageMetadata::new(Some("agent.judge".into()), Some("merge".into())),
        )
        .expect("merge spec");
        client
            .create_merge(&merge_stream, merge_spec.clone())
            .expect("create merge");

        let branch_lineage = client.lineage(&branch_a).expect("inspect branch lineage");
        let merge_lineage = client
            .lineage(&merge_stream)
            .expect("inspect merge lineage");

        assert_eq!(branch_lineage.ack().durability(), "local");
        assert_eq!(branch_lineage.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(branch_lineage.body().status().stream_id(), &branch_a);
        assert_eq!(branch_lineage.body().status().next_offset().value(), 2);
        match &branch_lineage.body().descriptor().lineage {
            StreamLineage::Branch { branch_point } => {
                assert_eq!(branch_point.parent.stream_id, root_stream);
                assert_eq!(branch_point.parent.offset.value(), 0);
            }
            other => panic!("expected branch lineage, got {other:?}"),
        }

        assert_eq!(merge_lineage.ack().durability(), "local");
        assert_eq!(merge_lineage.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(merge_lineage.body().status().stream_id(), &merge_stream);
        assert_eq!(merge_lineage.body().status().next_offset().value(), 1);
        match &merge_lineage.body().descriptor().lineage {
            StreamLineage::Merge { merge } => assert_eq!(merge, &merge_spec),
            other => panic!("expected merge lineage, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn lineage_surfaces_server_acknowledgement_and_error_envelopes() {
        let (_temp_dir, server, client, root_stream) = lineage_test_client();
        let missing_stream = StreamId::new("client.lineage.missing").expect("missing stream");

        client.append(&root_stream, b"seed").expect("append seed");
        let lineage = client.lineage(&root_stream).expect("inspect root lineage");
        assert_eq!(lineage.ack().durability(), "local");
        assert_eq!(lineage.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(lineage.body().status().stream_id(), &root_stream);
        assert_eq!(lineage.body().status().next_offset().value(), 1);

        let missing = client
            .lineage(&missing_stream)
            .expect_err("missing stream lineage should fail");
        match missing {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::NotFound);
                assert_eq!(error.topology(), RemoteTopology::SingleNode);
                assert!(!error.request_id().as_str().is_empty());
                assert!(!error.message().is_empty());
            }
            other => panic!("expected remote not_found, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }
}
