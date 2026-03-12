use crate::engine::{DurabilityMode, LocalEngine, LocalEngineConfig};
use anyhow::{Context, Result};
use std::net::{Shutdown, SocketAddr, TcpListener, TcpStream};
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;

const DEFAULT_ACCEPT_POLL_INTERVAL_MS: u64 = 10;

#[derive(Debug, Clone)]
pub struct ServerConfig {
    engine: LocalEngineConfig,
    listen_addr: SocketAddr,
    accept_poll_interval: Duration,
}

impl ServerConfig {
    pub fn new(engine: LocalEngineConfig, listen_addr: SocketAddr) -> Self {
        Self {
            engine,
            listen_addr,
            accept_poll_interval: Duration::from_millis(DEFAULT_ACCEPT_POLL_INTERVAL_MS),
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

        let thread_shutdown = Arc::clone(&shutdown_requested);
        let thread_connections = Arc::clone(&accepted_connections);
        let thread_error = Arc::clone(&fatal_error);
        let accept_poll_interval = config.accept_poll_interval();
        let listener_thread = thread::Builder::new()
            .name("transit-server-listener".into())
            .spawn(move || {
                run_accept_loop(
                    listener,
                    thread_shutdown,
                    thread_connections,
                    thread_error,
                    accept_poll_interval,
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
    data_dir: std::path::PathBuf,
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

fn run_accept_loop(
    listener: TcpListener,
    shutdown_requested: Arc<AtomicBool>,
    accepted_connections: Arc<AtomicU64>,
    fatal_error: Arc<Mutex<Option<String>>>,
    accept_poll_interval: Duration,
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
                let _ = stream.shutdown(Shutdown::Both);
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

#[cfg(test)]
mod tests {
    use super::{ServerConfig, ServerHandle};
    use crate::engine::{DurabilityMode, LocalEngine, LocalEngineConfig};
    use crate::kernel::{LineageMetadata, StreamDescriptor, StreamId};
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
}
