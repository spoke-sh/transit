use crate::kernel::{
    LineageMetadata, MergeSpec, Offset, StreamDescriptor, StreamId, StreamLineage, StreamPosition,
};
use crate::storage::{
    ManifestId, SegmentChecksum, SegmentDescriptor, SegmentId, SegmentManifest, StorageLocation,
};
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use std::fs::{self, File, OpenOptions};
use std::io::{BufRead, BufReader, BufWriter, Write};
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
pub struct LocalRecord {
    position: StreamPosition,
    payload: Vec<u8>,
}

impl LocalRecord {
    fn from_persisted(stream_id: StreamId, record: PersistedRecord) -> Self {
        Self {
            position: StreamPosition::new(stream_id, Offset::new(record.offset)),
            payload: record.payload,
        }
    }

    pub fn position(&self) -> &StreamPosition {
        &self.position
    }

    pub fn payload(&self) -> &[u8] {
        &self.payload
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
        let state = self.initialize_stream_state(descriptor)?;
        let stream_dir = self.stream_dir(state.stream_id());
        ensure!(
            !stream_dir.exists(),
            "stream '{}' already exists",
            state.stream_id().as_str()
        );

        fs::create_dir_all(stream_dir.join(SEGMENTS_DIR))
            .with_context(|| format!("create stream directory at {}", stream_dir.display()))?;

        let manifest = SegmentManifest::new(
            manifest_id(0)?,
            state.stream_id().clone(),
            0,
            Vec::new(),
            local_storage(self.manifest_path(state.stream_id()))?,
            None,
        );
        write_json_durable(&self.manifest_path(state.stream_id()), &manifest)?;
        create_empty_file(&self.active_segment_path(state.stream_id()))?;

        write_json_durable(&self.state_path(state.stream_id()), &state)?;

        self.stream_status(state.stream_id())
    }

    pub fn create_branch(
        &self,
        stream_id: StreamId,
        parent: StreamPosition,
        metadata: LineageMetadata,
    ) -> Result<LocalStreamStatus> {
        self.create_stream(StreamDescriptor::branch(stream_id, parent, metadata)?)
    }

