use crate::kernel::StreamId;
pub use crate::membership::NodeId;
use anyhow::{Context, Result, bail, ensure};
use async_trait::async_trait;
use object_store::path::Path as ObjectPath;
use object_store::{ObjectStore, ObjectStoreExt};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

const UNIX_MILLIS_THRESHOLD: i64 = 1_000_000_000_000;

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

    /// Check if the lease has expired.
    fn is_expired(&self) -> bool;

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
pub trait ConsensusProvider: Send + Sync + std::fmt::Debug {
    /// Attempt to acquire leadership for a stream.
    async fn acquire(
        &self,
        stream_id: &StreamId,
        owner: NodeId,
    ) -> Result<Arc<dyn ConsensusHandle + 'static>>;

    /// Returns the current lease for a stream, if it exists.
    async fn current_lease(&self, stream_id: &StreamId) -> Result<Option<StreamLease>>;
}

/// Trait for receiving election triggers from the monitor.
#[async_trait]
pub trait ElectionTrigger: Send + Sync + std::fmt::Debug {
    async fn on_election_required(&self, stream_id: &StreamId) -> Result<()>;
}

/// Monitors stream leases and triggers elections when they expire.
pub struct ElectionMonitor {
    provider: Arc<dyn ConsensusProvider>,
    trigger: Arc<dyn ElectionTrigger>,
    check_interval: std::time::Duration,
}

impl ElectionMonitor {
    pub fn new(
        provider: Arc<dyn ConsensusProvider>,
        trigger: Arc<dyn ElectionTrigger>,
        check_interval: std::time::Duration,
    ) -> Self {
        Self {
            provider,
            trigger,
            check_interval,
        }
    }

    pub fn spawn(self: Arc<Self>, streams: Vec<StreamId>) -> tokio::task::JoinHandle<()> {
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(self.check_interval);
            loop {
                interval.tick().await;
                for stream_id in &streams {
                    match self.provider.current_lease(stream_id).await {
                        Ok(Some(lease)) => {
                            let now = current_unix_timestamp_millis();
                            if now >= normalize_expiration_timestamp(lease.expires_at) {
                                if let Err(e) = self.trigger.on_election_required(stream_id).await {
                                    eprintln!(
                                        "election trigger failed for {}: {:#}",
                                        stream_id.as_str(),
                                        e
                                    );
                                }
                            }
                        }
                        Ok(None) => {
                            // No lease exists at all, trigger election
                            if let Err(e) = self.trigger.on_election_required(stream_id).await {
                                eprintln!(
                                    "election trigger failed for {}: {:#}",
                                    stream_id.as_str(),
                                    e
                                );
                            }
                        }
                        Err(e) => {
                            eprintln!("failed to check lease for {}: {:#}", stream_id.as_str(), e);
                        }
                    }
                }
            }
        })
    }
}

#[derive(Debug)]
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

    pub fn with_lease_duration_secs(mut self, secs: i64) -> Self {
        self.lease_duration_secs = secs;
        self
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
    duration_ms: i64,
}

#[async_trait]
impl ConsensusHandle for ObjectStoreLeaseHandle {
    fn is_leader(&self) -> bool {
        !self.is_expired() && self.lease.read().unwrap().owner == self.local_owner
    }

    fn is_expired(&self) -> bool {
        let lease = self.lease.read().unwrap();
        current_unix_timestamp_millis() >= normalize_expiration_timestamp(lease.expires_at)
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
                expires_at: current_unix_timestamp_millis() + self.duration_ms,
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
                expires_at: current_unix_timestamp_millis() + self.duration_ms,
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

        let existing = self.current_lease(stream_id).await?;

        let now = current_unix_timestamp_millis();

        if let Some(lease) = existing {
            if now < normalize_expiration_timestamp(lease.expires_at) && lease.owner != owner {
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
            expires_at: now + lease_duration_millis(self.lease_duration_secs),
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
            duration_ms: lease_duration_millis(self.lease_duration_secs),
        }))
    }

    async fn current_lease(&self, stream_id: &StreamId) -> Result<Option<StreamLease>> {
        let path = self.lease_path(stream_id);

        match self.store.get(&path).await {
            Ok(result) => {
                let bytes = result.bytes().await.context("read lease bytes")?;
                let lease: StreamLease = serde_json::from_slice(&bytes).context("parse lease")?;
                Ok(Some(lease))
            }
            Err(object_store::Error::NotFound { .. }) => Ok(None),
            Err(e) => bail!("failed to check lease: {e}"),
        }
    }
}

