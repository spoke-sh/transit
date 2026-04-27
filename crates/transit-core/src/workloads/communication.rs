use crate::artifact::{ARTIFACT_ROLE_LABEL, ArtifactEnvelope};
use crate::kernel::{LineageMetadata, Offset, StreamId, StreamPosition};
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub const CHANNEL_ROOT_KIND: &str = "channel-root";
pub const CHANNEL_MESSAGE_KIND: &str = "channel-message";
pub const THREAD_BRANCH_KIND: &str = "thread-branch";
pub const THREAD_REPLY_KIND: &str = "thread-reply";
pub const THREAD_BACKLINK_KIND: &str = "thread-backlink";
pub const THREAD_SUMMARY_KIND: &str = "thread-summary";
pub const CLASSIFIER_EVIDENCE_KIND: &str = "classifier-evidence";
pub const HUMAN_OVERRIDE_KIND: &str = "human-override";

pub const COMMUNICATION_KIND_LABEL: &str = "communication_kind";
pub const CHANNEL_ID_LABEL: &str = "channel_id";
pub const ACTOR_ID_LABEL: &str = "actor_id";
pub const CREATED_AT_LABEL: &str = "created_at";
pub const REASON_LABEL: &str = "reason";
pub const THREAD_STREAM_ID_LABEL: &str = "thread_stream_id";
pub const PARENT_STREAM_ID_LABEL: &str = "parent_stream_id";
pub const ANCHOR_MESSAGE_ID_LABEL: &str = "anchor_message_id";
pub const FORK_OFFSET_LABEL: &str = "fork_offset";
pub const THREAD_KIND_LABEL: &str = "thread_kind";
pub const DECISION_ID_LABEL: &str = "decision_id";
pub const CLASSIFIER_ID_LABEL: &str = "classifier_id";
pub const CLASSIFIER_VERSION_LABEL: &str = "classifier_version";
pub const DECISION_LABEL: &str = "decision";
pub const SCORE_LABEL: &str = "score";
pub const THRESHOLD_LABEL: &str = "threshold";
pub const EVIDENCE_REF_LABEL: &str = "evidence_ref";
pub const DECIDED_AT_LABEL: &str = "decided_at";
pub const OVERRIDE_ID_LABEL: &str = "override_id";
pub const OVERRIDE_KIND_LABEL: &str = "override_kind";
pub const SUPERSEDES_REF_LABEL: &str = "supersedes_ref";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ChannelMessage {
    #[serde(rename = "type")]
    pub event_type: String,
    pub channel_id: String,
    pub communication_kind: String,
    pub actor_id: String,
    pub author_id: String,
    pub created_at: i64,
    pub reason: String,
    pub message_id: String,
    pub body_ref: String,
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub labels: BTreeMap<String, String>,
}

