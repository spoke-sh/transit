use crate::engine::{read_json, write_json_durable};
use crate::kernel::{Offset, StreamId};
use crate::storage::LineageCheckpoint;
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

pub(crate) const MATERIALIZATION_CHECKPOINTS_DIR: &str = "materializations";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostedMaterializationCheckpoint {
    materialization_id: String,
    lineage_anchor: LineageCheckpoint,
    opaque_state: Vec<u8>,
    produced_at: i64,
}

impl HostedMaterializationCheckpoint {
    pub fn new(
        materialization_id: impl Into<String>,
        lineage_anchor: LineageCheckpoint,
        opaque_state: Vec<u8>,
        produced_at: i64,
    ) -> Result<Self> {
        let materialization_id = materialization_id.into();
        validate_materialization_id(&materialization_id)?;
        Ok(Self {
            materialization_id,
            lineage_anchor,
            opaque_state,
            produced_at,
        })
    }

    pub fn materialization_id(&self) -> &str {
        &self.materialization_id
    }

    pub fn source_stream_id(&self) -> &StreamId {
        &self.lineage_anchor.stream_id
    }

    pub fn lineage_anchor(&self) -> &LineageCheckpoint {
        &self.lineage_anchor
    }

    pub fn opaque_state(&self) -> &[u8] {
        &self.opaque_state
    }