    pub fn create_merge(&self, stream_id: StreamId, merge: MergeSpec) -> Result<LocalStreamStatus> {
        self.create_stream(StreamDescriptor::merge(stream_id, merge)?)
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

    pub fn stream_descriptor(&self, stream_id: &StreamId) -> Result<StreamDescriptor> {
        Ok(self.load_state(stream_id)?.descriptor)
    }

    pub fn replay(&self, stream_id: &StreamId) -> Result<Vec<LocalRecord>> {
        self.read_replay_records(stream_id)
    }

    pub fn tail_from(&self, stream_id: &StreamId, from: Offset) -> Result<Vec<LocalRecord>> {
        Ok(self
            .read_replay_records(stream_id)?
            .into_iter()
            .filter(|record| record.position.offset.value() >= from.value())
            .collect())
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

    fn initialize_stream_state(&self, descriptor: StreamDescriptor) -> Result<LocalStreamState> {
        let initial_next_offset = match &descriptor.lineage {
            StreamLineage::Root { .. } => 0,
            StreamLineage::Branch { branch_point } => {
                self.validate_lineage_position(&descriptor.stream_id, &branch_point.parent)?;
                branch_point.parent.offset.value() + 1
            }
            StreamLineage::Merge { merge } => {
                for parent in &merge.parents {
                    self.validate_lineage_position(&descriptor.stream_id, parent)?;
                }

                if let Some(merge_base) = &merge.merge_base {
                    self.validate_lineage_position(&descriptor.stream_id, merge_base)?;
                    merge_base.offset.value() + 1
                } else {
                    0
                }
            }
        };

        Ok(LocalStreamState::new(descriptor, initial_next_offset))
    }

    fn validate_lineage_position(
        &self,
        stream_id: &StreamId,
        position: &StreamPosition,
    ) -> Result<()> {
        ensure!(
            stream_id != &position.stream_id,
            "lineage positions must reference an existing distinct stream"
        );

        let parent_status = self.stream_status(&position.stream_id)?;
        ensure!(
            position.offset.value() < parent_status.next_offset().value(),
            "lineage position {}:{} is beyond committed head {}",
            position.stream_id.as_str(),
            position.offset.value(),
            parent_status.next_offset().value()
        );
        Ok(())
    }

    fn read_replay_records(&self, stream_id: &StreamId) -> Result<Vec<LocalRecord>> {
        let state = self.load_state(stream_id)?;
        let mut records = self.read_inherited_records(&state.descriptor)?;
        let mut expected_next_offset = records
            .last()
            .map(|record| record.position.offset.value() + 1)
            .unwrap_or(0);

        let manifest = self.load_manifest(stream_id)?;
        for descriptor in manifest.segments() {
            let segment_records =
                self.read_committed_segment(stream_id, descriptor, expected_next_offset)?;
            expected_next_offset = descriptor.last_offset().value() + 1;
            records.extend(segment_records);
        }

        let active_records = self.read_active_head(stream_id, &state, expected_next_offset)?;
        records.extend(active_records);
        Ok(records)
    }

    fn read_inherited_records(&self, descriptor: &StreamDescriptor) -> Result<Vec<LocalRecord>> {
        match &descriptor.lineage {
            StreamLineage::Root { .. } => Ok(Vec::new()),
            StreamLineage::Branch { branch_point } => self.read_prefix(&branch_point.parent),
            StreamLineage::Merge { merge } => match &merge.merge_base {
                Some(merge_base) => self.read_prefix(merge_base),
                None => Ok(Vec::new()),
            },
        }
    }

    fn read_prefix(&self, position: &StreamPosition) -> Result<Vec<LocalRecord>> {
        let mut records = self.read_replay_records(&position.stream_id)?;
        ensure!(
            position.offset.value() < records.len() as u64,
            "lineage position {}:{} is beyond replayable history {}",
            position.stream_id.as_str(),
            position.offset.value(),
            records.len()
        );
        records.truncate(position.offset.value() as usize + 1);
        Ok(records)
    }

    fn read_committed_segment(
        &self,
        stream_id: &StreamId,
        descriptor: &SegmentDescriptor,
        expected_start_offset: u64,
    ) -> Result<Vec<LocalRecord>> {
        ensure!(
            descriptor.stream_id() == stream_id,
            "segment '{}' belongs to '{}' not '{}'",
            descriptor.segment_id().as_str(),
            descriptor.stream_id().as_str(),
            stream_id.as_str()
        );
        ensure!(
            descriptor.start_offset().value() == expected_start_offset,
            "segment '{}' starts at {} but replay expected {}",
            descriptor.segment_id().as_str(),
            descriptor.start_offset().value(),
            expected_start_offset
        );

        let segment_path = descriptor
            .storage()
            .local_path()
            .cloned()
            .context("local replay requires a local segment path")?;
        let persisted = read_records(&segment_path)?;
        ensure!(
            persisted.len() as u64 == descriptor.record_count(),
            "segment '{}' expected {} records but found {}",
            descriptor.segment_id().as_str(),
            descriptor.record_count(),
            persisted.len()
        );
        ensure!(
            fs::metadata(&segment_path)
                .with_context(|| format!("read metadata for {}", segment_path.display()))?
                .len()
                == descriptor.byte_length(),
            "segment '{}' expected {} bytes on disk",
            descriptor.segment_id().as_str(),
            descriptor.byte_length()
        );

        validate_record_offsets(
            &persisted,
            descriptor.start_offset().value(),
            descriptor.last_offset().value() + 1,
            &format!("segment '{}'", descriptor.segment_id().as_str()),
        )?;

        Ok(persisted
            .into_iter()
            .map(|record| LocalRecord::from_persisted(stream_id.clone(), record))
            .collect())
    }

    fn read_active_head(
        &self,
        stream_id: &StreamId,
        state: &LocalStreamState,
        expected_start_offset: u64,
    ) -> Result<Vec<LocalRecord>> {
        ensure!(
            state.active_segment_start_offset == expected_start_offset,
            "active head for '{}' starts at {} but replay expected {}",
            stream_id.as_str(),
            state.active_segment_start_offset,
            expected_start_offset
        );

        let active_path = self.active_segment_path(stream_id);
        let persisted = read_records(&active_path)?;
        ensure!(
            persisted.len() as u64 == state.active_record_count,
            "active head for '{}' expected {} records but found {}",
            stream_id.as_str(),
            state.active_record_count,
            persisted.len()
        );

        validate_record_offsets(
            &persisted,
            state.active_segment_start_offset,
            state.next_offset,
            &format!("active head for '{}'", stream_id.as_str()),
        )?;

        Ok(persisted
            .into_iter()
            .map(|record| LocalRecord::from_persisted(stream_id.clone(), record))
            .collect())
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
    fn new(descriptor: StreamDescriptor, next_offset: u64) -> Self {
        Self {
            descriptor,
            next_offset,
            active_segment_sequence: 0,
            active_segment_start_offset: next_offset,
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

fn read_records(path: &Path) -> Result<Vec<PersistedRecord>> {
    let file = File::open(path).with_context(|| format!("open {}", path.display()))?;
    let reader = BufReader::new(file);
    let mut records = Vec::new();

    for (line_number, line) in reader.lines().enumerate() {
        let line =
            line.with_context(|| format!("read line {} from {}", line_number + 1, path.display()))?;
        if line.trim().is_empty() {
            continue;
        }

        let record = serde_json::from_str::<PersistedRecord>(&line)
            .with_context(|| format!("parse line {} from {}", line_number + 1, path.display()))?;
        records.push(record);
    }

    Ok(records)
}

fn validate_record_offsets(
    records: &[PersistedRecord],
    expected_start_offset: u64,
    expected_next_offset: u64,
    scope: &str,
) -> Result<()> {
    if records.is_empty() {
        ensure!(
            expected_start_offset == expected_next_offset,
            "{scope} is empty but expected offsets {}..{}",
            expected_start_offset,
            expected_next_offset
        );
        return Ok(());
    }

    let mut next_offset = expected_start_offset;
    for record in records {
        ensure!(
            record.offset == next_offset,
            "{scope} expected offset {} but found {}",
            next_offset,
            record.offset
        );
        next_offset += 1;
    }

    ensure!(
        next_offset == expected_next_offset,
        "{scope} ended at {} but expected {}",
        next_offset,
        expected_next_offset
    );
    Ok(())
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
    use crate::kernel::{
        LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset, StreamDescriptor,
        StreamId, StreamLineage, StreamPosition,
    };
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

    #[test]
    fn replay_reads_committed_records_in_manifest_order() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(2)
                .expect("config"),
        )
        .expect("engine");
        let stream_id = stream_id("task.root");
        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create stream");

        for payload in ["first", "second", "third", "fourth", "fifth"] {
            engine
                .append(&stream_id, payload.as_bytes())
                .expect("append");
        }

        let replayed = engine.replay(&stream_id).expect("replay");
        let offsets: Vec<u64> = replayed
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let payloads: Vec<&[u8]> = replayed.iter().map(|record| record.payload()).collect();

        assert_eq!(offsets, vec![0, 1, 2, 3, 4]);
        assert_eq!(
            payloads,
            vec![
                b"first".as_slice(),
                b"second".as_slice(),
                b"third".as_slice(),
                b"fourth".as_slice(),
                b"fifth".as_slice()
            ]
        );
    }

    #[test]
    fn tail_from_reads_across_rolled_segments_and_active_head() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(2)
                .expect("config"),
        )
        .expect("engine");
        let stream_id = stream_id("task.root");
        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create stream");

        for payload in ["first", "second", "third", "fourth", "fifth"] {
            engine
                .append(&stream_id, payload.as_bytes())
                .expect("append");
        }

        let tailed = engine.tail_from(&stream_id, Offset::new(3)).expect("tail");
        let offsets: Vec<u64> = tailed
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let payloads: Vec<&[u8]> = tailed.iter().map(|record| record.payload()).collect();

        assert_eq!(offsets, vec![3, 4]);
        assert_eq!(payloads, vec![b"fourth".as_slice(), b"fifth".as_slice()]);
        assert!(
            engine
                .tail_from(&stream_id, Offset::new(5))
                .expect("empty")
                .is_empty()
        );
    }

    #[test]
    fn replay_stays_local_first_without_remote_hydration() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(1)
                .expect("config"),
        )
        .expect("engine");
        let stream_id = stream_id("task.root");
        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create stream");

        engine.append(&stream_id, b"first").expect("append");
        engine.append(&stream_id, b"second").expect("append");

        let manifest = engine.load_manifest(&stream_id).expect("manifest");
        assert!(
            manifest
                .segments()
                .iter()
                .all(|segment| segment.storage().object_store().is_none())
        );

        let replayed = engine.replay(&stream_id).expect("replay");
        assert_eq!(replayed.len(), 2);
        assert_eq!(replayed[0].position().offset.value(), 0);
        assert_eq!(replayed[1].position().offset.value(), 1);
    }

