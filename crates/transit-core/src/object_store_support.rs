use crate::config::{LoadedTransitConfig, StorageDurability, StorageProvider};
use anyhow::{Context, Result, ensure};
use object_store::local::LocalFileSystem;
use object_store::path::Path as ObjectPath;
use object_store::{ObjectStoreExt, PutPayload};
use serde::Serialize;
use std::path::{Path, PathBuf};
use tokio::fs::OpenOptions;
use tokio::io::AsyncWriteExt;

const PROBE_OBJECT_PATH: &str = "mission/bootstrap/probe.txt";
const PROBE_PAYLOAD: &[u8] = b"transit bootstrap probe";
const DIRECTORY_PROBE_PAYLOAD: &[u8] = b"transit storage directory probe";

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct StorageProbeResult {
    pub config_sources: Vec<PathBuf>,
    pub node_id: String,
    pub mode: String,
    pub provider: String,
    pub durability: String,
    pub data_dir: PathBuf,
    pub cache_dir: PathBuf,
    pub object_store_root: PathBuf,
    pub object_prefix: String,
    pub object_path: String,
    pub bytes_written: usize,
    pub data_dir_ready: bool,
    pub cache_dir_ready: bool,
    pub round_trip_ok: bool,
    pub cleanup_ok: bool,
    pub guarantee: String,
    pub non_claim: String,
}

pub async fn probe_effective_storage(loaded: &LoadedTransitConfig) -> Result<StorageProbeResult> {
    let config = loaded.config();

    ensure!(
        config.storage.provider == StorageProvider::Filesystem,
        "transit storage probe currently supports only the filesystem provider; effective config provider is '{}'",
        config.storage.provider.as_str()
    );
    ensure!(
        config.storage.durability == StorageDurability::Local,
        "transit storage probe can only verify 'local' durability today; effective config durability is '{}'",
        config.storage.durability.as_str()
    );

    let data_dir = config.node.data_dir.clone();
    probe_local_directory(&data_dir, "data").await?;

    let cache_dir = config.node.cache_dir.clone();
    probe_local_directory(&cache_dir, "cache").await?;

    let object_store_root = config
        .filesystem_object_store_root()
        .context("filesystem storage probe requires [storage].bucket to be set")?;
    let object_store_result =
        probe_local_filesystem_store(&object_store_root, &config.storage.prefix).await?;

    Ok(StorageProbeResult {
        config_sources: loaded.sources().to_vec(),
        node_id: config.effective_node_id().to_owned(),
        mode: config.node.mode.as_str().to_owned(),
        provider: config.storage.provider.as_str().to_owned(),
        durability: config.storage.durability.as_str().to_owned(),
        data_dir,
        cache_dir,
        object_store_root,
        object_prefix: config.storage.prefix.clone(),
        object_path: object_store_result.object_path,
        bytes_written: object_store_result.bytes_written,
        data_dir_ready: true,
        cache_dir_ready: true,
        round_trip_ok: object_store_result.round_trip_ok,
        cleanup_ok: object_store_result.cleanup_ok,
        guarantee: "local".to_owned(),
        non_claim: "the current runtime verifies writable local durability only; it does not claim remote-tier acknowledgement from transit.toml".to_owned(),
    })
}

