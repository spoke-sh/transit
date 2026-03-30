use serde::{Deserialize, Serialize};
use std::fmt::Debug;

/// Unique identity of a node in the cluster.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct NodeIdentity(pub String);

impl std::fmt::Display for NodeIdentity {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Trait for querying cluster membership and calculating quorum.
#[async_trait::async_trait]
pub trait ClusterMembership: Send + Sync + Debug {
    /// Returns the set of nodes currently recognized as members of the cluster.
    async fn nodes(&self) -> anyhow::Result<Vec<NodeIdentity>>;

    /// Calculates the quorum size (majority) based on the current membership.
    async fn quorum_size(&self) -> anyhow::Result<usize> {
        let n = self.nodes().await?.len();
        Ok(if n == 0 { 0 } else { (n / 2) + 1 })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Debug)]
    struct MockMembership(Vec<NodeIdentity>);

    #[async_trait::async_trait]
    impl ClusterMembership for MockMembership {
        async fn nodes(&self) -> anyhow::Result<Vec<NodeIdentity>> {
            Ok(self.0.clone())
        }
    }

    #[tokio::test]
    async fn test_quorum_calculation() {
        let cases = vec![(0, 0), (1, 1), (2, 2), (3, 2), (4, 3), (5, 3), (10, 6)];

        for (n, expected_quorum) in cases {
            let nodes = (0..n)
                .map(|i| NodeIdentity(format!("node-{}", i)))
                .collect::<Vec<NodeIdentity>>();
            let mock = MockMembership(nodes);
            assert_eq!(
                mock.quorum_size().await.unwrap(),
                expected_quorum,
                "Failed for n={}",
                n
            );
        }
    }
}
