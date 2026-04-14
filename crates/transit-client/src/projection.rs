use anyhow::Result;
use transit_core::kernel::{Offset, StreamId, StreamPosition};

pub trait ProjectionReadConsumer: Send + Sync {
    type View;

    fn initial_view(&self) -> Self::View;

    fn reduce_view(
        &self,
        view: &mut Self::View,
        position: &StreamPosition,
        payload: &[u8],
    ) -> Result<()>;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProjectionReadRequest {
    projection_ref: StreamId,
    checkpoint_id: Option<String>,
}

impl ProjectionReadRequest {
    pub fn new(projection_ref: StreamId) -> Self {
        Self {
            projection_ref,
            checkpoint_id: None,
        }
    }

    pub fn projection_ref(&self) -> &StreamId {
        &self.projection_ref
    }

    pub fn checkpoint_id(&self) -> Option<&str> {
        self.checkpoint_id.as_deref()
    }

    pub fn with_checkpoint_id(mut self, checkpoint_id: impl Into<String>) -> Self {
        self.checkpoint_id = Some(checkpoint_id.into());
        self
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProjectionReadOutcome<V> {
    projection_ref: StreamId,
    consumed_records: usize,
    head_offset: Option<Offset>,
    projection_revision: Option<String>,
    checkpoint_id: Option<String>,
    checkpoint_matches: bool,
    view: V,
}

impl<V> ProjectionReadOutcome<V> {
    pub(crate) fn new(
        projection_ref: StreamId,
        consumed_records: usize,
        head_offset: Option<Offset>,
        projection_revision: Option<String>,
        checkpoint_id: Option<String>,
        checkpoint_matches: bool,
        view: V,
    ) -> Self {
        Self {
            projection_ref,
            consumed_records,
            head_offset,
            projection_revision,
            checkpoint_id,
            checkpoint_matches,
            view,
        }
    }

    pub fn projection_ref(&self) -> &StreamId {
        &self.projection_ref
    }

    pub fn consumed_records(&self) -> usize {
        self.consumed_records
    }

    pub fn head_offset(&self) -> Option<Offset> {
        self.head_offset
    }

    pub fn projection_revision(&self) -> Option<&str> {
        self.projection_revision.as_deref()
    }

    pub fn checkpoint_id(&self) -> Option<&str> {
        self.checkpoint_id.as_deref()
    }

    pub fn checkpoint_matches(&self) -> bool {
        self.checkpoint_matches
    }

    pub fn view(&self) -> &V {
        &self.view
    }
}

pub(crate) fn projection_revision_for(stream_id: &StreamId, head_offset: Offset) -> String {
    format!("projection:{}@{}", stream_id.as_str(), head_offset.value())
}
