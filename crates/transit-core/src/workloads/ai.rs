use crate::artifact::{ARTIFACT_ROLE_LABEL, ArtifactEnvelope};
use crate::kernel::{
    LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, StreamId, StreamPosition,
};
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub const ROOT_TRACE_KIND: &str = "root";
pub const RETRY_TRACE_KIND: &str = "retry";
pub const CRITIQUE_TRACE_KIND: &str = "critique";
pub const MERGE_TRACE_KIND: &str = "merge";
pub const TOOL_CALL_TRACE_KIND: &str = "tool-call";
pub const EVALUATOR_DECISION_TRACE_KIND: &str = "evaluator-decision";
pub const CHECKPOINT_TRACE_KIND: &str = "checkpoint";
pub const MERGE_ARTIFACT_ROLE: &str = "ai-merge-artifact";

pub const TASK_ID_LABEL: &str = "task_id";
pub const TRACE_KIND_LABEL: &str = "trace_kind";
pub const ACTOR_ID_LABEL: &str = "actor_id";
pub const CREATED_AT_LABEL: &str = "created_at";
pub const REASON_LABEL: &str = "reason";
pub const PARENT_STREAM_ID_LABEL: &str = "parent_stream_id";
pub const FORK_OFFSET_LABEL: &str = "fork_offset";
pub const BRANCH_KIND_LABEL: &str = "branch_kind";
pub const TOOL_NAME_LABEL: &str = "tool_name";
pub const TOOL_CALL_ID_LABEL: &str = "tool_call_id";
pub const TOOL_PHASE_LABEL: &str = "tool_phase";
pub const TOOL_STATUS_LABEL: &str = "tool_status";
pub const EVALUATOR_ID_LABEL: &str = "evaluator_id";
pub const SUBJECT_REF_LABEL: &str = "subject_ref";
pub const DECISION_LABEL: &str = "decision";
pub const CHECKPOINT_ID_LABEL: &str = "checkpoint_id";
pub const CHECKPOINT_KIND_LABEL: &str = "checkpoint_kind";
pub const CHECKPOINT_STATUS_LABEL: &str = "checkpoint_status";
pub const MERGE_PARENTS_LABEL: &str = "merge_parents";
pub const MERGE_POLICY_LABEL: &str = "merge_policy";
pub const MERGE_REASON_LABEL: &str = "merge_reason";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolCallEvent {
    #[serde(rename = "type")]
    pub event_type: String,
    pub task_id: String,
    pub trace_kind: String,
    pub actor_id: String,
    pub created_at: i64,
    pub reason: String,
    pub tool_name: String,
    pub tool_call_id: String,
    pub tool_phase: String,
    pub tool_status: String,
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub labels: BTreeMap<String, String>,
}

