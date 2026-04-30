use anyhow::{Context, Result, ensure};
use object_store::ObjectStoreExt;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
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

    pub fn node_count(&self) -> usize {
        self.nodes.lock().unwrap().len()
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
        let node = self
            .nodes
            .lock()
            .unwrap()
            .get(digest.digest())
            .cloned()
            .context("not found")?;
        ensure!(
            node.digest()? == *digest,
            "prolly node digest mismatch for {}",
            digest.digest()
        );
        Ok(node)
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
        let node: ProllyNode = serde_json::from_slice(&bytes).context("deserialize node")?;
        ensure!(
            node.digest()? == *digest,
            "prolly node digest mismatch for {}",
            digest.digest()
        );
        Ok(node)
    }
}

/// One node in a Prolly Tree.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProllyNode {
    Leaf(LeafNode),
    Internal(InternalNode),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LeafNode {
    pub entries: Vec<LeafEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LeafEntry {
    pub key: Vec<u8>,
    pub value: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct InternalNode {
    pub entries: Vec<InternalEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct InternalEntry {
    pub key: Vec<u8>,
    pub child_digest: ContentDigest,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ProllyDiff {
    Added {
        key: Vec<u8>,
        value: Vec<u8>,
    },
    Removed {
        key: Vec<u8>,
        value: Vec<u8>,
    },
    Changed {
        key: Vec<u8>,
        before: Vec<u8>,
        after: Vec<u8>,
    },
}

/// Metadata for a reusable materialization snapshot.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SnapshotManifest {
    pub materialization_id: String,
    pub snapshot_id: String,
    pub snapshot_kind: String,
    pub source_stream_id: StreamId,
    pub source_checkpoint: LineageCheckpoint,
    pub source_lineage_ref: String,
    pub source_manifest_generation: u64,
    pub source_checkpoint_ref: Option<String>,
    pub parent_snapshot_refs: Vec<String>,
    pub root_digest: ContentDigest,
    pub snapshot_root_ref: String,
    pub snapshot_stats_ref: Option<String>,
    pub created_at: i64,
    pub materializer_version: String,
}

pub struct ProllyTreeBuilder<'a, S: ProllyStore> {
    store: &'a S,
    chunk_threshold: u32,
}

struct InternalPathFrame {
    node: InternalNode,
    child_index: usize,
}

enum LeafPointMutation {
    Insert { key: Vec<u8>, value: Vec<u8> },
    Delete { key: Vec<u8> },
}

impl<'a, S: ProllyStore> ProllyTreeBuilder<'a, S> {
    pub fn new(store: &'a S) -> Self {
        Self {
            store,
            chunk_threshold: 0x000F_FFFF, // Adjust for chunk size
        }
    }

    pub async fn build_from_entries(&self, entries: Vec<LeafEntry>) -> Result<ContentDigest> {
        let entries = canonicalize_entries(entries)?;
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
                let separator_key = current_chunk
                    .last()
                    .expect("leaf chunk has at least one entry")
                    .key
                    .clone();
                let node = ProllyNode::Leaf(LeafNode {
                    entries: std::mem::take(&mut current_chunk),
                });
                let digest = self.store.put(node).await?;
                current_layer_digests.push(InternalEntry {
                    key: separator_key,
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
                    let separator_key = current_internal_chunk
                        .last()
                        .expect("internal chunk has at least one entry")
                        .key
                        .clone();
                    let node = ProllyNode::Internal(InternalNode {
                        entries: std::mem::take(&mut current_internal_chunk),
                    });
                    let digest = self.store.put(node).await?;
                    next_layer_digests.push(InternalEntry {
                        key: separator_key,
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

    pub async fn insert(
        &self,
        root_digest: &ContentDigest,
        key: impl Into<Vec<u8>>,
        value: impl Into<Vec<u8>>,
    ) -> Result<ContentDigest> {
        self.point_update(
            root_digest,
            LeafPointMutation::Insert {
                key: key.into(),
                value: value.into(),
            },
        )
        .await
    }

    pub async fn delete(&self, root_digest: &ContentDigest, key: &[u8]) -> Result<ContentDigest> {
        self.point_update(root_digest, LeafPointMutation::Delete { key: key.to_vec() })
            .await
    }

    pub async fn lookup(&self, root_digest: &ContentDigest, key: &[u8]) -> Result<Option<Vec<u8>>> {
        let mut next_digest = root_digest.clone();

        loop {
            match self.store.get(&next_digest).await? {
                ProllyNode::Leaf(leaf) => {
                    return Ok(leaf
                        .entries
                        .binary_search_by(|entry| entry.key.as_slice().cmp(key))
                        .ok()
                        .map(|index| leaf.entries[index].value.clone()));
                }
                ProllyNode::Internal(internal) => {
                    ensure!(
                        !internal.entries.is_empty(),
                        "internal prolly node must contain at least one child"
                    );
                    let child = internal
                        .entries
                        .iter()
                        .find(|entry| key <= entry.key.as_slice())
                        .unwrap_or_else(|| {
                            internal
                                .entries
                                .last()
                                .expect("internal node is known non-empty")
                        });
                    next_digest = child.child_digest.clone();
                }
            }
        }
    }

    pub async fn diff(
        &self,
        before_root: &ContentDigest,
        after_root: &ContentDigest,
    ) -> Result<Vec<ProllyDiff>> {
        let before = self.collect_entries(before_root).await?;
        let after = self.collect_entries(after_root).await?;
        let mut changes = Vec::new();

        for (key, before_value) in &before {
            match after.get(key) {
                Some(after_value) if after_value != before_value => {
                    changes.push(ProllyDiff::Changed {
                        key: key.clone(),
                        before: before_value.clone(),
                        after: after_value.clone(),
                    })
                }
                None => changes.push(ProllyDiff::Removed {
                    key: key.clone(),
                    value: before_value.clone(),
                }),
                _ => {}
            }
        }

        for (key, after_value) in &after {
            if !before.contains_key(key) {
                changes.push(ProllyDiff::Added {
                    key: key.clone(),
                    value: after_value.clone(),
                });
            }
        }

        Ok(changes)
    }

    async fn collect_entries(
        &self,
        root_digest: &ContentDigest,
    ) -> Result<BTreeMap<Vec<u8>, Vec<u8>>> {
        let mut entries = BTreeMap::new();
        let mut stack = vec![root_digest.clone()];

        while let Some(digest) = stack.pop() {
            match self.store.get(&digest).await? {
                ProllyNode::Leaf(leaf) => {
                    for entry in leaf.entries {
                        entries.insert(entry.key, entry.value);
                    }
                }
                ProllyNode::Internal(internal) => {
                    for entry in internal.entries.into_iter().rev() {
                        stack.push(entry.child_digest);
                    }
                }
            }
        }

        Ok(entries)
    }

    async fn point_update(
        &self,
        root_digest: &ContentDigest,
        mutation: LeafPointMutation,
    ) -> Result<ContentDigest> {
        let search_key = match &mutation {
            LeafPointMutation::Insert { key, .. } => key.as_slice(),
            LeafPointMutation::Delete { key } => key.as_slice(),
        };
        let mut path = Vec::new();
        let mut next_digest = root_digest.clone();

        let leaf = loop {
            match self.store.get(&next_digest).await? {
                ProllyNode::Leaf(leaf) => break leaf,
                ProllyNode::Internal(internal) => {
                    ensure!(
                        !internal.entries.is_empty(),
                        "internal prolly node must contain at least one child"
                    );
                    let child_index = self.child_index_for_key(&internal, search_key);
                    next_digest = internal.entries[child_index].child_digest.clone();
                    path.push(InternalPathFrame {
                        node: internal,
                        child_index,
                    });
                }
            }
        };

        let Some(updated_entries) = apply_leaf_mutation(leaf.entries, mutation) else {
            return Ok(root_digest.clone());
        };

        let mut replacement_entries = self.store_leaf_chunks(updated_entries).await?;
        for frame in path.into_iter().rev() {
            let mut entries = frame.node.entries;
            entries.splice(
                frame.child_index..=frame.child_index,
                replacement_entries.into_iter(),
            );
            replacement_entries = self.store_internal_chunks(entries).await?;
        }

        self.root_from_replacement_entries(replacement_entries)
            .await
    }

    fn child_index_for_key(&self, internal: &InternalNode, key: &[u8]) -> usize {
        internal
            .entries
            .iter()
            .position(|entry| key <= entry.key.as_slice())
            .unwrap_or_else(|| {
                internal
                    .entries
                    .len()
                    .checked_sub(1)
                    .expect("internal node is known non-empty")
            })
    }

    async fn store_leaf_chunks(&self, entries: Vec<LeafEntry>) -> Result<Vec<InternalEntry>> {
        let mut replacements = Vec::new();
        let mut current_chunk = Vec::new();

        for entry in entries {
            current_chunk.push(entry);
            if self.should_chunk_leaf(&current_chunk) {
                let separator_key = current_chunk
                    .last()
                    .expect("leaf chunk has at least one entry")
                    .key
                    .clone();
                let node = ProllyNode::Leaf(LeafNode {
                    entries: std::mem::take(&mut current_chunk),
                });
                let digest = self.store.put(node).await?;
                replacements.push(InternalEntry {
                    key: separator_key,
                    child_digest: digest,
                });
            }
        }

        if !current_chunk.is_empty() {
            let separator_key = current_chunk
                .last()
                .expect("leaf chunk has at least one entry")
                .key
                .clone();
            let node = ProllyNode::Leaf(LeafNode {
                entries: current_chunk,
            });
            let digest = self.store.put(node).await?;
            replacements.push(InternalEntry {
                key: separator_key,
                child_digest: digest,
            });
        }

        Ok(replacements)
    }

    async fn store_internal_chunks(
        &self,
        entries: Vec<InternalEntry>,
    ) -> Result<Vec<InternalEntry>> {
        let mut replacements = Vec::new();
        let mut current_chunk = Vec::new();

        for entry in entries {
            current_chunk.push(entry);
            if self.should_chunk_internal(&current_chunk) {
                let separator_key = current_chunk
                    .last()
                    .expect("internal chunk has at least one entry")
                    .key
                    .clone();
                let node = ProllyNode::Internal(InternalNode {
                    entries: std::mem::take(&mut current_chunk),
                });
                let digest = self.store.put(node).await?;
                replacements.push(InternalEntry {
                    key: separator_key,
                    child_digest: digest,
                });
            }
        }

        if !current_chunk.is_empty() {
            let separator_key = current_chunk
                .last()
                .expect("internal chunk has at least one entry")
                .key
                .clone();
            let node = ProllyNode::Internal(InternalNode {
                entries: current_chunk,
            });
            let digest = self.store.put(node).await?;
            replacements.push(InternalEntry {
                key: separator_key,
                child_digest: digest,
            });
        }

        Ok(replacements)
    }

    async fn root_from_replacement_entries(
        &self,
        mut entries: Vec<InternalEntry>,
    ) -> Result<ContentDigest> {
        if entries.is_empty() {
            return self
                .store
                .put(ProllyNode::Leaf(LeafNode {
                    entries: Vec::new(),
                }))
                .await;
        }

        while entries.len() > 1 {
            entries = self.store_internal_chunks(entries).await?;
        }

        Ok(entries
            .into_iter()
            .next()
            .expect("replacement entries are known non-empty")
            .child_digest)
    }

    fn should_chunk_leaf(&self, entries: &[LeafEntry]) -> bool {
        entries
            .last()
            .is_some_and(|last| stable_chunk_score(&last.key) & self.chunk_threshold == 0)
    }

    fn should_chunk_internal(&self, entries: &[InternalEntry]) -> bool {
        entries.len() > 1
            && entries
                .last()
                .is_some_and(|last| stable_chunk_score(&last.key) & self.chunk_threshold == 0)
    }
}

fn apply_leaf_mutation(
    mut entries: Vec<LeafEntry>,
    mutation: LeafPointMutation,
) -> Option<Vec<LeafEntry>> {
    match mutation {
        LeafPointMutation::Insert { key, value } => {
            match entries.binary_search_by(|entry| entry.key.cmp(&key)) {
                Ok(index) if entries[index].value == value => None,
                Ok(index) => {
                    entries[index].value = value;
                    Some(entries)
                }
                Err(index) => {
                    entries.insert(index, LeafEntry { key, value });
                    Some(entries)
                }
            }
        }
        LeafPointMutation::Delete { key } => {
            let index = entries.binary_search_by(|entry| entry.key.cmp(&key)).ok()?;
            entries.remove(index);
            Some(entries)
        }
    }
}

impl ProllyNode {
    pub fn digest(&self) -> Result<ContentDigest> {
        let encoded = serde_json::to_vec(self).context("serialize prolly node")?;
        ContentDigest::new("sha256", sha256_hex(&encoded))
    }
}

fn canonicalize_entries(mut entries: Vec<LeafEntry>) -> Result<Vec<LeafEntry>> {
    entries.sort_by(|left, right| left.key.cmp(&right.key));

    for pair in entries.windows(2) {
        ensure!(
            pair[0].key != pair[1].key,
            "prolly tree entries must not contain duplicate keys"
        );
    }

    Ok(entries)
}

fn stable_chunk_score(bytes: &[u8]) -> u32 {
    use sha2::{Digest, Sha256};
    let digest = Sha256::digest(bytes);
    u32::from_be_bytes([digest[0], digest[1], digest[2], digest[3]])
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
    use std::sync::Mutex;
    use std::sync::atomic::{AtomicUsize, Ordering};

    fn entry(key: &str, value: &str) -> LeafEntry {
        LeafEntry {
            key: key.as_bytes().to_vec(),
            value: value.as_bytes().to_vec(),
        }
    }

    struct CountingProllyStore {
        nodes: Mutex<std::collections::HashMap<String, ProllyNode>>,
        gets: AtomicUsize,
        puts: AtomicUsize,
    }

    impl CountingProllyStore {
        fn new() -> Self {
            Self {
                nodes: Mutex::new(std::collections::HashMap::new()),
                gets: AtomicUsize::new(0),
                puts: AtomicUsize::new(0),
            }
        }

        fn reset_counts(&self) {
            self.gets.store(0, Ordering::SeqCst);
            self.puts.store(0, Ordering::SeqCst);
        }

        fn counts(&self) -> (usize, usize) {
            (
                self.gets.load(Ordering::SeqCst),
                self.puts.load(Ordering::SeqCst),
            )
        }

        fn node_count(&self) -> usize {
            self.nodes.lock().unwrap().len()
        }
    }

    #[async_trait::async_trait]
    impl ProllyStore for CountingProllyStore {
        async fn put(&self, node: ProllyNode) -> Result<ContentDigest> {
            self.puts.fetch_add(1, Ordering::SeqCst);
            let digest = node.digest()?;
            self.nodes
                .lock()
                .unwrap()
                .insert(digest.digest().to_string(), node);
            Ok(digest)
        }

        async fn get(&self, digest: &ContentDigest) -> Result<ProllyNode> {
            self.gets.fetch_add(1, Ordering::SeqCst);
            let node = self
                .nodes
                .lock()
                .unwrap()
                .get(digest.digest())
                .cloned()
                .context("not found")?;
            ensure!(
                node.digest()? == *digest,
                "prolly node digest mismatch for {}",
                digest.digest()
            );
            Ok(node)
        }
    }

    fn node_max_key(node: &ProllyNode) -> Vec<u8> {
        match node {
            ProllyNode::Leaf(leaf) => leaf
                .entries
                .last()
                .expect("leaf node is non-empty")
                .key
                .clone(),
            ProllyNode::Internal(internal) => internal
                .entries
                .last()
                .expect("internal node is non-empty")
                .key
                .clone(),
        }
    }

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
    async fn prolly_tree_builder_sorts_entries_and_constructs_root() {
        let store = MemoryProllyStore::new();
        let builder = ProllyTreeBuilder::new(&store);

        let entries = vec![entry("c", "3"), entry("a", "1"), entry("b", "2")];

        let root_digest = builder.build_from_entries(entries).await.expect("build");
        let root_node = store.get(&root_digest).await.expect("get root");

        match root_node {
            ProllyNode::Leaf(leaf) => {
                assert_eq!(
                    leaf.entries
                        .iter()
                        .map(|entry| entry.key.as_slice())
                        .collect::<Vec<_>>(),
                    vec![b"a".as_slice(), b"b".as_slice(), b"c".as_slice()]
                );
                assert_eq!(
                    leaf.entries
                        .iter()
                        .map(|entry| entry.value.as_slice())
                        .collect::<Vec<_>>(),
                    vec![b"1".as_slice(), b"2".as_slice(), b"3".as_slice()]
                );
            }
            _ => panic!("expected leaf root for small dataset"),
        }
    }

    #[tokio::test]
    async fn prolly_tree_builder_rejects_duplicate_keys() {
        let store = MemoryProllyStore::new();
        let builder = ProllyTreeBuilder::new(&store);

        let err = builder
            .build_from_entries(vec![entry("a", "1"), entry("a", "2")])
            .await
            .expect_err("duplicate keys should be rejected");

        assert!(format!("{err:#}").contains("duplicate keys"));
    }

    #[tokio::test]
    async fn prolly_tree_builder_preserves_multi_layer_separator_keys() {
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
                assert!(internal.entries.iter().all(|entry| !entry.key.is_empty()));
                assert!(
                    internal
                        .entries
                        .windows(2)
                        .all(|pair| pair[0].key <= pair[1].key)
                );
                for entry in internal.entries {
                    let child = store.get(&entry.child_digest).await.expect("get child");
                    assert_eq!(entry.key, node_max_key(&child));
                }
            }
            _ => panic!("expected internal root for forced chunking"),
        }
    }

    #[tokio::test]
    async fn prolly_lookup_and_diff_work_for_single_layer_tree() {
        let store = MemoryProllyStore::new();
        let builder = ProllyTreeBuilder::new(&store);

        let before_root = builder
            .build_from_entries(vec![entry("a", "1"), entry("b", "2")])
            .await
            .expect("build before");
        let after_root = builder
            .build_from_entries(vec![
                entry("a", "1"),
                entry("b", "changed"),
                entry("c", "3"),
            ])
            .await
            .expect("build after");

        assert_eq!(
            builder
                .lookup(&after_root, b"b")
                .await
                .expect("lookup changed key"),
            Some(b"changed".to_vec())
        );
        assert_eq!(
            builder
                .lookup(&after_root, b"missing")
                .await
                .expect("lookup missing key"),
            None
        );

        let diff = builder
            .diff(&before_root, &after_root)
            .await
            .expect("diff snapshots");
        assert_eq!(
            diff,
            vec![
                ProllyDiff::Changed {
                    key: b"b".to_vec(),
                    before: b"2".to_vec(),
                    after: b"changed".to_vec(),
                },
                ProllyDiff::Added {
                    key: b"c".to_vec(),
                    value: b"3".to_vec(),
                },
            ]
        );
    }

    #[tokio::test]
    async fn prolly_insert_returns_new_root_without_rewriting_existing_root() {
        let store = MemoryProllyStore::new();
        let builder = ProllyTreeBuilder::new(&store);

        let before_root = builder
            .build_from_entries(vec![entry("a", "1"), entry("c", "3")])
            .await
            .expect("build before");

        let after_root = builder
            .insert(&before_root, b"b".to_vec(), b"2".to_vec())
            .await
            .expect("insert key");

        assert_ne!(before_root, after_root);
        assert_eq!(
            builder
                .lookup(&before_root, b"b")
                .await
                .expect("lookup before"),
            None
        );
        assert_eq!(
            builder
                .lookup(&after_root, b"b")
                .await
                .expect("lookup after"),
            Some(b"2".to_vec())
        );
        assert_eq!(
            builder
                .lookup(&after_root, b"c")
                .await
                .expect("lookup existing"),
            Some(b"3".to_vec())
        );
    }

    #[tokio::test]
    async fn prolly_delete_returns_new_root_and_preserves_absent_deletes() {
        let store = MemoryProllyStore::new();
        let builder = ProllyTreeBuilder::new(&store);

        let before_root = builder
            .build_from_entries(vec![entry("a", "1"), entry("b", "2"), entry("c", "3")])
            .await
            .expect("build before");

        let after_root = builder
            .delete(&before_root, b"b")
            .await
            .expect("delete key");
        let missing_delete_root = builder
            .delete(&after_root, b"missing")
            .await
            .expect("delete missing key");

        assert_ne!(before_root, after_root);
        assert_eq!(after_root, missing_delete_root);
        assert_eq!(
            builder
                .lookup(&after_root, b"b")
                .await
                .expect("lookup deleted"),
            None
        );
        assert_eq!(
            builder
                .lookup(&after_root, b"a")
                .await
                .expect("lookup retained"),
            Some(b"1".to_vec())
        );
    }

    #[tokio::test]
    async fn prolly_insert_and_delete_work_for_multi_layer_tree() {
        let store = MemoryProllyStore::new();
        let mut builder = ProllyTreeBuilder::new(&store);
        builder.chunk_threshold = 0x0000_0003;

        let entries = (0..256)
            .map(|index| LeafEntry {
                key: format!("key-{index:03}").into_bytes(),
                value: format!("value-{index:03}").into_bytes(),
            })
            .collect::<Vec<_>>();

        let root = builder.build_from_entries(entries).await.expect("build");
        assert!(store.node_count() > 32, "forced tree should be multi-layer");
        assert!(matches!(
            store.get(&root).await.expect("get root"),
            ProllyNode::Internal(_)
        ));

        let inserted_root = builder
            .insert(&root, b"key-127a".to_vec(), b"value-inserted".to_vec())
            .await
            .expect("insert into multi-layer tree");
        assert_eq!(
            builder
                .lookup(&inserted_root, b"key-127a")
                .await
                .expect("lookup inserted"),
            Some(b"value-inserted".to_vec())
        );
        assert_eq!(
            builder
                .lookup(&root, b"key-127a")
                .await
                .expect("lookup original root"),
            None
        );

        let deleted_root = builder
            .delete(&inserted_root, b"key-128")
            .await
            .expect("delete from multi-layer tree");
        assert_eq!(
            builder
                .lookup(&deleted_root, b"key-128")
                .await
                .expect("lookup deleted"),
            None
        );
        assert_eq!(
            builder
                .lookup(&root, b"key-128")
                .await
                .expect("lookup original retained"),
            Some(b"value-128".to_vec())
        );
        assert_eq!(
            builder
                .lookup(&deleted_root, b"key-127a")
                .await
                .expect("lookup inserted after delete"),
            Some(b"value-inserted".to_vec())
        );
    }

    #[tokio::test]
    async fn prolly_point_updates_touch_logarithmic_node_count() {
        let store = CountingProllyStore::new();
        let mut builder = ProllyTreeBuilder::new(&store);
        builder.chunk_threshold = 0x0000_0003;

        let entries = (0..2048)
            .map(|index| LeafEntry {
                key: format!("key-{index:04}").into_bytes(),
                value: format!("value-{index:04}").into_bytes(),
            })
            .collect::<Vec<_>>();

        let root = builder.build_from_entries(entries).await.expect("build");
        let total_nodes = store.node_count();
        assert!(
            total_nodes > 128,
            "test setup must build enough nodes to distinguish path updates"
        );

        store.reset_counts();
        let inserted_root = builder
            .insert(&root, b"key-1024a".to_vec(), b"value-inserted".to_vec())
            .await
            .expect("insert key");
        let (insert_gets, insert_puts) = store.counts();

        assert_eq!(
            builder
                .lookup(&inserted_root, b"key-1024a")
                .await
                .expect("lookup inserted"),
            Some(b"value-inserted".to_vec())
        );
        assert!(
            insert_gets + insert_puts <= 64,
            "insert touched too many nodes: gets={insert_gets}, puts={insert_puts}, total_nodes={total_nodes}"
        );
        assert!(
            (insert_gets + insert_puts) * 8 < total_nodes,
            "insert should touch far less than the full tree: gets={insert_gets}, puts={insert_puts}, total_nodes={total_nodes}"
        );

        store.reset_counts();
        let deleted_root = builder
            .delete(&inserted_root, b"key-1024")
            .await
            .expect("delete key");
        let (delete_gets, delete_puts) = store.counts();

        assert_eq!(
            builder
                .lookup(&deleted_root, b"key-1024")
                .await
                .expect("lookup deleted"),
            None
        );
        assert!(
            delete_gets + delete_puts <= 64,
            "delete touched too many nodes: gets={delete_gets}, puts={delete_puts}, total_nodes={total_nodes}"
        );
        assert!(
            (delete_gets + delete_puts) * 8 < total_nodes,
            "delete should touch far less than the full tree: gets={delete_gets}, puts={delete_puts}, total_nodes={total_nodes}"
        );
    }

    #[tokio::test]
    async fn prolly_lookup_and_diff_work_for_multi_layer_tree() {
        let store = MemoryProllyStore::new();
        let mut builder = ProllyTreeBuilder::new(&store);
        builder.chunk_threshold = 0x0000_0003;

        let before_entries = (0..96)
            .map(|index| LeafEntry {
                key: format!("key-{index:03}").into_bytes(),
                value: format!("value-{index:03}").into_bytes(),
            })
            .collect::<Vec<_>>();
        let mut after_entries = before_entries.clone();
        after_entries.retain(|entry| entry.key != b"key-010");
        after_entries
            .iter_mut()
            .find(|entry| entry.key == b"key-020")
            .expect("changed key exists")
            .value = b"changed".to_vec();
        after_entries.push(entry("key-999", "new"));

        let before_root = builder
            .build_from_entries(before_entries)
            .await
            .expect("build before");
        let after_root = builder
            .build_from_entries(after_entries)
            .await
            .expect("build after");

        assert_eq!(
            builder
                .lookup(&after_root, b"key-020")
                .await
                .expect("lookup changed key"),
            Some(b"changed".to_vec())
        );
        assert_eq!(
            builder
                .lookup(&after_root, b"key-010")
                .await
                .expect("lookup removed key"),
            None
        );

        let diff = builder
            .diff(&before_root, &after_root)
            .await
            .expect("diff snapshots");
        assert!(diff.contains(&ProllyDiff::Removed {
            key: b"key-010".to_vec(),
            value: b"value-010".to_vec(),
        }));
        assert!(diff.contains(&ProllyDiff::Changed {
            key: b"key-020".to_vec(),
            before: b"value-020".to_vec(),
            after: b"changed".to_vec(),
        }));
        assert!(diff.contains(&ProllyDiff::Added {
            key: b"key-999".to_vec(),
            value: b"new".to_vec(),
        }));
    }

    #[tokio::test]
    async fn object_store_backed_prolly_tree_supports_lookup_and_diff() {
        use object_store::local::LocalFileSystem;
        use std::sync::Arc;
        use tempfile::tempdir;

        let temp = tempdir().expect("temp");
        let local = Arc::new(LocalFileSystem::new_with_prefix(temp.path()).expect("local"));
        let store = ObjectStoreProllyStore::new(local, "snapshots");
        let builder = ProllyTreeBuilder::new(&store);

        let before_root = builder
            .build_from_entries(vec![entry("test-key", "test-value")])
            .await
            .expect("build before");
        let after_root = builder
            .build_from_entries(vec![
                entry("other-key", "other-value"),
                entry("test-key", "updated-value"),
            ])
            .await
            .expect("build after");

        assert_eq!(
            builder
                .lookup(&after_root, b"test-key")
                .await
                .expect("lookup object store key"),
            Some(b"updated-value".to_vec())
        );

        let diff = builder
            .diff(&before_root, &after_root)
            .await
            .expect("diff object-store snapshots");
        assert!(diff.contains(&ProllyDiff::Changed {
            key: b"test-key".to_vec(),
            before: b"test-value".to_vec(),
            after: b"updated-value".to_vec(),
        }));
        assert!(diff.contains(&ProllyDiff::Added {
            key: b"other-key".to_vec(),
            value: b"other-value".to_vec(),
        }));

        let root_node = store.get(&after_root).await.expect("get persisted root");
        assert!(matches!(root_node, ProllyNode::Leaf(_)));
    }
}
