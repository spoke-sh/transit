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
    OperationIdentity, ProcessRef, ResourceRef, Result,
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
    let fixture: Value =
        serde_json::from_slice(&fs::read(path(cfg, "http_fixtures")).map_err(io_error)?)
            .map_err(io_error)?;
    let prepared = prepare_http(
        ResourceRef::new(72, 8)?,
        u64::MAX,
        &HttpRequest {
            method: HttpMethod::Post,
            target: vec![HttpPiece::Literal("/write".into())],
            headers: vec![],
        },
        &transit_client::internal::unhex(fixture["body"].as_str().unwrap(), 65536)?,
        HttpRequestOptions {
            endpoint_revision: 7,
            reconcile_before_ms: Count::new(9000)?,
            max_attempts: 2,
        },
        None,
    )?;
    assert_eq!(
        transit_client::internal::hex(prepared.reference(), 112)?,
        fixture["reference"]
    );
    assert_eq!(
        std::str::from_utf8(prepared.metadata()).unwrap(),
        fixture["metadata"]
    );
    let bytes = transit_client::internal::unhex(fixture["outcome"].as_str().unwrap(), 71)?;
    let HttpReply::Outcome(outcome) = decode_http_reply(72, &bytes, None)? else {
        panic!("HTTP outcome");
    };
    assert_eq!(outcome.exchange, u64::MAX);
    assert_eq!(outcome.status, Some(200));
    assert_eq!(outcome.phase, HttpPhase::Observed);
    assert!(outcome.reference().is_some());
    assert!(matches!(
        decode_http_reply(
            72,
            &transit_client::internal::unhex(fixture["rejection"].as_str().unwrap(), 71)?,
            None
        )?,
        HttpReply::Rejected(HttpRejection::Denied)
    ));
    let codec = HttpReplyCodec::new(U64Codec, 72, None)?;
    assert!(matches!(
        codec.decode(&bytes)?,
        HttpMessage::Reply(HttpReply::Outcome(_))
    ));
    assert!(matches!(
        codec.decode(&codec.encode(&HttpMessage::Application(u64::MAX))?)?,
        HttpMessage::Application(u64::MAX)
    ));
    assert!(decode_http_reply(72, &bytes[..70], None).is_err());
    let release: Value =
        serde_json::from_slice(&fs::read(path(cfg, "http_release_fixtures")).map_err(io_error)?)
            .map_err(io_error)?;
    let released_bytes = transit_client::internal::unhex(release["reply"].as_str().unwrap(), 20)?;
    let HttpMessage::Reply(HttpReply::Released(released)) = codec.decode(&released_bytes)? else {
        panic!("HTTP released");
    };
    assert_eq!(released.resource, ResourceRef::new(72, 7)?);
    assert_eq!(released.exchange, u64::MAX);
    assert!(
        codec
            .encode(&HttpMessage::Reply(HttpReply::Released(released)))
            .is_err()
    );
    assert!(decode_http_reply(72, &released_bytes[..19], None).is_err());
    assert!(
        prepare_http(
            ResourceRef::new(72, 8)?,
            1,
            &HttpRequest {
                method: HttpMethod::Get,
                target: vec![HttpPiece::Literal("//other/".into())],
                headers: vec![],
            },
            b"",
            HttpRequestOptions {
                endpoint_revision: 1,
                reconcile_before_ms: Count::new(9000)?,
                max_attempts: 1
            },
            None
        )
        .is_err()
    );
    Ok(())
}

