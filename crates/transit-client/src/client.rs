use anyhow::Context;
use std::net::SocketAddr;
use std::time::Duration;

use crate::projection::{
    ProjectionReadConsumer, ProjectionReadOutcome, ProjectionReadRequest, projection_revision_for,
};
use transit_core::kernel::{
    Cursor, CursorId, LineageMetadata, MergeSpec, Offset, StreamId, StreamPosition,
    StreamRetentionPolicy,
};
use transit_core::materialization::{
    HostedMaterializationCheckpoint, HostedMaterializationResumeCursor,
};
use transit_core::server::{
    RemoteAcknowledged, RemoteAppendOutcome, RemoteBatchAppendOutcome, RemoteClient,
    RemoteClientError, RemoteCursorDeletedOutcome, RemoteDeletedStreamOutcome,
    RemoteLineageOutcome, RemoteMaterializationCheckpointDeletedOutcome, RemoteReadOutcome,
    RemoteReadPageOutcome, RemoteRecord, RemoteStreamListOutcome, RemoteStreamStatus,
    RemoteTailBatch, RemoteTailSessionCancelled, RemoteTailSessionOpened, TailSessionId,
};

pub type ClientResult<T> = std::result::Result<T, RemoteClientError>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HostedMaterializationResume {
    cursor: HostedMaterializationResumeCursor,
    pending_records: Vec<RemoteRecord>,
}

impl HostedMaterializationResume {
    pub fn new(
        cursor: HostedMaterializationResumeCursor,
        pending_records: Vec<RemoteRecord>,
    ) -> Self {
        Self {
            cursor,
            pending_records,
        }
    }

    pub fn checkpoint(&self) -> &HostedMaterializationCheckpoint {
        self.cursor.checkpoint()
    }

    pub fn replay_from(&self) -> Offset {
        self.cursor.replay_from()
    }

    pub fn source_next_offset(&self) -> Offset {
        self.cursor.source_next_offset()
    }

    pub fn pending_record_count(&self) -> u64 {
        self.cursor.pending_record_count()
    }

    pub fn is_caught_up(&self) -> bool {
        self.cursor.is_caught_up()
    }

