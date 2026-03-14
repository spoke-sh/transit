use anyhow::Result;
use async_trait::async_trait;
use crate::kernel::StreamId;
use serde::{Deserialize, Serialize};

/// Identifies a unique node in the Transit cluster.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NodeId(String);

impl NodeId {
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// A verifiable distributed lease for a stream head.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StreamLease {
    pub stream_id: StreamId,
    pub owner: NodeId,
    pub version: u64,
    pub expires_at: i64,
}

/// Handle for an active stream lease.
#[async_trait]
pub trait ConsensusHandle: Send + Sync {
    /// Check if this handle still represents the current leader for the stream.
    fn is_leader(&self) -> bool;

    /// The stream this lease belongs to.
    fn stream_id(&self) -> &StreamId;

    /// The current lease state.
    fn lease(&self) -> &StreamLease;
}

/// Provider for distributed coordination.
#[async_trait]
pub trait ConsensusProvider: Send + Sync {
    /// Attempt to acquire leadership for a stream.
    async fn acquire(&self, stream_id: &StreamId, owner: NodeId) -> Result<Box<dyn ConsensusHandle>>;
}
