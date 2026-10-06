//! Owned general Tables over the shared Zig compiler and durable owner.
use crate::abi;
use crate::bridge::{CatalogNative, counter, field, wide};
use crate::logical::{Atom, Cell, Descriptor};
use serde_json::{Value, json};
use transit_client::internal::{Worker, boolean, hex, number, string, unhex};
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
// Charge one completed fragment before converting the next logical value.
// Complete frame admission also counts enclosing punctuation and fields.
struct WireBudget(usize);
impl WireBudget {
    fn take(&mut self, value: Value) -> Result<Value> {
        let size = serde_json::to_vec(&value).map_err(|_| invalid())?.len();
        self.0 = self.0.checked_sub(size).ok_or_else(invalid)?;
        Ok(value)
    }
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
fn variant(value: &Value) -> Result<(&str, &Value)> {
    let map = value
        .as_object()
        .filter(|v| v.len() == 1)
        .ok_or_else(malformed)?;
    let (k, v) = map.iter().next().ok_or_else(malformed)?;
    Ok((k, v))
}
fn text(value: &str, limit: usize) -> Result<&str> {
    if value.is_empty() || value.len() > limit {
        Err(invalid())
    } else {
        Ok(value)
    }
}
fn name(value: &str) -> Result<&str> {
    text(value, 255)?;
    if value.contains('\0') {
        return Err(invalid());
    }
    Ok(value)
}
fn definition(value: &str) -> Result<&str> {
    if value != abi::ABI_DEFINITION {
        Err(invalid())
    } else {
        Ok(value)
    }
}
fn bytes(value: &Value, bound: usize) -> Result<Vec<u8>> {
    let value = string(value, "catalog-bytes")?;
    if !value
        .bytes()
        .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err(malformed());
    }
    unhex(value, bound)
}
fn digest(value: &Value) -> Result<[u8; 32]> {
    bytes(value, 32)?.try_into().map_err(|_| malformed())
}
fn w(value: &Value, zero: bool) -> Result<u64> {
    let value = wide(value)?;
    if !zero {
        positive(value)?;
    }
    Ok(value)
}
fn n(value: &Value, zero: bool) -> Result<u64> {
    number(value, "catalog-counter", zero)
}
fn u32n(value: &Value, zero: bool) -> Result<u32> {
    n(value, zero)?.try_into().map_err(|_| malformed())
}
fn optional<T>(value: &Value, parse: impl FnOnce(&Value) -> Result<T>) -> Result<Option<T>> {
    if value.is_null() {
        Ok(None)
    } else {
        parse(value).map(Some)
    }
}
fn diagnostic(value: &Value) -> Result<Value> {
    if !value.is_object() {
        return Err(malformed());
    }
    Ok(value.clone())
}

