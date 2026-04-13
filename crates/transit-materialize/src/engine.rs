use crate::{MaterializationCheckpoint, MaterializationResumeCursor, Materializer, Reducer};
use anyhow::{Context, Result, ensure};
use async_trait::async_trait;
use std::collections::BTreeMap;
use transit_core::engine::LocalEngine;
use transit_core::kernel::{Offset, StreamId};

pub type ReferenceProjectionState<V> = BTreeMap<String, V>;

pub trait ReferenceProjectionReducer: Send + Sync {
    type View: serde::Serialize + serde::de::DeserializeOwned + Clone + Send + Sync;

    fn reduce_view(
        &self,
        state: &mut ReferenceProjectionState<Self::View>,
        offset: Offset,
        payload: &[u8],
    ) -> Result<()>;
}

struct ReferenceProjectionAdapter<R: ReferenceProjectionReducer> {
    inner: R,
}

impl<R: ReferenceProjectionReducer> Reducer for ReferenceProjectionAdapter<R> {
    type State = ReferenceProjectionState<R::View>;

    fn reduce(&self, state: &mut Self::State, offset: Offset, payload: &[u8]) -> Result<()> {
        self.inner.reduce_view(state, offset, payload)
    }
}

pub struct LocalMaterializationEngine<R: Reducer> {
    id: String,
    stream_id: StreamId,
    inner: tokio::sync::Mutex<MaterializerInner<R>>,
}

pub struct ReferenceProjectionMaterializer<R: ReferenceProjectionReducer> {
    inner: LocalMaterializationEngine<ReferenceProjectionAdapter<R>>,
}

struct MaterializerInner<R: Reducer> {
    id: String,
    stream_id: StreamId,
    engine: LocalEngine,
    reducer: R,
    current_state: R::State,
    last_checkpoint: Option<MaterializationCheckpoint>,
}

#[async_trait]
impl<R: Reducer> Materializer for LocalMaterializationEngine<R> {
    fn id(&self) -> &str {
        &self.id
    }

    fn source_stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    async fn step(&self) -> Result<Option<transit_core::storage::LineageCheckpoint>> {
        self.catch_up().await?;
        let checkpoint = self.checkpoint().await?;
        Ok(Some(checkpoint.lineage_anchor))
    }
}

impl<R: Reducer> LocalMaterializationEngine<R> {
    pub fn new(
        id: String,
        stream_id: StreamId,
        engine: LocalEngine,
        reducer: R,
        initial_state: R::State,
    ) -> Self {
        Self {
            id: id.clone(),
            stream_id: stream_id.clone(),
            inner: tokio::sync::Mutex::new(MaterializerInner {
                id,
                stream_id,
                engine,
                reducer,
                current_state: initial_state,
                last_checkpoint: None,
            }),
        }
    }

    pub fn resume(
        id: String,
        stream_id: StreamId,
        engine: LocalEngine,
        reducer: R,
        checkpoint: MaterializationCheckpoint,
    ) -> Result<Self> {
        ensure!(
            checkpoint.materialization_id == id,
            "materialization checkpoint id mismatch: expected '{}', found '{}'",
            id,
            checkpoint.materialization_id
        );
        ensure!(
            checkpoint.lineage_anchor.stream_id == stream_id,
            "materialization checkpoint stream mismatch: expected '{}', found '{}'",
            stream_id.as_str(),
            checkpoint.lineage_anchor.stream_id.as_str()
        );

        let current_state = serde_json::from_slice(&checkpoint.opaque_state)
            .context("deserialize checkpoint state")?;

        Ok(Self {
            id: id.clone(),
            stream_id: stream_id.clone(),
            inner: tokio::sync::Mutex::new(MaterializerInner {
                id,
                stream_id,
                engine,
                reducer,
                current_state,
                last_checkpoint: Some(checkpoint),
            }),
        })
    }

    pub fn resume_verified(
        id: String,
        stream_id: StreamId,
        engine: LocalEngine,
        reducer: R,
        checkpoint: MaterializationCheckpoint,
    ) -> Result<Self> {
        checkpoint.resume_cursor(&engine)?;
        Self::resume(id, stream_id, engine, reducer, checkpoint)
    }

    pub async fn catch_up(&self) -> Result<()> {
        self.inner.lock().await.catch_up().await
    }

    pub async fn checkpoint(&self) -> Result<MaterializationCheckpoint> {
        self.inner.lock().await.checkpoint()
    }

    pub async fn current_state(&self) -> R::State {
        self.inner.lock().await.current_state.clone()
    }

