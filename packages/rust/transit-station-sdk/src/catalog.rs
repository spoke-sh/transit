//! Typed catalog requests and owned recovery over the shared Zig caller.
use crate::bridge::{CatalogNative, counter, field, wide};
use crate::{CellType, abi};
use serde_json::{Value, json};
use transit_client::internal::{Worker, boolean, number, string, unhex};
use transit_client::{
    AdmissionReceipt, ClientConfig, Counter, Credential, Error, ErrorKind, ProcessRef, ResourceRef,
    Result,
};

fn invalid() -> Error {
    Error::new(ErrorKind::InvalidArgument, "catalog-value")
}
fn malformed() -> Error {
    Error::new(ErrorKind::IncompatibleNative, "catalog-response")
}
fn positive(value: u64) -> Result<u64> {
    if value == 0 {
        Err(invalid())
    } else {
        Ok(value)
    }
}
fn native(value: u64, zero: bool) -> Result<u64> {
    Counter::new(value)?;
    if !zero {
        positive(value)?;
    }
    Ok(value)
}
fn object(value: &Value, fields: &[&str]) -> Result<()> {
    let map = value.as_object().ok_or_else(malformed)?;
    if map.len() != fields.len() || fields.iter().any(|key| !map.contains_key(*key)) {
        return Err(malformed());
    }
    Ok(())
}
fn result<'a>(value: &'a Value, tag: &str) -> Result<&'a Value> {
    object(value, &[tag])?;
    field(value, tag)
}
fn name(value: String) -> Result<String> {
    if value.is_empty() || value.len() > 16 {
        Err(invalid())
    } else {
        Ok(value)
    }
}
fn catalog_name(value: &str) -> Result<()> {
    let bytes = value.as_bytes();
    if bytes.is_empty()
        || bytes.len() > 16
        || !(bytes[0].is_ascii_alphabetic() || bytes[0] == b'_')
        || !bytes
            .iter()
            .all(|v| v.is_ascii_alphanumeric() || *v == b'_')
    {
        return Err(invalid());
    }
    Ok(())
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Scope {
    resource: ResourceRef,
    catalog: u64,
}
impl Scope {
    pub fn new(resource: ResourceRef, catalog: u64) -> Result<Self> {
        Ok(Self {
            resource,
            catalog: positive(catalog)?,
        })
    }
    pub fn resource(&self) -> ResourceRef {
        self.resource
    }
    pub fn catalog(&self) -> u64 {
        self.catalog
    }
    fn wire(&self) -> Value {
        json!({"realm":self.resource.realm(),"resource":self.resource.resource(),"catalog":self.catalog.to_string()})
    }
    fn parse(value: &Value) -> Result<Self> {
        object(value, &["realm", "resource", "catalog"])?;
        Self::new(
            ResourceRef::new(
                number(field(value, "realm")?, "realm", false)?,
                number(field(value, "resource")?, "resource", false)?,
            )?,
            wide(field(value, "catalog")?)?,
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Connection {
    owner: ProcessRef,
    scope: Scope,
}
impl Connection {
    pub fn new(owner: ProcessRef, scope: Scope) -> Result<Self> {
        if owner.realm() != scope.resource.realm() {
            return Err(invalid());
        }
        Ok(Self { owner, scope })
    }
    pub fn owner(&self) -> ProcessRef {
        self.owner
    }
    pub fn scope(&self) -> Scope {
        self.scope
    }
    pub(crate) fn wire(&self, principal: u64) -> Value {
        json!({"scope":self.scope.wire(),"owner":self.owner.pid(),"principal":principal})
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Configuration {
    scope: Scope,
    owner: ProcessRef,
    administrator: u64,
}
impl Configuration {
    pub fn new(scope: Scope, owner: ProcessRef, administrator: u64) -> Result<Self> {
        Connection::new(owner, scope)?;
        Ok(Self {
            scope,
            owner,
            administrator: native(administrator, false)?,
        })
    }
    pub fn scope(&self) -> Scope {
        self.scope
    }
    pub fn owner(&self) -> ProcessRef {
        self.owner
    }
    pub fn administrator(&self) -> u64 {
        self.administrator
    }
    fn wire(&self) -> Value {
        json!({"scope":self.scope.wire(),"owner":self.owner.pid(),"administrator":self.administrator})
    }
    fn parse(value: &Value) -> Result<Self> {
        object(value, &["scope", "owner", "administrator"])?;
        let scope = Scope::parse(field(value, "scope")?)?;
        Self::new(
            scope,
            ProcessRef::new(
                scope.resource.realm(),
                number(field(value, "owner")?, "owner", false)?,
            )?,
            number(field(value, "administrator")?, "administrator", false)?,
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Schema {
    names: [String; 2],
    value_type: CellType,
}
impl Schema {
    pub fn new(names: [String; 2], value_type: CellType) -> Result<Self> {
        let [first, second] = names;
        Ok(Self {
            names: [name(first)?, name(second)?],
            value_type,
        })
    }
    pub fn names(&self) -> &[String; 2] {
        &self.names
    }
    pub fn value_type(&self) -> CellType {
        self.value_type
    }
    fn wire(&self) -> Value {
        json!({"names":self.names,"value_type":self.value_type.native()})
    }
    fn parse(value: &Value) -> Result<Self> {
        object(value, &["names", "value_type"])?;
        let names = field(value, "names")?
            .as_array()
            .filter(|v| v.len() == 2)
            .ok_or_else(malformed)?;
        let value_type = match string(field(value, "value_type")?, "catalog-type")? {
            "int64" => CellType::Int64,
            "boolean" => CellType::Boolean,
            "utf8" => CellType::Utf8,
            "binary" => CellType::Binary,
            _ => return Err(malformed()),
        };
        Self::new(
            [
                string(&names[0], "name")?.to_owned(),
                string(&names[1], "name")?.to_owned(),
            ],
            value_type,
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CreateTable {
    scope: Scope,
    operation: u64,
    object: u64,
    table: u32,
    name: String,
    schema: Schema,
}
impl CreateTable {
    pub fn new(
        scope: Scope,
        operation: u64,
        object: u64,
        table: u32,
        table_name: String,
        schema: Schema,
    ) -> Result<Self> {
        positive(u64::from(table))?;
        Ok(Self {
            scope,
            operation: positive(operation)?,
            object: positive(object)?,
            table,
            name: name(table_name)?,
            schema,
        })
    }
    pub fn scope(&self) -> Scope {
        self.scope
    }
    pub fn operation(&self) -> u64 {
        self.operation
    }
    pub fn object(&self) -> u64 {
        self.object
    }
    pub fn table(&self) -> u32 {
        self.table
    }
    pub fn name(&self) -> &str {
        &self.name
    }
    pub fn schema(&self) -> &Schema {
        &self.schema
    }
    fn wire(&self) -> Value {
        json!({"scope":self.scope.wire(),"operation":self.operation.to_string(),"object":self.object.to_string(),"table":self.table,"name":self.name,"schema":self.schema.wire()})
    }
    fn parse(value: &Value) -> Result<Self> {
        object(
            value,
            &["scope", "operation", "object", "table", "name", "schema"],
        )?;
        Self::new(
            Scope::parse(field(value, "scope")?)?,
            wide(field(value, "operation")?)?,
            wide(field(value, "object")?)?,
            number(field(value, "table")?, "table", false)?
                .try_into()
                .map_err(|_| malformed())?,
            string(field(value, "name")?, "name")?.to_owned(),
            Schema::parse(field(value, "schema")?)?,
        )
    }
}
#[derive(Clone)]
pub struct Compiled {
    request: CreateTable,
    canonical: Vec<u8>,
}
impl Compiled {
    pub fn from_data(request: CreateTable, canonical: Vec<u8>) -> Result<Self> {
        if canonical.is_empty() || canonical.len() > 256 {
            return Err(invalid());
        }
        Ok(Self { request, canonical })
    }
    pub fn request(&self) -> &CreateTable {
        &self.request
    }
    pub fn canonical(&self) -> &[u8] {
        &self.canonical
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Policy {
    scope: Scope,
    principal: u64,
    revision: u64,
    inspect: bool,
    create: bool,
}
impl Policy {
    pub fn new(
        scope: Scope,
        principal: u64,
        revision: u64,
        inspect: bool,
        create: bool,
    ) -> Result<Self> {
        Ok(Self {
            scope,
            principal: native(principal, true)?,
            revision: positive(revision)?,
            inspect,
            create,
        })
    }
    pub fn scope(&self) -> Scope {
        self.scope
    }
    pub fn principal(&self) -> u64 {
        self.principal
    }
    pub fn revision(&self) -> u64 {
        self.revision
    }
    pub fn inspect(&self) -> bool {
        self.inspect
    }
    pub fn create(&self) -> bool {
        self.create
    }
    fn wire(&self) -> Value {
        json!({"scope":self.scope.wire(),"principal":self.principal,"revision":self.revision.to_string(),"inspect":self.inspect,"create":self.create})
    }
    fn parse(value: &Value) -> Result<Self> {
        object(
            value,
            &["scope", "principal", "revision", "inspect", "create"],
        )?;
        Self::new(
            Scope::parse(field(value, "scope")?)?,
            number(field(value, "principal")?, "principal", true)?,
            wide(field(value, "revision")?)?,
            boolean(field(value, "inspect")?, "inspect")?,
            boolean(field(value, "create")?, "create")?,
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PolicyChange {
    expected_revision: u64,
    policy: Policy,
}
impl PolicyChange {
    pub fn new(expected_revision: u64, policy: Policy) -> Self {
        Self {
            expected_revision,
            policy,
        }
    }
    pub fn expected_revision(&self) -> u64 {
        self.expected_revision
    }
    pub fn policy(&self) -> &Policy {
        &self.policy
    }
    fn wire(&self) -> Value {
        json!({"expected_revision":self.expected_revision.to_string(),"policy":self.policy.wire()})
    }
}
/// Exact opaque signed text. Submission borrows it without consuming or rewriting it.
#[derive(Clone)]
pub struct Prepared(String);
impl Prepared {
    pub fn from_data(data: String) -> Result<Self> {
        if data.is_empty() || data.len() > 8192 {
            Err(invalid())
        } else {
            Ok(Self(data))
        }
    }
    pub fn data(&self) -> &str {
        &self.0
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Observation {
    Pending,
    Processed,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Outcome {
    Applied,
    NameConflict,
    ObjectConflict,
    TableConflict,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Origin {
    External,
    Process,
    Effect,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DispositionOutcome {
    Initialized,
    PolicyApplied,
    InvalidCommand,
    Denied,
    IdentityConflict,
    StalePolicy,
}
#[derive(Clone, Debug)]
pub struct Capabilities {
    pub version: u8,
    pub definition: String,
    pub initialize: bool,
    pub create_table: bool,
    pub conditional_policy: bool,
    pub current_metadata: bool,
    pub max_saved_bytes: u16,
    pub table_columns: u8,
}
#[derive(Clone, Debug)]
pub struct Description {
    pub configuration: Configuration,
    pub policy: Policy,
    pub resource_revision: u64,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TableSource {
    pub table: u32,
    pub schema: Schema,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Definition {
    pub scope: Scope,
    pub object: u64,
    pub revision: u64,
    pub name: String,
    pub source: TableSource,
    pub principal: u64,
    pub operation: u64,
    pub input: u64,
}
impl Definition {
    fn parse(value: &Value) -> Result<Self> {
        object(
            value,
            &[
                "scope",
                "object",
                "revision",
                "name",
                "source",
                "principal",
                "operation",
                "input",
            ],
        )?;
        let source = field(value, "source")?;
        object(source, &["table"])?;
        let table = field(source, "table")?;
        object(table, &["id", "schema"])?;
        let schema = Schema::parse(field(table, "schema")?)?;
        for name in schema.names() {
            catalog_name(name)?;
        }
        if schema.names()[0] == schema.names()[1] {
            return Err(malformed());
        }
        let name = string(field(value, "name")?, "name")?;
        catalog_name(name)?;
        Ok(Self {
            scope: Scope::parse(field(value, "scope")?)?,
            object: positive(wide(field(value, "object")?)?)?,
            revision: positive(wide(field(value, "revision")?)?)?,
            name: name.to_owned(),
            source: TableSource {
                table: number(field(table, "id")?, "table", false)?
                    .try_into()
                    .map_err(|_| malformed())?,
                schema,
            },
            principal: number(field(value, "principal")?, "principal", true)?,
            operation: positive(wide(field(value, "operation")?)?)?,
            input: number(field(value, "input")?, "input", false)?,
        })
    }
}
/// Exact local continuation. Restoring it requires the original definition field.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Cursor {
    definition: String,
    scope: Scope,
    resource_revision: u64,
    after: String,
}
impl Cursor {
    pub fn new(
        definition: String,
        scope: Scope,
        resource_revision: u64,
        after: String,
    ) -> Result<Self> {
        if definition != abi::ABI_DEFINITION {
            return Err(malformed());
        }
        native(resource_revision, false)?;
        catalog_name(&after)?;
        Ok(Self {
            definition,
            scope,
            resource_revision,
            after,
        })
    }
    pub fn definition(&self) -> &str {
        &self.definition
    }
    pub fn scope(&self) -> Scope {
        self.scope
    }
    pub fn resource_revision(&self) -> u64 {
        self.resource_revision
    }
    pub fn after(&self) -> &str {
        &self.after
    }
    fn wire(&self) -> Value {
        json!({"definition":self.definition,"scope":self.scope.wire(),"resource_revision":self.resource_revision,"after":self.after})
    }
    fn parse(value: &Value) -> Result<Self> {
        object(
            value,
            &["definition", "scope", "resource_revision", "after"],
        )?;
        Self::new(
            string(field(value, "definition")?, "definition")?.to_owned(),
            Scope::parse(field(value, "scope")?)?,
            number(
                field(value, "resource_revision")?,
                "resource-revision",
                false,
            )?,
            string(field(value, "after")?, "after")?.to_owned(),
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Page {
    pub resource_revision: u64,
    pub entries: Vec<Definition>,
    pub next: Option<Cursor>,
}
impl Page {
    fn parse(value: &Value, scope: Scope, previous: Option<&Cursor>) -> Result<Self> {
        object(value, &["resource_revision", "entries", "next"])?;
        let resource_revision = number(
            field(value, "resource_revision")?,
            "resource-revision",
            false,
        )?;
        let slots = field(value, "entries")?
            .as_array()
            .filter(|v| v.len() == 8)
            .ok_or_else(malformed)?;
        let mut entries: Vec<Definition> = Vec::with_capacity(8);
        let mut ended = false;
        for slot in slots {
            if slot.is_null() {
                ended = true;
                continue;
            }
            let entry = Definition::parse(slot)?;
            if ended
                || entry.scope != scope
                || entries.last().is_some_and(|last| last.name >= entry.name)
            {
                return Err(malformed());
            }
            entries.push(entry);
        }
        let next = match field(value, "next")? {
            Value::Null => None,
            cursor => Some(Cursor::parse(cursor)?),
        };
        if let Some(next) = &next {
            let last = entries.last().ok_or_else(malformed)?;
            if next.scope != scope
                || next.after != last.name
                || next.resource_revision != resource_revision
            {
                return Err(malformed());
            }
        }
        if let Some(previous) = previous {
            if resource_revision != previous.resource_revision
                || entries
                    .first()
                    .is_some_and(|first| first.name <= previous.after)
            {
                return Err(malformed());
            }
        }
        Ok(Self {
            resource_revision,
            entries,
            next,
        })
    }
}
fn resolved(
    value: &Value,
    scope: Scope,
    name: Option<&str>,
    identity: Option<(u64, u64)>,
) -> Result<Option<Definition>> {
    if value.is_null() {
        return Ok(None);
    }
    let result = Definition::parse(value)?;
    if result.scope != scope
        || name.is_some_and(|name| result.name != name)
        || identity.is_some_and(|(object, revision)| {
            result.object != object || result.revision != revision
        })
    {
        return Err(malformed());
    }
    Ok(Some(result))
}
#[derive(Clone, Debug)]
pub struct Receipt {
    pub request: CreateTable,
    pub principal: u64,
    pub input: u64,
    pub outcome: Outcome,
}
#[derive(Clone, Debug)]
pub struct Disposition {
    pub scope: Scope,
    pub origin: Origin,
    pub principal: u64,
    pub input: u64,
    pub payload: [u8; 32],
    pub outcome: DispositionOutcome,
}

fn prepared(value: &Value) -> Result<Prepared> {
    Prepared::from_data(string(value, "catalog-prepared")?.to_owned())
}
fn admission(value: &Value) -> Result<AdmissionReceipt> {
    (|| {
        let receipt = result(value, "receipt")?;
        object(receipt, &["position"])?;
        Ok(AdmissionReceipt {
            position: counter(field(receipt, "position")?, false)?,
        })
    })()
    .map_err(|_: Error| Error::new(ErrorKind::UnknownOutcome, "catalog-receipt"))
}
fn submission(response: Result<Value>) -> Result<AdmissionReceipt> {
    let value = response.map_err(|mut error| {
        // A queued worker can fail after dispatch. Its failure does not prove
        // that the authority rejected the original signed command.
        if error.kind == ErrorKind::WorkerPanic {
            error.kind = ErrorKind::UnknownOutcome;
        }
        error
    })?;
    admission(&value)
}
/// One blocking worker. Mutable borrows serialize calls; close/drop joins destruction.
pub struct Client {
    connection: Connection,
    worker: Worker<CatalogNative>,
}
impl Client {
    pub fn open(
        config: ClientConfig,
        credential: Credential,
        connection: Connection,
    ) -> Result<Self> {
        if credential.realm() != connection.scope.resource.realm() {
            return Err(invalid());
        }
        let saved = connection.clone();
        let worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
            CatalogNative::open(&config, &credential, &saved)
        })?;
        Ok(Self { connection, worker })
    }
    pub fn connection(&self) -> &Connection {
        &self.connection
    }
    fn call(&mut self, action: Value) -> Result<Value> {
        self.worker.call(move |native| native.call(action))
    }
    pub fn capabilities(&mut self) -> Result<Capabilities> {
        let response = self.call(json!({"capabilities":{}}))?;
        let v = result(&response, "capabilities")?;
        object(
            v,
            &[
                "version",
                "definition",
                "initialize",
                "create_table",
                "conditional_policy",
                "current_metadata",
                "max_saved_bytes",
                "table_columns",
            ],
        )?;
        Ok(Capabilities {
            version: number(field(v, "version")?, "version", false)?
                .try_into()
                .map_err(|_| malformed())?,
            definition: string(field(v, "definition")?, "definition")?.to_owned(),
            initialize: boolean(field(v, "initialize")?, "initialize")?,
            create_table: boolean(field(v, "create_table")?, "create")?,
            conditional_policy: boolean(field(v, "conditional_policy")?, "policy")?,
            current_metadata: boolean(field(v, "current_metadata")?, "metadata")?,
            max_saved_bytes: number(field(v, "max_saved_bytes")?, "saved-bound", false)?
                .try_into()
                .map_err(|_| malformed())?,
            table_columns: number(field(v, "table_columns")?, "columns", false)?
                .try_into()
                .map_err(|_| malformed())?,
        })
    }
    pub fn describe(&mut self) -> Result<Description> {
        let response = self.call(json!({"describe":{}}))?;
        let v = result(&response, "description")?;
        object(v, &["configuration", "policy", "resource_revision"])?;
        Ok(Description {
            configuration: Configuration::parse(field(v, "configuration")?)?,
            policy: Policy::parse(field(v, "policy")?)?,
            resource_revision: number(field(v, "resource_revision")?, "revision", true)?,
        })
    }
    pub fn lookup(&mut self, name: &str) -> Result<Option<Definition>> {
        catalog_name(name)?;
        let response = self.call(json!({"lookup":name}))?;
        resolved(
            result(&response, "definition")?,
            self.connection.scope,
            Some(name),
            None,
        )
        .map_err(|_| malformed())
    }
    pub fn definition(&mut self, object: u64, revision: u64) -> Result<Option<Definition>> {
        positive(object)?;
        positive(revision)?;
        let response = self.call(
            json!({"definition":{"object":object.to_string(),"revision":revision.to_string()}}),
        )?;
        resolved(
            result(&response, "definition")?,
            self.connection.scope,
            None,
            Some((object, revision)),
        )
        .map_err(|_| malformed())
    }
    pub fn list(&mut self, cursor: Option<&Cursor>) -> Result<Page> {
        let response = self.call(json!({"list":cursor.map(Cursor::wire)}))?;
        Page::parse(result(&response, "page")?, self.connection.scope, cursor)
            .map_err(|_| malformed())
    }
    pub fn compile_sql(
        &mut self,
        sql: &str,
        operation: u64,
        object_id: u64,
        table: u32,
    ) -> Result<Compiled> {
        if sql.is_empty() || sql.len() > 4096 {
            return Err(invalid());
        }
        positive(operation)?;
        positive(object_id)?;
        positive(u64::from(table))?;
        let response=self.call(json!({"compile":{"sql":sql,"operation":operation.to_string(),"object":object_id.to_string(),"table":table}}))?;
        let value = result(&response, "compiled")?;
        object(value, &["request", "canonical"])?;
        Compiled::from_data(
            CreateTable::parse(field(value, "request")?)?,
            unhex(string(field(value, "canonical")?, "canonical")?, 256)?,
        )
    }
    pub fn prepare_initialize(&mut self, configuration: &Configuration) -> Result<Prepared> {
        let response = self.call(json!({"prepare_initialize":configuration.wire()}))?;
        prepared(result(&response, "prepared")?)
    }
    pub fn prepare_create(&mut self, request: &CreateTable) -> Result<Prepared> {
        let response = self.call(json!({"prepare_create":request.wire()}))?;
        prepared(result(&response, "prepared")?)
    }
    pub fn prepare_policy(&mut self, change: &PolicyChange) -> Result<Prepared> {
        let response = self.call(json!({"prepare_policy":change.wire()}))?;
        prepared(result(&response, "prepared")?)
    }
    /// UnknownOutcome requires retrying this same Prepared, including after replacement.
    pub fn submit(&mut self, prepared: &Prepared) -> Result<AdmissionReceipt> {
        submission(self.call(json!({"submit":prepared.data()})))
    }
    pub fn observe(&mut self, prepared: &Prepared, input: u64) -> Result<Observation> {
        let response = self
            .call(json!({"observe":{"prepared":prepared.data(),"input":native(input,false)?}}))?;
        Ok(
            match string(result(&response, "observation")?, "observation")? {
                "pending" => Observation::Pending,
                "processed" => Observation::Processed,
                _ => return Err(malformed()),
            },
        )
    }
    pub fn input_disposition(
        &mut self,
        prepared: &Prepared,
        input: u64,
    ) -> Result<Option<Disposition>> {
        let response = self.call(
            json!({"input_disposition":{"prepared":prepared.data(),"input":native(input,false)?}}),
        )?;
        let value = result(&response, "disposition")?;
        if value.is_null() {
            return Ok(None);
        }
        object(
            value,
            &[
                "scope",
                "origin",
                "principal",
                "input",
                "payload",
                "outcome",
            ],
        )?;
        let origin = match string(field(value, "origin")?, "origin")? {
            "external" => Origin::External,
            "process" => Origin::Process,
            "effect" => Origin::Effect,
            _ => return Err(malformed()),
        };
        let outcome = match string(field(value, "outcome")?, "outcome")? {
            "initialized" => DispositionOutcome::Initialized,
            "policy_applied" => DispositionOutcome::PolicyApplied,
            "invalid_command" => DispositionOutcome::InvalidCommand,
            "denied" => DispositionOutcome::Denied,
            "identity_conflict" => DispositionOutcome::IdentityConflict,
            "stale_policy" => DispositionOutcome::StalePolicy,
            _ => return Err(malformed()),
        };
        Ok(Some(Disposition {
            scope: Scope::parse(field(value, "scope")?)?,
            origin,
            principal: number(field(value, "principal")?, "principal", true)?,
            input: number(field(value, "input")?, "input", false)?,
            payload: unhex(string(field(value, "payload")?, "payload")?, 32)?
                .try_into()
                .map_err(|_| malformed())?,
            outcome,
        }))
    }
    pub fn status(&mut self, original: &CreateTable) -> Result<Option<Receipt>> {
        let response = self.call(json!({"status":original.wire()}))?;
        let value = result(&response, "status")?;
        if value.is_null() {
            return Ok(None);
        }
        object(value, &["request", "principal", "input", "outcome"])?;
        let request = CreateTable::parse(field(value, "request")?)?;
        if request != *original {
            return Err(malformed());
        }
        let outcome = match string(field(value, "outcome")?, "outcome")? {
            "applied" => Outcome::Applied,
            "name_conflict" => Outcome::NameConflict,
            "object_conflict" => Outcome::ObjectConflict,
            "table_conflict" => Outcome::TableConflict,
            _ => return Err(malformed()),
        };
        Ok(Some(Receipt {
            request,
            principal: number(field(value, "principal")?, "principal", true)?,
            input: number(field(value, "input")?, "input", false)?,
            outcome,
        }))
    }
    pub fn close(mut self) -> Result<()> {
        self.worker.close()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn metadata_owns_wide_identity_and_rejects_inconsistent_pages() {
        let scope = Scope::new(ResourceRef::new(46, 7).unwrap(), u64::MAX).unwrap();
        let definition = json!({"scope":scope.wire(),"object":u64::MAX.to_string(),"revision":u64::MAX.to_string(),"name":"items",
            "source":{"table":{"id":u32::MAX,"schema":{"names":["id","value"],"value_type":"utf8"}}},"principal":17,"operation":u64::MAX.to_string(),"input":2});
        let cursor = Cursor::new(abi::ABI_DEFINITION.into(), scope, 3, "items".into()).unwrap();
        let page = json!({"resource_revision":3,"entries":[definition,null,null,null,null,null,null,null],"next":cursor.wire()});
        let parsed = Page::parse(&page, scope, None).unwrap();
        assert_eq!(parsed.entries[0].object, u64::MAX);
        assert_eq!(parsed.entries[0].revision, u64::MAX);
        assert_eq!(parsed.entries[0].source.table, u32::MAX);
        let retained = parsed.clone();
        drop(parsed);
        assert_eq!(retained.next.as_ref().unwrap(), &cursor);
        assert_eq!(retained.entries[0].source.schema.names(), &["id", "value"]);
        assert_eq!(
            resolved(&definition, scope, Some("items"), None)
                .unwrap()
                .as_ref(),
            retained.entries.first()
        );
        assert!(resolved(&definition, scope, Some("other"), None).is_err());
        assert!(resolved(&definition, scope, None, Some((1, 1))).is_err());
        assert!(resolved(&Value::Null, scope, None, None).unwrap().is_none());
        for defect in 0..10 {
            let mut bad = page.clone();
            match defect {
                0 => {
                    bad["entries"][1] = bad["entries"][0].take();
                }
                1 => {
                    bad["entries"][1] = definition.clone();
                }
                2 => {
                    bad["entries"][0]["scope"]["catalog"] = json!("1");
                }
                3 => {
                    bad["next"]["resource_revision"] = json!(4);
                }
                4 => {
                    bad["next"]["after"] = json!("other");
                }
                5 => {
                    bad["next"].as_object_mut().unwrap().remove("definition");
                }
                6 => {
                    bad["next"]["definition"] = json!("0".repeat(64));
                }
                7 => {
                    bad["entries"][0]["object"] = json!(u64::MAX);
                }
                8 => {
                    bad["entries"][0]["source"] = json!({"document":{}});
                }
                _ => {
                    bad["entries"].as_array_mut().unwrap().push(Value::Null);
                }
            }
            assert!(Page::parse(&bad, scope, None).is_err(), "defect {defect}");
        }
        assert!(Page::parse(&page, scope, Some(&cursor)).is_err());
        let mut end = json!({"resource_revision":3,"entries":[null,null,null,null,null,null,null,null],"next":null});
        assert!(
            Page::parse(&end, scope, Some(&cursor))
                .unwrap()
                .entries
                .is_empty()
        );
        end["resource_revision"] = json!(4);
        assert!(Page::parse(&end, scope, Some(&cursor)).is_err());
    }
    #[test]
    fn owned_wide_values_and_strict_decoding() {
        let scope = Scope::new(ResourceRef::new(46, 7).unwrap(), u64::MAX).unwrap();
        let request = CreateTable::new(
            scope,
            u64::MAX,
            u64::MAX,
            u32::MAX,
            "items".into(),
            Schema::new(["id".into(), "value".into()], CellType::Utf8).unwrap(),
        )
        .unwrap();
        assert_eq!(CreateTable::parse(&request.wire()).unwrap(), request);
        let policy = Policy::new(scope, 0, u64::MAX, true, false).unwrap();
        assert_eq!(Policy::parse(&policy.wire()).unwrap(), policy);
        for bad in [
            json!(u64::MAX),
            json!("01"),
            json!("+1"),
            json!("18446744073709551616"),
        ] {
            let mut wire = policy.wire();
            wire["revision"] = bad;
            assert!(Policy::parse(&wire).is_err());
        }
        assert!(Scope::new(scope.resource(), 0).is_err());
        assert!(Connection::new(ProcessRef::new(47, 1).unwrap(), scope).is_err());
        let copy = Compiled::from_data(request, vec![1, 2]).unwrap();
        let saved = copy.clone();
        drop(copy);
        assert_eq!(saved.canonical(), [1, 2]);
        assert_eq!(saved.request().object(), u64::MAX);
    }
    #[test]
    fn malformed_success_keeps_admission_uncertain() {
        for value in [
            Value::Null,
            json!({}),
            json!({"receipt":{"position":0}}),
            json!({"receipt":{"position":"1"}}),
            json!({"receipt":{"position":1.5}}),
            json!({"receipt":{"position":1},"extra":true}),
        ] {
            assert_eq!(
                admission(&value).unwrap_err().kind,
                ErrorKind::UnknownOutcome
            );
        }
        assert_eq!(
            admission(&json!({"receipt":{"position":1}}))
                .unwrap()
                .position
                .get(),
            1
        );
    }
    #[test]
    fn worker_failure_after_admission_keeps_original_recovery() {
        let prepared = Prepared::from_data("saved signed command".into()).unwrap();
        let mut worker = Worker::open(abi::MINIMUM_STACK_BYTES, || Ok(false)).unwrap();
        let response = worker.call(|accepted| {
            *accepted = true;
            panic!("injected failure after dispatch");
        });
        assert_eq!(
            submission(response).unwrap_err().kind,
            ErrorKind::UnknownOutcome
        );
        assert!(worker.call(|accepted| Ok(*accepted)).unwrap());
        assert_eq!(prepared.data(), "saved signed command");
        worker.close().unwrap();
        for kind in [ErrorKind::Busy, ErrorKind::Closed, ErrorKind::AccessDenied] {
            let definite = Error {
                kind,
                status: Some(4),
                code: Some("Denied".into()),
                phase: "submit",
            };
            assert_eq!(submission(Err(definite.clone())).unwrap_err(), definite);
        }
    }
}
