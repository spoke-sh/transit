//! Typed, owned mutation callers over the shared Zig policy/staging/recovery owner.
use crate::bridge::{MutationNative, counter, field, wide};
use crate::{CellType, abi};
use serde_json::{Value, json};
use transit_client::internal::{Worker, hex, number, string, unhex};
use transit_client::{
    AdmissionReceipt, ClientConfig, Counter, Credential, Error, ErrorKind, ProcessRef, ResourceRef,
    Result,
};

fn invalid() -> Error {
    Error::new(ErrorKind::InvalidArgument, "mutation-value")
}
fn malformed() -> Error {
    Error::new(ErrorKind::IncompatibleNative, "mutation-response")
}

#[derive(Clone, Debug)]
pub struct Connection {
    writer: ProcessRef,
    resource: ResourceRef,
    table: u32,
}
impl Connection {
    pub fn new(writer: ProcessRef, resource: ResourceRef, table: u32) -> Result<Self> {
        if writer.realm() != resource.realm() || table == 0 {
            return Err(invalid());
        }
        Ok(Self {
            writer,
            resource,
            table,
        })
    }
    pub fn writer(&self) -> ProcessRef {
        self.writer
    }
    pub fn resource(&self) -> ResourceRef {
        self.resource
    }
    pub fn table(&self) -> u32 {
        self.table
    }
    pub(crate) fn wire(&self, principal: u64) -> Value {
        json!({"realm":self.writer.realm(),"principal":principal,"writer":self.writer.pid(),"resource":self.resource.resource(),"table":self.table})
    }
}
/// Complete request commitment; validation and authority remain native operations.
#[derive(Clone, Eq, PartialEq)]
pub struct Reference([u8; 68]);
impl Reference {
    pub fn from_data(data: [u8; 68]) -> Self {
        Self(data)
    }
    pub fn data(&self) -> &[u8; 68] {
        &self.0
    }
    fn parse(value: &Value) -> Result<Self> {
        Ok(Self(
            unhex(string(value, "mutation-reference")?, 68)?
                .try_into()
                .map_err(|_| malformed())?,
        ))
    }
}
/// Persist the canonical request and its full reference unchanged before upload.
#[derive(Clone)]
pub struct Compiled {
    request: Vec<u8>,
    reference: Reference,
}
impl Compiled {
    pub fn from_data(request: Vec<u8>, reference: Reference) -> Result<Self> {
        if request.is_empty() || request.len() > 799 {
            return Err(invalid());
        }
        Ok(Self { request, reference })
    }
    pub fn request(&self) -> &[u8] {
        &self.request
    }
    pub fn reference(&self) -> &Reference {
        &self.reference
    }
}
/// Opaque signed recovery text. Submit borrows it and never consumes or rewrites it.
#[derive(Clone)]
pub struct Prepared(String);
impl Prepared {
    pub fn from_data(data: String) -> Result<Self> {
        if data.is_empty() || data.len() > 8192 {
            return Err(invalid());
        }
        Ok(Self(data))
    }
    pub fn data(&self) -> &str {
        &self.0
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Permissions(u8);
impl Permissions {
    pub const INSERT: Self = Self(1);
    pub const UPDATE: Self = Self(2);
    pub const DELETE: Self = Self(4);
    pub fn bits(self) -> u8 {
        self.0
    }
    pub fn contains(self, other: Self) -> bool {
        self.0 & other.0 == other.0
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Phase {
    Uploading,
    Sealed,
    Applied,
    Rejected,
    Cancelled,
}
impl Phase {
    fn parse(value: &Value) -> Result<Self> {
        Ok(match string(value, "mutation-phase")? {
            "uploading" => Self::Uploading,
            "sealed" => Self::Sealed,
            "applied" => Self::Applied,
            "rejected" => Self::Rejected,
            "cancelled" => Self::Cancelled,
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Reason {
    None,
    RowExists,
    SourceChanged,
    InvalidRequest,
    Denied,
    Budget,
}
impl Reason {
    fn parse(value: &Value) -> Result<Self> {
        Ok(match string(value, "mutation-reason")? {
            "none" => Self::None,
            "row_exists" => Self::RowExists,
            "source_changed" => Self::SourceChanged,
            "invalid_request" => Self::InvalidRequest,
            "denied" => Self::Denied,
            "budget" => Self::Budget,
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Observation {
    Pending,
    Processed,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Rejection {
    InvalidCommand,
    Denied,
    IdentityConflict,
    Busy,
    NotFound,
    NotActive,
    UploadClosed,
    NotSealed,
    InvalidPart,
    IncompleteUpload,
    SourceChanged,
    StalePolicy,
}
impl Rejection {
    fn parse(value: &Value) -> Result<Self> {
        Ok(match string(value, "mutation-rejection")? {
            "invalid_command" => Self::InvalidCommand,
            "denied" => Self::Denied,
            "identity_conflict" => Self::IdentityConflict,
            "busy" => Self::Busy,
            "not_found" => Self::NotFound,
            "not_active" => Self::NotActive,
            "upload_closed" => Self::UploadClosed,
            "not_sealed" => Self::NotSealed,
            "invalid_part" => Self::InvalidPart,
            "incomplete_upload" => Self::IncompleteUpload,
            "source_changed" => Self::SourceChanged,
            "stale_policy" => Self::StalePolicy,
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone)]
pub struct Description {
    pub resource: ResourceRef,
    pub table: u32,
    pub names: [String; 2],
    pub value_type: CellType,
    pub resource_revision: u64,
    pub policy_revision: u64,
    pub declaration: [u8; 32],
    pub permissions: Permissions,
    pub active: Option<u64>,
}
#[derive(Clone)]
pub struct Status {
    pub reference: Reference,
    pub principal: u64,
    pub table: u32,
    pub declaration: [u8; 32],
    pub policy_revision: u64,
    pub phase: Phase,
    pub affected_rows: u8,
    pub reason: Reason,
    pub input: u64,
}
fn digest(value: &Value) -> Result<[u8; 32]> {
    unhex(string(value, "mutation-digest")?, 32)?
        .try_into()
        .map_err(|_| malformed())
}
fn revision(value: &Value) -> Result<u64> {
    let value = wide(value)?;
    if value == 0 {
        return Err(malformed());
    }
    Counter::new(value).map_err(|_| malformed())?;
    Ok(value)
}
fn position(value: u64) -> Result<u64> {
    if value == 0 {
        return Err(invalid());
    }
    Counter::new(value)?;
    Ok(value)
}
fn prepared(value: &Value) -> Result<Option<Prepared>> {
    if value.is_null() {
        Ok(None)
    } else {
        Ok(Some(Prepared::from_data(
            string(value, "prepared-mutation")?.to_owned(),
        )?))
    }
}
/// One owned blocking worker. Mutable borrows prevent overlap; close/drop joins.
pub struct Client {
    connection: Connection,
    worker: Worker<MutationNative>,
}
impl Client {
    pub fn open(
        config: ClientConfig,
        credential: Credential,
        connection: Connection,
    ) -> Result<Self> {
        if credential.realm() != connection.writer.realm() || credential.principal() == 0 {
            return Err(invalid());
        }
        let saved = connection.clone();
        let worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
            MutationNative::open(&config, &credential, &saved)
        })?;
        Ok(Self { connection, worker })
    }
    pub fn connection(&self) -> &Connection {
        &self.connection
    }
    fn call(&mut self, action: Value) -> Result<Value> {
        self.worker.call(move |native| native.call(action))
    }
    pub fn describe(&mut self) -> Result<Description> {
        let response = self.call(json!({"describe":{}}))?;
        let v = field(&response, "description")?;
        if number(field(v, "resource")?, "resource", false)? != self.connection.resource.resource()
            || number(field(v, "table")?, "table", false)? != u64::from(self.connection.table)
        {
            return Err(malformed());
        }
        let names = field(v, "names")?
            .as_array()
            .filter(|v| v.len() == 2)
            .ok_or_else(malformed)?;
        let names = [
            string(&names[0], "column-name")?.to_owned(),
            string(&names[1], "column-name")?.to_owned(),
        ];
        if names.iter().any(|v| v.len() > 16) {
            return Err(malformed());
        }
        let value_type = match string(field(v, "value_type")?, "cell-type")? {
            "int64" => CellType::Int64,
            "boolean" => CellType::Boolean,
            "utf8" => CellType::Utf8,
            "binary" => CellType::Binary,
            _ => return Err(malformed()),
        };
        let permissions = number(field(v, "permissions")?, "permissions", true)?;
        if permissions > 7 {
            return Err(malformed());
        }
        let active = field(v, "active")?;
        let active = if active.is_null() {
            None
        } else {
            Some(wide(active)?)
        };
        if active == Some(0) {
            return Err(malformed());
        }
        Ok(Description {
            resource: self.connection.resource,
            table: self.connection.table,
            names,
            value_type,
            resource_revision: number(field(v, "resource_revision")?, "revision", true)?,
            policy_revision: revision(field(v, "policy_revision")?)?,
            declaration: digest(field(v, "declaration")?)?,
            permissions: Permissions(permissions as u8),
            active,
        })
    }
    pub fn compile_sql(&mut self, name: &str, sql: &str, namespace: u64) -> Result<Compiled> {
        if name.len() > 16 || sql.len() > 4096 || namespace == 0 {
            return Err(invalid());
        }
        let result = self
            .call(json!({"compile":{"name":name,"sql":sql,"namespace":namespace.to_string()}}))?;
        let value = field(&result, "compiled")?;
        Compiled::from_data(
            unhex(string(field(value, "request")?, "mutation-request")?, 799)?,
            Reference::parse(field(value, "reference")?)?,
        )
    }
    pub fn prepare_next(&mut self, compiled: &Compiled) -> Result<Option<Prepared>> {
        let result = self.call(json!({"next":{"request":hex(compiled.request(),799)?,"reference":hex(compiled.reference().data(),68)?}}))?;
        prepared(field(&result, "prepared")?)
    }
    fn control(&mut self, kind: &str, reference: &Reference) -> Result<Prepared> {
        let result = self.call(json!({"prepare":{kind:hex(reference.data(),68)?}}))?;
        prepared(field(&result, "prepared")?)?.ok_or_else(malformed)
    }
    pub fn prepare_apply(&mut self, reference: &Reference) -> Result<Prepared> {
        self.control("apply", reference)
    }
    pub fn prepare_cancel(&mut self, reference: &Reference) -> Result<Prepared> {
        self.control("cancel", reference)
    }
    /// UnknownOutcome requires the same borrowed Prepared, including after replacement.
    pub fn submit(&mut self, prepared: &Prepared) -> Result<AdmissionReceipt> {
        let result = self.call(json!({"submit":prepared.data()}))?;
        (|| {
            Ok(AdmissionReceipt {
                position: counter(field(field(&result, "receipt")?, "position")?, false)?,
            })
        })()
        .map_err(|_: Error| Error::new(ErrorKind::UnknownOutcome, "mutation-receipt"))
    }
    pub fn observe(&mut self, prepared: &Prepared, input: u64) -> Result<Observation> {
        let result =
            self.call(json!({"observe":{"prepared":prepared.data(),"input":position(input)?}}))?;
        Ok(
            match string(field(&result, "observation")?, "mutation-observation")? {
                "pending" => Observation::Pending,
                "processed" => Observation::Processed,
                _ => return Err(malformed()),
            },
        )
    }
    pub fn rejection(&mut self, prepared: &Prepared, input: u64) -> Result<Option<Rejection>> {
        let result =
            self.call(json!({"rejection":{"prepared":prepared.data(),"input":position(input)?}}))?;
        let value = field(&result, "rejection")?;
        if value.is_null() {
            Ok(None)
        } else {
            Ok(Some(Rejection::parse(value)?))
        }
    }
    pub fn status(&mut self, reference: &Reference) -> Result<Option<Status>> {
        let result = self.call(json!({"status":hex(reference.data(),68)?}))?;
        let v = field(&result, "status")?;
        if v.is_null() {
            return Ok(None);
        }
        let actual = Reference::parse(field(v, "reference")?)?;
        if &actual != reference
            || number(field(v, "table")?, "table", false)? != u64::from(self.connection.table)
        {
            return Err(malformed());
        }
        let affected_rows = number(field(v, "affected_rows")?, "affected-rows", true)?;
        if affected_rows > 3 {
            return Err(malformed());
        }
        Ok(Some(Status {
            reference: actual,
            principal: number(field(v, "principal")?, "principal", false)?,
            table: self.connection.table,
            declaration: digest(field(v, "declaration")?)?,
            policy_revision: revision(field(v, "policy_revision")?)?,
            phase: Phase::parse(field(v, "phase")?)?,
            affected_rows: affected_rows as u8,
            reason: Reason::parse(field(v, "reason")?)?,
            input: number(field(v, "input")?, "input", true)?,
        }))
    }
    pub fn close(&mut self) -> Result<()> {
        self.worker.close()
    }
}
