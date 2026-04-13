use anyhow::{Result, ensure};
use async_trait::async_trait;
use transit_core::engine::{LocalEngine, LocalRecord};
use transit_core::kernel::{Offset, StreamId};
use transit_core::storage::LineageCheckpoint;

pub mod engine;
pub mod prolly;

pub use engine::{
    LocalMaterializationEngine, ReferenceProjectionMaterializer, ReferenceProjectionReducer,
    ReferenceProjectionState,
};

/// Envelope for a materializer's durable state and its lineage anchor.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct MaterializationCheckpoint {
    pub materialization_id: String,
    pub lineage_anchor: LineageCheckpoint,
    pub opaque_state: Vec<u8>, // Serialized materializer-specific state
    pub produced_at: i64,
}

impl MaterializationCheckpoint {
    pub fn source_stream_id(&self) -> &StreamId {
        &self.lineage_anchor.stream_id
    }

    pub fn lineage_anchor(&self) -> &LineageCheckpoint {
        &self.lineage_anchor
    }

    pub fn replay_from(&self) -> Offset {
        self.lineage_anchor.head_offset.increment()
    }

    pub fn resume_cursor(&self, engine: &LocalEngine) -> Result<MaterializationResumeCursor> {
        let status = engine.stream_status(&self.lineage_anchor.stream_id)?;
        ensure!(
            status.next_offset().value() > self.lineage_anchor.head_offset.value(),
            "checkpoint anchor '{}' is ahead of current replay head '{}' for '{}'",
            self.lineage_anchor.head_offset.value(),
            status.next_offset().value().saturating_sub(1),
            self.lineage_anchor.stream_id.as_str()
        );

        engine.verify_local_lineage(&self.lineage_anchor.stream_id)?;

        let anchor_record = engine
            .tail_from(
                &self.lineage_anchor.stream_id,
                self.lineage_anchor.head_offset,
            )?
            .into_iter()
            .next();
        ensure!(
            anchor_record
                .as_ref()
                .is_some_and(|record| record.position().offset == self.lineage_anchor.head_offset),
            "checkpoint anchor '{}' is not present in replay for '{}'",
            self.lineage_anchor.head_offset.value(),
            self.lineage_anchor.stream_id.as_str()
        );

        Ok(MaterializationResumeCursor {
            lineage_anchor: self.lineage_anchor.clone(),
            replay_from: self.replay_from(),
            source_next_offset: status.next_offset(),
        })
    }
}

/// Explicit replay window derived from a materialization checkpoint.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MaterializationResumeCursor {
    lineage_anchor: LineageCheckpoint,
    replay_from: Offset,
    source_next_offset: Offset,
}

impl MaterializationResumeCursor {
    pub fn source_stream_id(&self) -> &StreamId {
        &self.lineage_anchor.stream_id
    }

    pub fn lineage_anchor(&self) -> &LineageCheckpoint {
        &self.lineage_anchor
    }

    pub fn replay_from(&self) -> Offset {
        self.replay_from
    }

    pub fn source_next_offset(&self) -> Offset {
        self.source_next_offset
    }

    pub fn pending_record_count(&self) -> u64 {
        self.source_next_offset
            .value()
            .saturating_sub(self.replay_from.value())
    }

    pub fn is_caught_up(&self) -> bool {
        self.pending_record_count() == 0
    }

    pub fn pending_records(&self, engine: &LocalEngine) -> Result<Vec<LocalRecord>> {
        engine.tail_from(self.source_stream_id(), self.replay_from)
    }
}

/// Pure logic for reducing stream records into a derived state.
pub trait Reducer: Send + Sync {
    /// The type of state being produced.
    type State: serde::Serialize + serde::de::DeserializeOwned + Clone + Send + Sync;

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
