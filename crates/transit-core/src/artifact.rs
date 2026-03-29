use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub const ARTIFACT_ROLE_LABEL: &str = "artifact_role";
pub const SUMMARY_KIND_LABEL: &str = "summary_kind";
pub const BACKLINK_KIND_LABEL: &str = "backlink_kind";
pub const MERGE_OUTCOME_KIND_LABEL: &str = "merge_outcome_kind";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ArtifactEnvelope {
    pub artifact_id: String,
    pub artifact_kind: String,
    pub artifact_ref: String,
    pub content_type: String,
    pub content_encoding: Option<String>,
    pub byte_length: u64,
    pub digest: String,
    pub producer_id: String,
    pub created_at: i64,
    pub subject_ref: String,
    pub retention_class: Option<String>,
    pub preview: Option<String>,
    pub labels: BTreeMap<String, String>,
}

impl ArtifactEnvelope {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        artifact_id: impl Into<String>,
        artifact_kind: impl Into<String>,
        artifact_ref: impl Into<String>,
        content_type: impl Into<String>,
        byte_length: u64,
        digest: impl Into<String>,
        producer_id: impl Into<String>,
        created_at: i64,
        subject_ref: impl Into<String>,
    ) -> Self {
        Self {
            artifact_id: artifact_id.into(),
            artifact_kind: artifact_kind.into(),
            artifact_ref: artifact_ref.into(),
            content_type: content_type.into(),
            content_encoding: None,
            byte_length,
            digest: digest.into(),
            producer_id: producer_id.into(),
            created_at,
            subject_ref: subject_ref.into(),
            retention_class: None,
            preview: None,
            labels: BTreeMap::new(),
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn summary(
        artifact_id: impl Into<String>,
        artifact_kind: impl Into<String>,
        artifact_ref: impl Into<String>,
        content_type: impl Into<String>,
        byte_length: u64,
        digest: impl Into<String>,
        producer_id: impl Into<String>,
        created_at: i64,
        subject_ref: impl Into<String>,
        summary_kind: impl Into<String>,
    ) -> Self {
        Self::new(
            artifact_id,
            artifact_kind,
            artifact_ref,
            content_type,
            byte_length,
            digest,
            producer_id,
            created_at,
            subject_ref,
        )
        .with_role("summary")
        .with_label(SUMMARY_KIND_LABEL, summary_kind)
    }

    #[allow(clippy::too_many_arguments)]
    pub fn backlink(
        artifact_id: impl Into<String>,
        artifact_kind: impl Into<String>,
        artifact_ref: impl Into<String>,
        content_type: impl Into<String>,
        byte_length: u64,
        digest: impl Into<String>,
        producer_id: impl Into<String>,
        created_at: i64,
        subject_ref: impl Into<String>,
        backlink_kind: impl Into<String>,
    ) -> Self {
        Self::new(
            artifact_id,
            artifact_kind,
            artifact_ref,
            content_type,
            byte_length,
            digest,
            producer_id,
            created_at,
            subject_ref,
        )
        .with_role("backlink")
        .with_label(BACKLINK_KIND_LABEL, backlink_kind)
    }

    #[allow(clippy::too_many_arguments)]
    pub fn merge_outcome(
        artifact_id: impl Into<String>,
        artifact_kind: impl Into<String>,
        artifact_ref: impl Into<String>,
        content_type: impl Into<String>,
        byte_length: u64,
        digest: impl Into<String>,
        producer_id: impl Into<String>,
        created_at: i64,
        subject_ref: impl Into<String>,
        outcome_kind: impl Into<String>,
    ) -> Self {
        Self::new(
            artifact_id,
            artifact_kind,
            artifact_ref,
            content_type,
            byte_length,
            digest,
            producer_id,
            created_at,
            subject_ref,
        )
        .with_role("merge_outcome")
        .with_label(MERGE_OUTCOME_KIND_LABEL, outcome_kind)
    }

    pub fn with_content_encoding(mut self, content_encoding: impl Into<String>) -> Self {
        self.content_encoding = Some(content_encoding.into());
        self
    }

    pub fn with_retention_class(mut self, retention_class: impl Into<String>) -> Self {
        self.retention_class = Some(retention_class.into());
        self
    }

    pub fn with_preview(mut self, preview: impl Into<String>) -> Self {
        self.preview = Some(preview.into());
        self
    }

    pub fn with_label(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.labels.insert(key.into(), value.into());
        self
    }

    pub fn with_labels<I, K, V>(mut self, labels: I) -> Self
    where
        I: IntoIterator<Item = (K, V)>,
        K: Into<String>,
        V: Into<String>,
    {
        for (key, value) in labels {
            self.labels.insert(key.into(), value.into());
        }
        self
    }

    pub fn label(&self, key: &str) -> Option<&str> {
        self.labels.get(key).map(String::as_str)
    }

    pub fn role(&self) -> Option<&str> {
        self.label(ARTIFACT_ROLE_LABEL)
    }

    fn with_role(self, role: impl Into<String>) -> Self {
        self.with_label(ARTIFACT_ROLE_LABEL, role)
    }
}

#[cfg(test)]
mod tests {
    use super::{
        ARTIFACT_ROLE_LABEL, ArtifactEnvelope, BACKLINK_KIND_LABEL, MERGE_OUTCOME_KIND_LABEL,
        SUMMARY_KIND_LABEL,
    };

    #[test]
    fn summary_helper_preserves_explicit_descriptor_fields() {
        let envelope = ArtifactEnvelope::summary(
            "artifact-1",
            "artifact-envelope",
            "artifacts/root/summary-1",
            "application/json",
            128,
            "sha256:abc123",
            "tool.summary",
            1_742_000_000,
            "stream:task.root",
            "model",
        )
        .with_preview("short summary");

        assert_eq!(envelope.artifact_id, "artifact-1");
        assert_eq!(envelope.artifact_ref, "artifacts/root/summary-1");
        assert_eq!(envelope.digest, "sha256:abc123");
        assert_eq!(envelope.subject_ref, "stream:task.root");
        assert_eq!(envelope.role(), Some("summary"));
        assert_eq!(envelope.label(SUMMARY_KIND_LABEL), Some("model"));
        assert_eq!(envelope.preview.as_deref(), Some("short summary"));
    }

    #[test]
    fn backlink_helper_keeps_subject_and_custom_labels_explicit() {
        let envelope = ArtifactEnvelope::backlink(
            "artifact-2",
            "artifact-envelope",
            "artifacts/root/backlink-1",
            "application/json",
            96,
            "sha256:def456",
            "tool.backlink",
            1_742_000_100,
            "stream:task.root.thread",
            "mention",
        )
        .with_labels([
            ("thread_stream_id", "task.root.thread"),
            ("anchor_message_id", "msg-42"),
        ]);

        assert_eq!(envelope.role(), Some("backlink"));
        assert_eq!(envelope.label(BACKLINK_KIND_LABEL), Some("mention"));
        assert_eq!(envelope.label("thread_stream_id"), Some("task.root.thread"));
        assert_eq!(envelope.label("anchor_message_id"), Some("msg-42"));
    }

    #[test]
    fn merge_outcome_helper_preserves_replayable_descriptor_state() {
        let envelope = ArtifactEnvelope::merge_outcome(
            "artifact-3",
            "artifact-envelope",
            "artifacts/task/merge-1",
            "application/json",
            144,
            "sha256:789abc",
            "tool.merge",
            1_742_000_200,
            "stream:task.merge",
            "resolution",
        )
        .with_content_encoding("gzip")
        .with_retention_class("audit");

        assert_eq!(envelope.label(ARTIFACT_ROLE_LABEL), Some("merge_outcome"));
        assert_eq!(envelope.label(MERGE_OUTCOME_KIND_LABEL), Some("resolution"));
        assert_eq!(envelope.content_encoding.as_deref(), Some("gzip"));
        assert_eq!(envelope.retention_class.as_deref(), Some("audit"));
        assert_eq!(envelope.subject_ref, "stream:task.merge");
    }
}
