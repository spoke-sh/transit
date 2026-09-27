use crate::{
    Codec, Control, FailurePolicy, FrozenMutation, Incoming, Origin, Purpose, Recovery, Reply,
    ResultComplete, RunnerEvent, RunnerOptions, ServiceConfig, Turn, abi,
    bridge::{Bridge, counter, wide},
    types::decode,
};
use serde_json::{Value, json};
use std::panic::{AssertUnwindSafe, catch_unwind};
use transit_client::internal::{Worker, boolean, number, string, unhex};
use transit_client::{
    Correlation, Error, ErrorKind, MutationReceipt, ProcessRef, Result, StopToken,
};

pub trait Handler<M>: Send + 'static {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()>;
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<M>) -> Result<()>;
    fn handle_control(&mut self, _turn: &mut Turn<'_>, _input: Control) -> Result<()> {
        Err(Error::new(ErrorKind::Handler, "unhandled-control"))
    }
    fn handle_result(&mut self, _turn: &mut Turn<'_>, _input: ResultComplete) -> Result<()> {
        Err(Error::new(ErrorKind::Handler, "unhandled-query-result"))
    }
}
#[derive(Clone, Debug)]
pub struct Shutdown {
    pub pending: Option<FrozenMutation>,
    pub last_event: Option<RunnerEvent>,
}
#[derive(Debug)]
pub struct CloseError {
    pub error: Error,
    pub evidence: Option<Shutdown>,
}
impl std::fmt::Display for CloseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Runner cleanup failed: {}", self.error)
    }
}
impl std::error::Error for CloseError {}

