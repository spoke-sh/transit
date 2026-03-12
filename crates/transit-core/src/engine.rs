use crate::kernel::{Offset, StreamDescriptor, StreamId, StreamPosition};
use crate::storage::{
    ManifestId, SegmentChecksum, SegmentDescriptor, SegmentId, SegmentManifest, StorageLocation,
};
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use std::fs::{self, File, OpenOptions};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};

const STREAMS_DIR: &str = "streams";
const SEGMENTS_DIR: &str = "segments";
const STATE_FILE: &str = "state.json";
const ACTIVE_SEGMENT_FILE: &str = "active.segment";
const MANIFEST_FILE: &str = "manifest.json";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DurabilityMode {
    Local,
}

impl DurabilityMode {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Local => "local",
        }
    }
}

#[derive(Debug, Clone)]
pub struct LocalEngineConfig {
    data_dir: PathBuf,
    segment_max_records: u64,
    durability: DurabilityMode,
}

impl LocalEngineConfig {
    pub fn new(data_dir: impl Into<PathBuf>) -> Self {
        Self {
            data_dir: data_dir.into(),
            segment_max_records: 1_024,
            durability: DurabilityMode::Local,
        }
    }

    pub fn with_segment_max_records(mut self, segment_max_records: u64) -> Result<Self> {
        ensure!(
            segment_max_records > 0,
            "segment_max_records must be greater than zero"
        );
        self.segment_max_records = segment_max_records;
        Ok(self)
    }

    pub fn data_dir(&self) -> &Path {
        &self.data_dir
    }

    pub fn segment_max_records(&self) -> u64 {
        self.segment_max_records
    }

