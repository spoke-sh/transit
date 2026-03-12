use anyhow::{Context, Result};
use clap::{Args, Parser, Subcommand};
use serde::Serialize;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use transit_core::bootstrap::{MissionStatus, collect_mission_status};
use transit_core::engine::{LocalEngine, LocalEngineConfig, LocalRecord, LocalRecoveryOutcome};
use transit_core::kernel::{
    LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset, StreamDescriptor, StreamId,
    StreamLineage, StreamPosition,
};
use transit_core::object_store_support::{ObjectStoreProbeResult, probe_local_filesystem_store};

#[derive(Debug, Parser)]
#[command(name = "transit")]
#[command(about = "Object-storage-native append-only log bootstrap")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Debug, Subcommand)]
enum Commands {
    /// Human-facing mission verification surfaces.
    Mission(MissionArgs),
    /// Probe configured object-store support.
    ObjectStore(ObjectStoreArgs),
}

#[derive(Debug, Args)]
struct MissionArgs {
    #[command(subcommand)]
    command: MissionCommands,
}

#[derive(Debug, Subcommand)]
enum MissionCommands {
    /// Show a human-readable bootstrap status summary.
    Status(MissionStatusArgs),
    /// Exercise append, replay, lineage, and crash recovery in one local proof.
    LocalEngineProof(LocalEngineProofArgs),
}

#[derive(Debug, Args)]
struct MissionStatusArgs {
    /// Repository root used to verify required bootstrap artifacts.
    #[arg(long = "repo-root", default_value = ".")]
    repo_root: PathBuf,
    /// Render mission status as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct LocalEngineProofArgs {
    /// Filesystem root used for the local durable-engine proof.
    #[arg(long)]
    root: PathBuf,
    /// Render proof output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ObjectStoreArgs {
    #[command(subcommand)]
    command: ObjectStoreCommands,
}

#[derive(Debug, Subcommand)]
enum ObjectStoreCommands {
    /// Write, read, and delete a probe object using the filesystem backend.
    Probe(ObjectStoreProbeArgs),
}

#[derive(Debug, Args)]
struct ObjectStoreProbeArgs {
    /// Filesystem root used for the local object-store probe.
    #[arg(long)]
    root: PathBuf,
    /// Render probe output as JSON.
    #[arg(long)]
    json: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Mission(args) => match args.command {
            MissionCommands::Status(args) => {
                render_mission_status(collect_mission_status(args.repo_root), args.json)?
            }
            MissionCommands::LocalEngineProof(args) => {
                render_local_engine_proof(run_local_engine_proof(args.root)?, args.json)?
            }
        },
        Commands::ObjectStore(args) => match args.command {
            ObjectStoreCommands::Probe(args) => render_object_store_probe(
                probe_local_filesystem_store(args.root).await?,
                args.json,
            )?,
        },
    }

    Ok(())
}

fn render_mission_status(status: MissionStatus, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&status)?);
        return Ok(());
    }

    println!("transit mission status");
    println!("summary: {}", status.summary());
    println!("version: {}", status.version);
    println!(
        "docs: {}/{} present",
        status.docs_present(),
        status.docs.len()
    );
    println!(
        "workspace files: {}/{} present",
        status.workspace_files_present(),
        status.workspace_files.len()
    );
    println!(
        "kernel files: {}/{} present",
        status.kernel_files_present(),
        status.kernel_files.len()
    );
    if status.kernel_files.iter().all(|artifact| artifact.present) {
        println!("kernel slice: durable local engine + lineage replay");
    } else {
        println!("kernel slice: incomplete");
    }
    println!("object store: {}", status.object_store_backend);
    println!("verification path: {}", status.verification_recipe);

    let missing = status.missing_paths();
    if missing.is_empty() {
        println!("missing: none");
    } else {
        println!("missing:");
        for path in missing {
            println!("  - {path}");
        }
    }

    Ok(())
}

#[derive(Debug, Serialize)]
struct StreamProofSummary {
    stream_id: String,
    record_count: usize,
    head_offset: Option<u64>,
}

#[derive(Debug, Serialize)]
struct LocalEngineProofResult {
    data_root: PathBuf,
    durability: String,
    root_stream: StreamProofSummary,
    branch_stream: StreamProofSummary,
    merge_stream: StreamProofSummary,
    branch_parent: String,
    merge_parents: Vec<String>,
    merge_base: Option<String>,
    replay_before_recovery_failed: bool,
    recovery: RecoveryProofSummary,
}

#[derive(Debug, Serialize)]
struct RecoveryProofSummary {
    target_stream: String,
    retained_active_records: u64,
    truncated_bytes: u64,
    committed_next_offset: u64,
    manifest_generation: u64,
}

