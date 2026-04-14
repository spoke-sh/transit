use std::collections::BTreeMap;
use std::process::ExitCode;

use anyhow::{Context, Result, bail, ensure};
use serde::{Deserialize, Serialize};
use tempfile::tempdir;
use transit_client::{
    LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset, ProjectionReadConsumer,
    ProjectionReadRequest, RemoteTailSessionState, StreamId, StreamLineage, StreamPosition,
    TransitClient,
};
use transit_core::engine::LocalEngineConfig;
use transit_core::server::{ServerConfig, ServerHandle};

#[derive(Debug, Clone, PartialEq, Eq)]
struct ProjectionView {
    display_name: String,
    status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ProjectionEvent {
    reference_id: String,
    display_name: String,
    status: String,
    deleted: bool,
}

struct ReferenceProjectionConsumer;

impl ProjectionReadConsumer for ReferenceProjectionConsumer {
    type View = BTreeMap<String, ProjectionView>;

    fn initial_view(&self) -> Self::View {
        BTreeMap::new()
    }

    fn reduce_view(
        &self,
        view: &mut Self::View,
        _position: &StreamPosition,
        payload: &[u8],
    ) -> Result<()> {
        let event: ProjectionEvent =
            serde_json::from_slice(payload).context("deserialize proof projection event")?;
        if event.deleted {
            view.remove(&event.reference_id);
        } else {
            view.insert(
                event.reference_id,
                ProjectionView {
                    display_name: event.display_name,
                    status: event.status,
                },
            );
        }
        Ok(())
    }
}

fn projection_event(
    reference_id: &str,
    display_name: &str,
    status: &str,
    deleted: bool,
) -> Result<Vec<u8>> {
    serde_json::to_vec(&ProjectionEvent {
        reference_id: reference_id.to_owned(),
        display_name: display_name.to_owned(),
        status: status.to_owned(),
        deleted,
    })
    .context("serialize proof projection event")
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rust client proof failed: {error:#}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<()> {
    let temp_dir = tempdir().context("create rust client proof tempdir")?;
    let server = ServerHandle::bind(ServerConfig::new(
        LocalEngineConfig::new(
            temp_dir.path(),
            transit_core::membership::NodeId::new("proof-node"),
        )
        .with_segment_max_records(8)
        .context("configure proof server")?,
        "127.0.0.1:0".parse().expect("static listen addr parses"),
    ))
    .context("bind rust client proof server")?;

    let proof = run_proof(temp_dir.path(), &server);
    let shutdown = server
        .shutdown()
        .context("shutdown rust client proof server");
    proof.and(shutdown.map(|_| ()))
}

fn run_proof(root: &std::path::Path, server: &ServerHandle) -> Result<()> {
    let client = TransitClient::new(server.local_addr());
    let root_stream = StreamId::new("proof.client.root")?;
    let branch_stream = StreamId::new("proof.client.branch")?;
    let merge_stream = StreamId::new("proof.client.merge")?;
    let projection_stream = StreamId::new("proof.client.projection")?;

    println!("transit rust-client proof");
    println!("root: {}", root.display());
    println!("server: {}", server.local_addr());

    step("create_root", || {
        let root = client
            .create_root(
                &root_stream,
                LineageMetadata::new(Some("proof".into()), Some("rust-client".into())),
            )
            .context("create root stream through rust client")?;
        ensure!(
            root.body().stream_id() == &root_stream,
            "unexpected root stream id"
        );
        Ok((
            (),
            format!(
                "{} next {}",
                root.body().stream_id().as_str(),
                root.body().next_offset().value()
            ),
        ))
    })?;

    step("append", || {
        let append = client
            .append(&root_stream, b"seed")
            .context("append initial root record through rust client")?;
        ensure!(
            append.body().position().stream_id == root_stream,
            "unexpected append stream id"
        );
        Ok((
            (),
            format!(
                "{}@{}",
                append.body().position().stream_id.as_str(),
                append.body().position().offset.value()
            ),
        ))
    })?;

    let opened = step("tail_open", || {
        let opened = client
            .tail_open(&root_stream, Offset::new(0), 1)
            .context("open tail session through rust client")?;
        ensure!(
            opened.body().records().len() == 1,
            "tail_open should deliver the first record immediately"
        );
        ensure!(
            opened.body().state() == RemoteTailSessionState::Active,
            "tail_open should return an active session"
        );
        let detail = format!(
            "{} delivered {}",
            opened.body().session_id().as_str(),
            opened.body().records().len()
        );
        Ok((opened, detail))
    })?;
    let session_id = opened.body().session_id().clone();

    step("append_tail_target", || {
        let append = client
            .append(&root_stream, b"second")
            .context("append second root record through rust client")?;
        ensure!(
            append.body().position().offset.value() == 1,
            "expected second root append at offset 1"
        );
        Ok((
            (),
            format!(
                "{}@{}",
                append.body().position().stream_id.as_str(),
                append.body().position().offset.value()
            ),
        ))
    })?;

    step("tail_grant_credit", || {
        let batch = client
            .grant_credit(&session_id, 1)
            .context("grant tail credit through rust client")?;
        ensure!(
            batch.body().records().len() == 1,
            "grant_credit should deliver the newly appended record"
        );
        Ok((
            (),
            format!(
                "{} delivered {}",
                batch.body().session_id().as_str(),
                batch.body().delivered_credit()
            ),
        ))
    })?;

    step("tail_poll", || {
        let batch = client
            .poll(&session_id, 1)
            .context("poll tail session through rust client")?;
        ensure!(
            batch.body().records().is_empty(),
            "poll should report no new records after credit is exhausted"
        );
        ensure!(
            batch.body().state() == RemoteTailSessionState::AwaitingRecords,
            "poll should surface awaiting-records state"
        );
        Ok((
            (),
            format!(
                "{} {:?}",
                batch.body().session_id().as_str(),
                batch.body().state()
            ),
        ))
    })?;

    step("tail_cancel", || {
        let cancelled = client
            .cancel(&session_id)
            .context("cancel tail session through rust client")?;
        ensure!(
            cancelled.body().state() == RemoteTailSessionState::Cancelled,
            "tail_cancel should close the session"
        );
        Ok(((), cancelled.body().session_id().as_str().to_owned()))
    })?;

    step("read", || {
        let read = client
            .read(&root_stream)
            .context("read root stream through rust client")?;
        let payloads: Vec<&[u8]> = read
            .body()
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();
        ensure!(
            payloads == vec![b"seed".as_slice(), b"second".as_slice()],
            "read should return the two root records in order"
        );
        Ok(((), format!("{} records", read.body().records().len())))
    })?;

    step("create_branch", || {
        let branch = client
            .create_branch(
                &branch_stream,
                StreamPosition::new(root_stream.clone(), Offset::new(1)),
                LineageMetadata::new(Some("proof".into()), Some("branch".into())),
            )
            .context("create branch through rust client")?;
        ensure!(
            branch.body().next_offset().value() == 2,
            "branch should inherit the first two root offsets"
        );
        Ok((
            (),
            format!(
                "{} next {}",
                branch.body().stream_id().as_str(),
                branch.body().next_offset().value()
            ),
        ))
    })?;

    step("append_branch", || {
        let append = client
            .append(&branch_stream, b"branch-only")
            .context("append branch record through rust client")?;
        ensure!(
            append.body().position().offset.value() == 2,
            "branch append should advance to offset 2"
        );
        Ok((
            (),
            format!(
                "{}@{}",
                append.body().position().stream_id.as_str(),
                append.body().position().offset.value()
            ),
        ))
    })?;

    step("lineage_branch", || {
        let lineage = client
            .lineage(&branch_stream)
            .context("inspect branch lineage through rust client")?;
        match &lineage.body().descriptor().lineage {
            StreamLineage::Branch { branch_point } => {
                ensure!(
                    branch_point.parent.stream_id == root_stream,
                    "branch lineage should point back to the root stream"
                );
                ensure!(
                    branch_point.parent.offset.value() == 1,
                    "branch lineage should preserve the parent offset"
                );
            }
            other => bail!("expected branch lineage, got {other:?}"),
        }
        Ok(((), branch_stream.as_str().to_owned()))
    })?;

    let merge_spec = MergeSpec::new(
        vec![
            StreamPosition::new(root_stream.clone(), Offset::new(1)),
            StreamPosition::new(branch_stream.clone(), Offset::new(2)),
        ],
        Some(StreamPosition::new(root_stream.clone(), Offset::new(1))),
        MergePolicy::new(MergePolicyKind::Recursive).with_metadata("resolver", "proof"),
        LineageMetadata::new(Some("proof".into()), Some("merge".into())),
    )
    .context("build merge spec for rust client proof")?;

    step("create_merge", || {
        let merge = client
            .create_merge(&merge_stream, merge_spec.clone())
            .context("create merge through rust client")?;
        ensure!(
            merge.body().next_offset().value() == 2,
            "merge stream should start at merge-base + 1"
        );
        Ok((
            (),
            format!(
                "{} next {}",
                merge.body().stream_id().as_str(),
                merge.body().next_offset().value()
            ),
        ))
    })?;

    step("lineage_merge", || {
        let lineage = client
            .lineage(&merge_stream)
            .context("inspect merge lineage through rust client")?;
        match &lineage.body().descriptor().lineage {
            StreamLineage::Merge { merge } => ensure!(
                merge == &merge_spec,
                "merge lineage should preserve the exact merge spec"
            ),
            other => bail!("expected merge lineage, got {other:?}"),
        }
        Ok(((), merge_stream.as_str().to_owned()))
    })?;

    step("create_projection_stream", || {
        let projection = client
            .create_root(
                &projection_stream,
                LineageMetadata::new(Some("proof".into()), Some("projection-consumer".into())),
            )
            .context("create projection stream through rust client")?;
        ensure!(
            projection.body().stream_id() == &projection_stream,
            "unexpected projection stream id"
        );
        Ok((
            (),
            format!(
                "{} next {}",
                projection.body().stream_id().as_str(),
                projection.body().next_offset().value()
            ),
        ))
    })?;

    step("append_projection_events", || {
        client
            .append(
                &projection_stream,
                projection_event("ref-1", "Alpha", "active", false)?,
            )
            .context("append first projection event")?;
        client
            .append(
                &projection_stream,
                projection_event("ref-2", "Beta", "pending", false)?,
            )
            .context("append second projection event")?;
        client
            .append(
                &projection_stream,
                projection_event("ref-1", "Alpha", "active", true)?,
            )
            .context("append delete projection event")?;
        Ok(((), projection_stream.as_str().to_owned()))
    })?;

    let projection_revision = step("read_projection", || {
        let projection = client
            .read_projection(
                ProjectionReadRequest::new(projection_stream.clone()),
                ReferenceProjectionConsumer,
            )
            .context("read projection through rust client")?;
        ensure!(
            projection.ack().durability() == "local",
            "projection read should preserve hosted acknowledgement durability"
        );
        ensure!(
            projection.ack().topology() == transit_core::server::RemoteTopology::SingleNode,
            "projection read should preserve hosted topology"
        );
        ensure!(
            projection.body().view().len() == 1,
            "projection read should reduce deleted references out of the view"
        );
        ensure!(
            projection.body().view().contains_key("ref-2"),
            "projection read should preserve surviving references"
        );
        let revision = projection
            .body()
            .projection_revision()
            .context("projection read should surface a revision")?
            .to_owned();
        Ok((
            revision.clone(),
            format!("{} {} refs", revision, projection.body().view().len()),
        ))
    })?;

    step("read_projection_checkpoint_match", || {
        let projection = client
            .read_projection(
                ProjectionReadRequest::new(projection_stream.clone())
                    .with_checkpoint_id(&projection_revision),
                ReferenceProjectionConsumer,
            )
            .context("read projection with checkpoint through rust client")?;
        ensure!(
            projection.body().checkpoint_matches(),
            "projection read should report checkpoint matches when revision is reused"
        );
        Ok(((), projection_revision))
    })?;

    println!("status: VERIFIED");
    Ok(())
}

fn step<T>(name: &str, operation: impl FnOnce() -> Result<(T, String)>) -> Result<T> {
    match operation() {
        Ok((value, detail)) => {
            println!("PASS {name}: {detail}");
            Ok(value)
        }
        Err(error) => {
            eprintln!("FAIL {name}: {error:#}");
            Err(error)
        }
    }
}
