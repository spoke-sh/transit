use crate::engine::{
    DurabilityMode, LocalAppendOutcome, LocalEngine, LocalEngineConfig, LocalRecord,
    LocalStreamStatus,
};
use crate::kernel::{
    LineageMetadata, MergeSpec, Offset, StreamDescriptor, StreamId, StreamPosition,
};
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fmt;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::net::{Shutdown, SocketAddr, TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;

const DEFAULT_ACCEPT_POLL_INTERVAL_MS: u64 = 10;
const DEFAULT_CONNECTION_IO_TIMEOUT_MS: u64 = 1_000;

#[derive(Debug, Clone)]
pub struct ServerConfig {
    engine: LocalEngineConfig,
    listen_addr: SocketAddr,
    accept_poll_interval: Duration,
    connection_io_timeout: Duration,
}

impl ServerConfig {
    pub fn new(engine: LocalEngineConfig, listen_addr: SocketAddr) -> Self {
        Self {
            engine,
            listen_addr,
            accept_poll_interval: Duration::from_millis(DEFAULT_ACCEPT_POLL_INTERVAL_MS),
            connection_io_timeout: Duration::from_millis(DEFAULT_CONNECTION_IO_TIMEOUT_MS),
        }
    }

    pub fn engine(&self) -> &LocalEngineConfig {
        &self.engine
    }

    pub fn listen_addr(&self) -> SocketAddr {
        self.listen_addr
    }

    pub fn accept_poll_interval(&self) -> Duration {
        self.accept_poll_interval
    }

    pub fn connection_io_timeout(&self) -> Duration {
        self.connection_io_timeout
    }
}

pub struct ServerHandle {
    engine: LocalEngine,
    local_addr: SocketAddr,
    shutdown_requested: Arc<AtomicBool>,
    accepted_connections: Arc<AtomicU64>,
    fatal_error: Arc<Mutex<Option<String>>>,
    listener_thread: Option<JoinHandle<()>>,
}

impl ServerHandle {
    pub fn bind(config: ServerConfig) -> Result<Self> {
        let engine = LocalEngine::open(config.engine().clone()).with_context(|| {
            format!(
                "open shared engine for server at {}",
                config.engine().data_dir().display()
            )
        })?;
        let listener = TcpListener::bind(config.listen_addr())
            .with_context(|| format!("bind server listener at {}", config.listen_addr()))?;
        listener
            .set_nonblocking(true)
            .context("set server listener nonblocking")?;
        let local_addr = listener
            .local_addr()
            .context("resolve bound server listener address")?;

        let shutdown_requested = Arc::new(AtomicBool::new(false));
        let accepted_connections = Arc::new(AtomicU64::new(0));
        let fatal_error = Arc::new(Mutex::new(None));

        let thread_engine = engine.clone();
        let thread_shutdown = Arc::clone(&shutdown_requested);
        let thread_connections = Arc::clone(&accepted_connections);
        let thread_error = Arc::clone(&fatal_error);
        let accept_poll_interval = config.accept_poll_interval();
        let connection_io_timeout = config.connection_io_timeout();
        let listener_thread = thread::Builder::new()
            .name("transit-server-listener".into())
            .spawn(move || {
                run_accept_loop(
                    listener,
                    thread_engine,
                    thread_shutdown,
                    thread_connections,
                    thread_error,
                    accept_poll_interval,
                    connection_io_timeout,
                )
            })
            .context("spawn server listener thread")?;

        Ok(Self {
            engine,
            local_addr,
            shutdown_requested,
            accepted_connections,
            fatal_error,
            listener_thread: Some(listener_thread),
        })
    }

    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }

    pub fn data_dir(&self) -> &Path {
        self.engine.data_dir()
    }

    pub fn durability(&self) -> DurabilityMode {
        self.engine.durability()
    }

    pub fn engine(&self) -> LocalEngine {
        self.engine.clone()
    }

    pub fn accepted_connections(&self) -> u64 {
        self.accepted_connections.load(Ordering::Acquire)
    }

    pub fn shutdown(mut self) -> Result<ServerShutdownOutcome> {
        self.shutdown_requested.store(true, Ordering::Release);
        let _ = TcpStream::connect(self.local_addr);

        if let Some(listener_thread) = self.listener_thread.take() {
            listener_thread
                .join()
                .map_err(|_| anyhow::anyhow!("server listener thread panicked"))?;
        }

        if let Some(error) = self
            .fatal_error
            .lock()
            .expect("listener fatal_error mutex poisoned")
            .take()
        {
            return Err(anyhow::anyhow!(error));
        }

        Ok(ServerShutdownOutcome {
            data_dir: self.engine.data_dir().to_path_buf(),
            local_addr: self.local_addr,
            durability: self.engine.durability(),
            accepted_connections: self.accepted_connections.load(Ordering::Acquire),
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServerShutdownOutcome {
    data_dir: PathBuf,
    local_addr: SocketAddr,
    durability: DurabilityMode,
    accepted_connections: u64,
}

impl ServerShutdownOutcome {
    pub fn data_dir(&self) -> &Path {
        &self.data_dir
    }

    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }

    pub fn durability(&self) -> DurabilityMode {
        self.durability
    }

    pub fn accepted_connections(&self) -> u64 {
        self.accepted_connections
    }
}

#[derive(Debug, Clone)]
pub struct RemoteClient {
    server_addr: SocketAddr,
    io_timeout: Duration,
}

impl RemoteClient {
    pub fn new(server_addr: SocketAddr) -> Self {
        Self {
            server_addr,
            io_timeout: Duration::from_millis(DEFAULT_CONNECTION_IO_TIMEOUT_MS),
        }
    }

    pub fn append(
        &self,
        stream_id: &StreamId,
        payload: impl AsRef<[u8]>,
    ) -> RemoteClientResult<RemoteAppendOutcome> {
        match self.send_request(ConnectionRequest::Append {
            stream_id: stream_id.clone(),
            payload: payload.as_ref().to_vec(),
        })? {
            ConnectionResponse::AppendOk(outcome) => Ok(outcome),
            ConnectionResponse::Error(error) => Err(RemoteClientError::Remote(error)),
            other => Err(RemoteClientError::Protocol(format!(
                "append expected append_ok response, got {other:?}"
            ))),
        }
    }

    pub fn read(&self, stream_id: &StreamId) -> RemoteClientResult<RemoteReadOutcome> {
        match self.send_request(ConnectionRequest::Read {
            stream_id: stream_id.clone(),
        })? {
            ConnectionResponse::RecordsOk(outcome) => Ok(outcome),
            ConnectionResponse::Error(error) => Err(RemoteClientError::Remote(error)),
            other => Err(RemoteClientError::Protocol(format!(
                "read expected records_ok response, got {other:?}"
            ))),
        }
    }

    pub fn tail(
        &self,
        stream_id: &StreamId,
        from_offset: Offset,
    ) -> RemoteClientResult<RemoteReadOutcome> {
        match self.send_request(ConnectionRequest::Tail {
            stream_id: stream_id.clone(),
            from_offset,
        })? {
            ConnectionResponse::RecordsOk(outcome) => Ok(outcome),
            ConnectionResponse::Error(error) => Err(RemoteClientError::Remote(error)),
            other => Err(RemoteClientError::Protocol(format!(
                "tail expected records_ok response, got {other:?}"
            ))),
        }
    }

    pub fn create_branch(
        &self,
        stream_id: &StreamId,
        parent: StreamPosition,
        metadata: LineageMetadata,
    ) -> RemoteClientResult<RemoteStreamStatus> {
        match self.send_request(ConnectionRequest::CreateBranch {
            stream_id: stream_id.clone(),
            parent,
            metadata,
        })? {
            ConnectionResponse::StreamStatusOk(status) => Ok(status),
            ConnectionResponse::Error(error) => Err(RemoteClientError::Remote(error)),
            other => Err(RemoteClientError::Protocol(format!(
                "create_branch expected stream_status_ok response, got {other:?}"
            ))),
        }
    }

    pub fn create_merge(
        &self,
        stream_id: &StreamId,
        merge: MergeSpec,
    ) -> RemoteClientResult<RemoteStreamStatus> {
        match self.send_request(ConnectionRequest::CreateMerge {
            stream_id: stream_id.clone(),
            merge,
        })? {
            ConnectionResponse::StreamStatusOk(status) => Ok(status),
            ConnectionResponse::Error(error) => Err(RemoteClientError::Remote(error)),
            other => Err(RemoteClientError::Protocol(format!(
                "create_merge expected stream_status_ok response, got {other:?}"
            ))),
        }
    }

    pub fn inspect_lineage(
        &self,
        stream_id: &StreamId,
    ) -> RemoteClientResult<RemoteLineageOutcome> {
        match self.send_request(ConnectionRequest::InspectLineage {
            stream_id: stream_id.clone(),
        })? {
            ConnectionResponse::LineageOk(lineage) => Ok(lineage),
            ConnectionResponse::Error(error) => Err(RemoteClientError::Remote(error)),
            other => Err(RemoteClientError::Protocol(format!(
                "inspect_lineage expected lineage_ok response, got {other:?}"
            ))),
        }
    }

    fn send_request(&self, request: ConnectionRequest) -> RemoteClientResult<ConnectionResponse> {
        let mut stream =
            TcpStream::connect_timeout(&self.server_addr, self.io_timeout).map_err(|error| {
                RemoteClientError::Transport(format!("connect to {}: {error}", self.server_addr))
            })?;
        configure_connection_stream(&stream, self.io_timeout).map_err(|error| {
            RemoteClientError::Transport(format!(
                "configure connection to {}: {error}",
                self.server_addr
            ))
        })?;

        let mut encoded = serde_json::to_vec(&request)
            .map_err(|error| RemoteClientError::Protocol(format!("encode request: {error}")))?;
        encoded.push(b'\n');
        stream
            .write_all(&encoded)
            .map_err(|error| RemoteClientError::Transport(format!("send request: {error}")))?;
        stream
            .flush()
            .map_err(|error| RemoteClientError::Transport(format!("flush request: {error}")))?;
        let _ = stream.shutdown(Shutdown::Write);

        let mut response_line = String::new();
        let mut reader = BufReader::new(stream);
        reader
            .read_line(&mut response_line)
            .map_err(|error| RemoteClientError::Transport(format!("read response: {error}")))?;
        if response_line.trim().is_empty() {
            return Err(RemoteClientError::Protocol(
                "server returned an empty response".into(),
            ));
        }

        serde_json::from_str(response_line.trim_end())
            .map_err(|error| RemoteClientError::Decode(format!("decode response: {error}")))
    }
}

pub type RemoteClientResult<T> = std::result::Result<T, RemoteClientError>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RemoteClientError {
    Transport(String),
    Decode(String),
    Protocol(String),
    Remote(RemoteErrorResponse),
}

impl fmt::Display for RemoteClientError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Transport(message) => write!(f, "transport error: {message}"),
            Self::Decode(message) => write!(f, "decode error: {message}"),
            Self::Protocol(message) => write!(f, "protocol error: {message}"),
            Self::Remote(error) => {
                write!(f, "remote error [{}]: {}", error.code(), error.message())
            }
        }
    }
}

