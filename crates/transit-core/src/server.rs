use crate::engine::{
    DurabilityMode, LocalAppendOutcome, LocalEngine, LocalEngineConfig, LocalRecord,
    LocalStreamStatus,
};
use crate::kernel::{
    LineageMetadata, MergeSpec, Offset, StreamDescriptor, StreamId, StreamPosition,
};
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
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
const MAX_TAIL_SESSION_CREDIT: u64 = 256;

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
        let tail_sessions = Arc::new(Mutex::new(TailSessionRegistry::default()));

        let thread_engine = engine.clone();
        let thread_shutdown = Arc::clone(&shutdown_requested);
        let thread_connections = Arc::clone(&accepted_connections);
        let thread_error = Arc::clone(&fatal_error);
        let thread_tail_sessions = Arc::clone(&tail_sessions);
        let accept_poll_interval = config.accept_poll_interval();
        let connection_io_timeout = config.connection_io_timeout();
        let listener_thread = thread::Builder::new()
            .name("transit-server-listener".into())
            .spawn(move || {
                run_accept_loop(
                    listener,
                    AcceptLoopContext {
                        engine: thread_engine,
                        shutdown_requested: thread_shutdown,
                        accepted_connections: thread_connections,
                        fatal_error: thread_error,
                        tail_sessions: thread_tail_sessions,
                        accept_poll_interval,
                        connection_io_timeout,
                    },
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RequestId(String);

impl RequestId {
    pub fn new(value: impl Into<String>) -> Result<Self> {
        let value = value.into();
        if value.trim().is_empty() {
            anyhow::bail!("request ids must not be empty");
        }
        Ok(Self(value))
    }

    fn from_sequence(sequence: u64) -> Self {
        Self(format!("req-{sequence}"))
    }

    fn server_generated(suffix: &str) -> Self {
        Self(format!("server-{suffix}"))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RemoteTopology {
    SingleNode,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteAcknowledgement {
    durability: String,
    topology: RemoteTopology,
}

impl RemoteAcknowledgement {
    pub fn durability(&self) -> &str {
        &self.durability
    }

    pub fn topology(&self) -> RemoteTopology {
        self.topology
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RemoteAcknowledged<T> {
    request_id: RequestId,
    ack: RemoteAcknowledgement,
    body: T,
}

impl<T> RemoteAcknowledged<T> {
    fn new(request_id: RequestId, ack: RemoteAcknowledgement, body: T) -> Self {
        Self {
            request_id,
            ack,
            body,
        }
    }

    pub fn request_id(&self) -> &RequestId {
        &self.request_id
    }

    pub fn ack(&self) -> &RemoteAcknowledgement {
        &self.ack
    }

    pub fn body(&self) -> &T {
        &self.body
    }

    pub fn into_body(self) -> T {
        self.body
    }
}

#[derive(Debug, Clone)]
pub struct RemoteClient {
    server_addr: SocketAddr,
    io_timeout: Duration,
    request_sequence: Arc<AtomicU64>,
}

impl RemoteClient {
    pub fn new(server_addr: SocketAddr) -> Self {
        Self {
            server_addr,
            io_timeout: Duration::from_millis(DEFAULT_CONNECTION_IO_TIMEOUT_MS),
            request_sequence: Arc::new(AtomicU64::new(1)),
        }
    }

    pub fn append(
        &self,
        stream_id: &StreamId,
        payload: impl AsRef<[u8]>,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteAppendOutcome>> {
        match self.send_request(OperationRequest::Append {
            stream_id: stream_id.clone(),
            payload: payload.as_ref().to_vec(),
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::AppendOk(outcome),
            } => Ok(RemoteAcknowledged::new(request_id, ack, outcome)),
            other => Err(unexpected_operation_response("append", &other.outcome)),
        }
    }

    pub fn create_root(
        &self,
        stream_id: &StreamId,
        metadata: LineageMetadata,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteStreamStatus>> {
        match self.send_request(OperationRequest::CreateRoot {
            stream_id: stream_id.clone(),
            metadata,
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::StreamStatusOk(status),
            } => Ok(RemoteAcknowledged::new(request_id, ack, status)),
            other => Err(unexpected_operation_response("create_root", &other.outcome)),
        }
    }

    pub fn read(
        &self,
        stream_id: &StreamId,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteReadOutcome>> {
        match self.send_request(OperationRequest::Read {
            stream_id: stream_id.clone(),
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::RecordsOk(outcome),
            } => Ok(RemoteAcknowledged::new(request_id, ack, outcome)),
            other => Err(unexpected_operation_response("read", &other.outcome)),
        }
    }

    pub fn tail(
        &self,
        stream_id: &StreamId,
        from_offset: Offset,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteReadOutcome>> {
        match self.send_request(OperationRequest::Tail {
            stream_id: stream_id.clone(),
            from_offset,
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::RecordsOk(outcome),
            } => Ok(RemoteAcknowledged::new(request_id, ack, outcome)),
            other => Err(unexpected_operation_response("tail", &other.outcome)),
        }
    }

    pub fn open_tail_session(
        &self,
        stream_id: &StreamId,
        from_offset: Offset,
        initial_credit: u64,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteTailSessionOpened>> {
        match self.send_request(OperationRequest::OpenTailSession {
            stream_id: stream_id.clone(),
            from_offset,
            initial_credit,
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::TailSessionOpened(opened),
            } => Ok(RemoteAcknowledged::new(request_id, ack, opened)),
            other => Err(unexpected_operation_response(
                "open_tail_session",
                &other.outcome,
            )),
        }
    }

    pub fn poll_tail_session(
        &self,
        session_id: &TailSessionId,
        credit: u64,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteTailBatch>> {
        match self.send_request(OperationRequest::PollTailSession {
            session_id: session_id.clone(),
            credit,
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::TailBatchOk(batch),
            } => Ok(RemoteAcknowledged::new(request_id, ack, batch)),
            other => Err(unexpected_operation_response(
                "poll_tail_session",
                &other.outcome,
            )),
        }
    }

    pub fn cancel_tail_session(
        &self,
        session_id: &TailSessionId,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteTailSessionCancelled>> {
        match self.send_request(OperationRequest::CancelTailSession {
            session_id: session_id.clone(),
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::TailSessionCancelled(cancelled),
            } => Ok(RemoteAcknowledged::new(request_id, ack, cancelled)),
            other => Err(unexpected_operation_response(
                "cancel_tail_session",
                &other.outcome,
            )),
        }
    }

    pub fn create_branch(
        &self,
        stream_id: &StreamId,
        parent: StreamPosition,
        metadata: LineageMetadata,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteStreamStatus>> {
        match self.send_request(OperationRequest::CreateBranch {
            stream_id: stream_id.clone(),
            parent,
            metadata,
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::StreamStatusOk(status),
            } => Ok(RemoteAcknowledged::new(request_id, ack, status)),
            other => Err(unexpected_operation_response(
                "create_branch",
                &other.outcome,
            )),
        }
    }

    pub fn create_merge(
        &self,
        stream_id: &StreamId,
        merge: MergeSpec,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteStreamStatus>> {
        match self.send_request(OperationRequest::CreateMerge {
            stream_id: stream_id.clone(),
            merge,
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::StreamStatusOk(status),
            } => Ok(RemoteAcknowledged::new(request_id, ack, status)),
            other => Err(unexpected_operation_response(
                "create_merge",
                &other.outcome,
            )),
        }
    }

    pub fn inspect_lineage(
        &self,
        stream_id: &StreamId,
    ) -> RemoteClientResult<RemoteAcknowledged<RemoteLineageOutcome>> {
        match self.send_request(OperationRequest::InspectLineage {
            stream_id: stream_id.clone(),
        })? {
            SuccessfulResponse {
                request_id,
                ack,
                outcome: OperationResponse::LineageOk(lineage),
            } => Ok(RemoteAcknowledged::new(request_id, ack, lineage)),
            other => Err(unexpected_operation_response(
                "inspect_lineage",
                &other.outcome,
            )),
        }
    }

    fn send_request(&self, operation: OperationRequest) -> RemoteClientResult<SuccessfulResponse> {
        let request_id = self.next_request_id();
        let request = ProtocolRequest {
            request_id: request_id.clone(),
            operation,
        };
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

        let mut encoded = serde_json::to_vec(&request).map_err(|error| {
            RemoteClientError::Protocol(format!("encode request {}: {error}", request_id.as_str()))
        })?;
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

        let response: ProtocolResponse = serde_json::from_str(response_line.trim_end())
            .map_err(|error| RemoteClientError::Decode(format!("decode response: {error}")))?;
        if response.request_id != request_id {
            return Err(RemoteClientError::Protocol(format!(
                "response request_id '{}' did not match request '{}'",
                response.request_id.as_str(),
                request_id.as_str()
            )));
        }

        match response.envelope {
            ResponseEnvelope::Ack { ack, outcome } => Ok(SuccessfulResponse {
                request_id,
                ack,
                outcome: *outcome,
            }),
            ResponseEnvelope::Error { error } => Err(RemoteClientError::Remote(
                RemoteErrorResponse::new(request_id, error),
            )),
        }
    }

    fn next_request_id(&self) -> RequestId {
        RequestId::from_sequence(self.request_sequence.fetch_add(1, Ordering::AcqRel))
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
            Self::Remote(error) => write!(
                f,
                "remote error [{} {}]: {}",
                error.request_id().as_str(),
                error.code(),
                error.message()
            ),
        }
    }
}

impl std::error::Error for RemoteClientError {}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteAppendOutcome {
    position: StreamPosition,
    manifest_generation: u64,
    rolled_segment_id: Option<String>,
}

impl RemoteAppendOutcome {
    pub fn position(&self) -> &StreamPosition {
        &self.position
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
    records: Vec<RemoteRecord>,
}

impl RemoteReadOutcome {
    pub fn stream_id(&self) -> &StreamId {
        &self.stream_id
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
}

impl RemoteLineageOutcome {
    pub fn descriptor(&self) -> &StreamDescriptor {
        &self.descriptor
    }

    pub fn status(&self) -> &RemoteStreamStatus {
        &self.status
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RemoteErrorResponse {
    request_id: RequestId,
    topology: RemoteTopology,
    code: RemoteErrorCode,
    message: String,
}

impl RemoteErrorResponse {
    fn new(request_id: RequestId, error: ProtocolErrorResponse) -> Self {
        Self {
            request_id,
            topology: error.topology,
            code: error.code,
            message: error.message,
        }
    }

    pub fn request_id(&self) -> &RequestId {
        &self.request_id
    }

    pub fn topology(&self) -> RemoteTopology {
        self.topology
    }

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
struct ProtocolRequest {
    request_id: RequestId,
    operation: OperationRequest,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum OperationRequest {
    Append {
        stream_id: StreamId,
        payload: Vec<u8>,
    },
    CreateRoot {
        stream_id: StreamId,
        metadata: LineageMetadata,
    },
    OpenTailSession {
        stream_id: StreamId,
        from_offset: Offset,
        initial_credit: u64,
    },
    PollTailSession {
        session_id: TailSessionId,
        credit: u64,
    },
    CancelTailSession {
        session_id: TailSessionId,
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
struct ProtocolResponse {
    request_id: RequestId,
    envelope: ResponseEnvelope,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
enum ResponseEnvelope {
    Ack {
        ack: RemoteAcknowledgement,
        outcome: Box<OperationResponse>,
    },
    Error {
        error: ProtocolErrorResponse,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum OperationResponse {
    AppendOk(RemoteAppendOutcome),
    RecordsOk(RemoteReadOutcome),
    TailSessionOpened(RemoteTailSessionOpened),
    TailBatchOk(RemoteTailBatch),
    TailSessionCancelled(RemoteTailSessionCancelled),
    StreamStatusOk(RemoteStreamStatus),
    LineageOk(RemoteLineageOutcome),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
struct ProtocolErrorResponse {
    topology: RemoteTopology,
    code: RemoteErrorCode,
    message: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct SuccessfulResponse {
    request_id: RequestId,
    ack: RemoteAcknowledgement,
    outcome: OperationResponse,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct TailSessionId(String);

impl TailSessionId {
    pub fn new(value: impl Into<String>) -> Result<Self> {
        let value = value.into();
        if value.trim().is_empty() {
            anyhow::bail!("tail session ids must not be empty");
        }
        Ok(Self(value))
    }

    fn from_sequence(sequence: u64) -> Self {
        Self(format!("tail-{sequence}"))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteTailSessionOpened {
    session_id: TailSessionId,
    stream_id: StreamId,
    next_offset: Offset,
    requested_credit: u64,
    delivered_credit: u64,
    records: Vec<RemoteRecord>,
    state: RemoteTailSessionState,
    max_credit: u64,
}

impl RemoteTailSessionOpened {
    pub fn session_id(&self) -> &TailSessionId {
        &self.session_id
    }

    pub fn stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    pub fn next_offset(&self) -> Offset {
        self.next_offset
    }

    pub fn requested_credit(&self) -> u64 {
        self.requested_credit
    }

    pub fn delivered_credit(&self) -> u64 {
        self.delivered_credit
    }

    pub fn records(&self) -> &[RemoteRecord] {
        &self.records
    }

    pub fn state(&self) -> RemoteTailSessionState {
        self.state
    }

    pub fn max_credit(&self) -> u64 {
        self.max_credit
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteTailBatch {
    session_id: TailSessionId,
    stream_id: StreamId,
    next_offset: Offset,
    requested_credit: u64,
    delivered_credit: u64,
    records: Vec<RemoteRecord>,
    state: RemoteTailSessionState,
}

impl RemoteTailBatch {
    pub fn session_id(&self) -> &TailSessionId {
        &self.session_id
    }

    pub fn stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    pub fn next_offset(&self) -> Offset {
        self.next_offset
    }

    pub fn requested_credit(&self) -> u64 {
        self.requested_credit
    }

    pub fn delivered_credit(&self) -> u64 {
        self.delivered_credit
    }

    pub fn records(&self) -> &[RemoteRecord] {
        &self.records
    }

    pub fn state(&self) -> RemoteTailSessionState {
        self.state
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteTailSessionCancelled {
    session_id: TailSessionId,
    stream_id: StreamId,
    next_offset: Offset,
    state: RemoteTailSessionState,
}

impl RemoteTailSessionCancelled {
    pub fn session_id(&self) -> &TailSessionId {
        &self.session_id
    }

    pub fn stream_id(&self) -> &StreamId {
        &self.stream_id
    }

    pub fn next_offset(&self) -> Offset {
        self.next_offset
    }

    pub fn state(&self) -> RemoteTailSessionState {
        self.state
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RemoteTailSessionState {
    Active,
    AwaitingRecords,
    Cancelled,
}

#[derive(Debug, Clone)]
struct TailSessionState {
    stream_id: StreamId,
    next_offset: Offset,
}

#[derive(Debug, Clone)]
struct AcceptLoopContext {
    engine: LocalEngine,
    shutdown_requested: Arc<AtomicBool>,
    accepted_connections: Arc<AtomicU64>,
    fatal_error: Arc<Mutex<Option<String>>>,
    tail_sessions: Arc<Mutex<TailSessionRegistry>>,
    accept_poll_interval: Duration,
    connection_io_timeout: Duration,
}

#[derive(Debug, Default)]
struct TailSessionRegistry {
    next_session_sequence: u64,
    sessions: BTreeMap<TailSessionId, TailSessionState>,
}

fn run_accept_loop(listener: TcpListener, context: AcceptLoopContext) {
    loop {
        if context.shutdown_requested.load(Ordering::Acquire) {
            break;
        }

        match listener.accept() {
            Ok((stream, _peer_addr)) => {
                if context.shutdown_requested.load(Ordering::Acquire) {
                    let _ = stream.shutdown(Shutdown::Both);
                    break;
                }

                context.accepted_connections.fetch_add(1, Ordering::AcqRel);
                serve_connection(
                    stream,
                    &context.engine,
                    &context.tail_sessions,
                    context.connection_io_timeout,
                );
            }
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                thread::sleep(context.accept_poll_interval);
            }
            Err(error) => {
                *context
                    .fatal_error
                    .lock()
                    .expect("listener fatal_error mutex poisoned") =
                    Some(format!("server listener failure: {error}"));
                break;
            }
        }
    }
}

fn serve_connection(
    mut stream: TcpStream,
    engine: &LocalEngine,
    tail_sessions: &Arc<Mutex<TailSessionRegistry>>,
    io_timeout: Duration,
) {
    let response = match configure_connection_stream(&stream, io_timeout) {
        Ok(()) => match read_request(&mut stream) {
            Ok(request) => handle_request(engine, tail_sessions, request),
            Err(error) => invalid_request_response(RequestId::server_generated("decode"), error),
        },
        Err(error) => internal_error_response(
            RequestId::server_generated("configure"),
            format!("configure connection: {error}"),
        ),
    };

    let _ = write_response(&mut stream, &response);
}

fn configure_connection_stream(stream: &TcpStream, io_timeout: Duration) -> std::io::Result<()> {
    stream.set_nodelay(true)?;
    stream.set_read_timeout(Some(io_timeout))?;
    stream.set_write_timeout(Some(io_timeout))?;
    Ok(())
}

fn read_request(stream: &mut TcpStream) -> Result<ProtocolRequest> {
    let mut request_line = String::new();
    {
        let mut reader = BufReader::new(stream);
        reader
            .read_line(&mut request_line)
            .context("read request line from client")?;
    }

    ensure_request_line(&request_line)?;
    let request: ProtocolRequest =
        serde_json::from_str(request_line.trim_end()).context("decode client request")?;
    ensure_request_id(&request.request_id)?;
    Ok(request)
}

fn ensure_request_line(request_line: &str) -> Result<()> {
    if request_line.trim().is_empty() {
        anyhow::bail!("client request line must not be empty");
    }
    Ok(())
}

fn ensure_request_id(request_id: &RequestId) -> Result<()> {
    if request_id.as_str().trim().is_empty() {
        anyhow::bail!("request ids must not be empty");
    }
    Ok(())
}

fn write_response(stream: &mut TcpStream, response: &ProtocolResponse) -> std::io::Result<()> {
    let mut encoded = serde_json::to_vec(response).map_err(std::io::Error::other)?;
    encoded.push(b'\n');

    let mut writer = BufWriter::new(stream);
    writer.write_all(&encoded)?;
    writer.flush()?;
    Ok(())
}

fn handle_request(
    engine: &LocalEngine,
    tail_sessions: &Arc<Mutex<TailSessionRegistry>>,
    request: ProtocolRequest,
) -> ProtocolResponse {
    let request_id = request.request_id;
    match request.operation {
        OperationRequest::Append { stream_id, payload } => match engine.append(&stream_id, payload)
        {
            Ok(outcome) => ack_response(
                request_id,
                engine.durability(),
                OperationResponse::AppendOk(map_append_outcome(outcome)),
            ),
            Err(error) => engine_error_response(request_id, error),
        },
        OperationRequest::CreateRoot {
            stream_id,
            metadata,
        } => match engine.create_stream(StreamDescriptor::root(stream_id, metadata)) {
            Ok(status) => ack_response(
                request_id,
                engine.durability(),
                OperationResponse::StreamStatusOk(map_stream_status(status)),
            ),
            Err(error) => engine_error_response(request_id, error),
        },
        OperationRequest::OpenTailSession {
            stream_id,
            from_offset,
            initial_credit,
        } => match open_tail_session(
            engine,
            tail_sessions,
            &stream_id,
            from_offset,
            initial_credit,
        ) {
            Ok(opened) => ack_response(
                request_id,
                engine.durability(),
                OperationResponse::TailSessionOpened(opened),
            ),
            Err(error) => engine_error_response(request_id, error),
        },
        OperationRequest::PollTailSession { session_id, credit } => {
            match poll_tail_session(engine, tail_sessions, &session_id, credit) {
                Ok(batch) => ack_response(
                    request_id,
                    engine.durability(),
                    OperationResponse::TailBatchOk(batch),
                ),
                Err(error) => engine_error_response(request_id, error),
            }
        }
        OperationRequest::CancelTailSession { session_id } => {
            match cancel_tail_session(tail_sessions, &session_id) {
                Ok(cancelled) => ack_response(
                    request_id,
                    engine.durability(),
                    OperationResponse::TailSessionCancelled(cancelled),
                ),
                Err(error) => engine_error_response(request_id, error),
            }
        }
        OperationRequest::CreateBranch {
            stream_id,
            parent,
            metadata,
        } => match engine.create_branch(stream_id, parent, metadata) {
            Ok(status) => ack_response(
                request_id,
                engine.durability(),
                OperationResponse::StreamStatusOk(map_stream_status(status)),
            ),
            Err(error) => engine_error_response(request_id, error),
        },
        OperationRequest::CreateMerge { stream_id, merge } => {
            match engine.create_merge(stream_id, merge) {
                Ok(status) => ack_response(
                    request_id,
                    engine.durability(),
                    OperationResponse::StreamStatusOk(map_stream_status(status)),
                ),
                Err(error) => engine_error_response(request_id, error),
            }
        }
        OperationRequest::InspectLineage { stream_id } => match inspect_lineage(engine, &stream_id)
        {
            Ok(lineage) => ack_response(
                request_id,
                engine.durability(),
                OperationResponse::LineageOk(lineage),
            ),
            Err(error) => engine_error_response(request_id, error),
        },
        OperationRequest::Read { stream_id } => match engine.replay(&stream_id) {
            Ok(records) => ack_response(
                request_id,
                engine.durability(),
                OperationResponse::RecordsOk(map_read_outcome(stream_id, records)),
            ),
            Err(error) => engine_error_response(request_id, error),
        },
        OperationRequest::Tail {
            stream_id,
            from_offset,
        } => match engine.tail_from(&stream_id, from_offset) {
            Ok(records) => ack_response(
                request_id,
                engine.durability(),
                OperationResponse::RecordsOk(map_read_outcome(stream_id, records)),
            ),
            Err(error) => engine_error_response(request_id, error),
        },
    }
}

fn map_append_outcome(outcome: LocalAppendOutcome) -> RemoteAppendOutcome {
    RemoteAppendOutcome {
        position: outcome.position().clone(),
        manifest_generation: outcome.manifest_generation(),
        rolled_segment_id: outcome
            .rolled_segment()
            .map(|segment| segment.segment_id().as_str().to_owned()),
    }
}

fn map_read_outcome(stream_id: StreamId, records: Vec<LocalRecord>) -> RemoteReadOutcome {
    RemoteReadOutcome {
        stream_id,
        records: records.into_iter().map(map_record).collect(),
    }
}

fn map_stream_status(status: LocalStreamStatus) -> RemoteStreamStatus {
    RemoteStreamStatus {
        stream_id: status.stream_id().clone(),
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
        status: map_stream_status(status),
    })
}

fn open_tail_session(
    engine: &LocalEngine,
    tail_sessions: &Arc<Mutex<TailSessionRegistry>>,
    stream_id: &StreamId,
    from_offset: Offset,
    initial_credit: u64,
) -> Result<RemoteTailSessionOpened> {
    validate_tail_credit(initial_credit)?;
    let status = engine.stream_status(stream_id)?;
    ensure!(
        from_offset.value() <= status.next_offset().value(),
        "tail session start {}:{} is beyond committed head {}",
        stream_id.as_str(),
        from_offset.value(),
        status.next_offset().value()
    );

    let session_id = {
        let mut registry = tail_sessions
            .lock()
            .expect("tail session registry mutex poisoned");
        registry.next_session_sequence += 1;
        let session_id = TailSessionId::from_sequence(registry.next_session_sequence);
        registry.sessions.insert(
            session_id.clone(),
            TailSessionState {
                stream_id: stream_id.clone(),
                next_offset: from_offset,
            },
        );
        session_id
    };

    let batch = deliver_tail_batch(engine, tail_sessions, &session_id, initial_credit)?;
    Ok(RemoteTailSessionOpened {
        session_id: batch.session_id,
        stream_id: batch.stream_id,
        next_offset: batch.next_offset,
        requested_credit: batch.requested_credit,
        delivered_credit: batch.delivered_credit,
        records: batch.records,
        state: batch.state,
        max_credit: MAX_TAIL_SESSION_CREDIT,
    })
}

fn poll_tail_session(
    engine: &LocalEngine,
    tail_sessions: &Arc<Mutex<TailSessionRegistry>>,
    session_id: &TailSessionId,
    credit: u64,
) -> Result<RemoteTailBatch> {
    validate_tail_credit(credit)?;
    deliver_tail_batch(engine, tail_sessions, session_id, credit)
}

fn cancel_tail_session(
    tail_sessions: &Arc<Mutex<TailSessionRegistry>>,
    session_id: &TailSessionId,
) -> Result<RemoteTailSessionCancelled> {
    let state = tail_sessions
        .lock()
        .expect("tail session registry mutex poisoned")
        .sessions
        .remove(session_id)
        .ok_or_else(|| tail_session_not_found(session_id))?;

    Ok(RemoteTailSessionCancelled {
        session_id: session_id.clone(),
        stream_id: state.stream_id,
        next_offset: state.next_offset,
        state: RemoteTailSessionState::Cancelled,
    })
}

fn deliver_tail_batch(
    engine: &LocalEngine,
    tail_sessions: &Arc<Mutex<TailSessionRegistry>>,
    session_id: &TailSessionId,
    credit: u64,
) -> Result<RemoteTailBatch> {
    let (stream_id, next_offset) = {
        let registry = tail_sessions
            .lock()
            .expect("tail session registry mutex poisoned");
        let state = registry
            .sessions
            .get(session_id)
            .ok_or_else(|| tail_session_not_found(session_id))?;
        (state.stream_id.clone(), state.next_offset)
    };

    let records = engine.tail_from(&stream_id, next_offset)?;
    let delivered_count = records.len().min(credit as usize);
    let delivered_records: Vec<LocalRecord> = records.into_iter().take(delivered_count).collect();
    let next_offset_value = delivered_records
        .last()
        .map(|record| record.position().offset.value() + 1)
        .unwrap_or(next_offset.value());
    let state = if delivered_count == 0 {
        RemoteTailSessionState::AwaitingRecords
    } else {
        RemoteTailSessionState::Active
    };

    {
        let mut registry = tail_sessions
            .lock()
            .expect("tail session registry mutex poisoned");
        let session = registry
            .sessions
            .get_mut(session_id)
            .ok_or_else(|| tail_session_not_found(session_id))?;
        session.next_offset = Offset::new(next_offset_value);
    }

    Ok(RemoteTailBatch {
        session_id: session_id.clone(),
        stream_id,
        next_offset: Offset::new(next_offset_value),
        requested_credit: credit,
        delivered_credit: delivered_count as u64,
        records: delivered_records.into_iter().map(map_record).collect(),
        state,
    })
}

fn validate_tail_credit(credit: u64) -> Result<()> {
    ensure!(credit > 0, "tail session credit must be greater than zero");
    ensure!(
        credit <= MAX_TAIL_SESSION_CREDIT,
        "tail session credit {} exceeds max {}",
        credit,
        MAX_TAIL_SESSION_CREDIT
    );
    Ok(())
}

fn tail_session_not_found(session_id: &TailSessionId) -> anyhow::Error {
    std::io::Error::new(
        std::io::ErrorKind::NotFound,
        format!("tail session '{}' not found", session_id.as_str()),
    )
    .into()
}

fn map_record(record: LocalRecord) -> RemoteRecord {
    RemoteRecord {
        position: record.position().clone(),
        payload: record.payload().to_vec(),
    }
}

fn ack_response(
    request_id: RequestId,
    durability: DurabilityMode,
    outcome: OperationResponse,
) -> ProtocolResponse {
    ProtocolResponse {
        request_id,
        envelope: ResponseEnvelope::Ack {
            ack: RemoteAcknowledgement {
                durability: durability.as_str().to_owned(),
                topology: RemoteTopology::SingleNode,
            },
            outcome: Box::new(outcome),
        },
    }
}

fn invalid_request_response(request_id: RequestId, error: anyhow::Error) -> ProtocolResponse {
    error_response(
        request_id,
        RemoteErrorCode::InvalidRequest,
        error.to_string(),
    )
}

fn internal_error_response(request_id: RequestId, message: String) -> ProtocolResponse {
    error_response(request_id, RemoteErrorCode::Internal, message)
}

fn engine_error_response(request_id: RequestId, error: anyhow::Error) -> ProtocolResponse {
    error_response(request_id, classify_engine_error(&error), error.to_string())
}

fn error_response(
    request_id: RequestId,
    code: RemoteErrorCode,
    message: String,
) -> ProtocolResponse {
    ProtocolResponse {
        request_id,
        envelope: ResponseEnvelope::Error {
            error: ProtocolErrorResponse {
                topology: RemoteTopology::SingleNode,
                code,
                message,
            },
        },
    }
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
        "tail session start",
        "tail session credit",
        "already exists",
    ]
    .into_iter()
    .any(|pattern| message.contains(pattern))
}

fn unexpected_operation_response(
    operation: &str,
    outcome: &OperationResponse,
) -> RemoteClientError {
    RemoteClientError::Protocol(format!(
        "{operation} expected a different response envelope, got {outcome:?}"
    ))
}

#[cfg(test)]
mod tests {
    use super::{
        OperationRequest, OperationResponse, ProtocolRequest, ProtocolResponse, RemoteClient,
        RemoteClientError, RemoteErrorCode, RemoteTailSessionState, RemoteTopology, RequestId,
        ResponseEnvelope, ServerConfig, ServerHandle, configure_connection_stream,
    };
    use crate::engine::{DurabilityMode, LocalEngine, LocalEngineConfig};
    use crate::kernel::{
        LineageMetadata, MergePolicy, MergePolicyKind, MergeSpec, Offset, StreamDescriptor,
        StreamId, StreamLineage, StreamPosition,
    };
    use serde_json::Value;
    use std::io::{BufRead, BufReader, Write};
    use std::net::{SocketAddr, TcpStream};
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

    fn send_protocol_request(
        server_addr: SocketAddr,
        request: ProtocolRequest,
    ) -> ProtocolResponse {
        let mut stream =
            TcpStream::connect_timeout(&server_addr, Duration::from_secs(1)).expect("connect");
        configure_connection_stream(&stream, Duration::from_secs(1)).expect("configure stream");

        let mut encoded = serde_json::to_vec(&request).expect("encode protocol request");
        encoded.push(b'\n');
        stream.write_all(&encoded).expect("write protocol request");
        stream.flush().expect("flush protocol request");

        let mut response_line = String::new();
        let mut reader = BufReader::new(stream);
        reader
            .read_line(&mut response_line)
            .expect("read protocol response");

        serde_json::from_str(response_line.trim_end()).expect("decode protocol response")
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
    fn remote_protocol_envelope_carries_request_correlation_and_operation_selection() {
        let temp_dir = tempdir().expect("temp dir");
        let server = ServerHandle::bind(ServerConfig::new(
            LocalEngineConfig::new(temp_dir.path()),
            "127.0.0.1:0".parse().expect("listen addr"),
        ))
        .expect("bind server");
        let root_stream = stream_id("task.root");

        server
            .engine()
            .create_stream(root_descriptor("task.root"))
            .expect("create root");
        server
            .engine()
            .append(&root_stream, b"seed")
            .expect("append root");

        let request = ProtocolRequest {
            request_id: RequestId::new("req-42").expect("request id"),
            operation: OperationRequest::Read {
                stream_id: root_stream.clone(),
            },
        };
        let response = send_protocol_request(server.local_addr(), request.clone());

        assert_eq!(response.request_id, request.request_id);

        match response.envelope {
            ResponseEnvelope::Ack { ack, outcome } => {
                assert_eq!(ack.durability(), "local");
                assert_eq!(ack.topology(), RemoteTopology::SingleNode);
                match *outcome {
                    OperationResponse::RecordsOk(read) => {
                        assert_eq!(read.stream_id(), &root_stream);
                        assert_eq!(read.records().len(), 1);
                    }
                    other => panic!("expected records outcome, got {other:?}"),
                }
            }
            other => panic!("expected ack envelope, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
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

        assert_eq!(first.body().position().offset.value(), 0);
        assert_eq!(second.body().position().offset.value(), 1);
        assert_eq!(branch_append.body().position().offset.value(), 2);

        let root_read = client.read(&root_stream).expect("read root");
        let branch_read = client.read(&branch_stream).expect("read branch");
        let root_tail = client
            .tail(&root_stream, Offset::new(1))
            .expect("tail root");

        let root_offsets: Vec<u64> = root_read
            .body()
            .records()
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let branch_offsets: Vec<u64> = branch_read
            .body()
            .records()
            .iter()
            .map(|record| record.position().offset.value())
            .collect();
        let branch_payloads: Vec<&[u8]> = branch_read
            .body()
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();
        let tail_payloads: Vec<&[u8]> = root_tail
            .body()
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
        assert_eq!(root_read.ack().durability(), "local");
        assert_eq!(branch_read.ack().durability(), "local");
        assert_eq!(root_tail.ack().durability(), "local");

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_client_surfaces_explicit_acknowledgement_and_error_envelopes() {
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
                assert!(!error.request_id().as_str().is_empty());
                assert_eq!(error.code(), RemoteErrorCode::NotFound);
                assert_eq!(error.topology(), RemoteTopology::SingleNode);
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

        assert!(!append.request_id().as_str().is_empty());
        assert_eq!(append.ack().durability(), "local");
        assert_eq!(append.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(append.body().manifest_generation(), 0);
        assert_eq!(read.ack().durability(), "local");
        assert_eq!(read.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(read.body().records().len(), 1);

        match missing_append {
            RemoteClientError::Remote(error) => {
                assert!(!error.request_id().as_str().is_empty());
                assert_eq!(error.code(), RemoteErrorCode::NotFound);
                assert_eq!(error.topology(), RemoteTopology::SingleNode);
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
            .body()
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();
        let follow_up_payloads: Vec<&[u8]> = follow_up_tail
            .body()
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();

        assert_eq!(
            initial_payloads,
            vec![b"second".as_slice(), b"third".as_slice()]
        );
        assert_eq!(follow_up_payloads, vec![b"fourth".as_slice()]);
        assert_eq!(initial_tail.ack().durability(), "local");
        assert_eq!(follow_up_tail.ack().durability(), "local");

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_tail_sessions_have_explicit_lifecycle_and_cancellation() {
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

        let opened = client
            .open_tail_session(&root_stream, Offset::new(0), 1)
            .expect("open tail session");
        assert_eq!(opened.ack().durability(), "local");
        assert_eq!(opened.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(opened.body().records().len(), 1);
        assert_eq!(opened.body().state(), RemoteTailSessionState::Active);

        client
            .append(&root_stream, b"second")
            .expect("append second after open");
        let next_batch = client
            .poll_tail_session(opened.body().session_id(), 1)
            .expect("poll tail session");
        assert_eq!(next_batch.body().records().len(), 1);
        assert_eq!(
            next_batch.body().records()[0].payload(),
            b"second".as_slice()
        );
        assert_eq!(next_batch.body().state(), RemoteTailSessionState::Active);

        let cancelled = client
            .cancel_tail_session(opened.body().session_id())
            .expect("cancel tail session");
        assert_eq!(cancelled.body().session_id(), opened.body().session_id());
        assert_eq!(cancelled.body().state(), RemoteTailSessionState::Cancelled);

        let missing_poll = client
            .poll_tail_session(opened.body().session_id(), 1)
            .expect_err("poll after cancel should fail");
        match missing_poll {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::NotFound);
                assert!(error.message().contains("tail session"));
            }
            other => panic!("expected tail session not_found, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_tail_sessions_apply_explicit_credit_backpressure() {
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

        let opened = client
            .open_tail_session(&root_stream, Offset::new(0), 1)
            .expect("open tail session");
        let first_payloads: Vec<&[u8]> = opened
            .body()
            .records()
            .iter()
            .map(|record| record.payload())
            .collect();

        assert_eq!(opened.body().requested_credit(), 1);
        assert_eq!(opened.body().delivered_credit(), 1);
        assert_eq!(first_payloads, vec![b"first".as_slice()]);

        let second_batch = client
            .poll_tail_session(opened.body().session_id(), 1)
            .expect("poll second batch");
        let third_batch = client
            .poll_tail_session(opened.body().session_id(), 1)
            .expect("poll third batch");
        let waiting_batch = client
            .poll_tail_session(opened.body().session_id(), 1)
            .expect("poll awaiting batch");

        assert_eq!(second_batch.body().delivered_credit(), 1);
        assert_eq!(third_batch.body().delivered_credit(), 1);
        assert_eq!(waiting_batch.body().delivered_credit(), 0);
        assert_eq!(
            waiting_batch.body().state(),
            RemoteTailSessionState::AwaitingRecords
        );

        let excessive_credit = client
            .poll_tail_session(opened.body().session_id(), 300)
            .expect_err("credit above max should fail");
        match excessive_credit {
            RemoteClientError::Remote(error) => {
                assert_eq!(error.code(), RemoteErrorCode::InvalidRequest);
                assert!(error.message().contains("exceeds max"));
            }
            other => panic!("expected invalid_request for excessive credit, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_tail_sessions_are_logical_and_transport_agnostic_across_requests() {
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

        let opened = client
            .open_tail_session(&root_stream, Offset::new(0), 1)
            .expect("open session");
        client
            .append(&root_stream, b"first")
            .expect("append after open session");
        let batch = client
            .poll_tail_session(opened.body().session_id(), 1)
            .expect("poll over a later request");

        assert_eq!(batch.body().records().len(), 1);
        assert_eq!(batch.body().records()[0].payload(), b"first".as_slice());

        let encoded = serde_json::to_value(batch.body()).expect("encode batch");
        assert!(encoded.get("session_id").is_some());
        assert!(encoded.get("connection_id").is_none());
        assert!(encoded.get("socket").is_none());
        assert!(encoded.get("transport").is_none());
        assert!(encoded.get("wireguard_peer").is_none());

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

        assert_eq!(branch_status.body().stream_id(), &branch_stream);
        assert_eq!(branch_status.ack().durability(), "local");
        assert_eq!(branch_status.body().next_offset().value(), 2);
        assert_eq!(branch_append.body().position().offset.value(), 2);
        assert_eq!(lineage.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(lineage.body().status().stream_id(), &branch_stream);
        assert_eq!(lineage.body().status().next_offset().value(), 3);

        match &lineage.body().descriptor().lineage {
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
            .body()
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

        assert_eq!(merge_status.body().stream_id(), &merge_stream);
        assert_eq!(merge_status.ack().durability(), "local");
        assert_eq!(merge_status.body().next_offset().value(), 1);
        assert_eq!(lineage.ack().topology(), RemoteTopology::SingleNode);

        match &lineage.body().descriptor().lineage {
            StreamLineage::Merge { merge } => assert_eq!(merge, &merge_spec),
            other => panic!("expected merge lineage, got {other:?}"),
        }

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
                assert!(!error.request_id().as_str().is_empty());
                assert_eq!(error.code(), RemoteErrorCode::InvalidRequest);
                assert_eq!(error.topology(), RemoteTopology::SingleNode);
                assert!(error.message().contains("lineage position"));
            }
            other => panic!("expected remote invalid_request, got {other:?}"),
        }

        server.shutdown().expect("shutdown server");
    }

    #[test]
    fn remote_acknowledgement_semantics_remain_explicit_about_durability_and_non_replication_scope()
    {
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

        let read = client.read(&root_stream).expect("read root");
        let encoded = serde_json::to_value(read.ack()).expect("encode ack");

        assert_eq!(read.ack().durability(), "local");
        assert_eq!(read.ack().topology(), RemoteTopology::SingleNode);
        assert_eq!(
            encoded.get("topology").and_then(Value::as_str),
            Some("single_node")
        );
        assert_eq!(
            encoded.get("durability").and_then(Value::as_str),
            Some("local")
        );
        assert!(encoded.get("replication").is_none());
        assert!(encoded.get("leader").is_none());
        assert!(encoded.get("quorum").is_none());

        server.shutdown().expect("shutdown server");
    }
}
