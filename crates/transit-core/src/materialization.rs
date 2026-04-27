use crate::engine::{read_json, write_json_durable};
use crate::kernel::{Offset, StreamId};
use crate::storage::{ContentDigest, LineageCheckpoint};
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

pub(crate) const MATERIALIZATION_CHECKPOINTS_DIR: &str = "materializations";
pub const DEFAULT_MATERIALIZATION_VIEW_KIND: &str = "materialization";
pub const DEFAULT_MATERIALIZER_VERSION: &str = "unspecified";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostedMaterializationCheckpoint {
    materialization_id: String,
    view_kind: String,
    source_stream_id: StreamId,
    source_offset: Offset,
    source_manifest_generation: u64,
    source_manifest_root: ContentDigest,
    source_durability: String,
    lineage_ref: String,
    lineage_anchor: LineageCheckpoint,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    lineage_checkpoint_ref: Option<String>,
    opaque_state: Vec<u8>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    opaque_state_ref: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    snapshot_ref: Option<String>,
    produced_at: i64,
    materializer_version: String,
}

impl HostedMaterializationCheckpoint {
    pub fn new(
        materialization_id: impl Into<String>,
        lineage_anchor: LineageCheckpoint,
        opaque_state: Vec<u8>,
        produced_at: i64,
    ) -> Result<Self> {
        Self::from_contract(
            materialization_id,
            DEFAULT_MATERIALIZATION_VIEW_KIND,
            lineage_anchor,
            0,
            "local",
            opaque_state,
            None,
            None,
            produced_at,
            DEFAULT_MATERIALIZER_VERSION,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn from_contract(
        materialization_id: impl Into<String>,
        view_kind: impl Into<String>,
        lineage_anchor: LineageCheckpoint,
        source_manifest_generation: u64,
        source_durability: impl Into<String>,
        opaque_state: Vec<u8>,
        opaque_state_ref: Option<String>,
        snapshot_ref: Option<String>,
        produced_at: i64,
        materializer_version: impl Into<String>,
    ) -> Result<Self> {
        let materialization_id = materialization_id.into();
        validate_materialization_id(&materialization_id)?;
        let view_kind = require_non_empty("view kind", view_kind.into())?;
        let source_durability = require_non_empty("source durability", source_durability.into())?;
        let materializer_version =
            require_non_empty("materializer version", materializer_version.into())?;
        validate_optional_ref("opaque state ref", opaque_state_ref.as_deref())?;
        validate_optional_ref("snapshot ref", snapshot_ref.as_deref())?;

        let source_stream_id = lineage_anchor.stream_id.clone();
        let source_offset = lineage_anchor.head_offset;
        let source_manifest_root = lineage_anchor.manifest_root.clone();
        let lineage_ref = lineage_ref_for(&source_stream_id, source_offset);
        let lineage_checkpoint_ref = Some(format!(
            "{}:{}",
            lineage_anchor.kind,
            lineage_ref_for(&source_stream_id, source_offset)
        ));
        let checkpoint = Self {
            materialization_id,
            view_kind,
            source_stream_id,
            source_offset,
            source_manifest_generation,
            source_manifest_root,
            source_durability,
            lineage_ref,
            lineage_anchor,
            lineage_checkpoint_ref,
            opaque_state,
            opaque_state_ref,
            snapshot_ref,
            produced_at,
            materializer_version,
        };
        checkpoint.validate_contract()?;
        Ok(checkpoint)
    }

    pub fn materialization_id(&self) -> &str {
        &self.materialization_id
    }

    pub fn view_kind(&self) -> &str {
        &self.view_kind
    }

    pub fn source_stream_id(&self) -> &StreamId {
        &self.source_stream_id
    }

    pub fn source_offset(&self) -> Offset {
        self.source_offset
    }

    pub fn source_manifest_generation(&self) -> u64 {
        self.source_manifest_generation
    }

    pub fn source_manifest_root(&self) -> &ContentDigest {
        &self.source_manifest_root
    }

    pub fn source_durability(&self) -> &str {
        &self.source_durability
    }

    pub fn lineage_ref(&self) -> &str {
        &self.lineage_ref
    }

    pub fn lineage_anchor(&self) -> &LineageCheckpoint {
        &self.lineage_anchor
    }

    pub fn lineage_checkpoint_ref(&self) -> Option<&str> {
        self.lineage_checkpoint_ref.as_deref()
    }

    pub fn opaque_state(&self) -> &[u8] {
        &self.opaque_state
    }

    pub fn opaque_state_ref(&self) -> Option<&str> {
        self.opaque_state_ref.as_deref()
    }

    pub fn snapshot_ref(&self) -> Option<&str> {
        self.snapshot_ref.as_deref()
    }

    pub fn produced_at(&self) -> i64 {
        self.produced_at
    }

    pub fn materializer_version(&self) -> &str {
        &self.materializer_version
    }

    pub fn validate_contract(&self) -> Result<()> {
        validate_materialization_id(&self.materialization_id)?;
        require_non_empty("view kind", self.view_kind.clone())?;
        require_non_empty("source durability", self.source_durability.clone())?;
        require_non_empty("materializer version", self.materializer_version.clone())?;
        validate_optional_ref(
            "lineage checkpoint ref",
            self.lineage_checkpoint_ref.as_deref(),
        )?;
        validate_optional_ref("opaque state ref", self.opaque_state_ref.as_deref())?;
        validate_optional_ref("snapshot ref", self.snapshot_ref.as_deref())?;
        ensure!(
            self.source_stream_id == self.lineage_anchor.stream_id,
            "checkpoint source stream '{}' does not match lineage anchor '{}'",
            self.source_stream_id.as_str(),
            self.lineage_anchor.stream_id.as_str()
        );
        ensure!(
            self.source_offset == self.lineage_anchor.head_offset,
            "checkpoint source offset {} does not match lineage anchor {}",
            self.source_offset.value(),
            self.lineage_anchor.head_offset.value()
        );
        ensure!(
            self.source_manifest_root == self.lineage_anchor.manifest_root,
            "checkpoint source manifest root does not match lineage anchor"
        );
        let expected_lineage_ref = lineage_ref_for(&self.source_stream_id, self.source_offset);
        ensure!(
            self.lineage_ref == expected_lineage_ref,
            "checkpoint lineage ref '{}' does not match expected '{}'",
            self.lineage_ref,
            expected_lineage_ref
        );
        Ok(())
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

fn require_non_empty(field: &str, value: String) -> Result<String> {
    ensure!(!value.trim().is_empty(), "{field} must not be empty");
    Ok(value)
}

fn validate_optional_ref(field: &str, value: Option<&str>) -> Result<()> {
    if let Some(value) = value {
        ensure!(!value.trim().is_empty(), "{field} must not be empty");
    }
    Ok(())
}

fn lineage_ref_for(stream_id: &StreamId, offset: Offset) -> String {
    format!("{}@{}", stream_id.as_str(), offset.value())
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
        HostedMaterializationCheckpoint::from_contract(
            materialization_id,
            "reference_projection",
            LineageCheckpoint::new(
                StreamId::new("task.root").expect("stream id"),
                Offset::new(7),
                ContentDigest::new("sha256", "manifest-root").expect("digest"),
                "materialize",
            ),
            3,
            "local",
            vec![1, 2, 3],
            Some("state://consumer.analytics/7".into()),
            Some("snapshot://consumer.analytics/7".into()),
            1_700_000_000,
            "analytics.v1",
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
        assert_eq!(reloaded.view_kind(), "reference_projection");
        assert_eq!(reloaded.source_offset().value(), 7);
        assert_eq!(reloaded.source_manifest_generation(), 3);
        assert_eq!(reloaded.source_manifest_root().digest(), "manifest-root");
        assert_eq!(reloaded.source_durability(), "local");
        assert_eq!(reloaded.lineage_ref(), "task.root@7");
        assert_eq!(
            reloaded.lineage_checkpoint_ref(),
            Some("materialize:task.root@7")
        );
        assert_eq!(
            reloaded.opaque_state_ref(),
            Some("state://consumer.analytics/7")
        );
        assert_eq!(
            reloaded.snapshot_ref(),
            Some("snapshot://consumer.analytics/7")
        );
        assert_eq!(reloaded.materializer_version(), "analytics.v1");
    }

    #[test]
    fn materialization_checkpoint_contract_rejects_mismatched_source_fields() {
        let checkpoint = checkpoint("consumer.analytics");
        let mut encoded = serde_json::to_value(&checkpoint).expect("encode checkpoint");
        encoded["source_offset"] = serde_json::json!(8);

        let decoded: HostedMaterializationCheckpoint =
            serde_json::from_value(encoded).expect("decode checkpoint");
        let error = decoded
            .validate_contract()
            .expect_err("source offset mismatch should fail");

        assert!(error.to_string().contains("source offset 8"));
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