    pub fn durability(&self) -> DurabilityMode {
        self.durability
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalAppendOutcome {
    position: StreamPosition,
    durability: DurabilityMode,
    manifest_generation: u64,
    rolled_segment: Option<SegmentDescriptor>,
}

impl LocalAppendOutcome {
    pub fn position(&self) -> &StreamPosition {
        &self.position
    }

    pub fn durability(&self) -> DurabilityMode {
        self.durability
    }

    pub fn manifest_generation(&self) -> u64 {
        self.manifest_generation
    }

    pub fn rolled_segment(&self) -> Option<&SegmentDescriptor> {
        self.rolled_segment.as_ref()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalStreamStatus {
    stream_id: StreamId,
    next_offset: Offset,
    active_record_count: u64,
    active_segment_start_offset: Offset,
    manifest_generation: u64,
    rolled_segment_count: usize,
}

impl LocalStreamStatus {
    pub fn stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    pub fn next_offset(&self) -> Offset {
        self.next_offset
    }

    pub fn active_record_count(&self) -> u64 {
        self.active_record_count
    }

    pub fn active_segment_start_offset(&self) -> Offset {
        self.active_segment_start_offset
    }

    pub fn manifest_generation(&self) -> u64 {
        self.manifest_generation
    }

    pub fn rolled_segment_count(&self) -> usize {
        self.rolled_segment_count
    }
}

#[derive(Debug, Clone)]
pub struct LocalEngine {
    config: LocalEngineConfig,
}

impl LocalEngine {
    pub fn open(config: LocalEngineConfig) -> Result<Self> {
        fs::create_dir_all(config.data_dir().join(STREAMS_DIR)).with_context(|| {
            format!(
                "create streams directory at {}",
                config.data_dir().display()
            )
        })?;

        Ok(Self { config })
    }

    pub fn create_stream(&self, descriptor: StreamDescriptor) -> Result<LocalStreamStatus> {
        let stream_dir = self.stream_dir(&descriptor.stream_id);
        ensure!(
            !stream_dir.exists(),
            "stream '{}' already exists",
            descriptor.stream_id.as_str()
        );

        fs::create_dir_all(stream_dir.join(SEGMENTS_DIR))
            .with_context(|| format!("create stream directory at {}", stream_dir.display()))?;

        let manifest = SegmentManifest::new(
            manifest_id(0)?,
            descriptor.stream_id.clone(),
            0,
            Vec::new(),
            local_storage(self.manifest_path(&descriptor.stream_id))?,
            None,
        );
        write_json_durable(&self.manifest_path(&descriptor.stream_id), &manifest)?;
        create_empty_file(&self.active_segment_path(&descriptor.stream_id))?;

        let state = LocalStreamState::new(descriptor);
        write_json_durable(&self.state_path(state.stream_id()), &state)?;

        self.stream_status(state.stream_id())
    }

    pub fn append(
        &self,
        stream_id: &StreamId,
        payload: impl AsRef<[u8]>,
    ) -> Result<LocalAppendOutcome> {
        let mut state = self.load_state(stream_id)?;
        let record = PersistedRecord {
            offset: state.next_offset,
            payload: payload.as_ref().to_vec(),
        };
        let encoded = serde_json::to_vec(&record).context("serialize persisted record")?;

        {
            let active_path = self.active_segment_path(stream_id);
            let mut file = OpenOptions::new()
                .create(true)
                .append(true)
                .open(&active_path)
                .with_context(|| format!("open active segment {}", active_path.display()))?;
            file.write_all(&encoded)
                .with_context(|| format!("write active segment {}", active_path.display()))?;
            file.write_all(b"\n")
                .with_context(|| format!("write newline to {}", active_path.display()))?;
            file.sync_all()
                .with_context(|| format!("sync active segment {}", active_path.display()))?;
        }

        let position = StreamPosition::new(stream_id.clone(), Offset::new(state.next_offset));
        state.next_offset += 1;
        state.active_record_count += 1;
        state.active_byte_length += (encoded.len() + 1) as u64;

        let rolled_segment = if state.active_record_count >= self.config.segment_max_records() {
            Some(self.roll_active_segment(&mut state)?)
        } else {
            write_json_durable(&self.state_path(stream_id), &state)?;
            None
        };

        Ok(LocalAppendOutcome {
            position,
            durability: self.config.durability(),
            manifest_generation: state.manifest_generation,
            rolled_segment,
        })
    }

    pub fn load_manifest(&self, stream_id: &StreamId) -> Result<SegmentManifest> {
        read_json(&self.manifest_path(stream_id))
    }

    pub fn stream_status(&self, stream_id: &StreamId) -> Result<LocalStreamStatus> {
        let state = self.load_state(stream_id)?;
        let manifest = self.load_manifest(stream_id)?;

        Ok(LocalStreamStatus {
            stream_id: stream_id.clone(),
            next_offset: Offset::new(state.next_offset),
            active_record_count: state.active_record_count,
            active_segment_start_offset: Offset::new(state.active_segment_start_offset),
            manifest_generation: state.manifest_generation,
            rolled_segment_count: manifest.segments().len(),
        })
    }

    fn roll_active_segment(&self, state: &mut LocalStreamState) -> Result<SegmentDescriptor> {
        ensure!(
            state.active_record_count > 0,
            "cannot roll an empty active segment"
        );

        let source = self.active_segment_path(state.stream_id());
        let segment_id = segment_id(state.active_segment_sequence)?;
        let target = self.segment_path(state.stream_id(), &segment_id);

        fs::rename(&source, &target).with_context(|| {
            format!(
                "rename active segment from {} to {}",
                source.display(),
                target.display()
            )
        })?;
        sync_dir(target.parent().expect("segment path has parent"))?;

        let bytes = fs::read(&target)
            .with_context(|| format!("read rolled segment {}", target.display()))?;
        let checksum = SegmentChecksum::new("fnv1a64", fnv1a64_hex(&bytes))?;
        let descriptor = SegmentDescriptor::new(
            segment_id,
            state.stream_id().clone(),
            Offset::new(state.active_segment_start_offset),
            Offset::new(state.next_offset - 1),
            state.active_record_count,
            state.active_byte_length,
            checksum,
            local_storage(target.clone())?,
        )?;

        let manifest = self.load_manifest(state.stream_id())?;
        let mut segments = manifest.segments().to_vec();
        segments.push(descriptor.clone());
        let next_generation = manifest.generation() + 1;
        let persisted_manifest = SegmentManifest::new(
            manifest_id(next_generation)?,
            state.stream_id().clone(),
            next_generation,
            segments,
            local_storage(self.manifest_path(state.stream_id()))?,
            None,
        );
        write_json_durable(&self.manifest_path(state.stream_id()), &persisted_manifest)?;

        create_empty_file(&source)?;

        state.active_segment_sequence += 1;
        state.active_segment_start_offset = state.next_offset;
        state.active_record_count = 0;
        state.active_byte_length = 0;
        state.manifest_generation = next_generation;
        write_json_durable(&self.state_path(state.stream_id()), state)?;

        Ok(descriptor)
    }

    fn load_state(&self, stream_id: &StreamId) -> Result<LocalStreamState> {
        read_json(&self.state_path(stream_id))
    }

    fn stream_dir(&self, stream_id: &StreamId) -> PathBuf {
        self.config
            .data_dir()
            .join(STREAMS_DIR)
            .join(sanitize_stream_id(stream_id))
    }

    fn state_path(&self, stream_id: &StreamId) -> PathBuf {
        self.stream_dir(stream_id).join(STATE_FILE)
    }

    fn manifest_path(&self, stream_id: &StreamId) -> PathBuf {
        self.stream_dir(stream_id).join(MANIFEST_FILE)
    }

    fn active_segment_path(&self, stream_id: &StreamId) -> PathBuf {
        self.stream_dir(stream_id).join(ACTIVE_SEGMENT_FILE)
    }

    fn segment_path(&self, stream_id: &StreamId, segment_id: &SegmentId) -> PathBuf {
        self.stream_dir(stream_id)
            .join(SEGMENTS_DIR)
            .join(format!("{}.segment", segment_id.as_str()))
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct LocalStreamState {
    descriptor: StreamDescriptor,
    next_offset: u64,
    active_segment_sequence: u64,
    active_segment_start_offset: u64,
    active_record_count: u64,
    active_byte_length: u64,
    manifest_generation: u64,
}

impl LocalStreamState {
    fn new(descriptor: StreamDescriptor) -> Self {
        Self {
            descriptor,
            next_offset: 0,
            active_segment_sequence: 0,
            active_segment_start_offset: 0,
            active_record_count: 0,
            active_byte_length: 0,
            manifest_generation: 0,
        }
    }

    fn stream_id(&self) -> &StreamId {
        &self.descriptor.stream_id
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct PersistedRecord {
    offset: u64,
    payload: Vec<u8>,
}

fn local_storage(path: impl Into<PathBuf>) -> Result<StorageLocation> {
    StorageLocation::new(Some(path.into()), None)
}

fn segment_id(sequence: u64) -> Result<SegmentId> {
    SegmentId::new(format!("segment-{sequence:020}"))
}

fn manifest_id(generation: u64) -> Result<ManifestId> {
    ManifestId::new(format!("manifest-{generation:020}"))
}

fn sanitize_stream_id(stream_id: &StreamId) -> String {
    stream_id
        .as_str()
        .chars()
        .map(|character| match character {
            'a'..='z' | 'A'..='Z' | '0'..='9' | '.' | '-' | '_' => character,
            _ => '_',
        })
        .collect()
}

fn read_json<T>(path: &Path) -> Result<T>
where
    T: for<'de> Deserialize<'de>,
{
    let bytes = fs::read(path).with_context(|| format!("read {}", path.display()))?;
    serde_json::from_slice(&bytes).with_context(|| format!("parse {}", path.display()))
}

fn write_json_durable<T>(path: &Path, value: &T) -> Result<()>
where
    T: Serialize,
{
    let parent = path
        .parent()
        .with_context(|| format!("{} has no parent directory", path.display()))?;
    fs::create_dir_all(parent)
        .with_context(|| format!("create parent directory {}", parent.display()))?;

    let temp_path = path.with_extension("tmp");
    {
        let file = File::create(&temp_path)
            .with_context(|| format!("create temporary file {}", temp_path.display()))?;
        let mut writer = BufWriter::new(file);
        serde_json::to_writer_pretty(&mut writer, value)
            .with_context(|| format!("serialize {}", path.display()))?;
        writer.write_all(b"\n")?;
        writer.flush()?;
        writer
            .into_inner()
            .context("extract file handle from buffered writer")?
            .sync_all()
            .with_context(|| format!("sync {}", temp_path.display()))?;
    }

    fs::rename(&temp_path, path).with_context(|| {
        format!(
            "rename temporary file from {} to {}",
            temp_path.display(),
            path.display()
        )
    })?;
    sync_dir(parent)?;
    Ok(())
}

fn create_empty_file(path: &Path) -> Result<()> {
    let parent = path
        .parent()
        .with_context(|| format!("{} has no parent directory", path.display()))?;
    fs::create_dir_all(parent)
        .with_context(|| format!("create parent directory {}", parent.display()))?;

    let file = OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(path)
        .with_context(|| format!("create {}", path.display()))?;
    file.sync_all()
        .with_context(|| format!("sync {}", path.display()))?;
    sync_dir(parent)?;
    Ok(())
}

fn sync_dir(path: &Path) -> Result<()> {
    let directory =
        File::open(path).with_context(|| format!("open directory {}", path.display()))?;
    directory
        .sync_all()
        .with_context(|| format!("sync directory {}", path.display()))
}

fn fnv1a64_hex(bytes: &[u8]) -> String {
    let mut hash = 0xcbf29ce484222325_u64;
    for byte in bytes {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x100000001b3);
    }
    format!("{hash:016x}")
}

#[cfg(test)]
mod tests {
    use super::{DurabilityMode, LocalEngine, LocalEngineConfig};
    use crate::kernel::{LineageMetadata, Offset, StreamDescriptor, StreamId};
    use std::fs;
    use tempfile::tempdir;

    fn stream_id(value: &str) -> StreamId {
        StreamId::new(value).expect("stream id")
    }

    fn root_descriptor(value: &str) -> StreamDescriptor {
        StreamDescriptor::root(
            stream_id(value),
            LineageMetadata::new(Some("test".into()), Some("unit-test".into())),
        )
    }

    #[test]
    fn append_returns_explicit_stream_positions_for_local_commits() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(10)
                .expect("config"),
        )
        .expect("engine");
        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create stream");

        let first = engine
            .append(&stream_id("task.root"), b"first")
            .expect("first append");
        let second = engine
            .append(&stream_id("task.root"), b"second")
            .expect("second append");

        assert_eq!(first.position().offset.value(), 0);
        assert_eq!(second.position().offset.value(), 1);
        assert_eq!(first.position().stream_id.as_str(), "task.root");
        assert_eq!(first.durability(), DurabilityMode::Local);
        assert!(first.rolled_segment().is_none());
        assert_eq!(second.manifest_generation(), 0);

        let status = engine
            .stream_status(&stream_id("task.root"))
            .expect("status");
        assert_eq!(status.next_offset().value(), 2);
        assert_eq!(status.active_record_count(), 2);
        assert_eq!(status.rolled_segment_count(), 0);
        assert_eq!(status.active_segment_start_offset(), Offset::new(0));
    }

    #[test]
    fn append_rolls_segments_and_persists_manifest_state() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(2)
                .expect("config"),
        )
        .expect("engine");
        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create stream");

        engine
            .append(&stream_id("task.root"), b"first")
            .expect("first append");
        let second = engine
            .append(&stream_id("task.root"), b"second")
            .expect("second append");

        let rolled = second.rolled_segment().expect("rolled segment");
        assert_eq!(rolled.start_offset().value(), 0);
        assert_eq!(rolled.last_offset().value(), 1);
        assert_eq!(rolled.record_count(), 2);
        assert_eq!(rolled.checksum().algorithm(), "fnv1a64");
        assert!(
            rolled
                .storage()
                .local_path()
                .expect("local segment path")
                .exists()
        );

        let manifest = engine
            .load_manifest(&stream_id("task.root"))
            .expect("manifest");
        assert_eq!(manifest.generation(), 1);
        assert_eq!(manifest.segments().len(), 1);
        assert_eq!(manifest.segments()[0], rolled.clone());

        let status = engine
            .stream_status(&stream_id("task.root"))
            .expect("status");
        assert_eq!(status.manifest_generation(), 1);
        assert_eq!(status.active_record_count(), 0);
        assert_eq!(status.active_segment_start_offset(), Offset::new(2));
        assert_eq!(status.rolled_segment_count(), 1);
    }

    #[test]
    fn committed_state_is_persisted_under_explicit_local_durability_boundaries() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(1)
                .expect("config"),
        )
        .expect("engine");
        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create stream");

        let outcome = engine
            .append(&stream_id("task.root"), b"committed")
            .expect("append");
        assert_eq!(outcome.durability().as_str(), "local");
        assert!(outcome.rolled_segment().is_some());

        let state_path = temp_dir
            .path()
            .join("streams")
            .join("task.root")
            .join("state.json");
        let manifest_path = temp_dir
            .path()
            .join("streams")
            .join("task.root")
            .join("manifest.json");
        let active_path = temp_dir
            .path()
            .join("streams")
            .join("task.root")
            .join("active.segment");

        assert!(state_path.exists());
        assert!(manifest_path.exists());
        assert!(active_path.exists());
        assert_eq!(
            fs::metadata(
                outcome
                    .rolled_segment()
                    .expect("rolled")
                    .storage()
                    .local_path()
                    .expect("segment")
            )
            .expect("segment metadata")
            .len(),
            outcome.rolled_segment().expect("rolled").byte_length()
        );
    }
}
