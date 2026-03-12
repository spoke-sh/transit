use crate::kernel::{Offset, StreamId, StreamPosition};
use anyhow::{Result, ensure};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Stable identifier for one immutable segment.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct SegmentId(String);

impl SegmentId {
    pub fn new(value: impl Into<String>) -> Result<Self> {
        let value = value.into();
        ensure!(!value.trim().is_empty(), "segment ids must not be empty");
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// Stable identifier for one published manifest.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct ManifestId(String);

impl ManifestId {
    pub fn new(value: impl Into<String>) -> Result<Self> {
        let value = value.into();
        ensure!(!value.trim().is_empty(), "manifest ids must not be empty");
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// Logical object-store key. The scaffold stays backend-neutral and avoids
/// baking in one provider-specific URI scheme.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct ObjectStoreKey(String);

impl ObjectStoreKey {
    pub fn new(value: impl Into<String>) -> Result<Self> {
        let value = value.into();
        ensure!(
            !value.trim().is_empty(),
            "object-store keys must not be empty"
        );
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SegmentChecksum {
    algorithm: String,
    digest: String,
}

impl SegmentChecksum {
    pub fn new(algorithm: impl Into<String>, digest: impl Into<String>) -> Result<Self> {
        let algorithm = algorithm.into();
        let digest = digest.into();
        ensure!(
            !algorithm.trim().is_empty(),
            "checksum algorithm must not be empty"
        );
        ensure!(
            !digest.trim().is_empty(),
            "checksum digest must not be empty"
        );

        Ok(Self { algorithm, digest })
    }

    pub fn algorithm(&self) -> &str {
        &self.algorithm
    }

    pub fn digest(&self) -> &str {
        &self.digest
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ObjectStoreLocation {
    key: ObjectStoreKey,
    e_tag: Option<String>,
}

impl ObjectStoreLocation {
    pub fn new(key: ObjectStoreKey, e_tag: Option<String>) -> Self {
        Self { key, e_tag }
    }

    pub fn key(&self) -> &ObjectStoreKey {
        &self.key
    }

    pub fn e_tag(&self) -> Option<&str> {
        self.e_tag.as_deref()
    }
}

/// Explicit local and remote placement for an immutable segment or manifest.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StorageLocation {
    local_path: Option<PathBuf>,
    object_store: Option<ObjectStoreLocation>,
}

impl StorageLocation {
    pub fn new(
        local_path: Option<PathBuf>,
        object_store: Option<ObjectStoreLocation>,
    ) -> Result<Self> {
        ensure!(
            local_path.is_some() || object_store.is_some(),
            "storage locations require a local path, object-store location, or both"
        );

        Ok(Self {
            local_path,
            object_store,
        })
    }

    pub fn local_path(&self) -> Option<&PathBuf> {
        self.local_path.as_ref()
    }

    pub fn object_store(&self) -> Option<&ObjectStoreLocation> {
        self.object_store.as_ref()
    }

    pub fn with_object_store(&self, object_store: Option<ObjectStoreLocation>) -> Result<Self> {
        Self::new(self.local_path.clone(), object_store)
    }
}

/// Immutable segment descriptor shared by embedded and server-facing code.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SegmentDescriptor {
    segment_id: SegmentId,
    stream_id: StreamId,
    start_offset: Offset,
    last_offset: Offset,
    record_count: u64,
    byte_length: u64,
    checksum: SegmentChecksum,
    storage: StorageLocation,
}

impl SegmentDescriptor {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        segment_id: SegmentId,
        stream_id: StreamId,
        start_offset: Offset,
        last_offset: Offset,
        record_count: u64,
        byte_length: u64,
        checksum: SegmentChecksum,
        storage: StorageLocation,
    ) -> Result<Self> {
        ensure!(
            last_offset.value() >= start_offset.value(),
            "segment offsets must be monotonic"
        );
        ensure!(
            record_count > 0,
            "segments must contain at least one record"
        );

        Ok(Self {
            segment_id,
            stream_id,
            start_offset,
            last_offset,
            record_count,
            byte_length,
            checksum,
            storage,
        })
    }

    pub fn segment_id(&self) -> &SegmentId {
        &self.segment_id
    }

    pub fn stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    pub fn start_offset(&self) -> Offset {
        self.start_offset
    }

    pub fn last_offset(&self) -> Offset {
        self.last_offset
    }

    pub fn record_count(&self) -> u64 {
        self.record_count
    }

    pub fn byte_length(&self) -> u64 {
        self.byte_length
    }

    pub fn checksum(&self) -> &SegmentChecksum {
        &self.checksum
    }

    pub fn storage(&self) -> &StorageLocation {
        &self.storage
    }

    pub fn with_storage(&self, storage: StorageLocation) -> Self {
        Self {
            segment_id: self.segment_id.clone(),
            stream_id: self.stream_id.clone(),
            start_offset: self.start_offset,
            last_offset: self.last_offset,
            record_count: self.record_count,
            byte_length: self.byte_length,
            checksum: self.checksum.clone(),
            storage,
        }
    }
}

/// Future checkpoint/snapshot hand-off for materialized state.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MaterializationBoundary {
    checkpoint: StreamPosition,
    snapshot_hint: Option<String>,
    snapshot: Option<ObjectStoreLocation>,
}

impl MaterializationBoundary {
    pub fn new(
        checkpoint: StreamPosition,
        snapshot_hint: Option<String>,
        snapshot: Option<ObjectStoreLocation>,
    ) -> Self {
        Self {
            checkpoint,
            snapshot_hint,
            snapshot,
        }
    }

    pub fn checkpoint(&self) -> &StreamPosition {
        &self.checkpoint
    }

    pub fn snapshot_hint(&self) -> Option<&str> {
        self.snapshot_hint.as_deref()
    }

    pub fn snapshot(&self) -> Option<&ObjectStoreLocation> {
        self.snapshot.as_ref()
    }
}

/// Authoritative mapping from stream lineage to immutable segments.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SegmentManifest {
    manifest_id: ManifestId,
    stream_id: StreamId,
    generation: u64,
    segments: Vec<SegmentDescriptor>,
    storage: StorageLocation,
    materialization_boundary: Option<MaterializationBoundary>,
}

impl SegmentManifest {
    pub fn new(
        manifest_id: ManifestId,
        stream_id: StreamId,
        generation: u64,
        segments: Vec<SegmentDescriptor>,
        storage: StorageLocation,
        materialization_boundary: Option<MaterializationBoundary>,
    ) -> Self {
        Self {
            manifest_id,
            stream_id,
            generation,
            segments,
            storage,
            materialization_boundary,
        }
    }

    pub fn manifest_id(&self) -> &ManifestId {
        &self.manifest_id
    }

    pub fn stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    pub fn generation(&self) -> u64 {
        self.generation
    }

    pub fn segments(&self) -> &[SegmentDescriptor] {
        &self.segments
    }

    pub fn storage(&self) -> &StorageLocation {
        &self.storage
    }

    pub fn materialization_boundary(&self) -> Option<&MaterializationBoundary> {
        self.materialization_boundary.as_ref()
    }

    pub fn with_publication(
        &self,
        manifest_id: ManifestId,
        generation: u64,
        segments: Vec<SegmentDescriptor>,
        storage: StorageLocation,
    ) -> Self {
        Self {
            manifest_id,
            stream_id: self.stream_id.clone(),
            generation,
            segments,
            storage,
            materialization_boundary: self.materialization_boundary.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        ManifestId, MaterializationBoundary, ObjectStoreKey, ObjectStoreLocation, SegmentChecksum,
        SegmentDescriptor, SegmentId, SegmentManifest, StorageLocation,
    };
    use crate::kernel::{LineageMetadata, Offset, StreamDescriptor, StreamId, StreamPosition};
    use std::path::PathBuf;

    fn stream_id(value: &str) -> StreamId {
        StreamId::new(value).expect("stream id")
    }

    fn object_store_location(key: &str) -> ObjectStoreLocation {
        ObjectStoreLocation::new(
            ObjectStoreKey::new(key).expect("object-store key"),
            Some("etag-1".into()),
        )
    }

    #[test]
    fn segment_descriptor_keeps_local_and_object_store_locations_explicit() {
        let segment = SegmentDescriptor::new(
            SegmentId::new("segment-0001").expect("segment id"),
            stream_id("task.root"),
            Offset::new(0),
            Offset::new(9),
            10,
            4_096,
            SegmentChecksum::new("sha256", "deadbeef").expect("checksum"),
            StorageLocation::new(
                Some(PathBuf::from("segments/task.root/0001.segment")),
                Some(object_store_location(
                    "streams/task.root/segments/0001.segment",
                )),
            )
            .expect("storage location"),
        )
        .expect("segment");

        assert_eq!(segment.segment_id().as_str(), "segment-0001");
        assert_eq!(segment.stream_id().as_str(), "task.root");
        assert_eq!(segment.start_offset().value(), 0);
        assert_eq!(segment.last_offset().value(), 9);
        assert_eq!(
            segment
                .storage()
                .object_store()
                .expect("object store")
                .key()
                .as_str(),
            "streams/task.root/segments/0001.segment"
        );
        assert_eq!(
            segment.storage().local_path().expect("local path"),
            &PathBuf::from("segments/task.root/0001.segment")
        );
    }

    #[test]
    fn manifest_can_carry_materialization_boundary_without_changing_storage_model() {
        let root = StreamDescriptor::root(
            stream_id("task.root"),
            LineageMetadata::new(Some("agent".into()), Some("initial-request".into())),
        );
        let segment = SegmentDescriptor::new(
            SegmentId::new("segment-0001").expect("segment id"),
            root.stream_id.clone(),
            Offset::new(0),
            Offset::new(4),
            5,
            2_048,
            SegmentChecksum::new("sha256", "feedface").expect("checksum"),
            StorageLocation::new(
                Some(PathBuf::from("segments/task.root/0001.segment")),
                Some(object_store_location(
                    "streams/task.root/segments/0001.segment",
                )),
            )
            .expect("storage location"),
        )
        .expect("segment");

        let boundary = MaterializationBoundary::new(
            StreamPosition::new(root.stream_id.clone(), Offset::new(4)),
            Some("snapshot-v1".into()),
            Some(object_store_location("materialize/task.root/snapshot-v1")),
        );

        let manifest = SegmentManifest::new(
            ManifestId::new("manifest-0001").expect("manifest id"),
            root.stream_id,
            1,
            vec![segment],
            StorageLocation::new(
                Some(PathBuf::from("manifests/task.root/0001.json")),
                Some(object_store_location(
                    "streams/task.root/manifests/0001.json",
                )),
            )
            .expect("manifest location"),
            Some(boundary),
        );

        assert_eq!(manifest.manifest_id().as_str(), "manifest-0001");
        assert_eq!(manifest.generation(), 1);
        assert_eq!(manifest.segments().len(), 1);
        assert_eq!(
            manifest
                .materialization_boundary()
                .expect("boundary")
                .checkpoint()
                .offset
                .value(),
            4
        );
    }

    #[test]
    fn scaffold_rejects_invalid_segment_ranges_or_missing_locations() {
        let missing_location = StorageLocation::new(None, None).expect_err("missing location");
        assert!(
            missing_location
                .to_string()
                .contains("storage locations require a local path")
        );

        let invalid_segment = SegmentDescriptor::new(
            SegmentId::new("segment-0002").expect("segment id"),
            stream_id("task.root"),
            Offset::new(9),
            Offset::new(4),
            1,
            512,
            SegmentChecksum::new("sha256", "beadfeed").expect("checksum"),
            StorageLocation::new(Some(PathBuf::from("segments/task.root/0002.segment")), None)
                .expect("storage location"),
        )
        .expect_err("inverted offsets");
        assert!(
            invalid_segment
                .to_string()
                .contains("segment offsets must be monotonic")
        );
    }
}