macro_rules! tags {
    (read $name:ident {$($variant:ident => $tag:literal),+ $(,)?}) => {
        #[derive(Clone, Copy, Debug, Eq, PartialEq)] pub enum $name {$($variant),+}
        impl $name { fn parse(value:&Value)->Result<Self>{Ok(match string(value,"catalog-tag")? {$($tag=>Self::$variant,)+ _=>return Err(malformed())})} }
    };
    (write $name:ident {$($variant:ident => $tag:literal),+ $(,)?}) => {
        #[derive(Clone, Copy, Debug, Eq, PartialEq)] pub enum $name {$($variant),+}
        impl $name { fn tag(self)-> &'static str { match self {$(Self::$variant => $tag),+} } }
    };
}
tags!(read Kind {Create=>"create",Alter=>"alter",Rename=>"rename",Drop=>"drop",Insert=>"insert",Update=>"update",Delete=>"delete"});
tags!(read Phase {Preparing=>"preparing",Delegated=>"delegated",Building=>"building",Applied=>"applied",Unchanged=>"unchanged",Rejected=>"rejected",Cancelled=>"cancelled"});
tags!(read UploadPhase {Uploading=>"uploading",Sealed=>"sealed",Ready=>"ready",Cancelled=>"cancelled"});
tags!(read Observation {Pending=>"pending",Processed=>"processed"});
tags!(read DispositionOutcome {Initialized=>"initialized",PolicyApplied=>"policy_applied",DependencyApplied=>"dependency_applied",InvalidCommand=>"invalid_command",Blocked=>"blocked",Denied=>"denied",IdentityConflict=>"identity_conflict",StalePolicy=>"stale_policy"});
tags!(write Control {CancelOperation=>"cancel_operation",CleanupOperation=>"cleanup_operation",CancelUpload=>"cancel_upload",CollectUpload=>"collect_upload"});
tags!(write DependencyKind {QuerySource=>"query_source",Writer=>"writer",Watch=>"watch",MaintainedRelation=>"maintained_relation",History=>"history"});
tags!(write CellState {Missing=>"missing",Null=>"null",TypeError=>"type_error",Value=>"value",Conflict=>"conflict"});
tags!(write CompareOperator {Eq=>"eq",Ne=>"ne",Lt=>"lt",Le=>"le",Gt=>"gt",Ge=>"ge"});

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
    pub(crate) fn wire(&self) -> Value {
        json!({"realm":self.resource.realm(),"resource":self.resource.resource(),"catalog":self.catalog.to_string()})
    }
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["realm", "resource", "catalog"])?;
        Self::new(
            ResourceRef::new(n(&v["realm"], false)?, n(&v["resource"], false)?)?,
            w(&v["catalog"], false)?,
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
pub struct TableLimits {
    pub record_bytes: u32,
    pub staging_bytes: u64,
    pub staging_records: u32,
}
impl TableLimits {
    fn wire(&self) -> Result<Value> {
        positive(self.record_bytes.into())?;
        positive(self.staging_records.into())?;
        if self.staging_bytes < u64::from(self.record_bytes) {
            return Err(invalid());
        }
        Ok(
            json!({"record_bytes":self.record_bytes,"staging_bytes":self.staging_bytes.to_string(),"staging_records":self.staging_records}),
        )
    }
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["record_bytes", "staging_bytes", "staging_records"])?;
        let out = Self {
            record_bytes: u32n(&v["record_bytes"], false)?,
            staging_bytes: w(&v["staging_bytes"], false)?,
            staging_records: u32n(&v["staging_records"], false)?,
        };
        out.wire()?;
        Ok(out)
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Configuration {
    pub scope: Scope,
    pub owner: ProcessRef,
    pub administrator: u64,
    pub table_limits: TableLimits,
}
impl Configuration {
    fn wire(&self) -> Result<Value> {
        Connection::new(self.owner, self.scope)?;
        Ok(
            json!({"scope":self.scope.wire(),"owner":self.owner.pid(),"administrator":native(self.administrator,false)?,"table_limits":self.table_limits.wire()?}),
        )
    }
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["scope", "owner", "administrator", "table_limits"])?;
        let scope = Scope::parse(&v["scope"])?;
        Ok(Self {
            scope,
            owner: ProcessRef::new(scope.resource.realm(), n(&v["owner"], false)?)?,
            administrator: n(&v["administrator"], false)?,
            table_limits: TableLimits::parse(&v["table_limits"])?,
        })
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Rights {
    pub inspect: bool,
    pub create: bool,
    pub read: bool,
    pub insert: bool,
    pub update: bool,
    pub delete: bool,
    pub alter: bool,
    pub drop: bool,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Policy {
    pub scope: Scope,
    pub principal: u64,
    pub revision: u64,
    pub rights: Rights,
}
impl Policy {
    fn wire(&self) -> Result<Value> {
        let r = self.rights;
        Ok(
            json!({"scope":self.scope.wire(),"principal":native(self.principal,true)?,"revision":positive(self.revision)?.to_string(),"inspect":r.inspect,"create":r.create,"read":r.read,"insert":r.insert,"update":r.update,"delete":r.delete,"alter":r.alter,"drop":r.drop}),
        )
    }
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "scope",
                "principal",
                "revision",
                "inspect",
                "create",
                "read",
                "insert",
                "update",
                "delete",
                "alter",
                "drop",
            ],
        )?;
        let b = |key| boolean(&v[key], "catalog-right");
        Ok(Self {
            scope: Scope::parse(&v["scope"])?,
            principal: n(&v["principal"], true)?,
            revision: w(&v["revision"], false)?,
            rights: Rights {
                inspect: b("inspect")?,
                create: b("create")?,
                read: b("read")?,
                insert: b("insert")?,
                update: b("update")?,
                delete: b("delete")?,
                alter: b("alter")?,
                drop: b("drop")?,
            },
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PolicyChange {
    pub expected_revision: u64,
    pub policy: Policy,
}
impl PolicyChange {
    fn wire(&self) -> Result<Value> {
        if self.expected_revision.checked_add(1) != Some(self.policy.revision) {
            return Err(invalid());
        }
        Ok(
            json!({"expected_revision":self.expected_revision.to_string(),"policy":self.policy.wire()?}),
        )
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct Column {
    pub id: u64,
    pub name: String,
    pub datatype: Descriptor,
    pub nullable: bool,
    pub default: Option<Cell>,
    pub max_characters: Option<u32>,
}
impl Column {
    pub fn new(id: u64, name: String, datatype: Descriptor) -> Self {
        Self {
            id,
            name,
            datatype,
            nullable: true,
            default: None,
            max_characters: None,
        }
    }
    fn wire(&self) -> Result<Value> {
        let mut out = column(
            &self.name,
            &self.datatype,
            self.nullable,
            self.default.as_ref(),
            self.max_characters,
        )?;
        out["id"] = json!(positive(self.id)?.to_string());
        Ok(out)
    }
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "id",
                "name",
                "type",
                "nullable",
                "default",
                "max_characters",
            ],
        )?;
        Ok(Self {
            id: w(&v["id"], false)?,
            name: name(string(&v["name"], "column-name")?)?.into(),
            datatype: Descriptor::parse(&v["type"])?,
            nullable: boolean(&v["nullable"], "nullable")?,
            default: optional(&v["default"], Cell::parse)?,
            max_characters: optional(&v["max_characters"], |v| u32n(v, false))?,
        })
    }
}
fn column(
    name_: &str,
    datatype: &Descriptor,
    nullable: bool,
    default: Option<&Cell>,
    max_characters: Option<u32>,
) -> Result<Value> {
    if max_characters == Some(0) {
        return Err(invalid());
    }
    Ok(
        json!({"name":name(name_)?,"type":datatype.wire()?,"nullable":nullable,"default":default.map(Cell::wire).transpose()?,"max_characters":max_characters}),
    )
}
#[derive(Clone, Debug, PartialEq)]
pub struct Schema {
    pub object: u64,
    pub revision: u64,
    pub next_column: u64,
    pub columns: Vec<Column>,
    pub primary_key: Vec<u64>,
}
impl Schema {
    fn wire(&self) -> Result<Value> {
        if !(1..=128).contains(&self.columns.len()) || self.primary_key.len() > self.columns.len() {
            return Err(invalid());
        }
        let mut budget = WireBudget(2 * 1024 * 1024);
        let columns = self
            .columns
            .iter()
            .map(|column| budget.take(column.wire()?))
            .collect::<Result<Vec<_>>>()?;
        let keys = self
            .primary_key
            .iter()
            .map(|v| Ok(positive(*v)?.to_string()))
            .collect::<Result<Vec<_>>>()?;
        let out = json!({"definition":abi::ABI_DEFINITION,"object":positive(self.object)?.to_string(),"revision":positive(self.revision)?.to_string(),"next_column":positive(self.next_column)?.to_string(),"columns":columns,"primary_key":keys});
        if serde_json::to_vec(&out).map_err(|_| invalid())?.len() > 2 * 1024 * 1024 {
            return Err(invalid());
        }
        Ok(out)
    }
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "definition",
                "object",
                "revision",
                "next_column",
                "columns",
                "primary_key",
            ],
        )?;
        definition(string(&v["definition"], "schema-definition")?)?;
        let columns = v["columns"]
            .as_array()
            .filter(|v| (1..=128).contains(&v.len()))
            .ok_or_else(malformed)?
            .iter()
            .map(Column::parse)
            .collect::<Result<Vec<_>>>()?;
        let primary_key = v["primary_key"]
            .as_array()
            .filter(|v| v.len() <= columns.len())
            .ok_or_else(malformed)?
            .iter()
            .map(|v| w(v, false))
            .collect::<Result<Vec<_>>>()?;
        let out = Self {
            object: w(&v["object"], false)?,
            revision: w(&v["revision"], false)?,
            next_column: w(&v["next_column"], false)?,
            columns,
            primary_key,
        };
        out.wire()?;
        Ok(out)
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Identity {
    operation: u64,
    namespace: u64,
}
impl Identity {
    pub fn new(operation: u64, namespace: u64) -> Result<Self> {
        Ok(Self {
            operation: positive(operation)?,
            namespace: positive(namespace)?,
        })
    }
    pub fn operation(&self) -> u64 {
        self.operation
    }
    pub fn namespace(&self) -> u64 {
        self.namespace
    }
    fn wire(&self) -> Value {
        json!({"operation":self.operation.to_string(),"namespace":self.namespace.to_string()})
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Basis {
    pub object: u64,
    pub revision: u64,
    pub schema_fingerprint: [u8; 32],
}
impl Basis {
    fn wire(&self) -> Result<Value> {
        Ok(
            json!({"object":positive(self.object)?.to_string(),"revision":positive(self.revision)?.to_string(),"schema_fingerprint":hex(&self.schema_fingerprint,32)?}),
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MetadataCommitment {
    pub bytes: u32,
    pub digest: [u8; 32],
}
impl MetadataCommitment {
    pub(crate) fn wire(&self) -> Result<Value> {
        if !(1..=436).contains(&self.bytes) {
            return Err(invalid());
        }
        Ok(json!({"format":0x54434d01u32,"length":self.bytes,"digest":self.digest}))
    }
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["format", "length", "digest"])?;
        if v["format"] != 0x54434d01u32 {
            return Err(malformed());
        }
        let data = v["digest"]
            .as_array()
            .filter(|v| v.len() == 32)
            .ok_or_else(malformed)?;
        let mut digest = [0u8; 32];
        for (target, byte) in digest.iter_mut().zip(data) {
            *target = n(byte, true)?.try_into().map_err(|_| malformed())?;
        }
        let out = Self {
            bytes: u32n(&v["length"], false)?,
            digest,
        };
        out.wire()?;
        Ok(out)
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Metadata {
    pub scope: Scope,
    pub object: u64,
    pub revision: u64,
    pub name: String,
    pub schema_fingerprint: [u8; 32],
    pub principal: u64,
    pub operation: u64,
    pub admitted_input: u64,
    pub commitment: MetadataCommitment,
}
impl Metadata {
    pub fn basis(&self) -> Basis {
        Basis {
            object: self.object,
            revision: self.revision,
            schema_fingerprint: self.schema_fingerprint,
        }
    }
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "scope",
                "object",
                "revision",
                "name",
                "schema_fingerprint",
                "principal",
                "operation",
                "admitted_input",
                "commitment",
            ],
        )?;
        Ok(Self {
            scope: Scope::parse(&v["scope"])?,
            object: w(&v["object"], false)?,
            revision: w(&v["revision"], false)?,
            name: name(string(&v["name"], "table-name")?)?.into(),
            schema_fingerprint: digest(&v["schema_fingerprint"])?,
            principal: n(&v["principal"], true)?,
            operation: w(&v["operation"], false)?,
            admitted_input: n(&v["admitted_input"], false)?,
            commitment: MetadataCommitment::parse(&v["commitment"])?,
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Head {
    pub revision: u64,
    pub rows: u64,
    pub pending: u64,
}
impl Head {
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["revision", "rows", "pending"])?;
        Ok(Self {
            revision: w(&v["revision"], false)?,
            rows: w(&v["rows"], true)?,
            pending: w(&v["pending"], true)?,
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Entry {
    pub metadata: Metadata,
    pub head: Head,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Definition {
    pub metadata: Metadata,
    pub head: Head,
    pub schema: Schema,
}
#[derive(Clone, Debug, PartialEq)]
pub struct HistoricalDefinition {
    pub metadata: Metadata,
    pub schema: Schema,
}
fn resolved(v: &Value, scope: Scope, requested: &str) -> Result<Option<Definition>> {
    optional(v, |v| {
        object(v, &["metadata", "head", "schema"])?;
        let out = Definition {
            metadata: Metadata::parse(&v["metadata"])?,
            head: Head::parse(&v["head"])?,
            schema: Schema::parse(&v["schema"])?,
        };
        if out.metadata.scope != scope
            || out.metadata.name != requested
            || out.metadata.object != out.schema.object
        {
            return Err(malformed());
        }
        Ok(out)
    })
}
fn historical(
    v: &Value,
    scope: Scope,
    id: u64,
    revision: u64,
) -> Result<Option<HistoricalDefinition>> {
    optional(v, |v| {
        object(v, &["metadata", "schema"])?;
        let out = HistoricalDefinition {
            metadata: Metadata::parse(&v["metadata"])?,
            schema: Schema::parse(&v["schema"])?,
        };
        if out.metadata.scope != scope
            || out.metadata.object != id
            || out.metadata.revision != revision
            || out.schema.object != id
        {
            return Err(malformed());
        }
        Ok(out)
    })
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Cursor {
    definition: String,
    scope: Scope,
    resource_revision: u64,
    after_object: u64,
}
impl Cursor {
    pub fn new(
        definition_: String,
        scope: Scope,
        resource_revision: u64,
        after_object: u64,
    ) -> Result<Self> {
        definition(&definition_)?;
        native(resource_revision, true)?;
        positive(after_object)?;
        Ok(Self {
            definition: definition_,
            scope,
            resource_revision,
            after_object,
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
    pub fn after_object(&self) -> u64 {
        self.after_object
    }
    fn wire(&self) -> Value {
        json!({"definition":self.definition,"scope":self.scope.wire(),"resource_revision":self.resource_revision,"after_object":self.after_object.to_string()})
    }
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &["definition", "scope", "resource_revision", "after_object"],
        )?;
        Self::new(
            string(&v["definition"], "cursor-definition")?.into(),
            Scope::parse(&v["scope"])?,
            n(&v["resource_revision"], true)?,
            w(&v["after_object"], false)?,
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Page {
    pub resource_revision: u64,
    pub entries: Vec<Entry>,
    pub next: Option<Cursor>,
}
impl Page {
    fn parse(v: &Value, scope: Scope, previous: Option<&Cursor>) -> Result<Self> {
        object(v, &["resource_revision", "entries", "next"])?;
        let resource_revision = n(&v["resource_revision"], true)?;
        let slots = v["entries"]
            .as_array()
            .filter(|v| v.len() == 8)
            .ok_or_else(malformed)?;
        let mut entries: Vec<Entry> = Vec::with_capacity(8);
        let mut ended = false;
        for slot in slots {
            if slot.is_null() {
                ended = true;
                continue;
            }
            object(slot, &["metadata", "head"])?;
            let entry = Entry {
                metadata: Metadata::parse(&slot["metadata"])?,
                head: Head::parse(&slot["head"])?,
            };
            if ended
                || entry.metadata.scope != scope
                || entries
                    .last()
                    .is_some_and(|last| last.metadata.object >= entry.metadata.object)
            {
                return Err(malformed());
            }
            entries.push(entry);
        }
        let next = optional(&v["next"], Cursor::parse)?;
        if let Some(c) = &next {
            if c.scope != scope
                || c.resource_revision != resource_revision
                || entries
                    .last()
                    .is_some_and(|last| last.metadata.object > c.after_object)
            {
                return Err(malformed());
            }
        }
        if let Some(p) = previous {
            if p.scope != scope
                || p.resource_revision != resource_revision
                || entries
                    .first()
                    .is_some_and(|first| first.metadata.object <= p.after_object)
                || next
                    .as_ref()
                    .is_some_and(|next| next.after_object <= p.after_object)
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
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Reference {
    definition: String,
    digest: [u8; 32],
}
impl Reference {
    pub fn new(definition_: String, digest: [u8; 32]) -> Result<Self> {
        definition(&definition_)?;
        Ok(Self {
            definition: definition_,
            digest,
        })
    }
    pub fn definition(&self) -> &str {
        &self.definition
    }
    pub fn digest(&self) -> &[u8; 32] {
        &self.digest
    }
    fn wire(&self) -> Value {
        json!({"definition":self.definition,"digest":hex(&self.digest,32).expect("fixed digest width")})
    }
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["definition", "digest"])?;
        Self::new(
            string(&v["definition"], "intent-definition")?.into(),
            digest(&v["digest"])?,
        )
    }
}
#[derive(Clone, Eq, PartialEq)]
pub struct SavedIntent {
    definition: String,
    bytes: Vec<u8>,
}
impl std::fmt::Debug for SavedIntent {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("SavedIntent")
            .field("definition", &self.definition)
            .field("bytes", &self.bytes.len())
            .finish()
    }
}
impl SavedIntent {
    pub fn new(definition_: String, bytes: Vec<u8>) -> Result<Self> {
        definition(&definition_)?;
        if bytes.is_empty() || bytes.len() > abi::CATALOG_INTENT_BYTES {
            return Err(invalid());
        }
        Ok(Self {
            definition: definition_,
            bytes,
        })
    }
    pub fn definition(&self) -> &str {
        &self.definition
    }
    pub fn bytes(&self) -> &[u8] {
        &self.bytes
    }
    fn wire(&self) -> Result<Value> {
        Ok(
            json!({"definition":self.definition,"bytes":hex(&self.bytes,abi::CATALOG_INTENT_BYTES)?}),
        )
    }
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["definition", "bytes"])?;
        Self::new(
            string(&v["definition"], "saved-definition")?.into(),
            bytes(&v["bytes"], abi::CATALOG_INTENT_BYTES)?,
        )
    }
}
#[derive(Clone, Eq, PartialEq)]
pub struct Prepared {
    data: String,
}
impl std::fmt::Debug for Prepared {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Prepared")
            .field("bytes", &self.data.len())
            .finish()
    }
}
impl Prepared {
    pub fn from_data(data: String) -> Result<Self> {
        text(&data, abi::CATALOG_PREPARED_BYTES)?;
        Ok(Self { data })
    }
    pub fn data(&self) -> &str {
        &self.data
    }
}
fn prepared(value: &Value) -> Result<Prepared> {
    Prepared::from_data(string(value, "catalog-prepared")?.into())
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Intent {
    pub reference: Reference,
    pub scope: Scope,
    pub owner: ProcessRef,
    pub principal: u64,
    pub identity: Identity,
    pub object: u64,
    pub kind: Kind,
}
impl Intent {
    fn parse(v: &Value, connection: &Connection, principal: u64) -> Result<Self> {
        object(
            v,
            &[
                "reference",
                "scope",
                "owner",
                "principal",
                "operation",
                "namespace",
                "object",
                "kind",
            ],
        )?;
        let scope = Scope::parse(&v["scope"])?;
        let out = Self {
            reference: Reference::parse(&v["reference"])?,
            scope,
            owner: ProcessRef::new(scope.resource.realm(), n(&v["owner"], false)?)?,
            principal: n(&v["principal"], true)?,
            identity: Identity::new(w(&v["operation"], false)?, w(&v["namespace"], false)?)?,
            object: w(&v["object"], true)?,
            kind: Kind::parse(&v["kind"])?,
        };
        if out.scope != connection.scope
            || out.owner != connection.owner
            || out.principal != principal
        {
            return Err(malformed());
        }
        Ok(out)
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Compiled {
    pub intent: Intent,
    pub saved: SavedIntent,
}
impl Compiled {
    fn parse(
        v: &Value,
        connection: &Connection,
        principal: u64,
        identity: Identity,
        kind: Option<Kind>,
        id: Option<u64>,
    ) -> Result<Self> {
        object(v, &["intent", "saved"])?;
        let out = Self {
            intent: Intent::parse(&v["intent"], connection, principal)?,
            saved: SavedIntent::parse(&v["saved"])?,
        };
        if out.intent.identity != identity
            || kind.is_some_and(|k| k != out.intent.kind)
            || id.is_some_and(|id| id != out.intent.object)
        {
            return Err(malformed());
        }
        Ok(out)
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Counts {
    pub matched: u64,
    pub changed: u64,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Outcome {
    pub kind: Kind,
    pub operation: u64,
    pub object: u64,
    pub actual_object: Option<u64>,
    pub phase: Phase,
    pub terminal: bool,
    pub counts: Option<Counts>,
    pub admitted_input: u64,
    pub completed_input: Option<u64>,
    pub diagnostic: Value,
}
impl Outcome {
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "kind",
                "operation",
                "object",
                "actual_object",
                "phase",
                "terminal",
                "counts",
                "admitted_input",
                "completed_input",
                "diagnostic",
            ],
        )?;
        let kind = Kind::parse(&v["kind"])?;
        let phase = Phase::parse(&v["phase"])?;
        let terminal = boolean(&v["terminal"], "terminal")?;
        if terminal
            != matches!(
                phase,
                Phase::Applied | Phase::Unchanged | Phase::Rejected | Phase::Cancelled
            )
        {
            return Err(malformed());
        }
        let counts = optional(&v["counts"], |v| {
            object(v, &["matched", "changed"])?;
            let out = Counts {
                matched: w(&v["matched"], true)?,
                changed: w(&v["changed"], true)?,
            };
            if out.changed > out.matched {
                return Err(malformed());
            }
            Ok(out)
        })?;
        if counts.is_some()
            != (phase == Phase::Applied
                && matches!(kind, Kind::Insert | Kind::Update | Kind::Delete))
        {
            return Err(malformed());
        }
        Ok(Self {
            kind,
            operation: w(&v["operation"], false)?,
            object: w(&v["object"], true)?,
            actual_object: optional(&v["actual_object"], |v| w(v, true))?,
            phase,
            terminal,
            counts,
            admitted_input: n(&v["admitted_input"], false)?,
            completed_input: optional(&v["completed_input"], |v| n(v, false))?,
            diagnostic: diagnostic(&v["diagnostic"])?,
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Upload {
    pub phase: UploadPhase,
    pub received: usize,
    pub total: usize,
}
impl Upload {
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["phase", "received", "total"])?;
        let received = n(&v["received"], true)? as usize;
        let total = n(&v["total"], false)? as usize;
        if received > total || total > abi::CATALOG_INTENT_BYTES {
            return Err(malformed());
        }
        Ok(Self {
            phase: UploadPhase::parse(&v["phase"])?,
            received,
            total,
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct State {
    pub outcome: Option<Outcome>,
    pub upload: Option<Upload>,
}
impl State {
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["outcome", "upload"])?;
        Ok(Self {
            outcome: optional(&v["outcome"], Outcome::parse)?,
            upload: optional(&v["upload"], Upload::parse)?,
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct Disposition {
    pub input: u64,
    pub outcome: DispositionOutcome,
    pub diagnostic: Value,
}
impl Disposition {
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["input", "outcome", "diagnostic"])?;
        Ok(Self {
            input: n(&v["input"], false)?,
            outcome: DispositionOutcome::parse(&v["outcome"])?,
            diagnostic: diagnostic(&v["diagnostic"])?,
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Next {
    Send(Prepared),
    Running,
    UploadCancelled,
    Terminal(Outcome),
}
impl Next {
    fn parse(v: &Value) -> Result<Self> {
        let (k, v) = variant(v)?;
        Ok(match k {
            "send" => Self::Send(prepared(v)?),
            "terminal" => {
                let out = Outcome::parse(v)?;
                if !out.terminal {
                    return Err(malformed());
                }
                Self::Terminal(out)
            }
            "running" => {
                object(v, &[])?;
                Self::Running
            }
            "upload_cancelled" => {
                object(v, &[])?;
                Self::UploadCancelled
            }
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Progress {
    Pending,
    Processed {
        disposition: Option<Disposition>,
        outcome: Option<Outcome>,
        upload: Option<Upload>,
    },
}
impl Progress {
    fn parse(v: &Value) -> Result<Self> {
        let (k, v) = variant(v)?;
        Ok(match k {
            "pending" => {
                object(v, &[])?;
                Self::Pending
            }
            "processed" => {
                object(v, &["disposition", "outcome", "upload"])?;
                Self::Processed {
                    disposition: optional(&v["disposition"], Disposition::parse)?,
                    outcome: optional(&v["outcome"], Outcome::parse)?,
                    upload: optional(&v["upload"], Upload::parse)?,
                }
            }
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum AssignmentValue {
    Default,
    Cell(Cell),
}
#[derive(Clone, Debug, PartialEq)]
pub struct Assignment {
    pub column: u64,
    pub value: AssignmentValue,
}
fn assignments(values: &[Assignment], budget: &mut WireBudget) -> Result<Value> {
    if values.len() > 128 {
        return Err(invalid());
    }
    let values=values.iter().map(|a|budget.take(json!({"column":positive(a.column)?.to_string(),"value":match &a.value{AssignmentValue::Default=>json!({"default":{}}),AssignmentValue::Cell(cell)=>json!({"cell":cell.wire()?})}}))).collect::<Result<Vec<_>>>()?;
    Ok(json!(values))
}
#[derive(Clone, Debug, PartialEq)]
pub enum Predicate {
    All,
    Negate,
    Conjunction,
    Disjunction,
    State {
        column: u64,
        state: CellState,
    },
    Compare {
        column: u64,
        op: CompareOperator,
        value: Atom,
    },
}
impl Predicate {
    fn wire(&self) -> Result<Value> {
        Ok(match self {
            Self::All => json!({"atom":{"all":{}}}),
            Self::Negate => json!({"negate":{}}),
            Self::Conjunction => json!({"conjunction":{}}),
            Self::Disjunction => json!({"disjunction":{}}),
            Self::State { column, state } => {
                json!({"atom":{"state":{"column":positive(*column)?.to_string(),"value":state.tag()}}})
            }
            Self::Compare { column, op, value } => {
                json!({"atom":{"compare":{"column":positive(*column)?.to_string(),"op":op.tag(),"value":value.wire()?}}})
            }
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Mutation {
    Insert {
        rows: Vec<Vec<Assignment>>,
    },
    Update {
        assignments: Vec<Assignment>,
        predicate: Option<Vec<Predicate>>,
    },
    Delete {
        predicate: Option<Vec<Predicate>>,
    },
}
impl Mutation {
    fn wire(&self) -> Result<(Kind, Value)> {
        let mut budget = WireBudget(abi::CATALOG_ACTION_BYTES);
        let (kind, action, predicate) = match self {
            Self::Insert { rows } => {
                if !(1..=1024).contains(&rows.len()) {
                    return Err(invalid());
                }
                (
                    Kind::Insert,
                    json!({"insert":rows.iter().map(|r|assignments(r, &mut budget)).collect::<Result<Vec<_>>>()?}),
                    None,
                )
            }
            Self::Update {
                assignments: values,
                predicate,
            } => (
                Kind::Update,
                json!({"update":assignments(values, &mut budget)?}),
                predicate.as_ref(),
            ),
            Self::Delete { predicate } => (Kind::Delete, json!({"delete":{}}), predicate.as_ref()),
        };
        let predicate = predicate
            .map(|v| {
                if v.len() > 64 {
                    return Err(invalid());
                }
                v.iter()
                    .map(|p| budget.take(p.wire()?))
                    .collect::<Result<Vec<_>>>()
            })
            .transpose()?;
        Ok((kind, json!({"action":action,"predicate":predicate})))
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Change {
    Add {
        name: String,
        datatype: Descriptor,
        nullable: bool,
        default: Option<Cell>,
        max_characters: Option<u32>,
    },
    Drop {
        column: u64,
    },
    Rename {
        column: u64,
        name: String,
    },
    Default {
        column: u64,
        value: Option<Cell>,
    },
    Nullable {
        column: u64,
        value: bool,
    },
    Type {
        column: u64,
        datatype: Descriptor,
        max_characters: Option<u32>,
    },
}
impl Change {
    fn wire(&self) -> Result<Value> {
        Ok(match self {
            Self::Add {
                name,
                datatype,
                nullable,
                default,
                max_characters,
            } => json!({"add":column(name,datatype,*nullable,default.as_ref(),*max_characters)?}),
            Self::Drop { column } => json!({"drop":positive(*column)?.to_string()}),
            Self::Rename {
                column,
                name: new_name,
            } => json!({"rename":{"column":positive(*column)?.to_string(),"name":name(new_name)?}}),
            Self::Default { column, value } => {
                json!({"default":{"column":positive(*column)?.to_string(),"value":value.as_ref().map(Cell::wire).transpose()?}})
            }
            Self::Nullable { column, value } => {
                json!({"nullable":{"column":positive(*column)?.to_string(),"value":value}})
            }
            Self::Type {
                column,
                datatype,
                max_characters,
            } => {
                if *max_characters == Some(0) {
                    return Err(invalid());
                }
                json!({"type":{"column":positive(*column)?.to_string(),"type":datatype.wire()?,"max_characters":max_characters}})
            }
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Operation {
    Create {
        schema: Schema,
        if_not_exists: bool,
    },
    Alter {
        basis: Basis,
        change: Change,
    },
    Rename {
        basis: Basis,
        name: String,
    },
    Drop {
        basis: Option<Basis>,
        if_exists: bool,
    },
    Mutate {
        basis: Basis,
        mutation: Mutation,
    },
}
impl Operation {
    fn wire(&self) -> Result<(Kind, u64, Value)> {
        Ok(match self {
            Self::Create {
                schema,
                if_not_exists,
            } => (
                Kind::Create,
                schema.object,
                json!({"create":{"schema":schema.wire()?,"if_not_exists":if_not_exists}}),
            ),
            Self::Alter { basis, change } => (
                Kind::Alter,
                basis.object,
                json!({"alter":{"basis":basis.wire()?,"change":change.wire()?}}),
            ),
            Self::Rename {
                basis,
                name: new_name,
            } => (
                Kind::Rename,
                basis.object,
                json!({"rename":{"basis":basis.wire()?,"name":name(new_name)?}}),
            ),
            Self::Drop { basis, if_exists } => (
                Kind::Drop,
                basis.as_ref().map_or(0, |b| b.object),
                json!({"drop":{"basis":basis.as_ref().map(Basis::wire).transpose()?,"if_exists":if_exists}}),
            ),
            Self::Mutate { basis, mutation } => {
                let (kind, mutation) = mutation.wire()?;
                (
                    kind,
                    basis.object,
                    json!({"mutate":{"basis":basis.wire()?,"mutation":mutation}}),
                )
            }
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Dependency {
    pub scope: Scope,
    pub object: u64,
    pub identity: u64,
    pub owner: ProcessRef,
    pub kind: DependencyKind,
}
impl Dependency {
    fn wire(&self, present: bool) -> Result<Value> {
        Connection::new(self.owner, self.scope)?;
        Ok(
            json!({"scope":self.scope.wire(),"object":positive(self.object)?.to_string(),"identity":positive(self.identity)?.to_string(),"owner":self.owner.pid(),"kind":self.kind.tag(),"present":present}),
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Capabilities {
    pub version: u32,
    pub definition: String,
    pub max_columns: usize,
    pub max_rows: usize,
    pub max_sql_bytes: usize,
    pub max_intent_bytes: usize,
    pub max_action_bytes: usize,
    pub max_prepared_bytes: usize,
    pub resident_intents: usize,
}
impl Capabilities {
    pub(crate) fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "version",
                "definition",
                "max_columns",
                "max_rows",
                "max_sql_bytes",
                "max_intent_bytes",
                "max_action_bytes",
                "max_prepared_bytes",
                "resident_intents",
            ],
        )?;
        definition(string(&v["definition"], "catalog-definition")?)?;
        Ok(Self {
            version: u32n(&v["version"], false)?,
            definition: abi::ABI_DEFINITION.into(),
            max_columns: n(&v["max_columns"], false)? as usize,
            max_rows: n(&v["max_rows"], false)? as usize,
            max_sql_bytes: n(&v["max_sql_bytes"], false)? as usize,
            max_intent_bytes: n(&v["max_intent_bytes"], false)? as usize,
            max_action_bytes: n(&v["max_action_bytes"], false)? as usize,
            max_prepared_bytes: n(&v["max_prepared_bytes"], false)? as usize,
            resident_intents: n(&v["resident_intents"], false)? as usize,
        })
    }
    pub(crate) fn supported(&self) -> bool {
        self.version == 1
            && self.max_columns == 128
            && self.max_rows == 1024
            && self.max_sql_bytes == 4096
            && self.max_intent_bytes == abi::CATALOG_INTENT_BYTES
            && self.max_action_bytes == abi::CATALOG_ACTION_BYTES
            && self.max_prepared_bytes == abi::CATALOG_PREPARED_BYTES
            && self.resident_intents == 1
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Description {
    pub configuration: Configuration,
    pub policy: Policy,
    pub resource_revision: u64,
}
impl Description {
    fn parse(v: &Value, connection: &Connection, principal: u64) -> Result<Self> {
        object(v, &["configuration", "policy", "resource_revision"])?;
        let out = Self {
            configuration: Configuration::parse(&v["configuration"])?,
            policy: Policy::parse(&v["policy"])?,
            resource_revision: n(&v["resource_revision"], true)?,
        };
        if out.configuration.scope != connection.scope
            || out.configuration.owner != connection.owner
            || out.policy.scope != connection.scope
            || out.policy.principal != principal
        {
            return Err(malformed());
        }
        Ok(out)
    }
}
fn admission(value: &Value) -> Result<AdmissionReceipt> {
    (|| {
        let receipt = result(value, "receipt")?;
        object(receipt, &["position"])?;
        Ok(AdmissionReceipt {
            position: counter(&receipt["position"], false)?,
        })
    })()
    .map_err(|_: Error| Error::new(ErrorKind::UnknownOutcome, "catalog-receipt"))
}
fn submission(response: Result<Value>) -> Result<AdmissionReceipt> {
    let value = response.map_err(|mut error| {
        if error.kind == ErrorKind::WorkerPanic {
            error.kind = ErrorKind::UnknownOutcome;
        }
        error
    })?;
    admission(&value)
}
fn input(prepared: &Prepared, position: u64) -> Result<Value> {
    Ok(json!({"prepared":prepared.data(),"input":native(position,false)?}))
}

/// One blocking worker and one loaded intent. Mutable borrows serialize calls.
/// Persist the saved definition and bytes, then every Prepared before submission.
/// UnknownOutcome requires reconciliation using that identical Prepared.
pub struct Client {
    connection: Connection,
    principal: u64,
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
        let principal = credential.principal();
        let saved = connection.clone();
        let worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
            CatalogNative::open(&config, &credential, &saved)
        })?;
        Ok(Self {
            connection,
            principal,
            worker,
        })
    }
    pub fn connection(&self) -> &Connection {
        &self.connection
    }
    fn call(&mut self, action: Value) -> Result<Value> {
        self.worker.call(move |native| native.call(action))
    }
    fn query<T>(
        &mut self,
        action: Value,
        tag: &str,
        decode: impl FnOnce(&Value) -> Result<T>,
    ) -> Result<T> {
        let response = self.call(action)?;
        (|| decode(result(&response, tag)?))().map_err(|_| malformed())
    }
    pub fn capabilities(&mut self) -> Result<Capabilities> {
        self.query(
            json!({"capabilities":{}}),
            "capabilities",
            Capabilities::parse,
        )
    }
    pub fn describe(&mut self) -> Result<Description> {
        let connection = self.connection.clone();
        let principal = self.principal;
        self.query(json!({"describe":{}}), "description", |v| {
            Description::parse(v, &connection, principal)
        })
    }
    pub fn lookup(&mut self, name_: &str) -> Result<Option<Definition>> {
        let scope = self.connection.scope;
        self.query(json!({"lookup":name(name_)?}), "definition", |v| {
            resolved(v, scope, name_)
        })
    }
    pub fn definition(&mut self, id: u64, revision: u64) -> Result<Option<HistoricalDefinition>> {
        let scope = self.connection.scope;
        self.query(json!({"definition":{"object":positive(id)?.to_string(),"revision":positive(revision)?.to_string()}}),"historical",|v|historical(v,scope,id,revision))
    }
    pub fn list(&mut self, cursor: Option<&Cursor>) -> Result<Page> {
        let scope = self.connection.scope;
        if cursor.is_some_and(|c| c.scope != scope) {
            return Err(invalid());
        }
        self.query(json!({"list":cursor.map(Cursor::wire)}), "page", |v| {
            Page::parse(v, scope, cursor)
        })
    }
    pub fn compile_sql(
        &mut self,
        sql: &str,
        identity: Identity,
        create_object: Option<u64>,
    ) -> Result<Compiled> {
        if let Some(id) = create_object {
            positive(id)?;
        }
        let connection = self.connection.clone();
        let principal = self.principal;
        self.query(json!({"compile":{"sql":text(sql,4096)?,"identity":identity.wire(),"create_object":create_object.map(|v|v.to_string())}}),"compiled",|v|Compiled::parse(v,&connection,principal,identity,create_object.map(|_|Kind::Create),create_object))
    }
    pub fn prepare(
        &mut self,
        name_: &str,
        identity: Identity,
        operation: &Operation,
    ) -> Result<Compiled> {
        let (kind, id, action) = operation.wire()?;
        let connection = self.connection.clone();
        let principal = self.principal;
        self.query(json!({"prepare":{"definition":abi::ABI_DEFINITION,"identity":identity.wire(),"name":name(name_)?,"action":action}}),"compiled",|v|Compiled::parse(v,&connection,principal,identity,Some(kind),Some(id)))
    }
    pub fn load(&mut self, saved: &SavedIntent) -> Result<Intent> {
        let connection = self.connection.clone();
        let principal = self.principal;
        self.query(json!({"load":saved.wire()?}), "loaded", |v| {
            Intent::parse(v, &connection, principal)
        })
    }
    pub fn forget(&mut self, intent: &Reference) -> Result<()> {
        self.query(json!({"forget":intent.wire()}), "forgotten", |v| {
            object(v, &[])
        })
    }
    pub fn next(&mut self, intent: &Reference) -> Result<Next> {
        self.query(json!({"next":intent.wire()}), "next", Next::parse)
    }
    pub fn status(&mut self, intent: &Reference) -> Result<State> {
        self.query(json!({"status":intent.wire()}), "state", State::parse)
    }
    pub fn prepare_resume(&mut self, intent: &Reference) -> Result<Prepared> {
        self.query(
            json!({"prepare_resume":intent.wire()}),
            "prepared",
            prepared,
        )
    }
    pub fn prepare_control(&mut self, intent: &Reference, control: Control) -> Result<Prepared> {
        self.query(
            json!({"prepare_control":{"intent":intent.wire(),"control":control.tag()}}),
            "prepared",
            prepared,
        )
    }
    pub fn prepare_initialize(&mut self, configuration: &Configuration) -> Result<Prepared> {
        self.query(
            json!({"prepare_initialize":configuration.wire()?}),
            "prepared",
            prepared,
        )
    }
    pub fn prepare_policy(&mut self, change: &PolicyChange) -> Result<Prepared> {
        self.query(
            json!({"prepare_policy":change.wire()?}),
            "prepared",
            prepared,
        )
    }
    pub fn prepare_dependency(
        &mut self,
        dependency: &Dependency,
        present: bool,
    ) -> Result<Prepared> {
        self.query(
            json!({"prepare_dependency":dependency.wire(present)?}),
            "prepared",
            prepared,
        )
    }
    pub fn submit(&mut self, prepared: &Prepared) -> Result<AdmissionReceipt> {
        submission(self.call(json!({"submit":prepared.data()})))
    }
    pub fn observe(
        &mut self,
        prepared: &Prepared,
        position: u64,
        wait: bool,
    ) -> Result<Observation> {
        self.query(
            json!({(if wait{"wait_observe"}else{"observe"}):input(prepared,position)?}),
            "observation",
            Observation::parse,
        )
    }
    pub fn input_disposition(
        &mut self,
        prepared: &Prepared,
        position: u64,
    ) -> Result<Option<Disposition>> {
        self.query(
            json!({"input_disposition":input(prepared,position)?}),
            "disposition",
            |v| optional(v, Disposition::parse),
        )
    }
    pub fn progress(
        &mut self,
        intent: &Reference,
        prepared: &Prepared,
        position: u64,
        wait: bool,
    ) -> Result<Progress> {
        let mut action = input(prepared, position)?;
        action["intent"] = intent.wire();
        self.query(
            json!({(if wait{"wait_progress"}else{"progress"}):action}),
            "progress",
            Progress::parse,
        )
    }
    pub fn close(mut self) -> Result<()> {
        self.worker.close()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::logical::{CellValue, Field, ScalarType};
    #[test]
    fn aggregate_conversion_rejects_before_later_invalid_values() {
        let large = Cell::Value(CellValue::Atom(Atom::Binary(vec![0; 1024 * 1024])));
        let invalid_cell = Cell::Value(CellValue::Atom(Atom::Float64(f64::NAN)));
        let mut first = Column::new(1, "data".into(), Descriptor::Scalar(ScalarType::Binary));
        first.default = Some(large.clone());
        let mut later = Column::new(2, "later".into(), Descriptor::Scalar(ScalarType::Float64));
        later.default = Some(invalid_cell.clone());
        let schema = Schema {
            object: 1,
            revision: 1,
            next_column: 3,
            columns: vec![first, later],
            primary_key: vec![],
        };
        assert_eq!(schema.wire().unwrap_err().phase, "catalog-value");
        let assignment = Assignment {
            column: 1,
            value: AssignmentValue::Cell(large),
        };
        let mut rows = vec![vec![assignment]; 9];
        rows.push(vec![Assignment {
            column: 1,
            value: AssignmentValue::Cell(invalid_cell),
        }]);
        assert_eq!(
            Mutation::Insert { rows }.wire().unwrap_err().phase,
            "catalog-value"
        );
    }
    fn scope() -> Scope {
        Scope::new(ResourceRef::new(46, 7).unwrap(), u64::MAX).unwrap()
    }
    fn metadata() -> Value {
        json!({"scope":scope().wire(),"object":u64::MAX.to_string(),"revision":"2","name":"東京","schema_fingerprint":"ab".repeat(32),"principal":17,"operation":"9","admitted_input":3,"commitment":{"format":0x54434d01u32,"length":200,"digest":vec![1;32]}})
    }
    fn schema() -> Schema {
        Schema {
            object: u64::MAX,
            revision: 1,
            next_column: 2,
            columns: vec![Column::new(
                1,
                "東京".into(),
                Descriptor::Structure(vec![Field {
                    name: "amount".into(),
                    datatype: Descriptor::Decimal {
                        precision: 38,
                        scale: 2,
                    },
                    nullable: false,
                    optional: false,
                }]),
            )],
            primary_key: vec![],
        }
    }
    fn entry() -> Value {
        json!({"metadata":metadata(),"head":{"revision":"3","rows":"1","pending":"0"}})
    }
    fn page() -> Value {
        json!({"resource_revision":3,"entries":[entry(),null,null,null,null,null,null,null],"next":Cursor::new(abi::ABI_DEFINITION.into(),scope(),3,u64::MAX).unwrap().wire()})
    }
    #[test]
    fn historical_metadata_and_pages_preserve_exact_scope_order_and_cuts() {
        let original = page();
        let parsed = Page::parse(&original, scope(), None).unwrap();
        assert_eq!(parsed.entries[0].metadata.object, u64::MAX);
        assert_eq!(
            parsed.entries[0].metadata.commitment,
            MetadataCommitment {
                bytes: 200,
                digest: [1; 32]
            }
        );
        for defect in 0..14 {
            let mut bad = original.clone();
            match defect {
                0 => {
                    bad["entries"][1] = bad["entries"][0].take();
                }
                1 => {
                    bad["entries"][1] = entry();
                }
                2 => {
                    bad["entries"][0]["metadata"]["scope"]["catalog"] = json!("1");
                }
                3 => {
                    bad["next"]["resource_revision"] = json!(4);
                }
                4 => {
                    bad["next"]["after_object"] = json!("1");
                }
                5 => {
                    bad["next"].as_object_mut().unwrap().remove("definition");
                }
                6 => {
                    bad["next"]["definition"] = json!("0".repeat(64));
                }
                7 => {
                    bad["entries"][0]["metadata"]["object"] = json!(u64::MAX);
                }
                8 => {
                    bad["entries"][0]["metadata"]["revision"] = json!("01");
                }
                9 => {
                    bad["entries"].as_array_mut().unwrap().push(Value::Null);
                }
                10 => {
                    bad["entries"][0]["metadata"]
                        .as_object_mut()
                        .unwrap()
                        .remove("commitment");
                }
                11 => {
                    bad["entries"][0]["metadata"]["commitment"]["format"] = json!(0);
                }
                12 => {
                    bad["entries"][0]["metadata"]["commitment"]["length"] = json!(437);
                }
                _ => {
                    bad["entries"][0]["metadata"]["commitment"]["digest"][0] = json!(256);
                }
            }
            assert!(Page::parse(&bad, scope(), None).is_err(), "defect {defect}");
        }
        let previous = Cursor::new(abi::ABI_DEFINITION.into(), scope(), 3, 3).unwrap();
        let empty = json!({"resource_revision":3,"entries":[null,null,null,null,null,null,null,null],"next":Cursor::new(abi::ABI_DEFINITION.into(),scope(),3,4).unwrap().wire()});
        assert!(
            Page::parse(&empty, scope(), Some(&previous))
                .unwrap()
                .entries
                .is_empty()
        );
        assert!(Page::parse(&empty, scope(), parsed.next.as_ref()).is_err());
        let mut history = json!({"metadata":metadata(),"schema":schema().wire().unwrap()});
        assert_eq!(
            historical(&history, scope(), u64::MAX, 2)
                .unwrap()
                .unwrap()
                .schema,
            schema()
        );
        assert!(historical(&history, scope(), u64::MAX, 1).is_err());
        assert!(
            historical(&Value::Null, scope(), u64::MAX, 1)
                .unwrap()
                .is_none()
        );
        history["schema"]["object"] = json!("1");
        assert!(historical(&history, scope(), u64::MAX, 2).is_err());
        history["schema"] = schema().wire().unwrap();
        history["head"] = entry()["head"].clone();
        assert!(historical(&history, scope(), u64::MAX, 2).is_err());
    }
    #[test]
    fn typed_requests_own_wide_nested_values_and_recovery() {
        let saved = SavedIntent::new(abi::ABI_DEFINITION.into(), vec![1, 2, 255]).unwrap();
        let cloned = saved.clone();
        drop(saved);
        assert_eq!(cloned.bytes(), [1, 2, 255]);
        assert!(!format!("{cloned:?}").contains("255"));
        assert!(SavedIntent::new("".into(), vec![1]).is_err());
        assert!(Prepared::from_data("x".repeat(8193)).is_err());
        assert!(Connection::new(ProcessRef::new(47, 1).unwrap(), scope()).is_err());
        let right = Rights {
            inspect: true,
            create: false,
            read: true,
            insert: false,
            update: true,
            delete: false,
            alter: true,
            drop: false,
        };
        let p = Policy {
            scope: scope(),
            principal: 0,
            revision: u64::MAX,
            rights: right,
        };
        assert_eq!(Policy::parse(&p.wire().unwrap()).unwrap(), p);
        assert!(
            PolicyChange {
                expected_revision: u64::MAX,
                policy: p.clone()
            }
            .wire()
            .is_err()
        );
        let data = Cell::Value(CellValue::Structure(vec![Cell::Value(CellValue::Atom(
            Atom::Decimal(i128::MAX),
        ))]));
        let op = Operation::Mutate {
            basis: Basis {
                object: u64::MAX,
                revision: 1,
                schema_fingerprint: [255; 32],
            },
            mutation: Mutation::Insert {
                rows: vec![vec![Assignment {
                    column: 1,
                    value: AssignmentValue::Cell(data),
                }]],
            },
        };
        let (kind, id, wire) = op.wire().unwrap();
        assert_eq!(kind, Kind::Insert);
        assert_eq!(id, u64::MAX);
        assert_eq!(
            wire["mutate"]["mutation"]["action"]["insert"][0][0]["value"]["cell"]["value"]["structure"]
                [0]["value"]["atom"]["decimal"],
            i128::MAX.to_string()
        );
        assert_eq!(Schema::parse(&schema().wire().unwrap()).unwrap(), schema());
        let large = Assignment {
            column: 1,
            value: AssignmentValue::Cell(Cell::Value(CellValue::Atom(Atom::Binary(vec![
                128;
                300000
            ])))),
        };
        assert!(
            serde_json::to_vec(
                &assignments(&[large], &mut WireBudget(abi::CATALOG_ACTION_BYTES)).unwrap()
            )
            .unwrap()
            .len()
                > transit_client::internal::MAX_BODY
        );
        assert!(Descriptor::Scalar(ScalarType::Boolean).wire().is_ok());
    }
    #[test]
    fn compiled_identity_and_recorded_counts_are_not_invented() {
        let connection = Connection::new(ProcessRef::new(46, 3).unwrap(), scope()).unwrap();
        let ids = Identity::new(1, 2).unwrap();
        let original = json!({"intent":{"reference":{"definition":abi::ABI_DEFINITION,"digest":"ab".repeat(32)},"scope":scope().wire(),"owner":3,"principal":17,"operation":"1","namespace":"2","object":"8","kind":"insert"},"saved":{"definition":abi::ABI_DEFINITION,"bytes":"ff"}});
        assert_eq!(
            Compiled::parse(&original, &connection, 17, ids, Some(Kind::Insert), Some(8))
                .unwrap()
                .saved
                .bytes(),
            [255]
        );
        for key in ["operation", "namespace", "object", "owner", "principal"] {
            let mut bad = original.clone();
            bad["intent"][key] = if matches!(key, "owner" | "principal") {
                json!(99)
            } else {
                json!("99")
            };
            assert!(
                Compiled::parse(&bad, &connection, 17, ids, Some(Kind::Insert), Some(8)).is_err()
            );
        }
        let out = json!({"kind":"update","operation":"1","object":"8","actual_object":null,"phase":"applied","terminal":true,"counts":{"matched":"1","changed":"0"},"admitted_input":3,"completed_input":4,"diagnostic":{}});
        assert_eq!(
            Outcome::parse(&out).unwrap().counts,
            Some(Counts {
                matched: 1,
                changed: 0
            })
        );
        for (key, value) in [
            ("counts", Value::Null),
            ("terminal", json!(false)),
            ("phase", json!("preparing")),
            ("kind", json!("alter")),
        ] {
            let mut bad = out.clone();
            bad[key] = value;
            assert!(Outcome::parse(&bad).is_err());
        }
        let mut bad = out;
        bad["counts"]["changed"] = json!("2");
        assert!(Outcome::parse(&bad).is_err());
    }
    #[test]
    fn malformed_success_and_worker_panic_preserve_admission_uncertainty() {
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
        let prepared = Prepared::from_data("original signed command".into()).unwrap();
        let mut worker = Worker::open(abi::MINIMUM_STACK_BYTES, || Ok(false)).unwrap();
        let response = worker.call(|accepted| {
            *accepted = true;
            panic!("injected loss after dispatch");
        });
        assert_eq!(
            submission(response).unwrap_err().kind,
            ErrorKind::UnknownOutcome
        );
        assert_eq!(prepared.data(), "original signed command");
        let _ = worker.close();
    }
}
