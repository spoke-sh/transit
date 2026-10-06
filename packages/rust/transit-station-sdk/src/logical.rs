//! Owned logical values. Shared Zig owns domain validation and execution.
use serde_json::{Value as Json, json};
use transit_client::internal::{hex, unhex};
use transit_client::{Error, ErrorKind, Result};

fn invalid() -> Error {
    Error::new(ErrorKind::InvalidArgument, "logical-value")
}
fn malformed() -> Error {
    Error::new(ErrorKind::IncompatibleNative, "logical-response")
}
fn object(value: &Json, fields: &[&str]) -> Result<()> {
    let object = value.as_object().ok_or_else(malformed)?;
    if object.len() != fields.len() || fields.iter().any(|key| !object.contains_key(*key)) {
        return Err(malformed());
    }
    Ok(())
}
fn variant(value: &Json) -> Result<(&str, &Json)> {
    let object = value
        .as_object()
        .filter(|value| value.len() == 1)
        .ok_or_else(malformed)?;
    let (key, value) = object.iter().next().ok_or_else(malformed)?;
    Ok((key, value))
}
fn text(value: &Json) -> Result<&str> {
    value.as_str().ok_or_else(malformed)
}
fn boolean(value: &Json) -> Result<bool> {
    value.as_bool().ok_or_else(malformed)
}
fn list(value: &Json) -> Result<&Vec<Json>> {
    value.as_array().ok_or_else(malformed)
}
fn exact<T: std::str::FromStr + ToString>(value: &Json) -> Result<T> {
    let text = text(value)?;
    if text.len() > 40 {
        return Err(malformed());
    }
    text.parse::<T>()
        .ok()
        .filter(|value| value.to_string() == text)
        .ok_or_else(malformed)
}
fn bytes(value: &Json, bound: usize) -> Result<Vec<u8>> {
    let text = text(value)?;
    if !text
        .bytes()
        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        return Err(malformed());
    }
    unhex(text, bound).map_err(|_| malformed())
}
macro_rules! scalars {
    ($($variant:ident => $name:literal),+ $(,)?) => {
        #[derive(Clone, Copy, Debug, Eq, PartialEq)]
        pub enum ScalarType { $($variant),+ }
        impl ScalarType {
            pub(crate) fn name(self) -> &'static str { match self { $(Self::$variant => $name),+ } }
            fn parse(name: &str) -> Option<Self> { match name { $($name => Some(Self::$variant),)+ _ => None } }
        }
    };
}
scalars! {
    Int8 => "int8", Int16 => "int16", Int32 => "int32", Int64 => "int64", Int128 => "int128",
    Uint8 => "uint8", Uint16 => "uint16", Uint32 => "uint32", Uint64 => "uint64", Uint128 => "uint128",
    Float32 => "float32", Float64 => "float64", Boolean => "boolean", Utf8 => "utf8", Binary => "binary",
    Date => "date", Time => "time", Interval => "interval", Uuid => "uuid", Json => "json",
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TypeKind {
    Scalar(ScalarType),
    Decimal,
    Timestamp,
    Structure,
    TaggedUnion,
    List,
    Array,
    Map,
}
impl TypeKind {
    fn name(self) -> &'static str {
        match self {
            Self::Scalar(value) => value.name(),
            Self::Decimal => "decimal",
            Self::Timestamp => "timestamp",
            Self::Structure => "structure",
            Self::TaggedUnion => "tagged_union",
            Self::List => "list",
            Self::Array => "array",
            Self::Map => "map",
        }
    }
    fn parse(value: &str) -> Result<Self> {
        if let Some(value) = ScalarType::parse(value) {
            return Ok(Self::Scalar(value));
        }
        Ok(match value {
            "decimal" => Self::Decimal,
            "timestamp" => Self::Timestamp,
            "structure" => Self::Structure,
            "tagged_union" => Self::TaggedUnion,
            "list" => Self::List,
            "array" => Self::Array,
            "map" => Self::Map,
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TimestampZone {
    Civil,
    Utc,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Field {
    pub name: String,
    pub datatype: Descriptor,
    pub nullable: bool,
    pub optional: bool,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Element {
    pub datatype: Box<Descriptor>,
    pub nullable: bool,
}
impl Element {
    pub fn new(datatype: Descriptor, nullable: bool) -> Self {
        Self {
            datatype: Box::new(datatype),
            nullable,
        }
    }
    fn wire(&self, budget: &mut Budget, depth: usize) -> Result<Json> {
        Ok(json!({"type":self.datatype.encode(budget, depth)?,"nullable":self.nullable}))
    }
    fn parse(value: &Json, budget: &mut Budget, depth: usize) -> Result<Self> {
        object(value, &["type", "nullable"])?;
        Ok(Self::new(
            Descriptor::decode(&value["type"], budget, depth)?,
            boolean(&value["nullable"])?,
        ))
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Descriptor {
    Scalar(ScalarType),
    Decimal {
        precision: u8,
        scale: u8,
    },
    Timestamp(TimestampZone),
    Structure(Vec<Field>),
    TaggedUnion(Vec<Field>),
    List(Element),
    Array {
        element: Element,
        length: u32,
    },
    Map {
        key: Box<Descriptor>,
        value: Element,
    },
}
struct Budget {
    nodes: usize,
    bytes: usize,
    max_nodes: usize,
    names: usize,
}
impl Budget {
    fn new(max_nodes: usize) -> Self {
        Self {
            nodes: 0,
            bytes: 0,
            max_nodes,
            names: 0,
        }
    }
    fn child(&mut self, depth: usize) -> Result<()> {
        if depth >= 16 || self.nodes >= self.max_nodes {
            return Err(invalid());
        }
        self.nodes += 1;
        Ok(())
    }
    fn name<'a>(&mut self, value: &'a str) -> Result<&'a str> {
        if value.len() > 4096 - self.names {
            return Err(invalid());
        }
        self.names += value.len();
        Ok(value)
    }
    fn data(&mut self, length: usize) -> Result<()> {
        if length > 1024 * 1024 - self.bytes {
            return Err(invalid());
        }
        self.bytes += length;
        Ok(())
    }
}
impl Descriptor {
    pub(crate) fn wire(&self) -> Result<Json> {
        self.encode(&mut Budget::new(256), 0)
    }
    pub(crate) fn parse(value: &Json) -> Result<Self> {
        Self::decode(value, &mut Budget::new(256), 0)
    }
    fn encode(&self, budget: &mut Budget, depth: usize) -> Result<Json> {
        budget.child(depth)?;
        Ok(match self {
            Self::Scalar(kind) => json!({(kind.name()):{}}),
            Self::Decimal { precision, scale } => {
                if *precision == 0 || *precision > 38 || scale > precision {
                    return Err(invalid());
                }
                json!({"decimal":{"precision":precision,"scale":scale}})
            }
            Self::Timestamp(zone) => {
                json!({"timestamp":match zone { TimestampZone::Civil => "civil", TimestampZone::Utc => "utc" }})
            }
            Self::Structure(fields) | Self::TaggedUnion(fields) => {
                let fields: Vec<Json> = fields.iter().map(|field| Ok(json!({"name":budget.name(&field.name)?,"type":field.datatype.encode(budget,depth+1)?,"nullable":field.nullable,"optional":field.optional}))).collect::<Result<_>>()?;
                json!({(if matches!(self,Self::Structure(_)) {"structure"} else {"tagged_union"}):fields})
            }
            Self::List(element) => json!({"list":element.wire(budget,depth+1)?}),
            Self::Array { element, length } => {
                if *length == 0 {
                    return Err(invalid());
                }
                json!({"array":{"element":element.wire(budget,depth+1)?,"length":length}})
            }
            Self::Map { key, value } => {
                json!({"map":{"key":key.encode(budget,depth+1)?,"value":value.wire(budget,depth+1)?}})
            }
        })
    }
    fn decode(value: &Json, budget: &mut Budget, depth: usize) -> Result<Self> {
        budget.child(depth)?;
        let (kind, payload) = variant(value)?;
        if let Some(kind) = ScalarType::parse(kind) {
            object(payload, &[])?;
            return Ok(Self::Scalar(kind));
        }
        Ok(match kind {
            "decimal" => {
                object(payload, &["precision", "scale"])?;
                let precision = payload["precision"]
                    .as_u64()
                    .filter(|value| (1..=38).contains(value))
                    .ok_or_else(malformed)? as u8;
                let scale = payload["scale"]
                    .as_u64()
                    .filter(|value| *value <= u64::from(precision))
                    .ok_or_else(malformed)? as u8;
                Self::Decimal { precision, scale }
            }
            "timestamp" => Self::Timestamp(match text(payload)? {
                "civil" => TimestampZone::Civil,
                "utc" => TimestampZone::Utc,
                _ => return Err(malformed()),
            }),
            "structure" | "tagged_union" => {
                let fields = list(payload)?
                    .iter()
                    .map(|field| {
                        object(field, &["name", "type", "nullable", "optional"])?;
                        Ok(Field {
                            name: budget.name(text(&field["name"])?)?.into(),
                            datatype: Self::decode(&field["type"], budget, depth + 1)?,
                            nullable: boolean(&field["nullable"])?,
                            optional: boolean(&field["optional"])?,
                        })
                    })
                    .collect::<Result<Vec<_>>>()?;
                if kind == "structure" {
                    Self::Structure(fields)
                } else {
                    Self::TaggedUnion(fields)
                }
            }
            "list" => Self::List(Element::parse(payload, budget, depth + 1)?),
            "array" => {
                object(payload, &["element", "length"])?;
                let length = payload["length"]
                    .as_u64()
                    .and_then(|value| u32::try_from(value).ok())
                    .filter(|value| *value > 0)
                    .ok_or_else(malformed)?;
                Self::Array {
                    element: Element::parse(&payload["element"], budget, depth + 1)?,
                    length,
                }
            }
            "map" => {
                object(payload, &["key", "value"])?;
                Self::Map {
                    key: Box::new(Self::decode(&payload["key"], budget, depth + 1)?),
                    value: Element::parse(&payload["value"], budget, depth + 1)?,
                }
            }
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Atom {
    Signed(i128),
    Unsigned(u128),
    Decimal(i128),
    Float32(f32),
    Float64(f64),
    Boolean(bool),
    Utf8(String),
    Binary(Vec<u8>),
    DateDays(i32),
    TimeNanos(u64),
    TimestampMicros(i64),
    Interval { months: i32, days: i32, nanos: i64 },
    Uuid([u8; 16]),
}
impl Atom {
    pub(crate) fn wire(&self) -> Result<Json> {
        self.encode(&mut Budget::new(65536))
    }
    fn encode(&self, budget: &mut Budget) -> Result<Json> {
        Ok(match self {
            Self::Signed(value) => json!({"signed":value.to_string()}),
            Self::Unsigned(value) => json!({"unsigned":value.to_string()}),
            Self::Decimal(value) => json!({"decimal":value.to_string()}),
            Self::DateDays(value) => json!({"date_days":value.to_string()}),
            Self::TimeNanos(value) => json!({"time_nanos":value.to_string()}),
            Self::TimestampMicros(value) => json!({"timestamp_micros":value.to_string()}),
            Self::Interval {
                months,
                days,
                nanos,
            } => {
                json!({"interval":{"months":months.to_string(),"days":days.to_string(),"nanos":nanos.to_string()}})
            }
            Self::Float32(value) => {
                if !value.is_finite() {
                    return Err(invalid());
                }
                {
                    budget.data(4)?;
                    json!({"float_bits":hex(&value.to_le_bytes(),4)?})
                }
            }
            Self::Float64(value) => {
                if !value.is_finite() {
                    return Err(invalid());
                }
                {
                    budget.data(8)?;
                    json!({"float_bits":hex(&value.to_le_bytes(),8)?})
                }
            }
            Self::Boolean(value) => json!({"boolean":value}),
            Self::Utf8(value) => {
                budget.data(value.len())?;
                json!({"utf8":value})
            }
            Self::Binary(value) => {
                budget.data(value.len())?;
                json!({"binary":hex(value,1024*1024)?})
            }
            Self::Uuid(value) => {
                budget.data(value.len())?;
                json!({"uuid":hex(value,16)?})
            }
        })
    }
    fn decode(value: &Json, budget: &mut Budget) -> Result<Self> {
        let (kind, value) = variant(value)?;
        Ok(match kind {
            "signed" => Self::Signed(exact(value)?),
            "unsigned" => Self::Unsigned(exact(value)?),
            "decimal" => Self::Decimal(exact(value)?),
            "date_days" => Self::DateDays(exact(value)?),
            "time_nanos" => Self::TimeNanos(exact(value)?),
            "timestamp_micros" => Self::TimestampMicros(exact(value)?),
            "boolean" => Self::Boolean(boolean(value)?),
            "utf8" => {
                let text = text(value)?;
                budget.data(text.len())?;
                Self::Utf8(text.into())
            }
            "binary" => {
                let bytes = bytes(value, 1024 * 1024)?;
                budget.data(bytes.len())?;
                Self::Binary(bytes)
            }
            "uuid" => {
                let bytes = bytes(value, 16)?;
                budget.data(bytes.len())?;
                Self::Uuid(bytes.try_into().map_err(|_| malformed())?)
            }
            "float_bits" => {
                let bytes = bytes(value, 8)?;
                budget.data(bytes.len())?;
                match bytes.len() {
                    4 => {
                        let value = f32::from_le_bytes(bytes.try_into().map_err(|_| malformed())?);
                        if !value.is_finite() {
                            return Err(malformed());
                        }
                        Self::Float32(value)
                    }
                    8 => {
                        let value = f64::from_le_bytes(bytes.try_into().map_err(|_| malformed())?);
                        if !value.is_finite() {
                            return Err(malformed());
                        }
                        Self::Float64(value)
                    }
                    _ => return Err(malformed()),
                }
            }
            "interval" => {
                object(value, &["months", "days", "nanos"])?;
                Self::Interval {
                    months: exact(&value["months"])?,
                    days: exact(&value["days"])?,
                    nanos: exact(&value["nanos"])?,
                }
            }
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct MapEntry {
    pub key: Atom,
    pub value: Cell,
}
#[derive(Clone, Debug, PartialEq)]
pub enum CellValue {
    Atom(Atom),
    Structure(Vec<Cell>),
    List(Vec<Cell>),
    Array(Vec<Cell>),
    Map(Vec<MapEntry>),
    TaggedUnion { index: u8, value: Box<Cell> },
    Json(String),
}
#[derive(Clone, Debug, PartialEq)]
pub enum AlternativeValue {
    Null,
    TypeError(TypeKind),
    Value(CellValue),
}
#[derive(Clone, Debug, PartialEq)]
pub struct Alternative {
    pub counter: u64,
    pub replica: u64,
    pub value: AlternativeValue,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Cell {
    Missing,
    Null,
    TypeError(TypeKind),
    Value(CellValue),
    Conflict(Vec<Alternative>),
}
impl Cell {
    pub(crate) fn wire(&self) -> Result<Json> {
        self.encode(&mut Budget::new(65536), 0)
    }
    pub(crate) fn parse(value: &Json) -> Result<Self> {
        Self::decode(value, &mut Budget::new(65536), 0)
    }
    fn encode(&self, budget: &mut Budget, depth: usize) -> Result<Json> {
        budget.child(depth)?;
        Ok(match self {
            Self::Missing => json!({"missing":{}}),
            Self::Null => json!({"null":{}}),
            Self::TypeError(kind) => json!({"type_error":kind.name()}),
            Self::Value(value) => json!({"value":value.encode(budget,depth)?}),
            Self::Conflict(alternatives) => {
                if !(2..=8).contains(&alternatives.len()) {
                    return Err(invalid());
                }
                let mut previous = None;
                let values=alternatives.iter().map(|entry| {
                    budget.child(depth)?;
                    if entry.counter==0 || entry.replica==0 || previous.is_some_and(|prior|prior>=(entry.counter,entry.replica)) {return Err(invalid());}
                    previous=Some((entry.counter,entry.replica));
                    let value=match &entry.value { AlternativeValue::Null => json!({"null":{}}),AlternativeValue::TypeError(kind)=>json!({"type_error":kind.name()}),AlternativeValue::Value(value)=>json!({"value":value.encode(budget,depth)?}) };
                    Ok(json!({"counter":entry.counter.to_string(),"replica":entry.replica.to_string(),"value":value}))
                }).collect::<Result<Vec<_>>>()?;
                json!({"conflict":values})
            }
        })
    }
    fn decode(value: &Json, budget: &mut Budget, depth: usize) -> Result<Self> {
        budget.child(depth)?;
        let (kind, value) = variant(value)?;
        Ok(match kind {
            "missing" => {
                object(value, &[])?;
                Self::Missing
            }
            "null" => {
                object(value, &[])?;
                Self::Null
            }
            "type_error" => Self::TypeError(TypeKind::parse(text(value)?)?),
            "value" => Self::Value(CellValue::decode(value, budget, depth)?),
            "conflict" => {
                let entries = list(value)?;
                if !(2..=8).contains(&entries.len()) {
                    return Err(malformed());
                }
                let mut previous = None;
                Self::Conflict(
                    entries
                        .iter()
                        .map(|entry| {
                            budget.child(depth)?;
                            object(entry, &["counter", "replica", "value"])?;
                            let counter = exact::<u64>(&entry["counter"])?;
                            let replica = exact::<u64>(&entry["replica"])?;
                            if counter == 0
                                || replica == 0
                                || previous.is_some_and(|prior| prior >= (counter, replica))
                            {
                                return Err(malformed());
                            }
                            previous = Some((counter, replica));
                            let (kind, value) = variant(&entry["value"])?;
                            let value = match kind {
                                "null" => {
                                    object(value, &[])?;
                                    AlternativeValue::Null
                                }
                                "type_error" => {
                                    AlternativeValue::TypeError(TypeKind::parse(text(value)?)?)
                                }
                                "value" => AlternativeValue::Value(CellValue::decode(
                                    value, budget, depth,
                                )?),
                                _ => return Err(malformed()),
                            };
                            Ok(Alternative {
                                counter,
                                replica,
                                value,
                            })
                        })
                        .collect::<Result<_>>()?,
                )
            }
            _ => return Err(malformed()),
        })
    }
}
impl CellValue {
    fn encode(&self, budget: &mut Budget, depth: usize) -> Result<Json> {
        Ok(match self {
            Self::Atom(atom) => json!({"atom":atom.encode(budget)?}),
            Self::Structure(cells) | Self::List(cells) | Self::Array(cells) => {
                let cells = cells
                    .iter()
                    .map(|cell| cell.encode(budget, depth + 1))
                    .collect::<Result<Vec<_>>>()?;
                json!({(match self {Self::Structure(_)=>"structure",Self::List(_)=>"list",_=>"array"}):cells})
            }
            Self::Map(entries) => {
                let entries=entries.iter().map(|entry|{budget.child(depth+1)?;Ok(json!({"key":entry.key.encode(budget)?,"value":entry.value.encode(budget,depth+1)?}))}).collect::<Result<Vec<_>>>()?;
                json!({"map":entries})
            }
            Self::TaggedUnion { index, value } => {
                json!({"tagged_union":{"index":index,"value":value.encode(budget,depth+1)?}})
            }
            Self::Json(value) => {
                budget.data(value.len())?;
                json!({"json":value})
            }
        })
    }
    fn decode(value: &Json, budget: &mut Budget, depth: usize) -> Result<Self> {
        let (kind, value) = variant(value)?;
        Ok(match kind {
            "atom" => Self::Atom(Atom::decode(value, budget)?),
            "structure" | "list" | "array" => {
                let cells = list(value)?
                    .iter()
                    .map(|value| Cell::decode(value, budget, depth + 1))
                    .collect::<Result<Vec<_>>>()?;
                match kind {
                    "structure" => Self::Structure(cells),
                    "list" => Self::List(cells),
                    _ => Self::Array(cells),
                }
            }
            "map" => Self::Map(
                list(value)?
                    .iter()
                    .map(|value| {
                        budget.child(depth + 1)?;
                        object(value, &["key", "value"])?;
                        Ok(MapEntry {
                            key: Atom::decode(&value["key"], budget)?,
                            value: Cell::decode(&value["value"], budget, depth + 1)?,
                        })
                    })
                    .collect::<Result<_>>()?,
            ),
            "tagged_union" => {
                object(value, &["index", "value"])?;
                let index = value["index"]
                    .as_u64()
                    .and_then(|value| u8::try_from(value).ok())
                    .ok_or_else(malformed)?;
                Self::TaggedUnion {
                    index,
                    value: Box::new(Cell::decode(&value["value"], budget, depth + 1)?),
                }
            }
            "json" => {
                let text = text(value)?;
                budget.data(text.len())?;
                Self::Json(text.into())
            }
            _ => return Err(malformed()),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn owned_exact_atoms_and_recursive_descriptors() {
        let atoms = [
            Atom::Signed(i128::MIN),
            Atom::Unsigned(u128::MAX),
            Atom::Decimal(123456789012345678901234567890),
            Atom::Float32(-0.0),
            Atom::Float64(-0.0),
            Atom::DateDays(-719162),
            Atom::TimeNanos(1),
            Atom::TimestampMicros(-1),
            Atom::Interval {
                months: -12,
                days: 3,
                nanos: -99,
            },
            Atom::Boolean(true),
            Atom::Utf8("東京".into()),
            Atom::Binary(vec![0, 128, 255]),
            Atom::Uuid([1; 16]),
        ];
        for atom in &atoms {
            let encoded = atom.wire().unwrap();
            let decoded = Atom::decode(&encoded, &mut Budget::new(65536)).unwrap();
            assert_eq!(decoded.wire().unwrap(), encoded);
        }
        assert_eq!(
            atoms[0].wire().unwrap(),
            json!({"signed":"-170141183460469231731687303715884105728"})
        );
        assert_eq!(
            atoms[1].wire().unwrap(),
            json!({"unsigned":"340282366920938463463374607431768211455"})
        );
        assert_eq!(atoms[3].wire().unwrap(), json!({"float_bits":"00000080"}));
        assert_eq!(
            atoms[4].wire().unwrap(),
            json!({"float_bits":"0000000000000080"})
        );
        let descriptor = Descriptor::Array {
            element: Element::new(
                Descriptor::Structure(vec![Field {
                    name: "amount".into(),
                    datatype: Descriptor::Decimal {
                        precision: 38,
                        scale: 2,
                    },
                    nullable: true,
                    optional: false,
                }]),
                false,
            ),
            length: 2,
        };
        let expected = json!({"array":{"element":{"type":{"structure":[{"name":"amount","type":{"decimal":{"precision":38,"scale":2}},"nullable":true,"optional":false}]},"nullable":false},"length":2}});
        assert_eq!(descriptor.wire().unwrap(), expected);
        assert_eq!(Descriptor::parse(&expected).unwrap(), descriptor);
        for bad in [
            json!({"signed":"01"}),
            json!({"unsigned":"-1"}),
            json!({"signed":1}),
            json!({"binary":"FF"}),
            json!({"uuid":"00"}),
            json!({"float_bits":"000000000000f07f"}),
        ] {
            assert!(Atom::decode(&bad, &mut Budget::new(65536)).is_err());
        }
        assert!(Atom::Float64(f64::INFINITY).wire().is_err());
    }
    #[test]
    fn conflict_alternatives_share_their_column_depth_and_have_exact_dots() {
        let conflict = Cell::Conflict(vec![
            Alternative {
                counter: 1,
                replica: 1,
                value: AlternativeValue::Null,
            },
            Alternative {
                counter: u64::MAX,
                replica: u64::MAX,
                value: AlternativeValue::Value(CellValue::Atom(Atom::Boolean(true))),
            },
        ]);
        let mut deep = conflict.clone();
        for _ in 0..15 {
            deep = Cell::Value(CellValue::List(vec![deep]));
        }
        assert_eq!(Cell::parse(&deep.wire().unwrap()).unwrap(), deep);
        deep = Cell::Value(CellValue::List(vec![deep]));
        assert!(deep.wire().is_err());
        let mut invalid = conflict.wire().unwrap();
        invalid["conflict"][1]["counter"] = json!("1");
        invalid["conflict"][1]["replica"] = json!("1");
        assert!(Cell::parse(&invalid).is_err());
        invalid["conflict"][1]["counter"] = json!("2");
        invalid["conflict"][1]["value"] = json!({"missing":{}});
        assert!(Cell::parse(&invalid).is_err());
    }
    #[test]
    fn aggregate_value_and_map_child_budgets_precede_native_admission() {
        let oversized = Cell::Value(CellValue::Structure(vec![
            Cell::Value(CellValue::Atom(Atom::Binary(vec![0; 600_000]))),
            Cell::Value(CellValue::Atom(Atom::Binary(vec![0; 600_000]))),
        ]));
        assert!(oversized.wire().is_err());
        let encoded = json!({"value":{"structure":[{"value":{"atom":{"utf8":"a".repeat(600_000)}}},{"value":{"atom":{"utf8":"b".repeat(600_000)}}}]}});
        assert!(Cell::parse(&encoded).is_err());
        let entries = (0..32768)
            .map(|value| MapEntry {
                key: Atom::Unsigned(value),
                value: Cell::Null,
            })
            .collect();
        assert!(Cell::Value(CellValue::Map(entries)).wire().is_err());
    }
}
