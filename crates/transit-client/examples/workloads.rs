use std::process::ExitCode;

use anyhow::{Context, Result, ensure};
use tempfile::tempdir;
use transit_client::workloads::{ai, communication};
use transit_client::{MergePolicyKind, Offset, StreamId, TransitClient};
use transit_core::engine::{LocalEngine, LocalEngineConfig};
use transit_core::membership::NodeId;
use transit_core::server::{ServerConfig, ServerHandle};

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("workload helper example failed: {error:#}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<()> {
    let embedded_root = tempdir().context("create embedded workload tempdir")?;
    run_embedded_smoke(embedded_root.path())?;

    let hosted_root = tempdir().context("create hosted workload tempdir")?;
    let server = ServerHandle::bind(ServerConfig::new(
        LocalEngineConfig::new(hosted_root.path(), NodeId::new("workload-example-node"))
            .with_segment_max_records(8)
            .context("configure hosted workload server")?,
        "127.0.0.1:0".parse().expect("static listen addr parses"),
    ))
    .context("bind hosted workload server")?;

    let result = run_hosted_workloads(&server);
    let shutdown = server.shutdown().context("shutdown hosted workload server");
    result.and(shutdown.map(|_| ()))
}

fn run_embedded_smoke(root: &std::path::Path) -> Result<()> {
    let engine = LocalEngine::open(LocalEngineConfig::new(
        root,
        NodeId::new("embedded-workload-node"),
    ))
    .context("open embedded workload engine")?;
    let stream_id = StreamId::new("example.embedded.ai")?;
    let event = ai::ToolCallEvent::new(
        "task-embedded",
        "agent.local",
        "embedded-smoke",
        "search",
        "tc-embedded",
        "request",
        "success",
        1_774_400_000,
    )?;

    engine
        .create_stream(transit_core::kernel::StreamDescriptor::root(
            stream_id.clone(),
            ai::task_root_metadata(
                "task-embedded",
                "agent.local",
                "embedded-root",
                1_774_400_000,
            )?,
        ))
        .context("create embedded ai stream")?;
    engine
        .append(&stream_id, event.payload_bytes()?)
        .context("append embedded helper payload")?;

    let replay = engine
        .replay(&stream_id)
        .context("replay embedded stream")?;
    ensure!(
        replay.len() == 1,
        "embedded replay should contain one event"
    );
    println!("embedded helper payload appended through LocalEngine");
    Ok(())
}

fn run_hosted_workloads(server: &ServerHandle) -> Result<()> {
    let client = TransitClient::new(server.local_addr());
    run_hosted_ai_trace(&client)?;
    run_hosted_threaded_channel(&client)?;
    Ok(())
}

fn run_hosted_ai_trace(client: &TransitClient) -> Result<()> {
    let task_root = StreamId::new("example.ai.task")?;
    let retry_stream = StreamId::new("example.ai.task.retry")?;
    let critique_stream = StreamId::new("example.ai.task.critique")?;
    let merge_stream = StreamId::new("example.ai.task.merge")?;

    client
        .create_root(
            &task_root,
            ai::task_root_metadata("task-0142", "human.alex", "initial-request", 1_774_400_001)?,
        )
        .context("create hosted ai task root")?;

    let tool_event = ai::ToolCallEvent::new(
        "task-0142",
        "agent.planner.v1",
        "gather-context",
        "search",
        "tc-0091",
        "request",
        "success",
        1_774_400_002,
    )?;
    let root_append = client
        .append(&task_root, tool_event.payload_bytes()?)
        .context("append hosted ai tool event")?;

    let retry = ai::TraceBranch::retry(
        retry_stream.clone(),
        root_append.body().position().clone(),
        "task-0142",
        "agent.runner",
        "retry-after-timeout",
    )?;
    client
        .create_branch(
            &retry.branch_stream_id,
            retry.parent.clone(),
            retry.metadata.clone(),
        )
        .context("create hosted retry branch")?;
    let retry_decision = ai::EvaluatorDecision::new(
        "task-0142",
        "judge.v1",
        "rank-retry",
        "judge.v1",
        "stream:example.ai.task.retry",
        "selected",
        1_774_400_003,
    )?;
    let retry_append = client
        .append(&retry_stream, retry_decision.payload_bytes()?)
        .context("append hosted retry decision")?;

    let critique = ai::TraceBranch::critique(
        critique_stream.clone(),
        retry_append.body().position().clone(),
        "task-0142",
        "agent.critic",
        "critique-pass",
    )?;
    client
        .create_branch(
            &critique.branch_stream_id,
            critique.parent.clone(),
            critique.metadata.clone(),
        )
        .context("create hosted critique branch")?;
    let critique_checkpoint = ai::CompletionCheckpoint::new(
        "task-0142",
        "agent.critic",
        "critique-complete",
        "cp-critique",
        "intermediate",
        "success",
        1_774_400_004,
    )?;
    let critique_append = client
        .append(&critique_stream, critique_checkpoint.payload_bytes()?)
        .context("append hosted critique checkpoint")?;

    let trace_merge = ai::TraceMerge::new(
        merge_stream.clone(),
        vec![
            retry_append.body().position().clone(),
            critique_append.body().position().clone(),
        ],
        Some(root_append.body().position().clone()),
        "task-0142",
        "judge.v1",
        "merge-winning-paths",
        MergePolicyKind::Recursive,
        "select retry with critique notes",
    )?;
    client
        .create_merge(&trace_merge.merge_stream_id, trace_merge.merge.clone())
        .context("create hosted ai merge stream")?;

    let merge_artifact = ai::MergeArtifact::new(
        "task-0142",
        "judge.v1",
        "merge-winning-paths",
        trace_merge.merge.parents.clone(),
        "recursive",
        "select retry with critique notes",
    )?
    .artifact(ai::AiArtifactDescriptor::new(
        "merge-artifact-0142",
        "merge-artifact",
        "artifacts/task-0142/merge.json",
        "application/json",
        256,
        "sha256:merge0142",
        "judge.v1",
        1_774_400_005,
        "stream:example.ai.task.merge",
    )?);
    client
        .append(&merge_stream, serde_json::to_vec(&merge_artifact)?)
        .context("append hosted merge artifact envelope")?;

    let final_checkpoint = ai::CompletionCheckpoint::new(
        "task-0142",
        "agent.finalizer",
        "final-answer",
        "cp-final",
        "final",
        "success",
        1_774_400_006,
    )?;
    client
        .append(&merge_stream, final_checkpoint.payload_bytes()?)
        .context("append hosted final checkpoint")?;

    let merge_lineage = client
        .lineage(&merge_stream)
        .context("inspect hosted ai merge lineage")?;
    ensure!(
        merge_lineage.body().descriptor().parent_stream_ids().len() == 2,
        "hosted ai merge should preserve two parent heads"
    );
    println!("hosted ai trace helper flow created root, branches, merge artifact, checkpoint");
    Ok(())
}

