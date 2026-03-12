use anyhow::{Result, bail, ensure};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Stable identifier for one logical append-only stream.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct StreamId(String);

impl StreamId {
    pub fn new(value: impl Into<String>) -> Result<Self> {
        let value = value.into();
        ensure!(!value.trim().is_empty(), "stream ids must not be empty");
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl From<StreamId> for String {
    fn from(value: StreamId) -> Self {
        value.0
    }
}

/// Monotonic position within one logical stream.
#[derive(Debug, Copy, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct Offset(u64);

impl Offset {
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    pub const fn value(self) -> u64 {
        self.0
    }
}

/// Explicit stream-local record identity.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct StreamPosition {
    pub stream_id: StreamId,
    pub offset: Offset,
}

impl StreamPosition {
    pub fn new(stream_id: StreamId, offset: Offset) -> Self {
        Self { stream_id, offset }
    }
}

/// Shared lineage metadata for roots, branches, and merges.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct LineageMetadata {
    pub actor: Option<String>,
    pub reason: Option<String>,
    pub labels: BTreeMap<String, String>,
}

impl LineageMetadata {
    pub fn new(actor: Option<String>, reason: Option<String>) -> Self {
        Self {
            actor,
            reason,
            labels: BTreeMap::new(),
        }
    }

    pub fn with_label(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.labels.insert(key.into(), value.into());
        self
    }
}

/// The point where a child stream diverges from parent history.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BranchPoint {
    pub parent: StreamPosition,
    pub metadata: LineageMetadata,
}

impl BranchPoint {
    pub fn new(parent: StreamPosition, metadata: LineageMetadata) -> Self {
        Self { parent, metadata }
    }
}

/// Named merge-policy choice plus explicit metadata.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MergePolicy {
    pub kind: MergePolicyKind,
    pub metadata: BTreeMap<String, String>,
}

impl MergePolicy {
    pub fn new(kind: MergePolicyKind) -> Self {
        Self {
            kind,
            metadata: BTreeMap::new(),
        }
    }

    pub fn with_metadata(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.metadata.insert(key.into(), value.into());
        self
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MergePolicyKind {
    FastForward,
    Recursive,
    Custom(String),
}

/// Explicit reconciliation request that preserves every parent head.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MergeSpec {
    pub parents: Vec<StreamPosition>,
    pub merge_base: Option<StreamPosition>,
    pub policy: MergePolicy,
    pub metadata: LineageMetadata,
}

impl MergeSpec {
    pub fn new(
        parents: Vec<StreamPosition>,
        merge_base: Option<StreamPosition>,
        policy: MergePolicy,
        metadata: LineageMetadata,
    ) -> Result<Self> {
        ensure!(parents.len() >= 2, "merge specs require at least two parent heads");

        let mut seen_streams = BTreeMap::new();
        for parent in &parents {
            if seen_streams.insert(parent.stream_id.as_str().to_owned(), ()).is_some() {
                bail!("merge specs require parent heads from distinct streams");
            }
        }

        Ok(Self {
            parents,
            merge_base,
            policy,
            metadata,
        })
    }
}

/// Creation lineage for a stream head. Roots, branches, and merges all create
/// new append-only heads rather than mutating acknowledged history in place.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum StreamLineage {
    Root { metadata: LineageMetadata },
    Branch { branch_point: BranchPoint },
    Merge { merge: MergeSpec },
}

/// Stream descriptor used by the first storage kernel.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StreamDescriptor {
    pub stream_id: StreamId,
    pub lineage: StreamLineage,
}

impl StreamDescriptor {
    pub fn root(stream_id: StreamId, metadata: LineageMetadata) -> Self {
        Self {
            stream_id,
            lineage: StreamLineage::Root { metadata },
        }
    }

    pub fn branch(
        stream_id: StreamId,
        parent: StreamPosition,
        metadata: LineageMetadata,
    ) -> Result<Self> {
        ensure!(
            stream_id != parent.stream_id,
            "branch creation must create a new stream head"
        );

        Ok(Self {
            stream_id,
            lineage: StreamLineage::Branch {
                branch_point: BranchPoint::new(parent, metadata),
            },
        })
    }

