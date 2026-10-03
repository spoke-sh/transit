//! Typed RPC values; the shared Zig connector owns commitments and lifecycle.
use crate::{
    Codec, Runner,
    bridge::{counter, field, grpc_codec, wide},
};
use serde_json::{Value, json};
use std::{
    fmt,
    path::{Path, PathBuf},
};
use transit_client::internal::{boolean, hex, number, string, unhex};
use transit_client::{Counter, Error, ErrorKind, ResourceRef, Result};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GrpcShape {
    Unary,
    ServerStreaming,
    ClientStreaming,
    Bidi,
}
impl GrpcShape {
    fn wire(self) -> &'static str {
        match self {
            Self::Unary => "unary",
            Self::ServerStreaming => "server_streaming",
            Self::ClientStreaming => "client_streaming",
            Self::Bidi => "bidi",
        }
    }
}
#[derive(Clone, Debug)]
pub struct GrpcMethod {
    pub path: String,
    pub shape: GrpcShape,
    pub descriptor_digest: [u8; 32],
}
#[derive(Clone)]
pub enum GrpcMetadataValue {
    Literal(Vec<u8>),
    Secret { binding: String, version: u64 },
}
#[derive(Clone)]
pub struct GrpcMetadata {
    pub name: String,
    pub value: GrpcMetadataValue,
}
#[derive(Clone)]
pub struct GrpcRequest {
    pub method: GrpcMethod,
    pub metadata: Vec<GrpcMetadata>,
}
impl GrpcRequest {
    fn wire(&self) -> Result<Value> {
        if self.metadata.len() > 64 || self.method.path.len() > 512 {
            return Err(Error::new(ErrorKind::InvalidArgument, "grpc-request"));
        }
        let mut fields = Vec::with_capacity(self.metadata.len());
        for field in &self.metadata {
            if field.name.len() > 8192 {
                return Err(Error::new(ErrorKind::InvalidArgument, "grpc-metadata"));
            }
            let value = match &field.value {
                GrpcMetadataValue::Literal(bytes) => json!({"literal":hex(bytes,8192)?}),
                GrpcMetadataValue::Secret { binding, version }
                    if binding.len() <= 128 && *version != 0 =>
                {
                    json!({"secret":{"binding":binding,"version":version.to_string()}})
                }
                _ => return Err(Error::new(ErrorKind::InvalidArgument, "grpc-metadata")),
            };
            fields.push(json!({"name":field.name,"value":value}));
        }
        Ok(
            json!({"method":{"path":self.method.path,"shape":self.method.shape.wire(),"descriptor_digest":hex(&self.method.descriptor_digest,32)?},"metadata":fields}),
        )
    }
}
pub fn grpc_method(
    bytes: &[u8],
    path: &str,
    native_directory: Option<&Path>,
) -> Result<GrpcMethod> {
    let value = grpc_codec(
        json!({"descriptor":{"bytes":hex(bytes,65536)?,"method":path}}),
        native_directory,
        false,
    )?;
    let method = field(field(&value, "descriptor")?, "method")?;
    let shape = match string(&method["shape"], "grpc-shape")? {
        "unary" => GrpcShape::Unary,
        "server_streaming" => GrpcShape::ServerStreaming,
        "client_streaming" => GrpcShape::ClientStreaming,
        "bidi" => GrpcShape::Bidi,
        _ => return Err(Error::new(ErrorKind::IncompatibleNative, "grpc-shape")),
    };
    Ok(GrpcMethod {
        path: string(&method["path"], "grpc-path")?.to_owned(),
        shape,
        descriptor_digest: unhex(string(&method["descriptor_digest"], "grpc-digest")?, 32)?
            .try_into()
            .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "grpc-digest"))?,
    })
}
#[derive(Clone, Copy, Debug)]
pub struct GrpcRequestOptions {
    pub endpoint_revision: u64,
    pub reconcile_before_ms: Counter,
    pub max_attempts: u32,
}
#[derive(Clone)]
pub struct PreparedGrpcRequest {
    resource: ResourceRef,
    namespace: u64,
    reference: Box<[u8]>,
    metadata: Box<[u8]>,
    batch: Box<[u8]>,
}
impl PreparedGrpcRequest {
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
    pub fn batch(&self) -> &[u8] {
        &self.batch
    }
    pub(crate) fn wire(&self) -> Result<Value> {
        Ok(
            json!({"reference":hex(&self.reference,145)?,"metadata":hex(&self.metadata,8192)?,"batch":hex(&self.batch,65544)?}),
        )
    }
}
impl fmt::Debug for PreparedGrpcRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("PreparedGrpcRequest(owned bytes)")
    }
}
pub fn prepare_grpc(
    resource: ResourceRef,
    namespace: u64,
    request: &GrpcRequest,
    messages: &[&[u8]],
    options: GrpcRequestOptions,
    native_directory: Option<&Path>,
) -> Result<PreparedGrpcRequest> {
    if namespace == 0 || options.endpoint_revision == 0 || options.max_attempts == 0 {
        return Err(Error::new(
            ErrorKind::InvalidArgument,
            "grpc-request-identity",
        ));
    }
    if messages.len() > 64 {
        return Err(Error::new(ErrorKind::InvalidArgument, "grpc-messages"));
    }
    let messages = messages
        .iter()
        .map(|bytes| hex(bytes, 16384))
        .collect::<Result<Vec<_>>>()?;
    let value = grpc_codec(
        json!({"prepare":{"resource":resource.resource(),"namespace":namespace.to_string(),
        "request":request.wire()?,"messages":messages,"endpoint_revision":options.endpoint_revision.to_string(),
        "reconcile_before_ms":options.reconcile_before_ms.get(),"max_attempts":options.max_attempts}}),
        native_directory,
        false,
    )?;
    let prepared = field(&value, "prepared")?;
    Ok(PreparedGrpcRequest {
        resource,
        namespace,
        reference: unhex(string(&prepared["reference"], "grpc-reference")?, 145)?
            .into_boxed_slice(),
        metadata: unhex(string(&prepared["metadata"], "grpc-metadata")?, 8192)?.into_boxed_slice(),
        batch: unhex(string(&prepared["batch"], "grpc-batch")?, 65544)?.into_boxed_slice(),
    })
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GrpcPhase {
    Observed,
    ClosedUnknown,
    NotDispatched,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GrpcRejection {
    Denied,
    InvalidRequest,
    Busy,
}
#[derive(Clone)]
pub struct GrpcOutcome {
    pub phase: GrpcPhase,
    pub resource: ResourceRef,
    pub exchange: u64,
    pub effect: Counter,
    pub attempt: Counter,
    pub status: Option<u32>,
    pub(crate) reference: Option<Box<[u8]>>,
    pub diagnostic: Value,
}
impl GrpcOutcome {
    pub fn reference(&self) -> Option<&[u8]> {
        self.reference.as_deref()
    }
}
impl fmt::Debug for GrpcOutcome {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("GrpcOutcome")
            .field("phase", &self.phase)
            .finish_non_exhaustive()
    }
}
#[derive(Clone, Debug)]
pub struct GrpcRejected {
    pub reason: GrpcRejection,
    pub diagnostic: Value,
}
#[derive(Clone, Debug)]
pub enum GrpcReply {
    Outcome(GrpcOutcome),
    Rejected(GrpcRejected),
    Released(GrpcReleased),
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct GrpcReleased {
    pub resource: ResourceRef,
    pub exchange: u64,
}
pub fn decode_grpc_reply(
    realm: u64,
    bytes: &[u8],
    native_directory: Option<&Path>,
) -> Result<GrpcReply> {
    let invalid = || Error::new(ErrorKind::IncompatibleNative, "grpc-outcome");
    let value = grpc_codec(
        json!({"outcome":hex(bytes,73)?}),
        native_directory,
        bytes.starts_with(b"GRK1"),
    )?;
    if let Some(rejected) = value.get("rejected") {
        return Ok(GrpcReply::Rejected(GrpcRejected {
            reason: match string(field(rejected, "reason")?, "grpc-rejection")? {
                "denied" => GrpcRejection::Denied,
                "invalid_request" => GrpcRejection::InvalidRequest,
                "busy" => GrpcRejection::Busy,
                _ => return Err(invalid()),
            },
            diagnostic: field(rejected, "diagnostic")?.clone(),
        }));
    }
    if let Some(released) = value.get("released") {
        return Ok(GrpcReply::Released(GrpcReleased {
            resource: ResourceRef::new(
                realm,
                number(&released["resource"], "grpc-resource", false)?,
            )?,
            exchange: wide(&released["exchange"])?,
        }));
    }
    let value = field(&value, "outcome")?;
    Ok(GrpcReply::Outcome(GrpcOutcome {
        phase: match string(&value["phase"], "grpc-phase")? {
            "observed" => GrpcPhase::Observed,
            "closed_unknown" => GrpcPhase::ClosedUnknown,
            "not_dispatched" => GrpcPhase::NotDispatched,
            _ => return Err(invalid()),
        },
        resource: ResourceRef::new(realm, number(&value["resource"], "grpc-resource", false)?)?,
        exchange: wide(&value["exchange"])?,
        effect: counter(&value["effect"], true)?,
        attempt: counter(&value["attempt"], true)?,
        status: if value["status"].is_null() {
            None
        } else {
            Some(
                u32::try_from(number(&value["status"], "grpc-status", true)?)
                    .map_err(|_| invalid())?,
            )
        },
        diagnostic: field(value, "diagnostic")?.clone(),
        reference: if value["reference"].is_null() {
            None
        } else {
            Some(unhex(string(&value["reference"], "grpc-reference")?, 256)?.into_boxed_slice())
        },
    }))
}
pub enum GrpcMessage<T> {
    Application(T),
    Reply(GrpcReply),
}
pub struct GrpcReplyCodec<T> {
    application: Box<dyn Codec<T>>,
    realm: u64,
    directory: Option<PathBuf>,
    type_id: String,
}
impl<T: 'static> GrpcReplyCodec<T> {
    pub fn new(
        application: impl Codec<T>,
        realm: u64,
        native_directory: Option<PathBuf>,
    ) -> Result<Self> {
        Counter::new(realm)?;
        let type_id = format!("transit.grpc.reply+{}", application.type_id());
        Ok(Self {
            application: Box::new(application),
            realm,
            directory: native_directory,
            type_id,
        })
    }
}
impl<T: 'static> Codec<GrpcMessage<T>> for GrpcReplyCodec<T> {
    fn type_id(&self) -> &str {
        &self.type_id
    }
    fn version(&self) -> u32 {
        1
    }
    fn max_encoded_bytes(&self) -> usize {
        self.application.max_encoded_bytes().max(73)
    }
    fn encode(&self, value: &GrpcMessage<T>) -> Result<Vec<u8>> {
        match value {
            GrpcMessage::Application(value) => self.application.encode(value),
            GrpcMessage::Reply(_) => Err(Error::new(ErrorKind::Codec, "receive-only-grpc-outcome")),
        }
    }
    fn decode(&self, bytes: &[u8]) -> Result<GrpcMessage<T>> {
        if bytes.starts_with(b"GRR1") || bytes.starts_with(b"GRF1") || bytes.starts_with(b"GRK1") {
            Ok(GrpcMessage::Reply(decode_grpc_reply(
                self.realm,
                bytes,
                self.directory.as_deref(),
            )?))
        } else {
            Ok(GrpcMessage::Application(self.application.decode(bytes)?))
        }
    }
}
#[derive(Clone, Copy, Debug)]
pub enum GrpcReplayPolicy {
    Captured,
    RequireUnredacted,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GrpcPartKind {
    RequestMetadata,
    RequestBatch,
    EndpointPolicy,
    InitialMetadata,
    ResponseMessage,
    ResponseBody,
    HalfClose,
    Trailers,
    Timing,
    Omission,
    Completion,
}
pub struct GrpcPart {
    pub kind: GrpcPartKind,
    pub data: Box<[u8]>,
    pub complete: bool,
}
impl fmt::Debug for GrpcPart {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("GrpcPart")
            .field("kind", &self.kind)
            .field("complete", &self.complete)
            .finish_non_exhaustive()
    }
}
pub struct GrpcReader<'a, M: 'static> {
    runner: &'a mut Runner<M>,
    identity: u64,
    complete: bool,
    closed: bool,
}
impl<M: 'static> GrpcReader<'_, M> {
    pub(crate) fn new(runner: &mut Runner<M>, identity: u64) -> GrpcReader<'_, M> {
        GrpcReader {
            runner,
            identity,
            complete: false,
            closed: false,
        }
    }
    pub fn complete(&self) -> bool {
        self.complete
    }
    pub fn read(&mut self) -> Result<Option<GrpcPart>> {
        if self.closed {
            return Err(Error::new(ErrorKind::Closed, "grpc-reader"));
        }
        let value = self.runner.grpc_read(json!({"next":self.identity}))?;
        let part = field(&value, "part")?;
        if part.is_null() {
            if !self.complete {
                return Err(Error::new(ErrorKind::IncompatibleNative, "grpc-incomplete"));
            }
            return Ok(None);
        }
        let kind = match string(&part["kind"], "grpc-kind")? {
            "request_metadata" => GrpcPartKind::RequestMetadata,
            "request_batch" => GrpcPartKind::RequestBatch,
            "endpoint_policy" => GrpcPartKind::EndpointPolicy,
            "initial_metadata" => GrpcPartKind::InitialMetadata,
            "response_message" => GrpcPartKind::ResponseMessage,
            "response_body" => GrpcPartKind::ResponseBody,
            "half_close" => GrpcPartKind::HalfClose,
            "trailers" => GrpcPartKind::Trailers,
            "timing" => GrpcPartKind::Timing,
            "omission" => GrpcPartKind::Omission,
            "completion" => GrpcPartKind::Completion,
            _ => return Err(Error::new(ErrorKind::IncompatibleNative, "grpc-kind")),
        };
        let data = unhex(string(&part["bytes"], "grpc-bytes")?, 256)?.into_boxed_slice();
        self.complete = boolean(&part["complete"], "grpc-complete")?;
        Ok(Some(GrpcPart {
            kind,
            data,
            complete: self.complete,
        }))
    }
    pub fn close(&mut self) -> Result<()> {
        if !self.closed {
            let value = self.runner.grpc_read(json!({"close":self.identity}))?;
            if !boolean(&value["closed"], "grpc-close")? {
                return Err(Error::new(ErrorKind::IncompatibleNative, "grpc-close"));
            }
            self.closed = true;
        }
        Ok(())
    }
}
impl<M: 'static> Drop for GrpcReader<'_, M> {
    fn drop(&mut self) {
        let _ = self.close();
    }
}