impl ChannelMessage {
    pub fn new(
        channel_id: impl Into<String>,
        message_id: impl Into<String>,
        actor_id: impl Into<String>,
        author_id: impl Into<String>,
        body_ref: impl Into<String>,
        reason: impl Into<String>,
        created_at: i64,
    ) -> Result<Self> {
        let event = Self {
            event_type: "message.posted".to_owned(),
            channel_id: non_empty("channel_id", channel_id)?,
            communication_kind: CHANNEL_MESSAGE_KIND.to_owned(),
            actor_id: non_empty("actor_id", actor_id)?,
            author_id: non_empty("author_id", author_id)?,
            created_at,
            reason: non_empty("reason", reason)?,
            message_id: non_empty("message_id", message_id)?,
            body_ref: non_empty("body_ref", body_ref)?,
            labels: BTreeMap::new(),
        };
        Ok(event)
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
pub struct ThreadReply {
    #[serde(rename = "type")]
    pub event_type: String,
    pub channel_id: String,
    pub communication_kind: String,
    pub actor_id: String,
    pub author_id: String,
    pub created_at: i64,
    pub reason: String,
    pub message_id: String,
    pub thread_stream_id: String,
    pub body_ref: String,
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub labels: BTreeMap<String, String>,
}

impl ThreadReply {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        channel_id: impl Into<String>,
        message_id: impl Into<String>,
        thread_stream_id: impl Into<String>,
        actor_id: impl Into<String>,
        author_id: impl Into<String>,
        body_ref: impl Into<String>,
        reason: impl Into<String>,
        created_at: i64,
    ) -> Result<Self> {
        let event = Self {
            event_type: "thread.reply".to_owned(),
            channel_id: non_empty("channel_id", channel_id)?,
            communication_kind: THREAD_REPLY_KIND.to_owned(),
            actor_id: non_empty("actor_id", actor_id)?,
            author_id: non_empty("author_id", author_id)?,
            created_at,
            reason: non_empty("reason", reason)?,
            message_id: non_empty("message_id", message_id)?,
            thread_stream_id: non_empty("thread_stream_id", thread_stream_id)?,
            body_ref: non_empty("body_ref", body_ref)?,
            labels: BTreeMap::new(),
        };
        Ok(event)
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
pub struct ThreadBranch {
    pub thread_stream_id: StreamId,
    pub parent: StreamPosition,
    pub metadata: LineageMetadata,
}

impl ThreadBranch {
    pub fn manual(
        thread_stream_id: StreamId,
        parent: StreamPosition,
        channel_id: impl Into<String>,
        anchor_message_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
    ) -> Result<Self> {
        Self::new(
            thread_stream_id,
            parent,
            channel_id,
            anchor_message_id,
            "manual",
            actor_id,
            reason,
        )
    }

    pub fn new(
        thread_stream_id: StreamId,
        parent: StreamPosition,
        channel_id: impl Into<String>,
        anchor_message_id: impl Into<String>,
        thread_kind: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
    ) -> Result<Self> {
        let channel_id = non_empty("channel_id", channel_id)?;
        let anchor_message_id = non_empty("anchor_message_id", anchor_message_id)?;
        let thread_kind = non_empty("thread_kind", thread_kind)?;
        let actor_id = non_empty("actor_id", actor_id)?;
        let reason = non_empty("reason", reason)?;

        let metadata = thread_branch_metadata(
            &channel_id,
            thread_stream_id.as_str(),
            &parent,
            &anchor_message_id,
            &thread_kind,
            &actor_id,
            &reason,
        );

        Ok(Self {
            thread_stream_id,
            parent,
            metadata,
        })
    }

    pub fn classifier(
        thread_stream_id: StreamId,
        parent: StreamPosition,
        channel_id: impl Into<String>,
        evidence: &ClassifierEvidence,
    ) -> Result<Self> {
        let mut branch = Self::new(
            thread_stream_id,
            parent,
            channel_id,
            evidence.anchor_message_id.clone(),
            "classifier",
            evidence.classifier_id.clone(),
            "classifier-thread-split",
        )?;
        branch.metadata = evidence.apply_to_metadata(branch.metadata);
        Ok(branch)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ClassifierEvidence {
    pub decision_id: String,
    pub classifier_id: String,
    pub classifier_version: String,
    pub anchor_message_id: String,
    pub anchor_offset: Offset,
    pub decision: String,
    pub score: Option<f64>,
    pub threshold: Option<f64>,
    pub evidence_ref: Option<String>,
    pub decided_at: i64,
}

impl ClassifierEvidence {
    pub fn new(
        decision_id: impl Into<String>,
        classifier_id: impl Into<String>,
        classifier_version: impl Into<String>,
        anchor_message_id: impl Into<String>,
        anchor_offset: Offset,
        decision: impl Into<String>,
        decided_at: i64,
    ) -> Result<Self> {
        Ok(Self {
            decision_id: non_empty("decision_id", decision_id)?,
            classifier_id: non_empty("classifier_id", classifier_id)?,
            classifier_version: non_empty("classifier_version", classifier_version)?,
            anchor_message_id: non_empty("anchor_message_id", anchor_message_id)?,
            anchor_offset,
            decision: non_empty("decision", decision)?,
            score: None,
            threshold: None,
            evidence_ref: None,
            decided_at,
        })
    }

    pub fn with_score(mut self, score: f64, threshold: f64) -> Self {
        self.score = Some(score);
        self.threshold = Some(threshold);
        self
    }

    pub fn with_evidence_ref(mut self, evidence_ref: impl Into<String>) -> Self {
        self.evidence_ref = Some(evidence_ref.into());
        self
    }

    pub fn apply_to_metadata(&self, metadata: LineageMetadata) -> LineageMetadata {
        let mut metadata = metadata.with_labels([
            (DECISION_ID_LABEL, self.decision_id.as_str()),
            (CLASSIFIER_ID_LABEL, self.classifier_id.as_str()),
            (CLASSIFIER_VERSION_LABEL, self.classifier_version.as_str()),
            (DECISION_LABEL, self.decision.as_str()),
            (ANCHOR_MESSAGE_ID_LABEL, self.anchor_message_id.as_str()),
        ]);

        metadata = metadata
            .with_label(FORK_OFFSET_LABEL, self.anchor_offset.value().to_string())
            .with_label(DECIDED_AT_LABEL, self.decided_at.to_string());

        if let Some(score) = self.score {
            metadata = metadata.with_label(SCORE_LABEL, score.to_string());
        }
        if let Some(threshold) = self.threshold {
            metadata = metadata.with_label(THRESHOLD_LABEL, threshold.to_string());
        }
        if let Some(evidence_ref) = &self.evidence_ref {
            metadata = metadata.with_label(EVIDENCE_REF_LABEL, evidence_ref);
        }

        metadata
    }

    pub fn artifact(&self, descriptor: CommunicationArtifactDescriptor) -> ArtifactEnvelope {
        descriptor
            .into_envelope(CLASSIFIER_EVIDENCE_KIND)
            .with_label(ARTIFACT_ROLE_LABEL, CLASSIFIER_EVIDENCE_KIND)
            .with_label(DECISION_ID_LABEL, self.decision_id.as_str())
            .with_label(CLASSIFIER_ID_LABEL, self.classifier_id.as_str())
            .with_label(CLASSIFIER_VERSION_LABEL, self.classifier_version.as_str())
            .with_label(ANCHOR_MESSAGE_ID_LABEL, self.anchor_message_id.as_str())
            .with_label(FORK_OFFSET_LABEL, self.anchor_offset.value().to_string())
            .with_label(DECISION_LABEL, self.decision.as_str())
            .with_label(DECIDED_AT_LABEL, self.decided_at.to_string())
            .with_optional_label(SCORE_LABEL, self.score.map(|score| score.to_string()))
            .with_optional_label(
                THRESHOLD_LABEL,
                self.threshold.map(|threshold| threshold.to_string()),
            )
            .with_optional_label(EVIDENCE_REF_LABEL, self.evidence_ref.clone())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommunicationArtifactDescriptor {
    pub artifact_id: String,
    pub artifact_ref: String,
    pub content_type: String,
    pub byte_length: u64,
    pub digest: String,
    pub producer_id: String,
    pub created_at: i64,
    pub subject_ref: String,
}

impl CommunicationArtifactDescriptor {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        artifact_id: impl Into<String>,
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
            artifact_ref: non_empty("artifact_ref", artifact_ref)?,
            content_type: non_empty("content_type", content_type)?,
            byte_length,
            digest: non_empty("digest", digest)?,
            producer_id: non_empty("producer_id", producer_id)?,
            created_at,
            subject_ref: non_empty("subject_ref", subject_ref)?,
        })
    }

    fn into_envelope(self, artifact_kind: impl Into<String>) -> ArtifactEnvelope {
        ArtifactEnvelope::new(
            self.artifact_id,
            artifact_kind,
            self.artifact_ref,
            self.content_type,
            self.byte_length,
            self.digest,
            self.producer_id,
            self.created_at,
            self.subject_ref,
        )
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ThreadBacklinkArtifact {
    pub channel_id: String,
    pub actor_id: String,
    pub reason: String,
    pub thread_stream_id: String,
    pub anchor_message_id: String,
    pub backlink_kind: String,
}

impl ThreadBacklinkArtifact {
    pub fn new(
        channel_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
        thread_stream_id: impl Into<String>,
        anchor_message_id: impl Into<String>,
        backlink_kind: impl Into<String>,
    ) -> Result<Self> {
        Ok(Self {
            channel_id: non_empty("channel_id", channel_id)?,
            actor_id: non_empty("actor_id", actor_id)?,
            reason: non_empty("reason", reason)?,
            thread_stream_id: non_empty("thread_stream_id", thread_stream_id)?,
            anchor_message_id: non_empty("anchor_message_id", anchor_message_id)?,
            backlink_kind: non_empty("backlink_kind", backlink_kind)?,
        })
    }

    pub fn artifact(&self, descriptor: CommunicationArtifactDescriptor) -> ArtifactEnvelope {
        ArtifactEnvelope::backlink(
            descriptor.artifact_id,
            THREAD_BACKLINK_KIND,
            descriptor.artifact_ref,
            descriptor.content_type,
            descriptor.byte_length,
            descriptor.digest,
            descriptor.producer_id,
            descriptor.created_at,
            descriptor.subject_ref,
            self.backlink_kind.as_str(),
        )
        .with_communication_labels(
            THREAD_BACKLINK_KIND,
            &self.channel_id,
            &self.actor_id,
            descriptor_created_at_label(descriptor.created_at),
            &self.reason,
        )
        .with_label(THREAD_STREAM_ID_LABEL, self.thread_stream_id.as_str())
        .with_label(ANCHOR_MESSAGE_ID_LABEL, self.anchor_message_id.as_str())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ThreadSummaryArtifact {
    pub channel_id: String,
    pub actor_id: String,
    pub reason: String,
    pub thread_stream_id: String,
    pub summary_kind: String,
    pub summary_ref: String,
}

impl ThreadSummaryArtifact {
    pub fn new(
        channel_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
        thread_stream_id: impl Into<String>,
        summary_kind: impl Into<String>,
        summary_ref: impl Into<String>,
    ) -> Result<Self> {
        Ok(Self {
            channel_id: non_empty("channel_id", channel_id)?,
            actor_id: non_empty("actor_id", actor_id)?,
            reason: non_empty("reason", reason)?,
            thread_stream_id: non_empty("thread_stream_id", thread_stream_id)?,
            summary_kind: non_empty("summary_kind", summary_kind)?,
            summary_ref: non_empty("summary_ref", summary_ref)?,
        })
    }

    pub fn artifact(&self, descriptor: CommunicationArtifactDescriptor) -> ArtifactEnvelope {
        ArtifactEnvelope::summary(
            descriptor.artifact_id,
            THREAD_SUMMARY_KIND,
            descriptor.artifact_ref,
            descriptor.content_type,
            descriptor.byte_length,
            descriptor.digest,
            descriptor.producer_id,
            descriptor.created_at,
            descriptor.subject_ref,
            self.summary_kind.as_str(),
        )
        .with_communication_labels(
            THREAD_SUMMARY_KIND,
            &self.channel_id,
            &self.actor_id,
            descriptor_created_at_label(descriptor.created_at),
            &self.reason,
        )
        .with_label(THREAD_STREAM_ID_LABEL, self.thread_stream_id.as_str())
        .with_label("summary_ref", self.summary_ref.as_str())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HumanOverrideArtifact {
    pub override_id: String,
    pub override_kind: String,
    pub channel_id: String,
    pub thread_stream_id: String,
    pub anchor_message_id: String,
    pub actor_id: String,
    pub reason: String,
    pub created_at: i64,
    pub supersedes_ref: Option<String>,
}

impl HumanOverrideArtifact {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        override_id: impl Into<String>,
        override_kind: impl Into<String>,
        channel_id: impl Into<String>,
        thread_stream_id: impl Into<String>,
        anchor_message_id: impl Into<String>,
        actor_id: impl Into<String>,
        reason: impl Into<String>,
        created_at: i64,
    ) -> Result<Self> {
        Ok(Self {
            override_id: non_empty("override_id", override_id)?,
            override_kind: non_empty("override_kind", override_kind)?,
            channel_id: non_empty("channel_id", channel_id)?,
            thread_stream_id: non_empty("thread_stream_id", thread_stream_id)?,
            anchor_message_id: non_empty("anchor_message_id", anchor_message_id)?,
            actor_id: non_empty("actor_id", actor_id)?,
            reason: non_empty("reason", reason)?,
            created_at,
            supersedes_ref: None,
        })
    }

    pub fn with_supersedes_ref(mut self, supersedes_ref: impl Into<String>) -> Self {
        self.supersedes_ref = Some(supersedes_ref.into());
        self
    }

    pub fn artifact(&self, descriptor: CommunicationArtifactDescriptor) -> ArtifactEnvelope {
        descriptor
            .into_envelope(HUMAN_OVERRIDE_KIND)
            .with_label(ARTIFACT_ROLE_LABEL, HUMAN_OVERRIDE_KIND)
            .with_communication_labels(
                HUMAN_OVERRIDE_KIND,
                &self.channel_id,
                &self.actor_id,
                self.created_at.to_string(),
                &self.reason,
            )
            .with_label(OVERRIDE_ID_LABEL, self.override_id.as_str())
            .with_label(OVERRIDE_KIND_LABEL, self.override_kind.as_str())
            .with_label(THREAD_STREAM_ID_LABEL, self.thread_stream_id.as_str())
            .with_label(ANCHOR_MESSAGE_ID_LABEL, self.anchor_message_id.as_str())
            .with_optional_label(SUPERSEDES_REF_LABEL, self.supersedes_ref.clone())
    }
}

pub fn channel_root_metadata(
    channel_id: impl Into<String>,
    actor_id: impl Into<String>,
    reason: impl Into<String>,
) -> Result<LineageMetadata> {
    let channel_id = non_empty("channel_id", channel_id)?;
    let actor_id = non_empty("actor_id", actor_id)?;
    let reason = non_empty("reason", reason)?;
    Ok(
        LineageMetadata::new(Some(actor_id.clone()), Some(reason.clone())).with_labels([
            (COMMUNICATION_KIND_LABEL, CHANNEL_ROOT_KIND),
            (CHANNEL_ID_LABEL, channel_id.as_str()),
            (ACTOR_ID_LABEL, actor_id.as_str()),
            (REASON_LABEL, reason.as_str()),
        ]),
    )
}

pub fn payload_bytes<T>(payload: &T) -> Result<Vec<u8>>
where
    T: Serialize,
{
    serde_json::to_vec(payload).context("serialize communication payload")
}

fn thread_branch_metadata(
    channel_id: &str,
    thread_stream_id: &str,
    parent: &StreamPosition,
    anchor_message_id: &str,
    thread_kind: &str,
    actor_id: &str,
    reason: &str,
) -> LineageMetadata {
    LineageMetadata::new(Some(actor_id.to_owned()), Some(reason.to_owned()))
        .with_branch_kind("communication-thread")
        .with_anchor_ref(format!("message:{anchor_message_id}"))
        .with_labels([
            (COMMUNICATION_KIND_LABEL, THREAD_BRANCH_KIND),
            (CHANNEL_ID_LABEL, channel_id),
            (ACTOR_ID_LABEL, actor_id),
            (REASON_LABEL, reason),
            (THREAD_STREAM_ID_LABEL, thread_stream_id),
            (PARENT_STREAM_ID_LABEL, parent.stream_id.as_str()),
            (ANCHOR_MESSAGE_ID_LABEL, anchor_message_id),
            (THREAD_KIND_LABEL, thread_kind),
        ])
        .with_label(FORK_OFFSET_LABEL, parent.offset.value().to_string())
}

fn non_empty(name: &str, value: impl Into<String>) -> Result<String> {
    let value = value.into();
    ensure!(!value.trim().is_empty(), "{name} must not be empty");
    Ok(value)
}

fn descriptor_created_at_label(created_at: i64) -> String {
    created_at.to_string()
}

trait CommunicationEnvelopeExt {
    fn with_communication_labels(
        self,
        communication_kind: &str,
        channel_id: &str,
        actor_id: &str,
        created_at: String,
        reason: &str,
    ) -> Self;

    fn with_optional_label(self, key: &str, value: Option<String>) -> Self;
}

impl CommunicationEnvelopeExt for ArtifactEnvelope {
    fn with_communication_labels(
        self,
        communication_kind: &str,
        channel_id: &str,
        actor_id: &str,
        created_at: String,
        reason: &str,
    ) -> Self {
        self.with_labels([
            (COMMUNICATION_KIND_LABEL, communication_kind.to_owned()),
            (CHANNEL_ID_LABEL, channel_id.to_owned()),
            (ACTOR_ID_LABEL, actor_id.to_owned()),
            (CREATED_AT_LABEL, created_at),
            (REASON_LABEL, reason.to_owned()),
        ])
    }

    fn with_optional_label(self, key: &str, value: Option<String>) -> Self {
        if let Some(value) = value {
            self.with_label(key, value)
        } else {
            self
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::artifact::{BACKLINK_KIND_LABEL, SUMMARY_KIND_LABEL};
    use crate::engine::{LocalEngine, LocalEngineConfig};
    use crate::kernel::{Offset, StreamDescriptor, StreamLineage};
    use crate::membership::NodeId;
    use crate::server::{RemoteClient, ServerConfig, ServerHandle};
    use serde_json::Value;
    use tempfile::tempdir;

    fn stream_id(value: &str) -> StreamId {
        StreamId::new(value).expect("stream id")
    }

    fn artifact_descriptor(artifact_id: &str) -> CommunicationArtifactDescriptor {
        CommunicationArtifactDescriptor::new(
            artifact_id,
            format!("artifacts/eng/{artifact_id}.json"),
            "application/json",
            128,
            format!("sha256:{artifact_id}"),
            "system.communication",
            1_774_200_000,
            "stream:eng.thread.1042",
        )
        .expect("artifact descriptor")
    }

    #[test]
    fn typed_builders_cover_communication_contract_shapes() {
        let root_metadata =
            channel_root_metadata("eng", "system.channel", "channel-created").expect("metadata");
        assert_eq!(
            root_metadata.label(COMMUNICATION_KIND_LABEL),
            Some(CHANNEL_ROOT_KIND)
        );
        assert_eq!(root_metadata.label(CHANNEL_ID_LABEL), Some("eng"));
        assert_eq!(root_metadata.actor.as_deref(), Some("system.channel"));

        let message = ChannelMessage::new(
            "eng",
            "msg-1042",
            "human.alex",
            "alex",
            "inline:split deployment and model plans",
            "user-post",
            1_774_200_001,
        )
        .expect("channel message")
        .with_label("client", "desktop");
        let message_json: Value =
            serde_json::from_slice(&message.payload_bytes().expect("payload bytes"))
                .expect("message json");
        assert_eq!(message_json["type"], "message.posted");
        assert_eq!(message_json["communication_kind"], CHANNEL_MESSAGE_KIND);
        assert_eq!(message_json["message_id"], "msg-1042");
        assert_eq!(message_json["labels"]["client"], "desktop");

        let parent = StreamPosition::new(stream_id("eng"), Offset::new(91));
        let branch = ThreadBranch::manual(
            stream_id("eng.thread.1042"),
            parent.clone(),
            "eng",
            "msg-1042",
            "human.alex",
            "manual-thread-split",
        )
        .expect("thread branch");
        assert_eq!(branch.parent, parent);
        assert_eq!(branch.metadata.branch_kind(), Some("communication-thread"));
        assert_eq!(branch.metadata.anchor_ref(), Some("message:msg-1042"));
        assert_eq!(branch.metadata.label(THREAD_KIND_LABEL), Some("manual"));
        assert_eq!(branch.metadata.label(FORK_OFFSET_LABEL), Some("91"));

        let classifier = ClassifierEvidence::new(
            "thd-0091",
            "thread-boundary-v1",
            "2026-03-12",
            "msg-1042",
            Offset::new(91),
            "open-thread",
            1_774_200_002,
        )
        .expect("classifier evidence")
        .with_score(0.93, 0.81)
        .with_evidence_ref("artifacts/classifier/thd-0091");
        let classifier_branch = ThreadBranch::classifier(
            stream_id("eng.thread.classifier.1042"),
            branch.parent.clone(),
            "eng",
            &classifier,
        )
        .expect("classifier branch");
        assert_eq!(
            classifier_branch.metadata.label(DECISION_ID_LABEL),
            Some("thd-0091")
        );
        assert_eq!(classifier_branch.metadata.label(SCORE_LABEL), Some("0.93"));

        let reply = ThreadReply::new(
            "eng",
            "msg-1042-r1",
            "eng.thread.1042",
            "human.sasha",
            "sasha",
            "inline:deployment details stay here",
            "thread-reply",
            1_774_200_003,
        )
        .expect("thread reply");
        let reply_json: Value =
            serde_json::from_slice(&reply.payload_bytes().expect("payload bytes"))
                .expect("reply json");
        assert_eq!(reply_json["type"], "thread.reply");
        assert_eq!(reply_json["communication_kind"], THREAD_REPLY_KIND);
        assert_eq!(reply_json["thread_stream_id"], "eng.thread.1042");

        let backlink = ThreadBacklinkArtifact::new(
            "eng",
            "system.thread-index",
            "thread-visible-in-root",
            "eng.thread.1042",
            "msg-1042",
            "mention",
        )
        .expect("backlink")
        .artifact(artifact_descriptor("backlink-1042"));
        assert_eq!(backlink.role(), Some("backlink"));
        assert_eq!(backlink.label(BACKLINK_KIND_LABEL), Some("mention"));
        assert_eq!(
            backlink.label(COMMUNICATION_KIND_LABEL),
            Some(THREAD_BACKLINK_KIND)
        );
        assert_eq!(
            backlink.label(THREAD_STREAM_ID_LABEL),
            Some("eng.thread.1042")
        );

        let summary = ThreadSummaryArtifact::new(
            "eng",
            "agent.summary",
            "summary-published",
            "eng.thread.1042",
            "model",
            "inline:deployment plan only",
        )
        .expect("summary")
        .artifact(artifact_descriptor("summary-1042"));
        assert_eq!(summary.role(), Some("summary"));
        assert_eq!(summary.label(SUMMARY_KIND_LABEL), Some("model"));
        assert_eq!(
            summary.label("summary_ref"),
            Some("inline:deployment plan only")
        );

        let classifier_artifact = classifier.artifact(artifact_descriptor("classifier-1042"));
        assert_eq!(
            classifier_artifact.label(ARTIFACT_ROLE_LABEL),
            Some(CLASSIFIER_EVIDENCE_KIND)
        );
        assert_eq!(
            classifier_artifact.label(EVIDENCE_REF_LABEL),
            Some("artifacts/classifier/thd-0091")
        );

        let override_artifact = HumanOverrideArtifact::new(
            "override-1",
            "confirm-thread",
            "eng",
            "eng.thread.1042",
            "msg-1042",
            "human.moderator",
            "confirm classifier split",
            1_774_200_004,
        )
        .expect("override")
        .with_supersedes_ref("classifier:thd-0091")
        .artifact(artifact_descriptor("override-1042"));
        assert_eq!(
            override_artifact.label(ARTIFACT_ROLE_LABEL),
            Some(HUMAN_OVERRIDE_KIND)
        );
        assert_eq!(
            override_artifact.label(OVERRIDE_KIND_LABEL),
            Some("confirm-thread")
        );
        assert_eq!(
            override_artifact.label(SUPERSEDES_REF_LABEL),
            Some("classifier:thd-0091")
        );
    }

    #[test]
    fn communication_helpers_work_through_embedded_and_hosted_apis() {
        let channel_stream = stream_id("eng");
        let thread_stream = stream_id("eng.thread.1042");
        let message = ChannelMessage::new(
            "eng",
            "msg-1042",
            "human.alex",
            "alex",
            "inline:split deployment and model plans",
            "user-post",
            1_774_200_001,
        )
        .expect("channel message");
        let reply = ThreadReply::new(
            "eng",
            "msg-1042-r1",
            thread_stream.as_str(),
            "human.sasha",
            "sasha",
            "inline:deployment details stay here",
            "thread-reply",
            1_774_200_002,
        )
        .expect("thread reply");

        let local_root = tempdir().expect("local temp dir");
        let engine = LocalEngine::open(LocalEngineConfig::new(
            local_root.path(),
            NodeId::new("local-node"),
        ))
        .expect("open local engine");
        engine
            .create_stream(StreamDescriptor::root(
                channel_stream.clone(),
                channel_root_metadata("eng", "system.channel", "channel-created")
                    .expect("root metadata"),
            ))
            .expect("create local channel");
        let local_append = engine
            .append(
                &channel_stream,
                message.payload_bytes().expect("message bytes"),
            )
            .expect("append local message");
        let local_branch = ThreadBranch::manual(
            thread_stream.clone(),
            local_append.position().clone(),
            "eng",
            "msg-1042",
            "human.alex",
            "manual-thread-split",
        )
        .expect("local branch input");
        engine
            .create_branch(
                local_branch.thread_stream_id.clone(),
                local_branch.parent.clone(),
                local_branch.metadata.clone(),
            )
            .expect("create local branch");
        engine
            .append(&thread_stream, reply.payload_bytes().expect("reply bytes"))
            .expect("append local reply");
        let local_replay = engine.replay(&thread_stream).expect("replay local thread");
        assert_eq!(local_replay.len(), 2);
        let local_reply: ThreadReply =
            serde_json::from_slice(local_replay[1].payload()).expect("decode local reply payload");
        assert_eq!(local_reply.thread_stream_id, "eng.thread.1042");

        let hosted_root = tempdir().expect("hosted temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(hosted_root.path(), NodeId::new("hosted-node")),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind hosted server");
        let client = RemoteClient::new(server.local_addr());
        client
            .create_root(
                &channel_stream,
                channel_root_metadata("eng", "system.channel", "channel-created")
                    .expect("root metadata"),
            )
            .expect("create hosted channel");
        let hosted_append = client
            .append(
                &channel_stream,
                message.payload_bytes().expect("message bytes"),
            )
            .expect("append hosted message");
        let hosted_branch = ThreadBranch::manual(
            thread_stream.clone(),
            hosted_append.body().position().clone(),
            "eng",
            "msg-1042",
            "human.alex",
            "manual-thread-split",
        )
        .expect("hosted branch input");
        client
            .create_branch(
                &hosted_branch.thread_stream_id,
                hosted_branch.parent.clone(),
                hosted_branch.metadata.clone(),
            )
            .expect("create hosted branch");
        client
            .append(&thread_stream, reply.payload_bytes().expect("reply bytes"))
            .expect("append hosted reply");
        let hosted_replay = client.read(&thread_stream).expect("read hosted thread");
        assert_eq!(hosted_replay.body().records().len(), 2);
        let hosted_reply: ThreadReply =
            serde_json::from_slice(hosted_replay.body().records()[1].payload())
                .expect("decode hosted reply payload");
        assert_eq!(hosted_reply.message_id, "msg-1042-r1");

        let lineage = client.inspect_lineage(&thread_stream).expect("lineage");
        match &lineage.body().descriptor().lineage {
            StreamLineage::Branch { branch_point } => {
                assert_eq!(
                    branch_point.metadata.label(COMMUNICATION_KIND_LABEL),
                    Some(THREAD_BRANCH_KIND)
                );
                assert_eq!(branch_point.metadata.label(CHANNEL_ID_LABEL), Some("eng"));
                assert_eq!(
                    branch_point.metadata.label(ANCHOR_MESSAGE_ID_LABEL),
                    Some("msg-1042")
                );
            }
            other => panic!("expected hosted branch lineage, got {other:?}"),
        }

        server.shutdown().expect("shutdown hosted server");
    }

    #[test]
    fn communication_helpers_reject_missing_required_fields_without_policy_types() {
        let err = ChannelMessage::new(
            "eng",
            "",
            "human.alex",
            "alex",
            "inline:body",
            "user-post",
            1_774_200_001,
        )
        .expect_err("blank message id should be rejected");
        assert!(err.to_string().contains("message_id must not be empty"));

        let metadata =
            channel_root_metadata("eng", "system.channel", "channel-created").expect("metadata");
        assert!(metadata.label("account_id").is_none());
        assert!(metadata.label("moderation_policy").is_none());
        assert!(metadata.label("authorization_scope").is_none());
    }
}