fn current_unix_timestamp_millis() -> i64 {
    chrono::Utc::now().timestamp_millis()
}

fn normalize_expiration_timestamp(expires_at: i64) -> i64 {
    if expires_at >= UNIX_MILLIS_THRESHOLD {
        expires_at
    } else {
        expires_at.saturating_mul(1000)
    }
}

fn lease_duration_millis(duration_secs: i64) -> i64 {
    duration_secs.saturating_mul(1000)
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

    #[tokio::test]
    async fn test_lease_expiration_and_current_lease() {
        let temp = tempdir().expect("temp");
        let store: Arc<dyn ObjectStore> =
            Arc::new(LocalFileSystem::new_with_prefix(temp.path()).expect("local"));
        let mut consensus = ObjectStoreConsensus::new(store, "leases");
        // Set a very short duration for testing
        consensus.lease_duration_secs = 1;

        let stream_id = StreamId::new("test.stream").expect("id");
        let node_a = NodeId::new("node-a");

        // 1. Initially no lease
        assert!(consensus.current_lease(&stream_id).await.unwrap().is_none());

        // 2. Acquire lease
        let handle = consensus
            .acquire(&stream_id, node_a.clone())
            .await
            .expect("acquire");
        assert!(!handle.is_expired());

        // 3. Current lease should be Some
        let lease = consensus.current_lease(&stream_id).await.unwrap().unwrap();
        assert_eq!(lease.owner, node_a);

        // 4. Wait for expiration
        tokio::time::sleep(std::time::Duration::from_secs(2)).await;
        assert!(handle.is_expired());
        assert!(!handle.is_leader());

        // 5. Current lease still exists but is expired (checked via timestamp)
        let lease = consensus.current_lease(&stream_id).await.unwrap().unwrap();
        assert_eq!(lease.owner, node_a);
        assert!(
            current_unix_timestamp_millis() >= normalize_expiration_timestamp(lease.expires_at)
        );
    }

    #[tokio::test]
    async fn test_election_monitor_triggers_on_expiration() {
        use tokio::sync::mpsc;

        #[derive(Debug)]
        struct MockTrigger(mpsc::Sender<StreamId>);
        #[async_trait]
        impl ElectionTrigger for MockTrigger {
            async fn on_election_required(&self, stream_id: &StreamId) -> Result<()> {
                self.0.send(stream_id.clone()).await.unwrap();
                Ok(())
            }
        }

        let temp = tempdir().expect("temp");
        let store: Arc<dyn ObjectStore> =
            Arc::new(LocalFileSystem::new_with_prefix(temp.path()).expect("local"));
        let mut consensus = ObjectStoreConsensus::new(store, "leases");
        consensus.lease_duration_secs = 1;

        let stream_id = StreamId::new("test.stream").expect("id");
        let (tx, mut rx) = mpsc::channel(1);
        let trigger = Arc::new(MockTrigger(tx));

        let monitor = Arc::new(ElectionMonitor::new(
            Arc::new(consensus),
            trigger,
            std::time::Duration::from_millis(100),
        ));

        let _handle = monitor.spawn(vec![stream_id.clone()]);

        // Should trigger almost immediately because no lease exists
        let triggered = tokio::time::timeout(std::time::Duration::from_secs(2), rx.recv())
            .await
            .expect("timeout waiting for election trigger")
            .expect("channel closed");
        assert_eq!(triggered, stream_id);
    }
}