    pub fn produced_at(&self) -> i64 {
        self.produced_at
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostedMaterializationResumeCursor {
    checkpoint: HostedMaterializationCheckpoint,
    replay_from: Offset,
    source_next_offset: Offset,
}

impl HostedMaterializationResumeCursor {
    pub fn new(
        checkpoint: HostedMaterializationCheckpoint,
        replay_from: Offset,
        source_next_offset: Offset,
    ) -> Self {
        Self {
            checkpoint,
            replay_from,
            source_next_offset,
        }
    }

    pub fn checkpoint(&self) -> &HostedMaterializationCheckpoint {
        &self.checkpoint
    }

    pub fn source_stream_id(&self) -> &StreamId {
        self.checkpoint.source_stream_id()
    }

    pub fn replay_from(&self) -> Offset {
        self.replay_from
    }

    pub fn source_next_offset(&self) -> Offset {
        self.source_next_offset
    }

    pub fn pending_record_count(&self) -> u64 {
        self.source_next_offset
            .value()
            .saturating_sub(self.replay_from.value())
    }

    pub fn is_caught_up(&self) -> bool {
        self.pending_record_count() == 0
    }
}

#[derive(Debug)]
pub(crate) struct MaterializationCheckpointStore {
    dir: PathBuf,
}

impl MaterializationCheckpointStore {
    pub(crate) fn open(data_dir: &Path) -> Result<Self> {
        let dir = data_dir.join(MATERIALIZATION_CHECKPOINTS_DIR);
        fs::create_dir_all(&dir).with_context(|| {
            format!(
                "create materialization checkpoints directory at {}",
                dir.display()
            )
        })?;
        Ok(Self { dir })
    }

    fn path_for(&self, materialization_id: &str, stream_id: &StreamId) -> PathBuf {
        self.dir.join(format!(
            "{}__{}.json",
            file_key(stream_id.as_str()),
            file_key(materialization_id)
        ))
    }

    pub(crate) fn get(
        &self,
        materialization_id: &str,
        stream_id: &StreamId,
    ) -> Result<Option<HostedMaterializationCheckpoint>> {
        let path = self.path_for(materialization_id, stream_id);
        if !path.exists() {
            return Ok(None);
        }
        let checkpoint: HostedMaterializationCheckpoint = read_json(&path)?;
        Ok(Some(checkpoint))
    }

    pub(crate) fn put(&self, checkpoint: &HostedMaterializationCheckpoint) -> Result<()> {
        let path = self.path_for(
            checkpoint.materialization_id(),
            checkpoint.source_stream_id(),
        );
        write_json_durable(&path, checkpoint)
    }

    pub(crate) fn delete(&self, materialization_id: &str, stream_id: &StreamId) -> Result<()> {
        let path = self.path_for(materialization_id, stream_id);
        if path.exists() {
            fs::remove_file(&path)
                .with_context(|| format!("remove materialization checkpoint {}", path.display()))?;
        }
        Ok(())
    }
}

fn validate_materialization_id(materialization_id: &str) -> Result<()> {
    ensure!(
        !materialization_id.trim().is_empty(),
        "materialization ids must not be empty"
    );
    ensure!(
        materialization_id.chars().all(|character| {
            character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.' | '/' | ':')
        }),
        "materialization ids accept only ascii alphanumerics and '-', '_', '.', '/', ':'"
    );
    Ok(())
}

fn file_key(value: &str) -> String {
    value
        .as_bytes()
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::ContentDigest;
    use tempfile::tempdir;

    fn checkpoint(materialization_id: &str) -> HostedMaterializationCheckpoint {
        HostedMaterializationCheckpoint::new(
            materialization_id,
            LineageCheckpoint::new(
                StreamId::new("task.root").expect("stream id"),
                Offset::new(7),
                ContentDigest::new("sha256", "manifest-root").expect("digest"),
                "materialize",
            ),
            vec![1, 2, 3],
            1_700_000_000,
        )
        .expect("checkpoint")
    }

    #[test]
    fn materialization_checkpoint_store_persists_and_reloads_records() {
        let dir = tempdir().expect("temp dir");
        let store = MaterializationCheckpointStore::open(dir.path()).expect("open store");
        let checkpoint = checkpoint("consumer.analytics");

        store.put(&checkpoint).expect("put checkpoint");

        let reloaded = store
            .get(
                checkpoint.materialization_id(),
                checkpoint.source_stream_id(),
            )
            .expect("get checkpoint")
            .expect("checkpoint present");
        assert_eq!(reloaded, checkpoint);
    }

    #[test]
    fn materialization_checkpoint_store_delete_removes_file() {
        let dir = tempdir().expect("temp dir");
        let store = MaterializationCheckpointStore::open(dir.path()).expect("open store");
        let checkpoint = checkpoint("consumer.analytics");

        store.put(&checkpoint).expect("put checkpoint");
        store
            .delete(
                checkpoint.materialization_id(),
                checkpoint.source_stream_id(),
            )
            .expect("delete checkpoint");

        assert!(
            store
                .get(
                    checkpoint.materialization_id(),
                    checkpoint.source_stream_id()
                )
                .expect("get checkpoint")
                .is_none()
        );
    }

    #[test]
    fn materialization_checkpoint_rejects_blank_or_invalid_ids() {
        let blank = HostedMaterializationCheckpoint::new(
            "   ",
            LineageCheckpoint::new(
                StreamId::new("task.root").expect("stream id"),
                Offset::new(0),
                ContentDigest::new("sha256", "manifest-root").expect("digest"),
                "materialize",
            ),
            Vec::new(),
            1_700_000_000,
        )
        .expect_err("blank materialization id should reject");
        assert!(blank.to_string().contains("must not be empty"));

        let invalid = HostedMaterializationCheckpoint::new(
            "bad id!",
            LineageCheckpoint::new(
                StreamId::new("task.root").expect("stream id"),
                Offset::new(0),
                ContentDigest::new("sha256", "manifest-root").expect("digest"),
                "materialize",
            ),
            Vec::new(),
            1_700_000_000,
        )
        .expect_err("invalid materialization id should reject");
        assert!(invalid.to_string().contains("ascii alphanumerics"));
    }

    #[test]
    fn hosted_materialization_resume_cursor_reports_pending_window() {
        let checkpoint = checkpoint("consumer.analytics");
        let resume = HostedMaterializationResumeCursor::new(
            checkpoint.clone(),
            Offset::new(8),
            Offset::new(11),
        );

        assert_eq!(resume.checkpoint(), &checkpoint);
        assert_eq!(resume.source_stream_id().as_str(), "task.root");
        assert_eq!(resume.replay_from().value(), 8);
        assert_eq!(resume.source_next_offset().value(), 11);
        assert_eq!(resume.pending_record_count(), 3);
        assert!(!resume.is_caught_up());
    }
}
