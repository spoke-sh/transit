use anyhow::{Context, Result};
use object_store::ObjectStoreExt;
use serde::{Deserialize, Serialize};
use transit_core::kernel::StreamId;
use transit_core::storage::{ContentDigest, LineageCheckpoint};

/// Content-addressed storage for Prolly Tree nodes.
#[async_trait::async_trait]
pub trait ProllyStore: Send + Sync {
    async fn put(&self, node: ProllyNode) -> Result<ContentDigest>;
    async fn get(&self, digest: &ContentDigest) -> Result<ProllyNode>;
}

#[cfg(test)]
pub struct MemoryProllyStore {
    nodes: std::sync::Mutex<std::collections::HashMap<String, ProllyNode>>,
}

#[cfg(test)]
impl MemoryProllyStore {
    pub fn new() -> Self {
        Self {
            nodes: std::sync::Mutex::new(std::collections::HashMap::new()),
        }
    }
}

#[cfg(test)]
impl Default for MemoryProllyStore {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
#[async_trait::async_trait]
impl ProllyStore for MemoryProllyStore {
    async fn put(&self, node: ProllyNode) -> Result<ContentDigest> {
        let digest = node.digest()?;
        self.nodes
            .lock()
            .unwrap()
            .insert(digest.digest().to_string(), node);
        Ok(digest)
    }

    async fn get(&self, digest: &ContentDigest) -> Result<ProllyNode> {
        self.nodes
            .lock()
            .unwrap()
            .get(digest.digest())
            .cloned()
            .context("not found")
    }
}

pub struct ObjectStoreProllyStore {
    store: std::sync::Arc<dyn object_store::ObjectStore>,
    prefix: object_store::path::Path,
}

impl ObjectStoreProllyStore {
    pub fn new(
        store: std::sync::Arc<dyn object_store::ObjectStore>,
        prefix: impl Into<String>,
    ) -> Self {
        Self {
            store,
            prefix: object_store::path::Path::from(prefix.into()),
        }
    }

    fn node_path(&self, digest: &ContentDigest) -> object_store::path::Path {
        self.prefix.child(digest.digest())
    }
}

#[async_trait::async_trait]
impl ProllyStore for ObjectStoreProllyStore {
    async fn put(&self, node: ProllyNode) -> Result<ContentDigest> {
        let digest = node.digest()?;
        let path = self.node_path(&digest);
        let bytes = serde_json::to_vec(&node).context("serialize node")?;
        self.store
            .put(&path, bytes.into())
            .await
            .context("put node")?;
        Ok(digest)
    }

    async fn get(&self, digest: &ContentDigest) -> Result<ProllyNode> {
        let path = self.node_path(digest);
        let bytes = self
            .store
            .get(&path)
            .await
            .context("get node")?
            .bytes()
            .await
            .context("read node bytes")?;
        serde_json::from_slice(&bytes).context("deserialize node")
    }
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

pub struct ProllyTreeBuilder<'a, S: ProllyStore> {
    store: &'a S,
    chunk_threshold: u32,
}

impl<'a, S: ProllyStore> ProllyTreeBuilder<'a, S> {
    pub fn new(store: &'a S) -> Self {
        Self {
            store,
            chunk_threshold: 0x000F_FFFF, // Adjust for chunk size
        }
    }

    pub async fn build_from_entries(&self, entries: Vec<LeafEntry>) -> Result<ContentDigest> {
        if entries.is_empty() {
            let empty_leaf = ProllyNode::Leaf(LeafNode {
                entries: Vec::new(),
            });
            return self.store.put(empty_leaf).await;
        }

        // 1. Build Leaf Layer
        let mut current_layer_digests = Vec::new();
        let mut current_chunk = Vec::new();

        for entry in entries {
            current_chunk.push(entry);
            if self.should_chunk_leaf(&current_chunk) {
                let node = ProllyNode::Leaf(LeafNode {
                    entries: std::mem::take(&mut current_chunk),
                });
                let digest = self.store.put(node).await?;
                current_layer_digests.push(InternalEntry {
                    key: current_chunk
                        .last()
                        .map(|e| e.key.clone())
                        .unwrap_or_default(),
                    child_digest: digest,
                });
            }
        }

        if !current_chunk.is_empty() {
            let last_key = current_chunk.last().unwrap().key.clone();
            let node = ProllyNode::Leaf(LeafNode {
                entries: current_chunk,
            });
            let digest = self.store.put(node).await?;
            current_layer_digests.push(InternalEntry {
                key: last_key,
                child_digest: digest,
            });
        }

        // 2. Build Internal Layers
        while current_layer_digests.len() > 1 {
            let mut next_layer_digests = Vec::new();
            let mut current_internal_chunk = Vec::new();

            for entry in current_layer_digests {
                current_internal_chunk.push(entry);
                if self.should_chunk_internal(&current_internal_chunk) {
                    let node = ProllyNode::Internal(InternalNode {
                        entries: std::mem::take(&mut current_internal_chunk),
                    });
                    let digest = self.store.put(node).await?;
                    next_layer_digests.push(InternalEntry {
                        key: current_internal_chunk
                            .last()
                            .map(|e| e.key.clone())
                            .unwrap_or_default(),
                        child_digest: digest,
                    });
                }
            }

            if !current_internal_chunk.is_empty() {
                let last_key = current_internal_chunk.last().unwrap().key.clone();
                let node = ProllyNode::Internal(InternalNode {
                    entries: current_internal_chunk,
                });
                let digest = self.store.put(node).await?;
                next_layer_digests.push(InternalEntry {
                    key: last_key,
                    child_digest: digest,
                });
            }
            current_layer_digests = next_layer_digests;
        }

        Ok(current_layer_digests[0].child_digest.clone())
    }

