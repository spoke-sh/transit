use anyhow::{Context, Result, bail, ensure};
use clap::{Args, Parser, Subcommand};
use object_store::local::LocalFileSystem;
use serde::Serialize;
use std::collections::BTreeMap;
use std::fs::{self, OpenOptions};
use std::io::{self, BufRead, IsTerminal, Write};
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::time::Duration;
use transit_client::TransitClient;
use transit_core::config::{LoadedTransitConfig, load_transit_config};
use transit_core::engine::{
    LocalEngine, LocalEngineConfig, LocalRecord, LocalRecoveryOutcome, OwnershipPosture,
    inspect_local_log,
};
use transit_core::kernel::{
    LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset, StreamDescriptor, StreamId,
    StreamLineage, StreamPosition,
};
use transit_core::membership::NodeId;
use transit_core::object_store_support::{
    StorageProbeResult, build_loaded_runtime_object_store, probe_effective_storage,
};
use transit_core::server::{
    RemoteClient, ServerConfig, ServerHandle, ServerShutdownOutcome, TailSessionId,
};
use transit_materialize::engine::LocalMaterializationEngine;
use transit_materialize::prolly::{
    LeafEntry, ObjectStoreProllyStore, ProllyTreeBuilder, SnapshotManifest,
};
use transit_materialize::{
    MaterializationCheckpoint, Reducer, ReferenceProjectionMaterializer, ReferenceProjectionReducer,
};
use transit_server::bind_read_only_replica_from_frontier;

#[derive(Debug, Parser)]
#[command(name = "transit")]
#[command(about = "Object-storage-native append-only log bootstrap")]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Transit configuration file. Defaults to the documented search order.
    #[arg(long, global = true)]
    config: Option<PathBuf>,

    /// Unique identity of this node in the cluster.
    #[arg(long, global = true)]
    node_id: Option<String>,
}

#[derive(Debug, Subcommand)]
enum Commands {
    /// Show the state of the local transit log.
    Status(StatusArgs),
    /// Manage streams through the hosted transit server.
    Streams(StreamsArgs),
    /// Produce records to a stream through the hosted transit server.
    Produce(ProduceArgs),
    /// Consume records from a stream through the hosted transit server.
    Consume(ConsumeArgs),
    /// Run the human-oriented proof workflows.
    Proof(ProofArgs),
    /// Run local verification workflows.
    Verify(VerifyArgs),
    /// Create a verifiable checkpoint for a stream head.
    Checkpoint(CheckpointArgs),
    /// Probe configured storage support and guarantees.
    Storage(StorageArgs),
    /// Run the shared-engine server daemon.
    Server(ServerArgs),
}

#[derive(Debug, Args)]
struct ProofArgs {
    #[command(subcommand)]
    command: ProofCommands,
}

#[derive(Debug, Subcommand)]
enum ProofCommands {
    /// Exercise append, replay, lineage, and crash recovery in one local proof.
    LocalEngine(LocalEngineProofArgs),
    /// Exercise publication and cold restore through the shared local engine.
    TieredEngine(LocalEngineProofArgs),
    /// Exercise readiness, lease handoff, and stale-primary fencing for the bounded failover slice.
    ControlledFailover(LocalEngineProofArgs),
    /// Exercise automatic leader election and primary fencing after a simulated failure.
    ChaosFailover(LocalEngineProofArgs),
    /// Exercise the networked single-node server and its transport boundary end to end.
    NetworkedServer(LocalEngineProofArgs),
    /// Exercise thin-client producers and readers against a hosted transit-server authority.
    HostedAuthority(LocalEngineProofArgs),
    /// Exercise server restart and warm-cache recovery from the authoritative remote tier.
    WarmCacheRecovery(LocalEngineProofArgs),
    /// Exercise segment, manifest-root, checkpoint, tamper, and server-parity verification across the integrity proof flow.
    Integrity(IntegrityProofArgs),
    /// Exercise checkpoint and resume through the materialization engine.
    Materialization(MaterializationProofArgs),
    /// Exercise checkpoint resume and authoritative replay equivalence for reference projections.
    ReferenceProjection(MaterializationProofArgs),
}

#[derive(Debug, Args)]
struct StatusArgs {
    /// Filesystem root used for the shared local engine. Defaults to configured [node].data_dir.
    #[arg(long)]
    root: Option<PathBuf>,
    /// Optional stream identifier to inspect instead of listing every stream under the root.
    #[arg(long = "stream-id")]
    stream_id: Option<String>,
    /// Render log status as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct StreamsArgs {
    #[command(subcommand)]
    command: StreamsCommands,
}

#[derive(Debug, Subcommand)]
enum StreamsCommands {
    /// List streams currently hosted by the server.
    List(StreamsListArgs),
    /// Create a new root stream on the server.
    Create(StreamsCreateArgs),
    /// Delete a stream from the server.
    Delete(StreamsDeleteArgs),
}

#[derive(Debug, Args)]
struct StreamsListArgs {
    /// Transit server address. Defaults to configured [server].listen_addr.
    #[arg(long = "server-addr")]
    server_addr: Option<SocketAddr>,
    /// Render list output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct StreamsCreateArgs {
    /// Transit server address. Defaults to configured [server].listen_addr.
    #[arg(long = "server-addr")]
    server_addr: Option<SocketAddr>,
    /// Stream identifier to create.
    #[arg(long = "stream-id")]
    stream_id: String,
    /// Optional lineage actor.
    #[arg(long)]
    actor: Option<String>,
    /// Optional lineage reason.
    #[arg(long)]
    reason: Option<String>,
    /// Optional lineage labels in key=value form.
    #[arg(long = "label")]
    labels: Vec<String>,
    /// Render create output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct StreamsDeleteArgs {
    /// Transit server address. Defaults to configured [server].listen_addr.
    #[arg(long = "server-addr")]
    server_addr: Option<SocketAddr>,
    /// Stream identifier to delete.
    #[arg(long = "stream-id")]
    stream_id: String,
    /// Acknowledge the destructive delete.
    #[arg(long)]
    force: bool,
    /// Render delete output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ProduceArgs {
    /// Transit server address. Defaults to configured [server].listen_addr.
    #[arg(long = "server-addr")]
    server_addr: Option<SocketAddr>,
    /// Stream identifier to append to.
    #[arg(long = "stream-id")]
    stream_id: String,
    /// Append one payload. Repeat to send multiple records; if omitted, newline-delimited stdin is used.
    #[arg(long = "payload-text")]
    payload_text: Vec<String>,
    /// Render produce output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct ConsumeArgs {
    /// Transit server address. Defaults to configured [server].listen_addr.
    #[arg(long = "server-addr")]
    server_addr: Option<SocketAddr>,
    /// Stream identifier to read from.
    #[arg(long = "stream-id")]
    stream_id: String,
    /// Starting offset for consumption.
    #[arg(long = "from-offset", default_value_t = 0)]
    from_offset: u64,
    /// Optional maximum record count.
    #[arg(long)]
    limit: Option<usize>,
    /// Prefix each emitted record with its stream position.
    #[arg(long = "with-offsets")]
    with_offsets: bool,
    /// Render consume output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct LocalEngineProofArgs {
    /// Filesystem root used for the local durable-engine proof. Defaults to configured [node].data_dir.
    #[arg(long)]
    root: Option<PathBuf>,
    /// Render proof output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct IntegrityProofArgs {
    /// Filesystem root used for the local integrity proof. Defaults to configured [node].data_dir.
    #[arg(long)]
    root: Option<PathBuf>,
    /// Render proof output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct MaterializationProofArgs {
    /// Filesystem root used for the local materialization proof. Defaults to configured [node].data_dir.
    #[arg(long)]
    root: Option<PathBuf>,
    /// Render proof output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct VerifyArgs {
    #[command(subcommand)]
    command: VerifyCommands,
}

#[derive(Debug, Subcommand)]
enum VerifyCommands {
    /// Explicitly verify the cryptographic integrity of local history.
    Lineage(VerifyLineageArgs),
    /// Verify an existing lineage checkpoint.
    Checkpoint(VerifyCheckpointArgs),
}

#[derive(Debug, Args)]
struct VerifyLineageArgs {
    /// Filesystem root used for the shared local engine. Defaults to configured [node].data_dir.
    #[arg(long)]
    root: Option<PathBuf>,
    /// Stream identifier to verify.
    #[arg(long = "stream-id")]
    stream_id: String,
    /// Render verification output as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct CheckpointArgs {
    /// Filesystem root used for the shared local engine. Defaults to configured [node].data_dir.
    #[arg(long)]
    root: Option<PathBuf>,
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
    /// Filesystem root used for the shared local engine. Defaults to configured [node].data_dir.
    #[arg(long)]
    root: Option<PathBuf>,
    /// Path to the JSON checkpoint file to verify.
    #[arg(long)]
    checkpoint_path: PathBuf,
    /// Render verification result as JSON.
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Args)]
struct StorageArgs {
    #[command(subcommand)]
    command: StorageCommands,
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
    /// Append one or more records through the remote server API.
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
    /// Filesystem root used for the shared local engine. Defaults to configured [node].data_dir.
    #[arg(long)]
    root: Option<PathBuf>,
    /// Listen address for the first server daemon. Defaults to configured [server].listen_addr.
    #[arg(long = "listen-addr")]
    listen_addr: Option<SocketAddr>,
    /// Run for a bounded time before graceful shutdown. Useful for tests and proofs.
    #[arg(long = "serve-for-ms")]
    serve_for_ms: Option<u64>,
    /// Unique identifier for this node in the cluster.
    #[arg(long = "node-id")]
    node_id: Option<String>,
    /// Object store root used for consensus leases.
    #[arg(long = "consensus-root")]
    consensus_root: Option<PathBuf>,
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
    #[arg(long = "payload-text", required = true)]
    payload_text: Vec<String>,
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
enum StorageCommands {
    /// Verify the effective local storage configuration and guarantee class.
    Probe(StorageProbeArgs),
}

#[derive(Debug, Args)]
struct StorageProbeArgs {
    /// Render probe output as JSON.
    #[arg(long)]
    json: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    let config = load_transit_config(cli.config.clone())?;

