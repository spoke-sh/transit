use anyhow::{Context, Result};
use crate::{MaterializationCheckpoint, Materializer, Reducer};
use transit_core::engine::LocalEngine;
use transit_core::kernel::Offset;

pub struct LocalMaterializationEngine<R: Reducer> {
    id: String,
    engine: LocalEngine,
    reducer: R,
    current_state: R::State,
    last_checkpoint: Option<MaterializationCheckpoint>,
}

impl<R: Reducer> LocalMaterializationEngine<R> {
    pub fn new(id: String, engine: LocalEngine, reducer: R, initial_state: R::State) -> Self {
        Self {
            id,
            engine,
            reducer,
            current_state: initial_state,
            last_checkpoint: None,
        }
    }

    /// Replay from the last checkpoint and catch up to the current stream head.
    pub async fn catch_up(&mut self) -> Result<()> {
        let stream_id = self.engine.stream_status(&self.source_stream_id())?.stream_id().clone();
        
        let start_offset = self.last_checkpoint
            .as_ref()
            .map(|c| c.lineage_anchor.head_offset.increment())
            .unwrap_or(Offset::new(0));

        let records = self.engine.replay(&stream_id)?;
        for record in records {
            if record.position().offset >= start_offset {
                self.reducer.reduce(&mut self.current_state, record.position().offset, record.payload())?;
            }
        }

        Ok(())
    }

    /// Emit a verifiable checkpoint for the current state.
    pub fn checkpoint(&mut self) -> Result<MaterializationCheckpoint> {
        let lineage_checkpoint = self.engine.checkpoint(&self.source_stream_id(), "materialize")?;
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

    fn source_stream_id(&self) -> transit_core::kernel::StreamId {
        // For now, assume we're tied to one stream. 
        // This is a simplification for the first slice.
        transit_core::kernel::StreamId::new("task.root").unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use transit_core::engine::{LocalEngine, LocalEngineConfig};
    use transit_core::kernel::{LineageMetadata, StreamDescriptor, StreamId};
    use tempfile::tempdir;

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
        core.create_stream(StreamDescriptor::root(stream_id.clone(), LineageMetadata::default())).expect("create");
        
        core.append(&stream_id, b"one").expect("append");
        core.append(&stream_id, b"two").expect("append");

        let mut mat = LocalMaterializationEngine::new(
            "test-mat".into(),
            core.clone(),
            CountReducer,
            0,
        );

        mat.catch_up().await.expect("catch up");
        assert_eq!(mat.current_state, 2);

        let checkpoint = mat.checkpoint().expect("checkpoint");
        assert_eq!(checkpoint.lineage_anchor.head_offset.value(), 1);

        // Append more and catch up again
        core.append(&stream_id, b"three").expect("append");
        mat.catch_up().await.expect("catch up 2");
        assert_eq!(mat.current_state, 3);
    }
}
