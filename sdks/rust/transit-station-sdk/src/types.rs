use std::{fmt, path::PathBuf, sync::Arc};
use transit_client::internal::{MAX_BODY, VALUE_BYTES};
use transit_client::{
    ClientConfig, Correlation, Counter, Credential, Error, ErrorKind, MutationReceipt,
    OperationIdentity, ProcessRef, ResourceRef, Result,
};

pub trait Codec<T>: Send + Sync + 'static {
    fn type_id(&self) -> &str;
    fn version(&self) -> u32;
    fn max_encoded_bytes(&self) -> usize;
    fn encode(&self, value: &T) -> Result<Vec<u8>>;
    fn decode(&self, bytes: &[u8]) -> Result<T>;
}
fn codec_bound<T: 'static>(codec: &dyn Codec<T>, bound: usize) -> Result<usize> {
    let size = codec.max_encoded_bytes();
    if codec.type_id().is_empty()
        || codec.type_id().len() > MAX_BODY
        || codec.version() == 0
        || size == 0
        || size > bound
    {
        return Err(Error::new(ErrorKind::Codec, "codec-contract"));
    }
    Ok(size)
}
pub(crate) fn encode<T: 'static>(codec: &dyn Codec<T>, value: &T, bound: usize) -> Result<Vec<u8>> {
    let size = codec_bound(codec, bound)?;
    let bytes = codec
        .encode(value)
        .map_err(|_| Error::new(ErrorKind::Codec, "encode"))?;
    if bytes.len() > size {
        return Err(Error::new(ErrorKind::Codec, "encode-bound"));
    }
    Ok(bytes)
}
pub(crate) fn decode<T: 'static>(codec: &dyn Codec<T>, bytes: &[u8], bound: usize) -> Result<T> {
    if bytes.len() > codec_bound(codec, bound)? {
        return Err(Error::new(ErrorKind::Codec, "decode-bound"));
    }
    codec
        .decode(bytes)
        .map_err(|_| Error::new(ErrorKind::Codec, "decode"))
}
pub struct Key<T> {
    pub(crate) name: Box<[u8]>,
    pub(crate) codec: Arc<dyn Codec<T>>,
}
impl<T: 'static> Key<T> {
    pub fn new(name: &[u8], codec: impl Codec<T>) -> Result<Self> {
        if name.is_empty() || name[0] == 0 || name.len() > VALUE_BYTES {
            return Err(Error::new(ErrorKind::InvalidArgument, "application-key"));
        }
        Ok(Self {
            name: name.into(),
            codec: Arc::new(codec),
        })
    }
    pub fn name(&self) -> Box<[u8]> {
        self.name.clone()
    }
}
impl<T> Clone for Key<T> {
    fn clone(&self) -> Self {
        Self {
            name: self.name.clone(),
            codec: self.codec.clone(),
        }
    }
}
impl<T> fmt::Debug for Key<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("Key(application codec)")
    }
}
pub struct Found<T> {
    pub value: T,
}
impl<T> fmt::Debug for Found<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("Found(application value)")
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Basis {
    pub resource: ResourceRef,
    pub revision: Counter,
    pub schema: [u8; 32],
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Cursor(pub(crate) String);
impl Cursor {
    pub fn recover(value: &str) -> Result<Self> {
        if value.len() > MAX_BODY {
            return Err(Error::new(ErrorKind::InvalidArgument, "cursor-bound"));
        }
        Ok(Self(value.to_owned()))
    }
    pub fn export(&self) -> String {
        self.0.clone()
    }
}
pub struct Page<T> {
    pub entries: Vec<T>,
    pub next: Option<Cursor>,
    pub basis: Option<Basis>,
}
pub struct KvEntry {
    pub key: Box<[u8]>,
    pub value: Box<[u8]>,
    pub revision: Counter,
}
#[derive(Clone, Debug)]
pub struct Activation {
    pub(crate) process: ProcessRef,
    pub(crate) generation: Counter,
    pub(crate) credential: Credential,
}
impl Activation {
    pub fn new(
        process: ProcessRef,
        principal: u64,
        generation: u64,
        seed_file: impl Into<PathBuf>,
    ) -> Result<Self> {
        if generation == 0 {
            return Err(Error::new(ErrorKind::InvalidArgument, "activation"));
        }
        Ok(Self {
            process,
            generation: Counter::new(generation)?,
            credential: Credential::new(process.realm(), principal, seed_file)?,
        })
    }
    pub fn process(&self) -> ProcessRef {
        self.process
    }
    pub fn generation(&self) -> Counter {
        self.generation
    }
}
#[derive(Clone, Debug)]
pub struct ServiceConfig {
    pub(crate) client: ClientConfig,
    pub(crate) activation: Activation,
    pub(crate) association: String,
    pub(crate) query_results: bool,
}
impl ServiceConfig {
    pub fn new(client: ClientConfig, activation: Activation) -> Self {
        Self {
            client,
            activation,
            association: "data".into(),
            query_results: false,
        }
    }
    pub fn with_association(mut self, association: &str) -> Result<Self> {
        if association.is_empty() || association.len() > VALUE_BYTES {
            return Err(Error::new(ErrorKind::InvalidArgument, "association"));
        }
        self.association = association.to_owned();
        Ok(self)
    }
    pub fn with_query_results(mut self, enabled: bool) -> Self {
        self.query_results = enabled;
        self
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FailurePolicy {
    Stop,
    BlockInput,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum WaitPolicy {
    Untimed,
    Until {
        deadline_ms: Counter,
        observer: Counter,
    },
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Origin {
    External {
        principal: Counter,
        policy_revision: Counter,
    },
    Process {
        process: ProcessRef,
        turn: Counter,
        output: Counter,
    },
    Effect {
        effect: Counter,
        attempt: Counter,
        executor: Counter,
    },
}
pub struct Reply<T> {
    pub value: T,
    pub position: Counter,
    pub origin: Origin,
    pub correlation: Correlation,
}
pub enum Incoming<T> {
    Cast {
        value: T,
        position: Counter,
        origin: Origin,
    },
    Call {
        value: T,
        position: Counter,
        origin: Origin,
        correlation: Correlation,
    },
    Reply(Reply<T>),
}
#[derive(Clone, Debug)]
pub enum Control {
    Cancel {
        position: Counter,
        origin: Origin,
        correlation: Correlation,
    },
    Timeout {
        position: Counter,
        origin: Origin,
        correlation: Correlation,
    },
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Purpose {
    Permit,
    Open,
    Commit,
}
impl Purpose {
    pub(crate) fn native(self) -> &'static str {
        match self {
            Self::Permit => "permit",
            Self::Open => "open",
            Self::Commit => "commit",
        }
    }
}
#[derive(Clone)]
pub struct FrozenMutation {
    pub(crate) identity: OperationIdentity,
    pub(crate) purpose: Purpose,
    pub(crate) input: Counter,
    pub(crate) bytes: Box<[u8]>,
}
impl FrozenMutation {
    pub fn identity(&self) -> &OperationIdentity {
        &self.identity
    }
    pub fn purpose(&self) -> Purpose {
        self.purpose
    }
    pub fn input_position(&self) -> Counter {
        self.input
    }
    pub fn export(&self) -> Box<[u8]> {
        self.bytes.clone()
    }
}
impl fmt::Debug for FrozenMutation {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FrozenMutation")
            .field("identity", &self.identity)
            .field("purpose", &self.purpose)
            .field("input", &self.input)
            .finish_non_exhaustive()
    }
}
pub trait RecoveryStore: Send + 'static {
    fn before_dispatch(&mut self, mutation: &FrozenMutation) -> Result<()>;
    fn confirmed(&mut self, identity: &OperationIdentity, receipt: MutationReceipt) -> Result<()>;
}
pub enum Recovery {
    FenceOnRestart,
    PersistBeforeDispatch(Box<dyn RecoveryStore>),
}
pub struct RunnerOptions {
    pub failure: FailurePolicy,
    pub recovery: Recovery,
}
#[derive(Clone, Debug)]
pub enum RunnerEvent {
    Committed {
        input: Counter,
        receipt: MutationReceipt,
    },
    Blocked {
        input: Option<Counter>,
        receipt: Option<MutationReceipt>,
    },
    NeedsRecovery {
        mutation: FrozenMutation,
        phase: &'static str,
        error: Error,
        receipt: Option<MutationReceipt>,
    },
    Idle,
    Progress,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ReadVersion {
    pub pid: Counter,
    pub input: Counter,
    pub index: u8,
}
#[derive(Clone, Copy, Debug)]
pub struct Budgets {
    pub mutations: usize,
    pub outputs: usize,
    pub views: usize,
    pub retained_reads: usize,
    pub retains: usize,
    pub releases: usize,
}
