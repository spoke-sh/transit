use anyhow::{Context, Result, ensure};
use object_store::local::LocalFileSystem;
use object_store::path::Path as ObjectPath;
use object_store::{ObjectStoreExt, PutPayload};
use serde::Serialize;
use std::path::{Path, PathBuf};

const PROBE_OBJECT_PATH: &str = "mission/bootstrap/probe.txt";
const PROBE_PAYLOAD: &[u8] = b"transit bootstrap probe";

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct ObjectStoreProbeResult {
    pub backend: &'static str,
    pub root: PathBuf,
    pub object_path: String,
    pub bytes_written: usize,
    pub round_trip_ok: bool,
    pub cleanup_ok: bool,
}

pub async fn probe_local_filesystem_store(
    root: impl AsRef<Path>,
) -> Result<ObjectStoreProbeResult> {
    let root = root.as_ref().to_path_buf();
    tokio::fs::create_dir_all(&root)
        .await
        .with_context(|| format!("create probe root at {}", root.display()))?;

    let store = LocalFileSystem::new_with_prefix(&root)
        .with_context(|| format!("open local object store at {}", root.display()))?;
    let object_path = ObjectPath::from(PROBE_OBJECT_PATH);

    store
        .put(&object_path, PutPayload::from_static(PROBE_PAYLOAD))
        .await
        .context("write probe payload to filesystem object store")?;

    let bytes = store
        .get(&object_path)
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
        .delete(&object_path)
        .await
        .context("delete probe payload from filesystem object store")?;

    Ok(ObjectStoreProbeResult {
        backend: "filesystem",
        root,
        object_path: PROBE_OBJECT_PATH.to_owned(),
        bytes_written: PROBE_PAYLOAD.len(),
        round_trip_ok: true,
        cleanup_ok: true,
    })
}

#[cfg(test)]
mod tests {
    use super::probe_local_filesystem_store;
    use tempfile::tempdir;

    #[tokio::test]
    async fn probe_round_trips_through_local_filesystem_store() {
        let root = tempdir().expect("probe root");
        let result = probe_local_filesystem_store(root.path())
            .await
            .expect("successful filesystem probe");

        assert_eq!(result.backend, "filesystem");
        assert!(result.round_trip_ok);
        assert!(result.cleanup_ok);
        assert_eq!(result.bytes_written, b"transit bootstrap probe".len());
    }
}