    pub fn pending_records(&self) -> &[RemoteRecord] {
        &self.pending_records
    }
}

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

    pub fn with_io_timeout(mut self, timeout: Duration) -> Self {
        self.inner = self.inner.with_io_timeout(timeout);
        self
    }

    pub fn with_auth_token(mut self, token: impl Into<String>) -> Self {
        self.inner = self.inner.with_auth_token(token);
        self
    }

    pub fn io_timeout(&self) -> Duration {
        self.inner.io_timeout()
    }

    pub fn create_root(
        &self,
        stream_id: &StreamId,
        metadata: LineageMetadata,
    ) -> ClientResult<RemoteAcknowledged<RemoteStreamStatus>> {
        self.inner.create_root(stream_id, metadata)
    }

    pub fn create_root_with_retention(
        &self,
        stream_id: &StreamId,
        metadata: LineageMetadata,
        retention_policy: Option<StreamRetentionPolicy>,
    ) -> ClientResult<RemoteAcknowledged<RemoteStreamStatus>> {
        self.inner
            .create_root_with_retention(stream_id, metadata, retention_policy)
    }

    pub fn list_streams(&self) -> ClientResult<RemoteAcknowledged<RemoteStreamListOutcome>> {
        self.inner.list_streams()
    }

    pub fn delete_stream(
        &self,
        stream_id: &StreamId,
    ) -> ClientResult<RemoteAcknowledged<RemoteDeletedStreamOutcome>> {
        self.inner.delete_stream(stream_id)
    }

    pub fn append(
        &self,
        stream_id: &StreamId,
        payload: impl AsRef<[u8]>,
    ) -> ClientResult<RemoteAcknowledged<RemoteAppendOutcome>> {
        self.inner.append(stream_id, payload)
    }

    pub fn append_batch<I, P>(
        &self,
        stream_id: &StreamId,
        payloads: I,
    ) -> ClientResult<RemoteAcknowledged<RemoteBatchAppendOutcome>>
    where
        I: IntoIterator<Item = P>,
        P: AsRef<[u8]>,
    {
        self.inner.append_batch(stream_id, payloads)
    }

    pub fn read(
        &self,
        stream_id: &StreamId,
    ) -> ClientResult<RemoteAcknowledged<RemoteReadOutcome>> {
        self.inner.read(stream_id)
    }

    pub fn read_page(
        &self,
        stream_id: &StreamId,
        from_offset: Offset,
        max_records: usize,
    ) -> ClientResult<RemoteAcknowledged<RemoteReadPageOutcome>> {
        self.inner.read_page(stream_id, from_offset, max_records)
    }

    pub fn read_projection<C>(
        &self,
        request: ProjectionReadRequest,
        consumer: C,
    ) -> ClientResult<RemoteAcknowledged<ProjectionReadOutcome<C::View>>>
    where
        C: ProjectionReadConsumer,
    {
        let projection_ref = request.projection_ref().clone();
        let checkpoint_id = request.checkpoint_id().map(ToOwned::to_owned);
        let response = self.read(&projection_ref)?;
        let body = response.body();
        let mut view = consumer.initial_view();

        for record in body.records() {
            consumer
                .reduce_view(&mut view, record.position(), record.payload())
                .with_context(|| {
                    format!(
                        "reduce projection '{}' at offset {}",
                        body.stream_id().as_str(),
                        record.position().offset.value()
                    )
                })
                .map_err(|error| RemoteClientError::Protocol(format!("{error:#}")))?;
        }

        let consumed_records = body.records().len();
        let stream_id = body.stream_id().clone();
        let head_offset = body.records().last().map(|record| record.position().offset);
        let projection_revision =
            head_offset.map(|offset| projection_revision_for(body.stream_id(), offset));
        let checkpoint_matches = checkpoint_id
            .as_ref()
            .zip(projection_revision.as_ref())
            .is_some_and(|(checkpoint_id, revision)| checkpoint_id == revision);

        Ok(response.map_body(|_| {
            ProjectionReadOutcome::new(
                stream_id,
                consumed_records,
                head_offset,
                projection_revision,
                checkpoint_id,
                checkpoint_matches,
                view,
            )
        }))
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

    pub fn create_cursor(
        &self,
        cursor_id: &CursorId,
        stream_id: &StreamId,
        position: Offset,
        metadata: LineageMetadata,
    ) -> ClientResult<RemoteAcknowledged<Cursor>> {
        self.inner
            .create_cursor(cursor_id, stream_id, position, metadata)
    }

    pub fn get_cursor(&self, cursor_id: &CursorId) -> ClientResult<RemoteAcknowledged<Cursor>> {
        self.inner.get_cursor(cursor_id)
    }

    pub fn advance_cursor(
        &self,
        cursor_id: &CursorId,
        position: Offset,
    ) -> ClientResult<RemoteAcknowledged<transit_core::cursor::CursorAck>> {
        self.inner.advance_cursor(cursor_id, position)
    }

    pub fn ack_cursor(
        &self,
        cursor_id: &CursorId,
        position: Offset,
    ) -> ClientResult<RemoteAcknowledged<transit_core::cursor::CursorAck>> {
        self.inner.ack_cursor(cursor_id, position)
    }

    pub fn delete_cursor(
        &self,
        cursor_id: &CursorId,
    ) -> ClientResult<RemoteAcknowledged<RemoteCursorDeletedOutcome>> {
        self.inner.delete_cursor(cursor_id)
    }

    pub fn materialize_checkpoint(
        &self,
        stream_id: &StreamId,
        materialization_id: impl Into<String>,
        opaque_state: Vec<u8>,
    ) -> ClientResult<RemoteAcknowledged<HostedMaterializationCheckpoint>> {
        self.inner
            .materialize_checkpoint(stream_id, materialization_id, opaque_state)
    }

    #[allow(clippy::too_many_arguments)]
    pub fn materialize_checkpoint_with_contract(
        &self,
        stream_id: &StreamId,
        materialization_id: impl Into<String>,
        view_kind: impl Into<String>,
        opaque_state: Vec<u8>,
        opaque_state_ref: Option<String>,
        snapshot_ref: Option<String>,
        materializer_version: impl Into<String>,
    ) -> ClientResult<RemoteAcknowledged<HostedMaterializationCheckpoint>> {
        self.inner.materialize_checkpoint_with_contract(
            stream_id,
            materialization_id,
            view_kind,
            opaque_state,
            opaque_state_ref,
            snapshot_ref,
            materializer_version,
        )
    }

    pub fn get_materialization_checkpoint(
        &self,
        materialization_id: impl Into<String>,
        stream_id: &StreamId,
    ) -> ClientResult<RemoteAcknowledged<HostedMaterializationCheckpoint>> {
        self.inner
            .get_materialization_checkpoint(materialization_id, stream_id)
    }

    pub fn delete_materialization_checkpoint(
        &self,
        materialization_id: impl Into<String>,
        stream_id: &StreamId,
    ) -> ClientResult<RemoteAcknowledged<RemoteMaterializationCheckpointDeletedOutcome>> {
        self.inner
            .delete_materialization_checkpoint(materialization_id, stream_id)
    }

    pub fn resume_materialization_cursor(
        &self,
        checkpoint: &HostedMaterializationCheckpoint,
    ) -> ClientResult<RemoteAcknowledged<HostedMaterializationResumeCursor>> {
        self.inner.resume_materialization(checkpoint)
    }

    pub fn materialize_resume(
        &self,
        checkpoint: &HostedMaterializationCheckpoint,
    ) -> ClientResult<HostedMaterializationResume> {
        let resume_cursor = self.resume_materialization_cursor(checkpoint)?;
        let pending_records = if resume_cursor.body().is_caught_up() {
            Vec::new()
        } else {
            self.inner
                .tail(
                    checkpoint.source_stream_id(),
                    resume_cursor.body().replay_from(),
                )?
                .body()
                .records()
                .to_vec()
        };
        Ok(HostedMaterializationResume::new(
            resume_cursor.into_body(),
            pending_records,
        ))
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

    pub fn tail_page(
        &self,
        stream_id: &StreamId,
        from_offset: Offset,
        max_records: usize,
    ) -> ClientResult<RemoteAcknowledged<RemoteReadPageOutcome>> {
        self.inner.tail_page(stream_id, from_offset, max_records)
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
    use crate::projection::ProjectionReadRequest;
    use anyhow::{Context, Result, bail};
    use serde::{Deserialize, Serialize};
    use std::collections::BTreeMap;
    use tempfile::tempdir;
    use transit_core::engine::LocalEngineConfig;
    use transit_core::kernel::{MergePolicy, MergePolicyKind, StreamLineage};
    use transit_core::server::{
        RemoteClientError, RemoteErrorCode, RemoteTailSessionState, RemoteTopology, ServerConfig,
        ServerHandle,
    };

    fn tail_test_client() -> (tempfile::TempDir, ServerHandle, TransitClient, StreamId) {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(
            ServerConfig::new(
                LocalEngineConfig::new(
                    temp_dir.path(),
                    transit_core::membership::NodeId::new("test-node"),
                ),
                "127.0.0.1:0".parse().expect("listen addr"),
            )
            .with_connection_io_timeout(Duration::from_secs(5)),
        )
        .expect("bind server");
        let client =
            TransitClient::new(server.local_addr()).with_io_timeout(Duration::from_secs(5));
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
        let server = ServerHandle::bind(
            ServerConfig::new(
                LocalEngineConfig::new(
                    temp_dir.path(),
                    transit_core::membership::NodeId::new("test-node"),
                )
                .with_segment_max_records(8)
                .expect("config"),
                "127.0.0.1:0".parse().expect("listen addr"),
            )
            .with_connection_io_timeout(Duration::from_secs(5)),
        )
        .expect("bind server");
        let client =
            TransitClient::new(server.local_addr()).with_io_timeout(Duration::from_secs(5));
        let stream_id = StreamId::new("client.lineage.root").expect("stream id");

        client
            .create_root(
                &stream_id,
                LineageMetadata::new(Some("client".into()), Some("lineage-tests".into())),
            )
            .expect("create root");

        (temp_dir, server, client, stream_id)
    }

    fn hosted_authority_test_client() -> (tempfile::TempDir, ServerHandle, TransitClient) {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(
            ServerConfig::new(
                LocalEngineConfig::new(
                    temp_dir.path(),
                    transit_core::membership::NodeId::new("hosted-authority-node"),
                )
                .with_segment_max_records(4)
                .expect("config"),
                "127.0.0.1:0".parse().expect("listen addr"),
            )
            .with_connection_io_timeout(Duration::from_secs(5)),
        )
        .expect("bind server");
        let client =
            TransitClient::new(server.local_addr()).with_io_timeout(Duration::from_secs(5));

        (temp_dir, server, client)
    }

    #[test]
    fn hosted_timeout_config_client_allows_explicit_timeout_override() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let client = client.with_io_timeout(Duration::from_secs(5));

        assert_eq!(client.io_timeout(), Duration::from_secs(5));

        let stream_id = StreamId::new("client.timeout.override").expect("stream id");
        let created = client
            .create_root(
                &stream_id,
                LineageMetadata::new(Some("client".into()), Some("timeout-config-tests".into())),
            )
            .expect("create root");

        assert_eq!(created.ack().durability(), "local");
        assert_eq!(created.ack().topology(), RemoteTopology::SingleNode);

        let appended = client
            .append(&stream_id, b"payload")
            .expect("append with tuned timeout");
        assert_eq!(appended.ack().durability(), "local");
        assert_eq!(appended.ack().topology(), RemoteTopology::SingleNode);

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn hosted_timeout_config_client_preserves_remote_error_envelope() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let client = client.with_io_timeout(Duration::from_secs(5));
        let missing_stream = StreamId::new("client.timeout.missing").expect("stream id");

        let error = client
            .append(&missing_stream, b"payload")
            .expect_err("append should fail for missing stream");

        match error {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::NotFound);
                assert_eq!(error.request_id().as_str(), "req-1");
                assert!(!error.message().is_empty());
            }
            other => panic!("expected remote error envelope, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[derive(Debug, Clone, PartialEq, Eq)]
    struct ProjectionView {
        display_name: String,
        status: String,
    }

    #[derive(Debug, Clone, Serialize, Deserialize)]
    struct ProjectionEvent {
        reference_id: String,
        display_name: String,
        status: String,
        deleted: bool,
    }

    struct ReferenceProjectionConsumer;

    impl ProjectionReadConsumer for ReferenceProjectionConsumer {
        type View = BTreeMap<String, ProjectionView>;

        fn initial_view(&self) -> Self::View {
            BTreeMap::new()
        }

        fn reduce_view(
            &self,
            view: &mut Self::View,
            _position: &transit_core::kernel::StreamPosition,
            payload: &[u8],
        ) -> Result<()> {
            let event: ProjectionEvent =
                serde_json::from_slice(payload).context("deserialize projection event")?;
            if event.deleted {
                view.remove(&event.reference_id);
            } else {
                view.insert(
                    event.reference_id,
                    ProjectionView {
                        display_name: event.display_name,
                        status: event.status,
                    },
                );
            }
            Ok(())
        }
    }

    struct FailingProjectionConsumer;

    impl ProjectionReadConsumer for FailingProjectionConsumer {
        type View = ();

        fn initial_view(&self) -> Self::View {}

        fn reduce_view(
            &self,
            _view: &mut Self::View,
            _position: &transit_core::kernel::StreamPosition,
            _payload: &[u8],
        ) -> Result<()> {
            bail!("synthetic reducer failure")
        }
    }

    fn projection_event(
        reference_id: &str,
        display_name: &str,
        status: &str,
        deleted: bool,
    ) -> Vec<u8> {
        serde_json::to_vec(&ProjectionEvent {
            reference_id: reference_id.to_owned(),
            display_name: display_name.to_owned(),
            status: status.to_owned(),
            deleted,
        })
        .expect("serialize projection event")
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

    #[test]
    fn hosted_authority_appends_and_replays_consumer_records_through_server() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let stream_id = StreamId::new("client.hosted.orders").expect("stream id");

        let created = client
            .create_root(
                &stream_id,
                LineageMetadata::new(
                    Some("hub.producer".into()),
                    Some("hosted-authority-proof".into()),
                ),
            )
            .expect("create root");
        let first_payload = br#"{"consumer":"hub","record":"order.created","id":"order-1"}"#;
        let second_payload = br#"{"consumer":"hub","record":"order.shipped","id":"order-1"}"#;

        let first_append = client
            .append(&stream_id, first_payload)
            .expect("append first");
        let second_append = client
            .append(&stream_id, second_payload)
            .expect("append second");
        let replay = client.read(&stream_id).expect("read");

        assert_eq!(created.ack().durability(), "local");
        assert_eq!(created.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(first_append.ack().durability(), "local");
        assert_eq!(first_append.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(second_append.ack().durability(), "local");
        assert_eq!(second_append.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(replay.ack().durability(), "local");
        assert_eq!(replay.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(first_append.body().position().offset.value(), 0);
        assert_eq!(second_append.body().position().offset.value(), 1);
        assert_eq!(
            replay
                .body()
                .records()
                .iter()
                .map(|record| record.payload())
                .collect::<Vec<_>>(),
            vec![first_payload.as_slice(), second_payload.as_slice()]
        );

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn hosted_authority_exposes_bounded_read_pages() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let stream_id = StreamId::new("client.hosted.pages").expect("stream id");

        client
            .create_root(
                &stream_id,
                LineageMetadata::new(Some("hub.reader".into()), Some("hosted-page-proof".into())),
            )
            .expect("create root");
        for payload in [
            b"first".as_slice(),
            b"second".as_slice(),
            b"third".as_slice(),
        ] {
            client.append(&stream_id, payload).expect("append");
        }

        let first_page = client
            .read_page(&stream_id, Offset::new(0), 2)
            .expect("read page");
        let tail_page = client
            .tail_page(&stream_id, first_page.body().next_offset(), 2)
            .expect("tail page");

        assert_eq!(first_page.ack().durability(), "local");
        assert_eq!(first_page.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(first_page.body().stream_id(), &stream_id);
        assert_eq!(first_page.body().from_offset().value(), 0);
        assert_eq!(first_page.body().max_records(), 2);
        assert_eq!(first_page.body().next_offset().value(), 2);
        assert!(first_page.body().has_more());
        assert_eq!(
            first_page
                .body()
                .records()
                .iter()
                .map(|record| record.payload())
                .collect::<Vec<_>>(),
            vec![b"first".as_slice(), b"second".as_slice()]
        );

        assert_eq!(tail_page.ack().durability(), "local");
        assert_eq!(tail_page.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(tail_page.body().from_offset().value(), 2);
        assert_eq!(tail_page.body().next_offset().value(), 3);
        assert!(!tail_page.body().has_more());
        assert_eq!(tail_page.body().records()[0].payload(), b"third");

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn batch_append_preserves_acknowledgement_envelope_and_replays_individual_records() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let stream_id = StreamId::new("client.hosted.batch").expect("stream id");

        client
            .create_root(
                &stream_id,
                LineageMetadata::new(
                    Some("hub.producer".into()),
                    Some("hosted-batch-proof".into()),
                ),
            )
            .expect("create root");

        let batch = client
            .append_batch(
                &stream_id,
                [
                    b"first".as_slice(),
                    b"second".as_slice(),
                    b"third".as_slice(),
                ],
            )
            .expect("append batch");
        let replay = client.read(&stream_id).expect("read");

        assert_eq!(batch.ack().durability(), "local");
        assert_eq!(batch.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(batch.body().first_position().offset.value(), 0);
        assert_eq!(batch.body().last_position().offset.value(), 2);
        assert_eq!(batch.body().record_count(), 3);
        assert_eq!(
            replay
                .body()
                .records()
                .iter()
                .map(|record| record.payload())
                .collect::<Vec<_>>(),
            vec![
                b"first".as_slice(),
                b"second".as_slice(),
                b"third".as_slice()
            ]
        );

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn batch_append_surfaces_hosted_invalid_request_errors() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let stream_id = StreamId::new("client.hosted.batch-errors").expect("stream id");

        client
            .create_root(
                &stream_id,
                LineageMetadata::new(
                    Some("hub.producer".into()),
                    Some("hosted-batch-proof".into()),
                ),
            )
            .expect("create root");

        let error = client
            .append_batch(&stream_id, Vec::<Vec<u8>>::new())
            .expect_err("empty batch should fail");
        match error {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::InvalidRequest);
                assert!(error.message().contains("at least one payload"));
            }
            other => panic!("expected invalid_request for batch append, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn hosted_authority_surfaces_local_acknowledgements_until_tiered_publication_exists() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let stream_id = StreamId::new("client.hosted.acks").expect("stream id");

        let created = client
            .create_root(
                &stream_id,
                LineageMetadata::new(
                    Some("hub.reader".into()),
                    Some("hosted-authority-proof".into()),
                ),
            )
            .expect("create root");
        let append = client
            .append(
                &stream_id,
                br#"{"consumer":"hub","record":"cache.invalidate","id":"job-7"}"#,
            )
            .expect("append");
        let replay = client.read(&stream_id).expect("read");

        assert_eq!(created.ack().durability(), "local");
        assert_eq!(append.ack().durability(), "local");
        assert_eq!(replay.ack().durability(), "local");
        assert_eq!(created.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(append.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(replay.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(replay.body().records().len(), 1);

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn projection_read_reduces_authoritative_replay_into_a_current_view() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let projection_stream = StreamId::new("client.projection.accounts").expect("stream id");

        client
            .create_root(
                &projection_stream,
                LineageMetadata::new(
                    Some("consumer".into()),
                    Some("projection-read-tests".into()),
                ),
            )
            .expect("create projection stream");
        client
            .append(
                &projection_stream,
                projection_event("acct-1", "Pilot", "active", false),
            )
            .expect("append acct-1");
        client
            .append(
                &projection_stream,
                projection_event("acct-2", "Copilot", "pending", false),
            )
            .expect("append acct-2");
        client
            .append(
                &projection_stream,
                projection_event("acct-1", "Pilot", "active", true),
            )
            .expect("append acct-1 delete");

        let projection = client
            .read_projection(
                ProjectionReadRequest::new(projection_stream.clone()),
                ReferenceProjectionConsumer,
            )
            .expect("read projection");

        assert_eq!(projection.ack().durability(), "local");
        assert_eq!(projection.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(projection.body().projection_ref(), &projection_stream);
        assert_eq!(projection.body().consumed_records(), 3);
        assert_eq!(projection.body().head_offset(), Some(Offset::new(2)));
        assert_eq!(
            projection.body().projection_revision(),
            Some("projection:client.projection.accounts@2")
        );
        assert!(!projection.body().checkpoint_matches());
        assert_eq!(projection.body().view().len(), 1);
        assert_eq!(
            projection.body().view().get("acct-2"),
            Some(&ProjectionView {
                display_name: "Copilot".into(),
                status: "pending".into(),
            })
        );
        assert!(!projection.body().view().contains_key("acct-1"));

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn projection_read_surfaces_revision_and_checkpoint_match_metadata() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let projection_stream = StreamId::new("client.projection.sessions").expect("stream id");

        client
            .create_root(
                &projection_stream,
                LineageMetadata::new(
                    Some("consumer".into()),
                    Some("projection-read-tests".into()),
                ),
            )
            .expect("create projection stream");
        client
            .append(
                &projection_stream,
                projection_event("sess-1", "Session 1", "issued", false),
            )
            .expect("append projection");

        let initial = client
            .read_projection(
                ProjectionReadRequest::new(projection_stream.clone()),
                ReferenceProjectionConsumer,
            )
            .expect("initial projection");
        let revision = initial
            .body()
            .projection_revision()
            .expect("projection revision")
            .to_owned();

        let replayed = client
            .read_projection(
                ProjectionReadRequest::new(projection_stream.clone()).with_checkpoint_id(&revision),
                ReferenceProjectionConsumer,
            )
            .expect("replayed projection");

        assert_eq!(replayed.body().checkpoint_id(), Some(revision.as_str()));
        assert!(replayed.body().checkpoint_matches());
        assert_eq!(
            replayed.body().projection_revision(),
            Some(revision.as_str())
        );

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn projection_read_surfaces_reducer_failures_as_protocol_errors() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let projection_stream = StreamId::new("client.projection.failures").expect("stream id");

        client
            .create_root(
                &projection_stream,
                LineageMetadata::new(
                    Some("consumer".into()),
                    Some("projection-read-tests".into()),
                ),
            )
            .expect("create projection stream");
        client
            .append(
                &projection_stream,
                projection_event("broken", "Broken", "active", false),
            )
            .expect("append projection");

        let error = client
            .read_projection(
                ProjectionReadRequest::new(projection_stream),
                FailingProjectionConsumer,
            )
            .expect_err("failing reducer should error");

        match error {
            RemoteClientError::Protocol(message) => {
                assert!(message.contains("reduce projection"));
                assert!(message.contains("synthetic reducer failure"));
            }
            other => panic!("expected protocol error, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn cursor_lifecycle_is_available_from_transit_client() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let stream_id = StreamId::new("client.materialization.cursor").expect("stream id");
        let cursor_id = CursorId::new("consumer.analytics").expect("cursor id");

        client
            .create_root(
                &stream_id,
                LineageMetadata::new(
                    Some("consumer".into()),
                    Some("materialization-cursor-tests".into()),
                ),
            )
            .expect("create root");
        client
            .append(&stream_id, b"materialize-0")
            .expect("append record");

        let created = client
            .create_cursor(
                &cursor_id,
                &stream_id,
                Offset::new(1),
                LineageMetadata::new(Some("consumer".into()), Some("analytics".into())),
            )
            .expect("create cursor");
        assert_eq!(created.body().cursor_id, cursor_id);

        let loaded = client.get_cursor(&cursor_id).expect("get cursor");
        assert_eq!(loaded.body(), created.body());

        let acknowledged = client
            .ack_cursor(&cursor_id, Offset::new(1))
            .expect("ack cursor");
        assert_eq!(acknowledged.body().cursor_id, cursor_id);
        assert_eq!(acknowledged.body().stream_id, stream_id);

        let deleted = client.delete_cursor(&cursor_id).expect("delete cursor");
        assert_eq!(deleted.body().cursor_id().as_str(), cursor_id.as_str());

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn materialize_resume_replays_only_records_after_checkpoint_anchor() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let stream_id = StreamId::new("client.materialization.resume").expect("stream id");

        client
            .create_root(
                &stream_id,
                LineageMetadata::new(
                    Some("consumer".into()),
                    Some("materialization-resume-tests".into()),
                ),
            )
            .expect("create root");
        client
            .append(&stream_id, b"materialize-0")
            .expect("append first");
        client
            .append(&stream_id, b"materialize-1")
            .expect("append second");

        let checkpoint = client
            .materialize_checkpoint_with_contract(
                &stream_id,
                "consumer.analytics",
                "reference_projection",
                br#"{"processed_records":2}"#.to_vec(),
                Some("state://consumer.analytics/2".into()),
                None,
                "analytics.v1",
            )
            .expect("checkpoint");
        assert_eq!(checkpoint.body().view_kind(), "reference_projection");
        assert_eq!(checkpoint.body().source_stream_id(), &stream_id);
        assert_eq!(checkpoint.body().source_offset().value(), 1);
        assert_eq!(
            checkpoint.body().lineage_ref(),
            "client.materialization.resume@1"
        );
        assert_eq!(
            checkpoint.body().opaque_state_ref(),
            Some("state://consumer.analytics/2")
        );
        assert_eq!(checkpoint.body().materializer_version(), "analytics.v1");

        client
            .append(&stream_id, b"materialize-2")
            .expect("append third");
        client
            .append(&stream_id, b"materialize-3")
            .expect("append fourth");

        let resumed = client
            .materialize_resume(checkpoint.body())
            .expect("resume materialization");
        assert_eq!(resumed.checkpoint(), checkpoint.body());
        assert_eq!(resumed.replay_from().value(), 2);
        assert_eq!(resumed.source_next_offset().value(), 4);
        assert_eq!(resumed.pending_record_count(), 2);
        assert_eq!(resumed.pending_records().len(), 2);
        assert_eq!(resumed.pending_records()[0].position().offset.value(), 2);
        assert_eq!(resumed.pending_records()[1].position().offset.value(), 3);
        assert_eq!(resumed.pending_records()[0].payload(), b"materialize-2");
        assert_eq!(resumed.pending_records()[1].payload(), b"materialize-3");

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn materialization_resume_cursor_rejects_tampered_checkpoint() {
        let (_temp_dir, server, client) = hosted_authority_test_client();
        let stream_id = StreamId::new("client.materialization.resume.invalid").expect("stream id");

        client
            .create_root(
                &stream_id,
                LineageMetadata::new(
                    Some("consumer".into()),
                    Some("materialization-resume-invalid-tests".into()),
                ),
            )
            .expect("create root");
        client
            .append(&stream_id, b"materialize-0")
            .expect("append first");

        let checkpoint = client
            .materialize_checkpoint(&stream_id, "consumer.analytics", Vec::new())
            .expect("checkpoint");
        let anchor = checkpoint.body().lineage_anchor().clone();
        let tampered = HostedMaterializationCheckpoint::new(
            checkpoint.body().materialization_id(),
            transit_core::storage::LineageCheckpoint::new(
                anchor.stream_id,
                anchor.head_offset,
                transit_core::storage::ContentDigest::new("sha256", "tampered-root")
                    .expect("digest"),
                anchor.kind,
            ),
            checkpoint.body().opaque_state().to_vec(),
            checkpoint.body().produced_at(),
        )
        .expect("tampered checkpoint");

        let error = client
            .resume_materialization_cursor(&tampered)
            .expect_err("tampered checkpoint should reject");
        match error {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::InvalidRequest);
                assert!(
                    error
                        .message()
                        .contains("does not match the persisted hosted checkpoint")
                );
            }
            other => panic!("expected remote invalid_request, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }
}
