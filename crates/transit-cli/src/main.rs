use anyhow::{Context, Result};
use clap::{Args, Parser, Subcommand};
use object_store::local::LocalFileSystem;
use serde::Serialize;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::time::Duration;
use transit_core::bootstrap::{MissionStatus, collect_mission_status};
use transit_core::engine::{LocalEngine, LocalEngineConfig, LocalRecord, LocalRecoveryOutcome};
use transit_core::kernel::{
    LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset, StreamDescriptor, StreamId,
    StreamLineage, StreamPosition,
};
use transit_core::object_store_support::{ObjectStoreProbeResult, probe_local_filesystem_store};
use transit_core::server::{
    RemoteClient, ServerConfig, ServerHandle, ServerShutdownOutcome, TailSessionId,
};

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
    /// Run the shared-engine server daemon.
    Server(ServerArgs),
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
    /// Exercise publication and cold restore through the shared local engine.
    TieredEngineProof(LocalEngineProofArgs),
    /// Exercise the networked single-node server and its transport boundary end to end.
    NetworkedServerProof(LocalEngineProofArgs),
    /// Explicitly verify the cryptographic integrity of local history.
    VerifyLineage(VerifyLineageArgs),
    /// Create a verifiable checkpoint for a stream head.
    Checkpoint(CheckpointArgs),
    /// Verify an existing lineage checkpoint.
    VerifyCheckpoint(VerifyCheckpointArgs),
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
struct VerifyLineageArgs {
    /// Filesystem root used for the shared local engine.
    #[arg(long)]
    root: PathBuf,
    /// Stream identifier to verify.
    #[arg(long = "stream-id")]
    stream_id: String,
    /// Render verification output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct CheckpointArgs {
    /// Filesystem root used for the shared local engine.
    #[arg(long)]
    root: PathBuf,
    /// Stream identifier to checkpoint.
    #[arg(long = "stream-id")]
    stream_id: String,
    /// Checkpoint kind (e.g., "handoff", "snapshot").
    #[arg(long, default_value = "handoff")]
    kind: String,
    /// Render checkpoint as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct VerifyCheckpointArgs {
    /// Filesystem root used for the shared local engine.
    #[arg(long)]
    root: PathBuf,
    /// Path to the JSON checkpoint file to verify.
    #[arg(long)]
    checkpoint_path: PathBuf,
    /// Render verification result as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ObjectStoreArgs {
    #[command(subcommand)]
    command: ObjectStoreCommands,
}

#[derive(Debug, Args)]
struct ServerArgs {
    #[command(subcommand)]
    command: ServerCommands,
}

#[derive(Debug, Subcommand)]
enum ServerCommands {
    /// Boot a single-node daemon around the shared local engine.
    Run(ServerRunArgs),
    /// Create a root stream through the remote server API.
    CreateRoot(ServerCreateRootArgs),
    /// Append a record through the remote server API.
    Append(ServerAppendArgs),
    /// Read the full replay for a stream through the remote server API.
    Read(ServerReadArgs),
    /// Open a logical remote tail session with explicit credit.
    TailOpen(ServerTailOpenArgs),
    /// Poll an existing logical remote tail session.
    TailPoll(ServerTailPollArgs),
    /// Cancel an existing logical remote tail session.
    TailCancel(ServerTailCancelArgs),
    /// Create a branch through the remote server API.
    Branch(ServerBranchArgs),
    /// Create a merge through the remote server API.
    Merge(ServerMergeArgs),
    /// Inspect lineage through the remote server API.
    Lineage(ServerLineageArgs),
}

