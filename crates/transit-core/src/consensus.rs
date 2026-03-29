use crate::kernel::StreamId;
use anyhow::{Context, Result, bail, ensure};
use async_trait::async_trait;
use object_store::path::Path as ObjectPath;
use object_store::{ObjectStore, ObjectStoreExt};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
/// Identifies a unique node in the Transit cluster.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NodeId(pub String);

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
pub trait ConsensusHandle: std::fmt::Debug + Send + Sync {
    /// Check if this handle still represents the current leader for the stream.
    fn is_leader(&self) -> bool;

    /// The stream this lease belongs to.
    fn stream_id(&self) -> &StreamId;

    /// Copy of the current lease state.
    fn lease(&self) -> StreamLease;

    /// Attempt to heartbeat the lease to keep it alive.
    async fn heartbeat(&self) -> Result<()>;

    /// Explicitly hand writable ownership to a new owner.
    async fn handoff(&self, next_owner: NodeId) -> Result<StreamLease>;
}

/// Provider for distributed coordination.
#[async_trait]
pub trait ConsensusProvider: Send + Sync {
    /// Attempt to acquire leadership for a stream.
    async fn acquire(
        &self,
        stream_id: &StreamId,
        owner: NodeId,
    ) -> Result<Arc<dyn ConsensusHandle + 'static>>;
}

pub struct ObjectStoreConsensus {
    store: Arc<dyn ObjectStore>,
    prefix: ObjectPath,
    lease_duration_secs: i64,
}

/// Manages active leases and their background heartbeats.
pub struct ConsensusManager {
    provider: Arc<dyn ConsensusProvider>,
    node_id: NodeId,
    active_leases: Arc<
        std::sync::RwLock<std::collections::HashMap<StreamId, Arc<dyn ConsensusHandle + 'static>>>,
    >,
    shutdown: tokio::sync::broadcast::Sender<()>,
}

impl ConsensusManager {
    pub fn new(provider: Arc<dyn ConsensusProvider>, node_id: NodeId) -> Self {
        let (shutdown, _) = tokio::sync::broadcast::channel(1);
        Self {
            provider,
            node_id,
            active_leases: Arc::new(std::sync::RwLock::new(std::collections::HashMap::new())),
            shutdown,
        }
    }

    /// Acquire leadership for a stream and start heartbeating.
    pub async fn acquire(
        &self,
        stream_id: &StreamId,
    ) -> Result<Arc<dyn ConsensusHandle + 'static>> {
        let handle = self
            .provider
            .acquire(stream_id, self.node_id.clone())
            .await?;
        self.active_leases
            .write()
            .unwrap()
            .insert(stream_id.clone(), handle.clone());
        Ok(handle)
    }

    pub fn node_id(&self) -> &NodeId {
        &self.node_id
    }

    /// Spawn the background heartbeat loop.
    pub fn spawn_heartbeat_loop(&self) -> tokio::task::JoinHandle<()> {
        let active_leases = self.active_leases.clone();
        let mut shutdown = self.shutdown.subscribe();

        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(10));
            loop {
                tokio::select! {
                    _ = interval.tick() => {
                        let handles: Vec<(StreamId, Arc<dyn ConsensusHandle>)> = {
                            let map = active_leases.read().unwrap();
                            map.iter().map(|(k, v)| (k.clone(), v.clone())).collect()
                        };

                        for (stream_id, handle) in handles {
                            if let Err(e) = handle.heartbeat().await {
                                eprintln!("failed to heartbeat lease for stream '{}': {:#}", stream_id.as_str(), e);
                            }
                        }
                    }
                    _ = shutdown.recv() => break,
                }
            }
        })
    }

    pub fn shutdown(&self) {
        let _ = self.shutdown.send(());
    }
}

impl ObjectStoreConsensus {
    pub fn new(store: Arc<dyn ObjectStore>, prefix: impl Into<String>) -> Self {
        Self {
            store,
            prefix: ObjectPath::from(prefix.into()),
            lease_duration_secs: 30,
        }
    }

    fn lease_path(&self, stream_id: &StreamId) -> ObjectPath {
        self.prefix
            .clone()
            .child(format!("{}.lease.json", stream_id.as_str()))
    }
}

#[derive(Debug)]
struct ObjectStoreLeaseHandle {
    store: Arc<dyn ObjectStore>,
    path: ObjectPath,
    stream_id: StreamId,
    local_owner: NodeId,
    lease: std::sync::RwLock<StreamLease>,
    duration: i64,
}

#[async_trait]
impl ConsensusHandle for ObjectStoreLeaseHandle {
    fn is_leader(&self) -> bool {
        let lease = self.lease.read().unwrap();
        chrono::Utc::now().timestamp() < lease.expires_at && lease.owner == self.local_owner
    }

    fn stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    fn lease(&self) -> StreamLease {
        self.lease.read().unwrap().clone()
    }

    async fn heartbeat(&self) -> Result<()> {
        ensure!(
            self.is_leader(),
            "cannot heartbeat lease for '{}' after ownership moved",
            self.stream_id.as_str()
        );

        let next_lease = {
            let lease = self.lease.read().unwrap();
            StreamLease {
                stream_id: lease.stream_id.clone(),
                owner: lease.owner.clone(),
                version: lease.version + 1,
                expires_at: chrono::Utc::now().timestamp() + self.duration,
            }
        };

        let bytes = serde_json::to_vec(&next_lease).context("serialize lease")?;
        self.store
            .put(&self.path, bytes.into())
            .await
            .context("put heartbeat")?;

        *self.lease.write().unwrap() = next_lease;
        Ok(())
    }

