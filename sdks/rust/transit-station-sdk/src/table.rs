//! Owned general Table values and exact one-turn mutation steps.
use crate::catalog::{Counts, Mutation};
pub use crate::catalog::{Schema as TableSchema, TableLimits};
pub use crate::logical::Cell;
use crate::{
    Counter, Cursor, ReadVersion, Source, Turn, abi,
    bridge::{counter, field, wide},
    turn::{Access, cursor, next, version},
};
use serde_json::{Value, json};
use transit_client::internal::{hex, number, string, unhex};
use transit_client::{Error, ErrorKind, ResourceRef, Result};

fn invalid() -> Error {
    Error::new(ErrorKind::InvalidArgument, "handler-table-value")
}
fn malformed() -> Error {
    Error::new(ErrorKind::IncompatibleNative, "handler-table-response")
}
fn object(value: &Value, fields: &[&str]) -> Result<()> {
    let map = value.as_object().ok_or_else(malformed)?;
    if map.len() != fields.len() || fields.iter().any(|k| !map.contains_key(*k)) {
        return Err(malformed());
    }
    Ok(())
}
fn positive(value: u64) -> Result<u64> {
    if value == 0 {
        Err(invalid())
    } else {
        Ok(value)
    }
}
fn bytes<const N: usize>(value: &Value) -> Result<[u8; N]> {
    let text = string(value, "table-hex")?;
    let parsed = unhex(text, N)?;
    if hex(&parsed, N)? != text {
        return Err(malformed());
    }
    parsed.try_into().map_err(|_| malformed())
}
fn saved(data: &[u8], tag: &str) -> Result<Value> {
    if data.len() > abi::HANDLER_ACTION_BYTES {
        return Err(invalid());
    }
    let value: Value = serde_json::from_slice(data).map_err(|_| invalid())?;
    if serde_json::to_vec(&value).map_err(|_| invalid())? != data
        || serde_json::to_vec(&json!({"table":{tag:&value}}))
            .map_err(|_| invalid())?
            .len()
            > abi::HANDLER_ACTION_BYTES
    {
        return Err(invalid());
    }
    Ok(value)
}
fn apply(
    owner: &mut dyn Access,
    tag: &str,
    value: Value,
    result: &str,
    read: bool,
) -> Result<Value> {
    let value = owner.apply(json!({"table":{tag:value}}), read)?;
    object(&value, &["table"])?;
    let table = field(&value, "table")?;
    object(table, &[result])?;
    Ok(field(table, result)?.clone())
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct RowIdentity(pub [u8; 20]);
#[derive(Clone, Debug, PartialEq)]
pub struct Row {
    pub identity: RowIdentity,
    pub cells: Vec<Cell>,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TableBasis {
    pub resource: ResourceRef,
    pub revision: Counter,
    pub object: u64,
    pub head: [u8; 32],
}
#[derive(Clone, Debug)]
pub struct TablePage {
    pub rows: Vec<Row>,
    pub next: Option<Cursor>,
}
macro_rules! tags {
    ($name:ident {$($variant:ident => $tag:literal),+ $(,)?}) => {
        #[derive(Clone, Copy, Debug, Eq, PartialEq)] pub enum $name {$($variant),+}
        impl $name { fn parse(value:&Value)->Result<Self>{Ok(match string(value,"table-tag")? {$($tag=>Self::$variant,)+ _=>return Err(malformed())})} }
    };
}
tags!(TableCreationState {Building=>"building",Applied=>"applied"});
tags!(TableMutationState {Building=>"building",Applied=>"applied",Rejected=>"rejected",Cancelled=>"cancelled"});
tags!(TableMutationRoute {Point=>"point",Statement=>"statement",Alter=>"alter"});
tags!(TableRejection {None=>"none",RowExists=>"row_exists",RowIdentityExists=>"row_identity_exists",NullNotAllowed=>"null_not_allowed",MissingRequiredField=>"missing_required_field",CharacterLimitExceeded=>"character_limit_exceeded",Overflow=>"overflow",Inexact=>"inexact"});
tags!(TableWitnessSource {Input=>"input",Stored=>"stored",Withheld=>"withheld"});
#[derive(Clone, Debug)]
pub struct TableCreation {
    pub state: TableCreationState,
    pub admitted_input: Counter,
    pub completed_input: Option<Counter>,
}
#[derive(Clone, Debug)]
pub struct TableWitness {
    pub source: TableWitnessSource,
    pub row: Option<RowIdentity>,
    pub column: u64,
    pub text: String,
    pub truncated: bool,
}
#[derive(Clone, Debug)]
pub struct TableMutationStatus {
    pub reference: TableMutationReference,
    pub state: TableMutationState,
    pub route: TableMutationRoute,
    pub admitted_input: Counter,
    pub completed_input: Option<Counter>,
    pub counts: Option<Counts>,
    pub rejection: TableRejection,
    pub witness: Option<TableWitness>,
}
impl TableMutationStatus {
    fn parse(v: &Value) -> Result<Self> {
        object(
            v,
            &[
                "reference",
                "state",
                "route",
                "admitted_input",
                "completed_input",
                "counts",
                "rejection",
                "witness",
            ],
        )?;
        let state = TableMutationState::parse(&v["state"])?;
        let rejection = TableRejection::parse(&v["rejection"])?;
        let admitted_input = counter(&v["admitted_input"], false)?;
        let completed_input = if v["completed_input"].is_null() {
            None
        } else {
            Some(counter(&v["completed_input"], false)?)
        };
        if (completed_input.is_none() != (state == TableMutationState::Building))
            || completed_input.is_some_and(|c| c < admitted_input)
            || ((rejection != TableRejection::None) != (state == TableMutationState::Rejected))
        {
            return Err(malformed());
        }
        let counts = if v["counts"].is_null() {
            None
        } else {
            object(&v["counts"], &["matched", "changed"])?;
            let c = Counts {
                matched: wide(&v["counts"]["matched"])?,
                changed: wide(&v["counts"]["changed"])?,
            };
            if c.changed > c.matched {
                return Err(malformed());
            }
            Some(c)
        };
        if counts.is_some() != (state == TableMutationState::Applied) {
            return Err(malformed());
        }
        let witness = if v["witness"].is_null() {
            None
        } else {
            let w = &v["witness"];
            object(w, &["source", "row", "column", "text", "truncated"])?;
            let text = string(&w["text"], "witness-text")?;
            if text.len() > 256 {
                return Err(malformed());
            }
            Some(TableWitness {
                source: TableWitnessSource::parse(&w["source"])?,
                row: if w["row"].is_null() {
                    None
                } else {
                    Some(RowIdentity(bytes(&w["row"])?))
                },
                column: wide(&w["column"])?,
                text: text.to_owned(),
                truncated: w["truncated"].as_bool().ok_or_else(malformed)?,
            })
        };
        Ok(Self {
            reference: TableMutationReference::load(
                &serde_json::to_vec(&v["reference"]).map_err(|_| malformed())?,
            )?,
            state,
            route: TableMutationRoute::parse(&v["route"])?,
            admitted_input,
            completed_input,
            counts,
            rejection,
            witness,
        })
    }
}
#[derive(Clone, Debug)]
pub struct TableMutationReference {
    data: Vec<u8>,
    value: Value,
    resource: ResourceRef,
}
impl TableMutationReference {
    pub fn load(data: &[u8]) -> Result<Self> {
        let value = saved(data, "status")?;
        object(
            &value,
            &[
                "definition",
                "realm",
                "resource",
                "object",
                "principal",
                "operation",
                "digest",
            ],
        )?;
        if value["definition"] != abi::ABI_DEFINITION {
            return Err(malformed());
        }
        let resource = ResourceRef::new(
            number(&value["realm"], "realm", false)?,
            number(&value["resource"], "resource", false)?,
        )?;
        number(&value["principal"], "principal", true)?;
        positive(wide(&value["object"])?)?;
        positive(wide(&value["operation"])?)?;
        bytes::<32>(&value["digest"])?;
        Ok(Self {
            data: data.to_vec(),
            value,
            resource,
        })
    }
    pub fn save(&self) -> &[u8] {
        &self.data
    }
    fn read(&self, turn: &mut Turn<'_>, tag: &str) -> Result<Option<TableMutationStatus>> {
        if turn.resource() != self.resource {
            return Err(Error::new(ErrorKind::Handler, "foreign-table-resource"));
        }
        let value = apply(turn, tag, self.value.clone(), "mutation", tag == "status")?;
        if value.is_null() {
            return Ok(None);
        }
        let result = TableMutationStatus::parse(&value)?;
        if result.reference.value != self.value {
            return Err(malformed());
        }
        Ok(Some(result))
    }
    pub fn status(&self, turn: &mut Turn<'_>) -> Result<Option<TableMutationStatus>> {
        self.read(turn, "status")
    }
    pub fn cancel(&self, turn: &mut Turn<'_>) -> Result<TableMutationStatus> {
        self.read(turn, "cancel")?.ok_or_else(malformed)
    }
}
#[derive(Clone, Debug)]
pub struct TableMutation {
    data: Vec<u8>,
    value: Value,
    schema: TableSchema,
    resource: ResourceRef,
    operation: u64,
}
impl TableMutation {
    pub fn prepare(
        resource: ResourceRef,
        principal: Counter,
        operation: u64,
        schema: &TableSchema,
        mutation: &Mutation,
    ) -> Result<Self> {
        let value = json!({"realm":resource.realm(),"resource":resource.resource(),"principal":principal.get(),"operation":positive(operation)?.to_string(),"schema":schema.wire()?,"mutation":mutation.wire()?.1});
        Self::load(&serde_json::to_vec(&value).map_err(|_| invalid())?)
    }
    pub fn load(data: &[u8]) -> Result<Self> {
        let value = saved(data, "mutate")?;
        object(
            &value,
            &[
                "realm",
                "resource",
                "principal",
                "operation",
                "schema",
                "mutation",
            ],
        )?;
        let resource = ResourceRef::new(
            number(&value["realm"], "realm", false)?,
            number(&value["resource"], "resource", false)?,
        )?;
        number(&value["principal"], "principal", true)?;
        let operation = positive(wide(&value["operation"])?)?;
        let schema = TableSchema::parse(&value["schema"])?;
        Mutation::parse(&value["mutation"])?;
        Ok(Self {
            data: data.to_vec(),
            value,
            schema,
            resource,
            operation,
        })
    }
    pub fn save(&self) -> &[u8] {
        &self.data
    }
    pub fn schema(&self) -> &TableSchema {
        &self.schema
    }
    pub fn operation(&self) -> u64 {
        self.operation
    }
    pub fn step(&self, turn: &mut Turn<'_>) -> Result<TableMutationStatus> {
        if turn.resource() != self.resource {
            return Err(Error::new(ErrorKind::Handler, "foreign-table-resource"));
        }
        let result = TableMutationStatus::parse(&apply(
            turn,
            "mutate",
            self.value.clone(),
            "mutation",
            false,
        )?)?;
        if result.reference.value["object"] != self.value["schema"]["object"]
            || ["realm", "resource", "principal", "operation"]
                .iter()
                .any(|k| result.reference.value[k] != self.value[k])
        {
            return Err(malformed());
        }
        Ok(result)
    }
}
fn row(value: &Value) -> Result<Row> {
    object(value, &["identity", "cells"])?;
    let cells = value["cells"]
        .as_array()
        .filter(|v| (1..=128).contains(&v.len()))
        .ok_or_else(malformed)?
        .iter()
        .map(Cell::parse)
        .collect::<Result<Vec<_>>>()?;
    Ok(Row {
        identity: RowIdentity(bytes(&value["identity"])?),
        cells,
    })
}
pub struct Table<'a> {
    owner: &'a mut dyn Access,
    schema: TableSchema,
    basis: TableBasis,
    retained: Option<ReadVersion>,
}
impl<'a> Table<'a> {
    pub(crate) fn capture(
        owner: &'a mut dyn Access,
        object: u64,
        retained: Option<ReadVersion>,
    ) -> Result<Self> {
        positive(object)?;
        let value = apply(
            owner,
            "schema",
            json!({"object":object.to_string(),"version":retained.map(version)}),
            "schema",
            true,
        )?;
        self::object(&value, &["schema", "basis"])?;
        let schema = TableSchema::parse(&value["schema"])?;
        let b = &value["basis"];
        self::object(b, &["resource", "revision", "object", "head"])?;
        let basis = TableBasis {
            resource: ResourceRef::new(
                owner.process().realm(),
                number(&b["resource"], "resource", false)?,
            )?,
            revision: counter(&b["revision"], false)?,
            object: wide(&b["object"])?,
            head: bytes(&b["head"])?,
        };
        if schema.object != object || basis.object != object {
            return Err(malformed());
        }
        Ok(Self {
            owner,
            schema,
            basis,
            retained,
        })
    }
    pub fn schema(&self) -> &TableSchema {
        &self.schema
    }
    pub fn basis(&self) -> &TableBasis {
        &self.basis
    }
    fn source(&self) -> Value {
        json!({"object":self.schema.object.to_string(),"version":self.retained.map(version)})
    }
    fn check_basis(&self, v: &Value) -> Result<()> {
        object(v, &["schema", "basis"])?;
        let b = &v["basis"];
        object(b, &["resource", "revision", "object", "head"])?;
        if number(&b["resource"], "resource", false)? != self.basis.resource.resource()
            || counter(&b["revision"], false)? != self.basis.revision
            || wide(&b["object"])? != self.basis.object
            || bytes::<32>(&b["head"])? != self.basis.head
        {
            return Err(malformed());
        }
        Ok(())
    }
    fn read_row(&mut self, tag: &str, value: Value) -> Result<Option<Row>> {
        let v = apply(self.owner, tag, value, "row", true)?;
        object(&v, &["definition", "row"])?;
        self.check_basis(&v["definition"])?;
        if v["row"].is_null() {
            Ok(None)
        } else {
            row(&v["row"]).map(Some)
        }
    }
    pub fn get(&mut self, identity: RowIdentity) -> Result<Option<Row>> {
        self.read_row(
            "get",
            json!({"source":self.source(),"identity":hex(&identity.0,20)?}),
        )
    }
    pub fn get_key(&mut self, key: &[Cell]) -> Result<Option<Row>> {
        if !(1..=128).contains(&key.len()) {
            return Err(invalid());
        }
        self.read_row("get_key",json!({"source":self.source(),"key":key.iter().map(Cell::wire).collect::<Result<Vec<_>>>()?}))
    }
    pub fn page(&mut self, after: Option<&Cursor>, limit: u8) -> Result<TablePage> {
        if limit == 0 || usize::from(limit) > self.owner.caps().table_page {
            return Err(invalid());
        }
        let request = json!({"source":self.source(),"cursor":cursor(after),"limit":limit});
        let v = apply(self.owner, "page", request, "page", true)?;
        object(&v, &["definition", "rows", "next"])?;
        self.check_basis(&v["definition"])?;
        let rows = v["rows"]
            .as_array()
            .filter(|v| v.len() <= usize::from(limit))
            .ok_or_else(malformed)?
            .iter()
            .map(row)
            .collect::<Result<Vec<_>>>()?;
        Ok(TablePage {
            rows,
            next: next(&v["next"])?,
        })
    }
    pub fn prepare(
        &self,
        principal: Counter,
        operation: u64,
        mutation: &Mutation,
    ) -> Result<TableMutation> {
        self.owner.check()?;
        if self.retained.is_some() {
            return Err(Error::new(ErrorKind::Handler, "retained-table-write"));
        }
        TableMutation::prepare(
            self.basis.resource,
            principal,
            operation,
            &self.schema,
            mutation,
        )
    }
}
impl Turn<'_> {
    pub fn table(&mut self, object: u64) -> Result<Table<'_>> {
        Table::capture(self, object, None)
    }
    pub fn create_table(
        &mut self,
        schema: &TableSchema,
        limits: &TableLimits,
    ) -> Result<TableCreation> {
        let value = json!({"realm":self.resource().realm(),"resource":self.resource().resource(),"schema":schema.wire()?,"limits":limits.wire()?});
        let v = apply(self, "create", value, "created", false)?;
        object(&v, &["state", "admitted_input", "completed_input"])?;
        let state = TableCreationState::parse(&v["state"])?;
        let admitted_input = counter(&v["admitted_input"], false)?;
        let done = counter(&v["completed_input"], true)?;
        if (done.get() == 0) != (state == TableCreationState::Building)
            || (done.get() != 0 && done < admitted_input)
        {
            return Err(malformed());
        }
        Ok(TableCreation {
            state,
            admitted_input,
            completed_input: if done.get() == 0 { None } else { Some(done) },
        })
    }
}
impl Source<'_> {
    pub fn table(&mut self, object: u64) -> Result<Table<'_>> {
        Table::capture(self.owner, object, Some(self.identity))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::catalog::{Assignment, AssignmentValue, Column, CompareOperator, Predicate};
    use crate::logical::{Atom, CellValue, Descriptor, Element, ScalarType};
    fn schema() -> TableSchema {
        let mut id = Column::new(1, "id".into(), Descriptor::Scalar(ScalarType::Int64));
        id.nullable = false;
        TableSchema {
            object: u64::MAX,
            revision: 1,
            next_column: 5,
            columns: vec![
                id,
                Column::new(2, "name".into(), Descriptor::Scalar(ScalarType::Utf8)),
                Column::new(
                    3,
                    "amount".into(),
                    Descriptor::Decimal {
                        precision: 18,
                        scale: 2,
                    },
                ),
                Column::new(
                    4,
                    "tags".into(),
                    Descriptor::List(Element {
                        datatype: Box::new(Descriptor::Scalar(ScalarType::Binary)),
                        nullable: true,
                    }),
                ),
            ],
            primary_key: vec![1],
        }
    }
    fn intent(schema: &TableSchema, mutation: &Mutation) -> TableMutation {
        TableMutation::prepare(
            ResourceRef::new(1, 7).unwrap(),
            Counter::new(0).unwrap(),
            u64::MAX,
            schema,
            mutation,
        )
        .unwrap()
    }
    #[test]
    fn saved_typed_intents_own_original_schema_values_and_full_width_identity() {
        let mut schema = schema();
        let mut mutation = Mutation::Insert {
            rows: vec![vec![
                Assignment {
                    column: 1,
                    value: AssignmentValue::Cell(Cell::Value(CellValue::Atom(Atom::Signed(7)))),
                },
                Assignment {
                    column: 2,
                    value: AssignmentValue::Cell(Cell::Null),
                },
                Assignment {
                    column: 3,
                    value: AssignmentValue::Cell(Cell::Value(CellValue::Atom(Atom::Decimal(
                        12345,
                    )))),
                },
                Assignment {
                    column: 4,
                    value: AssignmentValue::Cell(Cell::Value(CellValue::List(vec![
                        Cell::Null,
                        Cell::Value(CellValue::Atom(Atom::Binary(vec![0, 255]))),
                    ]))),
                },
            ]],
        };
        let captured = intent(&schema, &mutation);
        let original = captured.save().to_vec();
        schema.columns.clear();
        if let Mutation::Insert { rows } = &mut mutation {
            rows.clear();
        }
        let loaded = TableMutation::load(&original).unwrap();
        assert_eq!(loaded.save(), captured.save());
        assert_eq!(loaded.schema().columns.len(), 4);
        assert_eq!(loaded.operation(), u64::MAX);
        assert_eq!(
            loaded.value["mutation"]["action"]["insert"][0][3]["value"]["cell"]["value"]["list"][1]
                ["value"]["atom"]["binary"],
            "00ff"
        );
        for action in [
            Mutation::Update {
                assignments: vec![Assignment {
                    column: 2,
                    value: AssignmentValue::Default,
                }],
                predicate: Some(vec![Predicate::Compare {
                    column: 1,
                    op: CompareOperator::Ge,
                    value: Atom::Signed(1),
                }]),
            },
            Mutation::Delete {
                predicate: Some(vec![Predicate::All, Predicate::Negate]),
            },
        ] {
            let expected = intent(&self::schema(), &action);
            assert_eq!(
                TableMutation::load(expected.save()).unwrap().save(),
                expected.save()
            );
        }
    }
    #[test]
    fn saved_intents_reject_foreign_definitions_and_malformed_original_work() {
        let captured = intent(&schema(), &Mutation::Delete { predicate: None });
        for field in [
            "realm",
            "resource",
            "principal",
            "operation",
            "schema",
            "mutation",
        ] {
            let mut value = captured.value.clone();
            value.as_object_mut().unwrap().remove(field);
            assert!(TableMutation::load(&serde_json::to_vec(&value).unwrap()).is_err());
        }
        for operation in [
            json!(1),
            json!("0"),
            json!("01"),
            json!("18446744073709551616"),
        ] {
            let mut value = captured.value.clone();
            value["operation"] = operation;
            assert!(TableMutation::load(&serde_json::to_vec(&value).unwrap()).is_err());
        }
        for definition in [json!(null), json!("old")] {
            let mut value = captured.value.clone();
            value["schema"]["definition"] = definition;
            assert!(TableMutation::load(&serde_json::to_vec(&value).unwrap()).is_err());
        }
        let mut value = captured.value.clone();
        value["legacy"] = json!({});
        assert!(TableMutation::load(&serde_json::to_vec(&value).unwrap()).is_err());
        let mut bytes = vec![b' '];
        bytes.extend_from_slice(captured.save());
        assert!(TableMutation::load(&bytes).is_err());
        assert!(TableMutation::load(&vec![b'['; 2048]).is_err());
    }
    #[test]
    fn handler_column_row_and_byte_budgets_are_independent() {
        let schema = TableSchema {
            object: 9,
            revision: 1,
            next_column: 129,
            columns: (0..128)
                .map(|i| {
                    Column::new(
                        i + 1,
                        format!("c{i}"),
                        Descriptor::Scalar(ScalarType::Int64),
                    )
                })
                .collect(),
            primary_key: vec![],
        };
        let rows: Vec<_> = (0..1024)
            .map(|i| {
                vec![Assignment {
                    column: 1,
                    value: AssignmentValue::Cell(Cell::Value(CellValue::Atom(Atom::Signed(i)))),
                }]
            })
            .collect();
        let captured = intent(&schema, &Mutation::Insert { rows: rows.clone() });
        assert_eq!(
            TableMutation::load(captured.save())
                .unwrap()
                .schema()
                .columns
                .len(),
            128
        );
        let mut extra = rows;
        extra.push(extra[0].clone());
        assert!(
            TableMutation::prepare(
                ResourceRef::new(1, 7).unwrap(),
                Counter::new(0).unwrap(),
                1,
                &schema,
                &Mutation::Insert { rows: extra }
            )
            .is_err()
        );
        let huge = Mutation::Insert {
            rows: vec![vec![Assignment {
                column: 1,
                value: AssignmentValue::Cell(Cell::Value(CellValue::Atom(Atom::Utf8(
                    "x".repeat(abi::HANDLER_ACTION_BYTES),
                )))),
            }]],
        };
        assert!(
            TableMutation::prepare(
                ResourceRef::new(1, 7).unwrap(),
                Counter::new(0).unwrap(),
                1,
                &schema,
                &huge
            )
            .is_err()
        );
    }
    #[test]
    fn owned_statuses_preserve_full_width_identity_and_only_applied_counts() {
        let reference = json!({"definition":abi::ABI_DEFINITION,"realm":1,"resource":7,"object":u64::MAX.to_string(),"principal":0,"operation":u64::MAX.to_string(),"digest":"11".repeat(32)});
        let parsed =
            TableMutationReference::load(&serde_json::to_vec(&reference).unwrap()).unwrap();
        assert_eq!(
            TableMutationReference::load(parsed.save()).unwrap().value,
            reference
        );
        let mut status = json!({"reference":reference,"state":"building","route":"statement","admitted_input":1,"completed_input":null,"counts":null,"rejection":"none","witness":null});
        assert_eq!(
            TableMutationStatus::parse(&status).unwrap().state,
            TableMutationState::Building
        );
        status["state"] = json!("applied");
        status["completed_input"] = json!(2);
        status["counts"] = json!({"matched":"1","changed":"1"});
        let applied = TableMutationStatus::parse(&status).unwrap();
        assert_eq!(applied.counts.unwrap().changed, 1);
        status["counts"] = Value::Null;
        assert!(TableMutationStatus::parse(&status).is_err());
        status["state"] = json!("building");
        assert!(TableMutationStatus::parse(&status).is_err());
    }
}
