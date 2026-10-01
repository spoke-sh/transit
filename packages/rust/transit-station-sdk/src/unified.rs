//! Typed v1 callers. Shared Zig owns source validation, admission and verified pages.
use crate::bridge::{QueryNative, counter, digest, field, signed, unified_codec, wide};
use crate::turn::read_version;
use crate::{Aggregate, Comparison, DocumentReference, ReadVersion, abi};
use serde_json::{Value, json};
use std::path::Path;
use transit_client::internal::{Worker, boolean, hex, number, string, unhex};
use transit_client::{
    AdmissionReceipt, ClientConfig, Credential, Error, ErrorKind, ProcessRef, ResourceRef, Result,
};

fn invalid() -> Error {
    Error::new(ErrorKind::InvalidArgument, "unified-query-value")
}
fn malformed() -> Error {
    Error::new(ErrorKind::IncompatibleNative, "unified-query-response")
}
fn tag(value: &Value) -> Result<(&str, &Value)> {
    let object = value
        .as_object()
        .filter(|v| v.len() == 1)
        .ok_or_else(malformed)?;
    let (name, item) = object.iter().next().ok_or_else(malformed)?;
    Ok((name, item))
}
fn array(value: &Value) -> Result<&Vec<Value>> {
    value.as_array().ok_or_else(malformed)
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Type {
    Int64,
    Uint64,
    Float64,
    Boolean,
    Utf8,
    Binary,
}
impl Type {
    fn wire(self) -> &'static str {
        match self {
            Self::Int64 => "int64",
            Self::Uint64 => "uint64",
            Self::Float64 => "float64",
            Self::Boolean => "boolean",
            Self::Utf8 => "utf8",
            Self::Binary => "binary",
        }
    }
    fn parse(value: &Value) -> Result<Self> {
        Ok(match string(value, "query-type")? {
            "int64" => Self::Int64,
            "uint64" => Self::Uint64,
            "float64" => Self::Float64,
            "boolean" => Self::Boolean,
            "utf8" => Self::Utf8,
            "binary" => Self::Binary,
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, PartialEq)]
pub enum Scalar {
    Int64(i64),
    Uint64(u64),
    Float64(f64),
    Boolean(bool),
    Utf8(String),
    Binary(Vec<u8>),
}
impl Scalar {
    fn wire(&self) -> Result<Value> {
        Ok(match self {
            Self::Int64(v) => json!({"int64":v.to_string()}),
            Self::Uint64(v) => json!({"uint64":v.to_string()}),
            Self::Float64(v) if v.is_finite() => json!({"float_bits":hex(&v.to_le_bytes(),8)?}),
            Self::Boolean(v) => json!({"boolean":v}),
            Self::Utf8(v) if v.len() <= 4096 => json!({"utf8":v}),
            Self::Binary(v) => json!({"binary":hex(v,4096)?}),
            _ => return Err(invalid()),
        })
    }
    fn parse(value: &Value) -> Result<Self> {
        let (name, v) = tag(value)?;
        let out = match name {
            "int64" => Self::Int64(signed(v)?),
            "uint64" => Self::Uint64(wide(v)?),
            "float_bits" => Self::Float64(f64::from_le_bytes(
                unhex(string(v, "query-float")?, 8)?
                    .try_into()
                    .map_err(|_| malformed())?,
            )),
            "boolean" => Self::Boolean(boolean(v, "query-bool")?),
            "utf8" => Self::Utf8(string(v, "query-text")?.to_owned()),
            "binary" => Self::Binary(unhex(string(v, "query-binary")?, 4096)?),
            _ => return Err(malformed()),
        };
        out.wire()?;
        Ok(out)
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum State {
    Missing,
    Null,
    TypeError,
    Value,
    Conflict,
}
impl State {
    fn wire(self) -> &'static str {
        match self {
            Self::Missing => "missing",
            Self::Null => "null",
            Self::TypeError => "type_error",
            Self::Value => "value",
            Self::Conflict => "conflict",
        }
    }
}
#[derive(Clone)]
pub enum AlternativeValue {
    Null,
    TypeError(String),
    Value(Scalar),
}
#[derive(Clone)]
pub struct Alternative {
    pub counter: u64,
    pub replica: u64,
    pub value: AlternativeValue,
}
#[derive(Clone)]
pub enum Cell {
    Missing,
    Null,
    TypeError(String),
    Value(Scalar),
    Conflict(Vec<Alternative>),
}
impl Cell {
    fn parse(value: &Value) -> Result<Self> {
        let (name, v) = tag(value)?;
        Ok(match name {
            "missing" => Self::Missing,
            "null" => Self::Null,
            "type_error" => Self::TypeError(string(v, "query-kind")?.to_owned()),
            "value" => Self::Value(Scalar::parse(v)?),
            "conflict" => Self::Conflict(
                array(v)?
                    .iter()
                    .map(|item| {
                        let value = match Self::parse(field(item, "value")?)? {
                            Self::Null => AlternativeValue::Null,
                            Self::TypeError(v) => AlternativeValue::TypeError(v),
                            Self::Value(v) => AlternativeValue::Value(v),
                            _ => return Err(malformed()),
                        };
                        let counter = wide(field(item, "counter")?)?;
                        let replica = wide(field(item, "replica")?)?;
                        if counter == 0 || replica == 0 {
                            return Err(malformed());
                        }
                        Ok(Alternative {
                            counter,
                            replica,
                            value,
                        })
                    })
                    .collect::<Result<_>>()?,
            ),
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Column {
    pub name: String,
    pub value_type: Type,
}
impl Column {
    fn wire(&self) -> Result<Value> {
        if self.name.len() > 64 {
            return Err(invalid());
        }
        Ok(json!({"name":self.name,"type":self.value_type.wire()}))
    }
    fn parse(v: &Value) -> Result<Self> {
        let out = Self {
            name: string(field(v, "name")?, "query-column")?.to_owned(),
            value_type: Type::parse(field(v, "type")?)?,
        };
        out.wire()?;
        Ok(out)
    }
}
#[derive(Clone, Copy, Debug)]
pub struct Decoder {
    pub version: u8,
    pub value_type: Type,
}
impl Decoder {
    pub fn v1(value_type: Type) -> Self {
        Self {
            version: 1,
            value_type,
        }
    }
    fn wire(self) -> Value {
        json!({"version":self.version,"type":self.value_type.wire()})
    }
}
#[derive(Clone, Copy, Debug, Default)]
pub enum ProjectionMode {
    #[default]
    Scalar,
    Text,
    ElementCounter,
    ElementReplica,
}
#[derive(Clone)]
pub struct Projection {
    pub column: Column,
    pub path: Vec<String>,
    pub relative: bool,
    pub mode: ProjectionMode,
    pub text_bytes: u16,
    pub text_steps: u16,
}
fn path(names: &[String]) -> Result<Value> {
    if names.len() > 8 || names.iter().any(|v| v.len() > 64) {
        return Err(invalid());
    }
    Ok(json!(names))
}
#[derive(Clone)]
pub enum Source {
    KV {
        resource: ResourceRef,
        prefix: Vec<u8>,
        key: Decoder,
        value: Decoder,
    },
    Table {
        resource: ResourceRef,
        table: u32,
        names: [String; 2],
        value_type: Type,
    },
    Document {
        reference: DocumentReference,
        expand: Option<Vec<String>>,
        projections: Vec<Projection>,
    },
}
impl Source {
    pub fn resource(&self) -> ResourceRef {
        match self {
            Self::KV { resource, .. } | Self::Table { resource, .. } => *resource,
            Self::Document { reference, .. } => reference.resource(),
        }
    }
    fn wire(&self) -> Result<Value> {
        let source = match self {
            Self::KV {
                prefix, key, value, ..
            } => json!({"kv":{"prefix":hex(prefix,32)?,"key":key.wire(),"value":value.wire()}}),
            Self::Table {
                table,
                names,
                value_type,
                ..
            } => json!({"table":{"id":table,"names":names,"value_type":value_type.wire()}}),
            Self::Document {
                reference: r,
                expand,
                projections,
            } => {
                if projections.is_empty() || projections.len() > 8 {
                    return Err(invalid());
                }
                let projections = projections.iter().map(|v|Ok(json!({"column":v.column.wire()?,"path":path(&v.path)?,"relative":v.relative,
                    "mode":match v.mode {ProjectionMode::Scalar=>"scalar",ProjectionMode::Text=>"text",ProjectionMode::ElementCounter=>"element_counter",ProjectionMode::ElementReplica=>"element_replica"},
                    "text_bytes":v.text_bytes,"text_steps":v.text_steps}))).collect::<Result<Vec<_>>>()?;
                json!({"document":{"reference":{"resource":r.resource().resource(),"document":r.document().to_string(),"epoch":r.epoch().to_string(),"type_revision":r.type_revision(),"revision":r.revision().to_string()},
                    "change_format":1,"expand":expand.as_deref().map(path).transpose()?,"projections":projections}})
            }
        };
        Ok(json!({"version":1,"resource":self.resource().resource(),"source":source}))
    }
}
#[derive(Clone, Default)]
pub enum Predicate {
    #[default]
    All,
    State {
        column: u8,
        state: State,
    },
    Compare {
        column: u8,
        comparison: Comparison,
        value: Scalar,
    },
}
#[derive(Clone)]
pub struct Plan {
    pub projection: Vec<u8>,
    pub output_names: Option<Vec<Option<String>>>,
    pub predicate: Predicate,
    pub limit: Option<u64>,
    pub aggregate: Aggregate,
}
impl Plan {
    fn wire(&self) -> Result<Value> {
        if self
            .output_names
            .as_ref()
            .is_some_and(|names| names.len() != self.projection.len())
        {
            return Err(invalid());
        }
        let predicate = match &self.predicate {
            Predicate::All => json!({"all":{}}),
            Predicate::State { column, state } => {
                json!({"state":{"column":column,"value":state.wire()}})
            }
            Predicate::Compare {
                column,
                comparison,
                value,
            } => {
                json!({"compare":{"column":column,"op":match comparison {Comparison::Eq=>"eq",Comparison::Ne=>"ne",Comparison::Lt=>"lt",Comparison::Le=>"le",Comparison::Gt=>"gt",Comparison::Ge=>"ge"},"value":value.wire()?}})
            }
        };
        Ok(
            json!({"version":1,"projection":self.projection,"output_names":self.output_names,"predicate":predicate,"limit":self.limit.map(|v|v.to_string()),"aggregate":match self.aggregate {Aggregate::Rows=>"rows",Aggregate::Count=>"count",Aggregate::Sum=>"sum"}}),
        )
    }
}
#[derive(Clone, Copy, Debug)]
pub struct Budgets {
    pub pages: u64,
    pub segments: u64,
    pub result_bytes: u64,
}
impl Budgets {
    fn wire(self) -> Result<Value> {
        if self.pages == 0 || self.segments == 0 || self.result_bytes == 0 {
            return Err(invalid());
        }
        Ok(
            json!({"pages":self.pages.to_string(),"segments":self.segments.to_string(),"result_bytes":self.result_bytes.to_string()}),
        )
    }
    fn parse(v: &Value) -> Result<Self> {
        let out = Self {
            pages: wide(field(v, "pages")?)?,
            segments: wide(field(v, "segments")?)?,
            result_bytes: wide(field(v, "result_bytes")?)?,
        };
        out.wire()?;
        Ok(out)
    }
}
#[derive(Clone)]
pub struct Bundle(Vec<u8>);
impl Bundle {
    pub fn from_bytes(data: Vec<u8>) -> Result<Self> {
        if data.len() > 16384 {
            return Err(invalid());
        }
        Ok(Self(data))
    }
    pub fn data(&self) -> &[u8] {
        &self.0
    }
    pub fn prepare(
        source: &Source,
        plan: &Plan,
        budgets: Budgets,
        native_directory: Option<&Path>,
    ) -> Result<Self> {
        let v = unified_codec(
            json!({"prepare":{"source":source.wire()?,"plan":plan.wire()?,"limits":budgets.wire()?}}),
            native_directory,
        )?;
        Self::from_bytes(unhex(
            string(field(field(&v, "prepared")?, "bytes")?, "query-bundle")?,
            16384,
        )?)
    }
}
pub fn decode_arrow(
    columns: &[Column],
    ipc: &[u8],
    rows: u8,
    native_directory: Option<&Path>,
) -> Result<Vec<Vec<Cell>>> {
    let v = unified_codec(
        json!({"inspect_arrow":{"columns":columns.iter().map(Column::wire).collect::<Result<Vec<_>>>()?,"ipc":hex(ipc,65536)?,"rows":rows}}),
        native_directory,
    )?;
    array(field(&v, "rows")?)?
        .iter()
        .map(|row| array(row)?.iter().map(Cell::parse).collect())
        .collect()
}
#[derive(Clone, Debug)]
pub struct Connection {
    source: ProcessRef,
    resource: ResourceRef,
    requester: ProcessRef,
    requests: ResourceRef,
}
impl Connection {
    pub fn new(
        source: ProcessRef,
        resource: ResourceRef,
        requester: ProcessRef,
        requests: ResourceRef,
    ) -> Result<Self> {
        if [resource.realm(), requester.realm(), requests.realm()]
            .iter()
            .any(|r| *r != source.realm())
        {
            return Err(invalid());
        }
        Ok(Self {
            source,
            resource,
            requester,
            requests,
        })
    }
    pub fn source(&self) -> ProcessRef {
        self.source
    }
    pub fn resource(&self) -> ResourceRef {
        self.resource
    }
    pub fn requester(&self) -> ProcessRef {
        self.requester
    }
    pub fn requests(&self) -> ResourceRef {
        self.requests
    }
    pub(crate) fn wire(&self, principal: u64) -> Value {
        json!({"realm":self.source.realm(),"principal":principal,"source":self.source.pid(),"resource":self.resource.resource(),"requester":self.requester.pid(),"requests":self.requests.resource()})
    }
}
/// Opaque signed bytes, retained independently of the client before dispatch.
#[derive(Clone)]
pub struct Prepared(String);
impl Prepared {
    pub fn from_data(data: String) -> Result<Self> {
        if data.len() > 8192 {
            return Err(invalid());
        }
        Ok(Self(data))
    }
    pub fn data(&self) -> &str {
        &self.0
    }
}
#[derive(Clone)]
pub struct Cursor(String);
impl Cursor {
    pub fn from_data(data: String) -> Result<Self> {
        if data.len() > 4096 {
            return Err(invalid());
        }
        Ok(Self(data))
    }
    pub fn data(&self) -> &str {
        &self.0
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Phase {
    Uploading,
    Sealed,
    Admitted,
    Complete,
    Cancelled,
    Denied,
    Rejected,
    Retired,
}
impl Phase {
    fn parse(v: &Value) -> Result<Self> {
        Ok(match string(v, "query-phase")? {
            "uploading" => Self::Uploading,
            "sealed" => Self::Sealed,
            "admitted" => Self::Admitted,
            "complete" => Self::Complete,
            "cancelled" => Self::Cancelled,
            "denied" => Self::Denied,
            "rejected" => Self::Rejected,
            "retired" => Self::Retired,
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone)]
pub struct Status {
    pub phase: Phase,
    pub correlation: u64,
    pub reference: Vec<u8>,
    pub manifest: Option<Vec<u8>>,
    pub collected: bool,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Observation {
    Pending,
    Committed,
    Rejected(String),
}
#[derive(Clone, Debug)]
pub struct Description {
    pub resource_revision: u64,
    pub policy_revision: u64,
    pub limits: Budgets,
    pub active: Option<u64>,
    pub bundle_bytes: u64,
    pub segment_bytes: u64,
    pub batch_rows: u64,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SourceKind {
    KV,
    Table,
    Document,
}
impl SourceKind {
    fn parse(value: &Value) -> Result<Self> {
        Ok(match string(value, "source-kind")? {
            "kv" => Self::KV,
            "table" => Self::Table,
            "document" => Self::Document,
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum InspectionOperator {
    Scan,
    Filter,
    Limit,
    Project,
    Count,
    Sum,
}
/// Predicate structure only. Inspection never returns the query's literal.
#[derive(Clone, Debug)]
pub enum InspectedPredicate {
    All,
    State {
        column: String,
        state: State,
    },
    Compare {
        column: String,
        comparison: Comparison,
        value_type: Type,
    },
}
#[derive(Clone, Debug)]
pub enum InspectionDetails {
    Description {
        columns: Vec<Column>,
    },
    Tables {
        names: Vec<String>,
    },
    Explanation {
        operators: Vec<InspectionOperator>,
        predicate: InspectedPredicate,
        projection: Vec<String>,
        limit: Option<u64>,
        aggregate: Aggregate,
        columns: Vec<Column>,
        budgets: Budgets,
    },
}
/// Owned current metadata for one configured source; not a retained query cut.
#[derive(Clone, Debug)]
pub struct Inspection {
    pub name: String,
    pub resource: ResourceRef,
    pub source_kind: SourceKind,
    pub source_digest: [u8; 32],
    pub schema_digest: [u8; 32],
    pub resource_revision: u64,
    pub policy_revision: u64,
    pub details: InspectionDetails,
}
impl Inspection {
    fn parse(v: &Value, resource: ResourceRef) -> Result<Self> {
        if v["version"] != 1
            || v["scope"] != "configured_source"
            || v["resource"] != resource.resource()
        {
            return Err(malformed());
        }
        fn names(v: &Value) -> Result<Vec<String>> {
            array(v)?
                .iter()
                .map(|name| Ok(string(name, "inspection-name")?.to_owned()))
                .collect()
        }
        fn columns(v: &Value) -> Result<Vec<Column>> {
            array(field(v, "columns")?)?
                .iter()
                .map(Column::parse)
                .collect()
        }
        let (kind, data) = tag(field(v, "details")?)?;
        let details = match kind {
            "description" => InspectionDetails::Description {
                columns: columns(data)?,
            },
            "tables" => InspectionDetails::Tables {
                names: names(data)?,
            },
            "explanation" => {
                let operators = array(field(data, "operators")?)?
                    .iter()
                    .map(|op| {
                        Ok(match string(op, "inspection-operator")? {
                            "scan" => InspectionOperator::Scan,
                            "filter" => InspectionOperator::Filter,
                            "limit" => InspectionOperator::Limit,
                            "project" => InspectionOperator::Project,
                            "count" => InspectionOperator::Count,
                            "sum" => InspectionOperator::Sum,
                            _ => return Err(malformed()),
                        })
                    })
                    .collect::<Result<Vec<_>>>()?;
                if !(2..=4).contains(&operators.len()) {
                    return Err(malformed());
                }
                let (kind, selection) = tag(field(data, "predicate")?)?;
                let predicate = match kind {
                    "all" => InspectedPredicate::All,
                    "state" => InspectedPredicate::State {
                        column: string(field(selection, "column")?, "inspection-column")?
                            .to_owned(),
                        state: match string(field(selection, "value")?, "inspection-state")? {
                            "missing" => State::Missing,
                            "null" => State::Null,
                            "type_error" => State::TypeError,
                            "value" => State::Value,
                            "conflict" => State::Conflict,
                            _ => return Err(malformed()),
                        },
                    },
                    "compare" => InspectedPredicate::Compare {
                        column: string(field(selection, "column")?, "inspection-column")?
                            .to_owned(),
                        comparison: match string(field(selection, "op")?, "inspection-comparison")?
                        {
                            "eq" => Comparison::Eq,
                            "ne" => Comparison::Ne,
                            "lt" => Comparison::Lt,
                            "le" => Comparison::Le,
                            "gt" => Comparison::Gt,
                            "ge" => Comparison::Ge,
                            _ => return Err(malformed()),
                        },
                        value_type: Type::parse(field(selection, "type")?)?,
                    },
                    _ => return Err(malformed()),
                };
                InspectionDetails::Explanation {
                    operators,
                    predicate,
                    projection: names(field(data, "projection")?)?,
                    limit: if field(data, "limit")?.is_null() {
                        None
                    } else {
                        Some(wide(field(data, "limit")?)?)
                    },
                    aggregate: match string(field(data, "aggregate")?, "inspection-aggregate")? {
                        "rows" => Aggregate::Rows,
                        "count" => Aggregate::Count,
                        "sum" => Aggregate::Sum,
                        _ => return Err(malformed()),
                    },
                    columns: columns(data)?,
                    budgets: Budgets::parse(field(data, "budgets")?)?,
                }
            }
            _ => return Err(malformed()),
        };
        Ok(Self {
            name: string(field(v, "name")?, "inspection-name")?.to_owned(),
            resource,
            source_kind: SourceKind::parse(field(v, "source_kind")?)?,
            source_digest: digest(field(v, "contract")?)?,
            schema_digest: digest(field(v, "schema")?)?,
            resource_revision: number(field(v, "resource_revision")?, "revision", true)?,
            policy_revision: wide(field(v, "policy_revision")?)?,
            details,
        })
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Finished {
    SourceEnd,
    Limit,
}
#[derive(Clone, Debug)]
pub struct Manifest {
    pub job: u64,
    pub source: ReadVersion,
    pub requester: ProcessRef,
    pub correlation: u64,
    pub policy_revision: u64,
    pub request: Vec<u8>,
    pub source_kind: SourceKind,
    pub resource: ResourceRef,
    pub revision: u64,
    pub source_digest: [u8; 32],
    pub schema_digest: [u8; 32],
    pub plan_digest: [u8; 32],
    pub pages: u64,
    pub scanned: u64,
    pub selected: u64,
    pub segments: u64,
    pub rows: u64,
    pub byte_count: u64,
    pub sum: Option<i64>,
    pub finished: Finished,
    pub chain: [u8; 32],
}
#[derive(Clone)]
pub struct Page {
    pub manifest: Manifest,
    pub columns: Vec<Column>,
    pub ordinal: u64,
    pub rows: u8,
    ipc: Vec<u8>,
    pub next: Option<Cursor>,
}
impl Page {
    pub fn ipc(&self) -> &[u8] {
        &self.ipc
    }
    pub fn decode(&self, native_directory: Option<&Path>) -> Result<Vec<Vec<Cell>>> {
        decode_arrow(&self.columns, &self.ipc, self.rows, native_directory)
    }
    #[cfg(feature = "arrow")]
    pub fn to_arrow(&self) -> Result<arrow_array::RecordBatch> {
        let mut reader =
            arrow_ipc::reader::StreamReader::try_new(std::io::Cursor::new(&self.ipc), None)
                .map_err(|_| malformed())?;
        let batch = reader
            .next()
            .ok_or_else(malformed)?
            .map_err(|_| malformed())?;
        if reader.next().is_some() || batch.num_rows() != usize::from(self.rows) {
            return Err(malformed());
        }
        Ok(batch)
    }
    fn parse(v: &Value, realm: u64) -> Result<Self> {
        let m = field(v, "manifest")?;
        let basis = field(m, "basis")?;
        let manifest = Manifest {
            job: number(field(m, "job")?, "job", false)?,
            source: read_version(field(m, "source")?)?,
            requester: ProcessRef::new(realm, number(field(m, "requester")?, "requester", false)?)?,
            correlation: wide(field(m, "correlation")?)?,
            policy_revision: wide(field(m, "policy_revision")?)?,
            request: unhex(string(field(m, "request")?, "request")?, 72)?,
            source_kind: SourceKind::parse(field(basis, "kind")?)?,
            resource: ResourceRef::new(
                realm,
                number(field(basis, "resource")?, "resource", false)?,
            )?,
            revision: number(field(basis, "revision")?, "revision", true)?,
            source_digest: digest(field(basis, "contract")?)?,
            schema_digest: digest(field(basis, "schema")?)?,
            plan_digest: digest(field(m, "plan")?)?,
            pages: wide(field(m, "pages")?)?,
            scanned: wide(field(m, "scanned")?)?,
            selected: wide(field(m, "selected")?)?,
            segments: wide(field(m, "segments")?)?,
            rows: wide(field(m, "rows")?)?,
            byte_count: wide(field(m, "bytes")?)?,
            sum: if m["sum"].is_null() {
                None
            } else {
                Some(signed(field(m, "sum")?)?)
            },
            finished: match string(field(m, "finished")?, "finished")? {
                "source_end" => Finished::SourceEnd,
                "limit" => Finished::Limit,
                _ => return Err(malformed()),
            },
            chain: digest(field(m, "chain")?)?,
        };
        let rows = number(field(v, "rows")?, "rows", true)?;
        if rows > 8 {
            return Err(malformed());
        }
        Ok(Self {
            manifest,
            columns: array(field(v, "columns")?)?
                .iter()
                .map(Column::parse)
                .collect::<Result<_>>()?,
            ordinal: wide(field(v, "ordinal")?)?,
            rows: rows as u8,
            ipc: unhex(string(field(v, "ipc")?, "ipc")?, 65536)?,
            next: if v["next"].is_null() {
                None
            } else {
                Some(Cursor::from_data(
                    string(field(v, "next")?, "cursor")?.to_owned(),
                )?)
            },
        })
    }
}
/// Blocking API on one owned native worker. Mutable borrows prevent overlap;
/// close/drop joins native destruction. Use a blocking host task on executors.
pub struct Client {
    connection: Connection,
    worker: Worker<QueryNative>,
}
impl Client {
    pub fn open(
        config: ClientConfig,
        credential: Credential,
        connection: Connection,
    ) -> Result<Self> {
        if credential.realm() != connection.source.realm() {
            return Err(invalid());
        }
        let saved = connection.clone();
        let worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
            QueryNative::open(&config, &credential, &saved)
        })?;
        Ok(Self { connection, worker })
    }
    pub fn connection(&self) -> &Connection {
        &self.connection
    }
    fn call(&mut self, action: Value) -> Result<Value> {
        self.worker.call(move |native| native.call(action))
    }
    pub fn describe(&mut self, source: &Source) -> Result<Description> {
        if source.resource() != self.connection.resource {
            return Err(invalid());
        }
        let response = self.call(json!({"describe":source.wire()?}))?;
        let v = field(&response, "description")?;
        let caps = field(v, "capabilities")?;
        Ok(Description {
            resource_revision: number(field(v, "resource_revision")?, "revision", true)?,
            policy_revision: wide(field(v, "policy_revision")?)?,
            limits: Budgets::parse(field(v, "limits")?)?,
            active: if v["active"].is_null() {
                None
            } else {
                Some(wide(field(v, "active")?)?)
            },
            bundle_bytes: number(field(caps, "bundle_bytes")?, "bound", false)?,
            segment_bytes: number(field(caps, "segment_bytes")?, "bound", false)?,
            batch_rows: number(field(caps, "batch_rows")?, "bound", false)?,
        })
    }
    pub fn inspect_sql(
        &mut self,
        source: &Source,
        name: &str,
        sql: &str,
        budgets: Budgets,
    ) -> Result<Inspection> {
        if source.resource() != self.connection.resource || name.len() > 32 || sql.len() > 4096 {
            return Err(invalid());
        }
        let response = self.call(json!({"inspect":{"scope":{"source":source.wire()?,"name":name,"limits":budgets.wire()?},"sql":sql}}))?;
        Inspection::parse(field(&response, "inspection")?, self.connection.resource)
    }
    pub fn prepare_next(&mut self, namespace: u64, bundle: &Bundle) -> Result<Option<Prepared>> {
        if namespace == 0 {
            return Err(invalid());
        }
        let v = self.call(
            json!({"next":{"namespace":namespace.to_string(),"bundle":hex(bundle.data(),16384)?}}),
        )?;
        let prepared = field(&v, "prepared")?;
        if prepared.is_null() {
            Ok(None)
        } else {
            Ok(Some(Prepared::from_data(
                string(prepared, "prepared")?.to_owned(),
            )?))
        }
    }
    fn control(&mut self, name: &str, namespace: u64) -> Result<Prepared> {
        if namespace == 0 {
            return Err(invalid());
        }
        let v = self.call(json!({"prepare":{name:namespace.to_string()}}))?;
        Prepared::from_data(string(field(&v, "prepared")?, "prepared")?.to_owned())
    }
    pub fn prepare_cancel(&mut self, namespace: u64) -> Result<Prepared> {
        self.control("cancel", namespace)
    }
    pub fn prepare_retire(&mut self, namespace: u64) -> Result<Prepared> {
        self.control("retire", namespace)
    }
    pub fn prepare_collect(&mut self, namespace: u64) -> Result<Prepared> {
        self.control("collect", namespace)
    }
    /// Borrows rather than consumes recovery material. UnknownOutcome requires
    /// resubmitting this identical Prepared; do not generate another command.
    pub fn submit(&mut self, prepared: &Prepared) -> Result<AdmissionReceipt> {
        let v = self.call(json!({"submit":prepared.data()}))?;
        (|| {
            Ok(AdmissionReceipt {
                position: counter(field(field(&v, "receipt")?, "position")?, false)?,
            })
        })()
        .map_err(|_: Error| Error::new(ErrorKind::UnknownOutcome, "query-receipt"))
    }
    pub fn observe(&mut self, position: u64) -> Result<Observation> {
        let v = self.call(json!({"observe":position}))?;
        let (kind, value) = tag(field(&v, "observation")?)?;
        Ok(match kind {
            "pending" => Observation::Pending,
            "committed" => Observation::Committed,
            "rejected" => Observation::Rejected(
                String::from_utf8(unhex(string(value, "rejection")?, 256)?)
                    .map_err(|_| malformed())?,
            ),
            _ => return Err(malformed()),
        })
    }
    pub fn status(&mut self, namespace: u64) -> Result<Option<Status>> {
        if namespace == 0 {
            return Err(invalid());
        }
        let response = self.call(json!({"status":namespace.to_string()}))?;
        let v = field(&response, "status")?;
        if v.is_null() {
            return Ok(None);
        }
        Ok(Some(Status {
            phase: Phase::parse(field(v, "phase")?)?,
            correlation: wide(field(v, "correlation")?)?,
            reference: unhex(string(field(v, "reference")?, "reference")?, 72)?,
            manifest: if v["manifest"].is_null() {
                None
            } else {
                Some(unhex(string(field(v, "manifest")?, "manifest")?, 72)?)
            },
            collected: boolean(field(v, "collected")?, "collected")?,
        }))
    }
    pub fn page(&mut self, namespace: u64, cursor: Option<&Cursor>) -> Result<Page> {
        if namespace == 0 {
            return Err(invalid());
        }
        let v = self.call(
            json!({"page":{"namespace":namespace.to_string(),"cursor":cursor.map(Cursor::data)}}),
        )?;
        Page::parse(field(&v, "page")?, self.connection.source.realm())
    }
    pub fn close(&mut self) -> Result<()> {
        self.worker.close()
    }
}