fn run_local_engine_proof(root: PathBuf) -> Result<LocalEngineProofResult> {
    if root.exists() {
        fs::remove_dir_all(&root)
            .with_context(|| format!("remove existing proof root {}", root.display()))?;
    }
    fs::create_dir_all(&root).with_context(|| format!("create proof root {}", root.display()))?;

    let engine = LocalEngine::open(LocalEngineConfig::new(&root).with_segment_max_records(2)?)
        .context("open local engine proof root")?;

    let root_stream = StreamId::new("mission.root")?;
    let branch_stream = StreamId::new("mission.branch")?;
    let merge_stream = StreamId::new("mission.merge")?;

    engine.create_stream(StreamDescriptor::root(
        root_stream.clone(),
        LineageMetadata::new(Some("mission".into()), Some("local-engine-proof".into())),
    ))?;
    engine.append(&root_stream, b"root-0")?;
    engine.append(&root_stream, b"root-1")?;
    engine.append(&root_stream, b"root-2")?;

    let branch_parent = StreamPosition::new(root_stream.clone(), Offset::new(1));
    engine.create_branch(
        branch_stream.clone(),
        branch_parent.clone(),
        LineageMetadata::new(
            Some("mission.classifier".into()),
            Some("thread-split".into()),
        ),
    )?;
    engine.append(&branch_stream, b"branch-2")?;

    let merge_spec = MergeSpec::new(
        vec![
            StreamPosition::new(root_stream.clone(), Offset::new(2)),
            StreamPosition::new(branch_stream.clone(), Offset::new(2)),
        ],
        Some(StreamPosition::new(root_stream.clone(), Offset::new(1))),
        MergePolicy::new(MergePolicyKind::Recursive)
            .with_metadata("policy_reason", "mission-proof"),
        LineageMetadata::new(Some("mission.judge".into()), Some("merge-branch".into())),
    )?;
    engine.create_merge(merge_stream.clone(), merge_spec.clone())?;
    engine.append(&merge_stream, b"merge-2")?;

    inject_trailing_uncommitted_bytes(&root, merge_stream.as_str())?;
    let replay_before_recovery_failed = engine.replay(&merge_stream).is_err();
    let recovery = engine.recover_stream(&merge_stream)?;

    let root_records = engine.replay(&root_stream)?;
    let branch_records = engine.replay(&branch_stream)?;
    let merge_records = engine.replay(&merge_stream)?;
    let merge_descriptor = engine.stream_descriptor(&merge_stream)?;

    Ok(LocalEngineProofResult {
        data_root: root,
        durability: recovery.durability().as_str().to_owned(),
        root_stream: summarize_stream(&root_stream, &root_records),
        branch_stream: summarize_stream(&branch_stream, &branch_records),
        merge_stream: summarize_stream(&merge_stream, &merge_records),
        branch_parent: render_position(branch_parent),
        merge_parents: match merge_descriptor.lineage {
            StreamLineage::Merge { merge } => merge
                .parents
                .into_iter()
                .map(render_position)
                .collect::<Vec<_>>(),
            _ => unreachable!("mission proof created a merge stream"),
        },
        merge_base: match merge_spec.merge_base {
            Some(position) => Some(render_position(position)),
            None => None,
        },
        replay_before_recovery_failed,
        recovery: summarize_recovery(&merge_stream, recovery),
    })
}

fn summarize_stream(stream_id: &StreamId, records: &[LocalRecord]) -> StreamProofSummary {
    StreamProofSummary {
        stream_id: stream_id.as_str().to_owned(),
        record_count: records.len(),
        head_offset: records
            .last()
            .map(|record| record.position().offset.value()),
    }
}

fn summarize_recovery(stream_id: &StreamId, outcome: LocalRecoveryOutcome) -> RecoveryProofSummary {
    RecoveryProofSummary {
        target_stream: stream_id.as_str().to_owned(),
        retained_active_records: outcome.retained_active_records(),
        truncated_bytes: outcome.truncated_bytes(),
        committed_next_offset: outcome.committed_next_offset().value(),
        manifest_generation: outcome.manifest_generation(),
    }
}

fn render_position(position: StreamPosition) -> String {
    format!(
        "{}@{}",
        position.stream_id.as_str(),
        position.offset.value()
    )
}

fn inject_trailing_uncommitted_bytes(root: &Path, stream_id: &str) -> Result<()> {
    let active_path = root.join("streams").join(stream_id).join("active.segment");
    let mut file = OpenOptions::new()
        .append(true)
        .open(&active_path)
        .with_context(|| format!("open active segment {}", active_path.display()))?;
    file.write_all(b"{\"offset\":3,\"payload\":[116,114,97,105,108]}\npartial")
        .with_context(|| format!("append uncommitted bytes to {}", active_path.display()))?;
    file.sync_all()
        .with_context(|| format!("sync active segment {}", active_path.display()))?;
    Ok(())
}

fn render_local_engine_proof(result: LocalEngineProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit local-engine proof");
    println!("root: {}", result.data_root.display());
    println!("durability: {}", result.durability);
    println!(
        "root replay: {} records, head {:?}",
        result.root_stream.record_count, result.root_stream.head_offset
    );
    println!(
        "branch replay: {} records, head {:?}",
        result.branch_stream.record_count, result.branch_stream.head_offset
    );
    println!(
        "merge replay: {} records, head {:?}",
        result.merge_stream.record_count, result.merge_stream.head_offset
    );
    println!("branch parent: {}", result.branch_parent);
    println!("merge parents:");
    for parent in &result.merge_parents {
        println!("  - {parent}");
    }
    if let Some(merge_base) = &result.merge_base {
        println!("merge base: {merge_base}");
    }
    println!(
        "replay before recovery: {}",
        if result.replay_before_recovery_failed {
            "failed as expected"
        } else {
            "unexpectedly succeeded"
        }
    );
    println!("recovery target: {}", result.recovery.target_stream);
    println!(
        "recovery retained active records: {}",
        result.recovery.retained_active_records
    );
    println!(
        "recovery truncated bytes: {}",
        result.recovery.truncated_bytes
    );
    println!(
        "recovery committed next offset: {}",
        result.recovery.committed_next_offset
    );
    println!(
        "recovery manifest generation: {}",
        result.recovery.manifest_generation
    );

    Ok(())
}

fn render_object_store_probe(result: ObjectStoreProbeResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit object-store probe");
    println!("backend: {}", result.backend);
    println!("root: {}", result.root.display());
    println!("object: {}", result.object_path);
    println!("bytes written: {}", result.bytes_written);
    println!(
        "round trip: {}",
        if result.round_trip_ok { "ok" } else { "failed" }
    );
    println!(
        "cleanup: {}",
        if result.cleanup_ok { "ok" } else { "failed" }
    );

    Ok(())
}