fn origin(realm: u64, value: &Value) -> Result<Origin> {
    if let Some(value) = value.get("external") {
        return Ok(Origin::External {
            principal: counter(&value["principal"], true)?,
            policy_revision: counter(&value["policy_revision"], false)?,
        });
    }
    if let Some(value) = value.get("process") {
        return Ok(Origin::Process {
            process: ProcessRef::new(realm, number(&value["pid"], "origin", false)?)?,
            turn: counter(&value["turn"], false)?,
            output: counter(&value["output"], true)?,
        });
    }
    if let Some(value) = value.get("effect") {
        return Ok(Origin::Effect {
            effect: counter(&value["id"], false)?,
            attempt: counter(&value["attempt"], false)?,
            executor: counter(&value["executor"], true)?,
        });
    }
    Err(Error::new(ErrorKind::IncompatibleNative, "input-origin"))
}
fn callback(work: impl FnOnce() -> Result<()>, phase: &'static str) -> Result<()> {
    catch_unwind(AssertUnwindSafe(work))
        .unwrap_or_else(|_| Err(Error::new(ErrorKind::Handler, phase)))
}
struct State<M: 'static> {
    bridge: Bridge,
    process: ProcessRef,
    handler: Box<dyn Handler<M>>,
    codec: Box<dyn Codec<M>>,
    options: RunnerOptions,
    stop: StopToken,
    pending: Option<FrozenMutation>,
    confirmed: Option<Value>,
    paused: Option<RunnerEvent>,
    attempted: bool,
    last_event: Option<RunnerEvent>,
}
impl<M: 'static> State<M> {
    fn record(&mut self, event: RunnerEvent) -> RunnerEvent {
        self.last_event = Some(event.clone());
        event
    }
    fn pause(
        &mut self,
        error: Error,
        phase: &'static str,
        receipt: Option<MutationReceipt>,
    ) -> RunnerEvent {
        let event = RunnerEvent::NeedsRecovery {
            mutation: self.pending.as_ref().expect("pending mutation").clone(),
            phase,
            error,
            receipt,
        };
        self.paused = Some(event.clone());
        self.record(event)
    }
    fn accept(&mut self, event: Value) -> RunnerEvent {
        self.confirmed = Some(event.clone());
        let pending = self.pending.as_ref().expect("pending mutation").clone();
        let confirmed = &event["confirmation"];
        if confirmed["kind"] != pending.purpose.native()
            || confirmed["input"] != pending.input.get()
        {
            return self.pause(
                Error::new(ErrorKind::IncompatibleNative, "confirmation-identity"),
                "confirm",
                None,
            );
        }
        let receipt = match counter(&confirmed["receipt"]["position"], false) {
            Ok(position) => MutationReceipt { position },
            Err(error) => return self.pause(error, "confirm", None),
        };
        if let Recovery::PersistBeforeDispatch(store) = &mut self.options.recovery {
            if let Err(error) = callback(
                || store.confirmed(&pending.identity, receipt),
                "confirmation-hook-panic",
            ) {
                return self.pause(error, "confirm", Some(receipt));
            }
        }
        let outcome = if event["event"] == "blocked" {
            RunnerEvent::Blocked {
                input: Some(pending.input),
                receipt: Some(receipt),
            }
        } else if pending.purpose == Purpose::Commit {
            RunnerEvent::Committed {
                input: pending.input,
                receipt,
            }
        } else {
            RunnerEvent::Progress
        };
        self.pending = None;
        self.confirmed = None;
        self.paused = None;
        self.attempted = false;
        self.record(outcome)
    }
    fn attempt(&mut self) -> Result<Option<RunnerEvent>> {
        let pending = self
            .pending
            .clone()
            .ok_or_else(|| Error::new(ErrorKind::Closed, "no-pending-mutation"))?;
        if let Some(confirmed) = self.confirmed.clone() {
            return Ok(Some(self.accept(confirmed)));
        }
        if self.attempted {
            match self.bridge.confirmation(&pending) {
                Ok(Some(confirmed)) => return Ok(Some(self.accept(confirmed))),
                Ok(None) => {}
                Err(error) => return Ok(Some(self.pause(error, "observe-confirmation", None))),
            }
        }
        if self.stop.is_stopped() {
            return Ok(None);
        }
        if let Recovery::PersistBeforeDispatch(store) = &mut self.options.recovery {
            if let Err(error) =
                callback(|| store.before_dispatch(&pending), "persistence-hook-panic")
            {
                return Ok(Some(self.pause(error, "persist", None)));
            }
        }
        if self.stop.is_stopped() {
            return Ok(None);
        }
        self.attempted = true;
        match self.bridge.dispatch() {
            Ok(event) => Ok(Some(self.accept(event))),
            Err(error) => Ok(Some(self.pause(error, "dispatch", None))),
        }
    }
    fn handle(&mut self, event: &Value) -> Result<bool> {
        let (scope, failure, poison) = {
            let mut turn = Turn::new(&mut self.bridge, event, self.process, &self.stop)?;
            let scope = turn.scope;
            let handled = if self.stop.is_stopped() {
                Ok(())
            } else {
                callback(
                    || {
                        let input = &event["input"];
                        let kind = string(&input["kind"], "input-kind")?;
                        let position = counter(&input["position"], false)?;
                        let provenance = origin(self.process.realm(), &input["origin"])?;
                        let initializing = boolean(&event["initializing"], "initializing")?;
                        if matches!(kind, "cast" | "call" | "reply") {
                            let bytes = unhex(
                                string(&input["payload"], "input-payload")?,
                                turn.bridge.caps.message,
                            )?;
                            let value = decode(&*self.codec, &bytes, turn.bridge.caps.message)?;
                            let incoming = match kind {
                                "cast" => Incoming::Cast {
                                    value,
                                    position,
                                    origin: provenance,
                                },
                                "call" => Incoming::Call {
                                    value,
                                    position,
                                    origin: provenance,
                                    correlation: Correlation::new(wide(&input["correlation"])?)?,
                                },
                                _ => Incoming::Reply(Reply {
                                    value,
                                    position,
                                    origin: provenance,
                                    correlation: Correlation::new(wide(&input["correlation"])?)?,
                                }),
                            };
                            if initializing {
                                self.handler.initialize(&mut turn)?;
                            }
                            if !self.stop.is_stopped() {
                                self.handler.handle(&mut turn, incoming)?;
                            }
                        } else {
                            let correlation = Correlation::new(wide(&input["correlation"])?)?;
                            if !matches!(kind, "result_complete" | "cancel" | "timeout") {
                                return Err(Error::new(
                                    ErrorKind::Handler,
                                    "unsupported-native-input",
                                ));
                            }
                            if initializing {
                                self.handler.initialize(&mut turn)?;
                            }
                            if !self.stop.is_stopped() {
                                if kind == "result_complete" {
                                    self.handler.handle_result(
                                        &mut turn,
                                        ResultComplete {
                                            position,
                                            origin: provenance,
                                            correlation,
                                        },
                                    )?;
                                } else {
                                    self.handler.handle_control(
                                        &mut turn,
                                        if kind == "cancel" {
                                            Control::Cancel {
                                                position,
                                                origin: provenance,
                                                correlation,
                                            }
                                        } else {
                                            Control::Timeout {
                                                position,
                                                origin: provenance,
                                                correlation,
                                            }
                                        },
                                    )?;
                                }
                            }
                        }
                        Ok(())
                    },
                    "handler-panic",
                )
            };
            (scope, handled.err(), turn.poison.clone())
        };
        if self.stop.is_stopped() {
            self.bridge.discard(scope)?;
            return Ok(false);
        }
        if let Some(error) = poison {
            self.bridge.discard(scope)?;
            return Err(error);
        }
        match self.bridge.finish(scope, failure.is_some()) {
            Err(error)
                if self.options.failure == FailurePolicy::Stop
                    && error.code.as_deref() == Some("ForeignHandlerFailure")
                    && failure.is_some() =>
            {
                Err(failure.unwrap())
            }
            Err(error) => Err(error),
            Ok(()) => Ok(true),
        }
    }
    fn next(&mut self) -> Result<Option<RunnerEvent>> {
        if let Some(paused) = &self.paused {
            return Ok(Some(paused.clone()));
        }
        if self.stop.is_stopped() {
            return Ok(None);
        }
        if self.pending.is_some() {
            return self.attempt();
        }
        for _ in 0..16 {
            if self.stop.is_stopped() {
                return Ok(None);
            }
            let event = self.bridge.prepare()?;
            match string(&event["event"], "prepare-event")? {
                "pending" => {
                    self.pending = Some(self.bridge.pending(&event)?);
                    return self.attempt();
                }
                "idle" => return Ok(Some(self.record(RunnerEvent::Idle))),
                "blocked" => {
                    return Ok(Some(self.record(RunnerEvent::Blocked {
                        input: None,
                        receipt: None,
                    })));
                }
                "ready" => {
                    if !self.handle(&event)? {
                        return Ok(None);
                    }
                }
                "progress" => {}
                _ => return Err(Error::new(ErrorKind::IncompatibleNative, "prepare-event")),
            }
        }
        Ok(Some(self.record(RunnerEvent::Progress)))
    }
    fn evidence(&self) -> Shutdown {
        Shutdown {
            pending: self.pending.clone(),
            last_event: self.last_event.clone(),
        }
    }
}
/// Blocking controller. Mutable access owns one operation; its worker owns all
/// native calls, callbacks and destruction on the required stack.
pub struct Runner<M: 'static> {
    worker: Worker<State<M>>,
    stop: StopToken,
}
impl<M: 'static> Runner<M> {
    pub fn open(
        config: ServiceConfig,
        handler: impl Handler<M>,
        codec: impl Codec<M>,
        options: RunnerOptions,
    ) -> Result<Self> {
        let stop = StopToken::default();
        let worker_stop = stop.clone();
        let worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
            let bridge = Bridge::open(&config, options.failure)?;
            Ok(State {
                bridge,
                process: config.activation.process,
                handler: Box::new(handler),
                codec: Box::new(codec),
                options,
                stop: worker_stop,
                pending: None,
                confirmed: None,
                paused: None,
                attempted: false,
                last_event: None,
            })
        })?;
        Ok(Self { worker, stop })
    }
    pub fn stop_token(&self) -> StopToken {
        self.stop.clone()
    }
    pub fn stop(&self) {
        self.stop.stop();
    }
    pub fn next(&mut self) -> Result<Option<RunnerEvent>> {
        self.worker.call(State::next)
    }
    pub fn reconcile(&mut self) -> Result<Option<RunnerEvent>> {
        self.worker.call(State::attempt)
    }
    pub fn evidence(&mut self) -> Result<Shutdown> {
        self.worker.call(|state| Ok(state.evidence()))
    }
    pub(crate) fn http_read(&mut self, action: Value) -> Result<Value> {
        self.worker.call(move |state| {
            if state.pending.is_some() {
                return Err(Error::new(ErrorKind::Busy, "pending-mutation"));
            }
            state.bridge.http_read(action)
        })
    }
    pub fn open_http(
        &mut self,
        outcome: &crate::HttpOutcome,
        policy: crate::HttpReplayPolicy,
    ) -> Result<crate::HttpReader<'_, M>> {
        if outcome.phase != crate::HttpPhase::Observed {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "http-incomplete-outcome",
            ));
        }
        let reference = outcome
            .reference()
            .ok_or_else(|| Error::new(ErrorKind::InvalidArgument, "http-reference"))?;
        let action = json!({"open":{"reference":transit_client::internal::hex(reference,256)?,
            "policy":match policy { crate::HttpReplayPolicy::Captured => "captured", crate::HttpReplayPolicy::RequireUnredacted => "require_unredacted" }}});
        let realm = outcome.resource.realm();
        let identity = self.worker.call(move |state| {
            if state.process.realm() != realm {
                return Err(Error::new(ErrorKind::InvalidArgument, "http-realm"));
            }
            if state.pending.is_some() {
                return Err(Error::new(ErrorKind::Busy, "pending-mutation"));
            }
            let result = state.bridge.http_read(action)?;
            number(&result["opened"], "http-reader", false)
        })?;
        Ok(crate::HttpReader::new(self, identity))
    }
    pub(crate) fn document_read(&mut self, realm: u64, action: Value) -> Result<Value> {
        self.worker.call(move |state| {
            if state.pending.is_some() {
                return Err(Error::new(ErrorKind::Busy, "pending-mutation"));
            }
            if realm != state.process.realm() {
                return Err(Error::new(ErrorKind::InvalidArgument, "document-realm"));
            }
            state.bridge.document_read(action)
        })
    }
    pub(crate) fn document_codec(&mut self, action: Value) -> Result<Value> {
        self.worker
            .call(move |state| state.bridge.document_codec(action))
    }
    pub fn documents(&mut self) -> Result<crate::DocumentReader<'_, M>> {
        let realm = self.worker.call(|state| Ok(state.process.realm()))?;
        Ok(crate::DocumentReader {
            runner: self,
            realm,
        })
    }
    pub(crate) fn grpc_read(&mut self, action: Value) -> Result<Value> {
        self.worker.call(move |state| {
            if state.pending.is_some() {
                return Err(Error::new(ErrorKind::Busy, "pending-mutation"));
            }
            state.bridge.grpc_read(action)
        })
    }
    pub fn open_grpc(
        &mut self,
        outcome: &crate::GrpcOutcome,
        policy: crate::GrpcReplayPolicy,
    ) -> Result<crate::GrpcReader<'_, M>> {
        if outcome.phase != crate::GrpcPhase::Observed {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "grpc-incomplete-outcome",
            ));
        }
        let reference = outcome
            .reference()
            .ok_or_else(|| Error::new(ErrorKind::InvalidArgument, "grpc-reference"))?;
        let action = json!({"open":{"reference":transit_client::internal::hex(reference,256)?,
            "policy":match policy { crate::GrpcReplayPolicy::Captured => "captured", crate::GrpcReplayPolicy::RequireUnredacted => "require_unredacted" }}});
        let realm = outcome.resource.realm();
        let identity = self.worker.call(move |state| {
            if state.process.realm() != realm {
                return Err(Error::new(ErrorKind::InvalidArgument, "grpc-realm"));
            }
            if state.pending.is_some() {
                return Err(Error::new(ErrorKind::Busy, "pending-mutation"));
            }
            let result = state.bridge.grpc_read(action)?;
            number(&result["opened"], "grpc-reader", false)
        })?;
        Ok(crate::GrpcReader::new(self, identity))
    }
    pub fn close(mut self) -> std::result::Result<Shutdown, CloseError> {
        self.stop();
        let evidence = self.evidence().map_err(|error| CloseError {
            error,
            evidence: None,
        })?;
        self.worker.close().map_err(|error| CloseError {
            error,
            evidence: Some(evidence.clone()),
        })?;
        Ok(evidence)
    }
}
impl<M: 'static> Drop for Runner<M> {
    fn drop(&mut self) {
        self.stop.stop();
    }
}