struct ByteCodec;
impl Codec<Vec<u8>> for ByteCodec {
    fn type_id(&self) -> &str {
        "test.http-control"
    }
    fn version(&self) -> u32 {
        1
    }
    fn max_encoded_bytes(&self) -> usize {
        243
    }
    fn encode(&self, value: &Vec<u8>) -> Result<Vec<u8>> {
        Ok(value.clone())
    }
    fn decode(&self, bytes: &[u8]) -> Result<Vec<u8>> {
        Ok(bytes.to_vec())
    }
}
struct HttpHandler {
    peer: ProcessRef,
    request: PreparedHttpRequest,
    observed: Arc<Mutex<Value>>,
    disposal: Option<HttpReleased>,
    parent: Option<HttpOutcome>,
    followup_reason: HttpFollowupReason,
}
impl Handler<HttpMessage<Vec<u8>>> for HttpHandler {
    fn initialize(&mut self, _turn: &mut Turn<'_>) -> Result<()> {
        Ok(())
    }
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<HttpMessage<Vec<u8>>>) -> Result<()> {
        let correlation = Key::new(b"http-correlation", U64Codec)?;
        let release_correlation = Key::new(b"http-release-correlation", U64Codec)?;
        let followup_correlation = Key::new(b"http-followup-correlation", U64Codec)?;
        match input {
            Incoming::Cast {
                value: HttpMessage::Application(bytes),
                ..
            } if bytes == b"followup" => {
                let parent = self.parent.as_ref().unwrap();
                let mut wrong = parent.clone();
                wrong.resource = ResourceRef::new(73, parent.resource.resource())?;
                assert_eq!(
                    turn.followup_http(self.peer, &wrong, self.followup_reason, &self.request)
                        .unwrap_err()
                        .kind,
                    ErrorKind::InvalidArgument
                );
                let call =
                    turn.followup_http(self.peer, parent, self.followup_reason, &self.request)?;
                turn.state().put(&followup_correlation, &call.get())?;
                *self.observed.lock().unwrap() = json!({"followup":false});
            }
            Incoming::Cast {
                value: HttpMessage::Application(bytes),
                ..
            } if bytes == b"dispose" => {
                let disposal = self.disposal.unwrap();
                assert_eq!(
                    turn.release_http(
                        self.peer,
                        ResourceRef::new(73, disposal.resource.resource())?,
                        disposal.exchange
                    )
                    .unwrap_err()
                    .kind,
                    ErrorKind::InvalidArgument
                );
                let call = turn.release_http(self.peer, disposal.resource, disposal.exchange)?;
                turn.state().put(&release_correlation, &call.get())?;
                *self.observed.lock().unwrap() = json!({"released":false});
            }
            Incoming::Cast { .. } => {
                if turn.state().find(&correlation)?.is_some() {
                    *self.observed.lock().unwrap() = json!({"called":true});
                } else if turn.stage_http(&self.request)? {
                    let call = turn.call_http(self.peer, &self.request)?;
                    turn.state().put(&correlation, &call.get())?;
                    *self.observed.lock().unwrap() = json!({"called":true});
                } else {
                    *self.observed.lock().unwrap() = json!({"called":false});
                }
            }
            Incoming::Reply(reply) => {
                if let HttpMessage::Reply(HttpReply::Rejected(reason)) = &reply.value {
                    let saved = turn.state().require(&followup_correlation)?;
                    turn.require_reply(&reply, self.peer, Correlation::new(saved)?)?;
                    assert_eq!(*reason, HttpRejection::Denied);
                    turn.state()
                        .put(&Key::new(b"http-followup-denied", U64Codec)?, &saved)?;
                    *self.observed.lock().unwrap() = json!({"followup":true});
                    return Ok(());
                }
                if let HttpMessage::Reply(HttpReply::Released(released)) = &reply.value {
                    let saved = turn.state().require(&release_correlation)?;
                    turn.require_reply(&reply, self.peer, Correlation::new(saved)?)?;
                    assert_eq!(Some(*released), self.disposal);
                    turn.state()
                        .put(&Key::new(b"http-disposed", U64Codec)?, &released.exchange)?;
                    *self.observed.lock().unwrap() = json!({"released":true});
                    return Ok(());
                }
                let saved = turn.state().require(&correlation)?;
                turn.require_reply(&reply, self.peer, Correlation::new(saved)?)?;
                let HttpMessage::Reply(HttpReply::Outcome(outcome)) = reply.value else {
                    panic!("HTTP outcome");
                };
                assert_eq!(outcome.phase, HttpPhase::Observed);
                assert_eq!(outcome.status, Some(200));
                turn.state()
                    .put(&Key::new(b"http-status", U64Codec)?, &200)?;
                *self.observed.lock().unwrap() = json!({"observed":true});
            }
            _ => panic!("HTTP input"),
        }
        Ok(())
    }
}
fn http_consumer(cfg: Value, mode: &str) -> Result<()> {
    let prepared = prepare_http(
        ResourceRef::new(72, number(&cfg, "resource"))?,
        u64::MAX,
        &HttpRequest {
            method: HttpMethod::Post,
            target: vec![
                HttpPiece::Literal("/items/".into()),
                HttpPiece::Variable {
                    name: "id".into(),
                    value: "λ /".into(),
                },
            ],
            headers: vec![
                HttpHeader {
                    name: "X-Tag".into(),
                    value: vec![HttpPiece::Literal("one".into())],
                },
                HttpHeader {
                    name: "X-Tag".into(),
                    value: vec![HttpPiece::Literal("two".into())],
                },
                HttpHeader {
                    name: "Authorization".into(),
                    value: vec![
                        HttpPiece::Literal("Bearer ".into()),
                        HttpPiece::Secret {
                            binding: "api".into(),
                            version: 7,
                        },
                    ],
                },
            ],
        },
        &transit_client::internal::unhex(&path(&cfg, "body"), 65536)?,
        HttpRequestOptions {
            endpoint_revision: 7,
            reconcile_before_ms: Count::new(number(&cfg, "deadline"))?,
            max_attempts: 1,
        },
        None,
    )?;
    let config = ServiceConfig::new(
        ClientConfig::growing(&path(&cfg, "url"))?,
        Activation::new(
            ProcessRef::new(72, number(&cfg, "pid"))?,
            number(&cfg, "principal"),
            number(&cfg, "generation"),
            path(&cfg, "seed_file"),
        )?,
    );
    let observed = Arc::new(Mutex::new(Value::Null));
    let parent = if let Some(value) = cfg["outcome"].as_str() {
        let HttpReply::Outcome(outcome) =
            decode_http_reply(72, &transit_client::internal::unhex(value, 71)?, None)?
        else {
            panic!("HTTP outcome");
        };
        Some(outcome)
    } else {
        None
    };
    let mut runner = Runner::open(
        config,
        HttpHandler {
            peer: ProcessRef::new(72, number(&cfg, "peer"))?,
            request: prepared,
            observed: observed.clone(),
            disposal: parent.as_ref().map(|outcome| HttpReleased {
                resource: outcome.resource,
                exchange: outcome.exchange,
            }),
            parent,
            followup_reason: match cfg["followup_reason"].as_str() {
                Some("redirect") => HttpFollowupReason::Redirect,
                Some("reconcile") => HttpFollowupReason::Reconcile,
                Some("cancel") => HttpFollowupReason::Cancel,
                Some("retry") | None => HttpFollowupReason::Retry,
                _ => panic!("followup reason"),
            },
        },
        HttpReplyCodec::new(ByteCodec, 72, None)?,
        RunnerOptions {
            failure: FailurePolicy::Stop,
            recovery: Recovery::FenceOnRestart,
        },
    )?;
    if mode == "http-caller" {
        for action in io::stdin().lock().lines() {
            let action = action.map_err(io_error)?;
            if action == "close" {
                break;
            }
            assert_eq!(action, "step");
            let mut committed = false;
            for _ in 0..32 {
                if matches!(runner.next()?, Some(RunnerEvent::Committed { .. })) {
                    committed = true;
                    break;
                }
            }
            assert!(committed);
            report(observed.lock().unwrap().clone());
        }
        runner.close().map_err(|e| e.error)?;
        report(json!({"closed":true,"owned":""}));
        return Ok(());
    }
    let HttpReply::Outcome(outcome) = decode_http_reply(
        72,
        &transit_client::internal::unhex(&path(&cfg, "outcome"), 71)?,
        None,
    )?
    else {
        panic!("HTTP outcome");
    };
    if mode == "http-async" {
        let stop = runner.stop_token();
        let accepted = path(&cfg, "accepted");
        let worker = thread::spawn(move || {
            let mut reader = runner
                .open_http(&outcome, HttpReplayPolicy::Captured)
                .unwrap();
            let first = reader.read().unwrap().unwrap();
            assert!(!first.data.is_empty());
            assert!(!first.complete);
            fs::write(path(&cfg, "ready"), "").unwrap();
            wait_file(path(&cfg, "continue"));
            reader.read().unwrap();
            drop(reader);
            runner.close().unwrap();
            assert!(!first.data.is_empty());
        });
        wait_file(accepted);
        stop.stop();
        let mut beats = 0;
        while !worker.is_finished() {
            beats += 1;
            thread::sleep(Duration::from_millis(10));
        }
        worker.join().unwrap();
        assert!(beats > 5);
        report(json!({"joined":true}));
        return Ok(());
    }
    let mut owned = Vec::new();
    {
        let mut reader = runner.open_http(&outcome, HttpReplayPolicy::Captured)?;
        for action in io::stdin().lock().lines() {
            match action.map_err(io_error)?.as_str() {
                "open" => {
                    let first = reader.read()?.unwrap();
                    assert!(!first.data.is_empty());
                    assert!(!first.complete);
                    report(json!({"prefix":true}));
                }
                "denied" => {
                    assert_eq!(reader.read().unwrap_err().kind, ErrorKind::AccessDenied);
                    report(json!({"denied":true}));
                }
                "reopen" => {
                    let error = reader.read().unwrap_err();
                    assert_eq!(error.kind, ErrorKind::ReadFailed);
                    assert_eq!(error.code.as_deref(), Some("HttpReplayFailed"));
                    reader.close()?;
                    reader.close()?;
                    drop(reader);
                    reader = runner.open_http(&outcome, HttpReplayPolicy::Captured)?;
                    while let Some(part) = reader.read()? {
                        if part.kind == HttpPartKind::ResponseBody {
                            owned.extend_from_slice(&part.data);
                        }
                    }
                    assert!(reader.complete());
                    reader.close()?;
                    report(
                        json!({"complete":true,"body":transit_client::internal::hex(&owned,65536)?}),
                    );
                }
                "close" => break,
                _ => panic!("HTTP command"),
            }
        }
    }
    runner.close().map_err(|e| e.error)?;
    report(json!({"closed":true,"owned":transit_client::internal::hex(&owned,65536)?}));
    Ok(())
}
fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().collect();
    let mode = &args[1];
    let cfg: Value = serde_json::from_slice(&fs::read(&args[2])?)?;
    assert_eq!(cfg["profile"], "growing_v3");
    if mode.starts_with("http-") {
        return Ok(http_consumer(cfg, mode)?);
    }
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