    pub fn merge(stream_id: StreamId, merge: MergeSpec) -> Result<Self> {
        ensure!(
            merge.parents.iter().all(|parent| parent.stream_id != stream_id),
            "merge results must create a new stream head"
        );

        Ok(Self {
            stream_id,
            lineage: StreamLineage::Merge { merge },
        })
    }

    pub fn parent_stream_ids(&self) -> Vec<&StreamId> {
        match &self.lineage {
            StreamLineage::Root { .. } => Vec::new(),
            StreamLineage::Branch { branch_point } => vec![&branch_point.parent.stream_id],
            StreamLineage::Merge { merge } => {
                merge.parents.iter().map(|parent| &parent.stream_id).collect()
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset, StreamDescriptor,
        StreamId, StreamPosition, StreamLineage,
    };

    fn stream_id(value: &str) -> StreamId {
        StreamId::new(value).expect("valid stream id")
    }

    fn position(stream_id: &str, offset: u64) -> StreamPosition {
        StreamPosition::new(super::StreamId::new(stream_id).expect("stream id"), Offset::new(offset))
    }

    #[test]
    fn branch_descriptor_records_parent_position_and_metadata() {
        let descriptor = StreamDescriptor::branch(
            stream_id("task.retry.1"),
            position("task.root", 7),
            LineageMetadata::new(Some("agent.planner".into()), Some("retry-after-timeout".into()))
                .with_label("branch_kind", "retry"),
        )
        .expect("valid branch");

        assert_eq!(descriptor.stream_id.as_str(), "task.retry.1");
        assert_eq!(
            descriptor.parent_stream_ids(),
            vec![&stream_id("task.root")]
        );

        match descriptor.lineage {
            StreamLineage::Branch { branch_point } => {
                assert_eq!(branch_point.parent.offset.value(), 7);
                assert_eq!(
                    branch_point.metadata.reason.as_deref(),
                    Some("retry-after-timeout")
                );
                assert_eq!(
                    branch_point.metadata.labels.get("branch_kind").map(String::as_str),
                    Some("retry")
                );
            }
            other => panic!("expected branch lineage, got {other:?}"),
        }
    }

    #[test]
    fn merge_descriptor_preserves_multi_parent_lineage() {
        let merge = MergeSpec::new(
            vec![position("task.retry.1", 12), position("task.critique.1", 9)],
            Some(position("task.root", 7)),
            MergePolicy::new(MergePolicyKind::Recursive)
                .with_metadata("policy_reason", "synthesize-best-answer"),
            LineageMetadata::new(Some("agent.judge".into()), Some("merge-winning-paths".into())),
        )
        .expect("valid merge");

        let descriptor = StreamDescriptor::merge(stream_id("task.merge.1"), merge.clone())
            .expect("merge descriptor");

        assert_eq!(descriptor.parent_stream_ids().len(), 2);

        match descriptor.lineage {
            StreamLineage::Merge { merge } => {
                assert_eq!(merge.parents.len(), 2);
                assert_eq!(merge.parents[0].stream_id.as_str(), "task.retry.1");
                assert_eq!(merge.parents[1].stream_id.as_str(), "task.critique.1");
                assert_eq!(merge.merge_base.expect("merge base").offset.value(), 7);
                assert_eq!(merge.policy.metadata["policy_reason"], "synthesize-best-answer");
            }
            other => panic!("expected merge lineage, got {other:?}"),
        }
    }

    #[test]
    fn append_only_constructors_reject_in_place_reconciliation() {
        let branch_error = StreamDescriptor::branch(
            stream_id("task.root"),
            position("task.root", 4),
            LineageMetadata::default(),
        )
        .expect_err("branch should require a new child stream");
        assert!(
            branch_error
                .to_string()
                .contains("branch creation must create a new stream head")
        );

        let merge_error = StreamDescriptor::merge(
            stream_id("task.retry.1"),
            MergeSpec::new(
                vec![position("task.retry.1", 12), position("task.critique.1", 9)],
                None,
                MergePolicy::new(MergePolicyKind::FastForward),
                LineageMetadata::default(),
            )
            .expect("valid parents"),
        )
        .expect_err("merge should create a new head");
        assert!(
            merge_error
                .to_string()
                .contains("merge results must create a new stream head")
        );
    }
}
