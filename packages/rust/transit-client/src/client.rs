use crate::{
    AdmissionReceipt, Capabilities, ClientConfig, Counter, Credential, Error, ErrorKind,
    MutationReceipt, OperationIdentity, ProcessRef, Result, Sequence, abi,
    native::{Native, hex, number, string},
    worker::Worker,
};
use serde_json::{Value, json};
use std::fmt;

#[derive(Clone, Debug)]
pub struct MutationInfo {
    pub identity: OperationIdentity,
    pub realm: Counter,
    pub principal: Counter,
    pub sequence: Sequence,
    pub command: String,
}
#[derive(Clone, Debug)]
pub struct SendInfo {
    pub mutation: MutationInfo,
    pub peer: ProcessRef,
}
pub struct PendingSend {
    info: SendInfo,
    bytes: Box<[u8]>,
}
pub struct PendingMutation {
    info: MutationInfo,
    bytes: Box<[u8]>,
}
impl PendingSend {
    pub fn info(&self) -> &SendInfo {
        &self.info
    }
    pub fn identity(&self) -> &OperationIdentity {
        &self.info.mutation.identity
    }
    pub fn export(&self) -> Box<[u8]> {
        self.bytes.clone()
    }
}
impl PendingMutation {
    pub fn info(&self) -> &MutationInfo {
        &self.info
    }
    pub fn identity(&self) -> &OperationIdentity {
        &self.info.identity
    }
    pub fn export(&self) -> Box<[u8]> {
        self.bytes.clone()
    }
}
impl fmt::Debug for PendingSend {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PendingSend")
            .field("info", &self.info)
            .finish_non_exhaustive()
    }
}
impl fmt::Debug for PendingMutation {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PendingMutation")
            .field("info", &self.info)
            .finish_non_exhaustive()
    }
}

