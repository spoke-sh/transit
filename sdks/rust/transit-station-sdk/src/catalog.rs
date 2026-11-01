//! Direct Table lifecycle with owned original work and explicit retained snapshots.
use crate::abi;
use crate::bridge::{CatalogNative, field, wide};
use crate::logical::{Atom, Cell, Descriptor};
use serde_json::{Value, json};
use transit_client::internal::{Worker, boolean, number, string, unhex};
use transit_client::{ClientConfig, Counter, Credential, Error, ErrorKind, ResourceRef, Result};

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
    let value = value
        .as_str()
        .filter(|s| s.len() <= bound.saturating_mul(2))
        .ok_or_else(malformed)?;
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
macro_rules! tags {
    (both $name:ident {$($variant:ident => $tag:literal),+ $(,)?}) => {
        tags!(read $name {$($variant => $tag),+});
        impl $name { fn tag(self)-> &'static str { match self {$(Self::$variant => $tag),+} } }
    };
    (read $name:ident {$($variant:ident => $tag:literal),+ $(,)?}) => {
        #[derive(Clone, Copy, Debug, Eq, PartialEq)] pub enum $name {$($variant),+}
        impl $name { fn parse(value:&Value)->Result<Self>{Ok(match string(value,"catalog-tag")? {$($tag=>Self::$variant,)+ _=>return Err(malformed())})} }
    };
    (write $name:ident {$($variant:ident => $tag:literal),+ $(,)?}) => {
        #[derive(Clone, Copy, Debug, Eq, PartialEq)] pub enum $name {$($variant),+}
        impl $name { fn tag(self)-> &'static str { match self {$(Self::$variant => $tag),+} } }
    };
}
tags!(both Encoding {Plain=>"plain",Bitpacked=>"bitpacked",Rle=>"rle",Dictionary=>"dictionary",Fsst=>"fsst",Comp=>"comp",Comp3=>"comp_3",Zoned=>"zoned",IbmHfp=>"ibm_hfp",Ebcdic=>"ebcdic"});
tags!(both Collation {None=>"none",Utf8Binary=>"utf8_binary",AsciiCi=>"ascii_ci",EbcdicCp037=>"ebcdic_cp037",IcuRoot=>"icu_root",Ebcdic037Pad=>"ebcdic_037_pad",Ebcdic1047Nopad=>"ebcdic_1047_nopad"});
impl Collation {
    pub(crate) fn wire(self) -> &'static str {
        self.tag()
    }
}
tags!(read Kind {Create=>"create",Alter=>"alter",Rename=>"rename",Drop=>"drop",Insert=>"insert",Update=>"update",Delete=>"delete"});
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
    pub(crate) fn parse(v: &Value) -> Result<Self> {
        object(v, &["realm", "resource", "catalog"])?;
        Self::new(
            ResourceRef::new(n(&v["realm"], false)?, n(&v["resource"], false)?)?,
            w(&v["catalog"], false)?,
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TableLimits {
    pub record_bytes: u32,
    pub staging_bytes: u64,
    pub staging_records: u32,
}
impl TableLimits {
    pub(crate) fn wire(&self) -> Result<Value> {
        positive(self.record_bytes.into())?;
        positive(self.staging_records.into())?;
        if self.staging_bytes < u64::from(self.record_bytes) {
            return Err(invalid());
        }
        Ok(
            json!({"record_bytes":self.record_bytes,"staging_bytes":self.staging_bytes.to_string(),"staging_records":self.staging_records}),
        )
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AuthorityProfile {
    pub database_domain: u64,
    pub schema_domain: u64,
    pub table_domain: u64,
    pub stream_domain: u64,
    pub queue_domain: u64,
    pub kv_domain: u64,
    pub database: u64,
    pub initial_schema: u64,
    pub initial_schema_authority: u64,
}
impl AuthorityProfile {
    fn wire(&self) -> Result<Value> {
        for value in [
            self.database_domain,
            self.schema_domain,
            self.table_domain,
            self.stream_domain,
            self.queue_domain,
            self.kv_domain,
            self.database,
            self.initial_schema,
            self.initial_schema_authority,
        ] {
            native(value, false)?;
        }
        let domains = [
            self.database_domain,
            self.schema_domain,
            self.table_domain,
            self.stream_domain,
            self.queue_domain,
            self.kv_domain,
        ];
        for (i, domain) in domains.iter().enumerate() {
            if domains[..i].contains(domain) {
                return Err(invalid());
            }
        }
        if self.database == self.initial_schema_authority {
            return Err(invalid());
        }
        Ok(
            json!({"database_domain":self.database_domain,"schema_domain":self.schema_domain,
            "table_domain":self.table_domain,"stream_domain":self.stream_domain,"queue_domain":self.queue_domain,"kv_domain":self.kv_domain,"database":self.database,"initial_schema":self.initial_schema,
            "initial_schema_authority":self.initial_schema_authority}),
        )
    }
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "database_domain",
                "schema_domain",
                "table_domain",
                "stream_domain",
                "queue_domain",
                "kv_domain",
                "database",
                "initial_schema",
                "initial_schema_authority",
            ],
        )?;
        let out = Self {
            database_domain: n(&v["database_domain"], false)?,
            schema_domain: n(&v["schema_domain"], false)?,
            table_domain: n(&v["table_domain"], false)?,
            stream_domain: n(&v["stream_domain"], false)?,
            queue_domain: n(&v["queue_domain"], false)?,
            kv_domain: n(&v["kv_domain"], false)?,
            database: n(&v["database"], false)?,
            initial_schema: n(&v["initial_schema"], false)?,
            initial_schema_authority: n(&v["initial_schema_authority"], false)?,
        };
        out.wire()?;
        Ok(out)
    }
}
#[cfg(test)]
mod authority_tests {
    use super::*;

    #[test]
    fn current_authority_domains_are_required_distinct_native_counters() {
        let value = json!({"database_domain":1,"schema_domain":2,"table_domain":3,
            "stream_domain":31,"queue_domain":32,"kv_domain":33,"database":4,"initial_schema":1,"initial_schema_authority":5});
        let profile = AuthorityProfile::parse(&value).unwrap();
        assert_eq!(
            (
                profile.stream_domain,
                profile.queue_domain,
                profile.kv_domain
            ),
            (31, 32, 33)
        );
        assert_eq!(profile.wire().unwrap(), value);
        for field in ["stream_domain", "queue_domain", "kv_domain"] {
            let mut missing = value.clone();
            missing.as_object_mut().unwrap().remove(field);
            assert!(AuthorityProfile::parse(&missing).is_err());
            for invalid in [
                0u64,
                1,
                2,
                3,
                if field == "stream_domain" { 32 } else { 31 },
                if field == "kv_domain" { 32 } else { 33 },
                1 << 53,
            ] {
                let mut bad = value.clone();
                bad[field] = json!(invalid);
                assert!(AuthorityProfile::parse(&bad).is_err());
            }
        }
    }
}

/// An observed subject, not a capability that can authorize another request.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Subject {
    pub principal: u64,
    pub login_role: u64,
    pub role: u64,
    pub credential_epoch: u64,
    pub audience: u64,
    pub context: [u8; 32],
}
impl Subject {
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "principal",
                "login_role",
                "role",
                "credential_epoch",
                "audience",
                "context",
            ],
        )?;
        let data = v["context"]
            .as_array()
            .filter(|v| v.len() == 32)
            .ok_or_else(malformed)?;
        let mut context = [0u8; 32];
        for (target, byte) in context.iter_mut().zip(data) {
            *target = n(byte, true)?.try_into().map_err(|_| malformed())?;
        }
        Ok(Self {
            principal: n(&v["principal"], true)?,
            login_role: n(&v["login_role"], true)?,
            role: n(&v["role"], true)?,
            credential_epoch: n(&v["credential_epoch"], false)?,
            audience: n(&v["audience"], false)?,
            context,
        })
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
    pub encoding: Encoding,
    pub collation: Collation,
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
            encoding: Encoding::Plain,
            collation: Collation::None,
        }
    }
    fn wire(&self) -> Result<Value> {
        let mut out = column(
            &self.name,
            &self.datatype,
            self.nullable,
            self.default.as_ref(),
            self.max_characters,
            self.encoding,
            self.collation,
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
                "encoding",
                "collation",
            ],
        )?;
        Ok(Self {
            id: w(&v["id"], false)?,
            name: name(string(&v["name"], "column-name")?)?.into(),
            datatype: Descriptor::parse(&v["type"])?,
            nullable: boolean(&v["nullable"], "nullable")?,
            default: optional(&v["default"], Cell::parse)?,
            max_characters: optional(&v["max_characters"], |v| u32n(v, false))?,
            encoding: Encoding::parse(&v["encoding"])?,
            collation: Collation::parse(&v["collation"])?,
        })
    }
}
fn column(
    name_: &str,
    datatype: &Descriptor,
    nullable: bool,
    default: Option<&Cell>,
    max_characters: Option<u32>,
    encoding: Encoding,
    collation: Collation,
) -> Result<Value> {
    if max_characters == Some(0) {
        return Err(invalid());
    }
    Ok(
        json!({"name":name(name_)?,"type":datatype.wire()?,"nullable":nullable,"default":default.map(Cell::wire).transpose()?,"max_characters":max_characters,"encoding":encoding.tag(),"collation":collation.tag()}),
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
    pub(crate) fn wire(&self) -> Result<Value> {
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
    pub(crate) fn parse(v: &Value) -> Result<Self> {
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
    pub(crate) fn parse(value: &Value) -> Result<Self> {
        object(value, &["action", "predicate"])?;
        fn parsed_assignments(v: &Value) -> Result<Vec<Assignment>> {
            v.as_array()
                .filter(|v| v.len() <= 128)
                .ok_or_else(malformed)?
                .iter()
                .map(|v| {
                    object(v, &["column", "value"])?;
                    let (tag, data) = variant(&v["value"])?;
                    let value = match tag {
                        "default" => {
                            object(data, &[])?;
                            AssignmentValue::Default
                        }
                        "cell" => AssignmentValue::Cell(Cell::parse(data)?),
                        _ => return Err(malformed()),
                    };
                    Ok(Assignment {
                        column: w(&v["column"], false)?,
                        value,
                    })
                })
                .collect()
        }
        let predicate = if value["predicate"].is_null() {
            None
        } else {
            Some(
                value["predicate"]
                    .as_array()
                    .filter(|v| (1..=64).contains(&v.len()))
                    .ok_or_else(malformed)?
                    .iter()
                    .map(|v| {
                        let (tag, data) = variant(v)?;
                        if tag != "atom" {
                            object(data, &[])?;
                            return Ok(match tag {
                                "negate" => Predicate::Negate,
                                "conjunction" => Predicate::Conjunction,
                                "disjunction" => Predicate::Disjunction,
                                _ => return Err(malformed()),
                            });
                        }
                        let (tag, data) = variant(data)?;
                        Ok(match tag {
                            "all" => {
                                object(data, &[])?;
                                Predicate::All
                            }
                            "state" => {
                                object(data, &["column", "value"])?;
                                let state = match string(&data["value"], "cell-state")? {
                                    "missing" => CellState::Missing,
                                    "null" => CellState::Null,
                                    "type_error" => CellState::TypeError,
                                    "value" => CellState::Value,
                                    "conflict" => CellState::Conflict,
                                    _ => return Err(malformed()),
                                };
                                Predicate::State {
                                    column: w(&data["column"], false)?,
                                    state,
                                }
                            }
                            "compare" => {
                                object(data, &["column", "op", "value"])?;
                                let op = match string(&data["op"], "comparison")? {
                                    "eq" => CompareOperator::Eq,
                                    "ne" => CompareOperator::Ne,
                                    "lt" => CompareOperator::Lt,
                                    "le" => CompareOperator::Le,
                                    "gt" => CompareOperator::Gt,
                                    "ge" => CompareOperator::Ge,
                                    _ => return Err(malformed()),
                                };
                                Predicate::Compare {
                                    column: w(&data["column"], false)?,
                                    op,
                                    value: Atom::parse(&data["value"])?,
                                }
                            }
                            _ => return Err(malformed()),
                        })
                    })
                    .collect::<Result<Vec<_>>>()?,
            )
        };
        let (tag, data) = variant(&value["action"])?;
        let out = match tag {
            "insert" => {
                if predicate.is_some() {
                    return Err(malformed());
                }
                Self::Insert {
                    rows: data
                        .as_array()
                        .filter(|v| (1..=1024).contains(&v.len()))
                        .ok_or_else(malformed)?
                        .iter()
                        .map(parsed_assignments)
                        .collect::<Result<Vec<_>>>()?,
                }
            }
            "update" => Self::Update {
                assignments: parsed_assignments(data)?,
                predicate,
            },
            "delete" => {
                object(data, &[])?;
                Self::Delete { predicate }
            }
            _ => return Err(malformed()),
        };
        if out.wire()?.1 != *value {
            return Err(malformed());
        }
        Ok(out)
    }

    pub(crate) fn wire(&self) -> Result<(Kind, Value)> {
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
        encoding: Encoding,
        collation: Collation,
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
    Physical {
        column: u64,
        encoding: Encoding,
        collation: Collation,
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
                encoding,
                collation,
            } => {
                json!({"add":column(name,datatype,*nullable,default.as_ref(),*max_characters,*encoding,*collation)?})
            }
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
            Self::Physical {
                column,
                encoding,
                collation,
            } => {
                json!({"physical":{"column":positive(*column)?.to_string(),"encoding":encoding.tag(),"collation":collation.tag()}})
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

tags!(write Ingestion {Point=>"point",Bulk=>"bulk"});
tags!(write Dialect {Transit=>"transit",Mysql=>"mysql"});
tags!(both WorkKind {Table=>"table",NameAssertion=>"name_assertion"});
tags!(read ObservationKind {Ddl=>"ddl",Rows=>"rows",NameAssertion=>"name_assertion"});
tags!(read OperationState {NotObserved=>"not_observed",Admitted=>"admitted",Rejected=>"rejected",Cancelled=>"cancelled",Committed=>"committed",Unchanged=>"unchanged"});
tags!(read Phase {Admitted=>"admitted",Ready=>"ready",Settled=>"settled",Rejected=>"rejected",Cancelled=>"cancelled"});
tags!(read Reason {None=>"none",NameConflict=>"name_conflict",ObjectConflict=>"object_conflict",StaleDefinition=>"stale_definition",StaleData=>"stale_data",Dependency=>"dependency",Constraint=>"constraint",DefinitionChanged=>"definition_changed",DataChanged=>"data_changed",DuplicateKey=>"duplicate_key",MissingRow=>"missing_row",InvalidRows=>"invalid_rows",WorkLimit=>"work_limit",ConditionChanged=>"condition_changed"});
tags!(read EvolutionWork {Metadata=>"metadata",ValidateRows=>"validate_rows",RewriteRows=>"rewrite_rows"});

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Connection {
    scope: Scope,
    audience: u64,
    branch: u64,
    role: Option<u64>,
}
impl Connection {
    pub fn new(scope: Scope, audience: u64) -> Result<Self> {
        Ok(Self {
            scope,
            audience: native(audience, false)?,
            branch: 1,
            role: None,
        })
    }
    pub fn with_branch(mut self, branch: u64) -> Result<Self> {
        self.branch = positive(branch)?;
        Ok(self)
    }
    pub fn with_role(mut self, role: u64) -> Result<Self> {
        self.role = Some(native(role, true)?);
        Ok(self)
    }
    pub fn scope(&self) -> Scope {
        self.scope
    }
    pub fn audience(&self) -> u64 {
        self.audience
    }
    pub fn branch(&self) -> u64 {
        self.branch
    }
    pub fn role(&self) -> Option<u64> {
        self.role
    }
    pub(crate) fn wire(&self, principal: u64) -> Value {
        json!({"scope":self.scope.wire(),"audience":self.audience,"branch":self.branch.to_string(),"role":self.role,"principal":principal})
    }
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["scope", "audience", "branch", "role", "principal"])?;
        n(&v["principal"], true)?;
        let mut c = Self::new(Scope::parse(&v["scope"])?, n(&v["audience"], false)?)?
            .with_branch(w(&v["branch"], false)?)?;
        c.role = optional(&v["role"], |v| n(v, true))?;
        Ok(c)
    }
    fn owns(&self, target: &ObjectIdentity) -> Result<()> {
        if self.scope != target.scope || self.branch != target.branch {
            return Err(invalid());
        }
        Ok(())
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
            namespace: native(namespace, false)?,
        })
    }
    pub fn operation(&self) -> u64 {
        self.operation
    }
    pub fn namespace(&self) -> u64 {
        self.namespace
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Counts {
    pub matched: u64,
    pub changed: u64,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Position {
    pub partition: u64,
    pub next_lsn: u64,
}
impl Position {
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["partition", "next_lsn"])?;
        Ok(Self {
            partition: w(&v["partition"], false)?,
            next_lsn: w(&v["next_lsn"], true)?,
        })
    }
    fn wire(self) -> Value {
        json!({"partition":self.partition.to_string(),"next_lsn":self.next_lsn.to_string()})
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ObjectIdentity {
    pub scope: Scope,
    pub branch: u64,
    pub object: u64,
}
impl ObjectIdentity {
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["scope", "branch", "object"])?;
        Ok(Self {
            scope: Scope::parse(&v["scope"])?,
            branch: w(&v["branch"], false)?,
            object: w(&v["object"], false)?,
        })
    }
    fn wire(&self) -> Value {
        json!({"scope":self.scope.wire(),"branch":self.branch.to_string(),"object":self.object.to_string()})
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Interpretation {
    pub object: ObjectIdentity,
    pub revision: u64,
    pub digest: [u8; 32],
}
impl Interpretation {
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["object", "revision", "digest"])?;
        Ok(Self {
            object: ObjectIdentity::parse(&v["object"])?,
            revision: w(&v["revision"], false)?,
            digest: digest(&v["digest"])?,
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Content {
    pub bytes: u64,
    pub sha256: [u8; 32],
}
impl Content {
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["bytes", "sha256"])?;
        Ok(Self {
            bytes: w(&v["bytes"], false)?,
            sha256: digest(&v["sha256"])?,
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct StoredDefinition {
    pub interpretation: Interpretation,
    pub content: Content,
    pub schema_fingerprint: [u8; 32],
    pub retired: bool,
}
impl StoredDefinition {
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &["interpretation", "content", "schema_fingerprint", "retired"],
        )?;
        let out = Self {
            interpretation: Interpretation::parse(&v["interpretation"])?,
            content: Content::parse(&v["content"])?,
            schema_fingerprint: digest(&v["schema_fingerprint"])?,
            retired: boolean(&v["retired"], "retired")?,
        };
        if out.interpretation.digest != out.content.sha256 {
            return Err(malformed());
        }
        Ok(out)
    }
}

// Saved data is untrusted JSON. Reject duplicate members and excessive depth
// before owning it; serde_json::Value alone would overwrite duplicate members.
fn parse_saved(data: &str) -> Result<Value> {
    use serde::de::{DeserializeSeed, Deserializer, Error as _, MapAccess, SeqAccess, Visitor};
    struct Seed(usize);
    impl<'de> DeserializeSeed<'de> for Seed {
        type Value = Value;
        fn deserialize<D: Deserializer<'de>>(self, d: D) -> std::result::Result<Value, D::Error> {
            if self.0 >= 96 {
                return Err(D::Error::custom("saved value depth"));
            }
            d.deserialize_any(self)
        }
    }
    impl<'de> Visitor<'de> for Seed {
        type Value = Value;
        fn expecting(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
            f.write_str("bounded unique JSON")
        }
        fn visit_bool<E: serde::de::Error>(self, v: bool) -> std::result::Result<Value, E> {
            Ok(json!(v))
        }
        fn visit_u64<E: serde::de::Error>(self, v: u64) -> std::result::Result<Value, E> {
            Ok(json!(v))
        }
        fn visit_i64<E: serde::de::Error>(self, v: i64) -> std::result::Result<Value, E> {
            Ok(json!(v))
        }
        fn visit_str<E: serde::de::Error>(self, v: &str) -> std::result::Result<Value, E> {
            Ok(json!(v))
        }
        fn visit_string<E: serde::de::Error>(self, v: String) -> std::result::Result<Value, E> {
            Ok(Value::String(v))
        }
        fn visit_unit<E: serde::de::Error>(self) -> std::result::Result<Value, E> {
            Ok(Value::Null)
        }
        fn visit_seq<A: SeqAccess<'de>>(self, mut a: A) -> std::result::Result<Value, A::Error> {
            let mut out = vec![];
            while let Some(v) = a.next_element_seed(Seed(self.0 + 1))? {
                out.push(v)
            }
            Ok(Value::Array(out))
        }
        fn visit_map<A: MapAccess<'de>>(self, mut a: A) -> std::result::Result<Value, A::Error> {
            let mut out = serde_json::Map::new();
            while let Some(k) = a.next_key::<String>()? {
                if out.contains_key(&k) {
                    return Err(A::Error::custom("duplicate saved member"));
                }
                out.insert(k, a.next_value_seed(Seed(self.0 + 1))?);
            }
            Ok(Value::Object(out))
        }
    }
    text(data, abi::CATALOG_ACTION_BYTES)?;
    let mut d = serde_json::Deserializer::from_str(data);
    let v = Seed(0).deserialize(&mut d).map_err(|_| invalid())?;
    d.end().map_err(|_| invalid())?;
    Ok(v)
}
macro_rules! saved {
    ($name:ident,$check:ident) => {
        #[derive(Clone, Eq, PartialEq)]
        pub struct $name(Value);
        impl $name {
            pub fn restore(data: &str) -> Result<Self> {
                Self::parse(&parse_saved(data)?)
            }
            fn parse(v: &Value) -> Result<Self> {
                $check(v)?;
                Ok(Self(v.clone()))
            }
            pub fn save(&self) -> String {
                self.0.to_string()
            }
            fn wire(&self) -> Value {
                self.0.clone()
            }
        }
        impl std::fmt::Debug for $name {
            fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
                f.write_str(concat!(stringify!($name), "[owned saved binding]"))
            }
        }
    };
}
fn check_basis(v: &Value) -> Result<()> {
    require_schema(
        "CatalogAction",
        &json!({"prepare":{"definition":abi::ABI_DEFINITION,"namespace":1,"operation":"1","name":"check","action":{"drop":{"basis":v,"if_exists":false}}}}),
    )?;
    object(
        v,
        &[
            "definition",
            "connection",
            "namespace",
            "name",
            "interpretation",
        ],
    )?;
    definition(string(&v["definition"], "definition")?)?;
    let c = Connection::parse(&v["connection"])?;
    n(&v["namespace"], false)?;
    name(string(&v["name"], "name")?)?;
    let stored = StoredDefinition::parse(&v["interpretation"])?;
    c.owns(&stored.interpretation.object)?;
    if stored.retired {
        return Err(invalid());
    }
    Ok(())
}
saved!(Basis, check_basis);
impl Basis {
    pub fn connection(&self) -> Connection {
        Connection::parse(&self.0["connection"]).expect("validated basis")
    }
    pub fn principal(&self) -> u64 {
        self.0["connection"]["principal"]
            .as_u64()
            .expect("validated basis")
    }
    pub fn namespace(&self) -> u64 {
        self.0["namespace"].as_u64().expect("validated basis")
    }
    pub fn name(&self) -> &str {
        self.0["name"].as_str().expect("validated basis")
    }
    pub fn interpretation(&self) -> StoredDefinition {
        StoredDefinition::parse(&self.0["interpretation"]).expect("validated basis")
    }
    pub fn object(&self) -> u64 {
        self.interpretation().interpretation.object.object
    }
}
fn check_binding(v: &Value, c: &Connection, principal: u64) -> Result<()> {
    object(
        v,
        &[
            "definition",
            "identity",
            "target",
            "action",
            "intent",
            "expected_definition",
            "expected_data",
            "prerequisite",
        ],
    )?;
    definition(string(&v["definition"], "definition")?)?;
    object(&v["identity"], &["scope", "principal", "operation"])?;
    if Scope::parse(&v["identity"]["scope"])? != c.scope
        || n(&v["identity"]["principal"], true)? != principal
    {
        return Err(invalid());
    }
    w(&v["identity"]["operation"], false)?;
    let target = ObjectIdentity::parse(&v["target"])?;
    c.owns(&target)?;
    digest(&v["intent"])?;
    let action = Kind::parse(&v["action"])?;
    let expected = optional(&v["expected_definition"], Interpretation::parse)?;
    let data = optional(&v["expected_data"], Position::parse)?;
    if action == Kind::Create {
        if expected.is_some() || data.is_some() {
            return Err(invalid());
        }
    } else if expected.as_ref().is_none_or(|x| x.object != target) {
        return Err(invalid());
    }
    Ok(())
}
fn check_assertion(v: &Value) -> Result<()> {
    object(
        v,
        &[
            "definition",
            "connection",
            "namespace",
            "name",
            "operation",
            "action",
            "expected",
            "intent",
        ],
    )?;
    definition(string(&v["definition"], "definition")?)?;
    let c = Connection::parse(&v["connection"])?;
    n(&v["namespace"], false)?;
    name(string(&v["name"], "name")?)?;
    w(&v["operation"], false)?;
    digest(&v["intent"])?;
    let expected = optional(&v["expected"], Interpretation::parse)?;
    if let Some(e) = &expected {
        c.owns(&e.object)?
    }
    match string(&v["action"], "action")? {
        "create_if_not_exists" if expected.is_some() => (),
        "drop_if_exists" if expected.is_none() => (),
        _ => return Err(invalid()),
    }
    Ok(())
}
fn check_saved(v: &Value) -> Result<()> {
    require_schema("CatalogAction", &json!({"load":v}))?;
    let (tag, raw) = variant(v)?;
    match tag {
        "table" => {
            object(raw, &["definition", "namespace", "bytes"])?;
            definition(string(&raw["definition"], "definition")?)?;
            n(&raw["namespace"], false)?;
            if bytes(&raw["bytes"], abi::CATALOG_INTENT_BYTES)?.is_empty() {
                return Err(invalid());
            }
            Ok(())
        }
        "name_assertion" => check_assertion(raw),
        _ => Err(invalid()),
    }
}
saved!(SavedIntent, check_saved);
fn check_reference(v: &Value) -> Result<()> {
    require_schema("CatalogAction", &json!({"admit":v}))?;
    let (tag, raw) = variant(v)?;
    match tag {
        "table" => {
            object(
                raw,
                &[
                    "definition",
                    "connection",
                    "namespace",
                    "binding",
                    "content",
                ],
            )?;
            definition(string(&raw["definition"], "definition")?)?;
            n(&raw["namespace"], false)?;
            let c = Connection::parse(&raw["connection"])?;
            check_binding(
                &raw["binding"],
                &c,
                n(&raw["connection"]["principal"], true)?,
            )?;
            let content = Content::parse(&raw["content"])?;
            if content.bytes <= 36 || content.bytes > abi::CATALOG_INTENT_BYTES as u64 {
                return Err(invalid());
            }
            Ok(())
        }
        "name_assertion" => check_assertion(raw),
        _ => Err(invalid()),
    }
}
saved!(Reference, check_reference);
impl Reference {
    pub fn kind(&self) -> WorkKind {
        if self.0.get("table").is_some() {
            WorkKind::Table
        } else {
            WorkKind::NameAssertion
        }
    }
    fn value(&self) -> &Value {
        &self.0[self.kind().tag()]
    }
    fn binding(&self) -> &Value {
        if self.kind() == WorkKind::Table {
            &self.value()["binding"]
        } else {
            self.value()
        }
    }
    pub fn connection(&self) -> Connection {
        Connection::parse(&self.value()["connection"]).expect("validated reference")
    }
    pub fn principal(&self) -> u64 {
        n(&self.value()["connection"]["principal"], true).expect("validated reference")
    }
    pub fn identity(&self) -> Identity {
        Identity {
            namespace: n(&self.value()["namespace"], false).expect("validated reference"),
            operation: w(
                if self.kind() == WorkKind::Table {
                    &self.binding()["identity"]["operation"]
                } else {
                    &self.value()["operation"]
                },
                false,
            )
            .expect("validated reference"),
        }
    }
}
fn check_cursor(v: &Value) -> Result<()> {
    require_schema(
        "CatalogAction",
        &if v["selection"].get("namespaces").is_some() {
            json!({"catalog":{"namespaces":v}})
        } else {
            json!({"catalog":{"tables":{"namespace":v["selection"]["tables"],"cursor":v}}})
        },
    )?;
    object(
        v,
        &["definition", "connection", "selection", "position", "after"],
    )?;
    definition(string(&v["definition"], "definition")?)?;
    Connection::parse(&v["connection"])?;
    let after = w(&v["after"], false)?;
    if Position::parse(&v["position"])?.next_lsn == 0 {
        return Err(invalid());
    }
    match variant(&v["selection"])? {
        ("namespaces", v) => {
            object(v, &[])?;
            native(after, false)?;
        }
        ("tables", v) => {
            n(v, false)?;
        }
        _ => return Err(invalid()),
    }
    Ok(())
}
saved!(Cursor, check_cursor);
impl Cursor {
    pub fn position(&self) -> Position {
        Position::parse(&self.0["position"]).expect("validated cursor")
    }
    pub fn after(&self) -> u64 {
        w(&self.0["after"], false).expect("validated cursor")
    }
    fn check(&self, c: &Connection, p: u64, selection: &Value) -> Result<()> {
        if self.0["connection"] != c.wire(p) || self.0["selection"] != *selection {
            return Err(invalid());
        }
        Ok(())
    }
}
fn check_owner(v: &Value) -> Result<()> {
    require_schema("CatalogAction", &json!({"retention":{"status":v}}))?;
    object(v, &["definition", "connection", "object", "operation"])?;
    definition(string(&v["definition"], "definition")?)?;
    Connection::parse(&v["connection"])?.owns(&ObjectIdentity::parse(&v["object"])?)?;
    w(&v["operation"], false)?;
    Ok(())
}
saved!(SnapshotOwner, check_owner);
impl SnapshotOwner {
    pub fn connection(&self) -> Connection {
        Connection::parse(&self.0["connection"]).expect("validated owner")
    }
    pub fn principal(&self) -> u64 {
        n(&self.0["connection"]["principal"], true).expect("validated owner")
    }
    pub fn object(&self) -> ObjectIdentity {
        ObjectIdentity::parse(&self.0["object"]).expect("validated owner")
    }
    pub fn operation(&self) -> u64 {
        w(&self.0["operation"], false).expect("validated owner")
    }
}
fn check_acquisition(v: &Value) -> Result<()> {
    require_schema("CatalogAction", &json!({"retention":{"acquire":v}}))?;
    object(v, &["owner", "expected"])?;
    check_owner(&v["owner"])?;
    Position::parse(&v["expected"])?;
    Ok(())
}
saved!(SnapshotAcquisition, check_acquisition);
impl SnapshotAcquisition {
    pub fn owner(&self) -> SnapshotOwner {
        SnapshotOwner(self.0["owner"].clone())
    }
    pub fn expected(&self) -> Position {
        Position::parse(&self.0["expected"]).expect("validated acquisition")
    }
}
fn check_snapshot(v: &Value) -> Result<()> {
    require_schema("CatalogAction", &json!({"retention":{"metadata":v}}))?;
    object(v, &["owner", "content"])?;
    check_owner(&v["owner"])?;
    Content::parse(&v["content"])?;
    Ok(())
}
saved!(Snapshot, check_snapshot);
impl Snapshot {
    pub fn owner(&self) -> SnapshotOwner {
        SnapshotOwner(self.0["owner"].clone())
    }
    pub fn content(&self) -> Content {
        Content::parse(&self.0["content"]).expect("validated snapshot")
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
        ingestion: Ingestion,
    },
}
impl Operation {
    fn wire(&self) -> Result<Value> {
        Ok(match self {
            Self::Create {
                schema,
                if_not_exists,
            } => json!({"create":{"schema":schema.wire()?,"if_not_exists":if_not_exists}}),
            Self::Alter { basis, change } => {
                json!({"alter":{"basis":basis.wire(),"change":change.wire()?}})
            }
            Self::Rename {
                basis,
                name: new_name,
            } => json!({"rename":{"basis":basis.wire(),"name":name(new_name)?}}),
            Self::Drop { basis, if_exists } => {
                json!({"drop":{"basis":basis.as_ref().map(Basis::wire),"if_exists":if_exists}})
            }
            Self::Mutate {
                basis,
                mutation,
                ingestion,
            } => {
                json!({"mutate":{"basis":basis.wire(),"mutation":mutation.wire()?.1,"ingestion":ingestion.tag()}})
            }
        })
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Configuration {
    pub scope: Scope,
    pub branch: u64,
    pub partition: u64,
    pub audience: u64,
    pub authority: AuthorityProfile,
    pub database_name: String,
    pub initial_schema_name: String,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Description {
    pub configuration: Configuration,
    pub subject: Subject,
    pub policy_revision: u64,
}
impl Description {
    fn parse(v: &Value, c: &Connection, p: u64) -> Result<Self> {
        object(v, &["configuration", "subject", "policy_revision"])?;
        let raw = &v["configuration"];
        object(
            raw,
            &[
                "scope",
                "branch",
                "partition",
                "audience",
                "authority",
                "database_name",
                "initial_schema_name",
            ],
        )?;
        let config = Configuration {
            scope: Scope::parse(&raw["scope"])?,
            branch: w(&raw["branch"], false)?,
            partition: w(&raw["partition"], false)?,
            audience: n(&raw["audience"], false)?,
            authority: AuthorityProfile::parse(&raw["authority"])?,
            database_name: name(string(&raw["database_name"], "name")?)?.into(),
            initial_schema_name: name(string(&raw["initial_schema_name"], "name")?)?.into(),
        };
        let subject = Subject::parse(&v["subject"])?;
        if config.scope != c.scope
            || config.branch != c.branch
            || config.audience != c.audience
            || subject.principal != p
            || subject.audience != c.audience
            || c.role.is_some_and(|r| r != subject.role)
        {
            return Err(malformed());
        }
        Ok(Self {
            configuration: config,
            subject,
            policy_revision: n(&v["policy_revision"], true)?,
        })
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
    pub metadata_page_entries: usize,
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
                "metadata_page_entries",
                "resident_intents",
            ],
        )?;
        Ok(Self {
            version: u32n(&v["version"], false)?,
            definition: definition(string(&v["definition"], "definition")?)?.into(),
            max_columns: n(&v["max_columns"], false)? as usize,
            max_rows: n(&v["max_rows"], false)? as usize,
            max_sql_bytes: n(&v["max_sql_bytes"], false)? as usize,
            max_intent_bytes: n(&v["max_intent_bytes"], false)? as usize,
            max_action_bytes: n(&v["max_action_bytes"], false)? as usize,
            metadata_page_entries: n(&v["metadata_page_entries"], false)? as usize,
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
            && self.metadata_page_entries == 8
            && self.resident_intents == 1
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct Metadata {
    pub basis: Basis,
    pub authorization: u64,
    pub position: Position,
    pub changed_lsn: u64,
    pub row_count: u64,
    pub schema: Schema,
}
impl Metadata {
    fn parse(v: &Value, c: &Connection, p: u64, namespace: u64, name_: &str) -> Result<Self> {
        object(
            v,
            &[
                "binding",
                "authorization",
                "position",
                "changed_lsn",
                "row_count",
                "schema",
            ],
        )?;
        let basis = Basis::parse(&v["binding"])?;
        let schema = Schema::parse(&v["schema"])?;
        if basis.connection() != *c
            || basis.principal() != p
            || basis.namespace() != namespace
            || basis.name() != name_
            || basis.object() != schema.object
        {
            return Err(malformed());
        }
        Ok(Self {
            basis,
            authorization: n(&v["authorization"], false)?,
            position: Position::parse(&v["position"])?,
            changed_lsn: w(&v["changed_lsn"], true)?,
            row_count: w(&v["row_count"], true)?,
            schema,
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Namespace {
    pub scope: Scope,
    pub id: u64,
    pub authorization: u64,
    pub name: String,
    pub revision: u64,
    pub retired: bool,
}
impl Namespace {
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "scope",
                "id",
                "authorization",
                "name",
                "revision",
                "retired",
            ],
        )?;
        Ok(Self {
            scope: Scope::parse(&v["scope"])?,
            id: n(&v["id"], false)?,
            authorization: n(&v["authorization"], false)?,
            name: name(string(&v["name"], "name")?)?.into(),
            revision: n(&v["revision"], false)?,
            retired: boolean(&v["retired"], "retired")?,
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Entry {
    pub interpretation: Interpretation,
    pub namespace: u64,
    pub name: String,
    pub position: Position,
    pub changed_lsn: u64,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Consistency {
    Independent,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Page<T> {
    pub position: Position,
    pub entries: Vec<T>,
    pub next: Option<Cursor>,
    pub consistency: Option<Consistency>,
}
fn page<T>(
    v: &Value,
    c: &Connection,
    p: u64,
    selection: &Value,
    previous: Option<&Cursor>,
    decode: impl Fn(&Value) -> Result<(u64, T)>,
) -> Result<Page<T>> {
    let tables = selection.get("tables").is_some();
    object(
        v,
        if tables {
            &["position", "entries", "next", "consistency"]
        } else {
            &["position", "entries", "next"]
        },
    )?;
    if tables && v["consistency"] != "independent" {
        return Err(malformed());
    }
    let position = Position::parse(&v["position"])?;
    let slots = v["entries"]
        .as_array()
        .filter(|a| a.len() == 8)
        .ok_or_else(malformed)?;
    let mut after = previous.map_or(0, Cursor::after);
    let mut ended = false;
    let mut entries = vec![];
    for raw in slots {
        if raw.is_null() {
            ended = true;
            continue;
        }
        if ended {
            return Err(malformed());
        }
        let (id, entry) = decode(raw)?;
        if id <= after {
            return Err(malformed());
        }
        after = id;
        entries.push(entry);
    }
    let next = optional(&v["next"], Cursor::parse)?;
    if let Some(next) = &next {
        next.check(c, p, selection)?;
        if next.position() != position
            || next.after() < after
            || next.after() <= previous.map_or(0, Cursor::after)
        {
            return Err(malformed());
        }
    }
    if previous.is_some_and(|v| v.position() != position) {
        return Err(malformed());
    }
    Ok(Page {
        position,
        entries,
        next,
        consistency: tables.then_some(Consistency::Independent),
    })
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Intent {
    id: Value,
    binding: Value,
    kind: WorkKind,
    identity: Identity,
    saved: SavedIntent,
}
impl Intent {
    pub fn kind(&self) -> WorkKind {
        self.kind
    }
    pub fn identity(&self) -> Identity {
        self.identity
    }
    pub fn saved(&self) -> &SavedIntent {
        &self.saved
    }

    fn parse(
        v: &Value,
        saved: SavedIntent,
        c: &Connection,
        p: u64,
        expected: Option<Identity>,
    ) -> Result<Self> {
        object(v, &["id", "binding", "namespace"])?;
        let id = &v["id"];
        object(id, &["definition", "digest"])?;
        definition(string(&id["definition"], "definition")?)?;
        digest(&id["digest"])?;
        let (kind, binding) = variant(&v["binding"])?;
        let kind = WorkKind::parse(&json!(kind))?;
        let ns = n(&v["namespace"], false)?;
        let operation = match kind {
            WorkKind::Table => {
                check_binding(binding, c, p)?;
                w(&binding["identity"]["operation"], false)?
            }
            WorkKind::NameAssertion => {
                check_assertion(binding)?;
                if binding["connection"] != c.wire(p) || n(&binding["namespace"], false)? != ns {
                    return Err(malformed());
                }
                w(&binding["operation"], false)?
            }
        };
        let identity = Identity::new(operation, ns)?;
        if expected.is_some_and(|v| v != identity) {
            return Err(malformed());
        }
        let raw = &saved.0[kind.tag()];
        if n(&raw["namespace"], false)? != ns || kind == WorkKind::NameAssertion && raw != binding {
            return Err(malformed());
        }
        Ok(Self {
            id: id.clone(),
            binding: binding.clone(),
            kind,
            identity,
            saved,
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Compiled {
    pub intent: Intent,
    pub saved: SavedIntent,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Commit {
    pub definition: StoredDefinition,
    pub position: Position,
    pub matched: u64,
    pub affected: u64,
    pub live_rows: u64,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Observation {
    pub kind: ObservationKind,
    pub state: OperationState,
    pub reference: Reference,
    pub commit: Option<Commit>,
    pub phase: Option<Phase>,
    pub reason: Option<Reason>,
    pub position: Option<Position>,
}
fn expected_kind(kind: WorkKind, binding: &Value) -> ObservationKind {
    if kind == WorkKind::NameAssertion {
        ObservationKind::NameAssertion
    } else if matches!(
        binding["action"].as_str(),
        Some("insert" | "update" | "delete")
    ) {
        ObservationKind::Rows
    } else {
        ObservationKind::Ddl
    }
}
impl Observation {
    fn parse(v: &Value, original: &Reference) -> Result<Self> {
        let (kind, state) = variant(v)?;
        let kind = ObservationKind::parse(&json!(kind))?;
        if kind != expected_kind(original.kind(), original.binding()) {
            return Err(malformed());
        }
        let (tag, raw) = variant(state)?;
        let mut out = Self {
            kind,
            state: if tag == "outcome" && kind == ObservationKind::NameAssertion {
                OperationState::NotObserved
            } else {
                OperationState::parse(&json!(tag))?
            },
            reference: original.clone(),
            commit: None,
            phase: None,
            reason: None,
            position: None,
        };
        if tag == "not_observed" {
            object(raw, &[])?;
            return Ok(out);
        }
        if raw["binding"] != *original.binding() {
            return Err(malformed());
        }
        if kind == ObservationKind::NameAssertion {
            object(raw, &["binding", "state", "reason", "position"])?;
            out.state = OperationState::parse(&raw["state"])?;
            out.reason = Some(Reason::parse(&raw["reason"])?);
            out.position = Some(Position::parse(&raw["position"])?);
            return Ok(out);
        }
        if tag == "committed" {
            object(raw, &["binding", "resulting", "outcome", "transaction"])?;
            if !raw["transaction"].is_null() {
                return Err(malformed());
            }
            let stored = StoredDefinition::parse(&raw["resulting"])?;
            let outcome = &raw["outcome"];
            object(outcome, &["position", "matched", "affected", "live_rows"])?;
            let matched = w(&outcome["matched"], true)?;
            let affected = w(&outcome["affected"], true)?;
            if affected > matched
                || stored.interpretation.object
                    != ObjectIdentity::parse(&original.binding()["target"])?
            {
                return Err(malformed());
            }
            out.commit = Some(Commit {
                definition: stored,
                position: Position::parse(&outcome["position"])?,
                matched,
                affected,
                live_rows: w(&outcome["live_rows"], true)?,
            });
            return Ok(out);
        }
        object(
            raw,
            if kind == ObservationKind::Rows {
                &["binding", "intent", "basis", "phase", "reason"]
            } else {
                &["binding", "intent", "phase", "reason"]
            },
        )?;
        Content::parse(&raw["intent"])?;
        let phase = string(&raw["phase"], "phase")?;
        if if tag == "admitted" {
            !matches!(phase, "admitted" | "ready" | "settled")
        } else {
            phase != tag
        } {
            return Err(malformed());
        }
        if kind == ObservationKind::Rows {
            let basis = &raw["basis"];
            object(basis, &["interpretation", "position", "changed_lsn"])?;
            Interpretation::parse(&basis["interpretation"])?;
            Position::parse(&basis["position"])?;
            w(&basis["changed_lsn"], true)?;
        }
        out.phase = Some(Phase::parse(&raw["phase"])?);
        out.reason = Some(Reason::parse(&raw["reason"])?);
        Ok(out)
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum PreviewCurrent {
    Definition {
        definition: StoredDefinition,
        position: Position,
        changed_lsn: u64,
        row_count: u64,
    },
    Name(Interpretation),
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Preview {
    pub kind: ObservationKind,
    pub intent: Intent,
    pub position: Position,
    pub current: Option<PreviewCurrent>,
    pub reason: Option<Reason>,
    pub work: Option<EvolutionWork>,
    pub rebuild_key: Option<bool>,
    pub schema_fingerprint: Option<[u8; 32]>,
    pub matches: Option<bool>,
}
impl Preview {
    fn parse(v: &Value, intent: &Intent) -> Result<Self> {
        let (kind, raw) = variant(v)?;
        let kind = ObservationKind::parse(&json!(kind))?;
        if kind != expected_kind(intent.kind, &intent.binding) || raw["binding"] != intent.binding {
            return Err(malformed());
        }
        if kind == ObservationKind::NameAssertion {
            object(raw, &["binding", "position", "current", "matches"])?;
            return Ok(Self {
                kind,
                intent: intent.clone(),
                position: Position::parse(&raw["position"])?,
                current: optional(&raw["current"], |v| {
                    Ok(PreviewCurrent::Name(Interpretation::parse(v)?))
                })?,
                reason: None,
                work: None,
                rebuild_key: None,
                schema_fingerprint: None,
                matches: Some(boolean(&raw["matches"], "matches")?),
            });
        }
        let ddl = kind == ObservationKind::Ddl;
        object(
            raw,
            if ddl {
                &[
                    "binding",
                    "directory_position",
                    "current",
                    "reason",
                    "work",
                    "rebuild_key",
                    "schema_fingerprint",
                ]
            } else {
                &["binding", "directory_position", "current", "reason"]
            },
        )?;
        let current = optional(&raw["current"], |v| {
            object(
                v,
                &["interpretation", "position", "changed_lsn", "row_count"],
            )?;
            Ok(PreviewCurrent::Definition {
                definition: StoredDefinition::parse(&v["interpretation"])?,
                position: Position::parse(&v["position"])?,
                changed_lsn: w(&v["changed_lsn"], true)?,
                row_count: w(&v["row_count"], true)?,
            })
        })?;
        Ok(Self {
            kind,
            intent: intent.clone(),
            position: Position::parse(&raw["directory_position"])?,
            current,
            reason: Some(Reason::parse(&raw["reason"])?),
            work: if ddl {
                optional(&raw["work"], EvolutionWork::parse)?
            } else {
                None
            },
            rebuild_key: if ddl {
                Some(boolean(&raw["rebuild_key"], "rebuild")?)
            } else {
                None
            },
            schema_fingerprint: if ddl {
                optional(&raw["schema_fingerprint"], digest)?
            } else {
                None
            },
            matches: None,
        })
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ReadAuthority {
    pub database: u64,
    pub schema: u64,
    pub table: u64,
}
impl ReadAuthority {
    fn parse(v: &Value) -> Result<Self> {
        object(v, &["database", "schema", "table"])?;
        let a = Self {
            database: n(&v["database"], false)?,
            schema: n(&v["schema"], false)?,
            table: n(&v["table"], false)?,
        };
        if a.database == a.schema || a.database == a.table || a.schema == a.table {
            return Err(malformed());
        }
        Ok(a)
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SnapshotStatus {
    pub owner: SnapshotOwner,
    pub current_interpretation: Interpretation,
    pub current_position: Position,
    pub retired: bool,
    pub snapshot: Option<Snapshot>,
    pub released: bool,
    pub authority: ReadAuthority,
}
impl SnapshotStatus {
    fn parse(v: &Value, owner: &SnapshotOwner) -> Result<Self> {
        object(
            v,
            &[
                "owner",
                "current_interpretation",
                "current_position",
                "retired",
                "snapshot",
                "released",
                "authority",
            ],
        )?;
        let current = Interpretation::parse(&v["current_interpretation"])?;
        let snapshot = optional(&v["snapshot"], Snapshot::parse)?;
        if v["owner"] != owner.0
            || current.object != owner.object()
            || snapshot.as_ref().is_some_and(|v| v.owner() != *owner)
        {
            return Err(malformed());
        }
        Ok(Self {
            owner: owner.clone(),
            current_interpretation: current,
            current_position: Position::parse(&v["current_position"])?,
            retired: boolean(&v["retired"], "retired")?,
            snapshot,
            released: boolean(&v["released"], "released")?,
            authority: ReadAuthority::parse(&v["authority"])?,
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct SnapshotMetadata {
    pub snapshot: Snapshot,
    pub interpretation: StoredDefinition,
    pub accepted: Position,
    pub changed_lsn: u64,
    pub row_count: u64,
    pub schema: Schema,
    pub authority: ReadAuthority,
}
impl SnapshotMetadata {
    fn parse(v: &Value, snapshot: &Snapshot) -> Result<Self> {
        object(
            v,
            &[
                "snapshot",
                "interpretation",
                "accepted",
                "changed_lsn",
                "row_count",
                "schema",
                "authority",
            ],
        )?;
        let interpretation = StoredDefinition::parse(&v["interpretation"])?;
        let schema = Schema::parse(&v["schema"])?;
        if v["snapshot"] != snapshot.0
            || interpretation.interpretation.object != snapshot.owner().object()
            || schema.object != snapshot.owner().object().object
        {
            return Err(malformed());
        }
        Ok(Self {
            snapshot: snapshot.clone(),
            interpretation,
            accepted: Position::parse(&v["accepted"])?,
            changed_lsn: w(&v["changed_lsn"], true)?,
            row_count: w(&v["row_count"], true)?,
            schema,
            authority: ReadAuthority::parse(&v["authority"])?,
        })
    }
}

// Interpret the generated JSON-schema subset; declarations remain owned by Zig.
fn require_schema(kind: &str, value: &Value) -> Result<()> {
    static CONTRACT: std::sync::OnceLock<Value> = std::sync::OnceLock::new();
    let contract = CONTRACT.get_or_init(|| {
        serde_json::from_str(include_str!("contract.json")).expect("generated contract")
    });
    let schema = &contract["schemas"][kind];
    fn integer(v: &Value) -> Option<i128> {
        v.as_i64()
            .map(i128::from)
            .or_else(|| v.as_u64().map(i128::from))
    }
    fn valid(s: &Value, v: &Value, root: &Value, depth: usize) -> bool {
        if depth >= 96 {
            return false;
        }
        if let Some(reference) = s["$ref"].as_str() {
            return reference
                .strip_prefix('#')
                .and_then(|p| root.pointer(p))
                .is_some_and(|s| valid(s, v, root, depth));
        }
        for key in ["anyOf", "oneOf"] {
            if let Some(alternatives) = s[key].as_array() {
                let mut count = 0;
                for a in alternatives {
                    if valid(a, v, root, depth) {
                        count += 1;
                        if key == "anyOf" {
                            return true;
                        }
                        if count > 1 {
                            return false;
                        }
                    }
                }
                return count == 1;
            }
        }
        if let Some(values) = s["enum"].as_array() {
            if !values.contains(v) {
                return false;
            }
        }
        match s["type"].as_str() {
            Some("object") => {
                let Some(map) = v.as_object() else {
                    return false;
                };
                if s["maxProperties"]
                    .as_u64()
                    .is_some_and(|n| map.len() as u64 > n)
                {
                    return false;
                }
                if s["required"].as_array().is_some_and(|a| {
                    a.iter()
                        .any(|k| k.as_str().is_none_or(|k| !map.contains_key(k)))
                }) {
                    return false;
                }
                for (key, value) in map {
                    if let Some(child) = s["properties"].get(key) {
                        if !valid(child, value, root, depth + 1) {
                            return false;
                        }
                    } else if s["additionalProperties"] == false {
                        return false;
                    } else if s["additionalProperties"].is_object()
                        && !valid(&s["additionalProperties"], value, root, depth + 1)
                    {
                        return false;
                    }
                }
                true
            }
            Some("array") => {
                let Some(array) = v.as_array() else {
                    return false;
                };
                let len = array.len() as u64;
                if s["minItems"].as_u64().is_some_and(|n| len < n)
                    || s["maxItems"].as_u64().is_some_and(|n| len > n)
                {
                    return false;
                }
                array.iter().all(|v| valid(&s["items"], v, root, depth + 1))
            }
            Some("string") => {
                let Some(text) = v.as_str() else { return false };
                if s["maxLength"]
                    .as_u64()
                    .is_some_and(|n| text.chars().count() as u64 > n)
                {
                    return false;
                }
                match s["pattern"].as_str() {
                    None => true,
                    Some("^(?:[0-9a-f]{2})*$") => {
                        text.len() % 2 == 0
                            && text
                                .bytes()
                                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
                    }
                    _ => false,
                }
            }
            Some("integer") => integer(v).is_some_and(|n| {
                !integer(&s["minimum"]).is_some_and(|min| n < min)
                    && !integer(&s["maximum"]).is_some_and(|max| n > max)
            }),
            Some("boolean") => v.is_boolean(),
            Some("null") => v.is_null(),
            _ => false,
        }
    }
    if valid(schema, value, schema, 0) {
        Ok(())
    } else {
        Err(Error::new(
            ErrorKind::IncompatibleNative,
            if kind == "CatalogAction" {
                "catalog-request-schema"
            } else {
                "catalog-response-schema"
            },
        ))
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Recovery {
    Intent(SavedIntent),
    Reference(Reference),
    Acquisition(SnapshotAcquisition),
    Snapshot(Snapshot),
}
impl Recovery {
    pub fn save(&self) -> String {
        match self {
            Self::Intent(v) => v.save(),
            Self::Reference(v) => v.save(),
            Self::Acquisition(v) => v.save(),
            Self::Snapshot(v) => v.save(),
        }
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum DispatchError {
    Definite(Error),
    Uncertain { cause: Error, original: Recovery },
}
impl From<Error> for DispatchError {
    fn from(value: Error) -> Self {
        Self::Definite(value)
    }
}
impl std::fmt::Display for DispatchError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        std::fmt::Debug::fmt(self, f)
    }
}
impl std::error::Error for DispatchError {}
pub type DispatchResult<T> = std::result::Result<T, DispatchError>;

/// One owned blocking worker. Mutable borrows serialize calls; close and Drop join.
/// Persist original saved work and references before dispatch. No implicit retry.
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
        service_url: Option<String>,
    ) -> Result<Self> {
        if credential.realm() != connection.scope.resource.realm() {
            return Err(invalid());
        }
        if let Some(url) = &service_url {
            text(url, 2048)?;
            ClientConfig::growing(url)?;
        }
        let principal = credential.principal();
        let saved = connection.clone();
        let worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
            CatalogNative::open(&config, &credential, &saved, service_url.as_deref())
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
        require_schema("CatalogAction", &action)?;
        self.worker.call(move |native| native.call(action))
    }
    fn decode<T>(
        response: &Value,
        path: &[&str],
        decode: impl FnOnce(&Value) -> Result<T>,
    ) -> Result<T> {
        require_schema("CatalogResult", response)?;
        let mut value = response;
        for key in path {
            value = result(value, key)?;
        }
        decode(value).map_err(|_| malformed())
    }
    fn read<T>(
        &mut self,
        action: Value,
        path: &[&str],
        decode: impl FnOnce(&Value) -> Result<T>,
    ) -> Result<T> {
        let response = self.call(action)?;
        Self::decode(&response, path, decode)
    }
    fn dispatch<T>(
        &mut self,
        action: Value,
        original: Recovery,
        path: &[&str],
        decode: impl FnOnce(&Value) -> Result<T>,
    ) -> DispatchResult<T> {
        let response = self.call(action).map_err(|cause| {
            if matches!(
                cause.kind,
                ErrorKind::UnknownOutcome | ErrorKind::WorkerPanic
            ) {
                DispatchError::Uncertain {
                    cause,
                    original: original.clone(),
                }
            } else {
                DispatchError::Definite(cause)
            }
        })?;
        Self::decode(&response, path, decode).map_err(|_| DispatchError::Uncertain {
            cause: Error::new(ErrorKind::UnknownOutcome, "catalog-response"),
            original,
        })
    }
    fn owner(&self, c: &Connection, p: u64) -> Result<()> {
        if *c != self.connection || p != self.principal {
            return Err(invalid());
        }
        Ok(())
    }
    pub fn capabilities(&mut self) -> Result<Capabilities> {
        self.read(
            json!({"catalog":{"capabilities":{}}}),
            &["catalog", "capabilities"],
            Capabilities::parse,
        )
    }
    pub fn describe(&mut self) -> Result<Description> {
        let c = self.connection.clone();
        let p = self.principal;
        self.read(
            json!({"catalog":{"describe":{}}}),
            &["catalog", "description"],
            |v| Description::parse(v, &c, p),
        )
    }
    pub fn namespace(&mut self, id: u64) -> Result<Option<Namespace>> {
        native(id, false)?;
        let scope = self.connection.scope;
        self.read(
            json!({"catalog":{"namespace":id}}),
            &["catalog", "namespace"],
            |v| {
                optional(v, |v| {
                    let found = Namespace::parse(v)?;
                    if found.id != id || found.scope != scope {
                        return Err(malformed());
                    }
                    Ok(found)
                })
            },
        )
    }
    pub fn namespaces(&mut self, cursor: Option<&Cursor>) -> Result<Page<Namespace>> {
        let c = self.connection.clone();
        let p = self.principal;
        let selection = json!({"namespaces":{}});
        if let Some(cursor) = cursor {
            cursor.check(&c, p, &selection)?
        }
        self.read(
            json!({"catalog":{"namespaces":cursor.map(Cursor::wire)}}),
            &["catalog", "namespaces"],
            |v| {
                page(v, &c, p, &selection, cursor, |v| {
                    let n = Namespace::parse(v)?;
                    if n.scope != c.scope {
                        return Err(malformed());
                    }
                    Ok((n.id, n))
                })
            },
        )
    }
    pub fn tables(&mut self, namespace: u64, cursor: Option<&Cursor>) -> Result<Page<Entry>> {
        native(namespace, false)?;
        let c = self.connection.clone();
        let p = self.principal;
        let selection = json!({"tables":namespace});
        if let Some(cursor) = cursor {
            cursor.check(&c, p, &selection)?
        }
        self.read(
            json!({"catalog":{"tables":{"namespace":namespace,"cursor":cursor.map(Cursor::wire)}}}),
            &["catalog", "tables"],
            |v| {
                page(v, &c, p, &selection, cursor, |v| {
                    object(
                        v,
                        &[
                            "interpretation",
                            "namespace",
                            "name",
                            "position",
                            "changed_lsn",
                        ],
                    )?;
                    let interpretation = Interpretation::parse(&v["interpretation"])?;
                    c.owns(&interpretation.object)?;
                    if n(&v["namespace"], false)? != namespace {
                        return Err(malformed());
                    }
                    Ok((
                        interpretation.object.object,
                        Entry {
                            interpretation,
                            namespace,
                            name: name(string(&v["name"], "name")?)?.into(),
                            position: Position::parse(&v["position"])?,
                            changed_lsn: w(&v["changed_lsn"], true)?,
                        },
                    ))
                })
            },
        )
    }
    pub fn lookup(&mut self, name_: &str, namespace: u64) -> Result<Option<Metadata>> {
        name(name_)?;
        native(namespace, false)?;
        let c = self.connection.clone();
        let p = self.principal;
        self.read(
            json!({"lookup":{"namespace":namespace,"name":name_}}),
            &["metadata"],
            |v| optional(v, |v| Metadata::parse(v, &c, p, namespace, name_)),
        )
    }
    fn compiled(&mut self, action: Value, identity: Identity) -> Result<Compiled> {
        let c = self.connection.clone();
        let p = self.principal;
        self.read(action, &["compiled"], |v| {
            object(v, &["summary", "saved"])?;
            let saved = SavedIntent::parse(&v["saved"])?;
            Ok(Compiled {
                intent: Intent::parse(&v["summary"], saved.clone(), &c, p, Some(identity))?,
                saved,
            })
        })
    }
    pub fn compile_sql(
        &mut self,
        sql: &str,
        identity: Identity,
        create_object: Option<u64>,
        dialect: Dialect,
        ingestion: Ingestion,
    ) -> Result<Compiled> {
        text(sql, 4096)?;
        create_object.map(positive).transpose()?;
        self.compiled(json!({"compile":{"sql":sql,"namespace":identity.namespace,"operation":identity.operation.to_string(),"create_object":create_object.map(|v|v.to_string()),"dialect":dialect.tag(),"ingestion":ingestion.tag()}}),identity)
    }
    pub fn prepare(
        &mut self,
        name_: &str,
        identity: Identity,
        operation: &Operation,
    ) -> Result<Compiled> {
        self.compiled(json!({"prepare":{"definition":abi::ABI_DEFINITION,"name":name(name_)?,"namespace":identity.namespace,"operation":identity.operation.to_string(),"action":operation.wire()?}}),identity)
    }
    pub fn load(&mut self, saved: &SavedIntent) -> Result<Intent> {
        let c = self.connection.clone();
        let p = self.principal;
        self.read(json!({"load":saved.wire()}), &["loaded"], |v| {
            Intent::parse(v, saved.clone(), &c, p, None)
        })
    }
    pub fn forget(&mut self, intent: &Intent) -> Result<()> {
        self.read(json!({"forget":intent.id}), &["forgotten"], |v| {
            object(v, &[])
        })
    }
    pub fn preview(&mut self, intent: &Intent) -> Result<Preview> {
        self.read(json!({"preview":intent.id}), &["preview"], |v| {
            Preview::parse(v, intent)
        })
    }
    pub fn stage(&mut self, intent: &Intent) -> DispatchResult<Reference> {
        let c = self.connection.clone();
        let p = self.principal;
        self.dispatch(
            json!({"stage":intent.id}),
            Recovery::Intent(intent.saved.clone()),
            &["staged"],
            |v| {
                let original = Reference::parse(v)?;
                if original.connection() != c
                    || original.principal() != p
                    || original.kind() != intent.kind
                    || *original.binding() != intent.binding
                    || original.identity() != intent.identity
                {
                    return Err(malformed());
                }
                Ok(original)
            },
        )
    }
    pub fn admit(&mut self, original: &Reference) -> DispatchResult<Observation> {
        self.owner(&original.connection(), original.principal())?;
        self.dispatch(
            json!({"admit":original.wire()}),
            Recovery::Reference(original.clone()),
            &["observation"],
            |v| Observation::parse(v, original),
        )
    }
    pub fn inspect(&mut self, original: &Reference) -> Result<Observation> {
        self.owner(&original.connection(), original.principal())?;
        self.read(
            json!({"operation":{"reference":original.wire(),"command":"inspect","steps":1}}),
            &["observation"],
            |v| Observation::parse(v, original),
        )
    }
    fn operation(
        &mut self,
        original: &Reference,
        command: &str,
        steps: u16,
    ) -> DispatchResult<Observation> {
        self.owner(&original.connection(), original.principal())?;
        positive(steps.into())?;
        self.dispatch(
            json!({"operation":{"reference":original.wire(),"command":command,"steps":steps}}),
            Recovery::Reference(original.clone()),
            &["observation"],
            |v| Observation::parse(v, original),
        )
    }
    pub fn execute(&mut self, original: &Reference, steps: u16) -> DispatchResult<Observation> {
        self.operation(original, "execute", steps)
    }
    pub fn cancel(&mut self, original: &Reference) -> DispatchResult<Observation> {
        self.operation(original, "cancel", 1)
    }
    pub fn prepare_snapshot(
        &self,
        metadata: &Metadata,
        operation: u64,
    ) -> Result<SnapshotAcquisition> {
        let basis = &metadata.basis;
        self.owner(&basis.connection(), basis.principal())?;
        SnapshotAcquisition::parse(
            &json!({"owner":{"definition":abi::ABI_DEFINITION,"connection":self.connection.wire(self.principal),"object":basis.interpretation().interpretation.object.wire(),"operation":positive(operation)?.to_string()},"expected":metadata.position.wire()}),
        )
    }
    pub fn acquire_snapshot(
        &mut self,
        acquisition: &SnapshotAcquisition,
    ) -> DispatchResult<Snapshot> {
        let owner = acquisition.owner();
        self.owner(&owner.connection(), owner.principal())?;
        self.dispatch(
            json!({"retention":{"acquire":acquisition.wire()}}),
            Recovery::Acquisition(acquisition.clone()),
            &["retention", "acquired"],
            |v| {
                let snapshot = Snapshot::parse(v)?;
                if snapshot.owner() != owner {
                    return Err(malformed());
                }
                Ok(snapshot)
            },
        )
    }
    pub fn snapshot_status(&mut self, owner: &SnapshotOwner) -> Result<SnapshotStatus> {
        self.owner(&owner.connection(), owner.principal())?;
        self.read(
            json!({"retention":{"status":owner.wire()}}),
            &["retention", "status"],
            |v| SnapshotStatus::parse(v, owner),
        )
    }
    pub fn snapshot_metadata(&mut self, snapshot: &Snapshot) -> Result<SnapshotMetadata> {
        let owner = snapshot.owner();
        self.owner(&owner.connection(), owner.principal())?;
        self.read(
            json!({"retention":{"metadata":snapshot.wire()}}),
            &["retention", "metadata"],
            |v| SnapshotMetadata::parse(v, snapshot),
        )
    }
    pub fn release_snapshot(&mut self, snapshot: &Snapshot) -> DispatchResult<Snapshot> {
        let owner = snapshot.owner();
        self.owner(&owner.connection(), owner.principal())?;
        self.dispatch(
            json!({"retention":{"release":snapshot.wire()}}),
            Recovery::Snapshot(snapshot.clone()),
            &["retention", "released"],
            |v| {
                if *v != snapshot.0 {
                    return Err(malformed());
                }
                Ok(snapshot.clone())
            },
        )
    }
    pub fn close(mut self) -> Result<()> {
        self.worker.close()
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::logical::{CellValue, ScalarType};
    #[test]
    fn authority_requires_complete_distinct_domains() {
        let wire = json!({"database_domain":10,"schema_domain":11,"table_domain":12,
            "stream_domain":31,"queue_domain":32,"kv_domain":33,
            "database":20,"initial_schema":1,"initial_schema_authority":21});
        assert_eq!(
            AuthorityProfile::parse(&wire).unwrap().wire().unwrap(),
            wire
        );
        for field in ["stream_domain", "queue_domain", "kv_domain"] {
            let mut missing = wire.clone();
            missing.as_object_mut().unwrap().remove(field);
            assert!(AuthorityProfile::parse(&missing).is_err());
            let mut duplicate = wire.clone();
            duplicate[field] = json!(12);
            assert!(AuthorityProfile::parse(&duplicate).is_err());
        }
    }
    #[test]
    fn physical_schema_and_alter_preserve_explicit_descriptors() {
        let wire = json!({"definition":abi::ABI_DEFINITION,"object":"7","revision":"2","next_column":"2",
            "columns":[{"id":"1","name":"text","type":{"utf8":{}},"nullable":true,"default":null,
                "max_characters":null,"encoding":"ebcdic","collation":"ebcdic_cp037"}],"primary_key":[]});
        let schema = Schema::parse(&wire).unwrap();
        assert_eq!(schema.columns[0].encoding, Encoding::Ebcdic);
        assert_eq!(schema.columns[0].collation, Collation::EbcdicCp037);
        assert_eq!(schema.wire().unwrap(), wire);
        assert_eq!(
            Change::Physical {
                column: 1,
                encoding: Encoding::Fsst,
                collation: Collation::AsciiCi
            }
            .wire()
            .unwrap(),
            json!({"physical":{"column":"1","encoding":"fsst","collation":"ascii_ci"}})
        );
        let added = Change::Add {
            name: "text".into(),
            datatype: schema.columns[0].datatype.clone(),
            nullable: true,
            default: None,
            max_characters: None,
            encoding: Encoding::Ebcdic,
            collation: Collation::EbcdicCp037,
        }
        .wire()
        .unwrap();
        assert_eq!(added["add"]["encoding"], "ebcdic");
        assert_eq!(added["add"]["collation"], "ebcdic_cp037");
        for field in ["encoding", "collation"] {
            let mut bad = wire.clone();
            bad["columns"][0].as_object_mut().unwrap().remove(field);
            assert!(Schema::parse(&bad).is_err());
            bad["columns"][0][field] = json!("invented");
            assert!(Schema::parse(&bad).is_err());
        }
    }
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
    fn connection() -> Connection {
        Connection::new(scope(), 3).unwrap()
    }
    fn target() -> Value {
        json!({"scope":scope().wire(),"branch":"1","object":u64::MAX.to_string()})
    }
    fn interpretation() -> Value {
        json!({"object":target(),"revision":"1","digest":"ab".repeat(32)})
    }
    fn stored() -> Value {
        json!({"interpretation":interpretation(),"content":{"bytes":"300","sha256":"ab".repeat(32)},"schema_fingerprint":"cd".repeat(32),"retired":false})
    }
    fn basis() -> Value {
        json!({"definition":abi::ABI_DEFINITION,"connection":connection().wire(17),"namespace":1,"name":"items","interpretation":stored()})
    }
    fn position() -> Value {
        json!({"partition":u64::MAX.to_string(),"next_lsn":u64::MAX.to_string()})
    }
    fn binding() -> Value {
        json!({"definition":abi::ABI_DEFINITION,"identity":{"scope":scope().wire(),"principal":17,"operation":"10"},"target":target(),"action":"insert","expected_definition":interpretation(),"expected_data":null,"intent":"aa".repeat(32),"prerequisite":null})
    }
    fn reference() -> Value {
        json!({"table":{"definition":abi::ABI_DEFINITION,"connection":connection().wire(17),"namespace":1,"binding":binding(),"content":{"bytes":"200","sha256":"22".repeat(32)}}})
    }
    fn observed() -> Value {
        json!({"rows":{"committed":{"binding":binding(),"resulting":stored(),"transaction":null,"outcome":{"position":position(),"matched":"9","affected":"9","live_rows":"9"}}}})
    }
    fn table_page() -> Value {
        json!({"position":position(),"entries":[{"interpretation":interpretation(),"namespace":1,"name":"items","position":position(),"changed_lsn":"3"},null,null,null,null,null,null,null],"next":{"definition":abi::ABI_DEFINITION,"connection":connection().wire(17),"selection":{"tables":1},"position":position(),"after":u64::MAX.to_string()},"consistency":"independent"})
    }
    fn parse_page(v: &Value, previous: Option<&Cursor>) -> Result<Page<Entry>> {
        require_schema("CatalogResult", &json!({"catalog":{"tables":v}}))?;
        page(v, &connection(), 17, &json!({"tables":1}), previous, |v| {
            let i = Interpretation::parse(&v["interpretation"])?;
            connection().owns(&i.object)?;
            if n(&v["namespace"], false)? != 1 {
                return Err(malformed());
            }
            Ok((
                i.object.object,
                Entry {
                    interpretation: i,
                    namespace: 1,
                    name: string(&v["name"], "name")?.into(),
                    position: Position::parse(&v["position"])?,
                    changed_lsn: w(&v["changed_lsn"], true)?,
                },
            ))
        })
    }
    #[test]
    fn direct_saved_bindings_and_strict_json_preserve_originals() {
        let wide = json!({"table":{"definition":abi::ABI_DEFINITION,"namespace":1,"bytes":"ab".repeat(300_000)}});
        assert_eq!(
            SavedIntent::restore(&wide.to_string()).unwrap().wire(),
            wide
        );

        let basis = Basis::restore(&basis().to_string()).unwrap();
        assert_eq!(basis.object(), u64::MAX);
        assert_eq!(basis.connection(), connection());
        assert!(!format!("{basis:?}").contains("items"));
        assert!(
            Basis::restore(&format!(
                "{},\"name\":\"other\"}}",
                &basis.save()[..basis.save().len() - 1]
            ))
            .is_err()
        );
        for fault in 0..7 {
            let mut bad = reference();
            match fault {
                0 => {
                    bad["table"].as_object_mut().unwrap().remove("definition");
                }
                1 => bad["table"]["definition"] = json!("00".repeat(32)),
                2 => bad["table"]["binding"]["identity"]["principal"] = json!(18),
                3 => bad["table"]["binding"]["target"]["branch"] = json!("2"),
                4 => {
                    bad["table"]["binding"]["expected_definition"]["object"]["object"] = json!("1")
                }
                5 => bad["table"]["content"]["bytes"] = json!("0"),
                _ => {
                    bad["table"]["binding"]
                        .as_object_mut()
                        .unwrap()
                        .remove("prerequisite");
                }
            }
            assert!(
                Reference::restore(&bad.to_string()).is_err(),
                "fault {fault}"
            );
        }
        let original = Reference::restore(&reference().to_string()).unwrap();
        assert_eq!(original.identity().operation(), 10);
        let saved = SavedIntent::restore(
            &json!({"table":{"definition":abi::ABI_DEFINITION,"namespace":1,"bytes":"aabb"}})
                .to_string(),
        )
        .unwrap();
        let summary = json!({"id":{"definition":abi::ABI_DEFINITION,"digest":"11".repeat(32)},"namespace":1,"binding":{"table":binding()}});
        require_schema("CatalogResult", &json!({"loaded":summary})).unwrap();
        assert_eq!(
            Intent::parse(
                &summary,
                saved,
                &connection(),
                17,
                Some(Identity::new(10, 1).unwrap())
            )
            .unwrap()
            .identity
            .operation(),
            10
        );
        let operation = Client::decode(&json!({"observation":observed()}), &["observation"], |v| {
            Observation::parse(v, &original)
        })
        .unwrap();
        assert_eq!(operation.commit.unwrap().position.next_lsn, u64::MAX);
        for fault in 0..5 {
            let mut bad = observed();
            match fault {
                0 => bad["rows"]["committed"]["binding"]["identity"]["operation"] = json!("11"),
                1 => bad["rows"]["committed"]["outcome"]["affected"] = json!("10"),
                2 => {
                    bad["rows"]["committed"]
                        .as_object_mut()
                        .unwrap()
                        .remove("transaction");
                }
                3 => bad["rows"]["committed"]["transaction"] = json!({}),
                _ => {
                    bad["rows"]["committed"]["resulting"]["content"]["sha256"] =
                        json!("00".repeat(32))
                }
            };
            assert!(Observation::parse(&bad, &original).is_err());
        }
    }
    #[test]
    fn direct_pages_and_retention_reject_changed_cuts_and_substitutions() {
        let mut source = table_page();
        let parsed = parse_page(&source, None).unwrap();
        source["entries"][0] = Value::Null;
        assert_eq!(parsed.entries[0].interpretation.object.object, u64::MAX);
        for fault in 0..9 {
            let mut bad = table_page();
            match fault {
                0 => {
                    bad["entries"].as_array_mut().unwrap().pop();
                }
                1 => {
                    bad["entries"][1] = bad["entries"][0].take();
                }
                2 => bad["entries"][1] = bad["entries"][0].clone(),
                3 => bad["entries"][0]["interpretation"]["object"]["scope"]["catalog"] = json!("1"),
                4 => {
                    bad["next"].as_object_mut().unwrap().remove("definition");
                }
                5 => bad["next"]["after"] = json!("1"),
                6 => bad["next"]["position"]["next_lsn"] = json!("1"),
                7 => bad["entries"][0]["namespace"] = json!(2),
                _ => bad["entries"][0]["interpretation"]["object"]["object"] = json!(u64::MAX),
            }
            assert!(parse_page(&bad, None).is_err(), "fault {fault}");
        }
        assert!(parse_page(&table_page(), parsed.next.as_ref()).is_err());
        let acquisition=SnapshotAcquisition::restore(&json!({"owner":{"definition":abi::ABI_DEFINITION,"connection":connection().wire(17),"object":target(),"operation":u64::MAX.to_string()},"expected":position()}).to_string()).unwrap();
        assert_eq!(acquisition.owner().operation(), u64::MAX);
        let snapshot=Snapshot::restore(&json!({"owner":acquisition.owner().wire(),"content":{"bytes":"500","sha256":"44".repeat(32)}}).to_string()).unwrap();
        let schema = Schema {
            object: u64::MAX,
            revision: 1,
            next_column: 2,
            columns: vec![Column::new(
                1,
                "id".into(),
                Descriptor::Scalar(ScalarType::Int128),
            )],
            primary_key: vec![],
        };
        let mut metadata = json!({"snapshot":snapshot.wire(),"interpretation":stored(),"accepted":position(),"changed_lsn":"3","row_count":"9","schema":schema.wire().unwrap(),"authority":{"database":31,"schema":32,"table":33}});
        require_schema("CatalogResult", &json!({"retention":{"metadata":metadata}})).unwrap();
        assert_eq!(
            SnapshotMetadata::parse(&metadata, &snapshot)
                .unwrap()
                .row_count,
            9
        );
        metadata["snapshot"]["content"]["sha256"] = json!("55".repeat(32));
        assert!(SnapshotMetadata::parse(&metadata, &snapshot).is_err());
    }

    #[test]
    fn typed_bulk_uses_generated_action_contract() {
        let operation = Operation::Mutate {
            basis: Basis::parse(&basis()).unwrap(),
            ingestion: Ingestion::Bulk,
            mutation: Mutation::Insert {
                rows: vec![
                    vec![
                        Assignment {
                            column: 1,
                            value: AssignmentValue::Cell(Cell::Value(CellValue::Atom(
                                Atom::Signed(0)
                            )))
                        },
                        Assignment {
                            column: 2,
                            value: AssignmentValue::Cell(Cell::Value(CellValue::Atom(
                                Atom::Binary(vec![0; 32768])
                            )))
                        }
                    ];
                    9
                ],
            },
        };
        require_schema("CatalogAction",&json!({"prepare":{"definition":abi::ABI_DEFINITION,"name":"items","namespace":1,"operation":"2","action":operation.wire().unwrap()}})).unwrap();
    }
}
