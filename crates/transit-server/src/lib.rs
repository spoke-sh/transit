use anyhow::{Context, Result, ensure};
use object_store::ObjectStore;
use std::net::SocketAddr;
use transit_core::engine::{
    AccessMode, LocalEngine, LocalEngineConfig, LocalPublishedReplicationFrontier,
    LocalReplicaSyncOutcome,
};
use transit_core::server::{ServerConfig, ServerHandle};

/// Hydrate a read-only server root from an authoritative published frontier and bind a server.
pub async fn bind_read_only_replica_from_frontier(
    config: LocalEngineConfig,
    listen_addr: SocketAddr,
    store: &dyn ObjectStore,
    frontier: &LocalPublishedReplicationFrontier,
) -> Result<(ServerHandle, LocalReplicaSyncOutcome)> {
    ensure!(
        config.access_mode() == AccessMode::ReadOnlyReplica,
        "read-only replica hydration requires read-only replica access mode"
    );

    let engine = LocalEngine::open(config.clone())
        .with_context(|| format!("open hydrate engine at {}", config.data_dir().display()))?;
    let sync = engine
        .sync_read_only_replica_from_frontier(store, frontier)
        .await
        .context("hydrate read-only replica from object-store frontier")?;
    drop(engine);

    let server = ServerHandle::bind(ServerConfig::new(config, listen_addr))
        .context("bind hydrated transit-server")?;

    Ok((server, sync))
}

#[cfg(test)]
mod tests {
    use super::*;
    use object_store::local::LocalFileSystem;
    use std::fs;
    use tempfile::tempdir;
    use transit_core::engine::LocalEngine;
    use transit_core::kernel::{LineageMetadata, StreamDescriptor, StreamId};
    use transit_core::membership::NodeId;
    use transit_core::server::RemoteClient;

    async fn publish_authoritative_history() -> (
        tempfile::TempDir,
        tempfile::TempDir,
        LocalFileSystem,
        StreamId,
        LocalPublishedReplicationFrontier,
    ) {
        let primary_root = tempdir().expect("primary root");
        let remote_root = tempdir().expect("remote root");
        let primary = LocalEngine::open(
            LocalEngineConfig::new(primary_root.path(), NodeId::new("primary-node"))
                .with_segment_max_records(2)
                .expect("config"),
        )
        .expect("primary");
        let store = LocalFileSystem::new_with_prefix(remote_root.path()).expect("object store");
        let stream_id = StreamId::new("server.hydrate.root").expect("stream id");

        primary
            .create_stream(StreamDescriptor::root(
                stream_id.clone(),
                LineageMetadata::new(
                    Some("test".into()),
                    Some("hydrate-from-object-store".into()),
                ),
            ))
            .expect("create stream");
        for payload in ["first", "second", "third", "fourth"] {
            primary
                .append(&stream_id, payload.as_bytes())
                .expect("append");
        }
        primary
            .publish_rolled_segments(&stream_id, &store, "tiered")
            .await
            .expect("publish rolled segments");
        let frontier = primary
            .published_replication_frontier(&stream_id)
            .expect("frontier lookup")
            .expect("published frontier");

        (primary_root, remote_root, store, stream_id, frontier)
    }

    #[tokio::test]
    async fn hydrate_from_object_store_bootstraps_server_when_warm_cache_is_missing() {
        let (_primary_root, _remote_root, store, stream_id, frontier) =
            publish_authoritative_history().await;
        let replica_root = tempdir().expect("replica root");
        let replica_path = replica_root.path().join("server-replica");
        let config = LocalEngineConfig::new(&replica_path, NodeId::new("server-replica"))
            .as_read_only_replica();

        let (server, sync) = bind_read_only_replica_from_frontier(
            config,
            "127.0.0.1:0".parse().expect("listen addr"),
            &store,
            &frontier,
        )
        .await
        .expect("hydrate and bind server");
        let client = RemoteClient::new(server.local_addr());
        let replay = client.read(&stream_id).expect("remote replay");

        assert!(sync.bootstrapped());
        assert_eq!(sync.restored_segment_ids().len(), 2);
        assert_eq!(replay.body().records().len(), 4);
        assert_eq!(replay.body().records()[0].payload(), b"first");
        assert_eq!(replay.body().records()[3].payload(), b"fourth");

        server.shutdown().expect("shutdown server");
    }

    #[tokio::test]
    async fn hydrate_from_object_store_preserves_acknowledged_tiered_history_after_cache_loss() {
        let (_primary_root, _remote_root, store, stream_id, frontier) =
            publish_authoritative_history().await;
        let replica_root = tempdir().expect("replica root");
        let replica_path = replica_root.path().join("server-replica");
        let config = LocalEngineConfig::new(&replica_path, NodeId::new("server-replica"))
            .as_read_only_replica();

        let (server, first_sync) = bind_read_only_replica_from_frontier(
            config.clone(),
            "127.0.0.1:0".parse().expect("listen addr"),
            &store,
            &frontier,
        )
        .await
        .expect("hydrate initial replica");
        assert!(first_sync.bootstrapped());
        server.shutdown().expect("shutdown initial server");

        fs::remove_dir_all(&replica_path).expect("remove replica warm cache");

        let (rehydrated_server, second_sync) = bind_read_only_replica_from_frontier(
            config,
            "127.0.0.1:0".parse().expect("listen addr"),
            &store,
            &frontier,
        )
        .await
        .expect("rehydrate replica after cache loss");
        let client = RemoteClient::new(rehydrated_server.local_addr());
        let replay = client
            .read(&stream_id)
            .expect("remote replay after cache loss");

        assert!(second_sync.bootstrapped());
        assert_eq!(second_sync.restored_segment_ids().len(), 2);
        assert_eq!(replay.body().records().len(), 4);
        assert_eq!(replay.body().records()[1].payload(), b"second");
        assert_eq!(replay.body().records()[3].payload(), b"fourth");

        rehydrated_server
            .shutdown()
            .expect("shutdown rehydrated server");
    }
}