fn run_hosted_threaded_channel(client: &TransitClient) -> Result<()> {
    let channel_stream = StreamId::new("example.channel.eng")?;
    let thread_stream = StreamId::new("example.channel.eng.thread.1042")?;

    client
        .create_root(
            &channel_stream,
            communication::channel_root_metadata("eng", "system.channel", "channel-created")?,
        )
        .context("create hosted communication channel")?;

    let message = communication::ChannelMessage::new(
        "eng",
        "msg-1042",
        "human.alex",
        "alex",
        "inline:Split deployment and model planning.",
        "user-post",
        1_774_400_010,
    )?;
    let message_append = client
        .append(&channel_stream, message.payload_bytes()?)
        .context("append hosted channel message")?;

    let thread = communication::ThreadBranch::manual(
        thread_stream.clone(),
        message_append.body().position().clone(),
        "eng",
        "msg-1042",
        "human.alex",
        "manual-thread-split",
    )?;
    client
        .create_branch(
            &thread.thread_stream_id,
            thread.parent.clone(),
            thread.metadata.clone(),
        )
        .context("create hosted thread branch")?;

    let reply = communication::ThreadReply::new(
        "eng",
        "msg-1042-r1",
        thread_stream.as_str(),
        "human.sasha",
        "sasha",
        "inline:Deployment details stay in this thread.",
        "thread-reply",
        1_774_400_011,
    )?;
    client
        .append(&thread_stream, reply.payload_bytes()?)
        .context("append hosted thread reply")?;

    let backlink = communication::ThreadBacklinkArtifact::new(
        "eng",
        "system.thread-index",
        "thread-visible-in-root",
        thread_stream.as_str(),
        "msg-1042",
        "mention",
    )?
    .artifact(communication_artifact(
        "backlink-1042",
        "artifacts/eng/backlink-1042.json",
        "stream:example.channel.eng.thread.1042",
    )?);
    client
        .append(&channel_stream, serde_json::to_vec(&backlink)?)
        .context("append hosted thread backlink artifact")?;

    let summary = communication::ThreadSummaryArtifact::new(
        "eng",
        "agent.summary",
        "summary-published",
        thread_stream.as_str(),
        "model",
        "inline:Deployment plan was split out and resolved.",
    )?
    .artifact(communication_artifact(
        "summary-1042",
        "artifacts/eng/summary-1042.json",
        "stream:example.channel.eng.thread.1042",
    )?);
    client
        .append(&channel_stream, serde_json::to_vec(&summary)?)
        .context("append hosted thread summary artifact")?;

    let override_artifact = communication::HumanOverrideArtifact::new(
        "override-1042",
        "confirm-thread",
        "eng",
        thread_stream.as_str(),
        "msg-1042",
        "human.moderator",
        "confirm manual thread split",
        1_774_400_012,
    )?
    .artifact(communication_artifact(
        "override-1042",
        "artifacts/eng/override-1042.json",
        "stream:example.channel.eng.thread.1042",
    )?);
    client
        .append(&channel_stream, serde_json::to_vec(&override_artifact)?)
        .context("append hosted human override artifact")?;

    let channel_replay = client
        .read_page(&channel_stream, Offset::new(0), 16)
        .context("read hosted channel page")?;
    ensure!(
        channel_replay.body().records().len() == 4,
        "hosted channel should contain message plus backlink, summary, and override"
    );
    println!(
        "hosted communication helper flow created channel, thread, backlink, summary, override"
    );
    Ok(())
}

fn communication_artifact(
    artifact_id: &str,
    artifact_ref: &str,
    subject_ref: &str,
) -> Result<communication::CommunicationArtifactDescriptor> {
    communication::CommunicationArtifactDescriptor::new(
        artifact_id,
        artifact_ref,
        "application/json",
        128,
        format!("sha256:{artifact_id}"),
        "system.communication",
        1_774_400_020,
        subject_ref,
    )
}