    async fn handoff(&self, next_owner: NodeId) -> Result<StreamLease> {
        ensure!(
            self.is_leader(),
            "cannot handoff non-leader lease for '{}'",
            self.stream_id.as_str()
        );

        let next_lease = {
            let lease = self.lease.read().unwrap();
            ensure!(
                lease.owner != next_owner,
                "stream '{}' is already owned by '{}'",
                self.stream_id.as_str(),
                next_owner.as_str()
            );

            StreamLease {
                stream_id: lease.stream_id.clone(),
                owner: next_owner,
                version: lease.version + 1,
                expires_at: chrono::Utc::now().timestamp() + self.duration,
            }
        };

        let bytes = serde_json::to_vec(&next_lease).context("serialize handoff lease")?;
        self.store
            .put(&self.path, bytes.into())
            .await
            .context("put handoff lease")?;

        *self.lease.write().unwrap() = next_lease.clone();
        Ok(next_lease)
    }
}

#[async_trait]
impl ConsensusProvider for ObjectStoreConsensus {
    async fn acquire(
        &self,
        stream_id: &StreamId,
        owner: NodeId,
    ) -> Result<Arc<dyn ConsensusHandle + 'static>> {
        let path = self.lease_path(stream_id);

        let existing = match self.store.get(&path).await {
            Ok(result) => {
                let bytes = result.bytes().await.context("read lease bytes")?;
                let lease: StreamLease = serde_json::from_slice(&bytes).context("parse lease")?;
                Some(lease)
            }
            Err(object_store::Error::NotFound { .. }) => None,
            Err(e) => bail!("failed to check lease: {e}"),
        };

        let now = chrono::Utc::now().timestamp();

        if let Some(lease) = existing {
            if now < lease.expires_at && lease.owner != owner {
                bail!(
                    "stream '{}' is currently owned by '{}'",
                    stream_id.as_str(),
                    lease.owner.as_str()
                );
            }
        }

        let lease = StreamLease {
            stream_id: stream_id.clone(),
            owner: owner.clone(),
            version: now as u64,
            expires_at: now + self.lease_duration_secs,
        };

        let bytes = serde_json::to_vec(&lease).context("serialize lease")?;
        self.store
            .put(&path, bytes.into())
            .await
            .context("put lease")?;

        Ok(Arc::new(ObjectStoreLeaseHandle {
            store: self.store.clone(),
            path,
            stream_id: stream_id.clone(),
            local_owner: owner,
            lease: std::sync::RwLock::new(lease),
            duration: self.lease_duration_secs,
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use object_store::local::LocalFileSystem;
    use tempfile::tempdir;

    #[tokio::test]
    async fn object_store_consensus_manages_exclusive_leases() {
        let temp = tempdir().expect("temp");
        let store: Arc<dyn ObjectStore> =
            Arc::new(LocalFileSystem::new_with_prefix(temp.path()).expect("local"));
        let consensus = ObjectStoreConsensus::new(store, "leases");

        let stream_id = StreamId::new("test.stream").expect("id");
        let node_a = NodeId::new("node-a");
        let node_b = NodeId::new("node-b");

        // 1. Node A acquires lease
        let handle_a = consensus
            .acquire(&stream_id, node_a.clone())
            .await
            .expect("a acquire");
        assert!(handle_a.is_leader());
        assert_eq!(handle_a.lease().owner, node_a);

        // 2. Node B fails to acquire active lease
        consensus
            .acquire(&stream_id, node_b.clone())
            .await
            .expect_err("b should fail");

        // 3. Node A heartbeats
        let version_before = handle_a.lease().version;
        handle_a.heartbeat().await.expect("a heartbeat");
        assert!(handle_a.lease().version > version_before);
    }

    #[tokio::test]
    async fn object_store_consensus_supports_explicit_handoff() {
        let temp = tempdir().expect("temp");
        let store: Arc<dyn ObjectStore> =
            Arc::new(LocalFileSystem::new_with_prefix(temp.path()).expect("local"));
        let consensus = ObjectStoreConsensus::new(store, "leases");

        let stream_id = StreamId::new("test.stream").expect("id");
        let handle_a = consensus
            .acquire(&stream_id, NodeId::new("node-a"))
            .await
            .expect("a acquire");
        let handed_off = handle_a
            .handoff(NodeId::new("node-b"))
            .await
            .expect("handoff");

        assert_eq!(handed_off.owner, NodeId::new("node-b"));
        assert!(!handle_a.is_leader());

        let handle_b = consensus
            .acquire(&stream_id, NodeId::new("node-b"))
            .await
            .expect("b acquire");
        assert!(handle_b.is_leader());

        let err = handle_a.heartbeat().await.expect_err("old owner fenced");
        assert!(err.to_string().contains("ownership moved"));
    }

    #[tokio::test]
    async fn consensus_manager_manages_background_heartbeats() {
        let temp = tempdir().expect("temp");
        let store: Arc<dyn ObjectStore> =
            Arc::new(LocalFileSystem::new_with_prefix(temp.path()).expect("local"));
        let provider = Arc::new(ObjectStoreConsensus::new(store, "leases"));
        let manager = ConsensusManager::new(provider, NodeId::new("test-node"));

        let stream_id = StreamId::new("test.stream").expect("id");
        let handle = manager.acquire(&stream_id).await.expect("acquire");

        let initial_version = handle.lease().version;

        // Manual heartbeat to prove it works through the manager's handle
        handle.heartbeat().await.expect("manual heartbeat");
        assert_eq!(handle.lease().version, initial_version + 1);

        manager.shutdown();
    }
}