    pub async fn resume_cursor(&self) -> Result<Option<MaterializationResumeCursor>> {
        self.inner.lock().await.resume_cursor()
    }
}

#[async_trait]
impl<R: ReferenceProjectionReducer> Materializer for ReferenceProjectionMaterializer<R> {
    fn id(&self) -> &str {
        self.inner.id()
    }

    fn source_stream_id(&self) -> &StreamId {
        self.inner.source_stream_id()
    }

    async fn step(&self) -> Result<Option<transit_core::storage::LineageCheckpoint>> {
        self.inner.step().await
    }
}

impl<R: ReferenceProjectionReducer> ReferenceProjectionMaterializer<R> {
    pub fn new(id: String, stream_id: StreamId, engine: LocalEngine, reducer: R) -> Self {
        Self {
            inner: LocalMaterializationEngine::new(
                id,
                stream_id,
                engine,
                ReferenceProjectionAdapter { inner: reducer },
                ReferenceProjectionState::new(),
            ),
        }
    }

    pub fn resume(
        id: String,
        stream_id: StreamId,
        engine: LocalEngine,
        reducer: R,
        checkpoint: MaterializationCheckpoint,
    ) -> Result<Self> {
        Ok(Self {
            inner: LocalMaterializationEngine::resume(
                id,
                stream_id,
                engine,
                ReferenceProjectionAdapter { inner: reducer },
                checkpoint,
            )?,
        })
    }

    pub fn resume_verified(
        id: String,
        stream_id: StreamId,
        engine: LocalEngine,
        reducer: R,
        checkpoint: MaterializationCheckpoint,
    ) -> Result<Self> {
        Ok(Self {
            inner: LocalMaterializationEngine::resume_verified(
                id,
                stream_id,
                engine,
                ReferenceProjectionAdapter { inner: reducer },
                checkpoint,
            )?,
        })
    }

    pub async fn catch_up(&self) -> Result<()> {
        self.inner.catch_up().await
    }

    pub async fn checkpoint(&self) -> Result<MaterializationCheckpoint> {
        self.inner.checkpoint().await
    }

    pub async fn current_view(&self) -> ReferenceProjectionState<R::View> {
        self.inner.current_state().await
    }

    pub async fn resume_cursor(&self) -> Result<Option<MaterializationResumeCursor>> {
        self.inner.resume_cursor().await
    }
}

impl<R: Reducer> MaterializerInner<R> {
    pub async fn catch_up(&mut self) -> Result<()> {
        let records = match self.resume_cursor()? {
            Some(cursor) => cursor.pending_records(&self.engine)?,
            None => self.engine.tail_from(&self.stream_id, Offset::new(0))?,
        };

        for record in records {
            self.reducer.reduce(
                &mut self.current_state,
                record.position().offset,
                record.payload(),
            )?;
        }

        Ok(())
    }

    pub fn checkpoint(&mut self) -> Result<MaterializationCheckpoint> {
        let lineage_checkpoint = self.engine.checkpoint(&self.stream_id, "materialize")?;
        let opaque_state = serde_json::to_vec(&self.current_state).context("serialize state")?;

        let checkpoint = MaterializationCheckpoint {
            materialization_id: self.id.clone(),
            lineage_anchor: lineage_checkpoint,
            opaque_state,
            produced_at: chrono::Utc::now().timestamp(),
        };

        self.last_checkpoint = Some(checkpoint.clone());
        Ok(checkpoint)
    }

