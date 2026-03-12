use anyhow::Result;
use clap::{Args, Parser, Subcommand};
use std::path::PathBuf;
use transit_core::bootstrap::{MissionStatus, collect_mission_status};
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
        println!("kernel slice: lineage kernel + storage scaffold");
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