    #[test]
    fn branch_creation_reuses_parent_history_without_copying_segments() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(2)
                .expect("config"),
        )
        .expect("engine");
        let root_stream = stream_id("task.root");
        let branch_stream = stream_id("task.root.retry");
        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create root");

        for payload in ["first", "second", "third"] {
            engine
                .append(&root_stream, payload.as_bytes())
                .expect("append");
        }

        let branch_status = engine
            .create_branch(
                branch_stream.clone(),
                StreamPosition::new(root_stream.clone(), Offset::new(1)),
                LineageMetadata::new(
                    Some("agent.retry".into()),
                    Some("branch-from-second-record".into()),
                ),
            )
            .expect("create branch");
        assert_eq!(branch_status.next_offset().value(), 2);
        assert_eq!(branch_status.rolled_segment_count(), 0);
        assert_eq!(
            engine
                .load_manifest(&branch_stream)
                .expect("manifest")
                .segments()
                .len(),
            0
        );

        engine
            .append(&branch_stream, b"branch-only")
            .expect("append branch");
        let replayed = engine.replay(&branch_stream).expect("replay branch");
        let offsets: Vec<u64> = replayed
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let payloads: Vec<&[u8]> = replayed.iter().map(|record| record.payload()).collect();

        assert_eq!(offsets, vec![0, 1, 2]);
        assert_eq!(
            payloads,
            vec![
                b"first".as_slice(),
                b"second".as_slice(),
                b"branch-only".as_slice()
            ]
        );
    }

    #[test]
    fn merge_creation_records_parent_heads_and_metadata() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(2)
                .expect("config"),
        )
        .expect("engine");
        let root_stream = stream_id("task.root");
        let branch_a = stream_id("task.retry");
        let branch_b = stream_id("task.critique");
        let merge_stream = stream_id("task.merge");
        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create root");
        engine.append(&root_stream, b"seed").expect("append seed");
        engine
            .append(&root_stream, b"context")
            .expect("append context");

        engine
            .create_branch(
                branch_a.clone(),
                StreamPosition::new(root_stream.clone(), Offset::new(0)),
                LineageMetadata::new(Some("agent.retry".into()), Some("explore".into())),
            )
            .expect("create branch a");
        engine
            .append(&branch_a, b"candidate-a")
            .expect("append branch a");

        engine
            .create_branch(
                branch_b.clone(),
                StreamPosition::new(root_stream.clone(), Offset::new(0)),
                LineageMetadata::new(Some("agent.critique".into()), Some("explore".into())),
            )
            .expect("create branch b");
        engine
            .append(&branch_b, b"candidate-b")
            .expect("append branch b");

        let merge_spec = MergeSpec::new(
            vec![
                StreamPosition::new(branch_a.clone(), Offset::new(1)),
                StreamPosition::new(branch_b.clone(), Offset::new(1)),
            ],
            Some(StreamPosition::new(root_stream.clone(), Offset::new(0))),
            MergePolicy::new(MergePolicyKind::Recursive)
                .with_metadata("policy_reason", "pick-best-candidate"),
            LineageMetadata::new(Some("agent.judge".into()), Some("merge-candidates".into())),
        )
        .expect("merge spec");

        let merge_status = engine
            .create_merge(merge_stream.clone(), merge_spec.clone())
            .expect("create merge");
        assert_eq!(merge_status.next_offset().value(), 1);

        let descriptor = engine.stream_descriptor(&merge_stream).expect("descriptor");
        match descriptor.lineage {
            StreamLineage::Merge { merge } => {
                assert_eq!(merge.parents, merge_spec.parents);
                assert_eq!(merge.parents[0].stream_id.as_str(), "task.retry");
                assert_eq!(merge.parents[1].stream_id.as_str(), "task.critique");
                assert_eq!(
                    merge
                        .policy
                        .metadata
                        .get("policy_reason")
                        .map(String::as_str),
                    Some("pick-best-candidate")
                );
                assert_eq!(merge.metadata.reason.as_deref(), Some("merge-candidates"));
            }
            other => panic!("expected merge lineage, got {other:?}"),
        }

        engine
            .append(&merge_stream, b"merged-answer")
            .expect("append merge");
        let replayed = engine.replay(&merge_stream).expect("replay merge");
        let offsets: Vec<u64> = replayed
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let payloads: Vec<&[u8]> = replayed.iter().map(|record| record.payload()).collect();

        assert_eq!(offsets, vec![0, 1]);
        assert_eq!(
            payloads,
            vec![b"seed".as_slice(), b"merged-answer".as_slice()]
        );
    }

    #[test]
    fn branch_and_merge_preserve_append_only_lineage_and_monotonic_offsets() {
        let temp_dir = tempdir().expect("temp dir");
        let engine = LocalEngine::open(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(4)
                .expect("config"),
        )
        .expect("engine");
        let root_stream = stream_id("task.root");
        let branch_stream = stream_id("task.retry");
        let merge_stream = stream_id("task.merge");
        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create root");

        engine.append(&root_stream, b"root-0").expect("append root");
        engine.append(&root_stream, b"root-1").expect("append root");

        engine
            .create_branch(
                branch_stream.clone(),
                StreamPosition::new(root_stream.clone(), Offset::new(1)),
                LineageMetadata::new(Some("agent.retry".into()), Some("branch".into())),
            )
            .expect("create branch");
        engine
            .append(&branch_stream, b"branch-2")
            .expect("append branch");

        let merge = MergeSpec::new(
            vec![
                StreamPosition::new(root_stream.clone(), Offset::new(1)),
                StreamPosition::new(branch_stream.clone(), Offset::new(2)),
            ],
            Some(StreamPosition::new(root_stream.clone(), Offset::new(1))),
            MergePolicy::new(MergePolicyKind::FastForward),
            LineageMetadata::new(Some("agent.judge".into()), Some("merge".into())),
        )
        .expect("merge spec");
        engine
            .create_merge(merge_stream.clone(), merge)
            .expect("create merge");
        engine
            .append(&merge_stream, b"merge-2")
            .expect("append merge");

        let root_offsets: Vec<u64> = engine
            .replay(&root_stream)
            .expect("replay root")
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let branch_offsets: Vec<u64> = engine
            .replay(&branch_stream)
            .expect("replay branch")
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let merge_offsets: Vec<u64> = engine
            .replay(&merge_stream)
            .expect("replay merge")
            .iter()
            .map(|record| record.position().offset.value())
            .collect();

        assert_eq!(root_offsets, vec![0, 1]);
        assert_eq!(branch_offsets, vec![0, 1, 2]);
        assert_eq!(merge_offsets, vec![0, 1, 2]);
    }
}
