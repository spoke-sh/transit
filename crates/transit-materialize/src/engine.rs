use crate::{MaterializationCheckpoint, Materializer, Reducer};
use anyhow::{Context, Result};
use async_trait::async_trait;
use transit_core::engine::LocalEngine;
use transit_core::kernel::{Offset, StreamId};

pub struct LocalMaterializationEngine<R: Reducer> {
    id: String,
    stream_id: StreamId,
    inner: tokio::sync::Mutex<MaterializerInner<R>>,
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
        let mut inner = self.inner.lock().await;
        inner.catch_up().await?;
        let checkpoint = inner.checkpoint()?;
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

    pub async fn current_state(&self) -> R::State {
        self.inner.lock().await.current_state.clone()
    }
}

impl<R: Reducer> MaterializerInner<R> {
    pub async fn catch_up(&mut self) -> Result<()> {
        let status = self.engine.stream_status(&self.stream_id)?;

        let start_offset = self
            .last_checkpoint
            .as_ref()
            .map(|c| c.lineage_anchor.head_offset.increment())
            .unwrap_or(Offset::new(0));

        let records = self.engine.replay(&self.stream_id)?;
        for record in records {
            if record.position().offset >= start_offset
                && record.position().offset < status.next_offset()
            {
                self.reducer.reduce(
                    &mut self.current_state,
                    record.position().offset,
                    record.payload(),
                )?;
            }
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
}

#[cfg(test)]
mod tests {
    use super::*;
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
        let core = LocalEngine::open(LocalEngineConfig::new(temp.path())).expect("core");
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
}