#[derive(Debug, Args)]
struct ServerRunArgs {
    /// Filesystem root used for the shared local engine.
    #[arg(long)]
    root: PathBuf,
    /// Listen address for the first server daemon.
    #[arg(long = "listen-addr", default_value = "127.0.0.1:7171")]
    listen_addr: SocketAddr,
    /// Run for a bounded time before graceful shutdown. Useful for tests and proofs.
    #[arg(long = "serve-for-ms")]
    serve_for_ms: Option<u64>,
    /// Render server lifecycle output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ServerAppendArgs {
    #[arg(long = "server-addr", default_value = "127.0.0.1:7171")]
    server_addr: SocketAddr,
    #[arg(long = "stream-id")]
    stream_id: String,
    #[arg(long = "payload-text")]
    payload_text: String,
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ServerCreateRootArgs {
    #[arg(long = "server-addr", default_value = "127.0.0.1:7171")]
    server_addr: SocketAddr,
    #[arg(long = "stream-id")]
    stream_id: String,
    #[arg(long)]
    actor: Option<String>,
    #[arg(long)]
    reason: Option<String>,
    #[arg(long = "label")]
    labels: Vec<String>,
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ServerReadArgs {
    #[arg(long = "server-addr", default_value = "127.0.0.1:7171")]
    server_addr: SocketAddr,
    #[arg(long = "stream-id")]
    stream_id: String,
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ServerTailOpenArgs {
    #[arg(long = "server-addr", default_value = "127.0.0.1:7171")]
    server_addr: SocketAddr,
    #[arg(long = "stream-id")]
    stream_id: String,
    #[arg(long = "from-offset", default_value_t = 0)]
    from_offset: u64,
    #[arg(long = "credit", default_value_t = 1)]
    credit: u64,
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ServerTailPollArgs {
    #[arg(long = "server-addr", default_value = "127.0.0.1:7171")]
    server_addr: SocketAddr,
    #[arg(long = "session-id")]
    session_id: String,
    #[arg(long = "credit", default_value_t = 1)]
    credit: u64,
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ServerTailCancelArgs {
    #[arg(long = "server-addr", default_value = "127.0.0.1:7171")]
    server_addr: SocketAddr,
    #[arg(long = "session-id")]
    session_id: String,
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ServerBranchArgs {
    #[arg(long = "server-addr", default_value = "127.0.0.1:7171")]
    server_addr: SocketAddr,
    #[arg(long = "stream-id")]
    stream_id: String,
    #[arg(long = "parent-stream-id")]
    parent_stream_id: String,
    #[arg(long = "parent-offset")]
    parent_offset: u64,
    #[arg(long)]
    actor: Option<String>,
    #[arg(long)]
    reason: Option<String>,
    #[arg(long = "label")]
    labels: Vec<String>,
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ServerMergeArgs {
    #[arg(long = "server-addr", default_value = "127.0.0.1:7171")]
    server_addr: SocketAddr,
    #[arg(long = "stream-id")]
    stream_id: String,
    #[arg(long = "parent")]
    parents: Vec<String>,
    #[arg(long = "merge-base")]
    merge_base: Option<String>,
    #[arg(long = "policy", default_value = "recursive")]
    policy: String,
    #[arg(long = "policy-metadata")]
    policy_metadata: Vec<String>,
    #[arg(long)]
    actor: Option<String>,
    #[arg(long)]
    reason: Option<String>,
    #[arg(long = "label")]
    labels: Vec<String>,
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ServerLineageArgs {
    #[arg(long = "server-addr", default_value = "127.0.0.1:7171")]
    server_addr: SocketAddr,
    #[arg(long = "stream-id")]
    stream_id: String,
    #[arg(long)]
    json: bool,
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
            MissionCommands::TieredEngineProof(args) => {
                render_tiered_engine_proof(run_tiered_engine_proof(args.root).await?, args.json)?
            }
            MissionCommands::NetworkedServerProof(args) => {
                render_networked_server_proof(run_networked_server_proof(args.root)?, args.json)?
            }
            MissionCommands::VerifyLineage(args) => {
                render_verify_lineage(run_verify_lineage(&args)?, args.json)?
            }
            MissionCommands::Checkpoint(args) => {
                render_checkpoint(run_checkpoint(&args)?, args.json)?
            }
            MissionCommands::VerifyCheckpoint(args) => {
                render_verify_checkpoint(run_verify_checkpoint(&args)?, args.json)?
            }
        },
        Commands::ObjectStore(args) => match args.command {
            ObjectStoreCommands::Probe(args) => render_object_store_probe(
                probe_local_filesystem_store(args.root).await?,
                args.json,
            )?,
        },
        Commands::Server(args) => match args.command {
            ServerCommands::Run(args) => {
                let json = args.json;
                render_server_run(run_server(args).await?, json)?
            }
            ServerCommands::CreateRoot(args) => {
                let json = args.json;
                render_remote_stream_status(run_remote_create_root(args)?, json)?
            }
            ServerCommands::Append(args) => {
                let json = args.json;
                render_remote_append(run_remote_append(args)?, json)?
            }
            ServerCommands::Read(args) => {
                let json = args.json;
                render_remote_read(run_remote_read(args)?, json)?
            }
            ServerCommands::TailOpen(args) => {
                let json = args.json;
                render_remote_tail_open(run_remote_tail_open(args)?, json)?
            }
            ServerCommands::TailPoll(args) => {
                let json = args.json;
                render_remote_tail_poll(run_remote_tail_poll(args)?, json)?
            }
            ServerCommands::TailCancel(args) => {
                let json = args.json;
                render_remote_tail_cancel(run_remote_tail_cancel(args)?, json)?
            }
            ServerCommands::Branch(args) => {
                let json = args.json;
                render_remote_stream_status(run_remote_branch(args)?, json)?
            }
            ServerCommands::Merge(args) => {
                let json = args.json;
                render_remote_stream_status(run_remote_merge(args)?, json)?
            }
            ServerCommands::Lineage(args) => {
                let json = args.json;
                render_remote_lineage(run_remote_lineage(args)?, json)?
            }
        },
    }

    Ok(())
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct VerifiedSegmentOutcome {
    segment_id: String,
    start_offset: u64,
    last_offset: u64,
    verified: bool,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct VerifyLineageOutcome {
    stream_id: String,
    manifest_id: String,
    manifest_root: String,
    verified: bool,
    segments: Vec<VerifiedSegmentOutcome>,
    error: Option<String>,
}

fn run_verify_lineage(args: &VerifyLineageArgs) -> Result<VerifyLineageOutcome> {
    use transit_core::engine::{LocalEngine, LocalEngineConfig};
    use transit_core::kernel::StreamId;

    let engine = LocalEngine::open(LocalEngineConfig::new(&args.root))?;
    let stream_id = StreamId::new(&args.stream_id)?;

    match engine.verify_local_lineage(&stream_id) {
        Ok(lineage) => Ok(VerifyLineageOutcome {
            stream_id: args.stream_id.clone(),
            manifest_id: lineage.manifest_id.as_str().to_string(),
            manifest_root: lineage.manifest_root.digest().to_string(),
            verified: true,
            segments: lineage
                .segments
                .into_iter()
                .map(|s| VerifiedSegmentOutcome {
                    segment_id: s.segment_id.as_str().to_string(),
                    start_offset: s.start_offset.value(),
                    last_offset: s.last_offset.value(),
                    verified: s.verified,
                })
                .collect(),
            error: None,
        }),
        Err(e) => Ok(VerifyLineageOutcome {
            stream_id: args.stream_id.clone(),
            manifest_id: "unknown".to_string(),
            manifest_root: "unknown".to_string(),
            verified: false,
            segments: Vec::new(),
            error: Some(format!("{e:#}")),
        }),
    }
}

fn render_verify_lineage(outcome: VerifyLineageOutcome, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&outcome)?);
        return Ok(());
    }

    use textplots::{Chart, Plot, Shape};

    println!("transit integrity: verification profile for '{}'", outcome.stream_id);
    println!("trust anchor: manifest_root={}", outcome.manifest_root);
    println!("manifest_id: {}", outcome.manifest_id);

    if outcome.verified {
        println!("\nTrust Chain:");
        println!("  [ROOT] -> {}", outcome.manifest_root);
        for segment in &outcome.segments {
            println!("    |-- [SEGMENT] {} (offsets {}..{}) [PASS]", segment.segment_id, segment.start_offset, segment.last_offset);
        }

        if !outcome.segments.is_empty() {
            println!("\nVerification Map (Offset vs Integrity):");
            let mut points = Vec::new();
            for segment in &outcome.segments {
                points.push((segment.start_offset as f32, 100.0));
                points.push((segment.last_offset as f32, 100.0));
            }
            let max_offset = outcome.segments.last().map(|s| s.last_offset as f32).unwrap_or(1.0);
            Chart::new(60, 40, 0.0, max_offset)
                .lineplot(&Shape::Lines(&points))
                .display();
            println!("  0.0                                          {max_offset}");
        }

        println!("\nstatus: VERIFIED");
    } else {
        println!("\n[!] BROKEN TRUST CHAIN");
        println!("    [ROOT] --X--> (TAMPERED OR INVALID)");
        println!("\nstatus: FAILED");
        if let Some(error) = outcome.error {
            println!("error: {error}");
        }
    }

    Ok(())
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct CheckpointOutcome {
    stream_id: transit_core::kernel::StreamId,
    head_offset: transit_core::kernel::Offset,
    manifest_root: transit_core::storage::ContentDigest,
    kind: String,
}

fn run_checkpoint(args: &CheckpointArgs) -> Result<CheckpointOutcome> {
    use transit_core::engine::{LocalEngine, LocalEngineConfig};
    use transit_core::kernel::StreamId;

    let engine = LocalEngine::open(LocalEngineConfig::new(&args.root))?;
    let stream_id = StreamId::new(&args.stream_id)?;
    let checkpoint = engine.checkpoint(&stream_id, &args.kind)?;

    Ok(CheckpointOutcome {
        stream_id: checkpoint.stream_id,
        head_offset: checkpoint.head_offset,
        manifest_root: checkpoint.manifest_root,
        kind: checkpoint.kind,
    })
}

fn render_checkpoint(outcome: CheckpointOutcome, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&outcome)?);
        return Ok(());
    }

    println!("transit integrity: lineage checkpoint created");
    println!("  stream: {}", outcome.stream_id.as_str());
    println!("  head:   {}", outcome.head_offset.value());
    println!("  root:   {}", outcome.manifest_root.digest());
    println!("  kind:   {}", outcome.kind);

    Ok(())
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct VerifyCheckpointOutcome {
    verified: bool,
    error: Option<String>,
}

fn run_verify_checkpoint(args: &VerifyCheckpointArgs) -> Result<VerifyCheckpointOutcome> {
    use transit_core::engine::{LocalEngine, LocalEngineConfig};
    use transit_core::storage::LineageCheckpoint;

    let engine = LocalEngine::open(LocalEngineConfig::new(&args.root))?;
    let bytes = fs::read(&args.checkpoint_path).context("read checkpoint file")?;
    let checkpoint: LineageCheckpoint = serde_json::from_slice(&bytes).context("parse checkpoint")?;

    match engine.verify_checkpoint(&checkpoint) {
        Ok(_) => Ok(VerifyCheckpointOutcome {
            verified: true,
            error: None,
        }),
        Err(e) => Ok(VerifyCheckpointOutcome {
            verified: false,
            error: Some(format!("{e:#}")),
        }),
    }
}

fn render_verify_checkpoint(outcome: VerifyCheckpointOutcome, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&outcome)?);
        return Ok(());
    }

    if outcome.verified {
        println!("transit integrity: checkpoint VERIFIED");
    } else {
        println!("transit integrity: checkpoint FAILED");
        if let Some(error) = outcome.error {
            println!("error: {error}");
        }
    }

    Ok(())
}

fn render_mission_status(status: MissionStatus, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&status)?);
        return Ok(());
    }

    use textplots::{Chart, Plot, Shape};

    println!("transit mission status");
    println!("summary: {}", status.summary());
    println!("version: {}", status.version);

    // Visual completion profile
    // X-axis: 0:Core, 1:Server, 2:Integrity, 3:Next
    // Y-axis: % Completion
    let integrity_score = if status.integrity_ready { 100.0 } else { 0.0 };
    let points = vec![
        (0.0, 100.0), // Core
        (1.0, 100.0), // Server
        (2.0, integrity_score), // Integrity
        (3.0, 0.0),   // Next (Materialization/Multi-node)
    ];

    println!("\nCompletion Profile:");
    Chart::new(60, 40, 0.0, 3.0)
        .lineplot(&Shape::Lines(&points))
        .display();
    println!("  0:Core  1:Server  2:Integrity  3:Next\n");

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
        println!("kernel slice: durable local engine + tiered publish/restore");
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

    println!("\nNext Missions:");
    println!("  - Materialization (Processing)");
    println!("  - Multi-Node Consensus (Durability)");
    println!("  - Multi-Node Replication (Distribution)");
    println!("  - Client Libraries (Expansion)");

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

