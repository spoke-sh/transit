use crate::config::{LoadedTransitConfig, StorageDurability, StorageProvider, TransitConfig};
use anyhow::{Context, Result, anyhow, bail, ensure};
use object_store::ClientOptions;
use object_store::ObjectStore;
use object_store::aws::AmazonS3Builder;
use object_store::azure::MicrosoftAzureBuilder;
use object_store::gcp::GoogleCloudStorageBuilder;
use object_store::local::LocalFileSystem;
use object_store::path::Path as ObjectPath;
use object_store::prefix::PrefixStore;
use object_store::{ObjectStoreExt, PutPayload};
use serde::Serialize;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::fs::OpenOptions;
use tokio::io::AsyncWriteExt;

const PROBE_OBJECT_PATH: &str = "mission/bootstrap/probe.txt";
const PROBE_PAYLOAD: &[u8] = b"transit bootstrap probe";
const DIRECTORY_PROBE_PAYLOAD: &[u8] = b"transit storage directory probe";

pub fn build_runtime_object_store(config: &TransitConfig) -> Result<Arc<dyn ObjectStore>> {
    let prefix = normalized_prefix(&config.storage.prefix);

    match config.storage.provider {
        StorageProvider::Filesystem => {
            let root = required_filesystem_root(config)?;
            std::fs::create_dir_all(&root).with_context(|| {
                format!("create filesystem object store root {}", root.display())
            })?;
            let store = LocalFileSystem::new_with_prefix(&root)
                .with_context(|| format!("open filesystem object store at {}", root.display()))?;
            Ok(wrap_store_prefix(store, prefix.as_deref()))
        }
        StorageProvider::S3 => {
            let bucket = required_storage_value(
                &config.storage.bucket,
                "s3",
                "[storage].bucket",
                "name the backing bucket",
            )?;
            let endpoint = optional_storage_value(config.storage.endpoint.as_deref());
            let region = optional_storage_value(config.storage.region.as_deref());
            if region.is_none() && endpoint.is_none() {
                bail!("s3 object-store provider requires [storage].region or [storage].endpoint");
            }

            let mut builder = AmazonS3Builder::from_env().with_bucket_name(bucket);
            if let Some(region) = region {
                builder = builder.with_region(region);
            }
            if let Some(endpoint) = endpoint {
                let allow_http = endpoint.starts_with("http://");
                builder = builder.with_endpoint(endpoint).with_allow_http(allow_http);
            }

            let store = builder
                .build()
                .context("build s3 object-store client from [storage] config")?;
            Ok(wrap_store_prefix(store, prefix.as_deref()))
        }
        StorageProvider::Gcs => {
            let bucket = required_storage_value(
                &config.storage.bucket,
                "gcs",
                "[storage].bucket",
                "name the backing bucket",
            )?;
            let endpoint = optional_storage_value(config.storage.endpoint.as_deref());

            let mut builder = GoogleCloudStorageBuilder::from_env().with_bucket_name(bucket);
            if let Some(endpoint) = endpoint {
                let mut options = ClientOptions::new();
                if endpoint.starts_with("http://") {
                    options = options.with_allow_http(true);
                }
                builder = builder.with_base_url(endpoint).with_client_options(options);
            }

            let store = builder
                .build()
                .context("build gcs object-store client from [storage] config")?;
            Ok(wrap_store_prefix(store, prefix.as_deref()))
        }
        StorageProvider::Azure => {
            let container = required_storage_value(
                &config.storage.bucket,
                "azure",
                "[storage].bucket",
                "name the backing container",
            )?;
            let endpoint = required_storage_value(
                config.storage.endpoint.as_deref().unwrap_or_default(),
                "azure",
                "[storage].endpoint",
                "name the account endpoint so Transit can derive the storage account",
            )?;

            let builder = MicrosoftAzureBuilder::from_env()
                .with_url(endpoint)
                .with_container_name(container)
                .with_allow_http(endpoint.starts_with("http://"));

            let store = builder
                .build()
                .context("build azure object-store client from [storage] config")?;
            Ok(wrap_store_prefix(store, prefix.as_deref()))
        }
    }
}

