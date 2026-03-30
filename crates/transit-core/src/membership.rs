use futures::StreamExt;
use object_store::{ObjectStore, ObjectStoreExt};
use serde::{Deserialize, Serialize};
use std::fmt::Debug;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Unique identity of a node in the cluster.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct NodeId(pub String);

impl NodeId {
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl std::fmt::Display for NodeId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Heartbeat data for a node.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeHeartbeat {
    pub identity: NodeId,
    pub last_seen_ts: u64,
}

/// Trait for querying cluster membership and calculating quorum.
#[async_trait::async_trait]
pub trait ClusterMembership: Send + Sync + Debug {
    /// Registers the node's presence and heartbeats its status.
    async fn heartbeat(&self, identity: &NodeId) -> anyhow::Result<()>;

    /// Returns the set of nodes currently recognized as members of the cluster.
    async fn nodes(&self) -> anyhow::Result<Vec<NodeId>>;

    /// Calculates the quorum size (majority) based on the current membership.
    async fn quorum_size(&self) -> anyhow::Result<usize> {
        let n = self.nodes().await?.len();
        Ok(if n == 0 { 0 } else { (n / 2) + 1 })
    }
}

/// Membership provider backed by an ObjectStore.
#[derive(Debug)]
pub struct ObjectStoreMembership {
    store: Arc<dyn ObjectStore>,
    heartbeat_expiry: Duration,
}

impl ObjectStoreMembership {
    pub fn new(store: Arc<dyn ObjectStore>, heartbeat_expiry: Duration) -> Self {
        Self {
            store,
            heartbeat_expiry,
        }
    }

    fn heartbeat_path(identity: &NodeId) -> String {
        format!("cluster/membership/{}.json", identity.0)
    }
}

#[async_trait::async_trait]
impl ClusterMembership for ObjectStoreMembership {
    async fn heartbeat(&self, identity: &NodeId) -> anyhow::Result<()> {
        let ts = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let heartbeat = NodeHeartbeat {
            identity: identity.clone(),
            last_seen_ts: ts,
        };
        let bytes = serde_json::to_vec(&heartbeat)?;
        self.store
            .put(&Self::heartbeat_path(identity).into(), bytes.into())
            .await?;
        Ok(())
    }

    async fn nodes(&self) -> anyhow::Result<Vec<NodeId>> {
        let prefix = object_store::path::Path::from("cluster/membership");
        let mut list_stream = self.store.list(Some(&prefix));
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let mut active_nodes = Vec::new();

        while let Some(meta) = list_stream.next().await {
            let meta = meta?;
            if let Ok(result) = self.store.get(&meta.location).await {
                let bytes = result.bytes().await?;
                if let Ok(heartbeat) = serde_json::from_slice::<NodeHeartbeat>(&bytes) {
                    if now.saturating_sub(heartbeat.last_seen_ts) < self.heartbeat_expiry.as_secs()
                    {
                        active_nodes.push(heartbeat.identity);
                    }
                }
            }
        }

        active_nodes.sort_by(|a, b| a.0.cmp(&b.0));
        active_nodes.dedup();
        Ok(active_nodes)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Debug)]
    struct MockMembership(Vec<NodeId>);

    #[async_trait::async_trait]
    impl ClusterMembership for MockMembership {
        async fn heartbeat(&self, _identity: &NodeId) -> anyhow::Result<()> {
            Ok(())
        }

        async fn nodes(&self) -> anyhow::Result<Vec<NodeId>> {
            Ok(self.0.clone())
        }
    }

    #[tokio::test]
    async fn test_quorum_calculation() {
        let cases = vec![(0, 0), (1, 1), (2, 2), (3, 2), (4, 3), (5, 3), (10, 6)];

        for (n, expected_quorum) in cases {
            let nodes = (0..n)
                .map(|i| NodeId(format!("node-{}", i)))
                .collect::<Vec<NodeId>>();
            let mock = MockMembership(nodes);
            assert_eq!(
                mock.quorum_size().await.unwrap(),
                expected_quorum,
                "Failed for n={}",
                n
            );
        }
    }

    #[tokio::test]
    async fn test_object_store_membership() {
        let store: Arc<dyn ObjectStore> = Arc::new(object_store::memory::InMemory::new());
        let expiry = Duration::from_secs(5);
        let membership = ObjectStoreMembership::new(store.clone(), expiry);

        let node1 = NodeId("node1".to_string());
        let node2 = NodeId("node2".to_string());

        // Initial state
        assert_eq!(membership.nodes().await.unwrap().len(), 0);

        // Heartbeat node1
        membership.heartbeat(&node1).await.unwrap();
        let nodes = membership.nodes().await.unwrap();
        assert_eq!(nodes.len(), 1);
        assert_eq!(nodes[0], node1);

        // Heartbeat node2
        membership.heartbeat(&node2).await.unwrap();
        let nodes = membership.nodes().await.unwrap();
        assert_eq!(nodes.len(), 2);
    }
}