    pub fn resume_cursor(&self) -> Result<Option<MaterializationResumeCursor>> {
        self.last_checkpoint
            .as_ref()
            .map(|checkpoint| checkpoint.resume_cursor(&self.engine))
            .transpose()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde::{Deserialize, Serialize};
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use tempfile::tempdir;
    use transit_core::engine::{LocalEngine, LocalEngineConfig};
    use transit_core::kernel::{LineageMetadata, StreamDescriptor};

    struct CountReducer;
    impl Reducer for CountReducer {
        type State = u64;
        fn reduce(&self, state: &mut Self::State, _offset: Offset, _payload: &[u8]) -> Result<()> {
            *state += 1;
            Ok(())
        }
    }

    #[tokio::test]
    async fn materializer_can_catch_up_and_checkpoint() {
        let temp = tempdir().expect("temp");
        let core = LocalEngine::open(LocalEngineConfig::new(
            temp.path(),
            transit_core::membership::NodeId::new("test-node"),
        ))
        .expect("core");
        let stream_id = StreamId::new("task.root").expect("id");
        core.create_stream(StreamDescriptor::root(
            stream_id.clone(),
            LineageMetadata::default(),
        ))
        .expect("create");

        core.append(&stream_id, b"one").expect("append");
        core.append(&stream_id, b"two").expect("append");

        let mat = LocalMaterializationEngine::new(
            "test-mat".into(),
            stream_id.clone(),
            core.clone(),
            CountReducer,
            0,
        );

        mat.step().await.expect("step");
        assert_eq!(mat.current_state().await, 2);

        // Append more and catch up again
        core.append(&stream_id, b"three").expect("append");
        mat.step().await.expect("step 2");
        assert_eq!(mat.current_state().await, 3);
    }

    #[tokio::test]
    async fn materializer_can_resume_from_checkpoint_without_reprocessing_old_records() {
        let temp = tempdir().expect("temp");
        let core = LocalEngine::open(LocalEngineConfig::new(
            temp.path(),
            transit_core::membership::NodeId::new("test-node"),
        ))
        .expect("core");
        let stream_id = StreamId::new("task.root").expect("id");
        let materialization_id = "test-mat".to_string();
        core.create_stream(StreamDescriptor::root(
            stream_id.clone(),
            LineageMetadata::default(),
        ))
        .expect("create");

        core.append(&stream_id, b"one").expect("append");
        core.append(&stream_id, b"two").expect("append");

        let mat = LocalMaterializationEngine::new(
            materialization_id.clone(),
            stream_id.clone(),
            core.clone(),
            CountReducer,
            0,
        );
        mat.catch_up().await.expect("catch up");
        assert_eq!(mat.current_state().await, 2);

        let checkpoint = mat.checkpoint().await.expect("checkpoint");
        assert_eq!(checkpoint.lineage_anchor.stream_id, stream_id);
        assert_eq!(checkpoint.lineage_anchor.head_offset.value(), 1);
        assert_eq!(checkpoint.lineage_anchor.kind, "materialize");
        core.verify_checkpoint(&checkpoint.lineage_anchor)
            .expect("verify lineage anchor");

        core.append(&stream_id, b"three").expect("append");

        let resumed = LocalMaterializationEngine::resume(
            materialization_id,
            stream_id,
            core,
            CountReducer,
            checkpoint,
        )
        .expect("resume");
        resumed.catch_up().await.expect("resume catch up");

        assert_eq!(resumed.current_state().await, 3);
    }

    #[tokio::test]
    async fn checkpoint_resume_cursor_reports_pending_branch_records() {
        let temp = tempdir().expect("temp");
        let core = LocalEngine::open(LocalEngineConfig::new(
            temp.path(),
            transit_core::membership::NodeId::new("test-node"),
        ))
        .expect("core");
        let root_stream = StreamId::new("task.root").expect("root id");
        let branch_stream = StreamId::new("task.root.thread").expect("branch id");

        core.create_stream(StreamDescriptor::root(
            root_stream.clone(),
            LineageMetadata::default(),
        ))
        .expect("create root");
        core.append(&root_stream, b"root-one").expect("append root");
        core.append(&root_stream, b"root-two").expect("append root");
        core.create_branch(
            branch_stream.clone(),
            transit_core::kernel::StreamPosition::new(root_stream, Offset::new(1)),
            LineageMetadata::default(),
        )
        .expect("create branch");
        core.append(&branch_stream, b"branch-one")
            .expect("append branch");

        let mat = LocalMaterializationEngine::new(
            "branch-mat".into(),
            branch_stream.clone(),
            core.clone(),
            CountReducer,
            0,
        );
        mat.catch_up().await.expect("catch up");

        let checkpoint = mat.checkpoint().await.expect("checkpoint");
        core.append(&branch_stream, b"branch-two")
            .expect("append branch");

        let cursor = checkpoint.resume_cursor(&core).expect("resume cursor");
        let pending_records = cursor.pending_records(&core).expect("pending records");

        assert_eq!(cursor.source_stream_id(), &branch_stream);
        assert_eq!(cursor.lineage_anchor().head_offset.value(), 2);
        assert_eq!(cursor.replay_from().value(), 3);
        assert_eq!(cursor.source_next_offset().value(), 4);
        assert_eq!(cursor.pending_record_count(), 1);
        assert!(!cursor.is_caught_up());
        assert_eq!(pending_records.len(), 1);
        assert_eq!(pending_records[0].payload(), b"branch-two");
    }

    #[tokio::test]
    async fn resume_verified_uses_explicit_checkpoint_cursor_before_replay() {
        let temp = tempdir().expect("temp");
        let core = LocalEngine::open(LocalEngineConfig::new(
            temp.path(),
            transit_core::membership::NodeId::new("test-node"),
        ))
        .expect("core");
        let stream_id = StreamId::new("task.root").expect("id");
        let materialization_id = "verified-mat".to_string();
        core.create_stream(StreamDescriptor::root(
            stream_id.clone(),
            LineageMetadata::default(),
        ))
        .expect("create");

        core.append(&stream_id, b"one").expect("append");
        core.append(&stream_id, b"two").expect("append");

        let mat = LocalMaterializationEngine::new(
            materialization_id.clone(),
            stream_id.clone(),
            core.clone(),
            CountReducer,
            0,
        );
        mat.catch_up().await.expect("catch up");
        let checkpoint = mat.checkpoint().await.expect("checkpoint");

        core.append(&stream_id, b"three").expect("append");

        let resumed = LocalMaterializationEngine::resume_verified(
            materialization_id,
            stream_id,
            core,
            CountReducer,
            checkpoint,
        )
        .expect("resume verified");
        let cursor = resumed
            .resume_cursor()
            .await
            .expect("resume cursor")
            .expect("checkpoint cursor");

        assert_eq!(cursor.replay_from().value(), 2);
        assert_eq!(cursor.pending_record_count(), 1);

        resumed.catch_up().await.expect("resume catch up");
        assert_eq!(resumed.current_state().await, 3);
    }

    #[tokio::test]
    async fn resume_cursor_rejects_checkpoint_when_stream_falls_behind_anchor() {
        let temp = tempdir().expect("temp");
        let core = LocalEngine::open(LocalEngineConfig::new(
            temp.path(),
            transit_core::membership::NodeId::new("test-node"),
        ))
        .expect("core");
        let stream_id = StreamId::new("task.root").expect("id");
        core.create_stream(StreamDescriptor::root(
            stream_id.clone(),
            LineageMetadata::default(),
        ))
        .expect("create");
        core.append(&stream_id, b"one").expect("append");

        let checkpoint = MaterializationCheckpoint {
            materialization_id: "cursor-mat".into(),
            lineage_anchor: transit_core::storage::LineageCheckpoint::new(
                stream_id,
                Offset::new(4),
                transit_core::storage::ContentDigest::new("sha256", "abc123").expect("digest"),
                "materialize",
            ),
            opaque_state: serde_json::to_vec(&0_u64).expect("serialize state"),
            produced_at: chrono::Utc::now().timestamp(),
        };

        let error = checkpoint
            .resume_cursor(&core)
            .expect_err("checkpoint should be ahead of stream");
        assert!(
            error
                .to_string()
                .contains("checkpoint anchor '4' is ahead of current replay head '0'")
        );
    }

    #[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
    struct ReferenceView {
        display_name: String,
        status: String,
    }

    #[derive(Debug, Serialize, Deserialize)]
    struct ReferenceEvent {
        reference_id: String,
        display_name: String,
        status: String,
        deleted: bool,
    }

    struct ReferenceReducer {
        processed: Arc<AtomicUsize>,
    }

    impl ReferenceProjectionReducer for ReferenceReducer {
        type View = ReferenceView;

        fn reduce_view(
            &self,
            state: &mut ReferenceProjectionState<Self::View>,
            _offset: Offset,
            payload: &[u8],
        ) -> Result<()> {
            self.processed.fetch_add(1, Ordering::SeqCst);
            let event: ReferenceEvent =
                serde_json::from_slice(payload).context("deserialize reference event")?;
            if event.deleted {
                state.remove(&event.reference_id);
            } else {
                state.insert(
                    event.reference_id,
                    ReferenceView {
                        display_name: event.display_name,
                        status: event.status,
                    },
                );
            }
            Ok(())
        }
    }

    fn reference_event(
        reference_id: &str,
        display_name: &str,
        status: &str,
        deleted: bool,
    ) -> Vec<u8> {
        serde_json::to_vec(&ReferenceEvent {
            reference_id: reference_id.to_owned(),
            display_name: display_name.to_owned(),
            status: status.to_owned(),
            deleted,
        })
        .expect("serialize reference event")
    }

    #[tokio::test]
    async fn reference_projection_derives_views_from_replay_and_resume_only_new_history() {
        let temp = tempdir().expect("temp");
        let core = LocalEngine::open(LocalEngineConfig::new(
            temp.path(),
            transit_core::membership::NodeId::new("test-node"),
        ))
        .expect("core");
        let stream_id = StreamId::new("task.reference.root").expect("id");
        let materialization_id = "reference-projection".to_owned();
        core.create_stream(StreamDescriptor::root(
            stream_id.clone(),
            LineageMetadata::default(),
        ))
        .expect("create");
        core.append(
            &stream_id,
            reference_event("ref-1", "alpha", "active", false),
        )
        .expect("append ref-1");
        core.append(
            &stream_id,
            reference_event("ref-2", "beta", "pending", false),
        )
        .expect("append ref-2");

        let processed = Arc::new(AtomicUsize::new(0));
        let materializer = ReferenceProjectionMaterializer::new(
            materialization_id.clone(),
            stream_id.clone(),
            core.clone(),
            ReferenceReducer {
                processed: Arc::clone(&processed),
            },
        );
        materializer.catch_up().await.expect("catch up");

        let initial_view = materializer.current_view().await;
        assert_eq!(processed.load(Ordering::SeqCst), 2);
        assert_eq!(initial_view.len(), 2);
        assert_eq!(initial_view["ref-1"].status, "active");

        let checkpoint = materializer.checkpoint().await.expect("checkpoint");
        core.append(
            &stream_id,
            reference_event("ref-1", "alpha", "disabled", false),
        )
        .expect("append ref-1 update");
        core.append(
            &stream_id,
            reference_event("ref-3", "gamma", "active", false),
        )
        .expect("append ref-3");

        let resumed = ReferenceProjectionMaterializer::resume_verified(
            materialization_id,
            stream_id,
            core,
            ReferenceReducer {
                processed: Arc::clone(&processed),
            },
            checkpoint,
        )
        .expect("resume verified");
        let cursor = resumed
            .resume_cursor()
            .await
            .expect("resume cursor")
            .expect("cursor");
        assert_eq!(cursor.pending_record_count(), 2);

        resumed.catch_up().await.expect("resume catch up");
        let resumed_view = resumed.current_view().await;
        assert_eq!(processed.load(Ordering::SeqCst), 4);
        assert_eq!(resumed_view.len(), 3);
        assert_eq!(resumed_view["ref-1"].status, "disabled");
        assert_eq!(resumed_view["ref-3"].display_name, "gamma");
        assert_eq!(cursor.pending_record_count(), 2);
    }

    #[tokio::test]
    async fn reference_projection_views_stay_replaceable_and_anchor_to_lineage() {
        let temp = tempdir().expect("temp");
        let core = LocalEngine::open(LocalEngineConfig::new(
            temp.path(),
            transit_core::membership::NodeId::new("test-node"),
        ))
        .expect("core");
        let stream_id = StreamId::new("task.reference.root").expect("id");
        let materialization_id = "reference-projection".to_owned();
        core.create_stream(StreamDescriptor::root(
            stream_id.clone(),
            LineageMetadata::default(),
        ))
        .expect("create");
        core.append(
            &stream_id,
            reference_event("ref-1", "alpha", "active", false),
        )
        .expect("append ref-1");
        core.append(
            &stream_id,
            reference_event("ref-2", "beta", "pending", false),
        )
        .expect("append ref-2");

        let processed = Arc::new(AtomicUsize::new(0));
        let materializer = ReferenceProjectionMaterializer::new(
            materialization_id.clone(),
            stream_id.clone(),
            core.clone(),
            ReferenceReducer {
                processed: Arc::clone(&processed),
            },
        );
        materializer.catch_up().await.expect("catch up");
        let checkpoint = materializer.checkpoint().await.expect("checkpoint");
        core.verify_checkpoint(checkpoint.lineage_anchor())
            .expect("verify lineage anchor");
        assert_eq!(checkpoint.lineage_anchor.head_offset.value(), 1);
        assert_eq!(checkpoint.lineage_anchor.stream_id, stream_id);

        core.append(
            &stream_id,
            reference_event("ref-2", "beta", "active", false),
        )
        .expect("append ref-2 update");

        let resumed = ReferenceProjectionMaterializer::resume_verified(
            materialization_id.clone(),
            stream_id.clone(),
            core.clone(),
            ReferenceReducer {
                processed: Arc::clone(&processed),
            },
            checkpoint,
        )
        .expect("resume verified");
        resumed.catch_up().await.expect("resumed catch up");

        let rebuilt = ReferenceProjectionMaterializer::new(
            materialization_id,
            stream_id,
            core,
            ReferenceReducer { processed },
        );
        rebuilt.catch_up().await.expect("rebuilt catch up");

        assert_eq!(resumed.current_view().await, rebuilt.current_view().await);
    }
}