pub fn build_loaded_runtime_object_store(
    loaded: &LoadedTransitConfig,
) -> Result<Arc<dyn ObjectStore>> {
    build_runtime_object_store(loaded.config())
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct StorageProbeResult {
    pub config_sources: Vec<PathBuf>,
    pub node_id: String,
    pub mode: String,
    pub provider: String,
    pub durability: String,
    pub data_dir: PathBuf,
    pub cache_dir: PathBuf,
    pub authority: String,
    pub object_prefix: String,
    pub authority_check: String,
    pub authority_ready: bool,
    pub object_path: Option<String>,
    pub bytes_written: Option<usize>,
    pub data_dir_ready: bool,
    pub cache_dir_ready: bool,
    pub round_trip_ok: Option<bool>,
    pub cleanup_ok: Option<bool>,
    pub guarantee: String,
    pub non_claim: String,
}

pub async fn probe_effective_storage(loaded: &LoadedTransitConfig) -> Result<StorageProbeResult> {
    let config = loaded.config();
    let data_dir = config.node.data_dir.clone();
    probe_local_directory(&data_dir, "data").await?;

    let cache_dir = config.node.cache_dir.clone();
    probe_local_directory(&cache_dir, "cache").await?;

    let authority = authority_description(config)?;
    let (authority_check, object_path, bytes_written, round_trip_ok, cleanup_ok) =
        match config.storage.provider {
            StorageProvider::Filesystem => {
                let object_store_root = config
                    .filesystem_object_store_root()
                    .context("filesystem storage probe requires [storage].bucket to be set")?;
                let object_store_result =
                    probe_local_filesystem_store(&object_store_root, &config.storage.prefix)
                        .await?;
                (
                    "filesystem_round_trip".to_owned(),
                    Some(object_store_result.object_path),
                    Some(object_store_result.bytes_written),
                    Some(object_store_result.round_trip_ok),
                    Some(object_store_result.cleanup_ok),
                )
            }
            _ => {
                let _authority_store =
                    build_loaded_runtime_object_store(loaded).with_context(|| {
                        format!(
                            "resolve {} object-store authority for transit storage probe",
                            config.storage.provider.as_str()
                        )
                    })?;
                ("provider_bootstrap".to_owned(), None, None, None, None)
            }
        };

    Ok(StorageProbeResult {
        config_sources: loaded.sources().to_vec(),
        node_id: config.effective_node_id().to_owned(),
        mode: config.node.mode.as_str().to_owned(),
        provider: config.storage.provider.as_str().to_owned(),
        durability: config.storage.durability.as_str().to_owned(),
        data_dir,
        cache_dir,
        authority,
        object_prefix: config.storage.prefix.clone(),
        authority_check,
        authority_ready: true,
        object_path,
        bytes_written,
        data_dir_ready: true,
        cache_dir_ready: true,
        round_trip_ok,
        cleanup_ok,
        guarantee: truthful_probe_guarantee(config).to_owned(),
        non_claim: truthful_probe_non_claim(config),
    })
}

fn authority_description(config: &TransitConfig) -> Result<String> {
    let prefix = normalized_prefix(&config.storage.prefix);

    match config.storage.provider {
        StorageProvider::Filesystem => Ok(required_filesystem_root(config)?.display().to_string()),
        StorageProvider::S3 => {
            let bucket = required_storage_value(
                &config.storage.bucket,
                "s3",
                "[storage].bucket",
                "name the backing bucket",
            )?;
            Ok(match prefix.as_deref() {
                Some(prefix) => format!("s3://{bucket}/{prefix}"),
                None => format!("s3://{bucket}"),
            })
        }
        StorageProvider::Gcs => {
            let bucket = required_storage_value(
                &config.storage.bucket,
                "gcs",
                "[storage].bucket",
                "name the backing bucket",
            )?;
            Ok(match prefix.as_deref() {
                Some(prefix) => format!("gs://{bucket}/{prefix}"),
                None => format!("gs://{bucket}"),
            })
        }
        StorageProvider::Azure => {
            let container = required_storage_value(
                &config.storage.bucket,
                "azure",
                "[storage].bucket",
                "name the backing container",
            )?;
            Ok(match prefix.as_deref() {
                Some(prefix) => format!("azure://{container}/{prefix}"),
                None => format!("azure://{container}"),
            })
        }
    }
}

fn truthful_probe_guarantee(config: &TransitConfig) -> &'static str {
    match config.storage.durability {
        StorageDurability::Local => "local",
        StorageDurability::Replicated | StorageDurability::Tiered | StorageDurability::Quorum => {
            "local"
        }
        StorageDurability::Memory => "memory",
    }
}

fn truthful_probe_non_claim(config: &TransitConfig) -> String {
    match (config.storage.provider, config.storage.durability) {
        (StorageProvider::Filesystem, StorageDurability::Local) => {
            "the current runtime verifies writable local durability only; it does not claim remote-tier acknowledgement from transit.toml".to_owned()
        }
        (_, StorageDurability::Tiered) => {
            "the current probe validates local working directories and hosted object-store bootstrap only; it does not claim remote-tier acknowledgement until append or recovery paths actually reach the authoritative object-store boundary".to_owned()
        }
        (_, StorageDurability::Replicated) => {
            "the current probe validates local working directories and authored provider bootstrap only; it does not claim replicated acknowledgement until the shared publication path is part of the response contract".to_owned()
        }
        (_, StorageDurability::Quorum) => {
            "the current probe validates local working directories and authored provider bootstrap only; it does not claim quorum acknowledgement until peer majority participation is part of the response contract".to_owned()
        }
        (_, StorageDurability::Memory) => {
            "the current probe validates bootstrap posture only; it does not claim durable acknowledgement beyond the configured in-memory test mode".to_owned()
        }
        (_, StorageDurability::Local) => {
            "the current probe validates local working directories and authored provider bootstrap; it does not claim any stronger hosted acknowledgement than local durability".to_owned()
        }
    }
}