async fn probe_local_directory(root: &Path, label: &str) -> Result<()> {
    tokio::fs::create_dir_all(root)
        .await
        .with_context(|| format!("create {label} directory {}", root.display()))?;

    let probe_path = root.join(format!(".transit-{label}-probe"));
    let mut file = OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .open(&probe_path)
        .await
        .with_context(|| format!("open {label} probe file {}", probe_path.display()))?;
    file.write_all(DIRECTORY_PROBE_PAYLOAD)
        .await
        .with_context(|| format!("write {label} probe file {}", probe_path.display()))?;
    file.sync_all()
        .await
        .with_context(|| format!("sync {label} probe file {}", probe_path.display()))?;
    drop(file);

    let bytes = tokio::fs::read(&probe_path)
        .await
        .with_context(|| format!("read {label} probe file {}", probe_path.display()))?;
    ensure!(
        bytes.as_slice() == DIRECTORY_PROBE_PAYLOAD,
        "{label} probe round-trip mismatch"
    );

    tokio::fs::remove_file(&probe_path)
        .await
        .with_context(|| format!("remove {label} probe file {}", probe_path.display()))?;

    Ok(())
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct ObjectStoreProbeResult {
    object_path: String,
    bytes_written: usize,
    round_trip_ok: bool,
    cleanup_ok: bool,
}

async fn probe_local_filesystem_store(
    root: impl AsRef<Path>,
    prefix: &str,
) -> Result<ObjectStoreProbeResult> {
    let root = root.as_ref().to_path_buf();
    tokio::fs::create_dir_all(&root)
        .await
        .with_context(|| format!("create probe root at {}", root.display()))?;

    let store = LocalFileSystem::new_with_prefix(&root)
        .with_context(|| format!("open local object store at {}", root.display()))?;
    let object_path = probe_object_path(prefix);
    let path = ObjectPath::from(object_path.as_str());

    store
        .put(&path, PutPayload::from_static(PROBE_PAYLOAD))
        .await
        .context("write probe payload to filesystem object store")?;

    let bytes = store
        .get(&path)
        .await
        .context("fetch probe payload from filesystem object store")?
        .bytes()
        .await
        .context("read probe payload bytes")?;

    ensure!(
        bytes.as_ref() == PROBE_PAYLOAD,
        "filesystem object store round-trip mismatch"
    );

    store
        .delete(&path)
        .await
        .context("delete probe payload from filesystem object store")?;

    Ok(ObjectStoreProbeResult {
        object_path,
        bytes_written: PROBE_PAYLOAD.len(),
        round_trip_ok: true,
        cleanup_ok: true,
    })
}

fn probe_object_path(prefix: &str) -> String {
    let prefix = prefix.trim_matches('/');
    if prefix.is_empty() {
        return PROBE_OBJECT_PATH.to_owned();
    }
    format!("{prefix}/{PROBE_OBJECT_PATH}")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::TransitConfig;
    use tempfile::tempdir;

    #[tokio::test]
    async fn storage_probe_verifies_local_filesystem_guarantee() {
        let temp_dir = tempdir().expect("temp dir");
        let mut config = TransitConfig::default();
        config.node.data_dir = temp_dir.path().join("data");
        config.node.cache_dir = temp_dir.path().join("cache");
        config.storage.bucket = temp_dir.path().join("objects").display().to_string();
        config.storage.prefix = "dev-a".to_owned();
        let loaded = LoadedTransitConfig::new(config, vec![temp_dir.path().join("transit.toml")]);

        let result = probe_effective_storage(&loaded)
            .await
            .expect("probe local filesystem storage");

        assert_eq!(result.guarantee, "local");
        assert_eq!(result.provider, "filesystem");
        assert_eq!(result.durability, "local");
        assert!(result.data_dir_ready);
        assert!(result.cache_dir_ready);
        assert!(result.round_trip_ok);
        assert!(result.cleanup_ok);
        assert_eq!(result.object_path, "dev-a/mission/bootstrap/probe.txt");
    }

    #[tokio::test]
    async fn storage_probe_rejects_non_local_durability_claims() {
        let temp_dir = tempdir().expect("temp dir");
        let mut config = TransitConfig::default();
        config.node.data_dir = temp_dir.path().join("data");
        config.node.cache_dir = temp_dir.path().join("cache");
        config.storage.bucket = temp_dir.path().join("objects").display().to_string();
        config.storage.durability = StorageDurability::Tiered;
        let loaded = LoadedTransitConfig::new(config, Vec::new());

        let error = probe_effective_storage(&loaded)
            .await
            .expect_err("tiered storage should not be accepted");

        assert!(
            error
                .to_string()
                .contains("can only verify 'local' durability")
        );
    }
}
