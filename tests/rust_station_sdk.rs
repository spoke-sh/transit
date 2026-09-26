use serde_json::{Value, json};
use std::{
    collections::{BTreeSet, HashMap},
    fs,
    io::{self, BufRead, Write},
    path::Path,
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};
use transit_client::{
    Client, ClientConfig, Correlation, Counter as Count, Error, ErrorKind, MutationReceipt,
    OperationIdentity, ProcessRef, Result,
};
use transit_sdk_examples::codecs::*;
use transit_sdk_examples::{Counter, QueryRequester, Requester, TABLE, TOTAL, TableService};
use transit_station_sdk::*;

fn number(cfg: &Value, name: &str) -> u64 {
    cfg[name].as_u64().unwrap()
}
fn path(cfg: &Value, name: &str) -> String {
    cfg[name].as_str().unwrap().into()
}
fn report(value: Value) {
    println!("{value}");
    io::stdout().flush().unwrap();
}
fn io_error(_: impl std::fmt::Debug) -> Error {
    Error::new(ErrorKind::Handler, "proof-io")
}
fn wait_file(path: impl AsRef<Path>) {
    let deadline = Instant::now() + Duration::from_secs(30);
    while !path.as_ref().exists() {
        assert!(Instant::now() < deadline);
        thread::sleep(Duration::from_millis(10));
    }
}
#[derive(Default)]
struct Observations {
    initialized: usize,
    handled: usize,
    current: String,
    before_failed: BTreeSet<String>,
    confirm_failed: BTreeSet<String>,
    saved: HashMap<String, Box<[u8]>>,
    confirmations: BTreeSet<String>,
    segments: Vec<IpcSegment>,
}
type Shared = Arc<Mutex<Observations>>;
struct Store {
    mode: String,
    pending: String,
    shared: Shared,
}
impl RecoveryStore for Store {
    fn before_dispatch(&mut self, mutation: &FrozenMutation) -> Result<()> {
        let purpose = format!("{:?}", mutation.purpose()).to_lowercase();
        let mut shared = self.shared.lock().unwrap();
        shared.current = purpose.clone();
        if self.mode == "gates" && shared.before_failed.insert(purpose.clone()) {
            drop(shared);
            if purpose == "permit" {
                panic!("injected persistence panic");
            }
            return Err(io_error("persist"));
        }
        let identity = mutation.identity().sha256().to_owned();
        let bytes = mutation.export();
        if let Some(saved) = shared.saved.get(&identity) {
            assert_eq!(saved, &bytes);
        }
        shared.saved.insert(identity, bytes.clone());
        use std::os::unix::fs::OpenOptionsExt;
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o600)
            .open(&self.pending)
            .map_err(io_error)?;
        file.write_all(&bytes).map_err(io_error)?;
        file.sync_all().map_err(io_error)
    }
    fn confirmed(&mut self, identity: &OperationIdentity, receipt: MutationReceipt) -> Result<()> {
        let mut shared = self.shared.lock().unwrap();
        assert!(shared.saved.contains_key(identity.sha256()));
        assert!(receipt.position.get() > 0);
        let purpose = shared.current.clone();
        if self.mode == "gates" && shared.confirm_failed.insert(purpose.clone()) {
            drop(shared);
            if purpose == "open" {
                panic!("injected confirmation panic");
            }
            return Err(io_error("confirm"));
        }
        shared.confirmations.insert(identity.sha256().to_owned());
        Ok(())
    }
}
struct Instrumented<H> {
    inner: H,
    mode: String,
    shared: Shared,
}
impl<M: 'static, H: Handler<M>> Handler<M> for Instrumented<H> {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()> {
        self.shared.lock().unwrap().initialized += 1;
        assert_eq!(turn.budgets()?.mutations, 3);
        self.inner.initialize(turn)
    }
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<M>) -> Result<()> {
        self.shared.lock().unwrap().handled += 1;
        if self.mode == "poison" {
            assert_eq!(
                turn.state().require(&TOTAL).unwrap_err().kind,
                ErrorKind::ReadFailed
            );
            return Ok(());
        }
        if self.mode.starts_with("handler-") || self.mode.starts_with("panic-") {
            turn.state().put(&TOTAL, &73)?;
            if self.mode.starts_with("panic-") {
                panic!("injected handler panic");
            }
            return Err(io_error("handler"));
        }
        self.inner.handle(turn, input)
    }
    fn handle_result(&mut self, turn: &mut Turn<'_>, input: ResultComplete) -> Result<()> {
        self.inner.handle_result(turn, input)
    }
}
struct TableProof {
    inner: TableService,
    output: String,
}
impl Handler<QueryMessage> for TableProof {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()> {
        self.inner.initialize(turn)
    }
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<QueryMessage>) -> Result<()> {
        let saved = format!("{}/version.json", self.output);
        match input {
            Incoming::Cast {
                value: QueryMessage::Rows,
                ..
            } => {
                let mut table = turn.table(&TABLE)?;
                let mut cursor = None;
                let mut rows = Vec::new();
                let mut pages = 0;
                loop {
                    let page = table.page(cursor.as_ref())?;
                    assert!(page.entries.len() <= 8);
                    assert_eq!(page.basis.as_ref(), Some(table.basis()));
                    rows.extend(page.entries);
                    pages += 1;
                    cursor = page.next;
                    if cursor.is_none() {
                        break;
                    }
                }
                assert_eq!(rows.len(), 41);
                assert_eq!(pages, 6);
                assert_eq!(rows[0].key, i64::MIN);
                assert_eq!(rows[0].value, None);
                let version = turn.retain()?;
                fs::write(saved, json!({"pid":version.pid.get(),"input":version.input.get(),"index":version.index}).to_string()).map_err(io_error)?;
                turn.table(&TABLE)?.update(&Row {
                    key: i64::MIN,
                    value: Some(17),
                })
            }
            Incoming::Cast {
                value: QueryMessage::Initialize,
                ..
            } if Path::new(&saved).exists() => {
                let value: Value = serde_json::from_slice(&fs::read(saved).map_err(io_error)?)
                    .map_err(io_error)?;
                let version = ReadVersion {
                    pid: Count::new(number(&value, "pid"))?,
                    input: Count::new(number(&value, "input"))?,
                    index: number(&value, "index") as u8,
                };
                assert_eq!(turn.table(&TABLE)?.get(i64::MIN)?.unwrap().value, Some(17));
                let mut source = turn.open_version(version)?;
                assert_eq!(source.table(&TABLE)?.get(i64::MIN)?.unwrap().value, None);
                assert_eq!(source.table(&TABLE)?.page(None)?.entries.len(), 8);
                assert!(source.state().page(None)?.entries.len() <= 8);
                turn.release(version)
            }
            _ => self.inner.handle(turn, input),
        }
    }
}
struct QueryProof<F> {
    inner: QueryRequester<F>,
    output: String,
}
impl<F: FnMut(IpcSegment) -> Result<()> + Send + 'static> Handler<QueryStart> for QueryProof<F> {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()> {
        self.inner.initialize(turn)
    }
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<QueryStart>) -> Result<()> {
        let file = format!("{}/manifest.json", self.output);
        if Path::new(&file).exists() {
            let value: Value =
                serde_json::from_slice(&fs::read(file).map_err(io_error)?).map_err(io_error)?;
            let mut reader = turn.result(Correlation::new(
                value["correlation"].as_str().unwrap().parse().unwrap(),
            )?)?;
            assert_eq!(reader.manifest()?.rows, 41);
            fs::write(format!("{}/ready", self.output), "").map_err(io_error)?;
            wait_file(format!("{}/continue", self.output));
            reader.segment(0)?;
            Ok(())
        } else {
            self.inner.handle(turn, input)
        }
    }
    fn handle_result(&mut self, turn: &mut Turn<'_>, complete: ResultComplete) -> Result<()> {
        self.inner.handle_result(turn, complete.clone())?;
        let manifest = turn.result(complete.correlation)?.manifest()?;
        fs::write(format!("{}/manifest.json",self.output), json!({"rows":manifest.rows,"segments":manifest.segments,
            "correlation":manifest.correlation.get().to_string(),"source":manifest.source.pid(),"destination":manifest.destination.pid(),
            "resource":manifest.basis.resource.resource(),"revision":manifest.basis.revision.get(),"bytes":manifest.byte_count}).to_string()).map_err(io_error)
    }
}
fn save_owned(shared: &Shared, output: &str) -> Result<()> {
    let mut shared = shared.lock().unwrap();
    #[cfg(feature = "arrow")]
    let mut batches = Vec::new();
    for segment in &mut shared.segments {
        fs::write(format!("{output}/{}.arrow", segment.ordinal), &segment.ipc).map_err(io_error)?;
        #[cfg(feature = "arrow")]
        {
            batches.extend(segment.to_arrow()?);
            segment.ipc.fill(0);
        }
    }
    #[cfg(feature = "arrow")]
    if !batches.is_empty() {
        use arrow_array::{Array, Int64Array};
        let mut rows = Vec::new();
        for batch in batches {
            let keys = batch
                .column(0)
                .as_any()
                .downcast_ref::<Int64Array>()
                .unwrap();
            let values = batch
                .column(1)
                .as_any()
                .downcast_ref::<Int64Array>()
                .unwrap();
            for i in 0..batch.num_rows() {
                rows.push((
                    keys.value(i),
                    if values.is_null(i) {
                        None
                    } else {
                        Some(values.value(i))
                    },
                ));
            }
        }
        assert_eq!(rows.len(), 41);
        assert_eq!(rows[0], (i64::MIN, Some(17)));
        assert_eq!(rows[1].1, Some(i64::MAX));
        assert_eq!(rows[2].1, Some((1 << 53) + 1));
        assert_eq!(rows[5].1, None);
        fs::write(
            format!("{output}/adapter-verified"),
            "owned IPC and batches survive runner close",
        )
        .map_err(io_error)?;
    }
    Ok(())
}
fn drive<M: 'static, H: Handler<M>>(
    cfg: Value,
    mode: &str,
    inner: H,
    codec: impl Codec<M>,
    shared: Shared,
) -> Result<()> {
    let config = ServiceConfig::new(
        ClientConfig::growing(&path(&cfg, "url"))?,
        Activation::new(
            ProcessRef::new(number(&cfg, "realm"), number(&cfg, "pid"))?,
            number(&cfg, "principal"),
            number(&cfg, "generation"),
            path(&cfg, "seed_file"),
        )?,
    )
    .with_query_results(cfg["query_results"].as_bool().unwrap());
    let options = RunnerOptions {
        failure: if mode.ends_with("-block") {
            FailurePolicy::BlockInput
        } else {
            FailurePolicy::Stop
        },
        recovery: Recovery::PersistBeforeDispatch(Box::new(Store {
            mode: mode.into(),
            pending: path(&cfg, "pending"),
            shared: shared.clone(),
        })),
    };
    let opened = Runner::open(
        config,
        Instrumented {
            inner,
            mode: mode.into(),
            shared: shared.clone(),
        },
        codec,
        options,
    );
    if mode == "denied" {
        assert!(matches!(opened,Err(error) if error.kind==ErrorKind::AccessDenied));
        return Ok(());
    }
    let mut runner = opened?;
    if mode == "async" {
        assert!(!matches!(
            runner.next()?,
            Some(RunnerEvent::Committed { .. })
        ));
        let stop = runner.stop_token();
        let worker = thread::spawn(move || {
            loop {
                if matches!(runner.next().unwrap(), Some(RunnerEvent::Committed { .. })) {
                    break;
                }
            }
            runner.close().unwrap()
        });
        wait_file(format!("{}/accepted", path(&cfg, "output")));
        stop.stop();
        let mut beats = 0;
        while !worker.is_finished() {
            beats += 1;
            thread::sleep(Duration::from_millis(10));
        }
        let evidence = worker.join().unwrap();
        assert!(beats > 5);
        assert!(evidence.pending.is_none());
        assert!(matches!(
            evidence.last_event,
            Some(RunnerEvent::Committed { .. })
        ));
        assert_eq!(shared.lock().unwrap().handled, 1);
        report(json!({"committed":true,"beats":beats}));
        return Ok(());
    }
    if mode == "gates" {
        let mut phases = BTreeSet::new();
        let mut done = false;
        for _ in 0..40 {
            let mut event = runner.next()?.unwrap();
            if let RunnerEvent::NeedsRecovery {
                phase, ref receipt, ..
            } = event
            {
                phases.insert(phase);
                if phase == "confirm" {
                    assert!(receipt.is_some());
                }
                assert!(
                    matches!(runner.next()?,Some(RunnerEvent::NeedsRecovery { phase:again,.. }) if again==phase)
                );
                event = runner.reconcile()?.unwrap();
            }
            if matches!(event, RunnerEvent::Committed { .. }) {
                done = true;
                break;
            }
        }
        assert!(done);
        assert_eq!(phases, BTreeSet::from(["confirm", "persist"]));
        let observations = shared.lock().unwrap();
        assert_eq!(observations.initialized, 1);
        assert_eq!(observations.handled, 1);
        assert_eq!(observations.confirmations.len(), 3);
        report(
            json!({"gates":observations.confirm_failed,"handled":observations.handled,"dispatches":observations.saved.len()}),
        );
    } else if mode.starts_with("decode-")
        || mode.starts_with("handler-")
        || mode.starts_with("panic-")
    {
        let mut stopped = false;
        for _ in 0..8 {
            match runner.next() {
                Err(error) => {
                    assert!(!mode.ends_with("-block"));
                    assert_eq!(
                        error.kind,
                        if mode.starts_with("decode-") {
                            ErrorKind::Codec
                        } else {
                            ErrorKind::Handler
                        }
                    );
                    stopped = true;
                    break;
                }
                Ok(Some(RunnerEvent::Blocked {
                    receipt: Some(_), ..
                })) => {
                    assert!(mode.ends_with("-block"));
                    stopped = true;
                    break;
                }
                _ => {}
            }
        }
        assert!(stopped);
    } else if ["stale", "expired", "revoked-result", "poison"].contains(&mode) {
        let expected = match mode {
            "stale" => ErrorKind::StaleOwnership,
            "expired" => ErrorKind::ProcessRetired,
            "poison" => ErrorKind::ReadFailed,
            _ => ErrorKind::AccessDenied,
        };
        let mut failed = false;
        for _ in 0..8 {
            if let Err(error) = runner.next() {
                assert_eq!(error.kind, expected, "{error:?}");
                failed = true;
                break;
            }
        }
        assert!(failed);
        report(json!({"denied":true}));
    } else {
        for line in io::stdin().lock().lines() {
            let line = line.map_err(io_error)?;
            if line == "close" {
                runner.close().map_err(|error| error.error)?;
                save_owned(&shared, &path(&cfg, "output"))?;
                report(json!({"closed":true}));
                return Ok(());
            }
            assert_eq!(line, "one");
            let mut result = None;
            for _ in 0..32 {
                match runner.next()?.unwrap() {
                    RunnerEvent::Progress => {}
                    RunnerEvent::Committed { .. } => {
                        result = Some(json!({"event":"Committed"}));
                        break;
                    }
                    RunnerEvent::Blocked { .. } => {
                        result = Some(json!({"event":"Blocked"}));
                        break;
                    }
                    RunnerEvent::Idle => {
                        result = Some(json!({"event":"Idle"}));
                        break;
                    }
                    RunnerEvent::NeedsRecovery {
                        mutation,
                        phase,
                        error,
                        ..
                    } => {
                        assert_eq!(
                            &*mutation.export(),
                            fs::read(path(&cfg, "pending")).map_err(io_error)?
                        );
                        result =
                            Some(json!({"event":"NeedsRecovery","phase":phase,"code":error.code}));
                        break;
                    }
                }
            }
            report(result.expect("bounded runner progress"));
        }
    }
    runner.close().map_err(|error| error.error)?;
    Ok(())
}
fn codecs(cfg: &Value) -> Result<()> {
    let fixture: Value =
        serde_json::from_slice(&fs::read(path(cfg, "fixtures")).map_err(io_error)?)
            .map_err(io_error)?;
    for item in fixture["valid"].as_array().unwrap() {
        let bytes = transit_client::internal::unhex(item["hex"].as_str().unwrap(), 256)?;
        let encoded = match item["codec"].as_str().unwrap() {
            "counter" => CounterFormat.encode(&CounterFormat.decode(&bytes)?)?,
            "query" => QueryFormat.encode(&QueryFormat.decode(&bytes)?)?,
            "u64" => {
                let value = U64Codec.decode(&bytes)?;
                assert_eq!(value.to_string(), item["value"].as_str().unwrap());
                U64Codec.encode(&value)?
            }
            _ => panic!("codec"),
        };
        assert_eq!(encoded, bytes);
    }
    for item in fixture["invalid"].as_array().unwrap() {
        let bytes = transit_client::internal::unhex(item["hex"].as_str().unwrap(), 256)?;
        assert!(match item["codec"].as_str().unwrap() {
            "counter" => CounterFormat.decode(&bytes).is_err(),
            "query" => QueryFormat.decode(&bytes).is_err(),
            "u64" => U64Codec.decode(&bytes).is_err(),
            _ => false,
        });
    }
    let value = CounterMessage::Add((1 << 53) + 1);
    let mut expected = b"STN1\x01\0\0\0\0\0\0\0\0".to_vec();
    expected.extend(CounterCodec.encode(&value)?);
    assert_eq!(&*encode_cast(&value, &CounterCodec, None)?, expected);
    Ok(())
}
fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().collect();
    let mode = &args[1];
    let cfg: Value = serde_json::from_slice(&fs::read(&args[2])?)?;
    assert_eq!(cfg["profile"], "growing_v3");
    if mode == "codecs" {
        return Ok(codecs(&cfg)?);
    }
    if mode == "arrow" {
        assert!(Path::new(&format!("{}/adapter-verified", path(&cfg, "output"))).exists());
        return Ok(());
    }
    if mode == "recover" {
        let mut client = Client::open(ClientConfig::growing(&path(&cfg, "url"))?)?;
        let mutation = client.recover_mutation(&fs::read(path(&cfg, "pending"))?)?;
        report(json!({"receipt":client.dispatch_mutation(&mutation)?.position.get()}));
        client.close()?;
        return Ok(());
    }
    let shared = Shared::default();
    let peer = ProcessRef::new(number(&cfg, "realm"), number(&cfg, "peer"))?;
    match cfg["role"].as_str().unwrap() {
        "service" => drive(cfg, mode, Counter, CounterCodec, shared)?,
        "requester" => drive(
            cfg,
            mode,
            Requester { counter: peer },
            RequesterCodec,
            shared,
        )?,
        "table" => drive(
            cfg.clone(),
            mode,
            TableProof {
                inner: TableService { requester: peer },
                output: path(&cfg, "output"),
            },
            QueryCodec,
            shared,
        )?,
        "query" => {
            let copy = shared.clone();
            let consume = move |segment| {
                copy.lock().unwrap().segments.push(segment);
                Ok(())
            };
            drive(
                cfg.clone(),
                mode,
                QueryProof {
                    inner: QueryRequester {
                        source: peer,
                        consume,
                    },
                    output: path(&cfg, "output"),
                },
                QueryStartCodec,
                shared,
            )?;
        }
        _ => panic!("role"),
    }
    Ok(())
}
