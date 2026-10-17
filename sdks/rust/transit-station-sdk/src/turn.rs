use crate::{
    Budgets, Codec, Correlation, Counter, Cursor, Found, Key, KvEntry, Page, ReadVersion, Reply,
    WaitPolicy,
    bridge::{Bridge, Caps, counter, field, size, wide},
    types::{decode, encode},
};
use serde_json::{Value, json};
use std::{marker::PhantomData, rc::Rc};
use transit_client::internal::{hex, number, string, unhex};
use transit_client::{Error, ErrorKind, ProcessRef, ResourceRef, Result, StopToken};

pub(crate) trait Access {
    fn check(&self) -> Result<()>;
    fn caps(&self) -> Caps;
    fn process(&self) -> ProcessRef;
    fn apply(&mut self, action: Value, read: bool) -> Result<Value>;
}
pub(crate) fn version(value: ReadVersion) -> Value {
    json!({"pid":value.pid.get(), "input":value.input.get(), "index":value.index})
}
pub(crate) fn read_version(value: &Value) -> Result<ReadVersion> {
    Ok(ReadVersion {
        pid: counter(&value["pid"], false)?,
        input: counter(&value["input"], false)?,
        index: u8::try_from(number(&value["index"], "read-version", true)?)
            .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "read-version"))?,
    })
}
fn key<T>(key: &Key<T>, caps: Caps) -> Result<String> {
    hex(&key.name, caps.key)
}
pub(crate) fn cursor(value: Option<&Cursor>) -> Value {
    value
        .map(|value| Value::String(value.0.clone()))
        .unwrap_or(Value::Null)
}
pub(crate) fn next(value: &Value) -> Result<Option<Cursor>> {
    if value.is_null() {
        Ok(None)
    } else {
        Cursor::recover(string(value, "cursor")?).map(Some)
    }
}

