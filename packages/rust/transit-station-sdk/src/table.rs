use crate::{
    Basis, Cursor, Page, ReadVersion, Source, Turn,
    bridge::{field, signed},
    turn::{Access, basis, cursor, next, version},
};
use serde_json::{Value, json};
use std::marker::PhantomData;
use transit_client::internal::{VALUE_BYTES, hex, string, unhex};
use transit_client::{Error, ErrorKind, Result};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CellType {
    Int64,
    Boolean,
    Utf8,
    Binary,
}
impl CellType {
    pub(crate) fn native(self) -> &'static str {
        match self {
            Self::Int64 => "int64",
            Self::Boolean => "boolean",
            Self::Utf8 => "utf8",
            Self::Binary => "binary",
        }
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Cell {
    Null,
    Int64(i64),
    Boolean(bool),
    Utf8(String),
    Binary(Vec<u8>),
}
impl Cell {
    pub(crate) fn wire(&self, bound: usize) -> Result<Value> {
        Ok(match self {
            Self::Null => json!({"null":{}}),
            Self::Int64(value) => json!({"int64":value.to_string()}),
            Self::Boolean(value) => json!({"boolean":value}),
            Self::Utf8(value) => {
                if value.len() > bound {
                    return Err(Error::new(ErrorKind::InvalidArgument, "cell-bound"));
                }
                json!({"utf8":value})
            }
            Self::Binary(value) => json!({"binary":hex(value,bound)?}),
        })
    }
}
mod sealed {
    pub trait Sealed {}
    impl Sealed for i64 {}
    impl Sealed for bool {}
    impl Sealed for String {}
    impl Sealed for Vec<u8> {}
}
pub trait TableValue: sealed::Sealed + Clone + 'static {
    #[doc(hidden)]
    const KIND: CellType;
    #[doc(hidden)]
    fn encode(&self, bound: usize) -> Result<Value>;
    #[doc(hidden)]
    fn decode(value: &Value, bound: usize) -> Result<Self>;
}
impl TableValue for i64 {
    const KIND: CellType = CellType::Int64;
    fn encode(&self, _bound: usize) -> Result<Value> {
        Ok(json!({"int64":self.to_string()}))
    }
    fn decode(value: &Value, _bound: usize) -> Result<Self> {
        signed(field(value, "int64")?)
    }
}
impl TableValue for bool {
    const KIND: CellType = CellType::Boolean;
    fn encode(&self, _bound: usize) -> Result<Value> {
        Ok(json!({"boolean":self}))
    }
    fn decode(value: &Value, _bound: usize) -> Result<Self> {
        field(value, "boolean")?
            .as_bool()
            .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "boolean-cell"))
    }
}
impl TableValue for String {
    const KIND: CellType = CellType::Utf8;
    fn encode(&self, bound: usize) -> Result<Value> {
        if self.len() > bound {
            return Err(Error::new(ErrorKind::InvalidArgument, "cell-bound"));
        }
        Ok(json!({"utf8":self}))
    }
    fn decode(value: &Value, bound: usize) -> Result<Self> {
        let text = string(field(value, "utf8")?, "utf8-cell")?;
        if text.len() > bound {
            return Err(Error::new(ErrorKind::IncompatibleNative, "cell-bound"));
        }
        Ok(text.to_owned())
    }
}
impl TableValue for Vec<u8> {
    const KIND: CellType = CellType::Binary;
    fn encode(&self, bound: usize) -> Result<Value> {
        Ok(json!({"binary":hex(self,bound)?}))
    }
    fn decode(value: &Value, bound: usize) -> Result<Self> {
        unhex(string(field(value, "binary")?, "binary-cell")?, bound)
    }
}
#[derive(Clone, Debug)]
pub struct TableSchema<C: TableValue> {
    pub(crate) id: u32,
    key_name: String,
    value_name: String,
    _value: PhantomData<fn() -> C>,
}
impl<C: TableValue> TableSchema<C> {
    pub fn new(id: u32) -> Result<Self> {
        if id == 0 {
            return Err(Error::new(ErrorKind::InvalidArgument, "table-id"));
        }
        Ok(Self {
            id,
            key_name: "id".into(),
            value_name: "value".into(),
            _value: PhantomData,
        })
    }
    pub fn named(mut self, key: &str, value: &str) -> Result<Self> {
        if key.is_empty()
            || value.is_empty()
            || key.len() > VALUE_BYTES
            || value.len() > VALUE_BYTES
        {
            return Err(Error::new(ErrorKind::InvalidArgument, "table-names"));
        }
        self.key_name = key.into();
        self.value_name = value.into();
        Ok(self)
    }
    pub fn id(&self) -> u32 {
        self.id
    }
    pub fn value_type(&self) -> CellType {
        C::KIND
    }
}
impl TableSchema<i64> {
    pub fn int64(id: u32) -> Result<Self> {
        Self::new(id)
    }
}
impl TableSchema<bool> {
    pub fn boolean(id: u32) -> Result<Self> {
        Self::new(id)
    }
}
impl TableSchema<String> {
    pub fn utf8(id: u32) -> Result<Self> {
        Self::new(id)
    }
}
impl TableSchema<Vec<u8>> {
    pub fn binary(id: u32) -> Result<Self> {
        Self::new(id)
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Row<C> {
    pub key: i64,
    pub value: Option<C>,
}
pub struct Table<'a, C: TableValue> {
    owner: &'a mut dyn Access,
    schema: TableSchema<C>,
    basis: Basis,
    retained: Option<ReadVersion>,
}
impl<'a, C: TableValue> Table<'a, C> {
    pub(crate) fn capture(
        owner: &'a mut dyn Access,
        schema: &TableSchema<C>,
        retained: Option<ReadVersion>,
    ) -> Result<Self> {
        let value = owner.apply(
            json!({"table_schema":{"id":schema.id,"version":retained.map(version)}}),
            true,
        )?;
        let value = field(&value, "schema")?;
        if value["id"] != schema.id
            || value["key_name"] != schema.key_name
            || value["value_name"] != schema.value_name
            || value["value_type"] != C::KIND.native()
        {
            return Err(Error::new(ErrorKind::Handler, "captured-table-schema"));
        }
        let basis = basis(&value["basis"], owner.process().realm())?;
        Ok(Self {
            owner,
            schema: schema.clone(),
            basis,
            retained,
        })
    }
    pub fn schema(&self) -> &TableSchema<C> {
        &self.schema
    }
    pub fn basis(&self) -> &Basis {
        &self.basis
    }
    fn row(&self, value: &Value) -> Result<Row<C>> {
        let cell = field(value, "value")?;
        let decoded = if cell.get("null").is_some() {
            None
        } else {
            Some(C::decode(cell, self.owner.caps().cell)?)
        };
        Ok(Row {
            key: signed(&value["key"])?,
            value: decoded,
        })
    }
    pub fn get(&mut self, key: i64) -> Result<Option<Row<C>>> {
        let action = if let Some(version_id) = self.retained {
            json!({"version_table_get":{"version":version(version_id),"id":self.schema.id,"key":key.to_string()}})
        } else {
            json!({"table_get":{"id":self.schema.id,"key":key.to_string()}})
        };
        let value = self.owner.apply(action, true)?;
        let value = field(&value, "row")?;
        if value.is_null() {
            Ok(None)
        } else {
            self.row(value).map(Some)
        }
    }
    fn writable(&self) -> Result<()> {
        self.owner.check()?;
        if self.retained.is_some() {
            return Err(Error::new(ErrorKind::Handler, "retained-table-write"));
        }
        Ok(())
    }
    fn write(&mut self, mode: &str, row: &Row<C>) -> Result<()> {
        self.writable()?;
        let cell = match &row.value {
            Some(value) => value.encode(self.owner.caps().cell)?,
            None => json!({"null":{}}),
        };
        self.owner.apply(json!({"table_write":{"id":self.schema.id,"mode":mode,"row":{"key":row.key.to_string(),"value":cell}}}), false).map(|_| ())
    }
    pub fn insert(&mut self, row: &Row<C>) -> Result<()> {
        self.write("insert", row)
    }
    pub fn update(&mut self, row: &Row<C>) -> Result<()> {
        self.write("update", row)
    }
    pub fn upsert(&mut self, row: &Row<C>) -> Result<()> {
        self.write("upsert", row)
    }
    pub fn delete(&mut self, key: i64) -> Result<()> {
        self.writable()?;
        self.owner
            .apply(
                json!({"table_delete":{"id":self.schema.id,"key":key.to_string()}}),
                false,
            )
            .map(|_| ())
    }
    pub fn page(&mut self, after: Option<&Cursor>) -> Result<Page<Row<C>>> {
        let value = self.owner.apply(json!({"table_page":{"id":self.schema.id,"version":self.retained.map(version),"cursor":cursor(after)}}), true)?;
        let page = field(&value, "rows")?;
        let values = page["rows"]
            .as_array()
            .filter(|items| items.len() <= self.owner.caps().page)
            .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "table-page-bound"))?;
        let entries = values
            .iter()
            .filter(|value| !value.is_null())
            .map(|value| self.row(value))
            .collect::<Result<_>>()?;
        Ok(Page {
            entries,
            next: next(&page["next"])?,
            basis: Some(basis(&page["basis"], self.owner.process().realm())?),
        })
    }
}
impl Turn<'_> {
    pub fn table<C: TableValue>(&mut self, schema: &TableSchema<C>) -> Result<Table<'_, C>> {
        Table::capture(self, schema, None)
    }
    pub fn create_table<C: TableValue>(&mut self, schema: &TableSchema<C>) -> Result<Table<'_, C>> {
        if schema.key_name.len() > self.caps().name || schema.value_name.len() > self.caps().name {
            return Err(Error::new(ErrorKind::InvalidArgument, "table-name-bound"));
        }
        self.apply(json!({"table_create":{"id":schema.id,"key_name":schema.key_name,"value_name":schema.value_name,"value_type":C::KIND.native()}}), false)?;
        Table::capture(self, schema, None)
    }
}
impl Source<'_> {
    pub fn table<C: TableValue>(&mut self, schema: &TableSchema<C>) -> Result<Table<'_, C>> {
        Table::capture(self.owner, schema, Some(self.identity))
    }
}