    match cli.command {
        Commands::Status(args) => render_status(
            run_status(
                resolve_local_root(args.root, &config),
                args.stream_id.as_deref(),
            )?,
            args.json,
        )?,
        Commands::Streams(args) => match args.command {
            StreamsCommands::List(args) => {
                let json = args.json;
                render_streams_list(
                    run_streams_list(resolve_server_addr(args.server_addr, &config))?,
                    json,
                )?
            }
            StreamsCommands::Create(args) => {
                let json = args.json;
                let server_addr = resolve_server_addr(args.server_addr, &config);
                render_remote_stream_status(run_streams_create(server_addr, args)?, json)?
            }
            StreamsCommands::Delete(args) => {
                let json = args.json;
                let server_addr = resolve_server_addr(args.server_addr, &config);
                render_streams_delete(run_streams_delete(server_addr, args)?, json)?
            }
        },
        Commands::Produce(args) => {
            let json = args.json;
            let server_addr = resolve_server_addr(args.server_addr, &config);
            render_produce(run_produce(server_addr, args)?, json)?
        }
        Commands::Consume(args) => {
            let with_offsets = args.with_offsets;
            let json = args.json;
            let server_addr = resolve_server_addr(args.server_addr, &config);
            render_consume(run_consume(server_addr, args)?, with_offsets, json)?
        }
        Commands::Proof(args) => match args.command {
            ProofCommands::LocalEngine(args) => render_local_engine_proof(
                run_local_engine_proof(resolve_local_root(args.root, &config))?,
                args.json,
            )?,
            ProofCommands::TieredEngine(args) => render_tiered_engine_proof(
                run_tiered_engine_proof(resolve_local_root(args.root, &config)).await?,
                args.json,
            )?,
            ProofCommands::ControlledFailover(args) => render_controlled_failover_proof(
                run_controlled_failover_proof(resolve_local_root(args.root, &config)).await?,
                args.json,
            )?,
            ProofCommands::ChaosFailover(args) => render_chaos_failover_proof(
                run_chaos_failover_proof(resolve_local_root(args.root, &config)).await?,
                args.json,
            )?,
            ProofCommands::NetworkedServer(args) => render_networked_server_proof(
                run_networked_server_proof(resolve_local_root(args.root, &config))?,
                args.json,
            )?,
            ProofCommands::HostedAuthority(args) => render_hosted_authority_proof(
                run_hosted_authority_proof(resolve_local_root(args.root, &config))?,
                args.json,
            )?,
            ProofCommands::WarmCacheRecovery(args) => render_warm_cache_recovery_proof(
                run_warm_cache_recovery_proof(resolve_local_root(args.root, &config)).await?,
                args.json,
            )?,
            ProofCommands::Integrity(args) => render_integrity_proof(
                run_integrity_proof(resolve_local_root(args.root, &config)).await?,
                args.json,
            )?,
            ProofCommands::Materialization(args) => render_materialization_proof(
                run_materialization_proof(resolve_local_root(args.root, &config)).await?,
                args.json,
            )?,
            ProofCommands::ReferenceProjection(args) => render_reference_projection_proof(
                run_reference_projection_proof(resolve_local_root(args.root, &config)).await?,
                args.json,
            )?,
        },
        Commands::Verify(args) => match args.command {
            VerifyCommands::Lineage(args) => render_verify_lineage(
                run_verify_lineage(resolve_local_root(args.root, &config), &args.stream_id)?,
                args.json,
            )?,
            VerifyCommands::Checkpoint(args) => render_verify_checkpoint(
                run_verify_checkpoint(
                    resolve_local_root(args.root, &config),
                    &args.checkpoint_path,
                )?,
                args.json,
            )?,
        },
        Commands::Checkpoint(args) => render_checkpoint(
            run_checkpoint(
                resolve_local_root(args.root, &config),
                &args.stream_id,
                &args.kind,
            )?,
            args.json,
        )?,
        Commands::Storage(args) => match args.command {
            StorageCommands::Probe(args) => {
                render_storage_probe(probe_effective_storage(&config).await?, args.json)?
            }
        },
        Commands::Server(args) => match args.command {
            ServerCommands::Run(args) => {
                let json = args.json;
                render_server_run(run_server(args, &config).await?, json)?
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

fn resolve_local_root(root: Option<PathBuf>, config: &LoadedTransitConfig) -> PathBuf {
    root.unwrap_or_else(|| config.config().node.data_dir.clone())
}

fn resolve_server_addr(
    server_addr: Option<SocketAddr>,
    config: &LoadedTransitConfig,
) -> SocketAddr {
    server_addr.unwrap_or(config.config().server.listen_addr)
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

fn run_verify_lineage(root: PathBuf, stream_id: &str) -> Result<VerifyLineageOutcome> {
    use transit_core::engine::{LocalEngine, LocalEngineConfig};
    use transit_core::kernel::StreamId;

    let engine = LocalEngine::open(LocalEngineConfig::new(&root, NodeId::new("cli-node")))?;
    let stream_id = StreamId::new(stream_id)?;

    match engine.verify_local_lineage(&stream_id) {
        Ok(lineage) => Ok(VerifyLineageOutcome {
            stream_id: stream_id.as_str().to_owned(),
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
            stream_id: stream_id.as_str().to_owned(),
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

    println!(
        "transit integrity: verification profile for '{}'",
        outcome.stream_id
    );
    println!("trust anchor: manifest_root={}", outcome.manifest_root);
    println!("manifest_id: {}", outcome.manifest_id);

    if outcome.verified {
        println!("\nTrust Chain:");
        println!("  [ROOT] -> {}", outcome.manifest_root);
        for segment in &outcome.segments {
            println!(
                "    |-- [SEGMENT] {} (offsets {}..{}) [PASS]",
                segment.segment_id, segment.start_offset, segment.last_offset
            );
        }

        if !outcome.segments.is_empty() {
            println!("\nVerification Map (Offset vs Integrity):");
            let mut points = Vec::new();
            for segment in &outcome.segments {
                points.push((segment.start_offset as f32, 100.0));
                points.push((segment.last_offset as f32, 100.0));
            }
            let max_offset = outcome
                .segments
                .last()
                .map(|s| s.last_offset as f32)
                .unwrap_or(1.0);
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

fn run_checkpoint(root: PathBuf, stream_id: &str, kind: &str) -> Result<CheckpointOutcome> {
    use transit_core::engine::{LocalEngine, LocalEngineConfig};
    use transit_core::kernel::StreamId;

    let engine = LocalEngine::open(LocalEngineConfig::new(&root, NodeId::new("cli-node")))?;
    let stream_id = StreamId::new(stream_id)?;
    let checkpoint = engine.checkpoint(&stream_id, kind)?;

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

fn run_verify_checkpoint(root: PathBuf, checkpoint_path: &Path) -> Result<VerifyCheckpointOutcome> {
    use transit_core::engine::{LocalEngine, LocalEngineConfig};
    use transit_core::storage::LineageCheckpoint;

    let engine = LocalEngine::open(LocalEngineConfig::new(&root, NodeId::new("cli-node")))?;
    let bytes = fs::read(checkpoint_path).context("read checkpoint file")?;
    let checkpoint: LineageCheckpoint =
        serde_json::from_slice(&bytes).context("parse checkpoint")?;

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

#[derive(Debug, Serialize)]
struct TransitLogStatusResult {
    root: PathBuf,
    initialized: bool,
    state: String,
    stream_count: usize,
    streams: Vec<TransitLogStreamStatusResult>,
}

#[derive(Debug, Serialize)]
struct TransitLogStreamStatusResult {
    stream_id: String,
    lineage_kind: String,
    parents: Vec<String>,
    merge_base: Option<String>,
    record_count: u64,
    head_offset: Option<u64>,
    next_offset: u64,
    active_record_count: u64,
    active_segment_start_offset: u64,
    manifest_generation: u64,
    rolled_segment_count: usize,
    published_frontier: Option<PublishedFrontierStatusResult>,
}

#[derive(Debug, Serialize)]
struct PublishedFrontierStatusResult {
    manifest_generation: u64,
    manifest_root: String,
    next_offset: u64,
    start_offset: Option<u64>,
    last_offset: Option<u64>,
    segment_count: usize,
}

fn run_status(root: PathBuf, stream_filter: Option<&str>) -> Result<TransitLogStatusResult> {
    let status = inspect_local_log(&root)?;
    let stream_filter = stream_filter.map(parse_stream_id_arg).transpose()?;

    let mut streams = status
        .streams()
        .iter()
        .map(summarize_local_log_stream_status)
        .collect::<Vec<_>>();

    if let Some(stream_filter) = stream_filter.as_ref() {
        streams.retain(|stream| stream.stream_id == stream_filter.as_str());
        ensure!(
            !streams.is_empty(),
            "stream '{}' not found under {}",
            stream_filter.as_str(),
            root.display()
        );
    }

    let state = if !status.initialized() {
        "uninitialized"
    } else if status.streams().is_empty() {
        "empty"
    } else {
        "active"
    };

    Ok(TransitLogStatusResult {
        root: status.data_dir().to_path_buf(),
        initialized: status.initialized(),
        state: state.to_owned(),
        stream_count: streams.len(),
        streams,
    })
}

fn summarize_descriptor_lineage(
    descriptor: &StreamDescriptor,
) -> (String, Vec<String>, Option<String>) {
    match &descriptor.lineage {
        StreamLineage::Root { .. } => ("root".to_owned(), Vec::new(), None),
        StreamLineage::Branch { branch_point } => (
            "branch".to_owned(),
            vec![render_position(branch_point.parent.clone())],
            None,
        ),
        StreamLineage::Merge { merge } => (
            "merge".to_owned(),
            merge.parents.iter().cloned().map(render_position).collect(),
            merge.merge_base.clone().map(render_position),
        ),
    }
}

fn summarize_local_log_stream_status(
    status: &transit_core::engine::LocalLogStreamStatus,
) -> TransitLogStreamStatusResult {
    let (lineage_kind, parents, merge_base) = summarize_descriptor_lineage(status.descriptor());
    let next_offset = status.next_offset().value();

    TransitLogStreamStatusResult {
        stream_id: status.descriptor().stream_id.as_str().to_owned(),
        lineage_kind,
        parents,
        merge_base,
        record_count: next_offset,
        head_offset: next_offset.checked_sub(1),
        next_offset,
        active_record_count: status.active_record_count(),
        active_segment_start_offset: status.active_segment_start_offset().value(),
        manifest_generation: status.manifest_generation(),
        rolled_segment_count: status.rolled_segment_count(),
        published_frontier: status.published_frontier().map(|frontier| {
            PublishedFrontierStatusResult {
                manifest_generation: frontier.manifest_generation(),
                manifest_root: frontier.manifest_root().digest().to_string(),
                next_offset: frontier.next_offset().value(),
                start_offset: frontier.start_offset().map(Offset::value),
                last_offset: frontier.last_offset().map(Offset::value),
                segment_count: frontier.published_segments().len(),
            }
        }),
    }
}

fn summarize_remote_stream_summary(
    summary: &transit_core::server::RemoteStreamSummary,
) -> RemoteStreamSummaryResult {
    let (lineage_kind, parents, merge_base) = summarize_descriptor_lineage(summary.descriptor());
    let next_offset = summary.status().next_offset().value();

    RemoteStreamSummaryResult {
        stream_id: summary.descriptor().stream_id.as_str().to_owned(),
        lineage_kind,
        parents,
        merge_base,
        record_count: next_offset,
        head_offset: next_offset.checked_sub(1),
        active_record_count: summary.status().active_record_count(),
        active_segment_start_offset: summary.status().active_segment_start_offset().value(),
        manifest_generation: summary.status().manifest_generation(),
        rolled_segment_count: summary.status().rolled_segment_count(),
    }
}

fn render_status(status: TransitLogStatusResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&status)?);
        return Ok(());
    }

    println!("transit status");
    println!("root: {}", status.root.display());
    println!("state: {}", status.state);
    println!("streams: {}", status.stream_count);

    if status.streams.is_empty() {
        if status.initialized {
            println!("log: initialized with no streams");
        } else {
            println!("log: no stream state exists under this root yet");
        }
        return Ok(());
    }

    for stream in status.streams {
        println!();
        println!("stream: {}", stream.stream_id);
        println!("lineage: {}", stream.lineage_kind);
        if stream.parents.is_empty() {
            println!("parents: none");
        } else {
            println!("parents: {}", stream.parents.join(", "));
        }
        if let Some(merge_base) = stream.merge_base {
            println!("merge base: {merge_base}");
        }
        println!("records: {}", stream.record_count);
        match stream.head_offset {
            Some(head_offset) => println!("head offset: {head_offset}"),
            None => println!("head offset: empty"),
        }
        println!("next offset: {}", stream.next_offset);
        println!("active records: {}", stream.active_record_count);
        println!(
            "active segment start offset: {}",
            stream.active_segment_start_offset
        );
        println!("manifest generation: {}", stream.manifest_generation);
        println!("rolled segments: {}", stream.rolled_segment_count);

        if let Some(frontier) = stream.published_frontier {
            println!(
                "published frontier: generation {} next offset {}",
                frontier.manifest_generation, frontier.next_offset
            );
            match (frontier.start_offset, frontier.last_offset) {
                (Some(start_offset), Some(last_offset)) => {
                    println!("published range: {start_offset}..{last_offset}");
                }
                _ => println!("published range: none"),
            }
            println!("published segments: {}", frontier.segment_count);
            println!("published manifest root: {}", frontier.manifest_root);
        } else {
            println!("published frontier: none");
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

#[derive(Debug, Serialize)]
struct TieredEngineProofResult {
    data_root: PathBuf,
    durability: String,
    publish_stream: StreamProofSummary,
    restored_stream: StreamProofSummary,
    published_frontier: PublishedFrontierResult,
    replicated_ack: ReplicatedAckResult,
    commitment_surface: CommitmentSurfaceResult,
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
struct OwnershipPostureResult {
    posture: String,
    lease_owner: Option<String>,
    lease_version: Option<u64>,
    lease_expires_at: Option<i64>,
}

#[derive(Debug, Serialize)]
struct LocalAppendProofResult {
    position: String,
    durability: String,
    manifest_generation: u64,
    rolled_segment_id: Option<String>,
}

#[derive(Debug, Serialize)]
struct ControlledFailoverReadinessResult {
    source_replicated_ack: ReplicatedAckResult,
    restore_next_offset: u64,
    required_frontier: PublishedFrontierResult,
    local_frontier: Option<PublishedFrontierResult>,
    candidate_posture: OwnershipPostureResult,
    frontier_caught_up: bool,
    ownership_ready: bool,
    promotable: bool,
    blockers: Vec<String>,
}

#[derive(Debug, Serialize)]
struct ControlledFailoverHandoffResult {
    stream_id: String,
    previous_owner: String,
    new_owner: String,
    lease_version: u64,
    expires_at: i64,
    manifest_generation: u64,
    frontier_next_offset: u64,
    promoted_posture: OwnershipPostureResult,
    promoted_append: LocalAppendProofResult,
}

#[derive(Debug, Serialize)]
struct ControlledFailoverFencingResult {
    former_primary_posture: OwnershipPostureResult,
    former_primary_append_rejected: bool,
    rejection: Option<String>,
}

#[derive(Debug, Serialize)]
struct ControlledFailoverContractResult {
    local: &'static str,
    replicated: &'static str,
    tiered: &'static str,
    quorum: &'static str,
    multi_primary: &'static str,
    automation: &'static str,
}

#[derive(Debug, Serialize)]
struct ControlledFailoverProofResult {
    data_root: PathBuf,
    stream_id: String,
    readiness: ControlledFailoverReadinessResult,
    handoff: ControlledFailoverHandoffResult,
    fencing: ControlledFailoverFencingResult,
    contract: ControlledFailoverContractResult,
    verified: bool,
    error: Option<String>,
}

#[derive(Debug, Serialize)]
struct ChaosFailoverElectionResult {
    trigger_reason: String,
    new_owner: String,
    lease_version: u64,
    expires_at: i64,
    election_duration_ms: u64,
}

#[derive(Debug, Serialize)]
struct ChaosFailoverProofResult {
    data_root: PathBuf,
    stream_id: String,
    primary_failure_simulated: bool,
    election: ChaosFailoverElectionResult,
    promoted_append: LocalAppendProofResult,
    former_primary_fenced: bool,
    former_primary_rejection: Option<String>,
    verified: bool,
    error: Option<String>,
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
struct HostedAuthorityProofResult {
    data_root: PathBuf,
    server_addr: String,
    durability: String,
    topology: String,
    stream_id: String,
    root_stream: RemoteStreamStatusResult,
    producer_appends: Vec<RemoteAppendResult>,
    reader_replay: RemoteReadResult,
    acknowledged_payloads: Vec<String>,
    replay_matches_acknowledged_history: bool,
    remote_tier_publication_performed: bool,
    authority_surface: &'static str,
    consumer_boundary: &'static str,
    tiered_non_claim: &'static str,
    embedded_authority_used: bool,
    accepted_connections: u64,
    graceful_shutdown: bool,
    server_api: &'static str,
    remote_api: &'static str,
}

#[derive(Debug, Serialize)]
struct WarmCacheRecoveryHydrationResult {
    server_addr: String,
    bootstrapped: bool,
    restored_segment_ids: Vec<String>,
    replay: RemoteReadResult,
    accepted_connections: u64,
    graceful_shutdown: bool,
}

#[derive(Debug, Serialize)]
struct WarmCacheRecoveryProofResult {
    data_root: PathBuf,
    stream_id: String,
    local_write_durability: String,
    authoritative_recovery_durability: String,
    published_frontier: PublishedFrontierResult,
    warm_cache_removed: bool,
    initial_hydrate: WarmCacheRecoveryHydrationResult,
    restart_hydrate: WarmCacheRecoveryHydrationResult,
    restored_history_matches: bool,
    local_non_claim: &'static str,
    authoritative_source: &'static str,
    server_api: &'static str,
    remote_api: &'static str,
}

#[derive(Debug, Clone, Serialize, serde::Deserialize, PartialEq, Eq)]
struct ReferenceProjectionProofView {
    display_name: String,
    status: String,
}

#[derive(Debug, Clone, Serialize, serde::Deserialize)]
struct ReferenceProjectionProofEvent {
    reference_id: String,
    display_name: String,
    status: String,
    deleted: bool,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct ReferenceProjectionProofCheckpointResult {
    stream_id: String,
    head_offset: u64,
    manifest_root: String,
    kind: String,
    verified: bool,
    shared_model_verified: bool,
    error: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct ReferenceProjectionProofResumeResult {
    appended_after_checkpoint: usize,
    replay_from_offset: u64,
    source_next_offset: u64,
    pending_record_count: u64,
    resumed_view: BTreeMap<String, ReferenceProjectionProofView>,
    resumed_reference_count: usize,
    resumed_only_new_history: bool,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct ReferenceProjectionProofRebuildResult {
    authoritative_record_count: usize,
    rebuilt_view: BTreeMap<String, ReferenceProjectionProofView>,
    rebuilt_reference_count: usize,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct ReferenceProjectionProofResult {
    data_root: PathBuf,
    durability: String,
    stream_id: String,
    materialization_id: String,
    materialization_api: &'static str,
    checkpoint_api: &'static str,
    checkpoint_anchor_api: &'static str,
    checkpoint_verification_api: &'static str,
    resume_api: &'static str,
    authoritative_replay_api: &'static str,
    checkpoint: ReferenceProjectionProofCheckpointResult,
    resume: ReferenceProjectionProofResumeResult,
    rebuild: ReferenceProjectionProofRebuildResult,
    equivalent_views: bool,
    projection_only_authority_used: bool,
    verified: bool,
    error: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct IntegrityProofSegmentResult {
    segment_id: String,
    start_offset: u64,
    last_offset: u64,
    record_count: u64,
    byte_length: u64,
    checksum_algorithm: String,
    checksum_digest: String,
    checksum_verified: bool,
    content_digest_algorithm: String,
    content_digest: String,
    content_digest_verified: bool,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct IntegrityProofPublicationResult {
    published_segment_ids: Vec<String>,
    manifest_object_key: String,
}

#[derive(Debug, Serialize)]
struct PublishedFrontierSegmentResult {
    segment_id: String,
    start_offset: u64,
    last_offset: u64,
    object_store_key: String,
}

#[derive(Debug, Serialize)]
struct PublishedFrontierResult {
    manifest_id: String,
    manifest_generation: u64,
    manifest_root: String,
    manifest_object_key: String,
    start_offset: Option<u64>,
    last_offset: Option<u64>,
    next_offset: u64,
    segments: Vec<PublishedFrontierSegmentResult>,
}

#[derive(Debug, Serialize)]
struct ReplicatedAckResult {
    commitment: String,
    position: String,
    manifest_generation: u64,
    frontier_next_offset: u64,
    manifest_object_key: String,
    published_segment_ids: Vec<String>,
    rolled_segment_id: Option<String>,
    non_claim: &'static str,
}

#[derive(Debug, Serialize)]
struct CommitmentSurfaceResult {
    local_head_offset: Option<u64>,
    replicated_frontier_offset: Option<u64>,
    tiered_restore_offset: Option<u64>,
    unpublished_local_records: usize,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct IntegrityProofRestoreResult {
    stream_id: String,
    restored_segment_ids: Vec<String>,
    manifest_generation: u64,
    manifest_root: String,
    manifest_roots_match: bool,
    next_offset: u64,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct IntegrityProofCheckpointResult {
    stream_id: String,
    lineage_kind: String,
    head_offset: u64,
    manifest_root: String,
    kind: String,
    verified: bool,
    error: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct IntegrityProofTamperResult {
    data_root: PathBuf,
    stream_id: String,
    segment_id: String,
    corrupted_path: PathBuf,
    verification_api: &'static str,
    detected: bool,
    error: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct IntegrityProofServerParityStreamResult {
    stream_id: String,
    remote_lineage_kind: String,
    local_lineage_kind: String,
    remote_parents: Vec<String>,
    local_parents: Vec<String>,
    remote_next_offset: u64,
    local_next_offset: u64,
    remote_manifest_generation: u64,
    local_manifest_generation: u64,
    remote_rolled_segment_count: usize,
    local_rolled_segment_count: usize,
    manifest_root: String,
    verified: bool,
    error: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct IntegrityProofServerParityResult {
    data_root: PathBuf,
    server_addr: String,
    durability: String,
    topology: String,
    verification_api: &'static str,
    remote_api: &'static str,
    server_api: &'static str,
    accepted_connections: u64,
    graceful_shutdown: bool,
    verified: bool,
    streams: Vec<IntegrityProofServerParityStreamResult>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct IntegrityProofResult {
    data_root: PathBuf,
    durability: String,
    stream_id: String,
    records_appended: usize,
    manifest_id: String,
    manifest_generation: u64,
    manifest_root: String,
    verification_api: &'static str,
    publication_api: &'static str,
    restore_api: &'static str,
    checkpoint_api: &'static str,
    checkpoint_verification_api: &'static str,
    verified: bool,
    segments: Vec<IntegrityProofSegmentResult>,
    publication: IntegrityProofPublicationResult,
    restore: IntegrityProofRestoreResult,
    checkpoints: Vec<IntegrityProofCheckpointResult>,
    tamper: IntegrityProofTamperResult,
    server_parity: IntegrityProofServerParityResult,
    error: Option<String>,
}

#[derive(Debug, Clone, Serialize, serde::Deserialize, PartialEq, Eq, Default)]
struct MaterializationProofState {
    processed_records: u64,
    last_offset: Option<u64>,
}

struct MaterializationProofCountReducer;

impl Reducer for MaterializationProofCountReducer {
    type State = MaterializationProofState;

    fn reduce(&self, state: &mut Self::State, offset: Offset, _payload: &[u8]) -> Result<()> {
        state.processed_records += 1;
        state.last_offset = Some(offset.value());
        Ok(())
    }
}

struct ReferenceProjectionProofReducer;

impl ReferenceProjectionReducer for ReferenceProjectionProofReducer {
    type View = ReferenceProjectionProofView;

    fn reduce_view(
        &self,
        state: &mut BTreeMap<String, Self::View>,
        _offset: Offset,
        payload: &[u8],
    ) -> Result<()> {
        let event: ReferenceProjectionProofEvent = serde_json::from_slice(payload)
            .context("deserialize reference projection proof event")?;

        if event.deleted {
            state.remove(&event.reference_id);
        } else {
            state.insert(
                event.reference_id,
                ReferenceProjectionProofView {
                    display_name: event.display_name,
                    status: event.status,
                },
            );
        }

        Ok(())
    }
}

fn reference_projection_proof_event(
    reference_id: &str,
    display_name: &str,
    status: &str,
    deleted: bool,
) -> Result<Vec<u8>> {
    serde_json::to_vec(&ReferenceProjectionProofEvent {
        reference_id: reference_id.to_owned(),
        display_name: display_name.to_owned(),
        status: status.to_owned(),
        deleted,
    })
    .context("serialize reference projection proof event")
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct MaterializationProofCheckpointResult {
    stream_id: String,
    head_offset: u64,
    manifest_root: String,
    kind: String,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct MaterializationProofResumeResult {
    appended_after_checkpoint: usize,
    resumed_total_count: u64,
    resumed_last_offset: Option<u64>,
    processed_new_records: u64,
    only_new_records_processed: bool,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct MaterializationProofSnapshotResult {
    snapshot_id: String,
    source_stream_id: String,
    source_head_offset: u64,
    source_manifest_root: String,
    root_digest: String,
    stored_node_count: usize,
    builder_api: &'static str,
    store_api: &'static str,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct MaterializationProofBranchResult {
    stream_id: String,
    parent_stream_id: String,
    parent_head_offset: u64,
    lineage_kind: String,
    materialization_id: String,
    branch_records_appended: usize,
    materialized_count: u64,
    checkpoint_stream_id: String,
    checkpoint_head_offset: u64,
    checkpoint_manifest_root: String,
    checkpoint_kind: String,
    snapshot: MaterializationProofSnapshotResult,
    shared_model_verified: bool,
    distinct_from_root_snapshot: bool,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
struct MaterializationProofResult {
    data_root: PathBuf,
    durability: String,
    stream_id: String,
    materialization_id: String,
    initial_records_appended: usize,
    initial_materialized_count: u64,
    materialization_api: &'static str,
    checkpoint_api: &'static str,
    checkpoint_anchor_api: &'static str,
    checkpoint: MaterializationProofCheckpointResult,
    resume: MaterializationProofResumeResult,
    snapshot: MaterializationProofSnapshotResult,
    branch: MaterializationProofBranchResult,
    verified: bool,
    error: Option<String>,
}

#[derive(Debug, Clone)]
struct MaterializationProofSnapshotArtifacts {
    result: MaterializationProofSnapshotResult,
    manifest: SnapshotManifest,
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
    last_position: String,
    record_count: u64,
    manifest_generation: u64,
    rolled_segment_ids: Vec<String>,
}

#[derive(Debug, Serialize)]
struct RemoteStreamListResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    stream_count: usize,
    streams: Vec<RemoteStreamSummaryResult>,
}

#[derive(Debug, Serialize)]
struct RemoteStreamSummaryResult {
    stream_id: String,
    lineage_kind: String,
    parents: Vec<String>,
    merge_base: Option<String>,
    record_count: u64,
    head_offset: Option<u64>,
    active_record_count: u64,
    active_segment_start_offset: u64,
    manifest_generation: u64,
    rolled_segment_count: usize,
}

#[derive(Debug, Serialize)]
struct RemoteDeletedStreamResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    stream_id: String,
    deleted_path: PathBuf,
    record_count: u64,
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

#[derive(Debug, Serialize)]
struct ProduceResult {
    server_addr: String,
    stream_id: String,
    append_count: usize,
    last_position: Option<String>,
    appends: Vec<RemoteAppendResult>,
}

#[derive(Debug, Serialize)]
struct ConsumeResult {
    server_addr: String,
    request_id: String,
    durability: String,
    topology: String,
    stream_id: String,
    from_offset: u64,
    record_count: usize,
    head_offset: Option<u64>,
    records: Vec<RemoteRecordView>,
}

fn run_local_engine_proof(root: PathBuf) -> Result<LocalEngineProofResult> {
    reset_directory(&root)?;

    let engine = LocalEngine::open(
        LocalEngineConfig::new(&root, NodeId::new("cli-node")).with_segment_max_records(2)?,
    )
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
        merge_base: merge_spec.merge_base.map(render_position),
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
        LocalEngineConfig::new(&root, NodeId::new("cli-node")).with_segment_max_records(2)?,
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
        payload_text: vec!["root-0".into()],
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
        payload_text: vec!["root-1".into()],
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

fn run_hosted_authority_proof(root: PathBuf) -> Result<HostedAuthorityProofResult> {
    reset_directory(&root)?;

    let requested_listen_addr = "127.0.0.1:0"
        .parse::<SocketAddr>()
        .context("parse hosted authority proof listen addr")?;
    let server = ServerHandle::bind(ServerConfig::new(
        LocalEngineConfig::new(&root, NodeId::new("cli-node")).with_segment_max_records(4)?,
        requested_listen_addr,
    ))
    .context("bind hosted authority proof daemon")?;
    let server_addr = server.local_addr();

    let proof = (|| -> Result<_> {
        let client = TransitClient::new(server_addr);
        let stream_id = StreamId::new("hosted.consumer.orders")?;
        let root_stream = client
            .create_root(
                &stream_id,
                LineageMetadata::new(
                    Some("hub.producer".into()),
                    Some("hosted-authority-proof".into()),
                ),
            )
            .context("create hosted authority root stream through transit client")?;
        let acknowledged_payloads = vec![
            r#"{"consumer":"hub","record":"order.created","id":"order-1"}"#.to_owned(),
            r#"{"consumer":"hub","record":"order.shipped","id":"order-1"}"#.to_owned(),
        ];
        let mut producer_appends = Vec::with_capacity(acknowledged_payloads.len());
        for payload in &acknowledged_payloads {
            let append = client
                .append(&stream_id, payload.as_bytes())
                .with_context(|| {
                    format!("append hosted authority payload for {}", stream_id.as_str())
                })?;
            producer_appends.push(summarize_single_remote_append(
                server_addr,
                &stream_id,
                append,
            ));
        }
        let reader_replay = summarize_remote_read(
            server_addr,
            &stream_id,
            client.read(&stream_id).with_context(|| {
                format!("replay hosted authority history for {}", stream_id.as_str())
            })?,
        );
        let replay_matches_acknowledged_history = reader_replay
            .records
            .iter()
            .map(|record| record.payload_text.as_str())
            .eq(acknowledged_payloads.iter().map(String::as_str));

        Ok((
            summarize_remote_stream_status(server_addr, root_stream),
            producer_appends,
            reader_replay,
            acknowledged_payloads,
            replay_matches_acknowledged_history,
        ))
    })();

    let shutdown = summarize_server_shutdown(
        requested_listen_addr,
        server
            .shutdown()
            .context("shutdown hosted authority proof daemon")?,
    )?;
    let (
        root_stream,
        producer_appends,
        reader_replay,
        acknowledged_payloads,
        replay_matches_acknowledged_history,
    ) = proof?;
    let topology = producer_appends
        .first()
        .map(|append| append.topology.clone())
        .unwrap_or_else(|| root_stream.topology.clone());

    Ok(HostedAuthorityProofResult {
        data_root: shutdown.data_root,
        server_addr: server_addr.to_string(),
        durability: shutdown.durability,
        topology,
        stream_id: root_stream.stream_id.clone(),
        root_stream,
        producer_appends,
        reader_replay,
        acknowledged_payloads,
        replay_matches_acknowledged_history,
        remote_tier_publication_performed: false,
        authority_surface: "transit-server remote append/read contract",
        consumer_boundary: "external producers and readers use TransitClient over the server boundary; they do not open LocalEngine as their own authority",
        tiered_non_claim: "tiered durability is not claimed here because this proof never publishes the acknowledged history to the remote tier",
        embedded_authority_used: false,
        accepted_connections: shutdown.accepted_connections,
        graceful_shutdown: shutdown.graceful_shutdown,
        server_api: shutdown.server_api,
        remote_api: "TransitClient",
    })
}

async fn run_warm_cache_recovery_proof(root: PathBuf) -> Result<WarmCacheRecoveryProofResult> {
    reset_directory(&root)?;

    let authority_root = root.join("authority");
    let server_root = root.join("server");
    let object_store_root = root.join("object-store");
    fs::create_dir_all(&object_store_root)
        .with_context(|| format!("create object store root {}", object_store_root.display()))?;

    let authority = LocalEngine::open(
        LocalEngineConfig::new(&authority_root, NodeId::new("cli-node"))
            .with_segment_max_records(2)
            .context("warm cache recovery config")?,
    )
    .context("open warm cache authority engine")?;
    let store = LocalFileSystem::new_with_prefix(&object_store_root)
        .with_context(|| format!("open local object store at {}", object_store_root.display()))?;
    let stream_id = StreamId::new("server.recovery.root")?;

    authority.create_stream(StreamDescriptor::root(
        stream_id.clone(),
        LineageMetadata::new(
            Some("mission".into()),
            Some("warm-cache-recovery-proof".into()),
        ),
    ))?;
    let local_write = authority.append(&stream_id, b"first")?;
    for payload in ["second", "third", "fourth"] {
        authority.append(&stream_id, payload.as_bytes())?;
    }
    authority
        .publish_rolled_segments(&stream_id, &store, "warm-cache-recovery")
        .await?;
    let frontier = authority
        .published_replication_frontier(&stream_id)?
        .context("warm cache recovery proof requires a published frontier")?;
    let source_payloads = authority
        .replay(&stream_id)?
        .into_iter()
        .map(|record| String::from_utf8_lossy(record.payload()).into_owned())
        .collect::<Vec<_>>();

    let replica_config =
        LocalEngineConfig::new(&server_root, NodeId::new("server-replica")).as_read_only_replica();
    let initial_hydrate =
        hydrate_server_from_frontier(&replica_config, &store, &frontier, &stream_id).await?;
    fs::remove_dir_all(&server_root)
        .with_context(|| format!("remove warm cache root {}", server_root.display()))?;
    let restart_hydrate =
        hydrate_server_from_frontier(&replica_config, &store, &frontier, &stream_id).await?;

    let restored_history_matches = initial_hydrate
        .replay
        .records
        .iter()
        .map(|record| record.payload_text.as_str())
        .eq(source_payloads.iter().map(String::as_str))
        && restart_hydrate
            .replay
            .records
            .iter()
            .map(|record| record.payload_text.as_str())
            .eq(source_payloads.iter().map(String::as_str));

    Ok(WarmCacheRecoveryProofResult {
        data_root: root,
        stream_id: stream_id.as_str().to_owned(),
        local_write_durability: local_write.durability().as_str().to_owned(),
        authoritative_recovery_durability: "tiered".to_owned(),
        published_frontier: summarize_published_frontier(&frontier),
        warm_cache_removed: true,
        initial_hydrate,
        restart_hydrate,
        restored_history_matches,
        local_non_claim: "local append acknowledgement does not by itself claim remote-tier safety; recovery depends on the published frontier in object-store authority",
        authoritative_source: "published manifest and segment objects in the shared object-store tier",
        server_api: "transit_server::bind_read_only_replica_from_frontier",
        remote_api: "RemoteClient",
    })
}

async fn hydrate_server_from_frontier(
    config: &LocalEngineConfig,
    store: &LocalFileSystem,
    frontier: &transit_core::engine::LocalPublishedReplicationFrontier,
    stream_id: &StreamId,
) -> Result<WarmCacheRecoveryHydrationResult> {
    let requested_listen_addr = "127.0.0.1:0"
        .parse::<SocketAddr>()
        .context("parse warm cache recovery listen addr")?;
    let (server, sync) = bind_read_only_replica_from_frontier(
        config.clone(),
        requested_listen_addr,
        store,
        frontier,
    )
    .await
    .context("bind hydrated warm cache recovery server")?;
    let server_addr = server.local_addr();
    let replay = run_remote_read(ServerReadArgs {
        server_addr,
        stream_id: stream_id.as_str().to_owned(),
        json: false,
    })?;
    let shutdown = summarize_server_shutdown(
        requested_listen_addr,
        server
            .shutdown()
            .context("shutdown warm cache recovery server")?,
    )?;

    Ok(WarmCacheRecoveryHydrationResult {
        server_addr: server_addr.to_string(),
        bootstrapped: sync.bootstrapped(),
        restored_segment_ids: sync
            .restored_segment_ids()
            .iter()
            .map(|segment_id| segment_id.as_str().to_owned())
            .collect(),
        replay,
        accepted_connections: shutdown.accepted_connections,
        graceful_shutdown: shutdown.graceful_shutdown,
    })
}

async fn run_integrity_proof(root: PathBuf) -> Result<IntegrityProofResult> {
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

    let engine = LocalEngine::open(
        LocalEngineConfig::new(&publish_root, NodeId::new("cli-node"))
            .with_segment_max_records(2)
            .context("integrity proof config")?,
    )
    .context("open integrity publish root")?;
    let restore_engine = LocalEngine::open(LocalEngineConfig::new(
        &restore_root,
        NodeId::new("cli-node"),
    ))
    .context("open integrity restore root")?;
    let store = LocalFileSystem::new_with_prefix(&object_store_root).with_context(|| {
        format!(
            "open integrity object store {}",
            object_store_root.display()
        )
    })?;

    let stream_id = StreamId::new("mission.integrity.root")?;
    let branch_stream = StreamId::new("mission.integrity.branch")?;
    let branch_two_stream = StreamId::new("mission.integrity.branch-two")?;
    let merge_stream = StreamId::new("mission.integrity.merge")?;
    engine.create_stream(StreamDescriptor::root(
        stream_id.clone(),
        LineageMetadata::new(Some("mission".into()), Some("integrity-proof".into())),
    ))?;

    let first_append = engine.append(&stream_id, b"integrity-0")?;
    let second_append = engine.append(&stream_id, b"integrity-1")?;
    ensure!(
        first_append.rolled_segment().is_none(),
        "integrity verification must remain off the first append acknowledgement path"
    );
    ensure!(
        second_append.rolled_segment().is_some(),
        "integrity proof expected segment roll after second append"
    );

    let publication = engine
        .publish_rolled_segments(&stream_id, &store, "integrity-proof")
        .await
        .context("publish integrity proof segments")?;
    ensure!(
        !publication.published_segment_ids().is_empty(),
        "integrity proof expected published segments"
    );
    let manifest_object_key = publication
        .manifest_object_key()
        .context("integrity proof publish should emit a remote manifest")?
        .clone();
    let manifest = engine
        .load_manifest(&stream_id)
        .context("load published manifest for integrity proof")?;
    ensure!(
        !manifest.segments().is_empty(),
        "integrity proof expected at least one rolled segment"
    );

    // Verification is intentionally off the append path: it runs only after segment roll.
    let verification = engine.verify_local_lineage(&stream_id);
    let segments = manifest
        .segments()
        .iter()
        .map(summarize_integrity_segment)
        .collect::<Result<Vec<_>>>()?;

    let restore = restore_engine
        .restore_stream_from_remote_manifest(&store, &manifest_object_key)
        .await
        .context("restore integrity proof stream from remote manifest")?;
    let restored_manifest = restore_engine
        .load_manifest(&stream_id)
        .context("load restored manifest for integrity proof")?;
    let manifest_roots_match =
        manifest.manifest_root().digest() == restored_manifest.manifest_root().digest();

    let branch_parent = second_append.position().clone();
    engine.create_branch(
        branch_stream.clone(),
        branch_parent.clone(),
        LineageMetadata::new(
            Some("mission.classifier".into()),
            Some("integrity-branch".into()),
        ),
    )?;
    engine.append(&branch_stream, b"branch-0")?;
    let branch_head = engine.append(&branch_stream, b"branch-1")?;
    ensure!(
        branch_head.rolled_segment().is_some(),
        "integrity proof expected rolled branch segment for checkpoint verification"
    );

    engine.create_branch(
        branch_two_stream.clone(),
        branch_parent.clone(),
        LineageMetadata::new(
            Some("mission.classifier".into()),
            Some("integrity-branch-two".into()),
        ),
    )?;
    engine.append(&branch_two_stream, b"branch-two-0")?;
    let branch_two_head = engine.append(&branch_two_stream, b"branch-two-1")?;
    ensure!(
        branch_two_head.rolled_segment().is_some(),
        "integrity proof expected rolled second branch segment for checkpoint verification"
    );

    let merge_spec = MergeSpec::new(
        vec![
            branch_head.position().clone(),
            branch_two_head.position().clone(),
        ],
        Some(branch_parent),
        MergePolicy::new(MergePolicyKind::Recursive)
            .with_metadata("policy_reason", "integrity-proof"),
        LineageMetadata::new(Some("mission.judge".into()), Some("integrity-merge".into())),
    )?;
    engine.create_merge(merge_stream.clone(), merge_spec)?;
    engine.append(&merge_stream, b"merge-0")?;
    let merge_head = engine.append(&merge_stream, b"merge-1")?;
    ensure!(
        merge_head.rolled_segment().is_some(),
        "integrity proof expected rolled merge segment for checkpoint verification"
    );

    let checkpoints = vec![
        summarize_integrity_checkpoint(&engine, &branch_stream, "branch-handoff")?,
        summarize_integrity_checkpoint(&engine, &merge_stream, "merge-handoff")?,
    ];
    let tamper = run_integrity_tamper_detection(&root)?;
    let server_parity = run_integrity_server_parity(&root)?;

    Ok(IntegrityProofResult {
        data_root: root,
        durability: publication.durability().as_str().to_owned(),
        stream_id: stream_id.as_str().to_owned(),
        records_appended: 2,
        manifest_id: manifest.manifest_id().as_str().to_owned(),
        manifest_generation: manifest.generation(),
        manifest_root: manifest.manifest_root().digest().to_owned(),
        verification_api: "LocalEngine::verify_local_lineage",
        publication_api: "LocalEngine::publish_rolled_segments",
        restore_api: "LocalEngine::restore_stream_from_remote_manifest",
        checkpoint_api: "LocalEngine::checkpoint",
        checkpoint_verification_api: "LocalEngine::verify_checkpoint",
        verified: verification.is_ok()
            && segments
                .iter()
                .all(|segment| segment.checksum_verified && segment.content_digest_verified)
            && manifest_roots_match
            && checkpoints.iter().all(|checkpoint| checkpoint.verified)
            && tamper.detected
            && server_parity.verified,
        segments,
        publication: IntegrityProofPublicationResult {
            published_segment_ids: publication
                .published_segment_ids()
                .iter()
                .map(|segment_id| segment_id.as_str().to_owned())
                .collect(),
            manifest_object_key: manifest_object_key.as_str().to_owned(),
        },
        restore: IntegrityProofRestoreResult {
            stream_id: restore.stream_id().as_str().to_owned(),
            restored_segment_ids: restore
                .restored_segment_ids()
                .iter()
                .map(|segment_id| segment_id.as_str().to_owned())
                .collect(),
            manifest_generation: restored_manifest.generation(),
            manifest_root: restored_manifest.manifest_root().digest().to_owned(),
            manifest_roots_match,
            next_offset: restore.next_offset().value(),
        },
        checkpoints,
        tamper,
        server_parity,
        error: verification.err().map(|error| format!("{error:#}")),
    })
}

async fn run_materialization_proof(root: PathBuf) -> Result<MaterializationProofResult> {
    reset_directory(&root)?;

    let engine = LocalEngine::open(
        LocalEngineConfig::new(&root, NodeId::new("cli-node"))
            .with_segment_max_records(2)
            .context("materialization proof config")?,
    )
    .context("open materialization proof root")?;
    let stream_id = StreamId::new("mission.materialization.root")?;
    let materialization_id = "mission.materialization.count".to_owned();

    engine.create_stream(StreamDescriptor::root(
        stream_id.clone(),
        LineageMetadata::new(Some("mission".into()), Some("materialization-proof".into())),
    ))?;

    let first_append = engine.append(&stream_id, b"materialize-0")?;
    engine.append(&stream_id, b"materialize-1")?;

    let materializer = LocalMaterializationEngine::new(
        materialization_id.clone(),
        stream_id.clone(),
        engine.clone(),
        MaterializationProofCountReducer,
        MaterializationProofState::default(),
    );
    materializer
        .catch_up()
        .await
        .context("materialize initial records")?;
    let initial_state = materializer.current_state().await;
    ensure!(
        initial_state.processed_records == 2,
        "materialization proof expected 2 processed records before checkpoint, found {}",
        initial_state.processed_records
    );

    let checkpoint = materializer
        .checkpoint()
        .await
        .context("checkpoint materialization proof")?;
    engine
        .verify_checkpoint(&checkpoint.lineage_anchor)
        .context("verify materialization checkpoint anchor")?;

    engine.append(&stream_id, b"materialize-2")?;
    engine.append(&stream_id, b"materialize-3")?;

    let resumed = LocalMaterializationEngine::resume(
        materialization_id.clone(),
        stream_id.clone(),
        engine.clone(),
        MaterializationProofCountReducer,
        checkpoint.clone(),
    )
    .context("resume materialization proof from checkpoint")?;
    resumed
        .catch_up()
        .await
        .context("materialize resumed records")?;
    let resumed_state = resumed.current_state().await;
    let processed_new_records = resumed_state
        .processed_records
        .checked_sub(initial_state.processed_records)
        .context("materialization proof resumed total count regressed")?;
    let only_new_records_processed =
        processed_new_records == 2 && resumed_state.processed_records == 4;
    ensure!(
        only_new_records_processed,
        "materialization proof expected resume to process only new records: initial={}, resumed={}, delta={}",
        initial_state.processed_records,
        resumed_state.processed_records,
        processed_new_records
    );

    let snapshot_checkpoint = resumed
        .checkpoint()
        .await
        .context("checkpoint snapshot source state")?;
    engine
        .verify_checkpoint(&snapshot_checkpoint.lineage_anchor)
        .context("verify snapshot source checkpoint anchor")?;
    let snapshot = build_materialization_snapshot(
        &root.join("snapshot-store"),
        &materialization_id,
        &stream_id,
        &snapshot_checkpoint,
        &resumed_state,
    )
    .await?;

    let branch_stream_id = StreamId::new("mission.materialization.branch")?;
    let branch_parent = StreamPosition::new(stream_id.clone(), Offset::new(0));
    engine
        .create_branch(
            branch_stream_id.clone(),
            branch_parent.clone(),
            LineageMetadata::new(
                Some("mission".into()),
                Some("materialization-branch-proof".into()),
            ),
        )
        .context("create materialization proof branch")?;
    let branch_descriptor = engine
        .stream_descriptor(&branch_stream_id)
        .context("load materialization proof branch descriptor")?;
    let StreamLineage::Branch { branch_point } = &branch_descriptor.lineage else {
        bail!("materialization proof branch descriptor did not preserve branch lineage");
    };
    ensure!(
        branch_point.parent.stream_id.as_str() == stream_id.as_str(),
        "materialization proof branch parent stream mismatch: expected '{}', found '{}'",
        stream_id.as_str(),
        branch_point.parent.stream_id.as_str()
    );
    ensure!(
        branch_point.parent.offset.value() == branch_parent.offset.value(),
        "materialization proof branch parent offset mismatch: expected {}, found {}",
        branch_parent.offset.value(),
        branch_point.parent.offset.value()
    );

    engine
        .append(&branch_stream_id, b"branch-materialize-0")
        .context("append first branch materialization record")?;
    engine
        .append(&branch_stream_id, b"branch-materialize-1")
        .context("append second branch materialization record")?;

    let branch_materialization_id = "mission.materialization.count.branch".to_owned();
    let branch_materializer = LocalMaterializationEngine::new(
        branch_materialization_id.clone(),
        branch_stream_id.clone(),
        engine.clone(),
        MaterializationProofCountReducer,
        MaterializationProofState::default(),
    );
    branch_materializer
        .catch_up()
        .await
        .context("materialize branch records")?;
    let branch_state = branch_materializer.current_state().await;
    ensure!(
        branch_state.processed_records == 3,
        "materialization proof branch expected 3 processed records, found {}",
        branch_state.processed_records
    );
    ensure!(
        branch_state.last_offset == Some(2),
        "materialization proof branch expected last offset 2, found {:?}",
        branch_state.last_offset
    );
    let branch_checkpoint = branch_materializer
        .checkpoint()
        .await
        .context("checkpoint branch materialization proof")?;
    engine
        .verify_checkpoint(&branch_checkpoint.lineage_anchor)
        .context("verify branch materialization checkpoint anchor")?;
    let branch_manifest = engine
        .load_manifest(&branch_stream_id)
        .context("load materialization proof branch manifest")?;
    let shared_model_verified = branch_checkpoint.lineage_anchor.stream_id.as_str()
        == branch_stream_id.as_str()
        && branch_checkpoint.lineage_anchor.manifest_root.digest()
            == branch_manifest.manifest_root().digest()
        && branch_manifest.stream_descriptor() == &branch_descriptor;
    ensure!(
        shared_model_verified,
        "materialization proof branch checkpoint diverged from the shared engine manifest/lineage model"
    );

    let branch_snapshot = build_materialization_snapshot(
        &root.join("branch-snapshot-store"),
        &branch_materialization_id,
        &branch_stream_id,
        &branch_checkpoint,
        &branch_state,
    )
    .await?;
    ensure!(
        branch_snapshot
            .manifest
            .source_checkpoint
            .manifest_root
            .digest()
            == branch_manifest.manifest_root().digest(),
        "materialization proof branch snapshot manifest root does not match the shared engine manifest root"
    );
    let distinct_from_root_snapshot =
        branch_snapshot.result.root_digest != snapshot.result.root_digest;
    ensure!(
        distinct_from_root_snapshot,
        "materialization proof branch snapshot should differ from the root snapshot digest"
    );

    Ok(MaterializationProofResult {
        data_root: root,
        durability: first_append.durability().as_str().to_owned(),
        stream_id: stream_id.as_str().to_owned(),
        materialization_id,
        initial_records_appended: initial_state.processed_records as usize,
        initial_materialized_count: initial_state.processed_records,
        materialization_api: "LocalMaterializationEngine::catch_up",
        checkpoint_api: "LocalMaterializationEngine::checkpoint",
        checkpoint_anchor_api: "LocalEngine::checkpoint",
        checkpoint: MaterializationProofCheckpointResult {
            stream_id: checkpoint.lineage_anchor.stream_id.as_str().to_owned(),
            head_offset: checkpoint.lineage_anchor.head_offset.value(),
            manifest_root: checkpoint.lineage_anchor.manifest_root.digest().to_owned(),
            kind: checkpoint.lineage_anchor.kind,
        },
        resume: MaterializationProofResumeResult {
            appended_after_checkpoint: processed_new_records as usize,
            resumed_total_count: resumed_state.processed_records,
            resumed_last_offset: resumed_state.last_offset,
            processed_new_records,
            only_new_records_processed,
        },
        snapshot: snapshot.result,
        branch: MaterializationProofBranchResult {
            stream_id: branch_stream_id.as_str().to_owned(),
            parent_stream_id: branch_point.parent.stream_id.as_str().to_owned(),
            parent_head_offset: branch_point.parent.offset.value(),
            lineage_kind: "branch".to_owned(),
            materialization_id: branch_materialization_id,
            branch_records_appended: 2,
            materialized_count: branch_state.processed_records,
            checkpoint_stream_id: branch_checkpoint
                .lineage_anchor
                .stream_id
                .as_str()
                .to_owned(),
            checkpoint_head_offset: branch_checkpoint.lineage_anchor.head_offset.value(),
            checkpoint_manifest_root: branch_checkpoint
                .lineage_anchor
                .manifest_root
                .digest()
                .to_owned(),
            checkpoint_kind: branch_checkpoint.lineage_anchor.kind.clone(),
            snapshot: branch_snapshot.result,
            shared_model_verified,
            distinct_from_root_snapshot,
        },
        verified: true,
        error: None,
    })
}

async fn run_reference_projection_proof(root: PathBuf) -> Result<ReferenceProjectionProofResult> {
    reset_directory(&root)?;

    let engine = LocalEngine::open(
        LocalEngineConfig::new(&root, NodeId::new("cli-node"))
            .with_segment_max_records(2)
            .context("reference projection proof config")?,
    )
    .context("open reference projection proof root")?;
    let stream_id = StreamId::new("mission.materialization.reference-projection.root")?;
    let materialization_id = "mission.materialization.reference-projection".to_owned();

    engine.create_stream(StreamDescriptor::root(
        stream_id.clone(),
        LineageMetadata::new(
            Some("mission".into()),
            Some("reference-projection-proof".into()),
        ),
    ))?;

    let first_append = engine.append(
        &stream_id,
        reference_projection_proof_event("ref-1", "alpha", "active", false)?,
    )?;
    engine.append(
        &stream_id,
        reference_projection_proof_event("ref-2", "beta", "pending", false)?,
    )?;

    let materializer = ReferenceProjectionMaterializer::new(
        materialization_id.clone(),
        stream_id.clone(),
        engine.clone(),
        ReferenceProjectionProofReducer,
    );
    materializer
        .catch_up()
        .await
        .context("materialize initial reference projection replay")?;

    let checkpoint = materializer
        .checkpoint()
        .await
        .context("checkpoint reference projection proof")?;
    engine
        .verify_checkpoint(&checkpoint.lineage_anchor)
        .context("verify reference projection checkpoint anchor")?;
    let checkpoint_manifest = engine
        .load_manifest(&stream_id)
        .context("load checkpoint manifest for reference projection proof")?;
    let shared_model_verified = checkpoint.lineage_anchor.stream_id == stream_id
        && checkpoint.lineage_anchor.manifest_root.digest()
            == checkpoint_manifest.manifest_root().digest();
    ensure!(
        shared_model_verified,
        "reference projection proof checkpoint diverged from the shared manifest or lineage model"
    );

    engine.append(
        &stream_id,
        reference_projection_proof_event("ref-2", "beta", "active", false)?,
    )?;
    engine.append(
        &stream_id,
        reference_projection_proof_event("ref-3", "gamma", "active", false)?,
    )?;
    engine.append(
        &stream_id,
        reference_projection_proof_event("ref-1", "alpha", "active", true)?,
    )?;

    let resumed = ReferenceProjectionMaterializer::resume_verified(
        materialization_id.clone(),
        stream_id.clone(),
        engine.clone(),
        ReferenceProjectionProofReducer,
        checkpoint.clone(),
    )
    .context("resume reference projection proof from checkpoint")?;
    let resume_cursor = resumed
        .resume_cursor()
        .await
        .context("load reference projection resume cursor")?
        .context("reference projection proof expected a resume cursor")?;
    let appended_after_checkpoint = 3usize;
    let resumed_only_new_history =
        resume_cursor.pending_record_count() == appended_after_checkpoint as u64;
    ensure!(
        resumed_only_new_history,
        "reference projection proof expected only new history after checkpoint: expected {}, found {}",
        appended_after_checkpoint,
        resume_cursor.pending_record_count()
    );

    resumed
        .catch_up()
        .await
        .context("materialize resumed reference projection replay")?;
    let resumed_view = resumed.current_view().await;

    let rebuilt = ReferenceProjectionMaterializer::new(
        format!("{materialization_id}.replay"),
        stream_id.clone(),
        engine.clone(),
        ReferenceProjectionProofReducer,
    );
    rebuilt
        .catch_up()
        .await
        .context("rebuild reference projection from authoritative replay")?;
    let rebuilt_view = rebuilt.current_view().await;
    let authoritative_record_count = engine
        .replay(&stream_id)
        .context("load authoritative replay for reference projection proof")?
        .len();
    let equivalent_views = resumed_view == rebuilt_view;
    ensure!(
        equivalent_views,
        "reference projection proof expected checkpoint resume and authoritative replay to converge on the same view"
    );

    let projection_only_authority_used = false;
    let verified = equivalent_views
        && resumed_only_new_history
        && shared_model_verified
        && !projection_only_authority_used;

    Ok(ReferenceProjectionProofResult {
        data_root: root,
        durability: first_append.durability().as_str().to_owned(),
        stream_id: stream_id.as_str().to_owned(),
        materialization_id,
        materialization_api: "ReferenceProjectionMaterializer::catch_up",
        checkpoint_api: "ReferenceProjectionMaterializer::checkpoint",
        checkpoint_anchor_api: "LocalEngine::checkpoint",
        checkpoint_verification_api: "LocalEngine::verify_checkpoint",
        resume_api: "ReferenceProjectionMaterializer::resume_verified",
        authoritative_replay_api: "ReferenceProjectionMaterializer::catch_up via LocalEngine::tail_from",
        checkpoint: ReferenceProjectionProofCheckpointResult {
            stream_id: checkpoint.lineage_anchor.stream_id.as_str().to_owned(),
            head_offset: checkpoint.lineage_anchor.head_offset.value(),
            manifest_root: checkpoint.lineage_anchor.manifest_root.digest().to_owned(),
            kind: checkpoint.lineage_anchor.kind,
            verified: true,
            shared_model_verified,
            error: None,
        },
        resume: ReferenceProjectionProofResumeResult {
            appended_after_checkpoint,
            replay_from_offset: resume_cursor.replay_from().value(),
            source_next_offset: resume_cursor.source_next_offset().value(),
            pending_record_count: resume_cursor.pending_record_count(),
            resumed_reference_count: resumed_view.len(),
            resumed_view,
            resumed_only_new_history,
        },
        rebuild: ReferenceProjectionProofRebuildResult {
            authoritative_record_count,
            rebuilt_reference_count: rebuilt_view.len(),
            rebuilt_view,
        },
        equivalent_views,
        projection_only_authority_used,
        verified,
        error: None,
    })
}

async fn build_materialization_snapshot(
    snapshot_store_root: &Path,
    materialization_id: &str,
    stream_id: &StreamId,
    checkpoint: &MaterializationCheckpoint,
    state: &MaterializationProofState,
) -> Result<MaterializationProofSnapshotArtifacts> {
    ensure!(
        checkpoint.materialization_id == materialization_id,
        "materialization proof snapshot checkpoint id mismatch: expected '{}', found '{}'",
        materialization_id,
        checkpoint.materialization_id
    );
    ensure!(
        checkpoint.lineage_anchor.stream_id.as_str() == stream_id.as_str(),
        "materialization proof snapshot checkpoint stream mismatch: expected '{}', found '{}'",
        stream_id.as_str(),
        checkpoint.lineage_anchor.stream_id.as_str()
    );

    fs::create_dir_all(snapshot_store_root).with_context(|| {
        format!(
            "create materialization proof snapshot store root at {}",
            snapshot_store_root.display()
        )
    })?;
    let snapshot_object_store = std::sync::Arc::new(
        LocalFileSystem::new_with_prefix(snapshot_store_root).with_context(|| {
            format!(
                "open materialization proof snapshot store at {}",
                snapshot_store_root.display()
            )
        })?,
    );
    let snapshot_store = ObjectStoreProllyStore::new(snapshot_object_store, "snapshots");
    let snapshot_builder = ProllyTreeBuilder::new(&snapshot_store);
    let root_digest = snapshot_builder
        .build_from_entries(materialization_snapshot_entries(state))
        .await
        .context("build materialization proof prolly snapshot")?;
    let snapshot_id = format!(
        "snapshot-{:020}",
        checkpoint.lineage_anchor.head_offset.value()
    );
    let manifest = SnapshotManifest {
        materialization_id: materialization_id.to_owned(),
        snapshot_id: snapshot_id.clone(),
        source_stream_id: stream_id.clone(),
        source_checkpoint: checkpoint.lineage_anchor.clone(),
        root_digest: root_digest.clone(),
        created_at: checkpoint.produced_at,
    };
    ensure!(
        manifest.source_checkpoint.stream_id.as_str() == stream_id.as_str(),
        "materialization proof snapshot manifest stream mismatch: expected '{}', found '{}'",
        stream_id.as_str(),
        manifest.source_checkpoint.stream_id.as_str()
    );
    ensure!(
        manifest.source_checkpoint.head_offset.value()
            == checkpoint.lineage_anchor.head_offset.value(),
        "materialization proof snapshot manifest head mismatch: expected {}, found {}",
        checkpoint.lineage_anchor.head_offset.value(),
        manifest.source_checkpoint.head_offset.value()
    );
    ensure!(
        manifest.root_digest == root_digest,
        "materialization proof snapshot manifest root digest mismatch"
    );
    let stored_nodes_dir = snapshot_store_root.join("snapshots");
    let stored_node_count = fs::read_dir(&stored_nodes_dir)
        .with_context(|| {
            format!(
                "read materialization proof nodes at {}",
                stored_nodes_dir.display()
            )
        })?
        .count();
    ensure!(
        stored_node_count > 0,
        "materialization proof expected at least one stored prolly node"
    );
    let root_node_path = stored_nodes_dir.join(root_digest.digest());
    ensure!(
        root_node_path.is_file(),
        "materialization proof missing persisted root node at {}",
        root_node_path.display()
    );

    Ok(MaterializationProofSnapshotArtifacts {
        result: MaterializationProofSnapshotResult {
            snapshot_id,
            source_stream_id: manifest.source_stream_id.as_str().to_owned(),
            source_head_offset: manifest.source_checkpoint.head_offset.value(),
            source_manifest_root: manifest.source_checkpoint.manifest_root.digest().to_owned(),
            root_digest: manifest.root_digest.digest().to_owned(),
            stored_node_count,
            builder_api: "ProllyTreeBuilder::build_from_entries",
            store_api: "ObjectStoreProllyStore",
        },
        manifest,
    })
}

fn materialization_snapshot_entries(state: &MaterializationProofState) -> Vec<LeafEntry> {
    vec![
        LeafEntry {
            key: b"last_offset".to_vec(),
            value: state
                .last_offset
                .map(|offset| offset.to_string())
                .unwrap_or_else(|| "none".to_owned())
                .into_bytes(),
        },
        LeafEntry {
            key: b"processed_records".to_vec(),
            value: state.processed_records.to_string().into_bytes(),
        },
    ]
}

async fn run_server(args: ServerRunArgs, config: &LoadedTransitConfig) -> Result<ServerRunResult> {
    use object_store::local::LocalFileSystem;
    use std::sync::Arc;
    use transit_core::consensus::{ConsensusManager, NodeId, ObjectStoreConsensus};

    let root = resolve_local_root(args.root, config);
    let effective_config = config.config();
    let requested_listen_addr = args
        .listen_addr
        .unwrap_or(effective_config.server.listen_addr);
    let effective_node_id = args
        .node_id
        .unwrap_or_else(|| effective_config.effective_node_id().to_owned());
    let effective_consensus_root = args
        .consensus_root
        .or_else(|| effective_config.replication.consensus_root.clone());

    let server =
        bind_hosted_runtime_server(config, &root, requested_listen_addr, &effective_node_id)?;

    // Optional: Initialize distributed consensus
    let mut _heartbeat_loop = None;
    if let Some(consensus_root) = effective_consensus_root {
        let store = Arc::new(LocalFileSystem::new_with_prefix(consensus_root)?);
        let provider = Arc::new(ObjectStoreConsensus::new(store, "leases"));
        let manager = ConsensusManager::new(provider, NodeId::new(effective_node_id.clone()));
        _heartbeat_loop = Some(manager.spawn_heartbeat_loop());

        if !args.json {
            println!(
                "consensus: enabled (node-id: {})",
                manager.node_id().as_str()
            );
        }

        // Note: In a real impl, we'd need to acquire leases for existing streams
        // OR acquire them lazily during the first write.
        // For now, I'll just show the integration.
    }

    if !args.json {
        println!("transit server bootstrap");
        println!("root: {}", server.data_dir().display());
        println!("listen requested: {}", requested_listen_addr);
        println!("listen bound: {}", server.local_addr());
        println!("durability: {}", server.durability().as_str());

        let recovery = server.startup_recovery();
        let recovered_count = recovery
            .iter()
            .filter(|outcome| outcome.truncated_bytes() > 0)
            .count();
        println!(
            "startup recovery: {} streams checked, {} recovered",
            recovery.len(),
            recovered_count
        );
        for outcome in recovery.iter().filter(|o| o.truncated_bytes() > 0) {
            println!(
                "  recovered '{}': truncated {} uncommitted bytes, committed offset {}",
                outcome.stream_id().as_str(),
                outcome.truncated_bytes(),
                outcome.committed_next_offset().value()
            );
        }

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

fn bind_hosted_runtime_server(
    config: &LoadedTransitConfig,
    root: &Path,
    requested_listen_addr: SocketAddr,
    effective_node_id: &str,
) -> Result<ServerHandle> {
    let effective_config = config.config();
    let _object_store_authority = build_loaded_runtime_object_store(config).with_context(|| {
        format!(
            "resolve {} object-store authority for transit server run",
            effective_config.storage.provider.as_str()
        )
    })?;

    let engine_config = LocalEngineConfig::new(root, NodeId::new(effective_node_id.to_owned()));
    let server_config = ServerConfig::new(engine_config, requested_listen_addr);
    ServerHandle::bind(server_config).context("bind shared-engine server")
}

fn run_streams_list(server_addr: SocketAddr) -> Result<RemoteStreamListResult> {
    let client = RemoteClient::new(server_addr);
    let listed = client
        .list_streams()
        .with_context(|| format!("list remote streams at {server_addr}"))?;

    Ok(RemoteStreamListResult {
        server_addr: server_addr.to_string(),
        request_id: listed.request_id().as_str().to_owned(),
        durability: listed.ack().durability().to_owned(),
        topology: render_topology(listed.ack().topology()),
        stream_count: listed.body().streams().len(),
        streams: listed
            .body()
            .streams()
            .iter()
            .map(summarize_remote_stream_summary)
            .collect(),
    })
}

fn run_streams_create(
    server_addr: SocketAddr,
    args: StreamsCreateArgs,
) -> Result<RemoteStreamStatusResult> {
    run_remote_create_root(ServerCreateRootArgs {
        server_addr,
        stream_id: args.stream_id,
        actor: args.actor,
        reason: args.reason,
        labels: args.labels,
        json: args.json,
    })
}

fn run_streams_delete(
    server_addr: SocketAddr,
    args: StreamsDeleteArgs,
) -> Result<RemoteDeletedStreamResult> {
    ensure!(
        args.force,
        "refusing to delete stream '{}' without --force",
        args.stream_id
    );

    let client = RemoteClient::new(server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let deleted = client
        .delete_stream(&stream_id)
        .with_context(|| format!("delete remote stream {}", stream_id.as_str()))?;

    Ok(RemoteDeletedStreamResult {
        server_addr: server_addr.to_string(),
        request_id: deleted.request_id().as_str().to_owned(),
        durability: deleted.ack().durability().to_owned(),
        topology: render_topology(deleted.ack().topology()),
        stream_id: deleted.body().stream_id().as_str().to_owned(),
        deleted_path: deleted.body().deleted_path().to_path_buf(),
        record_count: deleted.body().record_count(),
    })
}

fn run_produce(server_addr: SocketAddr, args: ProduceArgs) -> Result<ProduceResult> {
    let client = RemoteClient::new(server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let payloads = read_produce_payloads(args.payload_text)?;
    ensure!(
        !payloads.is_empty(),
        "produce requires at least one payload via --payload-text or stdin"
    );

    let mut appends = Vec::with_capacity(payloads.len());
    for payload in payloads {
        let append = client
            .append(&stream_id, payload.as_bytes())
            .with_context(|| format!("append remotely to {}", stream_id.as_str()))?;
        appends.push(summarize_single_remote_append(
            server_addr,
            &stream_id,
            append,
        ));
    }

    Ok(ProduceResult {
        server_addr: server_addr.to_string(),
        stream_id: stream_id.as_str().to_owned(),
        append_count: appends.len(),
        last_position: appends.last().map(|append| append.last_position.clone()),
        appends,
    })
}

fn run_consume(server_addr: SocketAddr, args: ConsumeArgs) -> Result<ConsumeResult> {
    let client = RemoteClient::new(server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let read = client
        .tail(&stream_id, Offset::new(args.from_offset))
        .with_context(|| format!("consume remotely from {}", stream_id.as_str()))?;
    let mut records = summarize_remote_records(read.body().records());
    if let Some(limit) = args.limit {
        records.truncate(limit);
    }

    Ok(ConsumeResult {
        server_addr: server_addr.to_string(),
        request_id: read.request_id().as_str().to_owned(),
        durability: read.ack().durability().to_owned(),
        topology: render_topology(read.ack().topology()),
        stream_id: stream_id.as_str().to_owned(),
        from_offset: args.from_offset,
        record_count: records.len(),
        head_offset: records
            .last()
            .and_then(|record| parse_rendered_position_offset(&record.position)),
        records,
    })
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

    Ok(summarize_remote_stream_status(args.server_addr, created))
}

fn run_remote_append(args: ServerAppendArgs) -> Result<RemoteAppendResult> {
    let client = RemoteClient::new(args.server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let append = client
        .append_batch(&stream_id, args.payload_text.iter().map(String::as_bytes))
        .with_context(|| format!("append remotely to {}", stream_id.as_str()))?;

    Ok(summarize_remote_append(
        args.server_addr,
        &stream_id,
        append,
    ))
}

fn run_remote_read(args: ServerReadArgs) -> Result<RemoteReadResult> {
    let client = RemoteClient::new(args.server_addr);
    let stream_id = parse_stream_id_arg(&args.stream_id)?;
    let read = client
        .read(&stream_id)
        .with_context(|| format!("read remotely from {}", stream_id.as_str()))?;

    Ok(summarize_remote_read(args.server_addr, &stream_id, read))
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

    Ok(summarize_remote_stream_status(args.server_addr, branch))
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

    Ok(summarize_remote_stream_status(args.server_addr, merged))
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
        LocalEngineConfig::new(&publish_root, NodeId::new("cli-node"))
            .with_segment_max_records(2)
            .context("tiered proof config")?,
    )
    .context("open publish engine")?;
    let restore_engine = LocalEngine::open(
        LocalEngineConfig::new(&restore_root, NodeId::new("cli-node")).as_read_only_replica(),
    )
    .context("open restore engine")?;
    let store = LocalFileSystem::new_with_prefix(&object_store_root)
        .with_context(|| format!("open local object store at {}", object_store_root.display()))?;

    let stream_id = StreamId::new("tiered.root")?;
    publish_engine.create_stream(StreamDescriptor::root(
        stream_id.clone(),
        LineageMetadata::new(Some("mission".into()), Some("tiered-engine-proof".into())),
    ))?;
    for payload in ["first", "second", "third", "fourth"] {
        publish_engine.append(&stream_id, payload.as_bytes())?;
    }
    let replicated_ack = publish_engine
        .append_with_replicated_ack(&stream_id, b"fifth", &store, "tiered-proof")
        .await?;
    let published_frontier = publish_engine
        .published_replication_frontier(&stream_id)?
        .context("tiered proof publish should persist a published frontier")?;
    publish_engine.append(&stream_id, b"sixth")?;

    let manifest_key = published_frontier.manifest_object_key().clone();
    let restore = restore_engine
        .sync_read_only_replica_from_frontier(&store, &published_frontier)
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
        durability: publish_engine.durability().as_str().to_owned(),
        publish_stream: summarize_stream(&stream_id, &published_records),
        restored_stream: summarize_stream(&stream_id, &restored_records),
        published_frontier: summarize_published_frontier(&published_frontier),
        replicated_ack: summarize_replicated_ack(&replicated_ack),
        commitment_surface: CommitmentSurfaceResult {
            local_head_offset: published_records
                .last()
                .map(|record| record.position().offset.value()),
            replicated_frontier_offset: published_frontier
                .last_offset()
                .map(|offset| offset.value()),
            tiered_restore_offset: restored_records
                .last()
                .map(|record| record.position().offset.value()),
            unpublished_local_records,
        },
        published_segments: replicated_ack
            .published_segment_ids()
            .iter()
            .map(|segment_id| segment_id.as_str().to_owned())
            .collect(),
        manifest_object_key: manifest_key.as_str().to_owned(),
        publication_manifest_generation: replicated_ack.manifest_generation(),
        restored_manifest_generation: restore.manifest_generation(),
        unpublished_local_records,
        publication_api: "LocalEngine::append_with_replicated_ack",
        restore_api: "LocalEngine::sync_read_only_replica_from_frontier",
        replay_after_remote_removal_ok,
    })
}

async fn run_controlled_failover_proof(root: PathBuf) -> Result<ControlledFailoverProofResult> {
    use object_store::local::LocalFileSystem;
    use transit_core::consensus::{ConsensusProvider, NodeId, ObjectStoreConsensus};

    reset_directory(&root)?;

    let primary_root = root.join("primary");
    let follower_root = root.join("follower");
    let object_store_root = root.join("object-store");
    fs::create_dir_all(&object_store_root).with_context(|| {
        format!(
            "create failover object store {}",
            object_store_root.display()
        )
    })?;

    let primary = LocalEngine::open(
        LocalEngineConfig::new(&primary_root, NodeId::new("cli-node"))
            .with_segment_max_records(2)
            .context("controlled failover primary config")?,
    )
    .context("open controlled failover primary engine")?;
    let follower = LocalEngine::open(
        LocalEngineConfig::new(&follower_root, NodeId::new("cli-node"))
            .with_segment_max_records(2)
            .context("controlled failover follower config")?
            .as_read_only_replica(),
    )
    .context("open controlled failover follower engine")?;
    let store: std::sync::Arc<dyn object_store::ObjectStore> = std::sync::Arc::new(
        LocalFileSystem::new_with_prefix(&object_store_root).with_context(|| {
            format!(
                "open controlled failover object store {}",
                object_store_root.display()
            )
        })?,
    );
    let consensus = ObjectStoreConsensus::new(store.clone(), "leases");

    let stream_id = StreamId::new("mission.failover.root")?;
    primary.create_stream(StreamDescriptor::root(
        stream_id.clone(),
        LineageMetadata::new(
            Some("mission".into()),
            Some("controlled-failover-proof".into()),
        ),
    ))?;

    primary
        .append(&stream_id, b"handoff-local-0")
        .context("append first controlled failover record")?;
    primary
        .append(&stream_id, b"handoff-local-1")
        .context("append second controlled failover record")?;

    let handle_a = consensus
        .acquire(&stream_id, NodeId::new("node-a"))
        .await
        .context("acquire primary failover lease")?;
    primary.bind_consensus(stream_id.clone(), handle_a);

    let source_replicated_ack = primary
        .append_with_replicated_ack(
            &stream_id,
            b"handoff-replicated-2",
            store.as_ref(),
            "failover-proof",
        )
        .await
        .context("append controlled failover replication unit")?;
    let required_frontier = primary
        .published_replication_frontier(&stream_id)?
        .context("controlled failover proof requires a published frontier")?;
    let sync = follower
        .sync_read_only_replica_from_frontier(store.as_ref(), &required_frontier)
        .await
        .context("sync controlled failover follower from frontier")?;
    let eligibility = follower
        .promotion_eligibility(&stream_id, &required_frontier)
        .context("compute controlled failover promotion eligibility")?;

    let transfer = primary
        .handoff_primary(&stream_id, NodeId::new("node-b"), &eligibility)
        .await
        .context("handoff controlled failover primary")?;
    let former_primary_error = primary
        .append(&stream_id, b"stale-primary-write")
        .expect_err("former primary must be fenced")
        .to_string();
    let former_primary_append_rejected = former_primary_error.contains("not the leader");
    let former_primary_posture =
        summarize_ownership_posture(&primary.ownership_posture(&stream_id));

    let promoted = LocalEngine::open(
        LocalEngineConfig::new(&follower_root, NodeId::new("cli-node"))
            .with_segment_max_records(2)
            .context("controlled failover promoted config")?,
    )
    .context("open controlled failover promoted engine")?;
    let handle_b = consensus
        .acquire(&stream_id, NodeId::new("node-b"))
        .await
        .context("acquire promoted failover lease")?;
    promoted.bind_consensus(stream_id.clone(), handle_b);
    let promoted_posture = summarize_ownership_posture(&promoted.ownership_posture(&stream_id));
    let promoted_append = promoted
        .append(&stream_id, b"promoted-primary-write")
        .context("append on promoted primary after handoff")?;

    let readiness = ControlledFailoverReadinessResult {
        source_replicated_ack: summarize_replicated_ack(&source_replicated_ack),
        restore_next_offset: sync.next_offset().value(),
        required_frontier: summarize_published_frontier(&required_frontier),
        local_frontier: eligibility
            .local_frontier()
            .map(summarize_published_frontier),
        candidate_posture: summarize_ownership_posture(eligibility.ownership_posture()),
        frontier_caught_up: eligibility.frontier_caught_up(),
        ownership_ready: eligibility.ownership_ready(),
        promotable: eligibility.promotable(),
        blockers: eligibility.blockers().to_vec(),
    };

    let handoff = ControlledFailoverHandoffResult {
        stream_id: transfer.stream_id().as_str().to_owned(),
        previous_owner: transfer.previous_owner().as_str().to_owned(),
        new_owner: transfer.new_owner().as_str().to_owned(),
        lease_version: transfer.lease_version(),
        expires_at: transfer.expires_at(),
        manifest_generation: transfer.manifest_generation(),
        frontier_next_offset: transfer.frontier_next_offset().value(),
        promoted_posture,
        promoted_append: summarize_local_append(&promoted_append),
    };

    let fencing = ControlledFailoverFencingResult {
        former_primary_posture,
        former_primary_append_rejected,
        rejection: Some(former_primary_error),
    };

    let contract = ControlledFailoverContractResult {
        local: "post-handoff writes on the promoted primary are only locally durable until they are explicitly published or acknowledged at a stronger level",
        replicated: "promotion readiness is anchored to a published frontier and explicit replicated acknowledgement, but the handoff does not replicate later writes automatically",
        tiered: "the proof restores the follower from the published object-store frontier; tiered publication remains an explicit step rather than hidden failover automation",
        quorum: "no quorum acknowledgement, majority election, or automatic leader selection is implied by this slice",
        multi_primary: "the lease still permits exactly one writable primary and fences stale leaders instead of supporting concurrent writable nodes",
        automation: "operators or higher-level orchestration must decide when to hand off; this proof does not perform autonomous failover",
    };

    let verified = readiness.promotable
        && readiness.frontier_caught_up
        && readiness.ownership_ready
        && fencing.former_primary_append_rejected
        && handoff.promoted_posture.posture == "lease_leader"
        && handoff.promoted_append.durability == "local"
        && handoff.promoted_append.position == "mission.failover.root@3";
    let error = if verified {
        None
    } else {
        Some(
            "controlled failover proof did not preserve promotable readiness, former-primary fencing, and local-only promoted writes".to_owned(),
        )
    };

    Ok(ControlledFailoverProofResult {
        data_root: root,
        stream_id: stream_id.as_str().to_owned(),
        readiness,
        handoff,
        fencing,
        contract,
        verified,
        error,
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

fn summarize_published_frontier(
    frontier: &transit_core::engine::LocalPublishedReplicationFrontier,
) -> PublishedFrontierResult {
    PublishedFrontierResult {
        manifest_id: frontier.manifest_id().as_str().to_owned(),
        manifest_generation: frontier.manifest_generation(),
        manifest_root: frontier.manifest_root().digest().to_owned(),
        manifest_object_key: frontier.manifest_object_key().as_str().to_owned(),
        start_offset: frontier.start_offset().map(|offset| offset.value()),
        last_offset: frontier.last_offset().map(|offset| offset.value()),
        next_offset: frontier.next_offset().value(),
        segments: frontier
            .published_segments()
            .iter()
            .map(|segment| PublishedFrontierSegmentResult {
                segment_id: segment.segment_id().as_str().to_owned(),
                start_offset: segment.start_offset().value(),
                last_offset: segment.last_offset().value(),
                object_store_key: segment.object_store_key().as_str().to_owned(),
            })
            .collect(),
    }
}

fn summarize_replicated_ack(
    outcome: &transit_core::engine::ReplicatedAppendOutcome,
) -> ReplicatedAckResult {
    ReplicatedAckResult {
        commitment: outcome.commitment().as_str().to_owned(),
        position: format!(
            "{}@{}",
            outcome.position().stream_id.as_str(),
            outcome.position().offset.value()
        ),
        manifest_generation: outcome.manifest_generation(),
        frontier_next_offset: outcome.frontier_next_offset().value(),
        manifest_object_key: outcome.manifest_object_key().as_str().to_owned(),
        published_segment_ids: outcome
            .published_segment_ids()
            .iter()
            .map(|segment_id| segment_id.as_str().to_owned())
            .collect(),
        rolled_segment_id: outcome
            .rolled_segment_id()
            .map(|segment_id| segment_id.as_str().to_owned()),
        non_claim: "publication does not imply follower hydration, failover readiness, or quorum acknowledgement",
    }
}

fn summarize_ownership_posture(posture: &OwnershipPosture) -> OwnershipPostureResult {
    let lease = posture.lease();
    OwnershipPostureResult {
        posture: posture.as_str().to_owned(),
        lease_owner: lease.map(|lease| lease.owner.as_str().to_owned()),
        lease_version: lease.map(|lease| lease.version),
        lease_expires_at: lease.map(|lease| lease.expires_at),
    }
}

fn summarize_local_append(
    outcome: &transit_core::engine::LocalAppendOutcome,
) -> LocalAppendProofResult {
    LocalAppendProofResult {
        position: render_position(outcome.position().clone()),
        durability: outcome.durability().as_str().to_owned(),
        manifest_generation: outcome.manifest_generation(),
        rolled_segment_id: outcome
            .rolled_segment()
            .map(|segment| segment.segment_id().as_str().to_owned()),
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
    response: transit_core::server::RemoteAcknowledged<transit_core::server::RemoteStreamStatus>,
) -> RemoteStreamStatusResult {
    RemoteStreamStatusResult {
        server_addr: server_addr.to_string(),
        request_id: response.request_id().as_str().to_owned(),
        durability: response.ack().durability().to_owned(),
        topology: render_topology(response.ack().topology()),
        stream_id: response.body().stream_id().as_str().to_owned(),
        next_offset: response.body().next_offset().value(),
        active_record_count: response.body().active_record_count(),
        active_segment_start_offset: response.body().active_segment_start_offset().value(),
        manifest_generation: response.body().manifest_generation(),
        rolled_segment_count: response.body().rolled_segment_count(),
    }
}

fn summarize_remote_append(
    server_addr: SocketAddr,
    stream_id: &StreamId,
    response: transit_core::server::RemoteAcknowledged<
        transit_core::server::RemoteBatchAppendOutcome,
    >,
) -> RemoteAppendResult {
    RemoteAppendResult {
        server_addr: server_addr.to_string(),
        request_id: response.request_id().as_str().to_owned(),
        durability: response.ack().durability().to_owned(),
        topology: render_topology(response.ack().topology()),
        stream_id: stream_id.as_str().to_owned(),
        position: render_position(response.body().first_position().clone()),
        last_position: render_position(response.body().last_position().clone()),
        record_count: response.body().record_count(),
        manifest_generation: response.body().manifest_generation(),
        rolled_segment_ids: response.body().rolled_segment_ids().to_vec(),
    }
}

fn summarize_single_remote_append(
    server_addr: SocketAddr,
    stream_id: &StreamId,
    response: transit_core::server::RemoteAcknowledged<transit_core::server::RemoteAppendOutcome>,
) -> RemoteAppendResult {
    let position = render_position(response.body().position().clone());

    RemoteAppendResult {
        server_addr: server_addr.to_string(),
        request_id: response.request_id().as_str().to_owned(),
        durability: response.ack().durability().to_owned(),
        topology: render_topology(response.ack().topology()),
        stream_id: stream_id.as_str().to_owned(),
        last_position: position.clone(),
        position,
        record_count: 1,
        manifest_generation: response.body().manifest_generation(),
        rolled_segment_ids: response
            .body()
            .rolled_segment_id()
            .into_iter()
            .map(str::to_owned)
            .collect(),
    }
}

fn summarize_remote_read(
    server_addr: SocketAddr,
    stream_id: &StreamId,
    response: transit_core::server::RemoteAcknowledged<transit_core::server::RemoteReadOutcome>,
) -> RemoteReadResult {
    let records = summarize_remote_records(response.body().records());

    RemoteReadResult {
        server_addr: server_addr.to_string(),
        request_id: response.request_id().as_str().to_owned(),
        durability: response.ack().durability().to_owned(),
        topology: render_topology(response.ack().topology()),
        stream_id: stream_id.as_str().to_owned(),
        record_count: records.len(),
        head_offset: response
            .body()
            .records()
            .last()
            .map(|record| record.position().offset.value()),
        records,
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

fn read_produce_payloads(payload_text: Vec<String>) -> Result<Vec<String>> {
    if !payload_text.is_empty() {
        return Ok(payload_text);
    }

    let stdin = io::stdin();
    ensure!(
        !stdin.is_terminal(),
        "produce requires --payload-text or newline-delimited stdin"
    );

    stdin
        .lock()
        .lines()
        .map(|line| line.context("read produce payload from stdin"))
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

fn parse_rendered_position_offset(value: &str) -> Option<u64> {
    value
        .rsplit_once('@')
        .and_then(|(_, offset)| offset.parse::<u64>().ok())
}

fn fnv1a64_hex(bytes: &[u8]) -> String {
    const FNV_OFFSET: u64 = 0xcbf29ce484222325;
    const FNV_PRIME: u64 = 0x100000001b3;

    let mut hash = FNV_OFFSET;
    for byte in bytes {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(FNV_PRIME);
    }

    format!("{hash:016x}")
}

fn sha256_hex(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};

    let mut hasher = Sha256::new();
    hasher.update(bytes);
    format!("{:x}", hasher.finalize())
}

fn summarize_integrity_segment(
    descriptor: &transit_core::storage::SegmentDescriptor,
) -> Result<IntegrityProofSegmentResult> {
    let local_path = descriptor.storage().local_path().with_context(|| {
        format!(
            "integrity proof requires local segment path for '{}'",
            descriptor.segment_id().as_str()
        )
    })?;
    let bytes = fs::read(local_path)
        .with_context(|| format!("read integrity proof segment {}", local_path.display()))?;

    let checksum_verified = match descriptor.checksum().algorithm() {
        "fnv1a64" => fnv1a64_hex(&bytes) == descriptor.checksum().digest(),
        other => {
            anyhow::bail!("unsupported checksum algorithm '{other}' in integrity proof")
        }
    };
    let content_digest_verified = match descriptor.content_digest().algorithm() {
        "sha256" => sha256_hex(&bytes) == descriptor.content_digest().digest(),
        other => anyhow::bail!("unsupported digest algorithm '{other}' in integrity proof"),
    };

    Ok(IntegrityProofSegmentResult {
        segment_id: descriptor.segment_id().as_str().to_owned(),
        start_offset: descriptor.start_offset().value(),
        last_offset: descriptor.last_offset().value(),
        record_count: descriptor.record_count(),
        byte_length: descriptor.byte_length(),
        checksum_algorithm: descriptor.checksum().algorithm().to_owned(),
        checksum_digest: descriptor.checksum().digest().to_owned(),
        checksum_verified,
        content_digest_algorithm: descriptor.content_digest().algorithm().to_owned(),
        content_digest: descriptor.content_digest().digest().to_owned(),
        content_digest_verified,
    })
}

fn summarize_integrity_checkpoint(
    engine: &LocalEngine,
    stream_id: &StreamId,
    kind: &str,
) -> Result<IntegrityProofCheckpointResult> {
    let descriptor = engine
        .stream_descriptor(stream_id)
        .with_context(|| format!("load stream descriptor for {}", stream_id.as_str()))?;
    let checkpoint = engine
        .checkpoint(stream_id, kind)
        .with_context(|| format!("create integrity checkpoint for {}", stream_id.as_str()))?;
    let verification = engine.verify_checkpoint(&checkpoint);

    Ok(IntegrityProofCheckpointResult {
        stream_id: stream_id.as_str().to_owned(),
        lineage_kind: match descriptor.lineage {
            StreamLineage::Root { .. } => "root".to_owned(),
            StreamLineage::Branch { .. } => "branch".to_owned(),
            StreamLineage::Merge { .. } => "merge".to_owned(),
        },
        head_offset: checkpoint.head_offset.value(),
        manifest_root: checkpoint.manifest_root.digest().to_owned(),
        kind: checkpoint.kind,
        verified: verification.is_ok(),
        error: verification.err().map(|error| format!("{error:#}")),
    })
}

fn run_integrity_tamper_detection(root: &Path) -> Result<IntegrityProofTamperResult> {
    let tamper_root = root.join("tamper");
    let engine = LocalEngine::open(
        LocalEngineConfig::new(&tamper_root, NodeId::new("cli-node"))
            .with_segment_max_records(2)
            .context("integrity tamper config")?,
    )
    .context("open integrity tamper root")?;
    let stream_id = StreamId::new("mission.integrity.tamper")?;
    engine.create_stream(StreamDescriptor::root(
        stream_id.clone(),
        LineageMetadata::new(Some("mission".into()), Some("integrity-tamper".into())),
    ))?;
    engine.append(&stream_id, b"tamper-0")?;
    let second_append = engine.append(&stream_id, b"tamper-1")?;
    ensure!(
        second_append.rolled_segment().is_some(),
        "integrity tamper scenario expected a rolled segment"
    );

    let manifest = engine
        .load_manifest(&stream_id)
        .context("load tamper manifest")?;
    let segment = manifest
        .segments()
        .first()
        .context("integrity tamper scenario expected one sealed segment")?;
    let corrupted_path = segment
        .storage()
        .local_path()
        .cloned()
        .context("integrity tamper scenario requires a local segment path")?;
    let mut corrupted_bytes =
        fs::read(&corrupted_path).with_context(|| format!("read {}", corrupted_path.display()))?;
    ensure!(
        !corrupted_bytes.is_empty(),
        "integrity tamper scenario expected non-empty segment bytes"
    );
    corrupted_bytes[0] ^= 0xff;
    fs::write(&corrupted_path, corrupted_bytes)
        .with_context(|| format!("overwrite corrupted segment {}", corrupted_path.display()))?;

    let verification = engine.verify_local_lineage(&stream_id);
    let error = verification.err().map(|error| format!("{error:#}"));
    let detected = error.as_deref().is_some_and(|message| {
        message.contains("segment checksum mismatch")
            || message.contains("segment content digest mismatch")
    });

    Ok(IntegrityProofTamperResult {
        data_root: tamper_root,
        stream_id: stream_id.as_str().to_owned(),
        segment_id: segment.segment_id().as_str().to_owned(),
        corrupted_path,
        verification_api: "LocalEngine::verify_local_lineage",
        detected,
        error,
    })
}

fn run_integrity_server_parity(root: &Path) -> Result<IntegrityProofServerParityResult> {
    let server_root = root.join("server");
    let requested_listen_addr = "127.0.0.1:0"
        .parse::<SocketAddr>()
        .context("parse integrity server parity listen addr")?;
    let server = ServerHandle::bind(ServerConfig::new(
        LocalEngineConfig::new(&server_root, NodeId::new("cli-node"))
            .with_segment_max_records(2)?,
        requested_listen_addr,
    ))
    .context("bind integrity server parity daemon")?;
    let server_addr = server.local_addr();
    let engine = server.engine();

    let parity = (|| -> Result<(String, String, Vec<IntegrityProofServerParityStreamResult>)> {
        let root_stream_id = "mission.integrity.server.root";
        let branch_stream_id = "mission.integrity.server.branch";
        let branch_two_stream_id = "mission.integrity.server.branch-two";
        let merge_stream_id = "mission.integrity.server.merge";

        run_remote_create_root(ServerCreateRootArgs {
            server_addr,
            stream_id: root_stream_id.into(),
            actor: Some("mission".into()),
            reason: Some("integrity-server-proof".into()),
            labels: vec!["kind=integrity-root".into()],
            json: false,
        })?;
        run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: root_stream_id.into(),
            payload_text: vec!["root-0".into()],
            json: false,
        })?;
        let root_second_append = run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: root_stream_id.into(),
            payload_text: vec!["root-1".into()],
            json: false,
        })?;
        ensure!(
            !root_second_append.rolled_segment_ids.is_empty(),
            "integrity server parity expected root segment roll"
        );

        run_remote_branch(ServerBranchArgs {
            server_addr,
            stream_id: branch_stream_id.into(),
            parent_stream_id: root_stream_id.into(),
            parent_offset: 1,
            actor: Some("mission.classifier".into()),
            reason: Some("integrity-branch".into()),
            labels: vec!["branch=one".into()],
            json: false,
        })?;
        run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: branch_stream_id.into(),
            payload_text: vec!["branch-0".into()],
            json: false,
        })?;
        let branch_second_append = run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: branch_stream_id.into(),
            payload_text: vec!["branch-1".into()],
            json: false,
        })?;
        ensure!(
            !branch_second_append.rolled_segment_ids.is_empty(),
            "integrity server parity expected branch segment roll"
        );

        run_remote_branch(ServerBranchArgs {
            server_addr,
            stream_id: branch_two_stream_id.into(),
            parent_stream_id: root_stream_id.into(),
            parent_offset: 1,
            actor: Some("mission.classifier".into()),
            reason: Some("integrity-branch-two".into()),
            labels: vec!["branch=two".into()],
            json: false,
        })?;
        run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: branch_two_stream_id.into(),
            payload_text: vec!["branch-two-0".into()],
            json: false,
        })?;
        let branch_two_second_append = run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: branch_two_stream_id.into(),
            payload_text: vec!["branch-two-1".into()],
            json: false,
        })?;
        ensure!(
            !branch_two_second_append.rolled_segment_ids.is_empty(),
            "integrity server parity expected second branch segment roll"
        );

        run_remote_merge(ServerMergeArgs {
            server_addr,
            stream_id: merge_stream_id.into(),
            parents: vec![
                "mission.integrity.server.branch@3".into(),
                "mission.integrity.server.branch-two@3".into(),
            ],
            merge_base: Some("mission.integrity.server.root@1".into()),
            policy: "recursive".into(),
            policy_metadata: vec!["resolver=integrity-proof".into()],
            actor: Some("mission.judge".into()),
            reason: Some("integrity-merge".into()),
            labels: vec!["decision=accepted".into()],
            json: false,
        })?;
        run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: merge_stream_id.into(),
            payload_text: vec!["merge-0".into()],
            json: false,
        })?;
        let merge_second_append = run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: merge_stream_id.into(),
            payload_text: vec!["merge-1".into()],
            json: false,
        })?;
        ensure!(
            !merge_second_append.rolled_segment_ids.is_empty(),
            "integrity server parity expected merge segment roll"
        );

        let root_lineage = run_remote_lineage(ServerLineageArgs {
            server_addr,
            stream_id: root_stream_id.into(),
            json: false,
        })?;
        let branch_lineage = run_remote_lineage(ServerLineageArgs {
            server_addr,
            stream_id: branch_stream_id.into(),
            json: false,
        })?;
        let branch_two_lineage = run_remote_lineage(ServerLineageArgs {
            server_addr,
            stream_id: branch_two_stream_id.into(),
            json: false,
        })?;
        let merge_lineage = run_remote_lineage(ServerLineageArgs {
            server_addr,
            stream_id: merge_stream_id.into(),
            json: false,
        })?;

        Ok((
            root_second_append.durability,
            root_second_append.topology,
            vec![
                summarize_integrity_server_parity_stream(&engine, root_lineage)?,
                summarize_integrity_server_parity_stream(&engine, branch_lineage)?,
                summarize_integrity_server_parity_stream(&engine, branch_two_lineage)?,
                summarize_integrity_server_parity_stream(&engine, merge_lineage)?,
            ],
        ))
    })();

    let shutdown = server
        .shutdown()
        .context("shutdown integrity server parity daemon")?;
    let (durability, topology, streams) = parity?;

    Ok(IntegrityProofServerParityResult {
        data_root: shutdown.data_dir().to_path_buf(),
        server_addr: server_addr.to_string(),
        durability,
        topology,
        verification_api: "LocalEngine::verify_local_lineage",
        remote_api: "RemoteClient",
        server_api: "ServerHandle::bind",
        accepted_connections: shutdown.accepted_connections(),
        graceful_shutdown: true,
        verified: streams.iter().all(|stream| stream.verified),
        streams,
    })
}

fn summarize_integrity_server_parity_stream(
    engine: &LocalEngine,
    remote_lineage: RemoteLineageResult,
) -> Result<IntegrityProofServerParityStreamResult> {
    let stream_id = StreamId::new(&remote_lineage.stream_id)?;
    let descriptor = engine
        .stream_descriptor(&stream_id)
        .with_context(|| format!("load local descriptor for {}", stream_id.as_str()))?;
    let local_status = engine
        .stream_status(&stream_id)
        .with_context(|| format!("load local status for {}", stream_id.as_str()))?;
    let local_manifest = engine
        .load_manifest(&stream_id)
        .with_context(|| format!("load local manifest for {}", stream_id.as_str()))?;
    let local_lineage_kind = match &descriptor.lineage {
        StreamLineage::Root { .. } => "root".to_owned(),
        StreamLineage::Branch { .. } => "branch".to_owned(),
        StreamLineage::Merge { .. } => "merge".to_owned(),
    };
    let local_parents = descriptor
        .parent_stream_ids()
        .into_iter()
        .map(|parent| parent.as_str().to_owned())
        .collect::<Vec<_>>();

    let mut mismatches = Vec::new();
    if remote_lineage.lineage_kind != local_lineage_kind {
        mismatches.push(format!(
            "lineage kind mismatch: remote {}, local {}",
            remote_lineage.lineage_kind, local_lineage_kind
        ));
    }
    if remote_lineage.parents != local_parents {
        mismatches.push(format!(
            "parent mismatch: remote {:?}, local {:?}",
            remote_lineage.parents, local_parents
        ));
    }
    if remote_lineage.next_offset != local_status.next_offset().value() {
        mismatches.push(format!(
            "next offset mismatch: remote {}, local {}",
            remote_lineage.next_offset,
            local_status.next_offset().value()
        ));
    }
    if remote_lineage.manifest_generation != local_status.manifest_generation() {
        mismatches.push(format!(
            "manifest generation mismatch: remote {}, local {}",
            remote_lineage.manifest_generation,
            local_status.manifest_generation()
        ));
    }
    if remote_lineage.rolled_segment_count != local_status.rolled_segment_count() {
        mismatches.push(format!(
            "rolled segment mismatch: remote {}, local {}",
            remote_lineage.rolled_segment_count,
            local_status.rolled_segment_count()
        ));
    }

    if let Err(error) = engine.verify_local_lineage(&stream_id) {
        mismatches.push(format!("{error:#}"));
    }

    Ok(IntegrityProofServerParityStreamResult {
        stream_id: remote_lineage.stream_id,
        remote_lineage_kind: remote_lineage.lineage_kind,
        local_lineage_kind,
        remote_parents: remote_lineage.parents,
        local_parents,
        remote_next_offset: remote_lineage.next_offset,
        local_next_offset: local_status.next_offset().value(),
        remote_manifest_generation: remote_lineage.manifest_generation,
        local_manifest_generation: local_status.manifest_generation(),
        remote_rolled_segment_count: remote_lineage.rolled_segment_count,
        local_rolled_segment_count: local_status.rolled_segment_count(),
        manifest_root: local_manifest.manifest_root().digest().to_owned(),
        verified: mismatches.is_empty(),
        error: if mismatches.is_empty() {
            None
        } else {
            Some(mismatches.join("; "))
        },
    })
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

async fn run_chaos_failover_proof(root: PathBuf) -> Result<ChaosFailoverProofResult> {
    use object_store::local::LocalFileSystem;
    use std::time::Duration;
    use transit_core::consensus::{
        ConsensusHandle, ElectionMonitor, ObjectStoreConsensus, StreamLease,
    };

    reset_directory(&root)?;

    let primary_root = root.join("primary");
    let follower_root = root.join("follower");
    let object_store_root = root.join("object-store");
    fs::create_dir_all(&object_store_root).context("create object store root")?;

    let store: std::sync::Arc<dyn object_store::ObjectStore> = std::sync::Arc::new(
        LocalFileSystem::new_with_prefix(&object_store_root).context("open object store")?,
    );
    // Shared consensus with a very short lease (1 second) for the proof
    let consensus = ObjectStoreConsensus::new(store.clone(), "leases").with_lease_duration_secs(1);
    let provider: std::sync::Arc<dyn transit_core::consensus::ConsensusProvider> =
        std::sync::Arc::new(consensus);

    let stream_id = StreamId::new("mission.chaos.root")?;

    // --- Primary: acquire lease, write data ---
    let primary = LocalEngine::open(
        LocalEngineConfig::new(&primary_root, NodeId::new("node-primary"))
            .with_provider(provider.clone()),
    )
    .context("open primary engine")?;

    let handle_a: std::sync::Arc<dyn ConsensusHandle> = provider
        .acquire(&stream_id, NodeId::new("node-primary"))
        .await
        .context("primary acquire")?;
    primary.bind_consensus(stream_id.clone(), handle_a);

    primary.create_stream(StreamDescriptor::root(
        stream_id.clone(),
        LineageMetadata::new(Some("mission".into()), Some("chaos-failover-proof".into())),
    ))?;
    primary.append(&stream_id, b"before-failover")?;

    // --- Simulate primary failure: let the lease expire ---
    // We don't heartbeat handle_a here, so it will expire.
    tokio::time::sleep(Duration::from_secs(2)).await;

    // --- Follower: configure with provider, start election monitor ---
    // Copy the primary's data to the follower to simulate a caught-up replica
    let primary_stream_dir = primary_root.join("streams").join(stream_id.as_str());
    let follower_stream_dir = follower_root.join("streams").join(stream_id.as_str());
    fs::create_dir_all(follower_stream_dir.join("segments"))?;

    // Copy the core files
    for file in &["active.segment", "manifest.json", "state.json"] {
        fs::copy(
            primary_stream_dir.join(file),
            follower_stream_dir.join(file),
        )?;
    }
    // No segments to copy in this proof yet (segment roll is at 2 records)

    let follower: std::sync::Arc<LocalEngine> = std::sync::Arc::new(
        LocalEngine::open(
            LocalEngineConfig::new(&follower_root, NodeId::new("node-follower"))
                .with_provider(provider.clone()),
        )
        .context("open follower engine")?,
    );

    let monitor = std::sync::Arc::new(ElectionMonitor::new(
        provider.clone(),
        follower.clone(),
        Duration::from_millis(100),
    ));
    let monitor_handle = monitor.spawn(vec![stream_id.clone()]);

    // Wait for the election to trigger and follower to acquire
    let election_start = std::time::Instant::now();
    let mut acquired = false;
    while election_start.elapsed() < Duration::from_secs(5) {
        if follower.is_leader(&stream_id) {
            acquired = true;
            break;
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
    let election_duration = election_start.elapsed();
    monitor_handle.abort();

    ensure!(acquired, "follower failed to acquire lease automatically");

    let promoted_append = follower
        .append(&stream_id, b"after-failover")
        .context("append on promoted follower")?;

    // --- Verify: the original primary is now fenced ---
    let primary_err = primary
        .append(&stream_id, b"should-fail")
        .expect_err("primary must be fenced after lease loss");
    let former_primary_fenced = primary_err.to_string().contains("FENCED")
        || primary_err.to_string().contains("not the leader");

    let lease: StreamLease = provider
        .current_lease(&stream_id)
        .await?
        .context("lease must exist")?;

    Ok(ChaosFailoverProofResult {
        data_root: root,
        stream_id: stream_id.as_str().to_owned(),
        primary_failure_simulated: true,
        election: ChaosFailoverElectionResult {
            trigger_reason: "lease_expired".to_owned(),
            new_owner: lease.owner.as_str().to_owned(),
            lease_version: lease.version,
            expires_at: lease.expires_at,
            election_duration_ms: election_duration.as_millis() as u64,
        },
        promoted_append: summarize_local_append(&promoted_append),
        former_primary_fenced,
        former_primary_rejection: Some(primary_err.to_string()),
        verified: acquired
            && former_primary_fenced
            && promoted_append.position().offset.value() == 1,
        error: None,
    })
}

fn render_local_engine_proof(result: LocalEngineProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit proof local-engine");
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

fn render_integrity_proof(result: IntegrityProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit proof integrity");
    println!("root: {}", result.data_root.display());
    println!("durability: {}", result.durability);
    println!("stream: {}", result.stream_id);
    println!("root records appended: {}", result.records_appended);
    println!("manifest id: {}", result.manifest_id);
    println!("manifest generation: {}", result.manifest_generation);
    println!("manifest root: {}", result.manifest_root);
    println!("verification api: {}", result.verification_api);
    println!("verification timing: after segment roll");
    println!("publication api: {}", result.publication_api);
    println!("restore api: {}", result.restore_api);
    println!("checkpoint api: {}", result.checkpoint_api);
    println!(
        "checkpoint verification api: {}",
        result.checkpoint_verification_api
    );

    if result.segments.is_empty() {
        println!("segments: none");
    } else {
        println!("segments:");
        for segment in &result.segments {
            println!(
                "  - {} offsets {}..{} records {} bytes {}",
                segment.segment_id,
                segment.start_offset,
                segment.last_offset,
                segment.record_count,
                segment.byte_length
            );
            println!(
                "    checksum {} {} {}",
                segment.checksum_algorithm,
                segment.checksum_digest,
                if segment.checksum_verified {
                    "PASS"
                } else {
                    "FAIL"
                }
            );
            println!(
                "    content digest {} {} {}",
                segment.content_digest_algorithm,
                segment.content_digest,
                if segment.content_digest_verified {
                    "PASS"
                } else {
                    "FAIL"
                }
            );
        }
    }

    if result.publication.published_segment_ids.is_empty() {
        println!("published segments: none");
    } else {
        println!("published segments:");
        for segment_id in &result.publication.published_segment_ids {
            println!("  - {segment_id}");
        }
    }
    println!(
        "manifest object key: {}",
        result.publication.manifest_object_key
    );
    println!("restored stream: {}", result.restore.stream_id);
    println!(
        "restored manifest generation: {}",
        result.restore.manifest_generation
    );
    println!("restored manifest root: {}", result.restore.manifest_root);
    println!(
        "manifest root parity: {}",
        if result.restore.manifest_roots_match {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!("restored next offset: {}", result.restore.next_offset);
    if result.restore.restored_segment_ids.is_empty() {
        println!("restored segments: none");
    } else {
        println!("restored segments:");
        for segment_id in &result.restore.restored_segment_ids {
            println!("  - {segment_id}");
        }
    }

    if result.checkpoints.is_empty() {
        println!("checkpoints: none");
    } else {
        println!("checkpoints:");
        for checkpoint in &result.checkpoints {
            println!(
                "  - {} [{}] head {} kind {} root {} {}",
                checkpoint.stream_id,
                checkpoint.lineage_kind,
                checkpoint.head_offset,
                checkpoint.kind,
                checkpoint.manifest_root,
                if checkpoint.verified { "PASS" } else { "FAIL" }
            );
            if let Some(error) = &checkpoint.error {
                println!("    error: {error}");
            }
        }
    }

    println!("tamper detection:");
    println!("  root: {}", result.tamper.data_root.display());
    println!("  stream: {}", result.tamper.stream_id);
    println!("  segment: {}", result.tamper.segment_id);
    println!("  path: {}", result.tamper.corrupted_path.display());
    println!("  verification api: {}", result.tamper.verification_api);
    println!(
        "  status: {}",
        if result.tamper.detected {
            "PASS"
        } else {
            "FAIL"
        }
    );
    if let Some(error) = &result.tamper.error {
        println!("  error: {error}");
    }

    println!("server parity:");
    println!("  root: {}", result.server_parity.data_root.display());
    println!("  server: {}", result.server_parity.server_addr);
    println!("  durability: {}", result.server_parity.durability);
    println!("  topology: {}", result.server_parity.topology);
    println!(
        "  verification api: {}",
        result.server_parity.verification_api
    );
    println!("  remote api: {}", result.server_parity.remote_api);
    println!("  server api: {}", result.server_parity.server_api);
    println!(
        "  accepted connections: {}",
        result.server_parity.accepted_connections
    );
    println!(
        "  graceful shutdown: {}",
        if result.server_parity.graceful_shutdown {
            "yes"
        } else {
            "no"
        }
    );
    if result.server_parity.streams.is_empty() {
        println!("  streams: none");
    } else {
        println!("  streams:");
        for stream in &result.server_parity.streams {
            println!(
                "    - {} [{}] root {} remote/local next {}/{} generation {}/{} segments {}/{} {}",
                stream.stream_id,
                stream.local_lineage_kind,
                stream.manifest_root,
                stream.remote_next_offset,
                stream.local_next_offset,
                stream.remote_manifest_generation,
                stream.local_manifest_generation,
                stream.remote_rolled_segment_count,
                stream.local_rolled_segment_count,
                if stream.verified { "PASS" } else { "FAIL" }
            );
            if !(stream.remote_parents.is_empty() && stream.local_parents.is_empty()) {
                println!(
                    "      parents remote/local: {:?} / {:?}",
                    stream.remote_parents, stream.local_parents
                );
            }
            if let Some(error) = &stream.error {
                println!("      error: {error}");
            }
        }
    }

    println!(
        "status: {}",
        if result.verified {
            "VERIFIED"
        } else {
            "FAILED"
        }
    );
    if let Some(error) = result.error {
        println!("error: {error}");
    }

    Ok(())
}

fn render_materialization_proof(result: MaterializationProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit proof materialization");
    println!("root: {}", result.data_root.display());
    println!("durability: {}", result.durability);
    println!("stream: {}", result.stream_id);
    println!("materialization id: {}", result.materialization_id);
    println!(
        "initial records appended: {}",
        result.initial_records_appended
    );
    println!("materialized count: {}", result.initial_materialized_count);
    println!("materialization api: {}", result.materialization_api);
    println!("checkpoint api: {}", result.checkpoint_api);
    println!("checkpoint anchor api: {}", result.checkpoint_anchor_api);
    println!("checkpoint stream: {}", result.checkpoint.stream_id);
    println!("checkpoint head: {}", result.checkpoint.head_offset);
    println!(
        "checkpoint manifest root: {}",
        result.checkpoint.manifest_root
    );
    println!("checkpoint kind: {}", result.checkpoint.kind);
    println!(
        "resume appended records: {}",
        result.resume.appended_after_checkpoint
    );
    println!("resume total count: {}", result.resume.resumed_total_count);
    println!(
        "resume processed new records: {}",
        result.resume.processed_new_records
    );
    if let Some(last_offset) = result.resume.resumed_last_offset {
        println!("resume last offset: {last_offset}");
    }
    println!(
        "resume status: {}",
        if result.resume.only_new_records_processed {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!("snapshot id: {}", result.snapshot.snapshot_id);
    println!(
        "snapshot source stream: {}",
        result.snapshot.source_stream_id
    );
    println!(
        "snapshot source head: {}",
        result.snapshot.source_head_offset
    );
    println!(
        "snapshot source manifest root: {}",
        result.snapshot.source_manifest_root
    );
    println!("snapshot root digest: {}", result.snapshot.root_digest);
    println!(
        "snapshot stored nodes: {}",
        result.snapshot.stored_node_count
    );
    println!("snapshot builder api: {}", result.snapshot.builder_api);
    println!("snapshot store api: {}", result.snapshot.store_api);
    println!("branch stream: {}", result.branch.stream_id);
    println!("branch parent stream: {}", result.branch.parent_stream_id);
    println!("branch parent head: {}", result.branch.parent_head_offset);
    println!("branch lineage kind: {}", result.branch.lineage_kind);
    println!(
        "branch materialization id: {}",
        result.branch.materialization_id
    );
    println!(
        "branch records appended: {}",
        result.branch.branch_records_appended
    );
    println!(
        "branch materialized count: {}",
        result.branch.materialized_count
    );
    println!(
        "branch checkpoint stream: {}",
        result.branch.checkpoint_stream_id
    );
    println!(
        "branch checkpoint head: {}",
        result.branch.checkpoint_head_offset
    );
    println!(
        "branch checkpoint manifest root: {}",
        result.branch.checkpoint_manifest_root
    );
    println!("branch checkpoint kind: {}", result.branch.checkpoint_kind);
    println!("branch snapshot id: {}", result.branch.snapshot.snapshot_id);
    println!(
        "branch snapshot source manifest root: {}",
        result.branch.snapshot.source_manifest_root
    );
    println!(
        "branch snapshot root digest: {}",
        result.branch.snapshot.root_digest
    );
    println!(
        "branch shared model: {}",
        if result.branch.shared_model_verified {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!(
        "branch distinct snapshot: {}",
        if result.branch.distinct_from_root_snapshot {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!(
        "status: {}",
        if result.verified {
            "VERIFIED"
        } else {
            "FAILED"
        }
    );
    if let Some(error) = result.error {
        println!("error: {error}");
    }

    Ok(())
}

fn render_tiered_engine_proof(result: TieredEngineProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit proof tiered-engine");
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
    println!(
        "published frontier: manifest {} generation {}, offsets {:?}..{:?}, next {}",
        result.published_frontier.manifest_id,
        result.published_frontier.manifest_generation,
        result.published_frontier.start_offset,
        result.published_frontier.last_offset,
        result.published_frontier.next_offset
    );
    println!(
        "published frontier root: {}",
        result.published_frontier.manifest_root
    );
    println!(
        "published frontier manifest object: {}",
        result.published_frontier.manifest_object_key
    );
    println!(
        "replicated ack: {} at {}, frontier next {}, manifest {}",
        result.replicated_ack.commitment,
        result.replicated_ack.position,
        result.replicated_ack.frontier_next_offset,
        result.replicated_ack.manifest_generation
    );
    println!(
        "replicated ack non-claim: {}",
        result.replicated_ack.non_claim
    );
    println!(
        "commitments: local head {:?}, replicated frontier {:?}, tiered restore {:?}",
        result.commitment_surface.local_head_offset,
        result.commitment_surface.replicated_frontier_offset,
        result.commitment_surface.tiered_restore_offset
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

fn render_controlled_failover_proof(
    result: ControlledFailoverProofResult,
    json: bool,
) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit proof controlled-failover");
    println!("root: {}", result.data_root.display());
    println!("stream: {}", result.stream_id);
    println!(
        "readiness replicated ack: {}",
        result.readiness.source_replicated_ack.position
    );
    println!(
        "readiness commitment: {}",
        result.readiness.source_replicated_ack.commitment
    );
    println!(
        "required frontier: manifest {} generation {} next {}",
        result.readiness.required_frontier.manifest_id,
        result.readiness.required_frontier.manifest_generation,
        result.readiness.required_frontier.next_offset
    );
    println!(
        "candidate frontier next offset: {}",
        result
            .readiness
            .local_frontier
            .as_ref()
            .map(|frontier| frontier.next_offset)
            .unwrap_or(0)
    );
    println!(
        "candidate restore next offset: {}",
        result.readiness.restore_next_offset
    );
    println!(
        "candidate posture: {}",
        result.readiness.candidate_posture.posture
    );
    println!(
        "frontier caught up: {}",
        if result.readiness.frontier_caught_up {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!(
        "ownership ready: {}",
        if result.readiness.ownership_ready {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!(
        "promotable: {}",
        if result.readiness.promotable {
            "PASS"
        } else {
            "FAIL"
        }
    );
    if result.readiness.blockers.is_empty() {
        println!("readiness blockers: none");
    } else {
        println!("readiness blockers:");
        for blocker in &result.readiness.blockers {
            println!("  - {blocker}");
        }
    }
    println!(
        "handoff: {} -> {} lease {} frontier next {}",
        result.handoff.previous_owner,
        result.handoff.new_owner,
        result.handoff.lease_version,
        result.handoff.frontier_next_offset
    );
    println!(
        "promoted posture: {}",
        result.handoff.promoted_posture.posture
    );
    println!(
        "promoted append: {} durability {}",
        result.handoff.promoted_append.position, result.handoff.promoted_append.durability
    );
    println!(
        "former primary posture: {}",
        result.fencing.former_primary_posture.posture
    );
    println!(
        "former primary append: {}",
        if result.fencing.former_primary_append_rejected {
            "rejected as expected"
        } else {
            "unexpectedly accepted"
        }
    );
    if let Some(rejection) = &result.fencing.rejection {
        println!("former primary rejection: {rejection}");
    }
    println!("bounded contract:");
    println!("  local: {}", result.contract.local);
    println!("  replicated: {}", result.contract.replicated);
    println!("  tiered: {}", result.contract.tiered);
    println!("  quorum: {}", result.contract.quorum);
    println!("  multi-primary: {}", result.contract.multi_primary);
    println!("  automation: {}", result.contract.automation);
    println!(
        "status: {}",
        if result.verified {
            "VERIFIED"
        } else {
            "FAILED"
        }
    );
    if let Some(error) = result.error {
        println!("error: {error}");
    }

    Ok(())
}

fn render_chaos_failover_proof(outcome: ChaosFailoverProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&outcome)?);
        return Ok(());
    }

    println!("transit proof chaos-failover");
    println!("data root: {}", outcome.data_root.display());
    println!("stream:    {}", outcome.stream_id);

    println!("\n[1] Primary Failure Simulation:");
    println!("  failure:        PRIMARY CRASH (NO HEARTBEAT)");
    println!("  simulated:      {}", outcome.primary_failure_simulated);

    println!("\n[2] Automatic Leader Election (ElectionMonitor):");
    println!("  reason:         {}", outcome.election.trigger_reason);
    println!("  new owner:      {}", outcome.election.new_owner);
    println!("  lease version:  {}", outcome.election.lease_version);
    println!(
        "  election time:  {}ms",
        outcome.election.election_duration_ms
    );

    println!("\n[3] Post-Promotion Append:");
    println!(
        "  position:       {} (durability={})",
        outcome.promoted_append.position, outcome.promoted_append.durability
    );

    println!("\n[4] Stale-Primary Fencing:");
    println!(
        "  fenced:         {} (FAIL_SAFE)",
        outcome.former_primary_fenced
    );
    if let Some(rejection) = &outcome.former_primary_rejection {
        println!("  rejection:      {}", rejection);
    }

    if outcome.verified {
        println!("\nstatus: VERIFIED");
    } else {
        println!("\nstatus: FAILED");
        if let Some(error) = outcome.error {
            println!("error: {error}");
        }
    }

    Ok(())
}

fn render_networked_server_proof(result: NetworkedServerProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit proof networked-server");
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

fn render_reference_projection_proof(
    result: ReferenceProjectionProofResult,
    json: bool,
) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit proof reference-projection");
    println!("root: {}", result.data_root.display());
    println!("durability: {}", result.durability);
    println!("stream: {}", result.stream_id);
    println!("materialization id: {}", result.materialization_id);
    println!("materialization api: {}", result.materialization_api);
    println!("checkpoint api: {}", result.checkpoint_api);
    println!("checkpoint anchor api: {}", result.checkpoint_anchor_api);
    println!(
        "checkpoint verification api: {}",
        result.checkpoint_verification_api
    );
    println!("resume api: {}", result.resume_api);
    println!(
        "authoritative replay api: {}",
        result.authoritative_replay_api
    );
    println!("checkpoint stream: {}", result.checkpoint.stream_id);
    println!("checkpoint head: {}", result.checkpoint.head_offset);
    println!(
        "checkpoint manifest root: {}",
        result.checkpoint.manifest_root
    );
    println!("checkpoint kind: {}", result.checkpoint.kind);
    println!(
        "checkpoint verification: {}",
        if result.checkpoint.verified {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!(
        "checkpoint shared model: {}",
        if result.checkpoint.shared_model_verified {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!(
        "resume appended records: {}",
        result.resume.appended_after_checkpoint
    );
    println!(
        "resume replay window: {}..{}",
        result.resume.replay_from_offset, result.resume.source_next_offset
    );
    println!(
        "resume pending records: {}",
        result.resume.pending_record_count
    );
    println!(
        "resumed references: {}",
        result.resume.resumed_reference_count
    );
    println!(
        "resume only new history: {}",
        if result.resume.resumed_only_new_history {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!(
        "rebuilt authoritative records: {}",
        result.rebuild.authoritative_record_count
    );
    println!(
        "rebuilt references: {}",
        result.rebuild.rebuilt_reference_count
    );
    println!(
        "equivalent views: {}",
        if result.equivalent_views {
            "PASS"
        } else {
            "FAIL"
        }
    );
    println!(
        "projection-only authority used: {}",
        if result.projection_only_authority_used {
            "yes"
        } else {
            "no"
        }
    );
    println!(
        "status: {}",
        if result.verified {
            "VERIFIED"
        } else {
            "FAILED"
        }
    );
    if let Some(error) = result.error {
        println!("error: {error}");
    }

    Ok(())
}

fn render_hosted_authority_proof(result: HostedAuthorityProofResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit proof hosted-authority");
    println!("root: {}", result.data_root.display());
    println!("server: {}", result.server_addr);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("authority surface: {}", result.authority_surface);
    println!("consumer boundary: {}", result.consumer_boundary);
    println!(
        "root create: {} next {}",
        result.root_stream.stream_id, result.root_stream.next_offset
    );
    println!("producer appends:");
    for append in &result.producer_appends {
        println!("  - {} ({})", append.position, append.durability);
    }
    println!(
        "reader replay: {} records, head {:?}",
        result.reader_replay.record_count, result.reader_replay.head_offset
    );
    println!("replayed payloads:");
    for record in &result.reader_replay.records {
        println!("  - {} {}", record.position, record.payload_text);
    }
    println!(
        "replay matches acknowledged history: {}",
        if result.replay_matches_acknowledged_history {
            "yes"
        } else {
            "no"
        }
    );
    println!(
        "remote tier publication performed: {}",
        if result.remote_tier_publication_performed {
            "yes"
        } else {
            "no"
        }
    );
    println!("tiered non-claim: {}", result.tiered_non_claim);
    println!(
        "embedded authority used by consumer: {}",
        if result.embedded_authority_used {
            "yes"
        } else {
            "no"
        }
    );
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

fn render_warm_cache_recovery_proof(
    result: WarmCacheRecoveryProofResult,
    json: bool,
) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit proof warm-cache-recovery");
    println!("root: {}", result.data_root.display());
    println!("stream: {}", result.stream_id);
    println!("local write durability: {}", result.local_write_durability);
    println!(
        "authoritative recovery durability: {}",
        result.authoritative_recovery_durability
    );
    println!(
        "published frontier: manifest {} generation {} next {}",
        result.published_frontier.manifest_id,
        result.published_frontier.manifest_generation,
        result.published_frontier.next_offset
    );
    println!(
        "initial hydrate: bootstrapped {}, restored {} segments, replayed {} records",
        if result.initial_hydrate.bootstrapped {
            "yes"
        } else {
            "no"
        },
        result.initial_hydrate.restored_segment_ids.len(),
        result.initial_hydrate.replay.record_count
    );
    println!(
        "warm cache removed: {}",
        if result.warm_cache_removed {
            "yes"
        } else {
            "no"
        }
    );
    println!(
        "restart hydrate after cache loss: bootstrapped {}, restored {} segments, replayed {} records",
        if result.restart_hydrate.bootstrapped {
            "yes"
        } else {
            "no"
        },
        result.restart_hydrate.restored_segment_ids.len(),
        result.restart_hydrate.replay.record_count
    );
    println!(
        "restored history matches authoritative replay: {}",
        if result.restored_history_matches {
            "yes"
        } else {
            "no"
        }
    );
    println!("cache rebuild source: {}", result.authoritative_source);
    println!("local non-claim: {}", result.local_non_claim);
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
    println!("first position: {}", result.position);
    println!("last position: {}", result.last_position);
    println!("records: {}", result.record_count);
    println!("manifest generation: {}", result.manifest_generation);
    for segment_id in result.rolled_segment_ids {
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

fn render_streams_list(result: RemoteStreamListResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit streams list");
    println!("server: {}", result.server_addr);
    println!("request: {}", result.request_id);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("streams: {}", result.stream_count);

    for stream in result.streams {
        println!();
        println!("stream: {}", stream.stream_id);
        println!("lineage: {}", stream.lineage_kind);
        if stream.parents.is_empty() {
            println!("parents: none");
        } else {
            println!("parents: {}", stream.parents.join(", "));
        }
        if let Some(merge_base) = stream.merge_base {
            println!("merge base: {merge_base}");
        }
        println!("records: {}", stream.record_count);
        match stream.head_offset {
            Some(head_offset) => println!("head offset: {head_offset}"),
            None => println!("head offset: empty"),
        }
        println!("active records: {}", stream.active_record_count);
        println!(
            "active segment start offset: {}",
            stream.active_segment_start_offset
        );
        println!("manifest generation: {}", stream.manifest_generation);
        println!("rolled segments: {}", stream.rolled_segment_count);
    }

    Ok(())
}

fn render_streams_delete(result: RemoteDeletedStreamResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit streams delete");
    println!("server: {}", result.server_addr);
    println!("request: {}", result.request_id);
    println!("durability: {}", result.durability);
    println!("topology: {}", result.topology);
    println!("stream: {}", result.stream_id);
    println!("records removed: {}", result.record_count);
    println!("deleted path: {}", result.deleted_path.display());
    Ok(())
}

fn render_produce(result: ProduceResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit produce");
    println!("server: {}", result.server_addr);
    println!("stream: {}", result.stream_id);
    println!("appends: {}", result.append_count);
    if let Some(last_position) = result.last_position {
        println!("last position: {last_position}");
    }
    for append in result.appends {
        println!("{}", append.position);
    }
    Ok(())
}

fn render_consume(result: ConsumeResult, with_offsets: bool, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    if with_offsets {
        println!("transit consume");
        println!("server: {}", result.server_addr);
        println!("request: {}", result.request_id);
        println!("durability: {}", result.durability);
        println!("topology: {}", result.topology);
        println!("stream: {}", result.stream_id);
        println!("from offset: {}", result.from_offset);
        println!("records: {}", result.record_count);
        if let Some(head_offset) = result.head_offset {
            println!("head offset: {head_offset}");
        }
        for record in result.records {
            println!("{} {}", record.position, record.payload_text);
        }
        return Ok(());
    }

    for record in result.records {
        println!("{}", record.payload_text);
    }
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

fn render_storage_probe(result: StorageProbeResult, json: bool) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(&result)?);
        return Ok(());
    }

    println!("transit storage probe");
    if result.config_sources.is_empty() {
        println!("config: defaults only");
    } else {
        println!(
            "config: {}",
            result
                .config_sources
                .iter()
                .map(|path| path.display().to_string())
                .collect::<Vec<_>>()
                .join(", ")
        );
    }
    println!("node: {}", result.node_id);
    println!("mode: {}", result.mode);
    println!("provider: {}", result.provider);
    println!("durability: {}", result.durability);
    println!("data dir: {}", result.data_dir.display());
    println!("cache dir: {}", result.cache_dir.display());
    println!("authority: {}", result.authority);
    println!("object prefix: {}", result.object_prefix);
    println!("authority check: {}", result.authority_check);
    println!(
        "authority bootstrap: {}",
        if result.authority_ready {
            "ok"
        } else {
            "failed"
        }
    );
    if let Some(object_path) = &result.object_path {
        println!("object: {object_path}");
    }
    if let Some(bytes_written) = result.bytes_written {
        println!("bytes written: {bytes_written}");
    }
    println!(
        "data dir probe: {}",
        if result.data_dir_ready {
            "ok"
        } else {
            "failed"
        }
    );
    println!(
        "cache dir probe: {}",
        if result.cache_dir_ready {
            "ok"
        } else {
            "failed"
        }
    );
    if let Some(round_trip_ok) = result.round_trip_ok {
        println!(
            "round trip: {}",
            if round_trip_ok { "ok" } else { "failed" }
        );
    }
    if let Some(cleanup_ok) = result.cleanup_ok {
        println!("cleanup: {}", if cleanup_ok { "ok" } else { "failed" });
    }
    println!("guarantee: {}", result.guarantee);
    println!("non-claim: {}", result.non_claim);

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::Parser;
    use std::path::Path;
    use tempfile::tempdir;

    fn start_server() -> (tempfile::TempDir, ServerHandle, SocketAddr) {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path(), NodeId::new("test-node")),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let server_addr = server.local_addr();
        (temp_dir, server, server_addr)
    }

    fn load_temp_config(dir: &Path, contents: &str) -> LoadedTransitConfig {
        let config_path = dir.join("transit.toml");
        fs::write(&config_path, contents).expect("write transit config");
        load_transit_config(Some(config_path)).expect("load transit config")
    }

    #[test]
    fn cli_promotes_status_and_proofs_to_their_new_namespaces() {
        let cli = Cli::try_parse_from([
            "transit",
            "status",
            "--root",
            "target/demo",
            "--stream-id",
            "task.root",
        ])
        .expect("parse top-level status command");
        assert!(matches!(cli.command, Commands::Status(_)));

        let cli = Cli::try_parse_from(["transit", "streams", "list"])
            .expect("parse streams list command");
        assert!(matches!(cli.command, Commands::Streams(_)));

        let cli = Cli::try_parse_from([
            "transit",
            "produce",
            "--stream-id",
            "task.root",
            "--payload-text",
            "hello",
        ])
        .expect("parse produce command");
        assert!(matches!(cli.command, Commands::Produce(_)));

        let cli = Cli::try_parse_from([
            "transit",
            "consume",
            "--stream-id",
            "task.root",
            "--from-offset",
            "0",
        ])
        .expect("parse consume command");
        assert!(matches!(cli.command, Commands::Consume(_)));

        let cli =
            Cli::try_parse_from(["transit", "proof", "local-engine", "--root", "target/demo"])
                .expect("parse proof command");
        assert!(matches!(cli.command, Commands::Proof(_)));

        let cli = Cli::try_parse_from(["transit", "storage", "probe"])
            .expect("parse storage probe command");
        assert!(matches!(cli.command, Commands::Storage(_)));

        let cli = Cli::try_parse_from(["transit", "verify", "lineage", "--stream-id", "task.root"])
            .expect("parse verify lineage command");
        assert!(matches!(
            cli.command,
            Commands::Verify(VerifyArgs {
                command: VerifyCommands::Lineage(_)
            })
        ));

        let cli = Cli::try_parse_from([
            "transit",
            "verify",
            "checkpoint",
            "--checkpoint-path",
            "target/checkpoint.json",
        ])
        .expect("parse verify checkpoint command");
        assert!(matches!(
            cli.command,
            Commands::Verify(VerifyArgs {
                command: VerifyCommands::Checkpoint(_)
            })
        ));
    }

    #[test]
    fn cli_rejects_removed_mission_wrapper_old_probe_and_old_top_level_proofs() {
        let error = Cli::try_parse_from(["transit", "mission", "status", "--repo-root", "."])
            .expect_err("mission wrapper should be rejected");

        assert!(
            error
                .to_string()
                .contains("unrecognized subcommand 'mission'")
        );

        let error = Cli::try_parse_from(["transit", "status", "--repo-root", "."])
            .expect_err("old repo-root status argument should be rejected");

        assert!(error.to_string().contains("--repo-root"));

        let error = Cli::try_parse_from(["transit", "object-store", "probe"])
            .expect_err("object-store probe should be rejected");

        assert!(
            error
                .to_string()
                .contains("unrecognized subcommand 'object-store'")
        );

        let error = Cli::try_parse_from(["transit", "local-engine-proof", "--root", "target/demo"])
            .expect_err("old top-level proof command should be rejected");

        assert!(
            error
                .to_string()
                .contains("unrecognized subcommand 'local-engine-proof'")
        );

        let error = Cli::try_parse_from(["transit", "verify-lineage", "--stream-id", "task.root"])
            .expect_err("old top-level verify-lineage command should be rejected");

        assert!(
            error
                .to_string()
                .contains("unrecognized subcommand 'verify-lineage'")
        );

        let error = Cli::try_parse_from([
            "transit",
            "verify-checkpoint",
            "--checkpoint-path",
            "target/checkpoint.json",
        ])
        .expect_err("old top-level verify-checkpoint command should be rejected");

        assert!(
            error
                .to_string()
                .contains("unrecognized subcommand 'verify-checkpoint'")
        );
    }

    #[test]
    fn status_reports_local_log_state_instead_of_bootstrap_state() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path(), NodeId::new("test-node"))
                .with_segment_max_records(2)
                .expect("config"),
        )
        .expect("engine");
        let root_stream = StreamId::new("task.root").expect("stream id");
        let branch_stream = StreamId::new("task.branch").expect("stream id");

        engine
            .create_stream(StreamDescriptor::root(
                root_stream.clone(),
                LineageMetadata::new(Some("test".into()), Some("status".into())),
            ))
            .expect("create root stream");
        engine.append(&root_stream, b"first").expect("append first");
        engine
            .append(&root_stream, b"second")
            .expect("append second");
        engine
            .create_stream(
                StreamDescriptor::branch(
                    branch_stream.clone(),
                    StreamPosition::new(root_stream.clone(), Offset::new(1)),
                    LineageMetadata::new(Some("test".into()), Some("branch".into()))
                        .with_branch_kind("review"),
                )
                .expect("branch descriptor"),
            )
            .expect("create branch stream");

        let status = run_status(temp_dir.path().to_path_buf(), None).expect("run status");
        assert_eq!(status.state, "active");
        assert_eq!(status.stream_count, 2);

        let root_status = status
            .streams
            .iter()
            .find(|stream| stream.stream_id == "task.root")
            .expect("root stream status");
        assert_eq!(root_status.lineage_kind, "root");
        assert_eq!(root_status.record_count, 2);
        assert_eq!(root_status.head_offset, Some(1));
        assert_eq!(root_status.rolled_segment_count, 1);

        let branch_status = status
            .streams
            .iter()
            .find(|stream| stream.stream_id == "task.branch")
            .expect("branch stream status");
        assert_eq!(branch_status.lineage_kind, "branch");
        assert_eq!(branch_status.parents, vec!["task.root@1"]);
        assert_eq!(branch_status.record_count, 2);
        assert_eq!(branch_status.head_offset, Some(1));
        assert_eq!(branch_status.active_record_count, 0);

        let filtered =
            run_status(temp_dir.path().to_path_buf(), Some("task.root")).expect("filtered status");
        assert_eq!(filtered.stream_count, 1);
        assert_eq!(filtered.streams[0].stream_id, "task.root");
    }

    #[test]
    fn streams_produce_and_consume_cover_the_kcat_style_remote_flow() {
        let (_temp_dir, server, server_addr) = start_server();

        let listed_before = run_streams_list(server_addr).expect("list streams");
        assert_eq!(listed_before.stream_count, 0);

        let created = run_streams_create(
            server_addr,
            StreamsCreateArgs {
                server_addr: Some(server_addr),
                stream_id: "task.root".into(),
                actor: Some("cli".into()),
                reason: Some("create".into()),
                labels: vec![],
                json: true,
            },
        )
        .expect("create stream");
        assert_eq!(created.stream_id, "task.root");

        let listed_after = run_streams_list(server_addr).expect("list streams");
        assert_eq!(listed_after.stream_count, 1);
        assert_eq!(listed_after.streams[0].stream_id, "task.root");
        assert_eq!(listed_after.streams[0].lineage_kind, "root");

        let produced = run_produce(
            server_addr,
            ProduceArgs {
                server_addr: Some(server_addr),
                stream_id: "task.root".into(),
                payload_text: vec!["first".into(), "second".into()],
                json: true,
            },
        )
        .expect("produce");
        assert_eq!(produced.append_count, 2);
        assert_eq!(produced.last_position.as_deref(), Some("task.root@1"));

        let consumed = run_consume(
            server_addr,
            ConsumeArgs {
                server_addr: Some(server_addr),
                stream_id: "task.root".into(),
                from_offset: 1,
                limit: Some(1),
                with_offsets: false,
                json: true,
            },
        )
        .expect("consume");
        assert_eq!(consumed.record_count, 1);
        assert_eq!(consumed.records[0].payload_text, "second");
        assert_eq!(consumed.head_offset, Some(1));

        let deleted = run_streams_delete(
            server_addr,
            StreamsDeleteArgs {
                server_addr: Some(server_addr),
                stream_id: "task.root".into(),
                force: true,
                json: true,
            },
        )
        .expect("delete");
        assert_eq!(deleted.stream_id, "task.root");
        assert_eq!(deleted.record_count, 2);

        server.shutdown().expect("shutdown server");
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
            payload_text: vec!["first".into()],
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
            payload_text: vec!["hello".into()],
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
    fn remote_cli_batch_append_accepts_multiple_payload_values_and_reports_batch_metadata() {
        let (_temp_dir, server, server_addr) = start_server();
        run_remote_create_root(ServerCreateRootArgs {
            server_addr,
            stream_id: "task.root".into(),
            actor: Some("test".into()),
            reason: Some("batch".into()),
            labels: vec!["kind=root".into()],
            json: true,
        })
        .expect("create root stream");

        let append = run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: "task.root".into(),
            payload_text: vec!["first".into(), "second".into(), "third".into()],
            json: true,
        })
        .expect("append batch");
        let read = run_remote_read(ServerReadArgs {
            server_addr,
            stream_id: "task.root".into(),
            json: true,
        })
        .expect("read");

        assert_eq!(append.position, "task.root@0");
        assert_eq!(append.last_position, "task.root@2");
        assert_eq!(append.record_count, 3);
        assert_eq!(read.record_count, 3);
        assert_eq!(
            read.records
                .iter()
                .map(|record| record.payload_text.as_str())
                .collect::<Vec<_>>(),
            vec!["first", "second", "third"]
        );

        render_remote_append(append, false).expect("render batch append");
        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_cli_batch_append_results_serialize_batch_metadata_for_mission_scripts() {
        let (_temp_dir, server, server_addr) = start_server();
        run_remote_create_root(ServerCreateRootArgs {
            server_addr,
            stream_id: "task.root".into(),
            actor: Some("proof".into()),
            reason: Some("batch".into()),
            labels: vec![],
            json: true,
        })
        .expect("create root stream");

        let append = run_remote_append(ServerAppendArgs {
            server_addr,
            stream_id: "task.root".into(),
            payload_text: vec!["first".into(), "second".into()],
            json: true,
        })
        .expect("append batch");
        let append_json = serde_json::to_value(&append).expect("serialize append");

        assert_eq!(
            append_json
                .get("position")
                .and_then(serde_json::Value::as_str),
            Some("task.root@0")
        );
        assert_eq!(
            append_json
                .get("last_position")
                .and_then(serde_json::Value::as_str),
            Some("task.root@1")
        );
        assert_eq!(
            append_json
                .get("record_count")
                .and_then(serde_json::Value::as_u64),
            Some(2)
        );
        assert!(
            append_json
                .get("rolled_segment_ids")
                .and_then(serde_json::Value::as_array)
                .is_some()
        );

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
            payload_text: vec!["proof".into()],
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

    #[tokio::test]
    async fn server_run_accepts_tiered_config_and_binds_against_authored_object_store_authority() {
        let temp_dir = tempdir().expect("temp dir");
        let data_dir = temp_dir.path().join("server-data");
        let cache_dir = temp_dir.path().join("server-cache");
        let object_store_root = temp_dir.path().join("object-store");
        let config = load_temp_config(
            temp_dir.path(),
            &format!(
                r#"
[node]
id = "hosted-node"
mode = "server"
data_dir = "{data_dir}"
cache_dir = "{cache_dir}"

[storage]
provider = "filesystem"
bucket = "{object_store_root}"
prefix = "hosted/runtime"
durability = "tiered"

[server]
listen_addr = "127.0.0.1:0"
"#,
                data_dir = data_dir.display(),
                cache_dir = cache_dir.display(),
                object_store_root = object_store_root.display(),
            ),
        );

        let result = run_server(
            ServerRunArgs {
                root: None,
                listen_addr: None,
                serve_for_ms: Some(1),
                node_id: None,
                consensus_root: None,
                json: true,
            },
            &config,
        )
        .await
        .expect("run server");

        assert_eq!(result.data_root, data_dir);
        assert_eq!(result.durability, "local");
        assert!(object_store_root.is_dir());
        assert!(data_dir.join("streams").is_dir());
    }

    #[test]
    fn tiered_configured_hosted_server_keeps_remote_acknowledgements_local_until_remote_authority_participates()
     {
        let temp_dir = tempdir().expect("temp dir");
        let data_dir = temp_dir.path().join("server-data");
        let cache_dir = temp_dir.path().join("server-cache");
        let object_store_root = temp_dir.path().join("object-store");
        let config = load_temp_config(
            temp_dir.path(),
            &format!(
                r#"
[node]
id = "hosted-node"
mode = "server"
data_dir = "{data_dir}"
cache_dir = "{cache_dir}"

[storage]
provider = "filesystem"
bucket = "{object_store_root}"
prefix = "hosted/runtime"
durability = "tiered"

[server]
listen_addr = "127.0.0.1:0"
"#,
                data_dir = data_dir.display(),
                cache_dir = cache_dir.display(),
                object_store_root = object_store_root.display(),
            ),
        );
        let requested_listen_addr = "127.0.0.1:0".parse().expect("listen addr");
        let server = bind_hosted_runtime_server(
            &config,
            &resolve_local_root(None, &config),
            requested_listen_addr,
            config.config().effective_node_id(),
        )
        .expect("bind hosted runtime server");
        let client = TransitClient::new(server.local_addr());
        let stream_id = StreamId::new("cli.hosted.tiered").expect("stream id");

        let created = client
            .create_root(
                &stream_id,
                LineageMetadata::new(
                    Some("hub.reader".into()),
                    Some("tiered-config-server".into()),
                ),
            )
            .expect("create root");
        let append = client
            .append(&stream_id, br#"{"kind":"order","id":"order-1"}"#)
            .expect("append");
        let replay = client.read(&stream_id).expect("read");

        assert_eq!(server.durability().as_str(), "local");
        assert_eq!(created.ack().durability(), "local");
        assert_eq!(append.ack().durability(), "local");
        assert_eq!(replay.ack().durability(), "local");

        server.shutdown().expect("shutdown server");
    }

    #[tokio::test]
    async fn server_run_surfaces_hosted_provider_validation_errors_clearly() {
        let temp_dir = tempdir().expect("temp dir");
        let config = load_temp_config(
            temp_dir.path(),
            r#"
[node]
id = "hosted-node"
mode = "server"
data_dir = "server-data"
cache_dir = "server-cache"

[storage]
provider = "s3"
bucket = "transit-prod"
durability = "tiered"

[server]
listen_addr = "127.0.0.1:0"
"#,
        );

        let error = run_server(
            ServerRunArgs {
                root: None,
                listen_addr: None,
                serve_for_ms: Some(1),
                node_id: None,
                consensus_root: None,
                json: true,
            },
            &config,
        )
        .await
        .expect_err("server run should reject incomplete hosted provider config");

        assert!(
            error
                .to_string()
                .contains("resolve s3 object-store authority for transit server run")
        );
        assert!(error.chain().any(|cause| {
            cause.to_string().contains(
                "s3 object-store provider requires [storage].region or [storage].endpoint",
            )
        }));
    }

    #[tokio::test]
    async fn integrity_proof_exercises_segment_checksum_restore_checkpoint_tamper_and_server_parity_verification()
     {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_integrity_proof(temp_dir.path().join("integrity"))
            .await
            .expect("run integrity proof");

        assert_eq!(proof.durability, "local");
        assert_eq!(proof.stream_id, "mission.integrity.root");
        assert_eq!(proof.records_appended, 2);
        assert_eq!(proof.verification_api, "LocalEngine::verify_local_lineage");
        assert_eq!(
            proof.publication_api,
            "LocalEngine::publish_rolled_segments"
        );
        assert_eq!(
            proof.restore_api,
            "LocalEngine::restore_stream_from_remote_manifest"
        );
        assert_eq!(proof.checkpoint_api, "LocalEngine::checkpoint");
        assert_eq!(
            proof.checkpoint_verification_api,
            "LocalEngine::verify_checkpoint"
        );
        assert!(proof.verified);
        assert_eq!(proof.segments.len(), 1);
        assert_eq!(proof.segments[0].checksum_algorithm, "fnv1a64");
        assert_eq!(proof.segments[0].content_digest_algorithm, "sha256");
        assert!(proof.segments[0].checksum_verified);
        assert!(proof.segments[0].content_digest_verified);
        assert_eq!(proof.manifest_generation, 2);
        assert_eq!(proof.publication.published_segment_ids.len(), 1);
        assert!(
            proof
                .publication
                .manifest_object_key
                .contains("integrity-proof")
        );
        assert_eq!(proof.restore.stream_id, "mission.integrity.root");
        assert_eq!(proof.restore.manifest_generation, proof.manifest_generation);
        assert_eq!(proof.restore.manifest_root, proof.manifest_root);
        assert!(proof.restore.manifest_roots_match);
        assert_eq!(proof.restore.next_offset, 2);
        assert_eq!(proof.checkpoints.len(), 2);
        assert_eq!(proof.checkpoints[0].lineage_kind, "branch");
        assert_eq!(proof.checkpoints[1].lineage_kind, "merge");
        assert!(
            proof
                .checkpoints
                .iter()
                .all(|checkpoint| checkpoint.verified)
        );
        assert_eq!(
            proof.tamper.verification_api,
            "LocalEngine::verify_local_lineage"
        );
        assert!(proof.tamper.detected);
        assert_eq!(proof.tamper.stream_id, "mission.integrity.tamper");
        assert!(
            proof
                .tamper
                .error
                .as_deref()
                .is_some_and(|message| message.contains("segment checksum mismatch"))
        );
        assert_eq!(
            proof.server_parity.verification_api,
            "LocalEngine::verify_local_lineage"
        );
        assert_eq!(proof.server_parity.remote_api, "RemoteClient");
        assert_eq!(proof.server_parity.server_api, "ServerHandle::bind");
        assert_eq!(proof.server_parity.durability, "local");
        assert_eq!(proof.server_parity.topology, "single_node");
        assert!(proof.server_parity.graceful_shutdown);
        assert!(proof.server_parity.accepted_connections > 0);
        assert!(proof.server_parity.verified);
        assert_eq!(proof.server_parity.streams.len(), 4);
        assert_eq!(proof.server_parity.streams[0].local_lineage_kind, "root");
        assert_eq!(proof.server_parity.streams[1].local_lineage_kind, "branch");
        assert_eq!(proof.server_parity.streams[3].local_lineage_kind, "merge");
        assert!(
            proof
                .server_parity
                .streams
                .iter()
                .all(|stream| stream.verified)
        );
    }

    #[tokio::test]
    async fn integrity_proof_results_serialize_cleanly_for_mission_scripts() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_integrity_proof(temp_dir.path().join("integrity-json"))
            .await
            .expect("run proof");
        let proof_json = serde_json::to_value(&proof).expect("serialize proof");

        assert_eq!(
            proof_json
                .get("stream_id")
                .and_then(serde_json::Value::as_str),
            Some("mission.integrity.root")
        );
        assert_eq!(
            proof_json
                .get("verified")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["restore"]
                .get("manifest_roots_match")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["checkpoints"][0]
                .get("verified")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["tamper"]
                .get("detected")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["server_parity"]
                .get("verified")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["segments"][0]
                .get("content_digest_verified")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
    }

    #[tokio::test]
    async fn materialization_proof_exercises_checkpoint_and_resume() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_materialization_proof(temp_dir.path().join("materialization"))
            .await
            .expect("run materialization proof");

        assert_eq!(proof.durability, "local");
        assert_eq!(proof.stream_id, "mission.materialization.root");
        assert_eq!(proof.materialization_id, "mission.materialization.count");
        assert_eq!(proof.initial_records_appended, 2);
        assert_eq!(proof.initial_materialized_count, 2);
        assert_eq!(
            proof.materialization_api,
            "LocalMaterializationEngine::catch_up"
        );
        assert_eq!(
            proof.checkpoint_api,
            "LocalMaterializationEngine::checkpoint"
        );
        assert_eq!(proof.checkpoint_anchor_api, "LocalEngine::checkpoint");
        assert_eq!(proof.checkpoint.stream_id, "mission.materialization.root");
        assert_eq!(proof.checkpoint.head_offset, 1);
        assert_eq!(proof.checkpoint.kind, "materialize");
        assert_eq!(proof.resume.appended_after_checkpoint, 2);
        assert_eq!(proof.resume.resumed_total_count, 4);
        assert_eq!(proof.resume.resumed_last_offset, Some(3));
        assert_eq!(proof.resume.processed_new_records, 2);
        assert!(proof.resume.only_new_records_processed);
        assert_eq!(proof.snapshot.snapshot_id, "snapshot-00000000000000000003");
        assert_eq!(
            proof.snapshot.source_stream_id,
            "mission.materialization.root"
        );
        assert_eq!(proof.snapshot.source_head_offset, 3);
        assert!(!proof.snapshot.source_manifest_root.is_empty());
        assert!(!proof.snapshot.root_digest.is_empty());
        assert!(proof.snapshot.stored_node_count >= 1);
        assert_eq!(
            proof.snapshot.builder_api,
            "ProllyTreeBuilder::build_from_entries"
        );
        assert_eq!(proof.snapshot.store_api, "ObjectStoreProllyStore");
        assert_eq!(proof.branch.stream_id, "mission.materialization.branch");
        assert_eq!(
            proof.branch.parent_stream_id,
            "mission.materialization.root"
        );
        assert_eq!(proof.branch.parent_head_offset, 0);
        assert_eq!(proof.branch.lineage_kind, "branch");
        assert_eq!(
            proof.branch.materialization_id,
            "mission.materialization.count.branch"
        );
        assert_eq!(proof.branch.branch_records_appended, 2);
        assert_eq!(proof.branch.materialized_count, 3);
        assert_eq!(
            proof.branch.checkpoint_stream_id,
            "mission.materialization.branch"
        );
        assert_eq!(proof.branch.checkpoint_head_offset, 2);
        assert_eq!(proof.branch.checkpoint_kind, "materialize");
        assert_eq!(
            proof.branch.snapshot.source_stream_id,
            "mission.materialization.branch"
        );
        assert_eq!(proof.branch.snapshot.source_head_offset, 2);
        assert!(proof.branch.shared_model_verified);
        assert!(proof.branch.distinct_from_root_snapshot);
        assert_ne!(
            proof.branch.snapshot.root_digest,
            proof.snapshot.root_digest
        );
        assert!(proof.verified);
        assert!(proof.error.is_none());
    }

    #[tokio::test]
    async fn materialization_proof_results_serialize_cleanly_for_mission_scripts() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_materialization_proof(temp_dir.path().join("materialization-json"))
            .await
            .expect("run materialization proof");
        let proof_json = serde_json::to_value(&proof).expect("serialize proof");

        assert_eq!(
            proof_json
                .get("stream_id")
                .and_then(serde_json::Value::as_str),
            Some("mission.materialization.root")
        );
        assert_eq!(
            proof_json
                .get("checkpoint_api")
                .and_then(serde_json::Value::as_str),
            Some("LocalMaterializationEngine::checkpoint")
        );
        assert_eq!(
            proof_json["resume"]
                .get("processed_new_records")
                .and_then(serde_json::Value::as_u64),
            Some(2)
        );
        assert_eq!(
            proof_json["snapshot"]
                .get("snapshot_id")
                .and_then(serde_json::Value::as_str),
            Some("snapshot-00000000000000000003")
        );
        assert_eq!(
            proof_json["snapshot"]
                .get("source_head_offset")
                .and_then(serde_json::Value::as_u64),
            Some(3)
        );
        assert_eq!(
            proof_json["snapshot"]
                .get("store_api")
                .and_then(serde_json::Value::as_str),
            Some("ObjectStoreProllyStore")
        );
        assert_eq!(
            proof_json["branch"]
                .get("lineage_kind")
                .and_then(serde_json::Value::as_str),
            Some("branch")
        );
        assert_eq!(
            proof_json["branch"]
                .get("shared_model_verified")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["branch"]
                .get("distinct_from_root_snapshot")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json
                .get("verified")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
    }

    #[tokio::test]
    async fn reference_projection_proof_rebuilds_equivalent_views_from_replay_and_resume() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_reference_projection_proof(temp_dir.path().join("reference-projection"))
            .await
            .expect("run reference projection proof");

        assert_eq!(proof.durability, "local");
        assert_eq!(
            proof.stream_id,
            "mission.materialization.reference-projection.root"
        );
        assert_eq!(
            proof.materialization_id,
            "mission.materialization.reference-projection"
        );
        assert_eq!(
            proof.materialization_api,
            "ReferenceProjectionMaterializer::catch_up"
        );
        assert_eq!(
            proof.checkpoint_api,
            "ReferenceProjectionMaterializer::checkpoint"
        );
        assert_eq!(proof.checkpoint_anchor_api, "LocalEngine::checkpoint");
        assert_eq!(
            proof.checkpoint_verification_api,
            "LocalEngine::verify_checkpoint"
        );
        assert_eq!(
            proof.resume_api,
            "ReferenceProjectionMaterializer::resume_verified"
        );
        assert_eq!(proof.checkpoint.stream_id, proof.stream_id);
        assert_eq!(proof.checkpoint.head_offset, 1);
        assert_eq!(proof.checkpoint.kind, "materialize");
        assert!(proof.checkpoint.verified);
        assert!(proof.checkpoint.shared_model_verified);
        assert_eq!(proof.resume.appended_after_checkpoint, 3);
        assert_eq!(proof.resume.replay_from_offset, 2);
        assert_eq!(proof.resume.source_next_offset, 5);
        assert_eq!(proof.resume.pending_record_count, 3);
        assert_eq!(proof.resume.resumed_reference_count, 2);
        assert!(proof.resume.resumed_only_new_history);
        assert_eq!(
            proof.resume.resumed_view.get("ref-2"),
            Some(&ReferenceProjectionProofView {
                display_name: "beta".to_owned(),
                status: "active".to_owned(),
            })
        );
        assert_eq!(
            proof.resume.resumed_view.get("ref-3"),
            Some(&ReferenceProjectionProofView {
                display_name: "gamma".to_owned(),
                status: "active".to_owned(),
            })
        );
        assert!(!proof.resume.resumed_view.contains_key("ref-1"));
        assert_eq!(proof.rebuild.authoritative_record_count, 5);
        assert_eq!(proof.rebuild.rebuilt_reference_count, 2);
        assert_eq!(proof.rebuild.rebuilt_view, proof.resume.resumed_view);
        assert!(proof.equivalent_views);
        assert!(!proof.projection_only_authority_used);
        assert!(proof.verified);
        assert!(proof.error.is_none());
    }

    #[tokio::test]
    async fn reference_projection_proof_results_serialize_cleanly_for_mission_scripts() {
        let temp_dir = tempdir().expect("temp dir");
        let proof =
            run_reference_projection_proof(temp_dir.path().join("reference-projection-json"))
                .await
                .expect("run reference projection proof");
        let proof_json =
            serde_json::to_value(&proof).expect("serialize reference projection proof result");

        assert_eq!(
            proof_json
                .get("stream_id")
                .and_then(serde_json::Value::as_str),
            Some("mission.materialization.reference-projection.root")
        );
        assert_eq!(
            proof_json
                .get("checkpoint_api")
                .and_then(serde_json::Value::as_str),
            Some("ReferenceProjectionMaterializer::checkpoint")
        );
        assert_eq!(
            proof_json["checkpoint"]
                .get("shared_model_verified")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["resume"]
                .get("pending_record_count")
                .and_then(serde_json::Value::as_u64),
            Some(3)
        );
        assert_eq!(
            proof_json["resume"]["resumed_view"]["ref-2"]
                .get("status")
                .and_then(serde_json::Value::as_str),
            Some("active")
        );
        assert_eq!(
            proof_json["rebuild"]
                .get("authoritative_record_count")
                .and_then(serde_json::Value::as_u64),
            Some(5)
        );
        assert_eq!(
            proof_json
                .get("projection_only_authority_used")
                .and_then(serde_json::Value::as_bool),
            Some(false)
        );
        assert_eq!(
            proof_json
                .get("equivalent_views")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json
                .get("verified")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
    }

    #[tokio::test]
    async fn controlled_failover_proof_exercises_readiness_handoff_and_fencing() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_controlled_failover_proof(temp_dir.path().join("controlled-failover"))
            .await
            .expect("run controlled failover proof");

        assert_eq!(proof.stream_id, "mission.failover.root");
        assert_eq!(
            proof.readiness.source_replicated_ack.commitment,
            "replicated"
        );
        assert_eq!(proof.readiness.restore_next_offset, 3);
        assert_eq!(proof.readiness.required_frontier.next_offset, 3);
        assert_eq!(
            proof.readiness.candidate_posture.posture,
            "read_only_replica"
        );
        assert!(proof.readiness.frontier_caught_up);
        assert!(proof.readiness.ownership_ready);
        assert!(proof.readiness.promotable);
        assert!(proof.readiness.blockers.is_empty());
        assert_eq!(proof.handoff.previous_owner, "node-a");
        assert_eq!(proof.handoff.new_owner, "node-b");
        assert_eq!(proof.handoff.frontier_next_offset, 3);
        assert_eq!(proof.handoff.promoted_posture.posture, "lease_leader");
        assert_eq!(
            proof.handoff.promoted_append.position,
            "mission.failover.root@3"
        );
        assert_eq!(proof.handoff.promoted_append.durability, "local");
        assert_eq!(
            proof.fencing.former_primary_posture.posture,
            "lease_follower"
        );
        assert!(proof.fencing.former_primary_append_rejected);
        assert!(
            proof
                .fencing
                .rejection
                .as_deref()
                .is_some_and(|message| message.contains("not the leader"))
        );
        assert!(
            proof.contract.quorum.contains("no quorum acknowledgement"),
            "unexpected quorum contract: {}",
            proof.contract.quorum
        );
        assert!(
            proof
                .contract
                .multi_primary
                .contains("exactly one writable primary"),
            "unexpected multi-primary contract: {}",
            proof.contract.multi_primary
        );
        assert!(proof.verified);
        assert!(proof.error.is_none());
    }

    #[tokio::test]
    async fn controlled_failover_proof_results_serialize_cleanly_for_mission_scripts() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_controlled_failover_proof(temp_dir.path().join("controlled-failover-json"))
            .await
            .expect("run controlled failover proof");
        let proof_json = serde_json::to_value(&proof).expect("serialize proof");

        assert_eq!(
            proof_json
                .get("stream_id")
                .and_then(serde_json::Value::as_str),
            Some("mission.failover.root")
        );
        assert_eq!(
            proof_json["readiness"]["source_replicated_ack"]
                .get("commitment")
                .and_then(serde_json::Value::as_str),
            Some("replicated")
        );
        assert_eq!(
            proof_json["readiness"]
                .get("promotable")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["handoff"]["promoted_append"]
                .get("durability")
                .and_then(serde_json::Value::as_str),
            Some("local")
        );
        assert_eq!(
            proof_json["fencing"]
                .get("former_primary_append_rejected")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["contract"]
                .get("multi_primary")
                .and_then(serde_json::Value::as_str),
            Some(
                "the lease still permits exactly one writable primary and fences stale leaders instead of supporting concurrent writable nodes"
            )
        );
        assert_eq!(
            proof_json
                .get("verified")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
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

    #[test]
    fn hosted_authority_proof_exercises_remote_consumer_workflow() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_hosted_authority_proof(temp_dir.path().join("hosted-authority"))
            .expect("hosted authority proof");

        assert_eq!(proof.durability, "local");
        assert_eq!(proof.topology, "single_node");
        assert_eq!(proof.stream_id, "hosted.consumer.orders");
        assert_eq!(proof.root_stream.stream_id, "hosted.consumer.orders");
        assert_eq!(proof.producer_appends.len(), 2);
        assert_eq!(
            proof.producer_appends[0].position,
            "hosted.consumer.orders@0"
        );
        assert_eq!(
            proof.producer_appends[1].position,
            "hosted.consumer.orders@1"
        );
        assert_eq!(proof.reader_replay.record_count, 2);
        assert!(proof.replay_matches_acknowledged_history);
        assert!(!proof.remote_tier_publication_performed);
        assert!(!proof.embedded_authority_used);
        assert_eq!(proof.remote_api, "TransitClient");
    }

    #[test]
    fn hosted_authority_proof_results_serialize_cleanly_for_mission_scripts() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_hosted_authority_proof(temp_dir.path().join("hosted-authority-json"))
            .expect("hosted authority proof");
        let proof_json =
            serde_json::to_value(&proof).expect("serialize hosted authority proof result");

        assert_eq!(
            proof_json
                .get("durability")
                .and_then(serde_json::Value::as_str),
            Some("local")
        );
        assert_eq!(
            proof_json
                .get("remote_tier_publication_performed")
                .and_then(serde_json::Value::as_bool),
            Some(false)
        );
        assert_eq!(
            proof_json
                .get("embedded_authority_used")
                .and_then(serde_json::Value::as_bool),
            Some(false)
        );
        assert_eq!(
            proof_json
                .get("reader_replay")
                .and_then(|value| value.get("record_count"))
                .and_then(serde_json::Value::as_u64),
            Some(2)
        );
        assert!(
            proof_json
                .get("tiered_non_claim")
                .and_then(serde_json::Value::as_str)
                .expect("tiered non-claim string")
                .contains("remote tier")
        );
    }

    #[tokio::test]
    async fn warm_cache_recovery_proof_demonstrates_restart_from_authoritative_remote_tier() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_warm_cache_recovery_proof(temp_dir.path().join("warm-cache-recovery"))
            .await
            .expect("warm cache recovery proof");

        assert_eq!(proof.stream_id, "server.recovery.root");
        assert_eq!(proof.local_write_durability, "local");
        assert_eq!(proof.authoritative_recovery_durability, "tiered");
        assert_eq!(proof.published_frontier.next_offset, 4);
        assert!(proof.warm_cache_removed);
        assert!(proof.initial_hydrate.bootstrapped);
        assert!(proof.restart_hydrate.bootstrapped);
        assert_eq!(proof.initial_hydrate.replay.record_count, 4);
        assert_eq!(proof.restart_hydrate.replay.record_count, 4);
        assert!(proof.restored_history_matches);
        assert_eq!(
            proof.server_api,
            "transit_server::bind_read_only_replica_from_frontier"
        );
    }

    #[tokio::test]
    async fn warm_cache_recovery_proof_results_serialize_cleanly_for_mission_scripts() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_warm_cache_recovery_proof(temp_dir.path().join("warm-cache-recovery-json"))
            .await
            .expect("warm cache recovery proof");
        let proof_json =
            serde_json::to_value(&proof).expect("serialize warm cache recovery proof result");

        assert_eq!(
            proof_json
                .get("local_write_durability")
                .and_then(serde_json::Value::as_str),
            Some("local")
        );
        assert_eq!(
            proof_json
                .get("authoritative_recovery_durability")
                .and_then(serde_json::Value::as_str),
            Some("tiered")
        );
        assert_eq!(
            proof_json
                .get("warm_cache_removed")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json["restart_hydrate"]
                .get("bootstrapped")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
        assert_eq!(
            proof_json
                .get("restored_history_matches")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );
    }

    #[tokio::test]
    async fn tiered_engine_proof_exposes_published_frontier() {
        let temp_dir = tempdir().expect("temp dir");
        let proof = run_tiered_engine_proof(temp_dir.path().join("tiered"))
            .await
            .expect("run tiered proof");

        assert_eq!(proof.durability, "local");
        assert_eq!(proof.published_segments.len(), 3);
        assert_eq!(
            proof.published_frontier.manifest_generation,
            proof.publication_manifest_generation
        );
        assert_eq!(proof.published_frontier.start_offset, Some(0));
        assert_eq!(proof.published_frontier.last_offset, Some(4));
        assert_eq!(proof.published_frontier.next_offset, 5);
        assert_eq!(proof.published_frontier.segments.len(), 3);
        assert!(
            proof
                .published_frontier
                .manifest_object_key
                .contains("tiered-proof")
        );
        assert!(!proof.published_frontier.manifest_root.is_empty());
        assert_eq!(proof.replicated_ack.commitment, "replicated");
        assert_eq!(proof.replicated_ack.position, "tiered.root@4");
        assert_eq!(proof.replicated_ack.frontier_next_offset, 5);
        assert_eq!(proof.commitment_surface.local_head_offset, Some(5));
        assert_eq!(proof.commitment_surface.replicated_frontier_offset, Some(4));
        assert_eq!(proof.commitment_surface.tiered_restore_offset, Some(4));
        assert_eq!(proof.unpublished_local_records, 1);
    }
}