/// A private proposal borrowed only for one handler invocation. Neither Send nor Sync.
pub struct Turn<'a> {
    pub(crate) bridge: &'a mut Bridge,
    pub(crate) scope: u64,
    input: Value,
    process: ProcessRef,
    resource: ResourceRef,
    revision: Counter,
    stop: &'a StopToken,
    pub(crate) poison: Option<Error>,
    _local: PhantomData<Rc<()>>,
}
impl<'a> Turn<'a> {
    pub(crate) fn new(
        bridge: &'a mut Bridge,
        event: &Value,
        process: ProcessRef,
        stop: &'a StopToken,
    ) -> Result<Self> {
        if event["event"] != "ready" {
            return Err(Error::new(ErrorKind::IncompatibleNative, "ready-scope"));
        }
        Ok(Self {
            bridge,
            scope: number(&event["scope"], "scope", false)?,
            input: event["input"].clone(),
            process,
            resource: ResourceRef::new(
                process.realm(),
                number(&event["resource"], "resource", false)?,
            )?,
            revision: counter(&event["resource_revision"], true)?,
            stop,
            poison: None,
            _local: PhantomData,
        })
    }
    pub fn process(&self) -> ProcessRef {
        self.process
    }
    pub fn resource(&self) -> ResourceRef {
        self.resource
    }
    pub fn resource_revision(&self) -> Counter {
        self.revision
    }
    fn http_request(&self, request: &crate::PreparedHttpRequest) -> Result<()> {
        self.check()?;
        if request.resource() != self.resource {
            return Err(Error::new(ErrorKind::InvalidArgument, "http-resource"));
        }
        if !self.caps().http_requests {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "http-requests",
            ));
        }
        Ok(())
    }
    pub fn stage_http(&mut self, request: &crate::PreparedHttpRequest) -> Result<bool> {
        self.http_request(request)?;
        let value = self.apply(json!({"http_stage":request.wire()?}), false)?;
        transit_client::internal::boolean(&value["staged"], "http-staged")
    }
    pub fn call_http(
        &mut self,
        peer: ProcessRef,
        request: &crate::PreparedHttpRequest,
    ) -> Result<Correlation> {
        let pid = self.peer(peer)?;
        self.http_request(request)?;
        let value = self.apply(
            json!({"http_call":{"pid":pid,"reference":hex(request.reference(),112)?}}),
            false,
        )?;
        Correlation::new(wide(field(&value, "correlation")?)?)
    }
    /// Request durable hold disposal; authenticate the correlated HttpReleased reply.
    pub fn release_http(
        &mut self,
        peer: ProcessRef,
        resource: ResourceRef,
        exchange: u64,
    ) -> Result<Correlation> {
        let pid = self.peer(peer)?;
        if resource.realm() != self.resource.realm() || exchange == 0 {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "http-release-identity",
            ));
        }
        if !self.caps().http_release {
            return Err(Error::new(ErrorKind::UnsupportedCapability, "http-release"));
        }
        let value = self.apply(
            json!({"http_release":{"pid":pid,"resource":resource.resource(),"exchange":exchange.to_string()}}),
            false,
        )?;
        Correlation::new(wide(field(&value, "correlation")?)?)
    }
    pub fn state(&mut self) -> State<'_> {
        State {
            owner: self,
            retained: None,
        }
    }
    /// Submit an explicit linked attempt; the service decides current admission.
    pub fn followup_http(
        &mut self,
        peer: ProcessRef,
        parent: &crate::HttpOutcome,
        reason: crate::HttpFollowupReason,
        request: &crate::PreparedHttpRequest,
    ) -> Result<Correlation> {
        let pid = self.peer(peer)?;
        self.http_request(request)?;
        if parent.resource.realm() != self.resource.realm() || parent.exchange == 0 {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "http-followup-identity",
            ));
        }
        if !self.caps().http_followup {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "http-followup",
            ));
        }
        let value = self.apply(
            json!({"http_followup":{"pid":pid,"resource":parent.resource.resource(),"parent":parent.exchange.to_string(),"reason":reason.wire(),"reference":hex(request.reference(),112)?}}),
            false,
        )?;
        Correlation::new(wide(field(&value, "correlation")?)?)
    }
    fn grpc_request(&self, request: &crate::PreparedGrpcRequest) -> Result<()> {
        self.check()?;
        if request.resource() != self.resource {
            return Err(Error::new(ErrorKind::InvalidArgument, "grpc-resource"));
        }
        if !self.caps().grpc_requests {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "grpc-requests",
            ));
        }
        Ok(())
    }
    pub fn stage_grpc(&mut self, request: &crate::PreparedGrpcRequest) -> Result<bool> {
        self.grpc_request(request)?;
        let value = self.apply(json!({"grpc_stage":request.wire()?}), false)?;
        transit_client::internal::boolean(&value["staged"], "grpc-staged")
    }
    pub fn call_grpc(
        &mut self,
        peer: ProcessRef,
        request: &crate::PreparedGrpcRequest,
    ) -> Result<Correlation> {
        let pid = self.peer(peer)?;
        self.grpc_request(request)?;
        let value = self.apply(
            json!({"grpc_call":{"pid":pid,"reference":hex(request.reference(),145)?}}),
            false,
        )?;
        Correlation::new(wide(field(&value, "correlation")?)?)
    }
    /// Request durable hold disposal; authenticate the correlated GrpcReleased reply.
    pub fn release_grpc(
        &mut self,
        peer: ProcessRef,
        resource: ResourceRef,
        exchange: u64,
    ) -> Result<Correlation> {
        let pid = self.peer(peer)?;
        if resource.realm() != self.resource.realm() || exchange == 0 {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "grpc-release-identity",
            ));
        }
        if !self.caps().grpc_release {
            return Err(Error::new(ErrorKind::UnsupportedCapability, "grpc-release"));
        }
        let value = self.apply(
            json!({"grpc_release":{"pid":pid,"resource":resource.resource(),"exchange":exchange.to_string()}}),
            false,
        )?;
        Correlation::new(wide(field(&value, "correlation")?)?)
    }
    /// Submit an explicit linked attempt; the service decides current admission.
    pub fn retry_grpc(
        &mut self,
        peer: ProcessRef,
        parent: &crate::GrpcOutcome,
        request: &crate::PreparedGrpcRequest,
    ) -> Result<Correlation> {
        let pid = self.peer(peer)?;
        self.grpc_request(request)?;
        if parent.resource.realm() != self.resource.realm() || parent.exchange == 0 {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "grpc-followup-identity",
            ));
        }
        if !self.caps().grpc_followup {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "grpc-followup",
            ));
        }
        let value = self.apply(
            json!({"grpc_followup":{"pid":pid,"resource":parent.resource.resource(),"parent":parent.exchange.to_string(),"reference":hex(request.reference(),145)?}}),
            false,
        )?;
        Correlation::new(wide(field(&value, "correlation")?)?)
    }
    pub fn budgets(&mut self) -> Result<Budgets> {
        let value = self.apply(json!({"budgets":{}}), false)?;
        let value = field(&value, "budgets")?;
        Ok(Budgets {
            mutations: size(&value["mutations"], true)?,
            outputs: size(&value["outputs"], true)?,
            views: size(&value["views"], true)?,
            retained_reads: size(&value["retained_reads"], true)?,
            retains: size(&value["retains"], true)?,
            releases: size(&value["releases"], true)?,
        })
    }
    fn peer(&self, peer: ProcessRef) -> Result<u64> {
        self.check()?;
        if peer.realm() != self.process.realm() {
            return Err(Error::new(ErrorKind::InvalidArgument, "peer-realm"));
        }
        Ok(peer.pid())
    }
    pub fn cast<T: 'static>(
        &mut self,
        peer: ProcessRef,
        value: &T,
        codec: &dyn Codec<T>,
    ) -> Result<()> {
        let pid = self.peer(peer)?;
        let bytes = encode(codec, value, self.caps().message)?;
        self.apply(
            json!({"cast":{"pid":pid, "value":hex(&bytes, self.caps().message)?}}),
            false,
        )
        .map(|_| ())
    }
    pub fn call<T: 'static>(
        &mut self,
        peer: ProcessRef,
        value: &T,
        codec: &dyn Codec<T>,
        wait: WaitPolicy,
    ) -> Result<Correlation> {
        let pid = self.peer(peer)?;
        let bytes = encode(codec, value, self.caps().message)?;
        let (deadline, observer) = match wait {
            WaitPolicy::Untimed => (None, None),
            WaitPolicy::Until {
                deadline_ms,
                observer,
            } => (Some(deadline_ms.get()), Some(observer.get())),
        };
        let value = self.apply(json!({"call":{"pid":pid, "value":hex(&bytes, self.caps().message)?, "deadline_ms":deadline, "observer":observer}}), false)?;
        Correlation::new(wide(field(&value, "correlation")?)?)
    }
    pub fn reply<T: 'static>(&mut self, value: &T, codec: &dyn Codec<T>) -> Result<()> {
        self.check()?;
        let bytes = encode(codec, value, self.caps().message)?;
        self.apply(json!({"reply":hex(&bytes, self.caps().message)?}), false)
            .map(|_| ())
    }
    pub fn require_reply<T>(
        &self,
        reply: &Reply<T>,
        peer: ProcessRef,
        correlation: Correlation,
    ) -> Result<()> {
        let pid = self.peer(peer)?;
        if self.input["kind"] != "reply"
            || self.input["origin"]["process"]["pid"] != pid
            || wide(&self.input["correlation"])? != correlation.get()
            || self.input["position"] != reply.position.get()
            || reply.correlation != correlation
        {
            return Err(Error::new(ErrorKind::Handler, "reply-provenance"));
        }
        Ok(())
    }
    pub fn cancel_call(&mut self, correlation: Correlation) -> Result<bool> {
        let value = self.apply(json!({"cancel":correlation.get().to_string()}), false)?;
        field(&value, "cancelled")?
            .as_bool()
            .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "cancel"))
    }
    pub fn retain(&mut self) -> Result<ReadVersion> {
        let value = self.apply(json!({"retain":{}}), false)?;
        read_version(field(&value, "version")?)
    }
    pub fn open_version(&mut self, identity: ReadVersion) -> Result<Source<'_>> {
        self.check()?;
        Ok(Source {
            owner: self,
            identity,
        })
    }
    pub fn release(&mut self, identity: ReadVersion) -> Result<()> {
        self.apply(json!({"release":version(identity)}), false)
            .map(|_| ())
    }
}
impl Access for Turn<'_> {
    fn check(&self) -> Result<()> {
        if self.stop.is_stopped() {
            return Err(Error::new(ErrorKind::Closed, "local-stop"));
        }
        if let Some(error) = &self.poison {
            return Err(error.clone());
        }
        Ok(())
    }
    fn caps(&self) -> Caps {
        self.bridge.caps
    }
    fn process(&self) -> ProcessRef {
        self.process
    }
    fn apply(&mut self, action: Value, read: bool) -> Result<Value> {
        self.check()?;
        let result = self.bridge.apply(self.scope, &action);
        if read {
            if let Err(error) = &result {
                self.poison = Some(error.clone());
            }
        }
        result
    }
}
pub struct State<'a> {
    pub(crate) owner: &'a mut dyn Access,
    pub(crate) retained: Option<ReadVersion>,
}
impl State<'_> {
    pub fn find<T: 'static>(&mut self, name: &Key<T>) -> Result<Option<Found<T>>> {
        let key = key(name, self.owner.caps())?;
        let action = if let Some(id) = self.retained {
            json!({"version_get":{"id":version(id), "key":key}})
        } else {
            json!({"get":key})
        };
        let value = self.owner.apply(action, true)?;
        let value = field(&value, "value")?;
        if value.is_null() {
            return Ok(None);
        }
        let bytes = unhex(string(value, "state-value")?, self.owner.caps().value)?;
        Ok(Some(Found {
            value: decode(&*name.codec, &bytes, self.owner.caps().value)?,
        }))
    }
    pub fn require<T: 'static>(&mut self, name: &Key<T>) -> Result<T> {
        self.find(name)?
            .map(|found| found.value)
            .ok_or_else(|| Error::new(ErrorKind::MissingValue, "state-require"))
    }
    pub fn put<T: 'static>(&mut self, name: &Key<T>, value: &T) -> Result<()> {
        self.writable()?;
        let key = key(name, self.owner.caps())?;
        let bytes = encode(&*name.codec, value, self.owner.caps().value)?;
        self.owner
            .apply(
                json!({"put":{"key":key,"value":hex(&bytes, self.owner.caps().value)?}}),
                false,
            )
            .map(|_| ())
    }
    pub fn delete<T>(&mut self, name: &Key<T>) -> Result<()> {
        self.writable()?;
        self.owner
            .apply(json!({"delete":key(name, self.owner.caps())?}), false)
            .map(|_| ())
    }
    fn writable(&self) -> Result<()> {
        self.owner.check()?;
        if self.retained.is_some() {
            return Err(Error::new(ErrorKind::Handler, "retained-state-write"));
        }
        Ok(())
    }
    pub fn page(&mut self, after: Option<&Cursor>) -> Result<Page<KvEntry>> {
        let action = if let Some(id) = self.retained {
            json!({"version_page":{"id":version(id), "cursor":cursor(after)}})
        } else {
            json!({"page":cursor(after)})
        };
        let value = self.owner.apply(action, true)?;
        let page = field(&value, "page")?;
        let values = page["entries"]
            .as_array()
            .filter(|items| items.len() <= self.owner.caps().page)
            .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "page-bound"))?;
        let mut entries = Vec::with_capacity(values.len());
        for item in values.iter().filter(|value| !value.is_null()) {
            entries.push(KvEntry {
                key: unhex(string(&item["key"], "entry")?, self.owner.caps().key)?
                    .into_boxed_slice(),
                value: unhex(string(&item["value"], "entry")?, self.owner.caps().value)?
                    .into_boxed_slice(),
                revision: counter(&item["revision"], true)?,
            });
        }
        Ok(Page {
            entries,
            next: next(&page["next"])?,
            basis: None,
        })
    }
}
pub struct Source<'a> {
    pub(crate) owner: &'a mut dyn Access,
    pub(crate) identity: ReadVersion,
}
impl Source<'_> {
    pub fn identity(&self) -> ReadVersion {
        self.identity
    }
    pub fn state(&mut self) -> State<'_> {
        State {
            owner: self.owner,
            retained: Some(self.identity),
        }
    }
}