fn required_filesystem_root(config: &TransitConfig) -> Result<PathBuf> {
    config.filesystem_object_store_root().ok_or_else(|| {
        anyhow!("filesystem object-store provider requires [storage].bucket to be set")
    })
}

fn required_storage_value<'a>(
    value: &'a str,
    provider: &str,
    field: &str,
    expectation: &str,
) -> Result<&'a str> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        bail!("{provider} object-store provider requires {field} to {expectation}");
    }
    Ok(trimmed)
}

fn optional_storage_value(value: Option<&str>) -> Option<&str> {
    value.map(str::trim).filter(|value| !value.is_empty())
}

fn normalized_prefix(prefix: &str) -> Option<String> {
    let prefix = prefix.trim_matches('/');
    if prefix.is_empty() {
        None
    } else {
        Some(prefix.to_owned())
    }
}

fn wrap_store_prefix<T>(store: T, prefix: Option<&str>) -> Arc<dyn ObjectStore>
where
    T: ObjectStore + 'static,
{
    match prefix {
        Some(prefix) => Arc::new(PrefixStore::new(store, prefix)),
        None => Arc::new(store),
    }
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
    async fn runtime_object_store_factory_scopes_filesystem_provider_with_prefix() {
        let temp_dir = tempdir().expect("temp dir");
        let mut config = TransitConfig::default();
        config.storage.bucket = temp_dir.path().join("objects").display().to_string();
        config.storage.prefix = "env-a".to_owned();

        let store = build_runtime_object_store(&config).expect("build runtime object store");
        let path = ObjectPath::from("nested/probe.txt");
        store
            .put(&path, PutPayload::from_static(b"prefix-check"))
            .await
            .expect("write prefixed object");

        let bytes = store
            .get(&path)
            .await
            .expect("fetch prefixed object")
            .bytes()
            .await
            .expect("read prefixed object bytes");
        assert_eq!(bytes.as_ref(), b"prefix-check");

        let disk_path = temp_dir.path().join("objects/env-a/nested/probe.txt");
        assert!(
            disk_path.exists(),
            "prefixed filesystem object should exist on disk"
        );
    }

    #[test]
    fn runtime_object_store_factory_rejects_s3_without_region_or_endpoint() {
        let mut config = TransitConfig::default();
        config.storage.provider = StorageProvider::S3;
        config.storage.bucket = "transit-prod".to_owned();
        config.storage.region = None;
        config.storage.endpoint = None;

        let error = build_runtime_object_store(&config).expect_err("missing s3 region or endpoint");
        assert!(
            error
                .to_string()
                .contains("requires [storage].region or [storage].endpoint")
        );
    }

    #[test]
    fn runtime_object_store_factory_rejects_azure_without_endpoint() {
        let mut config = TransitConfig::default();
        config.storage.provider = StorageProvider::Azure;
        config.storage.bucket = "transit-container".to_owned();
        config.storage.endpoint = None;

        let error = build_runtime_object_store(&config).expect_err("missing azure endpoint");
        assert!(
            error
                .to_string()
                .contains("azure object-store provider requires [storage].endpoint")
        );
    }

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
        assert_eq!(
            result.authority,
            temp_dir.path().join("objects").display().to_string()
        );
        assert_eq!(result.authority_check, "filesystem_round_trip");
        assert!(result.authority_ready);
        assert_eq!(result.round_trip_ok, Some(true));
        assert_eq!(result.cleanup_ok, Some(true));
        assert_eq!(
            result.object_path.as_deref(),
            Some("dev-a/mission/bootstrap/probe.txt")
        );
    }

    #[tokio::test]
    async fn storage_probe_reports_tiered_filesystem_posture_without_claiming_remote_ack() {
        let temp_dir = tempdir().expect("temp dir");
        let mut config = TransitConfig::default();
        config.node.data_dir = temp_dir.path().join("data");
        config.node.cache_dir = temp_dir.path().join("cache");
        config.storage.bucket = temp_dir.path().join("objects").display().to_string();
        config.storage.prefix = "hosted/runtime".to_owned();
        config.storage.durability = StorageDurability::Tiered;
        let loaded = LoadedTransitConfig::new(config, Vec::new());

        let result = probe_effective_storage(&loaded)
            .await
            .expect("probe hosted tiered filesystem posture");

        assert_eq!(result.provider, "filesystem");
        assert_eq!(result.durability, "tiered");
        assert_eq!(result.guarantee, "local");
        assert_eq!(result.authority_check, "filesystem_round_trip");
        assert!(result.authority_ready);
        assert_eq!(
            result.object_path.as_deref(),
            Some("hosted/runtime/mission/bootstrap/probe.txt")
        );
        assert!(
            result
                .non_claim
                .contains("does not claim remote-tier acknowledgement")
        );
    }
}
