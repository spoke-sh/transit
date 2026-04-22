use crate::storage::SegmentCompression;
use anyhow::{Context, Result, anyhow, bail};
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum TransitMode {
    #[default]
    Embedded,
    Server,
}

impl TransitMode {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Embedded => "embedded",
            Self::Server => "server",
        }
    }
}

impl FromStr for TransitMode {
    type Err = anyhow::Error;

    fn from_str(value: &str) -> Result<Self> {
        match value.trim().to_ascii_lowercase().as_str() {
            "embedded" => Ok(Self::Embedded),
            "server" => Ok(Self::Server),
            other => bail!("unsupported transit mode '{other}'"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum StorageProvider {
    #[default]
    Filesystem,
    S3,
    Gcs,
    Azure,
}

impl StorageProvider {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Filesystem => "filesystem",
            Self::S3 => "s3",
            Self::Gcs => "gcs",
            Self::Azure => "azure",
        }
    }
}

impl FromStr for StorageProvider {
    type Err = anyhow::Error;

    fn from_str(value: &str) -> Result<Self> {
        match value.trim().to_ascii_lowercase().as_str() {
            "filesystem" => Ok(Self::Filesystem),
            "s3" => Ok(Self::S3),
            "gcs" => Ok(Self::Gcs),
            "azure" => Ok(Self::Azure),
            other => bail!("unsupported storage provider '{other}'"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum StorageDurability {
    Memory,
    #[default]
    Local,
    Replicated,
    Quorum,
    Tiered,
}

impl StorageDurability {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Memory => "memory",
            Self::Local => "local",
            Self::Replicated => "replicated",
            Self::Quorum => "quorum",
            Self::Tiered => "tiered",
        }
    }
}

impl FromStr for StorageDurability {
    type Err = anyhow::Error;

    fn from_str(value: &str) -> Result<Self> {
        match value.trim().to_ascii_lowercase().as_str() {
            "memory" => Ok(Self::Memory),
            "local" => Ok(Self::Local),
            "replicated" => Ok(Self::Replicated),
            "quorum" => Ok(Self::Quorum),
            "tiered" => Ok(Self::Tiered),
            other => bail!("unsupported durability mode '{other}'"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "kebab-case")]
pub enum ReplicationMode {
    #[default]
    SingleNode,
    Cluster,
}

impl ReplicationMode {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::SingleNode => "single-node",
            Self::Cluster => "cluster",
        }
    }
}

impl FromStr for ReplicationMode {
    type Err = anyhow::Error;

    fn from_str(value: &str) -> Result<Self> {
        match value.trim().to_ascii_lowercase().as_str() {
            "single-node" => Ok(Self::SingleNode),
            "cluster" => Ok(Self::Cluster),
            other => bail!("unsupported replication mode '{other}'"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct TransitConfig {
    #[serde(default)]
    pub node: NodeConfig,
    #[serde(default)]
    pub storage: StorageConfig,
    #[serde(default)]
    pub streams: StreamsConfig,
    #[serde(default)]
    pub server: ServerSettings,
    #[serde(default)]
    pub replication: ReplicationConfig,
    #[serde(default)]
    pub telemetry: TelemetryConfig,
}

impl TransitConfig {
    pub fn effective_node_id(&self) -> &str {
        self.replication
            .node_id
            .as_deref()
            .unwrap_or(self.node.id.as_str())
    }

    pub fn filesystem_object_store_root(&self) -> Option<PathBuf> {
        if self.storage.provider == StorageProvider::Filesystem
            && !self.storage.bucket.trim().is_empty()
        {
            return Some(PathBuf::from(&self.storage.bucket));
        }

        None
    }

    fn apply_patch(&mut self, patch: TransitConfigPatch) {
        if let Some(node) = patch.node {
            self.node.apply_patch(node);
        }
        if let Some(storage) = patch.storage {
            self.storage.apply_patch(storage);
        }
        if let Some(streams) = patch.streams {
            self.streams.apply_patch(streams);
        }
        if let Some(server) = patch.server {
            self.server.apply_patch(server);
        }
        if let Some(replication) = patch.replication {
            self.replication.apply_patch(replication);
        }
        if let Some(telemetry) = patch.telemetry {
            self.telemetry.apply_patch(telemetry);
        }
    }

    fn apply_env_overrides(&mut self) -> Result<()> {
        if let Some(mode) = env_var("TRANSIT_MODE")? {
            self.node.mode = TransitMode::from_str(&mode)?;
        }
        if let Some(node_id) = env_var("TRANSIT_NODE_ID")? {
            self.replication.node_id = Some(node_id);
        }
        if let Some(namespace) = env_var("TRANSIT_NAMESPACE")? {
            self.node.namespace = namespace;
        }
        if let Some(data_dir) = env_path("TRANSIT_DATA_DIR") {
            self.node.data_dir = data_dir;
        }
        if let Some(cache_dir) = env_path("TRANSIT_CACHE_DIR") {
            self.node.cache_dir = cache_dir;
        }
        if let Some(provider) = env_var("TRANSIT_STORAGE_PROVIDER")? {
            self.storage.provider = StorageProvider::from_str(&provider)?;
        }
        if let Some(bucket) = env_var("TRANSIT_OBJECT_BUCKET")? {
            self.storage.bucket = bucket;
        }
        if let Some(prefix) = env_var("TRANSIT_OBJECT_PREFIX")? {
            self.storage.prefix = prefix;
        }
        if let Some(endpoint) = env_var("TRANSIT_OBJECT_ENDPOINT")? {
            self.storage.endpoint = Some(endpoint);
        }
        if let Some(durability) = env_var("TRANSIT_DURABILITY")? {
            self.storage.durability = StorageDurability::from_str(&durability)?;
        }
        if let Some(listen_addr) = env_var("TRANSIT_LISTEN_ADDR")? {
            self.server.listen_addr = listen_addr
                .parse()
                .with_context(|| format!("parse TRANSIT_LISTEN_ADDR '{listen_addr}'"))?;
        }
        if let Some(log_level) = env_var("TRANSIT_LOG")? {
            self.telemetry.log_level = log_level;
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NodeConfig {
    pub id: String,
    pub mode: TransitMode,
    pub namespace: String,
    pub data_dir: PathBuf,
    pub cache_dir: PathBuf,
}

impl Default for NodeConfig {
    fn default() -> Self {
        Self {
            id: default_node_id(),
            mode: TransitMode::Embedded,
            namespace: "default".to_owned(),
            data_dir: PathBuf::from(".transit/data"),
            cache_dir: PathBuf::from(".transit/cache"),
        }
    }
}

impl NodeConfig {
    fn apply_patch(&mut self, patch: NodeConfigPatch) {
        if let Some(id) = patch.id {
            self.id = id;
        }
        if let Some(mode) = patch.mode {
            self.mode = mode;
        }
        if let Some(namespace) = patch.namespace {
            self.namespace = namespace;
        }
        if let Some(data_dir) = patch.data_dir {
            self.data_dir = data_dir;
        }
        if let Some(cache_dir) = patch.cache_dir {
            self.cache_dir = cache_dir;
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StorageConfig {
    pub provider: StorageProvider,
    pub bucket: String,
    pub prefix: String,
    pub endpoint: Option<String>,
    pub region: Option<String>,
    pub durability: StorageDurability,
    pub segment_target_bytes: u64,
    pub flush_bytes: u64,
    pub flush_interval_ms: u64,
    pub compression: SegmentCompression,
    pub checksum: String,
    pub local_cache_bytes: u64,
    pub prefetch_window_segments: u64,
}

impl Default for StorageConfig {
    fn default() -> Self {
        Self {
            provider: StorageProvider::Filesystem,
            bucket: ".transit/objects".to_owned(),
            prefix: String::new(),
            endpoint: None,
            region: None,
            durability: StorageDurability::Local,
            segment_target_bytes: 134_217_728,
            flush_bytes: 1_048_576,
            flush_interval_ms: 50,
            compression: SegmentCompression::Zstd,
            checksum: "crc32c".to_owned(),
            local_cache_bytes: 2_147_483_648,
            prefetch_window_segments: 2,
        }
    }
}

impl StorageConfig {
    fn apply_patch(&mut self, patch: StorageConfigPatch) {
        if let Some(provider) = patch.provider {
            self.provider = provider;
        }
        if let Some(bucket) = patch.bucket {
            self.bucket = bucket;
        }
        if let Some(prefix) = patch.prefix {
            self.prefix = prefix;
        }
        if patch.endpoint.is_some() {
            self.endpoint = patch.endpoint;
        }
        if patch.region.is_some() {
            self.region = patch.region;
        }
        if let Some(durability) = patch.durability {
            self.durability = durability;
        }
        if let Some(segment_target_bytes) = patch.segment_target_bytes {
            self.segment_target_bytes = segment_target_bytes;
        }
        if let Some(flush_bytes) = patch.flush_bytes {
            self.flush_bytes = flush_bytes;
        }
        if let Some(flush_interval_ms) = patch.flush_interval_ms {
            self.flush_interval_ms = flush_interval_ms;
        }
        if let Some(compression) = patch.compression {
            self.compression = compression;
        }
        if let Some(checksum) = patch.checksum {
            self.checksum = checksum;
        }
        if let Some(local_cache_bytes) = patch.local_cache_bytes {
            self.local_cache_bytes = local_cache_bytes;
        }
        if let Some(prefetch_window_segments) = patch.prefetch_window_segments {
            self.prefetch_window_segments = prefetch_window_segments;
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StreamsConfig {
    pub max_record_bytes: u64,
    pub index_stride_bytes: u64,
    pub local_head_min_segments: u64,
    pub branch_policy: String,
    pub allow_branch_from_non_head: bool,
}

impl Default for StreamsConfig {
    fn default() -> Self {
        Self {
            max_record_bytes: 1_048_576,
            index_stride_bytes: 4_096,
            local_head_min_segments: 2,
            branch_policy: "single-writer".to_owned(),
            allow_branch_from_non_head: true,
        }
    }
}

impl StreamsConfig {
    fn apply_patch(&mut self, patch: StreamsConfigPatch) {
        if let Some(max_record_bytes) = patch.max_record_bytes {
            self.max_record_bytes = max_record_bytes;
        }
        if let Some(index_stride_bytes) = patch.index_stride_bytes {
            self.index_stride_bytes = index_stride_bytes;
        }
        if let Some(local_head_min_segments) = patch.local_head_min_segments {
            self.local_head_min_segments = local_head_min_segments;
        }
        if let Some(branch_policy) = patch.branch_policy {
            self.branch_policy = branch_policy;
        }
        if let Some(allow_branch_from_non_head) = patch.allow_branch_from_non_head {
            self.allow_branch_from_non_head = allow_branch_from_non_head;
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServerSettings {
    pub listen_addr: SocketAddr,
    pub advertise_addr: Option<String>,
    pub max_connections: u64,
    pub request_body_limit_bytes: u64,
    pub auth_mode: String,
}

impl Default for ServerSettings {
    fn default() -> Self {
        Self {
            listen_addr: "127.0.0.1:7171".parse().expect("default listen addr"),
            advertise_addr: None,
            max_connections: 1_024,
            request_body_limit_bytes: 8_388_608,
            auth_mode: "none".to_owned(),
        }
    }
}

impl ServerSettings {
    fn apply_patch(&mut self, patch: ServerSettingsPatch) {
        if let Some(listen_addr) = patch.listen_addr {
            self.listen_addr = listen_addr;
        }
        if patch.advertise_addr.is_some() {
            self.advertise_addr = patch.advertise_addr;
        }
        if let Some(max_connections) = patch.max_connections {
            self.max_connections = max_connections;
        }
        if let Some(request_body_limit_bytes) = patch.request_body_limit_bytes {
            self.request_body_limit_bytes = request_body_limit_bytes;
        }
        if let Some(auth_mode) = patch.auth_mode {
            self.auth_mode = auth_mode;
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReplicationConfig {
    pub mode: ReplicationMode,
    pub node_id: Option<String>,
    pub consensus_root: Option<PathBuf>,
    pub lease_duration_secs: u64,
    pub election_poll_interval_ms: u64,
    pub quorum_size: u64,
}

impl Default for ReplicationConfig {
    fn default() -> Self {
        Self {
            mode: ReplicationMode::SingleNode,
            node_id: None,
            consensus_root: None,
            lease_duration_secs: 10,
            election_poll_interval_ms: 1_000,
            quorum_size: 1,
        }
    }
}

impl ReplicationConfig {
    fn apply_patch(&mut self, patch: ReplicationConfigPatch) {
        if let Some(mode) = patch.mode {
            self.mode = mode;
        }
        if patch.node_id.is_some() {
            self.node_id = patch.node_id;
        }
        if patch.consensus_root.is_some() {
            self.consensus_root = patch.consensus_root;
        }
        if let Some(lease_duration_secs) = patch.lease_duration_secs {
            self.lease_duration_secs = lease_duration_secs;
        }
        if let Some(election_poll_interval_ms) = patch.election_poll_interval_ms {
            self.election_poll_interval_ms = election_poll_interval_ms;
        }
        if let Some(quorum_size) = patch.quorum_size {
            self.quorum_size = quorum_size;
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TelemetryConfig {
    pub log_level: String,
    pub metrics_namespace: String,
    pub prometheus_addr: Option<SocketAddr>,
    pub tracing_json: bool,
    pub slow_request_ms: u64,
}

impl Default for TelemetryConfig {
    fn default() -> Self {
        Self {
            log_level: "info".to_owned(),
            metrics_namespace: "transit".to_owned(),
            prometheus_addr: None,
            tracing_json: false,
            slow_request_ms: 25,
        }
    }
}

impl TelemetryConfig {
    fn apply_patch(&mut self, patch: TelemetryConfigPatch) {
        if let Some(log_level) = patch.log_level {
            self.log_level = log_level;
        }
        if let Some(metrics_namespace) = patch.metrics_namespace {
            self.metrics_namespace = metrics_namespace;
        }
        if patch.prometheus_addr.is_some() {
            self.prometheus_addr = patch.prometheus_addr;
        }
        if let Some(tracing_json) = patch.tracing_json {
            self.tracing_json = tracing_json;
        }
        if let Some(slow_request_ms) = patch.slow_request_ms {
            self.slow_request_ms = slow_request_ms;
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LoadedTransitConfig {
    config: TransitConfig,
    sources: Vec<PathBuf>,
}

impl LoadedTransitConfig {
    pub fn new(config: TransitConfig, sources: Vec<PathBuf>) -> Self {
        Self { config, sources }
    }

    pub fn config(&self) -> &TransitConfig {
        &self.config
    }

    pub fn sources(&self) -> &[PathBuf] {
        &self.sources
    }
}

pub fn load_transit_config(explicit_path: Option<PathBuf>) -> Result<LoadedTransitConfig> {
    let mut config = TransitConfig::default();
    let mut loaded_sources = Vec::new();

    for path in config_candidate_paths(explicit_path.clone())? {
        if !path.exists() {
            if explicit_config_requested(&path, explicit_path.as_deref()) {
                bail!("transit config file not found at {}", path.display());
            }
            continue;
        }

        let contents = fs::read_to_string(&path)
            .with_context(|| format!("read transit config {}", path.display()))?;
        let patch: TransitConfigPatch = toml::from_str(&contents)
            .with_context(|| format!("parse transit config {}", path.display()))?;
        config.apply_patch(patch);
        loaded_sources.push(path);
    }

    config.apply_env_overrides()?;

    Ok(LoadedTransitConfig::new(config, loaded_sources))
}

fn config_candidate_paths(explicit_path: Option<PathBuf>) -> Result<Vec<PathBuf>> {
    if let Some(path) = explicit_path {
        return Ok(vec![path]);
    }

    if let Some(path) = env_path("TRANSIT_CONFIG") {
        return Ok(vec![path]);
    }

    let mut paths = vec![PathBuf::from("/etc/transit.toml")];
    if let Some(xdg_path) = xdg_config_path()? {
        paths.push(xdg_path);
    }
    let cwd = env::current_dir().context("resolve current working directory for transit config")?;
    paths.push(cwd.join("transit.toml"));
    Ok(paths)
}

fn explicit_config_requested(path: &Path, cli_path: Option<&Path>) -> bool {
    cli_path.is_some() || env_path("TRANSIT_CONFIG").as_deref() == Some(path)
}

fn xdg_config_path() -> Result<Option<PathBuf>> {
    if let Some(path) = env_path("XDG_CONFIG_HOME") {
        return Ok(Some(path.join("transit/transit.toml")));
    }

    let Some(home) = env_path("HOME") else {
        return Ok(None);
    };
    Ok(Some(home.join(".config/transit/transit.toml")))
}

fn default_node_id() -> String {
    for key in ["HOSTNAME", "COMPUTERNAME"] {
        if let Some(value) = env::var_os(key)
            .map(|value| value.to_string_lossy().trim().to_owned())
            .filter(|value| !value.is_empty())
        {
            return value;
        }
    }

    "transit-node".to_owned()
}

fn env_var(name: &str) -> Result<Option<String>> {
    env::var_os(name)
        .map(|value| {
            value.into_string().map_err(|value| {
                anyhow!(
                    "{name} must be valid UTF-8, got '{}'",
                    value.to_string_lossy()
                )
            })
        })
        .transpose()
}

fn env_path(name: &str) -> Option<PathBuf> {
    env::var_os(name).map(PathBuf::from)
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
struct TransitConfigPatch {
    node: Option<NodeConfigPatch>,
    storage: Option<StorageConfigPatch>,
    streams: Option<StreamsConfigPatch>,
    server: Option<ServerSettingsPatch>,
    replication: Option<ReplicationConfigPatch>,
    telemetry: Option<TelemetryConfigPatch>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
struct NodeConfigPatch {
    id: Option<String>,
    mode: Option<TransitMode>,
    namespace: Option<String>,
    data_dir: Option<PathBuf>,
    cache_dir: Option<PathBuf>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
struct StorageConfigPatch {
    provider: Option<StorageProvider>,
    bucket: Option<String>,
    prefix: Option<String>,
    endpoint: Option<String>,
    region: Option<String>,
    durability: Option<StorageDurability>,
    segment_target_bytes: Option<u64>,
    flush_bytes: Option<u64>,
    flush_interval_ms: Option<u64>,
    compression: Option<SegmentCompression>,
    checksum: Option<String>,
    local_cache_bytes: Option<u64>,
    prefetch_window_segments: Option<u64>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
struct StreamsConfigPatch {
    max_record_bytes: Option<u64>,
    index_stride_bytes: Option<u64>,
    local_head_min_segments: Option<u64>,
    branch_policy: Option<String>,
    allow_branch_from_non_head: Option<bool>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
struct ServerSettingsPatch {
    listen_addr: Option<SocketAddr>,
    advertise_addr: Option<String>,
    max_connections: Option<u64>,
    request_body_limit_bytes: Option<u64>,
    auth_mode: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
struct ReplicationConfigPatch {
    mode: Option<ReplicationMode>,
    node_id: Option<String>,
    consensus_root: Option<PathBuf>,
    lease_duration_secs: Option<u64>,
    election_poll_interval_ms: Option<u64>,
    quorum_size: Option<u64>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
struct TelemetryConfigPatch {
    log_level: Option<String>,
    metrics_namespace: Option<String>,
    prometheus_addr: Option<SocketAddr>,
    tracing_json: Option<bool>,
    slow_request_ms: Option<u64>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn default_config_uses_local_filesystem_layout() {
        let config = TransitConfig::default();

        assert_eq!(config.node.mode, TransitMode::Embedded);
        assert_eq!(config.node.namespace, "default");
        assert_eq!(config.node.data_dir, PathBuf::from(".transit/data"));
        assert_eq!(config.node.cache_dir, PathBuf::from(".transit/cache"));
        assert_eq!(config.storage.provider, StorageProvider::Filesystem);
        assert_eq!(config.storage.bucket, ".transit/objects");
        assert_eq!(config.storage.durability, StorageDurability::Local);
        assert_eq!(config.storage.compression, SegmentCompression::Zstd);
        assert_eq!(config.server.listen_addr, "127.0.0.1:7171".parse().unwrap());
    }

    #[test]
    fn explicit_config_file_overrides_defaults_and_keeps_unspecified_values() {
        let temp_dir = tempdir().expect("temp dir");
        let config_path = temp_dir.path().join("transit.toml");
        fs::write(
            &config_path,
            r#"
[node]
id = "dev-a"
mode = "server"
data_dir = "var/data"

[storage]
bucket = "var/objects"
durability = "local"
compression = "none"

[server]
listen_addr = "127.0.0.1:9090"
"#,
        )
        .expect("write config");

        let loaded = load_transit_config(Some(config_path)).expect("load config");

        assert_eq!(loaded.sources().len(), 1);
        assert_eq!(loaded.config().node.id, "dev-a");
        assert_eq!(loaded.config().node.mode, TransitMode::Server);
        assert_eq!(loaded.config().node.data_dir, PathBuf::from("var/data"));
        assert_eq!(
            loaded.config().node.cache_dir,
            PathBuf::from(".transit/cache")
        );
        assert_eq!(loaded.config().storage.bucket, "var/objects");
        assert_eq!(
            loaded.config().storage.provider,
            StorageProvider::Filesystem
        );
        assert_eq!(
            loaded.config().storage.compression,
            SegmentCompression::None
        );
        assert_eq!(
            loaded.config().server.listen_addr,
            "127.0.0.1:9090".parse().unwrap()
        );
    }
}
