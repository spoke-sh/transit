use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use transit_core::kernel::StreamId;
use transit_core::storage::{ContentDigest, LineageCheckpoint};

/// Content-addressed storage for Prolly Tree nodes.
#[async_trait::async_trait]
pub trait ProllyStore: Send + Sync {
    async fn put(&self, node: ProllyNode) -> Result<ContentDigest>;
    async fn get(&self, digest: &ContentDigest) -> Result<ProllyNode>;
}

/// One node in a Prolly Tree.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ProllyNode {
    Leaf(LeafNode),
    Internal(InternalNode),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LeafNode {
    pub entries: Vec<LeafEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LeafEntry {
    pub key: Vec<u8>,
    pub value: Vec<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InternalNode {
    pub entries: Vec<InternalEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InternalEntry {
    pub key: Vec<u8>,
    pub child_digest: ContentDigest,
}

/// Metadata for a reusable materialization snapshot.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SnapshotManifest {
    pub materialization_id: String,
    pub snapshot_id: String,
    pub source_stream_id: StreamId,
    pub source_checkpoint: LineageCheckpoint,
    pub root_digest: ContentDigest,
    pub created_at: i64,
}

impl ProllyNode {
    pub fn digest(&self) -> Result<ContentDigest> {
        let encoded = serde_json::to_vec(self).context("serialize prolly node")?;
        // For now, use the same SHA-256 helper from core (via a bridge or local impl)
        // I'll implement a local sha256_hex for now to avoid complexity.
        Ok(ContentDigest::new("sha256", sha256_hex(&encoded))?)
    }
}

fn sha256_hex(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    format!("{:x}", hasher.finalize())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prolly_node_can_be_digested() {
        let leaf = ProllyNode::Leaf(LeafNode {
            entries: vec![LeafEntry {
                key: b"key1".to_vec(),
                value: b"value1".to_vec(),
            }],
        });

        let digest = leaf.digest().expect("digest");
        assert_eq!(digest.algorithm(), "sha256");
        assert!(!digest.digest().is_empty());
    }
}