impl ToolCallEvent {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        task_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
        tool_name: impl Into<String>,
        tool_call_id: impl Into<String>,
        tool_phase: impl Into<String>,
        tool_status: impl Into<String>,
        created_at: i64,
    ) -> Result<Self> {
        Ok(Self {
            event_type: "agent.tool_call".to_owned(),
            task_id: non_empty("task_id", task_id)?,
            trace_kind: TOOL_CALL_TRACE_KIND.to_owned(),
            actor_id: non_empty("actor_id", actor_id)?,
            created_at,
            reason: non_empty("reason", reason)?,
            tool_name: non_empty("tool_name", tool_name)?,
            tool_call_id: non_empty("tool_call_id", tool_call_id)?,
            tool_phase: non_empty("tool_phase", tool_phase)?,
            tool_status: non_empty("tool_status", tool_status)?,
            labels: BTreeMap::new(),
        })
    }

    pub fn with_label(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.labels.insert(key.into(), value.into());
        self
    }

    pub fn payload_bytes(&self) -> Result<Vec<u8>> {
        payload_bytes(self)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EvaluatorDecision {
    #[serde(rename = "type")]
    pub event_type: String,
    pub task_id: String,
    pub trace_kind: String,
    pub actor_id: String,
    pub created_at: i64,
    pub reason: String,
    pub evaluator_id: String,
    pub subject_ref: String,
    pub decision: String,
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub labels: BTreeMap<String, String>,
}

impl EvaluatorDecision {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        task_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
        evaluator_id: impl Into<String>,
        subject_ref: impl Into<String>,
        decision: impl Into<String>,
        created_at: i64,
    ) -> Result<Self> {
        Ok(Self {
            event_type: "agent.evaluator_decision".to_owned(),
            task_id: non_empty("task_id", task_id)?,
            trace_kind: EVALUATOR_DECISION_TRACE_KIND.to_owned(),
            actor_id: non_empty("actor_id", actor_id)?,
            created_at,
            reason: non_empty("reason", reason)?,
            evaluator_id: non_empty("evaluator_id", evaluator_id)?,
            subject_ref: non_empty("subject_ref", subject_ref)?,
            decision: non_empty("decision", decision)?,
            labels: BTreeMap::new(),
        })
    }

    pub fn with_label(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.labels.insert(key.into(), value.into());
        self
    }

    pub fn payload_bytes(&self) -> Result<Vec<u8>> {
        payload_bytes(self)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompletionCheckpoint {
    #[serde(rename = "type")]
    pub event_type: String,
    pub task_id: String,
    pub trace_kind: String,
    pub actor_id: String,
    pub created_at: i64,
    pub reason: String,
    pub checkpoint_id: String,
    pub checkpoint_kind: String,
    pub checkpoint_status: String,
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub labels: BTreeMap<String, String>,
}

impl CompletionCheckpoint {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        task_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
        checkpoint_id: impl Into<String>,
        checkpoint_kind: impl Into<String>,
        checkpoint_status: impl Into<String>,
        created_at: i64,
    ) -> Result<Self> {
        Ok(Self {
            event_type: "agent.checkpoint".to_owned(),
            task_id: non_empty("task_id", task_id)?,
            trace_kind: CHECKPOINT_TRACE_KIND.to_owned(),
            actor_id: non_empty("actor_id", actor_id)?,
            created_at,
            reason: non_empty("reason", reason)?,
            checkpoint_id: non_empty("checkpoint_id", checkpoint_id)?,
            checkpoint_kind: non_empty("checkpoint_kind", checkpoint_kind)?,
            checkpoint_status: non_empty("checkpoint_status", checkpoint_status)?,
            labels: BTreeMap::new(),
        })
    }

    pub fn with_label(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.labels.insert(key.into(), value.into());
        self
    }

    pub fn payload_bytes(&self) -> Result<Vec<u8>> {
        payload_bytes(self)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TraceBranch {
    pub branch_stream_id: StreamId,
    pub parent: StreamPosition,
    pub metadata: LineageMetadata,
}

impl TraceBranch {
    pub fn retry(
        branch_stream_id: StreamId,
        parent: StreamPosition,
        task_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
    ) -> Result<Self> {
        Self::new(
            branch_stream_id,
            parent,
            task_id,
            RETRY_TRACE_KIND,
            actor_id,
            reason,
        )
    }

    pub fn critique(
        branch_stream_id: StreamId,
        parent: StreamPosition,
        task_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
    ) -> Result<Self> {
        Self::new(
            branch_stream_id,
            parent,
            task_id,
            CRITIQUE_TRACE_KIND,
            actor_id,
            reason,
        )
    }

    pub fn new(
        branch_stream_id: StreamId,
        parent: StreamPosition,
        task_id: impl Into<String>,
        branch_kind: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
    ) -> Result<Self> {
        let task_id = non_empty("task_id", task_id)?;
        let branch_kind = non_empty("branch_kind", branch_kind)?;
        let actor_id = non_empty("actor_id", actor_id)?;
        let reason = non_empty("reason", reason)?;
        let metadata = branch_metadata(&task_id, &branch_kind, &parent, &actor_id, &reason);

        Ok(Self {
            branch_stream_id,
            parent,
            metadata,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TraceMerge {
    pub merge_stream_id: StreamId,
    pub merge: MergeSpec,
}

impl TraceMerge {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        merge_stream_id: StreamId,
        parents: Vec<StreamPosition>,
        merge_base: Option<StreamPosition>,
        task_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
        policy_kind: MergePolicyKind,
        merge_reason: impl Into<String>,
    ) -> Result<Self> {
        let task_id = non_empty("task_id", task_id)?;
        let actor_id = non_empty("actor_id", actor_id)?;
        let reason = non_empty("reason", reason)?;
        let merge_reason = non_empty("merge_reason", merge_reason)?;
        let merge_policy = merge_policy_label(&policy_kind);
        let parent_refs = position_refs(&parents);
        let policy = MergePolicy::new(policy_kind)
            .with_metadata(MERGE_POLICY_LABEL, merge_policy.clone())
            .with_metadata(MERGE_REASON_LABEL, merge_reason.clone());
        let metadata = LineageMetadata::new(Some(actor_id.clone()), Some(reason.clone()))
            .with_labels([
                (TASK_ID_LABEL, task_id.as_str()),
                (TRACE_KIND_LABEL, MERGE_TRACE_KIND),
                (ACTOR_ID_LABEL, actor_id.as_str()),
                (REASON_LABEL, reason.as_str()),
            ])
            .with_label(MERGE_PARENTS_LABEL, parent_refs)
            .with_label(MERGE_POLICY_LABEL, merge_policy)
            .with_label(MERGE_REASON_LABEL, merge_reason);

        Ok(Self {
            merge_stream_id,
            merge: MergeSpec::new(parents, merge_base, policy, metadata)?,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AiArtifactDescriptor {
    pub artifact_id: String,
    pub artifact_kind: String,
    pub artifact_ref: String,
    pub content_type: String,
    pub byte_length: u64,
    pub digest: String,
    pub producer_id: String,
    pub created_at: i64,
    pub subject_ref: String,
}

impl AiArtifactDescriptor {
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
    ) -> Result<Self> {
        Ok(Self {
            artifact_id: non_empty("artifact_id", artifact_id)?,
            artifact_kind: non_empty("artifact_kind", artifact_kind)?,
            artifact_ref: non_empty("artifact_ref", artifact_ref)?,
            content_type: non_empty("content_type", content_type)?,
            byte_length,
            digest: non_empty("digest", digest)?,
            producer_id: non_empty("producer_id", producer_id)?,
            created_at,
            subject_ref: non_empty("subject_ref", subject_ref)?,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MergeArtifact {
    pub task_id: String,
    pub actor_id: String,
    pub reason: String,
    pub merge_parents: Vec<StreamPosition>,
    pub merge_policy: String,
    pub merge_reason: String,
}

impl MergeArtifact {
    pub fn new(
        task_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
        merge_parents: Vec<StreamPosition>,
        merge_policy: impl Into<String>,
        merge_reason: impl Into<String>,
    ) -> Result<Self> {
        ensure!(
            merge_parents.len() >= 2,
            "merge artifacts require at least two parent heads"
        );
        Ok(Self {
            task_id: non_empty("task_id", task_id)?,
            actor_id: non_empty("actor_id", actor_id)?,
            reason: non_empty("reason", reason)?,
            merge_parents,
            merge_policy: non_empty("merge_policy", merge_policy)?,
            merge_reason: non_empty("merge_reason", merge_reason)?,
        })
    }

    pub fn artifact(&self, descriptor: AiArtifactDescriptor) -> ArtifactEnvelope {
        ArtifactEnvelope::merge_outcome(
            descriptor.artifact_id,
            descriptor.artifact_kind,
            descriptor.artifact_ref,
            descriptor.content_type,
            descriptor.byte_length,
            descriptor.digest,
            descriptor.producer_id,
            descriptor.created_at,
            descriptor.subject_ref,
            self.merge_reason.as_str(),
        )
        .with_label(ARTIFACT_ROLE_LABEL, MERGE_ARTIFACT_ROLE)
        .with_label(TASK_ID_LABEL, self.task_id.as_str())
        .with_label(TRACE_KIND_LABEL, MERGE_TRACE_KIND)
        .with_label(ACTOR_ID_LABEL, self.actor_id.as_str())
        .with_label(REASON_LABEL, self.reason.as_str())
        .with_label(MERGE_PARENTS_LABEL, position_refs(&self.merge_parents))
        .with_label(MERGE_POLICY_LABEL, self.merge_policy.as_str())
        .with_label(MERGE_REASON_LABEL, self.merge_reason.as_str())
    }
}

pub fn task_root_metadata(
    task_id: impl Into<String>,
    actor_id: impl Into<String>,
    reason: impl Into<String>,
    created_at: i64,
) -> Result<LineageMetadata> {
    let task_id = non_empty("task_id", task_id)?;
    let actor_id = non_empty("actor_id", actor_id)?;
    let reason = non_empty("reason", reason)?;
    Ok(
        LineageMetadata::new(Some(actor_id.clone()), Some(reason.clone()))
            .with_labels([
                (TASK_ID_LABEL, task_id.as_str()),
                (TRACE_KIND_LABEL, ROOT_TRACE_KIND),
                (ACTOR_ID_LABEL, actor_id.as_str()),
                (REASON_LABEL, reason.as_str()),
            ])
            .with_label(CREATED_AT_LABEL, created_at.to_string()),
    )
}

pub fn payload_bytes<T>(payload: &T) -> Result<Vec<u8>>
where
    T: Serialize,
{
    serde_json::to_vec(payload).context("serialize ai trace payload")
}

fn branch_metadata(
    task_id: &str,
    branch_kind: &str,
    parent: &StreamPosition,
    actor_id: &str,
    reason: &str,
) -> LineageMetadata {
    LineageMetadata::new(Some(actor_id.to_owned()), Some(reason.to_owned()))
        .with_branch_kind(branch_kind)
        .with_anchor_ref(position_ref(parent))
        .with_labels([
            (TASK_ID_LABEL, task_id),
            (TRACE_KIND_LABEL, branch_kind),
            (ACTOR_ID_LABEL, actor_id),
            (REASON_LABEL, reason),
            (PARENT_STREAM_ID_LABEL, parent.stream_id.as_str()),
            (BRANCH_KIND_LABEL, branch_kind),
        ])
        .with_label(FORK_OFFSET_LABEL, parent.offset.value().to_string())
}

fn non_empty(name: &str, value: impl Into<String>) -> Result<String> {
    let value = value.into();
    ensure!(!value.trim().is_empty(), "{name} must not be empty");
    Ok(value)
}

fn position_ref(position: &StreamPosition) -> String {
    format!(
        "{}@{}",
        position.stream_id.as_str(),
        position.offset.value()
    )
}

fn position_refs(positions: &[StreamPosition]) -> String {
    positions
        .iter()
        .map(position_ref)
        .collect::<Vec<_>>()
        .join(",")
}

fn merge_policy_label(policy_kind: &MergePolicyKind) -> String {
    match policy_kind {
        MergePolicyKind::FastForward => "fast-forward".to_owned(),
        MergePolicyKind::Recursive => "recursive".to_owned(),
        MergePolicyKind::Custom(kind) => kind.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::artifact::MERGE_OUTCOME_KIND_LABEL;
    use crate::engine::{LocalEngine, LocalEngineConfig};
    use crate::kernel::{Offset, StreamDescriptor, StreamLineage};
    use crate::membership::NodeId;
    use serde_json::Value;
    use tempfile::tempdir;

    fn stream_id(value: &str) -> StreamId {
        StreamId::new(value).expect("stream id")
    }

    fn artifact_descriptor(artifact_id: &str) -> AiArtifactDescriptor {
        AiArtifactDescriptor::new(
            artifact_id,
            "merge-artifact",
            format!("artifacts/task-0142/{artifact_id}.json"),
            "application/json",
            256,
            format!("sha256:{artifact_id}"),
            "agent.judge",
            1_774_300_000,
            "stream:task.merge",
        )
        .expect("artifact descriptor")
    }

    #[test]
    fn typed_builders_cover_ai_trace_contract_shapes() {
        let root = task_root_metadata("task-0142", "human.alex", "initial-request", 1_774_300_000)
            .expect("root metadata");
        assert_eq!(root.label(TASK_ID_LABEL), Some("task-0142"));
        assert_eq!(root.label(TRACE_KIND_LABEL), Some(ROOT_TRACE_KIND));
        assert_eq!(root.label(CREATED_AT_LABEL), Some("1774300000"));

        let parent = StreamPosition::new(stream_id("task.root"), Offset::new(7));
        let retry = TraceBranch::retry(
            stream_id("task.retry.1"),
            parent.clone(),
            "task-0142",
            "agent.runner",
            "retry-after-timeout",
        )
        .expect("retry branch");
        assert_eq!(retry.metadata.branch_kind(), Some(RETRY_TRACE_KIND));
        assert_eq!(retry.metadata.anchor_ref(), Some("task.root@7"));
        assert_eq!(retry.metadata.label(FORK_OFFSET_LABEL), Some("7"));

        let critique = TraceBranch::critique(
            stream_id("task.critique.1"),
            parent.clone(),
            "task-0142",
            "agent.critic",
            "critique-pass",
        )
        .expect("critique branch");
        assert_eq!(critique.metadata.branch_kind(), Some(CRITIQUE_TRACE_KIND));
        assert_eq!(
            critique.metadata.label(TRACE_KIND_LABEL),
            Some(CRITIQUE_TRACE_KIND)
        );

        let tool = ToolCallEvent::new(
            "task-0142",
            "agent.planner.v1",
            "gather-context",
            "search",
            "tc-0091",
            "request",
            "success",
            1_774_300_001,
        )
        .expect("tool event")
        .with_label("provider", "local");
        let tool_json: Value =
            serde_json::from_slice(&tool.payload_bytes().expect("tool bytes")).expect("tool json");
        assert_eq!(tool_json["type"], "agent.tool_call");
        assert_eq!(tool_json["trace_kind"], TOOL_CALL_TRACE_KIND);
        assert_eq!(tool_json["tool_call_id"], "tc-0091");
        assert_eq!(tool_json["labels"]["provider"], "local");

        let evaluator = EvaluatorDecision::new(
            "task-0142",
            "judge.v1",
            "rank-candidate",
            "judge.v1",
            "stream:task.retry.1@9",
            "selected",
            1_774_300_002,
        )
        .expect("evaluator decision");
        let evaluator_json: Value =
            serde_json::from_slice(&evaluator.payload_bytes().expect("evaluator bytes"))
                .expect("evaluator json");
        assert_eq!(evaluator_json["type"], "agent.evaluator_decision");
        assert_eq!(evaluator_json["decision"], "selected");

        let checkpoint = CompletionCheckpoint::new(
            "task-0142",
            "agent.finalizer",
            "final-answer",
            "cp-final",
            "final",
            "success",
            1_774_300_003,
        )
        .expect("checkpoint");
        let checkpoint_json: Value =
            serde_json::from_slice(&checkpoint.payload_bytes().expect("checkpoint bytes"))
                .expect("checkpoint json");
        assert_eq!(checkpoint_json["type"], "agent.checkpoint");
        assert_eq!(checkpoint_json["checkpoint_status"], "success");

        let parents = vec![
            StreamPosition::new(stream_id("task.retry.1"), Offset::new(9)),
            StreamPosition::new(stream_id("task.critique.1"), Offset::new(4)),
        ];
        let merge = TraceMerge::new(
            stream_id("task.merge.1"),
            parents.clone(),
            Some(parent),
            "task-0142",
            "judge.v1",
            "merge-winning-paths",
            MergePolicyKind::Recursive,
            "select retry with critique notes",
        )
        .expect("merge spec");
        assert_eq!(merge.merge.parents, parents);
        assert_eq!(
            merge.merge.metadata.label(MERGE_PARENTS_LABEL),
            Some("task.retry.1@9,task.critique.1@4")
        );
        assert_eq!(
            merge.merge.policy.metadata[MERGE_REASON_LABEL],
            "select retry with critique notes"
        );

        let artifact = MergeArtifact::new(
            "task-0142",
            "judge.v1",
            "merge-winning-paths",
            merge.merge.parents.clone(),
            "recursive",
            "select retry with critique notes",
        )
        .expect("merge artifact")
        .artifact(artifact_descriptor("merge-1"));
        assert_eq!(
            artifact.label(ARTIFACT_ROLE_LABEL),
            Some(MERGE_ARTIFACT_ROLE)
        );
        assert_eq!(
            artifact.label(MERGE_OUTCOME_KIND_LABEL),
            Some("select retry with critique notes")
        );
        assert_eq!(
            artifact.label(MERGE_PARENTS_LABEL),
            Some("task.retry.1@9,task.critique.1@4")
        );
    }

    #[test]
    fn ai_trace_helpers_preserve_lineage_and_explicit_merge_metadata() {
        let temp = tempdir().expect("temp dir");
        let engine = LocalEngine::open(LocalEngineConfig::new(temp.path(), NodeId::new("ai-node")))
            .expect("open engine");

        let root_stream = stream_id("task.root");
        let retry_stream = stream_id("task.retry.1");
        let critique_stream = stream_id("task.critique.1");
        let merge_stream = stream_id("task.merge.1");

        engine
            .create_stream(StreamDescriptor::root(
                root_stream.clone(),
                task_root_metadata("task-0142", "human.alex", "initial-request", 1_774_300_000)
                    .expect("root metadata"),
            ))
            .expect("create root");
        let root_event = ToolCallEvent::new(
            "task-0142",
            "agent.planner.v1",
            "gather-context",
            "search",
            "tc-0091",
            "request",
            "success",
            1_774_300_001,
        )
        .expect("root tool event");
        let root_append = engine
            .append(
                &root_stream,
                root_event.payload_bytes().expect("root bytes"),
            )
            .expect("append root event");

        let retry = TraceBranch::retry(
            retry_stream.clone(),
            root_append.position().clone(),
            "task-0142",
            "agent.runner",
            "retry-after-timeout",
        )
        .expect("retry branch");
        engine
            .create_branch(
                retry.branch_stream_id.clone(),
                retry.parent.clone(),
                retry.metadata.clone(),
            )
            .expect("create retry branch");
        let retry_event = ToolCallEvent::new(
            "task-0142",
            "agent.runner",
            "rerun-tool",
            "search",
            "tc-0092",
            "result",
            "success",
            1_774_300_002,
        )
        .expect("retry event");
        let retry_append = engine
            .append(
                &retry_stream,
                retry_event.payload_bytes().expect("retry bytes"),
            )
            .expect("append retry event");

        let critique = TraceBranch::critique(
            critique_stream.clone(),
            retry_append.position().clone(),
            "task-0142",
            "agent.critic",
            "critique-pass",
        )
        .expect("critique branch");
        engine
            .create_branch(
                critique.branch_stream_id.clone(),
                critique.parent.clone(),
                critique.metadata.clone(),
            )
            .expect("create critique branch");
        let decision = EvaluatorDecision::new(
            "task-0142",
            "judge.v1",
            "rank-candidate",
            "judge.v1",
            "stream:task.retry.1@1",
            "selected",
            1_774_300_003,
        )
        .expect("decision");
        let critique_append = engine
            .append(
                &critique_stream,
                decision.payload_bytes().expect("decision bytes"),
            )
            .expect("append critique decision");

        assert_eq!(engine.replay(&root_stream).expect("root replay").len(), 1);
        assert_eq!(engine.replay(&retry_stream).expect("retry replay").len(), 2);
        assert_eq!(
            engine
                .replay(&critique_stream)
                .expect("critique replay")
                .len(),
            3
        );

        let trace_merge = TraceMerge::new(
            merge_stream.clone(),
            vec![
                retry_append.position().clone(),
                critique_append.position().clone(),
            ],
            Some(root_append.position().clone()),
            "task-0142",
            "judge.v1",
            "merge-winning-paths",
            MergePolicyKind::Recursive,
            "select retry with critique notes",
        )
        .expect("trace merge");
        engine
            .create_merge(
                trace_merge.merge_stream_id.clone(),
                trace_merge.merge.clone(),
            )
            .expect("create merge");

        let merge_descriptor = engine
            .stream_descriptor(&merge_stream)
            .expect("merge descriptor");
        match merge_descriptor.lineage {
            StreamLineage::Merge { merge } => {
                assert_eq!(merge.parents.len(), 2);
                assert_eq!(merge.parents[0].stream_id.as_str(), "task.retry.1");
                assert_eq!(merge.parents[1].stream_id.as_str(), "task.critique.1");
                assert_eq!(
                    merge.merge_base.expect("merge base"),
                    root_append.position().clone()
                );
                assert_eq!(
                    merge.metadata.label(TRACE_KIND_LABEL),
                    Some(MERGE_TRACE_KIND)
                );
                assert_eq!(
                    merge.metadata.label(MERGE_PARENTS_LABEL),
                    Some("task.retry.1@1,task.critique.1@2")
                );
                assert_eq!(merge.policy.metadata[MERGE_POLICY_LABEL], "recursive");
                assert_eq!(
                    merge.policy.metadata[MERGE_REASON_LABEL],
                    "select retry with critique notes"
                );
            }
            other => panic!("expected merge lineage, got {other:?}"),
        }
    }
}
