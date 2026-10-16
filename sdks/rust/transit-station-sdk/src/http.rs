//! Typed HTTP values; the shared Zig connector owns commitments and lifecycle.
use crate::{
    Codec, Runner,
    bridge::{counter, field, http_codec, wide},
};
use serde_json::{Value, json};
use std::{
    fmt,
    path::{Path, PathBuf},
};
use transit_client::internal::{boolean, hex, number, string, unhex};
use transit_client::{Counter, Error, ErrorKind, ResourceRef, Result};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HttpMethod {
    Get,
    Head,
    Post,
    Put,
    Patch,
    Delete,
    Options,
}
impl HttpMethod {
    fn wire(self) -> &'static str {
        match self {
            Self::Get => "GET",
            Self::Head => "HEAD",
            Self::Post => "POST",
            Self::Put => "PUT",
            Self::Patch => "PATCH",
            Self::Delete => "DELETE",
            Self::Options => "OPTIONS",
        }
    }
}
#[derive(Clone)]
pub enum HttpPiece {
    Literal(String),
    Variable { name: String, value: String },
    Secret { binding: String, version: u64 },
}
#[derive(Clone)]
pub struct HttpHeader {
    pub name: String,
    pub value: Vec<HttpPiece>,
}
#[derive(Clone)]
pub struct HttpRequest {
    pub method: HttpMethod,
    pub target: Vec<HttpPiece>,
    pub headers: Vec<HttpHeader>,
}
fn pieces(values: &[HttpPiece]) -> Result<Value> {
    if values.len() > 128 {
        return Err(Error::new(ErrorKind::InvalidArgument, "http-pieces"));
    }
    let mut result = Vec::with_capacity(values.len());
    for value in values {
        let item = match value {
            HttpPiece::Literal(value) if value.len() <= 8192 => json!({"literal":value}),
            HttpPiece::Variable { name, value } if name.len() <= 128 && value.len() <= 8192 => {
                json!({"variable":{"name":name,"value":value}})
            }
            HttpPiece::Secret { binding, version } if binding.len() <= 128 && *version != 0 => {
                json!({"secret":{"binding":binding,"version":version.to_string()}})
            }
            _ => return Err(Error::new(ErrorKind::InvalidArgument, "http-piece")),
        };
        result.push(item);
    }
    Ok(Value::Array(result))
}
impl HttpRequest {
    fn wire(&self) -> Result<Value> {
        if self.headers.len() > 64 {
            return Err(Error::new(ErrorKind::InvalidArgument, "http-headers"));
        }
        let mut headers = Vec::with_capacity(self.headers.len());
        for header in &self.headers {
            if header.name.len() > 8192 {
                return Err(Error::new(ErrorKind::InvalidArgument, "http-header"));
            }
            headers.push(json!({"name":header.name,"value":pieces(&header.value)?}));
        }
        Ok(json!({"method":self.method.wire(),"target":pieces(&self.target)?,"headers":headers}))
    }
}
#[derive(Clone, Copy, Debug)]
pub struct HttpRequestOptions {
    pub endpoint_revision: u64,
    pub reconcile_before_ms: Counter,
    pub max_attempts: u32,
}
#[derive(Clone)]
pub struct PreparedHttpRequest {
    resource: ResourceRef,
    namespace: u64,
    reference: Box<[u8]>,
    metadata: Box<[u8]>,
    body: Box<[u8]>,
}
impl PreparedHttpRequest {
    pub fn resource(&self) -> ResourceRef {
        self.resource
    }
    pub fn namespace(&self) -> u64 {
        self.namespace
    }
    pub fn reference(&self) -> &[u8] {
        &self.reference
    }
    pub fn metadata(&self) -> &[u8] {
        &self.metadata
    }
    pub fn body(&self) -> &[u8] {
        &self.body
    }
    pub(crate) fn wire(&self) -> Result<Value> {
        Ok(
            json!({"reference":hex(&self.reference,112)?,"metadata":hex(&self.metadata,8192)?,"body":hex(&self.body,65536)?}),
        )
    }
}
impl fmt::Debug for PreparedHttpRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("PreparedHttpRequest(owned bytes)")
    }
}
pub fn prepare_http(
    resource: ResourceRef,
    namespace: u64,
    request: &HttpRequest,
    body: &[u8],
    options: HttpRequestOptions,
    native_directory: Option<&Path>,
) -> Result<PreparedHttpRequest> {
    if namespace == 0 || options.endpoint_revision == 0 || options.max_attempts == 0 {
        return Err(Error::new(
            ErrorKind::InvalidArgument,
            "http-request-identity",
        ));
    }
    let value = http_codec(
        json!({"prepare":{"resource":resource.resource(),"namespace":namespace.to_string(),
        "request":request.wire()?,"body":hex(body,65536)?,"endpoint_revision":options.endpoint_revision.to_string(),
        "reconcile_before_ms":options.reconcile_before_ms.get(),"max_attempts":options.max_attempts}}),
        native_directory,
        false,
    )?;
    let prepared = field(&value, "prepared")?;
    Ok(PreparedHttpRequest {
        resource,
        namespace,
        reference: unhex(string(&prepared["reference"], "http-reference")?, 112)?
            .into_boxed_slice(),
        metadata: unhex(string(&prepared["metadata"], "http-metadata")?, 8192)?.into_boxed_slice(),
        body: body.into(),
    })
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HttpPhase {
    Observed,
    ClosedUnknown,
    NotDispatched,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HttpFollowupReason {
    Retry,
    Redirect,
    Reconcile,
    Cancel,
}
impl HttpFollowupReason {
    pub(crate) fn wire(self) -> &'static str {
        match self {
            Self::Retry => "retry",
            Self::Redirect => "redirect",
            Self::Reconcile => "reconcile",
            Self::Cancel => "cancel",
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HttpRejection {
    Denied,
    InvalidRequest,
    Busy,
}
#[derive(Clone)]
pub struct HttpOutcome {
    pub phase: HttpPhase,
    pub resource: ResourceRef,
    pub exchange: u64,
    pub effect: Counter,
    pub attempt: Counter,
    pub status: Option<u16>,
    pub(crate) reference: Option<Box<[u8]>>,
    pub diagnostic: Value,
}
impl HttpOutcome {
    pub fn reference(&self) -> Option<&[u8]> {
        self.reference.as_deref()
    }
}
impl fmt::Debug for HttpOutcome {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("HttpOutcome")
            .field("phase", &self.phase)
            .finish_non_exhaustive()
    }
}
#[derive(Clone, Debug)]
pub struct HttpRejected {
    pub reason: HttpRejection,
    pub diagnostic: Value,
}
#[derive(Clone, Debug)]
pub enum HttpReply {
    Outcome(HttpOutcome),
    Rejected(HttpRejected),
    Released(HttpReleased),
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct HttpReleased {
    pub resource: ResourceRef,
    pub exchange: u64,
}
pub fn decode_http_reply(
    realm: u64,
    bytes: &[u8],
    native_directory: Option<&Path>,
) -> Result<HttpReply> {
    let invalid = || Error::new(ErrorKind::IncompatibleNative, "http-outcome");
    let value = http_codec(
        json!({"outcome":hex(bytes,232)?}),
        native_directory,
        bytes.starts_with(b"HTK1"),
    )?;
    if let Some(rejected) = value.get("rejected") {
        return Ok(HttpReply::Rejected(HttpRejected {
            reason: match string(field(rejected, "reason")?, "http-rejection")? {
                "denied" => HttpRejection::Denied,
                "invalid_request" => HttpRejection::InvalidRequest,
                "busy" => HttpRejection::Busy,
                _ => return Err(invalid()),
            },
            diagnostic: field(rejected, "diagnostic")?.clone(),
        }));
    }
    if let Some(released) = value.get("released") {
        return Ok(HttpReply::Released(HttpReleased {
            resource: ResourceRef::new(
                realm,
                number(&released["resource"], "http-resource", false)?,
            )?,
            exchange: wide(&released["exchange"])?,
        }));
    }
    let value = field(&value, "outcome")?;
    Ok(HttpReply::Outcome(HttpOutcome {
        phase: match string(&value["phase"], "http-phase")? {
            "observed" => HttpPhase::Observed,
            "closed_unknown" => HttpPhase::ClosedUnknown,
            "not_dispatched" => HttpPhase::NotDispatched,
            _ => return Err(invalid()),
        },
        resource: ResourceRef::new(realm, number(&value["resource"], "http-resource", false)?)?,
        exchange: wide(&value["exchange"])?,
        effect: counter(&value["effect"], true)?,
        attempt: counter(&value["attempt"], true)?,
        status: if value["status"].is_null() {
            None
        } else {
            Some(
                u16::try_from(number(&value["status"], "http-status", false)?)
                    .map_err(|_| invalid())?,
            )
        },
        diagnostic: field(value, "diagnostic")?.clone(),
        reference: if value["reference"].is_null() {
            None
        } else {
            Some(unhex(string(&value["reference"], "http-reference")?, 256)?.into_boxed_slice())
        },
    }))
}
pub enum HttpMessage<T> {
    Application(T),
    Reply(HttpReply),
}
pub struct HttpReplyCodec<T> {
    application: Box<dyn Codec<T>>,
    realm: u64,
    directory: Option<PathBuf>,
    type_id: String,
}
impl<T: 'static> HttpReplyCodec<T> {
    pub fn new(
        application: impl Codec<T>,
        realm: u64,
        native_directory: Option<PathBuf>,
    ) -> Result<Self> {
        Counter::new(realm)?;
        let type_id = format!("transit.http.reply+{}", application.type_id());
        Ok(Self {
            application: Box::new(application),
            realm,
            directory: native_directory,
            type_id,
        })
    }
}
impl<T: 'static> Codec<HttpMessage<T>> for HttpReplyCodec<T> {
    fn type_id(&self) -> &str {
        &self.type_id
    }
    fn version(&self) -> u32 {
        1
    }
    fn max_encoded_bytes(&self) -> usize {
        self.application.max_encoded_bytes().max(232)
    }
    fn encode(&self, value: &HttpMessage<T>) -> Result<Vec<u8>> {
        match value {
            HttpMessage::Application(value) => self.application.encode(value),
            HttpMessage::Reply(_) => Err(Error::new(ErrorKind::Codec, "receive-only-http-outcome")),
        }
    }
    fn decode(&self, bytes: &[u8]) -> Result<HttpMessage<T>> {
        if bytes.starts_with(b"HTR1") || bytes.starts_with(b"HTF1") || bytes.starts_with(b"HTK1") {
            Ok(HttpMessage::Reply(decode_http_reply(
                self.realm,
                bytes,
                self.directory.as_deref(),
            )?))
        } else {
            Ok(HttpMessage::Application(self.application.decode(bytes)?))
        }
    }
}
#[derive(Clone, Copy, Debug)]
pub enum HttpReplayPolicy {
    Captured,
    RequireUnredacted,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HttpPartKind {
    RequestTemplate,
    RequestHead,
    RequestBody,
    ResponseHead,
    ResponseBody,
    ResponseTrailers,
    Timing,
    Omission,
    Completion,
}
pub struct HttpPart {
    pub kind: HttpPartKind,
    pub data: Box<[u8]>,
    pub complete: bool,
}
impl fmt::Debug for HttpPart {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("HttpPart")
            .field("kind", &self.kind)
            .field("complete", &self.complete)
            .finish_non_exhaustive()
    }
}
pub struct HttpReader<'a, M: 'static> {
    runner: &'a mut Runner<M>,
    identity: u64,
    complete: bool,
    closed: bool,
}
impl<M: 'static> HttpReader<'_, M> {
    pub(crate) fn new(runner: &mut Runner<M>, identity: u64) -> HttpReader<'_, M> {
        HttpReader {
            runner,
            identity,
            complete: false,
            closed: false,
        }
    }
    pub fn complete(&self) -> bool {
        self.complete
    }
    pub fn read(&mut self) -> Result<Option<HttpPart>> {
        if self.closed {
            return Err(Error::new(ErrorKind::Closed, "http-reader"));
        }
        let value = self.runner.http_read(json!({"next":self.identity}))?;
        let part = field(&value, "part")?;
        if part.is_null() {
            if !self.complete {
                return Err(Error::new(ErrorKind::IncompatibleNative, "http-incomplete"));
            }
            return Ok(None);
        }
        let kind = match string(&part["kind"], "http-kind")? {
            "request_template" => HttpPartKind::RequestTemplate,
            "request_head" => HttpPartKind::RequestHead,
            "request_body" => HttpPartKind::RequestBody,
            "response_head" => HttpPartKind::ResponseHead,
            "response_body" => HttpPartKind::ResponseBody,
            "response_trailers" => HttpPartKind::ResponseTrailers,
            "timing" => HttpPartKind::Timing,
            "omission" => HttpPartKind::Omission,
            "completion" => HttpPartKind::Completion,
            _ => return Err(Error::new(ErrorKind::IncompatibleNative, "http-kind")),
        };
        let data = unhex(string(&part["bytes"], "http-bytes")?, 256)?.into_boxed_slice();
        self.complete = boolean(&part["complete"], "http-complete")?;
        Ok(Some(HttpPart {
            kind,
            data,
            complete: self.complete,
        }))
    }
    pub fn close(&mut self) -> Result<()> {
        if !self.closed {
            let value = self.runner.http_read(json!({"close":self.identity}))?;
            if !boolean(&value["closed"], "http-close")? {
                return Err(Error::new(ErrorKind::IncompatibleNative, "http-close"));
            }
            self.closed = true;
        }
        Ok(())
    }
}
impl<M: 'static> Drop for HttpReader<'_, M> {
    fn drop(&mut self) {
        let _ = self.close();
    }
}
