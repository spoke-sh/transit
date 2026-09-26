use crate::{Error, ErrorKind, Result, abi};
use std::{fmt, path::PathBuf};

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct Counter(u64);
impl Counter {
    pub fn new(value: u64) -> Result<Self> {
        if value > abi::MAX_COUNTER as u64 {
            return Err(Error::new(ErrorKind::InvalidArgument, "counter"));
        }
        Ok(Self(value))
    }
    pub fn get(self) -> u64 {
        self.0
    }
    pub(crate) fn positive(value: u64) -> Result<Self> {
        if value == 0 {
            return Err(Error::new(ErrorKind::InvalidArgument, "counter"));
        }
        Self::new(value)
    }
}
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct ProcessRef {
    realm: Counter,
    pid: Counter,
}
impl ProcessRef {
    pub fn new(realm: u64, pid: u64) -> Result<Self> {
        Ok(Self {
            realm: Counter::positive(realm)?,
            pid: Counter::positive(pid)?,
        })
    }
    pub fn realm(self) -> u64 {
        self.realm.get()
    }
    pub fn pid(self) -> u64 {
        self.pid.get()
    }
}
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct ResourceRef {
    realm: Counter,
    resource: Counter,
}
impl ResourceRef {
    pub fn new(realm: u64, resource: u64) -> Result<Self> {
        Ok(Self {
            realm: Counter::positive(realm)?,
            resource: Counter::positive(resource)?,
        })
    }
    pub fn realm(self) -> u64 {
        self.realm.get()
    }
    pub fn resource(self) -> u64 {
        self.resource.get()
    }
}
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct Sequence(Counter);
impl Sequence {
    pub fn new(value: u64) -> Result<Self> {
        Ok(Self(Counter::positive(value)?))
    }
    pub fn get(self) -> u64 {
        self.0.get()
    }
}
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct Correlation(std::num::NonZeroU64);
impl Correlation {
    pub fn new(value: u64) -> Result<Self> {
        std::num::NonZeroU64::new(value)
            .map(Self)
            .ok_or_else(|| Error::new(ErrorKind::InvalidArgument, "correlation"))
    }
    pub fn get(self) -> u64 {
        self.0.get()
    }
}
#[derive(Clone)]
pub struct Credential {
    realm: Counter,
    principal: Counter,
    seed_file: PathBuf,
}
impl Credential {
    pub fn new(realm: u64, principal: u64, seed_file: impl Into<PathBuf>) -> Result<Self> {
        let seed_file = seed_file.into();
        if seed_file.as_os_str().is_empty() || seed_file.as_os_str().len() > abi::MAX_BODY {
            return Err(Error::new(ErrorKind::InvalidArgument, "credential"));
        }
        Ok(Self {
            realm: Counter::positive(realm)?,
            principal: Counter::new(principal)?,
            seed_file,
        })
    }
    pub fn realm(&self) -> u64 {
        self.realm.get()
    }
    pub fn principal(&self) -> u64 {
        self.principal.get()
    }
    pub(crate) fn seed_file(&self) -> &std::path::Path {
        &self.seed_file
    }
}
impl fmt::Debug for Credential {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Credential")
            .field("realm", &self.realm)
            .field("principal", &self.principal)
            .finish_non_exhaustive()
    }
}
#[derive(Clone, Debug, Eq, Hash, PartialEq)]
pub struct OperationIdentity(String);
impl OperationIdentity {
    pub(crate) fn new(value: &str) -> Result<Self> {
        if value.len() != 64
            || !value
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        {
            return Err(Error::new(ErrorKind::IncompatibleNative, "metadata"));
        }
        Ok(Self(value.to_owned()))
    }
    pub fn sha256(&self) -> &str {
        &self.0
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AdmissionReceipt {
    pub position: Counter,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct MutationReceipt {
    pub position: Counter,
}
#[derive(Clone, Debug)]
pub struct ClientConfig {
    pub(crate) url: String,
    pub(crate) timeout_ms: u32,
    pub(crate) native_directory: Option<PathBuf>,
}
impl ClientConfig {
    /// Explicitly selects the growing_v3 profile; there is no legacy fallback.
    pub fn growing(url: impl Into<String>) -> Result<Self> {
        let url = url.into();
        if url.len() > abi::MAX_BODY
            || !(url.starts_with("http://") || url.starts_with("https://"))
            || url.contains('\0')
        {
            return Err(Error::new(ErrorKind::InvalidArgument, "configuration"));
        }
        Ok(Self {
            url,
            timeout_ms: 30000,
            native_directory: None,
        })
    }
    pub fn with_timeout(mut self, milliseconds: u32) -> Result<Self> {
        if !(1..=60000).contains(&milliseconds) {
            return Err(Error::new(ErrorKind::InvalidArgument, "timeout"));
        }
        self.timeout_ms = milliseconds;
        Ok(self)
    }
    pub fn with_native_directory(mut self, directory: impl Into<PathBuf>) -> Self {
        self.native_directory = Some(directory.into());
        self
    }
}
#[derive(Clone, Debug)]
pub struct Capabilities {
    pub realm: Counter,
    pub observed_at: Counter,
    pub principal_sequence: Counter,
    pub page_size: Counter,
    pub mutations_per_turn: Counter,
    pub outputs_per_turn: Counter,
    pub retained_versions: bool,
    pub association_lookup: bool,
    pub scoped_retry: bool,
    pub station: bool,
}