    fn should_chunk_leaf(&self, entries: &[LeafEntry]) -> bool {
        // Simple content-defined chunking: hash the last entry and check threshold
        if let Some(last) = entries.last() {
            let mut hasher = std::collections::hash_map::DefaultHasher::new();
            use std::hash::Hasher;
            std::hash::Hash::hash(&last.key, &mut hasher);
            (hasher.finish() as u32) & self.chunk_threshold == 0
        } else {
            false
        }
    }

    fn should_chunk_internal(&self, entries: &[InternalEntry]) -> bool {
        if let Some(last) = entries.last() {
            let mut hasher = std::collections::hash_map::DefaultHasher::new();
            use std::hash::Hasher;
            std::hash::Hash::hash(&last.key, &mut hasher);
            (hasher.finish() as u32) & self.chunk_threshold == 0
        } else {
            false
        }
    }
}

impl ProllyNode {
    pub fn digest(&self) -> Result<ContentDigest> {
        let encoded = serde_json::to_vec(self).context("serialize prolly node")?;
        ContentDigest::new("sha256", sha256_hex(&encoded))
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

    #[tokio::test]
    async fn prolly_tree_builder_constructs_root_from_entries() {
        let store = MemoryProllyStore::new();
        let builder = ProllyTreeBuilder::new(&store);

        let entries = vec![
            LeafEntry {
                key: b"a".to_vec(),
                value: b"1".to_vec(),
            },
            LeafEntry {
                key: b"b".to_vec(),
                value: b"2".to_vec(),
            },
            LeafEntry {
                key: b"c".to_vec(),
                value: b"3".to_vec(),
            },
        ];

        let root_digest = builder.build_from_entries(entries).await.expect("build");
        let root_node = store.get(&root_digest).await.expect("get root");

        match root_node {
            ProllyNode::Leaf(leaf) => assert_eq!(leaf.entries.len(), 3),
            _ => panic!("expected leaf root for small dataset"),
        }
    }

    #[tokio::test]
    async fn prolly_tree_builder_forces_multi_layer_construction() {
        let store = MemoryProllyStore::new();
        let mut builder = ProllyTreeBuilder::new(&store);
        builder.chunk_threshold = 0x0000_0003; // Force frequent chunking

        let mut entries = Vec::new();
        for i in 0..100 {
            entries.push(LeafEntry {
                key: format!("key-{:03}", i).into_bytes(),
                value: vec![i as u8],
            });
        }

        let root_digest = builder.build_from_entries(entries).await.expect("build");
        let root_node = store.get(&root_digest).await.expect("get root");

        match root_node {
            ProllyNode::Internal(internal) => {
                assert!(internal.entries.len() > 1);
                assert!(internal.entries.len() < 100);
            }
            _ => panic!("expected internal root for forced chunking"),
        }
    }

    #[tokio::test]
    async fn object_store_prolly_store_persists_to_filesystem() {
        use object_store::local::LocalFileSystem;
        use std::sync::Arc;
        use tempfile::tempdir;

        let temp = tempdir().expect("temp");
        let local = Arc::new(LocalFileSystem::new_with_prefix(temp.path()).expect("local"));
        let store = ObjectStoreProllyStore::new(local, "snapshots");

        let leaf = ProllyNode::Leaf(LeafNode {
            entries: vec![LeafEntry {
                key: b"test-key".to_vec(),
                value: b"test-value".to_vec(),
            }],
        });

        let digest = store.put(leaf.clone()).await.expect("put");
        let retrieved = store.get(&digest).await.expect("get");

        match (leaf, retrieved) {
            (ProllyNode::Leaf(orig), ProllyNode::Leaf(got)) => {
                assert_eq!(orig.entries.len(), got.entries.len());
                assert_eq!(orig.entries[0].key, got.entries[0].key);
            }
            _ => panic!("node mismatch"),
        }
    }
}