#[derive(Debug, Serialize)]
struct TieredEngineProofResult {
    data_root: PathBuf,
    durability: String,
    publish_stream: StreamProofSummary,
    restored_stream: StreamProofSummary,
    published_segments: Vec<String>,
    manifest_object_key: String,
    publication_manifest_generation: u64,
    restored_manifest_generation: u64,
    unpublished_local_records: usize,
    publication_api: &'static str,
    restore_api: &'static str,
    replay_after_remote_removal_ok: bool,
}

#[derive(Debug, Serialize)]
struct NetworkedTransportProofSummary {
    application_protocol: &'static str,
    transport_boundary: &'static str,
    wireguard_role: &'static str,
    replication_scope: &'static str,
}

#[derive(Debug, Serialize)]
struct NetworkedServerProofResult {
    data_root: PathBuf,
    server_addr: String,
    durability: String,
    topology: String,
    root_stream: RemoteStreamStatusResult,
    initial_append: RemoteAppendResult,
    root_replay: RemoteReadResult,
    branch_stream: RemoteStreamStatusResult,
    second_branch_stream: RemoteStreamStatusResult,
    merge_stream: RemoteStreamStatusResult,
    merge_lineage: RemoteLineageResult,
    tail_open: RemoteTailOpenResult,
    tail_append: RemoteAppendResult,
    tail_poll: RemoteTailPollResult,
    tail_cancel: RemoteTailCancelResult,
    transport: NetworkedTransportProofSummary,
    accepted_connections: u64,
    graceful_shutdown: bool,
    server_api: &'static str,
    remote_api: &'static str,
}

#[derive(Debug, Serialize)]
struct ServerRunResult {
    data_root: PathBuf,
    requested_listen_addr: String,
    bound_listen_addr: String,
    durability: String,
    accepted_connections: u64,
    graceful_shutdown: bool,
    server_api: &'static str,
}

#[derive(Debug, Serialize)]
struct RemoteAppendResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    stream_id: String,
    position: String,
    manifest_generation: u64,
    rolled_segment_id: Option<String>,
}

#[derive(Debug, Serialize)]
struct RemoteReadResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    stream_id: String,
    record_count: usize,
    head_offset: Option<u64>,
    records: Vec<RemoteRecordView>,
}

#[derive(Debug, Serialize)]
struct RemoteRecordView {
    position: String,
    payload_text: String,
}

#[derive(Debug, Serialize)]
struct RemoteStreamStatusResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    stream_id: String,
    next_offset: u64,
    active_record_count: u64,
    active_segment_start_offset: u64,
    manifest_generation: u64,
    rolled_segment_count: usize,
}

#[derive(Debug, Serialize)]
struct RemoteLineageResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    stream_id: String,
    lineage_kind: String,
    parents: Vec<String>,
    next_offset: u64,
    manifest_generation: u64,
    rolled_segment_count: usize,
}

#[derive(Debug, Serialize)]
struct RemoteTailOpenResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    session_id: String,
    stream_id: String,
    requested_credit: u64,
    delivered_credit: u64,
    next_offset: u64,
    state: String,
    max_credit: u64,
    records: Vec<RemoteRecordView>,
}

#[derive(Debug, Serialize)]
struct RemoteTailPollResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    session_id: String,
    stream_id: String,
    requested_credit: u64,
    delivered_credit: u64,
    next_offset: u64,
    state: String,
    records: Vec<RemoteRecordView>,
}

#[derive(Debug, Serialize)]
struct RemoteTailCancelResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    session_id: String,
    stream_id: String,
    next_offset: u64,
    state: String,
}