pub enum DispatchError {
    Preflight(Error),
    Rejected(Error),
    Uncertain { cause: Error, recovery: Box<[u8]> },
}
impl fmt::Debug for DispatchError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Preflight(error) => f.debug_tuple("Preflight").field(error).finish(),
            Self::Rejected(error) => f.debug_tuple("Rejected").field(error).finish(),
            Self::Uncertain { cause, .. } => f
                .debug_struct("Uncertain")
                .field("cause", cause)
                .finish_non_exhaustive(),
        }
    }
}
impl fmt::Display for DispatchError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Debug::fmt(self, f)
    }
}
impl std::error::Error for DispatchError {}
fn classify(error: Error, bytes: &[u8]) -> DispatchError {
    match error.kind {
        ErrorKind::Rejected
        | ErrorKind::AccessDenied
        | ErrorKind::StaleOwnership
        | ErrorKind::ProcessRetired
        | ErrorKind::HistoryUnavailable => DispatchError::Rejected(error),
        ErrorKind::UnknownOutcome | ErrorKind::WorkerPanic => DispatchError::Uncertain {
            cause: error,
            recovery: bytes.into(),
        },
        _ => DispatchError::Preflight(error),
    }
}
pub(crate) fn info(value: &Value) -> Result<MutationInfo> {
    if value["version"] != 1
        || value["profile"] != "growing_v3"
        || value["kind"] != "growing_command"
    {
        return Err(Error::new(
            ErrorKind::UnsupportedCapability,
            "mutation-metadata",
        ));
    }
    let sequence_text = string(&value["sequence"], "metadata")?;
    let sequence = sequence_text
        .parse::<u64>()
        .ok()
        .filter(|value| value.to_string() == sequence_text)
        .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "metadata"))?;
    let command = string(&value["command"], "metadata")?;
    if command.is_empty() || command.len() > 64 {
        return Err(Error::new(ErrorKind::IncompatibleNative, "metadata"));
    }
    Ok(MutationInfo {
        identity: OperationIdentity::new(string(&value["identity"], "metadata")?)?,
        realm: Counter::new(number(&value["realm"], "metadata", false)?)?,
        principal: Counter::new(number(&value["principal"], "metadata", true)?)?,
        sequence: Sequence::new(sequence)?,
        command: command.to_owned(),
    })
}
fn recover_send(native: &Native, bytes: Box<[u8]>) -> Result<PendingSend> {
    let value = native.metadata(&bytes)?;
    let mutation = info(&value)?;
    if mutation.command != "send" {
        return Err(Error::new(
            ErrorKind::UnsupportedCapability,
            "send-metadata",
        ));
    }
    let peer = ProcessRef::new(
        mutation.realm.get(),
        number(&value["destination"], "metadata", false)?,
    )?;
    Ok(PendingSend {
        info: SendInfo { mutation, peer },
        bytes,
    })
}
fn bounded(bytes: &[u8], bound: usize) -> Result<Box<[u8]>> {
    if bytes.len() > bound {
        return Err(Error::new(ErrorKind::InvalidArgument, "byte-bound"));
    }
    Ok(bytes.into())
}
#[derive(Clone, Debug)]
pub struct ClientShutdown {
    pub last_admission: Option<AdmissionReceipt>,
    pub last_mutation: Option<MutationReceipt>,
}
pub struct Client {
    worker: Worker<Native>,
    last: ClientShutdown,
}
impl Client {
    pub fn open(config: ClientConfig) -> Result<Self> {
        let worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || Native::open(&config))?;
        Ok(Self {
            worker,
            last: ClientShutdown {
                last_admission: None,
                last_mutation: None,
            },
        })
    }
    pub fn capabilities(&mut self, credential: &Credential) -> Result<Capabilities> {
        let credential = credential.clone();
        self.worker
            .call(move |native| native.capabilities(&credential))
    }
    pub fn prepare_send(
        &mut self,
        peer: ProcessRef,
        bytes: &[u8],
        credential: &Credential,
        sequence: Sequence,
    ) -> Result<PendingSend> {
        if peer.realm() != credential.realm() {
            return Err(Error::new(ErrorKind::InvalidArgument, "send-realm"));
        }
        let bytes = bounded(bytes, abi::VALUE_BYTES)?;
        let credential = credential.clone();
        self.worker.call(move |native| {
            let operation = native.prepare(6, &credential, &json!({"realm":credential.realm(), "principal":credential.principal(), "sequence":sequence.get(),
                "command":{"send":{"pid":peer.pid(), "value":hex(&bytes, abi::VALUE_BYTES)?}}}))?;
            recover_send(native, operation.into_boxed_slice())
        })
    }
    pub fn recover_send(&mut self, bytes: &[u8]) -> Result<PendingSend> {
        let bytes = bounded(bytes, abi::MAX_BODY)?;
        self.worker.call(move |native| recover_send(native, bytes))
    }
    pub fn recover_mutation(&mut self, bytes: &[u8]) -> Result<PendingMutation> {
        let bytes = bounded(bytes, abi::MAX_BODY)?;
        self.worker.call(move |native| {
            Ok(PendingMutation {
                info: info(&native.metadata(&bytes)?)?,
                bytes,
            })
        })
    }
    pub fn dispatch(
        &mut self,
        pending: &PendingSend,
    ) -> std::result::Result<AdmissionReceipt, DispatchError> {
        self.last.last_admission = None;
        let bytes = pending.export();
        let result = self
            .worker
            .call(move |native| {
                let info = info(&native.metadata(&bytes)?)?;
                if info.command != "send" {
                    return Err(Error::new(
                        ErrorKind::UnsupportedCapability,
                        "send-metadata",
                    ));
                }
                let value = native.call(&bytes, true)?;
                number(&value["position"], "receipt", false)
                    .and_then(Counter::positive)
                    .map(|position| AdmissionReceipt { position })
                    .map_err(|_| Error::new(ErrorKind::UnknownOutcome, "receipt"))
            })
            .map_err(|error| classify(error, &pending.bytes))?;
        self.last.last_admission = Some(result);
        Ok(result)
    }
    pub fn dispatch_mutation(
        &mut self,
        pending: &PendingMutation,
    ) -> std::result::Result<MutationReceipt, DispatchError> {
        self.last.last_mutation = None;
        let bytes = pending.export();
        let result = self
            .worker
            .call(move |native| {
                info(&native.metadata(&bytes)?)?;
                let value = native.call(&bytes, true)?;
                number(&value["position"], "receipt", false)
                    .and_then(Counter::positive)
                    .map(|position| MutationReceipt { position })
                    .map_err(|_| Error::new(ErrorKind::UnknownOutcome, "receipt"))
            })
            .map_err(|error| classify(error, &pending.bytes))?;
        self.last.last_mutation = Some(result);
        Ok(result)
    }
    pub fn last_receipt(&self) -> Option<AdmissionReceipt> {
        self.last.last_admission
    }
    pub fn last_mutation_receipt(&self) -> Option<MutationReceipt> {
        self.last.last_mutation
    }
    pub fn close(mut self) -> Result<ClientShutdown> {
        self.worker.close()?;
        Ok(self.last.clone())
    }
}