impl std::error::Error for RemoteClientError {}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteAppendOutcome {
    position: StreamPosition,
    durability: String,
    manifest_generation: u64,
    rolled_segment_id: Option<String>,
}

impl RemoteAppendOutcome {
    pub fn position(&self) -> &StreamPosition {
        &self.position
    }

    pub fn durability(&self) -> &str {
        &self.durability
    }

    pub fn manifest_generation(&self) -> u64 {
        self.manifest_generation
    }

    pub fn rolled_segment_id(&self) -> Option<&str> {
        self.rolled_segment_id.as_deref()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteReadOutcome {
    stream_id: StreamId,
    durability: String,
    records: Vec<RemoteRecord>,
}

impl RemoteReadOutcome {
    pub fn stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    pub fn durability(&self) -> &str {
        &self.durability
    }

    pub fn records(&self) -> &[RemoteRecord] {
        &self.records
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteRecord {
    position: StreamPosition,
    payload: Vec<u8>,
}

impl RemoteRecord {
    pub fn position(&self) -> &StreamPosition {
        &self.position
    }

    pub fn payload(&self) -> &[u8] {
        &self.payload
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteStreamStatus {
    stream_id: StreamId,
    durability: String,
    next_offset: Offset,
    active_record_count: u64,
    active_segment_start_offset: Offset,
    manifest_generation: u64,
    rolled_segment_count: usize,
}

impl RemoteStreamStatus {
    pub fn stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    pub fn durability(&self) -> &str {
        &self.durability
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteLineageOutcome {
    descriptor: StreamDescriptor,
    status: RemoteStreamStatus,
    topology: RemoteTopology,
}

impl RemoteLineageOutcome {
    pub fn descriptor(&self) -> &StreamDescriptor {
        &self.descriptor
    }

    pub fn status(&self) -> &RemoteStreamStatus {
        &self.status
    }

    pub fn topology(&self) -> RemoteTopology {
        self.topology
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RemoteTopology {
    SingleNode,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteErrorResponse {
    code: RemoteErrorCode,
    message: String,
}

impl RemoteErrorResponse {
    pub fn code(&self) -> RemoteErrorCode {
        self.code
    }

    pub fn message(&self) -> &str {
        &self.message
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RemoteErrorCode {
    InvalidRequest,
    NotFound,
    Internal,
}

impl fmt::Display for RemoteErrorCode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidRequest => write!(f, "invalid_request"),
            Self::NotFound => write!(f, "not_found"),
            Self::Internal => write!(f, "internal"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ConnectionRequest {
    Append {
        stream_id: StreamId,
        payload: Vec<u8>,
    },
    CreateBranch {
        stream_id: StreamId,
        parent: StreamPosition,
        metadata: LineageMetadata,
    },
    CreateMerge {
        stream_id: StreamId,
        merge: MergeSpec,
    },
    InspectLineage {
        stream_id: StreamId,
    },
    Read {
        stream_id: StreamId,
    },
    Tail {
        stream_id: StreamId,
        from_offset: Offset,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ConnectionResponse {
    AppendOk(RemoteAppendOutcome),
    RecordsOk(RemoteReadOutcome),
    StreamStatusOk(RemoteStreamStatus),
    LineageOk(RemoteLineageOutcome),
    Error(RemoteErrorResponse),
}

fn run_accept_loop(
    listener: TcpListener,
    engine: LocalEngine,
    shutdown_requested: Arc<AtomicBool>,
    accepted_connections: Arc<AtomicU64>,
    fatal_error: Arc<Mutex<Option<String>>>,
    accept_poll_interval: Duration,
    connection_io_timeout: Duration,
) {
    loop {
        if shutdown_requested.load(Ordering::Acquire) {
            break;
        }

        match listener.accept() {
            Ok((stream, _peer_addr)) => {
                if shutdown_requested.load(Ordering::Acquire) {
                    let _ = stream.shutdown(Shutdown::Both);
                    break;
                }

                accepted_connections.fetch_add(1, Ordering::AcqRel);
                serve_connection(stream, &engine, connection_io_timeout);
            }
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                thread::sleep(accept_poll_interval);
            }
            Err(error) => {
                *fatal_error
                    .lock()
                    .expect("listener fatal_error mutex poisoned") =
                    Some(format!("server listener failure: {error}"));
                break;
            }
        }
    }
}

fn serve_connection(mut stream: TcpStream, engine: &LocalEngine, io_timeout: Duration) {
    let response = match configure_connection_stream(&stream, io_timeout) {
        Ok(()) => match read_request(&mut stream) {
            Ok(request) => handle_request(engine, request),
            Err(error) => invalid_request_response(error),
        },
        Err(error) => internal_error_response(format!("configure connection: {error}")),
    };

    let _ = write_response(&mut stream, &response);
}

fn configure_connection_stream(stream: &TcpStream, io_timeout: Duration) -> std::io::Result<()> {
    stream.set_nodelay(true)?;
    stream.set_read_timeout(Some(io_timeout))?;
    stream.set_write_timeout(Some(io_timeout))?;
    Ok(())
}

fn read_request(stream: &mut TcpStream) -> Result<ConnectionRequest> {
    let mut request_line = String::new();
    {
        let mut reader = BufReader::new(stream);
        reader
            .read_line(&mut request_line)
            .context("read request line from client")?;
    }

    ensure_request_line(&request_line)?;
    serde_json::from_str(request_line.trim_end()).context("decode client request")
}

fn ensure_request_line(request_line: &str) -> Result<()> {
    if request_line.trim().is_empty() {
        anyhow::bail!("client request line must not be empty");
    }
    Ok(())
}

fn write_response(stream: &mut TcpStream, response: &ConnectionResponse) -> std::io::Result<()> {
    let mut encoded = serde_json::to_vec(response).map_err(std::io::Error::other)?;
    encoded.push(b'\n');

    let mut writer = BufWriter::new(stream);
    writer.write_all(&encoded)?;
    writer.flush()?;
    Ok(())
}

fn handle_request(engine: &LocalEngine, request: ConnectionRequest) -> ConnectionResponse {
    match request {
        ConnectionRequest::Append { stream_id, payload } => {
            match engine.append(&stream_id, payload) {
                Ok(outcome) => ConnectionResponse::AppendOk(map_append_outcome(outcome)),
                Err(error) => engine_error_response(error),
            }
        }
        ConnectionRequest::CreateBranch {
            stream_id,
            parent,
            metadata,
        } => match engine.create_branch(stream_id, parent, metadata) {
            Ok(status) => {
                ConnectionResponse::StreamStatusOk(map_stream_status(engine.durability(), status))
            }
            Err(error) => engine_error_response(error),
        },
        ConnectionRequest::CreateMerge { stream_id, merge } => {
            match engine.create_merge(stream_id, merge) {
                Ok(status) => ConnectionResponse::StreamStatusOk(map_stream_status(
                    engine.durability(),
                    status,
                )),
                Err(error) => engine_error_response(error),
            }
        }
        ConnectionRequest::InspectLineage { stream_id } => {
            match inspect_lineage(engine, &stream_id) {
                Ok(lineage) => ConnectionResponse::LineageOk(lineage),
                Err(error) => engine_error_response(error),
            }
        }
        ConnectionRequest::Read { stream_id } => match engine.replay(&stream_id) {
            Ok(records) => ConnectionResponse::RecordsOk(map_read_outcome(
                stream_id,
                engine.durability(),
                records,
            )),
            Err(error) => engine_error_response(error),
        },
        ConnectionRequest::Tail {
            stream_id,
            from_offset,
        } => match engine.tail_from(&stream_id, from_offset) {
            Ok(records) => ConnectionResponse::RecordsOk(map_read_outcome(
                stream_id,
                engine.durability(),
                records,
            )),
            Err(error) => engine_error_response(error),
        },
    }
}

fn map_append_outcome(outcome: LocalAppendOutcome) -> RemoteAppendOutcome {
    RemoteAppendOutcome {
        position: outcome.position().clone(),
        durability: outcome.durability().as_str().to_owned(),
        manifest_generation: outcome.manifest_generation(),
        rolled_segment_id: outcome
            .rolled_segment()
            .map(|segment| segment.segment_id().as_str().to_owned()),
    }
}

fn map_read_outcome(
    stream_id: StreamId,
    durability: DurabilityMode,
    records: Vec<LocalRecord>,
) -> RemoteReadOutcome {
    RemoteReadOutcome {
        stream_id,
        durability: durability.as_str().to_owned(),
        records: records.into_iter().map(map_record).collect(),
    }
}

fn map_stream_status(durability: DurabilityMode, status: LocalStreamStatus) -> RemoteStreamStatus {
    RemoteStreamStatus {
        stream_id: status.stream_id().clone(),
        durability: durability.as_str().to_owned(),
        next_offset: status.next_offset(),
        active_record_count: status.active_record_count(),
        active_segment_start_offset: status.active_segment_start_offset(),
        manifest_generation: status.manifest_generation(),
        rolled_segment_count: status.rolled_segment_count(),
    }
}

fn inspect_lineage(engine: &LocalEngine, stream_id: &StreamId) -> Result<RemoteLineageOutcome> {
    let descriptor = engine.stream_descriptor(stream_id)?;
    let status = engine.stream_status(stream_id)?;
    Ok(RemoteLineageOutcome {
        descriptor,
        status: map_stream_status(engine.durability(), status),
        topology: RemoteTopology::SingleNode,
    })
}

fn map_record(record: LocalRecord) -> RemoteRecord {
    RemoteRecord {
        position: record.position().clone(),
        payload: record.payload().to_vec(),
    }
}

fn invalid_request_response(error: anyhow::Error) -> ConnectionResponse {
    ConnectionResponse::Error(RemoteErrorResponse {
        code: RemoteErrorCode::InvalidRequest,
        message: error.to_string(),
    })
}

fn internal_error_response(message: String) -> ConnectionResponse {
    ConnectionResponse::Error(RemoteErrorResponse {
        code: RemoteErrorCode::Internal,
        message,
    })
}

fn engine_error_response(error: anyhow::Error) -> ConnectionResponse {
    ConnectionResponse::Error(RemoteErrorResponse {
        code: classify_engine_error(&error),
        message: error.to_string(),
    })
}

fn classify_engine_error(error: &anyhow::Error) -> RemoteErrorCode {
    if error.chain().any(|cause| {
        cause
            .downcast_ref::<std::io::Error>()
            .is_some_and(|io_error| io_error.kind() == std::io::ErrorKind::NotFound)
    }) {
        return RemoteErrorCode::NotFound;
    }

    if error
        .chain()
        .any(|cause| is_invalid_request_message(&cause.to_string()))
        || is_invalid_request_message(&error.to_string())
    {
        return RemoteErrorCode::InvalidRequest;
    }

    RemoteErrorCode::Internal
}

fn is_invalid_request_message(message: &str) -> bool {
    [
        "stream ids must not be empty",
        "branch creation must create a new stream head",
        "merge results must create a new stream head",
        "merge specs require",
        "lineage positions must reference an existing distinct stream",
        "lineage position ",
        "already exists",
    ]
    .into_iter()
    .any(|pattern| message.contains(pattern))
}

#[cfg(test)]
mod tests {
    use super::{
        RemoteClient, RemoteClientError, RemoteErrorCode, RemoteTopology, ServerConfig,
        ServerHandle,
    };
    use crate::engine::{DurabilityMode, LocalEngine, LocalEngineConfig};
    use crate::kernel::{
        LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset, StreamDescriptor,
        StreamId, StreamLineage, StreamPosition,
    };
    use serde_json::Value;
    use std::net::TcpStream;
    use std::time::Duration;
    use tempfile::tempdir;

    fn stream_id(value: &str) -> StreamId {
        StreamId::new(value).expect("stream id")
    }

    fn root_descriptor(value: &str) -> StreamDescriptor {
        StreamDescriptor::root(
            stream_id(value),
            LineageMetadata::new(Some("test".into()), Some("server-bootstrap".into())),
        )
    }

    #[test]
    fn server_bootstrap_binds_listener_and_accepts_connections() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path()),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");

        let local_addr = server.local_addr();
        let stream =
            TcpStream::connect_timeout(&local_addr, Duration::from_secs(1)).expect("connect");
        drop(stream);
        for _ in 0..20 {
            if server.accepted_connections() == 1 {
                break;
            }
            std::thread::sleep(Duration::from_millis(10));
        }

        let shutdown = server.shutdown().expect("shutdown server");
        assert_eq!(shutdown.local_addr(), local_addr);
        assert_eq!(shutdown.durability(), DurabilityMode::Local);
        assert_eq!(shutdown.accepted_connections(), 1);
    }

    #[test]
    fn server_shutdown_is_deterministic_for_tests_and_proof_flows() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path()),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let local_addr = server.local_addr();

        let shutdown = server.shutdown().expect("shutdown server");
        assert_eq!(shutdown.local_addr(), local_addr);
        assert_eq!(shutdown.data_dir(), temp_dir.path());

        let error = TcpStream::connect_timeout(&local_addr, Duration::from_millis(200))
            .expect_err("listener should be closed after shutdown");
        assert!(matches!(
            error.kind(),
            std::io::ErrorKind::ConnectionRefused
                | std::io::ErrorKind::TimedOut
                | std::io::ErrorKind::AddrNotAvailable
        ));
    }

    #[test]
    fn server_remains_a_wrapper_around_shared_engine_storage() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path()),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");

        let engine = server.engine();
        let stream_id = stream_id("server.root");
        engine
            .create_stream(root_descriptor("server.root"))
            .expect("create stream");
        engine.append(&stream_id, b"server-append").expect("append");

        let shutdown = server.shutdown().expect("shutdown server");
        assert_eq!(shutdown.accepted_connections(), 0);

        let reopened = LocalEngine::open(LocalEngineConfig::new(temp_dir.path()))
            .expect("reopen local engine");
        let replayed = reopened.replay(&stream_id).expect("replay");

        assert_eq!(replayed.len(), 1);
        assert_eq!(replayed[0].payload(), b"server-append");
    }

    #[test]
    fn remote_append_read_and_tail_preserve_positions_and_branch_aware_replay_behavior() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(8)
                .expect("config"),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let client = RemoteClient::new(server.local_addr());
        let engine = server.engine();
        let root_stream = stream_id("task.root");
        let branch_stream = stream_id("task.root.branch");

        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create root stream");

        let first = client.append(&root_stream, b"first").expect("append first");
        let second = client
            .append(&root_stream, b"second")
            .expect("append second");
        engine
            .create_branch(
                branch_stream.clone(),
                StreamPosition::new(root_stream.clone(), Offset::new(1)),
                LineageMetadata::new(
                    Some("test.classifier".into()),
                    Some("branch-after-second".into()),
                ),
            )
            .expect("create branch");
        let branch_append = client
            .append(&branch_stream, b"branch-only")
            .expect("append branch");

        assert_eq!(first.position().offset.value(), 0);
        assert_eq!(second.position().offset.value(), 1);
        assert_eq!(branch_append.position().offset.value(), 2);

        let root_read = client.read(&root_stream).expect("read root");
        let branch_read = client.read(&branch_stream).expect("read branch");
        let root_tail = client
            .tail(&root_stream, Offset::new(1))
            .expect("tail root");

        let root_offsets: Vec<u64> = root_read
            .records()
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let branch_offsets: Vec<u64> = branch_read
            .records()
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let branch_payloads: Vec<&[u8]> = branch_read
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();
        let tail_payloads: Vec<&[u8]> = root_tail
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();

        assert_eq!(root_offsets, vec![0, 1]);
        assert_eq!(branch_offsets, vec![0, 1, 2]);
        assert_eq!(
            branch_payloads,
            vec![
                b"first".as_slice(),
                b"second".as_slice(),
                b"branch-only".as_slice()
            ]
        );
        assert_eq!(tail_payloads, vec![b"second".as_slice()]);
        assert_eq!(root_read.durability(), "local");
        assert_eq!(branch_read.durability(), "local");
        assert_eq!(root_tail.durability(), "local");

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_append_and_read_surface_explicit_durability_and_error_information() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path()),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let client = RemoteClient::new(server.local_addr());
        let root_stream = stream_id("task.root");
        let missing_stream = stream_id("task.missing");

        let missing_read = client
            .read(&missing_stream)
            .expect_err("missing read should fail");
        match missing_read {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::NotFound);
                assert!(error.message().contains("task.missing"));
            }
            other => panic!("expected remote error, got {other:?}"),
        }

        server
            .engine()
            .create_stream(root_descriptor("task.root"))
            .expect("create root");

        let append = client.append(&root_stream, b"first").expect("append");
        let read = client.read(&root_stream).expect("read");
        let missing_append = client
            .append(&missing_stream, b"payload")
            .expect_err("missing append should fail");

        assert_eq!(append.durability(), "local");
        assert_eq!(append.manifest_generation(), 0);
        assert_eq!(read.durability(), "local");
        assert_eq!(read.records().len(), 1);

        match missing_append {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::NotFound);
                assert!(error.message().contains("task.missing"));
            }
            other => panic!("expected remote error, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_tail_is_snapshot_based_with_explicit_lifecycle_and_durability_boundaries() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path()),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let client = RemoteClient::new(server.local_addr());
        let root_stream = stream_id("task.root");

        server
            .engine()
            .create_stream(root_descriptor("task.root"))
            .expect("create root");
        client.append(&root_stream, b"first").expect("append first");
        client
            .append(&root_stream, b"second")
            .expect("append second");
        client.append(&root_stream, b"third").expect("append third");

        let initial_tail = client.tail(&root_stream, Offset::new(1)).expect("tail");
        client
            .append(&root_stream, b"fourth")
            .expect("append fourth after tail");
        let follow_up_tail = client
            .tail(&root_stream, Offset::new(3))
            .expect("tail again");

        let initial_payloads: Vec<&[u8]> = initial_tail
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();
        let follow_up_payloads: Vec<&[u8]> = follow_up_tail
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();

        assert_eq!(
            initial_payloads,
            vec![b"second".as_slice(), b"third".as_slice()]
        );
        assert_eq!(follow_up_payloads, vec![b"fourth".as_slice()]);
        assert_eq!(initial_tail.durability(), "local");
        assert_eq!(follow_up_tail.durability(), "local");

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_branch_creation_uses_explicit_parent_positions_and_preserves_lineage() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(8)
                .expect("config"),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let client = RemoteClient::new(server.local_addr());
        let engine = server.engine();
        let root_stream = stream_id("task.root");
        let branch_stream = stream_id("task.root.thread");

        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create root stream");
        client.append(&root_stream, b"first").expect("append first");
        client
            .append(&root_stream, b"second")
            .expect("append second");

        let branch_status = client
            .create_branch(
                &branch_stream,
                StreamPosition::new(root_stream.clone(), Offset::new(1)),
                LineageMetadata::new(
                    Some("classifier.thread-boundary".into()),
                    Some("remote-thread-split".into()),
                )
                .with_label("anchor_message_id", "msg-42"),
            )
            .expect("create remote branch");
        let branch_append = client
            .append(&branch_stream, b"branch-only")
            .expect("append branch");
        let lineage = client
            .inspect_lineage(&branch_stream)
            .expect("inspect branch lineage");
        let branch_read = client.read(&branch_stream).expect("read branch");

        assert_eq!(branch_status.stream_id(), &branch_stream);
        assert_eq!(branch_status.durability(), "local");
        assert_eq!(branch_status.next_offset().value(), 2);
        assert_eq!(branch_append.position().offset.value(), 2);
        assert_eq!(lineage.topology(), RemoteTopology::SingleNode);
        assert_eq!(lineage.status().stream_id(), &branch_stream);
        assert_eq!(lineage.status().next_offset().value(), 3);

        match &lineage.descriptor().lineage {
            StreamLineage::Branch { branch_point } => {
                assert_eq!(branch_point.parent.stream_id, root_stream);
                assert_eq!(branch_point.parent.offset.value(), 1);
                assert_eq!(
                    branch_point.metadata.labels.get("anchor_message_id"),
                    Some(&"msg-42".to_owned())
                );
            }
            other => panic!("expected branch lineage, got {other:?}"),
        }

        let payloads: Vec<&[u8]> = branch_read
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();
        assert_eq!(
            payloads,
            vec![
                b"first".as_slice(),
                b"second".as_slice(),
                b"branch-only".as_slice()
            ]
        );

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_merge_and_lineage_inspection_remain_explicitly_single_node() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path())
                .with_segment_max_records(8)
                .expect("config"),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let client = RemoteClient::new(server.local_addr());
        let engine = server.engine();
        let root_stream = stream_id("task.root");
        let branch_a = stream_id("task.root.retry");
        let branch_b = stream_id("task.root.critique");
        let merge_stream = stream_id("task.root.merge");

        engine
            .create_stream(root_descriptor("task.root"))
            .expect("create root stream");
        client.append(&root_stream, b"seed").expect("append root");
        client
            .create_branch(
                &branch_a,
                StreamPosition::new(root_stream.clone(), Offset::new(0)),
                LineageMetadata::new(Some("agent.retry".into()), Some("explore".into())),
            )
            .expect("create branch a");
        client
            .create_branch(
                &branch_b,
                StreamPosition::new(root_stream.clone(), Offset::new(0)),
                LineageMetadata::new(Some("agent.critique".into()), Some("explore".into())),
            )
            .expect("create branch b");
        client.append(&branch_a, b"retry").expect("append branch a");
        client
            .append(&branch_b, b"critique")
            .expect("append branch b");

        let merge_spec = MergeSpec::new(
            vec![
                StreamPosition::new(branch_a.clone(), Offset::new(1)),
                StreamPosition::new(branch_b.clone(), Offset::new(1)),
            ],
            Some(StreamPosition::new(root_stream.clone(), Offset::new(0))),
            MergePolicy::new(MergePolicyKind::Recursive).with_metadata("resolver", "judge-v1"),
            LineageMetadata::new(Some("agent.judge".into()), Some("merge".into())),
        )
        .expect("merge spec");

        let merge_status = client
            .create_merge(&merge_stream, merge_spec.clone())
            .expect("create merge");
        let lineage = client
            .inspect_lineage(&merge_stream)
            .expect("inspect merge lineage");

        assert_eq!(merge_status.stream_id(), &merge_stream);
        assert_eq!(merge_status.durability(), "local");
        assert_eq!(merge_status.next_offset().value(), 1);
        assert_eq!(lineage.topology(), RemoteTopology::SingleNode);

        match &lineage.descriptor().lineage {
            StreamLineage::Merge { merge } => assert_eq!(merge, &merge_spec),
            other => panic!("expected merge lineage, got {other:?}"),
        }

        let encoded = serde_json::to_value(&lineage).expect("encode lineage");
        assert_eq!(
            encoded.get("topology").and_then(Value::as_str),
            Some("single_node")
        );
        assert!(encoded.get("replication").is_none());
        assert!(encoded.get("leader").is_none());
        assert!(encoded.get("quorum").is_none());

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_lineage_validation_errors_surface_as_invalid_requests() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path()),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let client = RemoteClient::new(server.local_addr());
        let root_stream = stream_id("task.root");
        let invalid_branch = stream_id("task.root.invalid");

        server
            .engine()
            .create_stream(root_descriptor("task.root"))
            .expect("create root");
        client.append(&root_stream, b"first").expect("append root");

        let error = client
            .create_branch(
                &invalid_branch,
                StreamPosition::new(root_stream.clone(), Offset::new(4)),
                LineageMetadata::new(Some("classifier".into()), Some("invalid-branch".into())),
            )
            .expect_err("invalid branch should fail");

        match error {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::InvalidRequest);
                assert!(error.message().contains("lineage position"));
            }
            other => panic!("expected remote invalid_request, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_lineage_inspection_declares_single_node_topology_without_replication_fields() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path()),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let client = RemoteClient::new(server.local_addr());
        let root_stream = stream_id("task.root");

        server
            .engine()
            .create_stream(root_descriptor("task.root"))
            .expect("create root");

        let lineage = client
            .inspect_lineage(&root_stream)
            .expect("inspect root lineage");
        let encoded = serde_json::to_value(&lineage).expect("encode lineage");

        assert_eq!(lineage.topology(), RemoteTopology::SingleNode);
        assert_eq!(
            encoded.get("topology").and_then(Value::as_str),
            Some("single_node")
        );
        assert!(encoded.get("replication").is_none());
        assert!(encoded.get("leader").is_none());
        assert!(encoded.get("quorum").is_none());

        server.shutdown().expect("shutdown server");
    }
}