fn run_local_engine_proof(root: PathBuf) -> Result<LocalEngineProofResult> {
    reset_directory(&root)?;

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

fn run_networked_server_proof(root: PathBuf) -> Result<NetworkedServerProofResult> {
    reset_directory(&root)?;

    let requested_listen_addr = "127.0.0.1:0"
        .parse::<SocketAddr>()
        .context("parse networked server proof listen addr")?;
    let server = ServerHandle::bind(ServerConfig::new(
        LocalEngineConfig::new(&root).with_segment_max_records(2)?,
        requested_listen_addr,
    ))
    .context("bind networked server proof daemon")?;
    let server_addr = server.local_addr();

    let root_stream = run_remote_create_root(ServerCreateRootArgs {
        server_addr,
        stream_id: "mission.root".into(),
        actor: Some("mission".into()),
        reason: Some("networked-server-proof".into()),
        labels: vec!["kind=root".into()],
        json: false,
    })?;
    let initial_append = run_remote_append(ServerAppendArgs {
        server_addr,
        stream_id: "mission.root".into(),
        payload_text: "root-0".into(),
        json: false,
    })?;
    let root_replay = run_remote_read(ServerReadArgs {
        server_addr,
        stream_id: "mission.root".into(),
        json: false,
    })?;
    let branch_stream = run_remote_branch(ServerBranchArgs {
        server_addr,
        stream_id: "mission.branch".into(),
        parent_stream_id: "mission.root".into(),
        parent_offset: 0,
        actor: Some("mission.classifier".into()),
        reason: Some("thread-split".into()),
        labels: vec!["thread=1".into()],
        json: false,
    })?;
    let second_branch_stream = run_remote_branch(ServerBranchArgs {
        server_addr,
        stream_id: "mission.branch-two".into(),
        parent_stream_id: "mission.root".into(),
        parent_offset: 0,
        actor: Some("mission.classifier".into()),
        reason: Some("thread-split-two".into()),
        labels: vec!["thread=2".into()],
        json: false,
    })?;
    let merge_stream = run_remote_merge(ServerMergeArgs {
        server_addr,
        stream_id: "mission.merge".into(),
        parents: vec!["mission.branch@0".into(), "mission.branch-two@0".into()],
        merge_base: Some("mission.root@0".into()),
        policy: "recursive".into(),
        policy_metadata: vec!["resolver=mission-judge".into()],
        actor: Some("mission.judge".into()),
        reason: Some("merge-branches".into()),
        labels: vec!["decision=accepted".into()],
        json: false,
    })?;
    let merge_lineage = run_remote_lineage(ServerLineageArgs {
        server_addr,
        stream_id: "mission.merge".into(),
        json: false,
    })?;
    let tail_open = run_remote_tail_open(ServerTailOpenArgs {
        server_addr,
        stream_id: "mission.root".into(),
        from_offset: 0,
        credit: 1,
        json: false,
    })?;
    let tail_append = run_remote_append(ServerAppendArgs {
        server_addr,
        stream_id: "mission.root".into(),
        payload_text: "root-1".into(),
        json: false,
    })?;
    let tail_poll = run_remote_tail_poll(ServerTailPollArgs {
        server_addr,
        session_id: tail_open.session_id.clone(),
        credit: 1,
        json: false,
    })?;
    let tail_cancel = run_remote_tail_cancel(ServerTailCancelArgs {
        server_addr,
        session_id: tail_open.session_id.clone(),
        json: false,
    })?;

    let shutdown = summarize_server_shutdown(
        requested_listen_addr,
        server
            .shutdown()
            .context("shutdown networked server proof daemon")?,
    )?;

    Ok(NetworkedServerProofResult {
        data_root: shutdown.data_root,
        server_addr: server_addr.to_string(),
        durability: shutdown.durability,
        topology: initial_append.topology.clone(),
        root_stream,
        initial_append,
        root_replay,
        branch_stream,
        second_branch_stream,
        merge_stream,
        merge_lineage,
        tail_open,
        tail_append,
        tail_poll,
        tail_cancel,
        transport: NetworkedTransportProofSummary {
            application_protocol: "framed request-response plus logical tail sessions",
            transport_boundary: "the transit protocol stays above generic transports and below optional secure underlays",
            wireguard_role: "optional secure underlay for trusted node links, not the application protocol",
            replication_scope: "single_node_only",
        },
        accepted_connections: shutdown.accepted_connections,
        graceful_shutdown: shutdown.graceful_shutdown,
        server_api: shutdown.server_api,
        remote_api: "RemoteClient",
    })
}

async fn run_server(args: ServerRunArgs) -> Result<ServerRunResult> {
    let requested_listen_addr = args.listen_addr;
    let server = ServerHandle::bind(ServerConfig::new(
        LocalEngineConfig::new(&args.root),
        args.listen_addr,
    ))
    .context("bind shared-engine server")?;

    if !args.json {
        println!("transit server bootstrap");
        println!("root: {}", server.data_dir().display());
        println!("listen requested: {}", requested_listen_addr);
        println!("listen bound: {}", server.local_addr());
        println!("durability: {}", server.durability().as_str());
        if args.serve_for_ms.is_none() {
            println!("shutdown: waiting for Ctrl-C");
        }
    }

    if let Some(serve_for_ms) = args.serve_for_ms {
        std::thread::sleep(Duration::from_millis(serve_for_ms));
    } else {
        tokio::signal::ctrl_c()
            .await
            .context("wait for Ctrl-C before shutting down server")?;
    }

    summarize_server_shutdown(
        requested_listen_addr,
        server.shutdown().context("shutdown shared-engine server")?,
    )
}

fn run_remote_create_root(args: ServerCreateRootArgs) -> Result<RemoteStreamStatusResult> {
    let client = RemoteClient::new(args.server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let created = client
        .create_root(
            &stream_id,
            parse_lineage_metadata(args.actor, args.reason, args.labels)?,
        )
        .with_context(|| format!("create remote root {}", stream_id.as_str()))?;

    Ok(summarize_remote_stream_status(
        args.server_addr,
        created.request_id().as_str(),
        created.ack().durability(),
        created.ack().topology(),
        created.body().stream_id().as_str(),
        created.body().next_offset().value(),
        created.body().active_record_count(),
        created.body().active_segment_start_offset().value(),
        created.body().manifest_generation(),
        created.body().rolled_segment_count(),
    ))
}

fn run_remote_append(args: ServerAppendArgs) -> Result<RemoteAppendResult> {
    let client = RemoteClient::new(args.server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let append = client
        .append(&stream_id, args.payload_text.as_bytes())
        .with_context(|| format!("append remotely to {}", stream_id.as_str()))?;

    Ok(RemoteAppendResult {
        server_addr: args.server_addr.to_string(),
        request_id: append.request_id().as_str().to_owned(),
        durability: append.ack().durability().to_owned(),
        topology: render_topology(append.ack().topology()),
        stream_id: stream_id.as_str().to_owned(),
        position: render_position(append.body().position().clone()),
        manifest_generation: append.body().manifest_generation(),
        rolled_segment_id: append.body().rolled_segment_id().map(str::to_owned),
    })
}

fn run_remote_read(args: ServerReadArgs) -> Result<RemoteReadResult> {
    let client = RemoteClient::new(args.server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let read = client
        .read(&stream_id)
        .with_context(|| format!("read remotely from {}", stream_id.as_str()))?;
    let records = summarize_remote_records(read.body().records());

    Ok(RemoteReadResult {
        server_addr: args.server_addr.to_string(),
        request_id: read.request_id().as_str().to_owned(),
        durability: read.ack().durability().to_owned(),
        topology: render_topology(read.ack().topology()),
        stream_id: stream_id.as_str().to_owned(),
        record_count: records.len(),
        head_offset: read
            .body()
            .records()
            .last()
            .map(|record| record.position().offset.value()),
        records,
    })
}

fn run_remote_tail_open(args: ServerTailOpenArgs) -> Result<RemoteTailOpenResult> {
    let client = RemoteClient::new(args.server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let opened = client
        .open_tail_session(&stream_id, Offset::new(args.from_offset), args.credit)
        .with_context(|| format!("open remote tail session for {}", stream_id.as_str()))?;

    Ok(RemoteTailOpenResult {
        server_addr: args.server_addr.to_string(),
        request_id: opened.request_id().as_str().to_owned(),
        durability: opened.ack().durability().to_owned(),
        topology: render_topology(opened.ack().topology()),
        session_id: opened.body().session_id().as_str().to_owned(),
        stream_id: opened.body().stream_id().as_str().to_owned(),
        requested_credit: opened.body().requested_credit(),
        delivered_credit: opened.body().delivered_credit(),
        next_offset: opened.body().next_offset().value(),
        state: render_tail_state(opened.body().state()),
        max_credit: opened.body().max_credit(),
        records: summarize_remote_records(opened.body().records()),
    })
}

fn run_remote_tail_poll(args: ServerTailPollArgs) -> Result<RemoteTailPollResult> {
    let client = RemoteClient::new(args.server_addr);
    let session_id = parse_tail_session_id_arg(&args.session_id)?;
    let batch = client
        .poll_tail_session(&session_id, args.credit)
        .with_context(|| format!("poll remote tail session {}", session_id.as_str()))?;

    Ok(RemoteTailPollResult {
        server_addr: args.server_addr.to_string(),
        request_id: batch.request_id().as_str().to_owned(),
        durability: batch.ack().durability().to_owned(),
        topology: render_topology(batch.ack().topology()),
        session_id: batch.body().session_id().as_str().to_owned(),
        stream_id: batch.body().stream_id().as_str().to_owned(),
        requested_credit: batch.body().requested_credit(),
        delivered_credit: batch.body().delivered_credit(),
        next_offset: batch.body().next_offset().value(),
        state: render_tail_state(batch.body().state()),
        records: summarize_remote_records(batch.body().records()),
    })
}

fn run_remote_tail_cancel(args: ServerTailCancelArgs) -> Result<RemoteTailCancelResult> {
    let client = RemoteClient::new(args.server_addr);
    let session_id = parse_tail_session_id_arg(&args.session_id)?;
    let cancelled = client
        .cancel_tail_session(&session_id)
        .with_context(|| format!("cancel remote tail session {}", session_id.as_str()))?;

    Ok(RemoteTailCancelResult {
        server_addr: args.server_addr.to_string(),
        request_id: cancelled.request_id().as_str().to_owned(),
        durability: cancelled.ack().durability().to_owned(),
        topology: render_topology(cancelled.ack().topology()),
        session_id: cancelled.body().session_id().as_str().to_owned(),
        stream_id: cancelled.body().stream_id().as_str().to_owned(),
        next_offset: cancelled.body().next_offset().value(),
        state: render_tail_state(cancelled.body().state()),
    })
}

fn run_remote_branch(args: ServerBranchArgs) -> Result<RemoteStreamStatusResult> {
    let client = RemoteClient::new(args.server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let parent = StreamPosition::new(
        parse_stream_id_arg(&args.parent_stream_id)?,
        Offset::new(args.parent_offset),
    );
    let branch = client
        .create_branch(
            &stream_id,
            parent,
            parse_lineage_metadata(args.actor, args.reason, args.labels)?,
        )
        .with_context(|| format!("create remote branch {}", stream_id.as_str()))?;

    Ok(summarize_remote_stream_status(
        args.server_addr,
        branch.request_id().as_str(),
        branch.ack().durability(),
        branch.ack().topology(),
        branch.body().stream_id().as_str(),
        branch.body().next_offset().value(),
        branch.body().active_record_count(),
        branch.body().active_segment_start_offset().value(),
        branch.body().manifest_generation(),
        branch.body().rolled_segment_count(),
    ))
}

fn run_remote_merge(args: ServerMergeArgs) -> Result<RemoteStreamStatusResult> {
    let client = RemoteClient::new(args.server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let parents = args
        .parents
        .iter()
        .map(|value| parse_position_arg(value))
        .collect::<Result<Vec<_>>>()?;
    let merge_base = args
        .merge_base
        .as_deref()
        .map(parse_position_arg)
        .transpose()?;
    let merge = MergeSpec::new(
        parents,
        merge_base,
        parse_merge_policy(&args.policy, &args.policy_metadata)?,
        parse_lineage_metadata(args.actor, args.reason, args.labels)?,
    )?;
    let merged = client
        .create_merge(&stream_id, merge)
        .with_context(|| format!("create remote merge {}", stream_id.as_str()))?;

    Ok(summarize_remote_stream_status(
        args.server_addr,
        merged.request_id().as_str(),
        merged.ack().durability(),
        merged.ack().topology(),
        merged.body().stream_id().as_str(),
        merged.body().next_offset().value(),
        merged.body().active_record_count(),
        merged.body().active_segment_start_offset().value(),
        merged.body().manifest_generation(),
        merged.body().rolled_segment_count(),
    ))
}

fn run_remote_lineage(args: ServerLineageArgs) -> Result<RemoteLineageResult> {
    let client = RemoteClient::new(args.server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let lineage = client
        .inspect_lineage(&stream_id)
        .with_context(|| format!("inspect remote lineage for {}", stream_id.as_str()))?;
    let descriptor = lineage.body().descriptor();

    Ok(RemoteLineageResult {
        server_addr: args.server_addr.to_string(),
        request_id: lineage.request_id().as_str().to_owned(),
        durability: lineage.ack().durability().to_owned(),
        topology: render_topology(lineage.ack().topology()),
        stream_id: descriptor.stream_id.as_str().to_owned(),
        lineage_kind: match &descriptor.lineage {
            StreamLineage::Root { .. } => "root".to_owned(),
            StreamLineage::Branch { .. } => "branch".to_owned(),
            StreamLineage::Merge { .. } => "merge".to_owned(),
        },
        parents: descriptor
            .parent_stream_ids()
            .into_iter()
            .map(|parent| parent.as_str().to_owned())
            .collect(),
        next_offset: lineage.body().status().next_offset().value(),
        manifest_generation: lineage.body().status().manifest_generation(),
        rolled_segment_count: lineage.body().status().rolled_segment_count(),
    })
}

async fn run_tiered_engine_proof(root: PathBuf) -> Result<TieredEngineProofResult> {
    reset_directory(&root)?;

    let publish_root = root.join("publish");
    let restore_root = root.join("restore");
    let object_store_root = root.join("object-store");
    fs::create_dir_all(&publish_root)
        .with_context(|| format!("create publish root {}", publish_root.display()))?;
    fs::create_dir_all(&restore_root)
        .with_context(|| format!("create restore root {}", restore_root.display()))?;
    fs::create_dir_all(&object_store_root)
        .with_context(|| format!("create object store root {}", object_store_root.display()))?;

    let publish_engine = LocalEngine::open(
        LocalEngineConfig::new(&publish_root)
            .with_segment_max_records(2)
            .context("tiered proof config")?,
    )
    .context("open publish engine")?;
    let restore_engine =
        LocalEngine::open(LocalEngineConfig::new(&restore_root)).context("open restore engine")?;
    let store = LocalFileSystem::new_with_prefix(&object_store_root)
        .with_context(|| format!("open local object store at {}", object_store_root.display()))?;

    let stream_id = StreamId::new("tiered.root")?;
    publish_engine.create_stream(StreamDescriptor::root(
        stream_id.clone(),
        LineageMetadata::new(Some("mission".into()), Some("tiered-engine-proof".into())),
    ))?;
    for payload in ["first", "second", "third", "fourth", "fifth"] {
        publish_engine.append(&stream_id, payload.as_bytes())?;
    }

    let publication = publish_engine
        .publish_rolled_segments(&stream_id, &store, "tiered-proof")
        .await?;
    let manifest_key = publication
        .manifest_object_key()
        .context("tiered proof publish should emit a remote manifest")?
        .clone();
    let restore = restore_engine
        .restore_stream_from_remote_manifest(&store, &manifest_key)
        .await?;

    let published_records = publish_engine.replay(&stream_id)?;
    let restored_records = restore_engine.replay(&stream_id)?;
    let unpublished_local_records = published_records
        .len()
        .saturating_sub(restored_records.len());

    drop(store);
    fs::remove_dir_all(&object_store_root)
        .with_context(|| format!("remove object store root {}", object_store_root.display()))?;
    let replay_after_remote_removal_ok = restore_engine.replay(&stream_id).is_ok();

    Ok(TieredEngineProofResult {
        data_root: root,
        durability: publication.durability().as_str().to_owned(),
        publish_stream: summarize_stream(&stream_id, &published_records),
        restored_stream: summarize_stream(&stream_id, &restored_records),
        published_segments: publication
            .published_segment_ids()
            .iter()
            .map(|segment_id| segment_id.as_str().to_owned())
            .collect(),
        manifest_object_key: manifest_key.as_str().to_owned(),
        publication_manifest_generation: publication.manifest_generation(),
        restored_manifest_generation: restore.manifest_generation(),
        unpublished_local_records,
        publication_api: "LocalEngine::publish_rolled_segments",
        restore_api: "LocalEngine::restore_stream_from_remote_manifest",
        replay_after_remote_removal_ok,
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

fn summarize_remote_stream_status(
    server_addr: SocketAddr,
    request_id: &str,
    durability: &str,
    topology: transit_core::server::RemoteTopology,
    stream_id: &str,
    next_offset: u64,
    active_record_count: u64,
    active_segment_start_offset: u64,
    manifest_generation: u64,
    rolled_segment_count: usize,
) -> RemoteStreamStatusResult {
    RemoteStreamStatusResult {
        server_addr: server_addr.to_string(),
        request_id: request_id.to_owned(),
        durability: durability.to_owned(),
        topology: render_topology(topology),
        stream_id: stream_id.to_owned(),
        next_offset,
        active_record_count,
        active_segment_start_offset,
        manifest_generation,
        rolled_segment_count,
    }
}

fn summarize_remote_records(
    records: &[transit_core::server::RemoteRecord],
) -> Vec<RemoteRecordView> {
    records
        .iter()
        .map(|record| RemoteRecordView {
            position: render_position(record.position().clone()),
            payload_text: String::from_utf8_lossy(record.payload()).into_owned(),
        })
        .collect()
}

fn parse_stream_id_arg(value: &str) -> Result<StreamId> {
    StreamId::new(value).with_context(|| format!("parse stream id '{value}'"))
}

fn parse_tail_session_id_arg(value: &str) -> Result<TailSessionId> {
    TailSessionId::new(value).with_context(|| format!("parse tail session id '{value}'"))
}

fn parse_lineage_metadata(
    actor: Option<String>,
    reason: Option<String>,
    labels: Vec<String>,
) -> Result<LineageMetadata> {
    let mut metadata = LineageMetadata::new(actor, reason);
    for entry in labels {
        let (key, value) = parse_key_value_arg(&entry)?;
        metadata = metadata.with_label(key, value);
    }
    Ok(metadata)
}

fn parse_merge_policy(policy: &str, entries: &[String]) -> Result<MergePolicy> {
    let kind = match policy {
        "fast_forward" => MergePolicyKind::FastForward,
        "recursive" => MergePolicyKind::Recursive,
        other => match other.strip_prefix("custom:") {
            Some(name) => MergePolicyKind::Custom(name.to_owned()),
            None => {
                anyhow::bail!(
                    "unsupported merge policy '{other}', use fast_forward, recursive, or custom:<name>"
                )
            }
        },
    };

    let mut policy = MergePolicy::new(kind);
    for entry in entries {
        let (key, value) = parse_key_value_arg(entry)?;
        policy = policy.with_metadata(key, value);
    }
    Ok(policy)
}

fn parse_position_arg(value: &str) -> Result<StreamPosition> {
    let (stream_id, offset) = value
        .rsplit_once('@')
        .with_context(|| format!("parse position '{value}' as <stream-id>@<offset>"))?;
    let offset = offset
        .parse::<u64>()
        .with_context(|| format!("parse offset in position '{value}'"))?;
    Ok(StreamPosition::new(
        parse_stream_id_arg(stream_id)?,
        Offset::new(offset),
    ))
}

fn parse_key_value_arg(value: &str) -> Result<(String, String)> {
    let (key, value) = value
        .split_once('=')
        .with_context(|| format!("parse key=value pair '{value}'"))?;
    Ok((key.to_owned(), value.to_owned()))
}

fn reset_directory(root: &Path) -> Result<()> {
    if root.exists() {
        fs::remove_dir_all(root)
            .with_context(|| format!("remove existing proof root {}", root.display()))?;
    }
    fs::create_dir_all(root).with_context(|| format!("create proof root {}", root.display()))?;
    Ok(())
}

fn render_position(position: StreamPosition) -> String {
    format!(
        "{}@{}",
        position.stream_id.as_str(),
        position.offset.value()
    )
}

fn render_topology(topology: transit_core::server::RemoteTopology) -> String {
    match topology {
        transit_core::server::RemoteTopology::SingleNode => "single_node".to_owned(),
    }
}

fn render_tail_state(state: transit_core::server::RemoteTailSessionState) -> String {
    match state {
        transit_core::server::RemoteTailSessionState::Active => "active".to_owned(),
        transit_core::server::RemoteTailSessionState::AwaitingRecords => {
            "awaiting_records".to_owned()
        }
        transit_core::server::RemoteTailSessionState::Cancelled => "cancelled".to_owned(),
    }
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

fn render_tiered_engine_proof(result: TieredEngineProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit tiered-engine proof");
    println!("root: {}", result.data_root.display());
    println!("durability: {}", result.durability);
    println!(
        "published stream replay: {} records, head {:?}",
        result.publish_stream.record_count, result.publish_stream.head_offset
    );
    println!(
        "restored stream replay: {} records, head {:?}",
        result.restored_stream.record_count, result.restored_stream.head_offset
    );
    println!("published segments:");
    for segment_id in &result.published_segments {
        println!("  - {segment_id}");
    }
    println!("manifest object: {}", result.manifest_object_key);
    println!(
        "publication manifest generation: {}",
        result.publication_manifest_generation
    );
    println!(
        "restored manifest generation: {}",
        result.restored_manifest_generation
    );
    println!(
        "unpublished local records omitted from restore: {}",
        result.unpublished_local_records
    );
    println!("publication api: {}", result.publication_api);
    println!("restore api: {}", result.restore_api);
    println!(
        "replay after remote removal: {}",
        if result.replay_after_remote_removal_ok {
            "ok"
        } else {
            "failed"
        }
    );

    Ok(())
}

fn render_networked_server_proof(result: NetworkedServerProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit networked-server proof");
    println!("root: {}", result.data_root.display());
    println!("server: {}", result.server_addr);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!(
        "root create: {} next {}",
        result.root_stream.stream_id, result.root_stream.next_offset
    );
    println!("initial append: {}", result.initial_append.position);
    println!(
        "root replay: {} records, head {:?}",
        result.root_replay.record_count, result.root_replay.head_offset
    );
    println!(
        "branch streams: {}, {}",
        result.branch_stream.stream_id, result.second_branch_stream.stream_id
    );
    println!(
        "merge stream: {} ({})",
        result.merge_stream.stream_id, result.merge_lineage.lineage_kind
    );
    if result.merge_lineage.parents.is_empty() {
        println!("merge parents: none");
    } else {
        println!("merge parents:");
        for parent in &result.merge_lineage.parents {
            println!("  - {parent}");
        }
    }
    println!(
        "tail open: {} delivered {} state {}",
        result.tail_open.session_id, result.tail_open.delivered_credit, result.tail_open.state
    );
    println!("tail append: {}", result.tail_append.position);
    println!(
        "tail poll: delivered {} next {} state {}",
        result.tail_poll.delivered_credit, result.tail_poll.next_offset, result.tail_poll.state
    );
    println!("tail cancel: {}", result.tail_cancel.state);
    println!(
        "transport contract: {}",
        result.transport.application_protocol
    );
    println!(
        "transport boundary: {}",
        result.transport.transport_boundary
    );
    println!("wireguard role: {}", result.transport.wireguard_role);
    println!("replication scope: {}", result.transport.replication_scope);
    println!("accepted connections: {}", result.accepted_connections);
    println!(
        "graceful shutdown: {}",
        if result.graceful_shutdown {
            "yes"
        } else {
            "no"
        }
    );
    println!("server api: {}", result.server_api);
    println!("remote api: {}", result.remote_api);

    Ok(())
}

fn summarize_server_shutdown(
    requested_listen_addr: SocketAddr,
    outcome: ServerShutdownOutcome,
) -> Result<ServerRunResult> {
    Ok(ServerRunResult {
        data_root: outcome.data_dir().to_path_buf(),
        requested_listen_addr: requested_listen_addr.to_string(),
        bound_listen_addr: outcome.local_addr().to_string(),
        durability: outcome.durability().as_str().to_owned(),
        accepted_connections: outcome.accepted_connections(),
        graceful_shutdown: true,
        server_api: "ServerHandle::bind",
    })
}

fn render_server_run(result: ServerRunResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit server shutdown");
    println!("root: {}", result.data_root.display());
    println!("listen requested: {}", result.requested_listen_addr);
    println!("listen bound: {}", result.bound_listen_addr);
    println!("durability: {}", result.durability);
    println!("accepted connections: {}", result.accepted_connections);
    println!(
        "graceful shutdown: {}",
        if result.graceful_shutdown {
            "yes"
        } else {
            "no"
        }
    );
    println!("server api: {}", result.server_api);

    Ok(())
}

fn render_remote_append(result: RemoteAppendResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit server append");
    println!("server: {}", result.server_addr);
    println!("request: {}", result.request_id);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("stream: {}", result.stream_id);
    println!("position: {}", result.position);
    println!("manifest generation: {}", result.manifest_generation);
    if let Some(segment_id) = result.rolled_segment_id {
        println!("rolled segment: {segment_id}");
    }
    Ok(())
}

fn render_remote_read(result: RemoteReadResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit server read");
    println!("server: {}", result.server_addr);
    println!("request: {}", result.request_id);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("stream: {}", result.stream_id);
    println!("records: {}", result.record_count);
    if let Some(head_offset) = result.head_offset {
        println!("head offset: {head_offset}");
    }
    for record in result.records {
        println!("{} {}", record.position, record.payload_text);
    }
    Ok(())
}

fn render_remote_stream_status(result: RemoteStreamStatusResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit server stream status");
    println!("server: {}", result.server_addr);
    println!("request: {}", result.request_id);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("stream: {}", result.stream_id);
    println!("next offset: {}", result.next_offset);
    println!("active records: {}", result.active_record_count);
    println!(
        "active segment start offset: {}",
        result.active_segment_start_offset
    );
    println!("manifest generation: {}", result.manifest_generation);
    println!("rolled segments: {}", result.rolled_segment_count);
    Ok(())
}

fn render_remote_lineage(result: RemoteLineageResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit server lineage");
    println!("server: {}", result.server_addr);
    println!("request: {}", result.request_id);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("stream: {}", result.stream_id);
    println!("lineage kind: {}", result.lineage_kind);
    if result.parents.is_empty() {
        println!("parents: none");
    } else {
        println!("parents:");
        for parent in result.parents {
            println!("  - {parent}");
        }
    }
    println!("next offset: {}", result.next_offset);
    println!("manifest generation: {}", result.manifest_generation);
    println!("rolled segments: {}", result.rolled_segment_count);
    Ok(())
}

fn render_remote_tail_open(result: RemoteTailOpenResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit server tail open");
    println!("server: {}", result.server_addr);
    println!("request: {}", result.request_id);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("session: {}", result.session_id);
    println!("stream: {}", result.stream_id);
    println!("requested credit: {}", result.requested_credit);
    println!("delivered credit: {}", result.delivered_credit);
    println!("next offset: {}", result.next_offset);
    println!("state: {}", result.state);
    println!("max credit: {}", result.max_credit);
    for record in result.records {
        println!("{} {}", record.position, record.payload_text);
    }
    Ok(())
}

fn render_remote_tail_poll(result: RemoteTailPollResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit server tail poll");
    println!("server: {}", result.server_addr);
    println!("request: {}", result.request_id);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("session: {}", result.session_id);
    println!("stream: {}", result.stream_id);
    println!("requested credit: {}", result.requested_credit);
    println!("delivered credit: {}", result.delivered_credit);
    println!("next offset: {}", result.next_offset);
    println!("state: {}", result.state);
    for record in result.records {
        println!("{} {}", record.position, record.payload_text);
    }
    Ok(())
}

fn render_remote_tail_cancel(result: RemoteTailCancelResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit server tail cancel");
    println!("server: {}", result.server_addr);
    println!("request: {}", result.request_id);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("session: {}", result.session_id);
    println!("stream: {}", result.stream_id);
    println!("next offset: {}", result.next_offset);
    println!("state: {}", result.state);
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

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn start_server() -> (tempfile::TempDir, ServerHandle, SocketAddr) {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path()),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let server_addr = server.local_addr();
        (temp_dir, server, server_addr)
    }

    #[test]
    fn remote_cli_helpers_cover_core_server_workflows() {
        let (_temp_dir, server, server_addr) = start_server();
        let engine = server.engine();
        let root = run_remote_create_root(ServerCreateRootArgs {
            server_addr,
            stream_id: "task.root".into(),
            actor: Some("test".into()),
            reason: Some("cli".into()),
            labels: vec!["kind=root".into()],
            json: true,
        })
        .expect("create root stream");
        let root_stream = StreamId::new("task.root").expect("stream id");

        let append = run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: "task.root".into(),
            payload_text: "first".into(),
            json: true,
        })
        .expect("append");
        let read = run_remote_read(ServerReadArgs {
            server_addr,
            stream_id: "task.root".into(),
            json: true,
        })
        .expect("read");
        let branch = run_remote_branch(ServerBranchArgs {
            server_addr,
            stream_id: "task.branch".into(),
            parent_stream_id: "task.root".into(),
            parent_offset: 0,
            actor: Some("classifier".into()),
            reason: Some("split".into()),
            labels: vec!["thread=1".into()],
            json: true,
        })
        .expect("branch");
        let second_branch = run_remote_branch(ServerBranchArgs {
            server_addr,
            stream_id: "task.branch-two".into(),
            parent_stream_id: "task.root".into(),
            parent_offset: 0,
            actor: Some("classifier".into()),
            reason: Some("split-two".into()),
            labels: vec![],
            json: true,
        })
        .expect("second branch");
        let merge = run_remote_merge(ServerMergeArgs {
            server_addr,
            stream_id: "task.merge".into(),
            parents: vec!["task.branch@0".into(), "task.branch-two@0".into()],
            merge_base: Some("task.root@0".into()),
            policy: "recursive".into(),
            policy_metadata: vec!["resolver=judge-v1".into()],
            actor: Some("judge".into()),
            reason: Some("merge".into()),
            labels: vec!["decision=accepted".into()],
            json: true,
        })
        .expect("merge");
        let lineage = run_remote_lineage(ServerLineageArgs {
            server_addr,
            stream_id: "task.merge".into(),
            json: true,
        })
        .expect("lineage");
        let tail_open = run_remote_tail_open(ServerTailOpenArgs {
            server_addr,
            stream_id: "task.root".into(),
            from_offset: 0,
            credit: 1,
            json: true,
        })
        .expect("tail open");
        engine
            .append(&root_stream, b"second")
            .expect("append second");
        let tail_poll = run_remote_tail_poll(ServerTailPollArgs {
            server_addr,
            session_id: tail_open.session_id.clone(),
            credit: 1,
            json: true,
        })
        .expect("tail poll");
        let tail_cancel = run_remote_tail_cancel(ServerTailCancelArgs {
            server_addr,
            session_id: tail_open.session_id.clone(),
            json: true,
        })
        .expect("tail cancel");

        assert_eq!(root.stream_id, "task.root");
        assert_eq!(append.position, "task.root@0");
        assert_eq!(read.record_count, 1);
        assert_eq!(branch.stream_id, "task.branch");
        assert_eq!(second_branch.stream_id, "task.branch-two");
        assert_eq!(merge.stream_id, "task.merge");
        assert_eq!(lineage.lineage_kind, "merge");
        assert_eq!(tail_open.delivered_credit, 1);
        assert_eq!(tail_poll.delivered_credit, 1);
        assert_eq!(tail_cancel.state, "cancelled");

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_cli_helpers_surface_ack_position_and_lineage_details() {
        let (_temp_dir, server, server_addr) = start_server();
        let root = run_remote_create_root(ServerCreateRootArgs {
            server_addr,
            stream_id: "task.root".into(),
            actor: Some("classifier".into()),
            reason: Some("bootstrap".into()),
            labels: vec!["kind=root".into()],
            json: true,
        })
        .expect("create root stream");
        let append = run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: "task.root".into(),
            payload_text: "hello".into(),
            json: true,
        })
        .expect("append");
        let branch = run_remote_branch(ServerBranchArgs {
            server_addr,
            stream_id: "task.thread".into(),
            parent_stream_id: "task.root".into(),
            parent_offset: 0,
            actor: Some("classifier".into()),
            reason: Some("split".into()),
            labels: vec!["anchor=msg-42".into()],
            json: true,
        })
        .expect("branch");
        let lineage = run_remote_lineage(ServerLineageArgs {
            server_addr,
            stream_id: "task.thread".into(),
            json: true,
        })
        .expect("lineage");

        assert!(!append.request_id.is_empty());
        assert_eq!(append.durability, "local");
        assert_eq!(append.topology, "single_node");
        assert_eq!(append.position, "task.root@0");
        assert!(!root.request_id.is_empty());
        assert_eq!(root.durability, "local");
        assert!(!branch.request_id.is_empty());
        assert_eq!(branch.durability, "local");
        assert_eq!(lineage.stream_id, "task.thread");
        assert_eq!(lineage.lineage_kind, "branch");
        assert_eq!(lineage.parents, vec!["task.root".to_owned()]);

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_cli_results_serialize_cleanly_for_mission_proof_scripts() {
        let (_temp_dir, server, server_addr) = start_server();
        let root = run_remote_create_root(ServerCreateRootArgs {
            server_addr,
            stream_id: "task.root".into(),
            actor: Some("proof".into()),
            reason: Some("bootstrap".into()),
            labels: vec![],
            json: true,
        })
        .expect("create root stream");

        let append = run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: "task.root".into(),
            payload_text: "proof".into(),
            json: true,
        })
        .expect("append");
        let lineage = run_remote_lineage(ServerLineageArgs {
            server_addr,
            stream_id: "task.root".into(),
            json: true,
        })
        .expect("lineage");

        let root_json = serde_json::to_value(&root).expect("serialize root");
        let append_json = serde_json::to_value(&append).expect("serialize append");
        let lineage_json = serde_json::to_value(&lineage).expect("serialize lineage");

        assert_eq!(
            root_json
                .get("stream_id")
                .and_then(serde_json::Value::as_str),
            Some("task.root")
        );
        assert_eq!(
            append_json
                .get("durability")
                .and_then(serde_json::Value::as_str),
            Some("local")
        );
        assert_eq!(
            append_json
                .get("position")
                .and_then(serde_json::Value::as_str),
            Some("task.root@0")
        );
        assert_eq!(
            lineage_json
                .get("lineage_kind")
                .and_then(serde_json::Value::as_str),
            Some("root")
        );
        assert!(lineage_json.get("request_id").is_some());

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn networked_server_proof_exercises_remote_mission_path_and_transport_boundary() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_networked_server_proof(temp_dir.path().join("networked-server"))
            .expect("networked server proof");

        assert_eq!(proof.durability, "local");
        assert_eq!(proof.topology, "single_node");
        assert_eq!(proof.initial_append.position, "mission.root@0");
        assert_eq!(proof.tail_append.position, "mission.root@1");
        assert_eq!(proof.merge_lineage.lineage_kind, "merge");
        assert_eq!(
            proof.merge_lineage.parents,
            vec!["mission.branch".to_owned(), "mission.branch-two".to_owned()]
        );
        assert_eq!(proof.transport.replication_scope, "single_node_only");
        assert!(
            proof
                .transport
                .wireguard_role
                .contains("optional secure underlay")
        );
        assert!(proof.accepted_connections >= 9);
    }
}
