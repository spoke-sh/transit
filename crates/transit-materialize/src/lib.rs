use anyhow::Result;
use async_trait::async_trait;
use transit_core::kernel::{Offset, StreamId};
use transit_core::storage::LineageCheckpoint;

/// Pure logic for reducing stream records into a derived state.
pub trait Reducer: Send + Sync {
    /// The type of state being produced.
    type State: serde::Serialize + serde::de::DeserializeOwned + Send + Sync;

    /// Apply a single record to the current state.
    fn reduce(&self, state: &mut Self::State, offset: Offset, payload: &[u8]) -> Result<()>;
}

/// Orchestrates stream consumption and checkpointing for a specific reducer.
#[async_trait]
pub trait Materializer: Send + Sync {
    /// Identifier for this materializer instance.
    fn id(&self) -> &str;

    /// The stream being consumed.
    fn source_stream_id(&self) -> &StreamId;

    /// Trigger a reduction pass and optionally emit a checkpoint.
    async fn step(&self) -> Result<Option<LineageCheckpoint>>;
}
