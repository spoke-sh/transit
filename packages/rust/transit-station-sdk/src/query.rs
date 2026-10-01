use crate::{
    Basis, Cell, Counter, Origin, ReadVersion, Table, TableSchema, TableValue, Turn,
    bridge::{counter, digest, field, size, wide},
    turn::{Access, basis, read_version},
};
use serde_json::{Value, json};
use transit_client::internal::{number, string, unhex};
use transit_client::{Correlation, Error, ErrorKind, ProcessRef, Result};

#[derive(Clone, Copy, Debug, Default)]
pub enum Projection {
    #[default]
    Both,
    Key,
    Value,
}
#[derive(Clone, Copy, Debug, Default)]
pub enum Aggregate {
    #[default]
    Rows,
    Count,
    Sum,
    CountValues,
}
#[derive(Clone, Copy, Debug)]
pub enum Column {
    Key,
    Value,
}
#[derive(Clone, Copy, Debug)]
pub enum Comparison {
    Eq,
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
}
#[derive(Clone, Debug, Default)]
pub enum Predicate {
    #[default]
    All,
    IsNull(Column),
    Compare {
        column: Column,
        comparison: Comparison,
        value: Cell,
    },
}
#[derive(Clone, Debug, Default)]
pub struct QueryPlan {
    pub projection: Projection,
    pub aggregate: Aggregate,
    pub limit: Option<u64>,
    pub predicate: Predicate,
}
impl QueryPlan {
    fn wire(&self, bound: usize) -> Result<Value> {
        let column = |value: Column| match value {
            Column::Key => 0,
            Column::Value => 1,
        };
        let predicate = match &self.predicate {
            Predicate::All => json!({"all":{}}),
            Predicate::IsNull(value) => json!({"is_null":column(*value)}),
            Predicate::Compare {
                column: selected,
                comparison,
                value,
            } => json!({"compare":{"column":column(*selected),
                "op":match comparison { Comparison::Eq=>"eq", Comparison::Ne=>"ne", Comparison::Lt=>"lt", Comparison::Le=>"le", Comparison::Gt=>"gt", Comparison::Ge=>"ge" },
                "value":value.wire(bound)?}}),
        };
        Ok(
            json!({"projection":match self.projection { Projection::Both=>"both", Projection::Key=>"key", Projection::Value=>"value" },
            "aggregate":match self.aggregate { Aggregate::Rows=>"rows", Aggregate::Count=>"count", Aggregate::Sum=>"sum",Aggregate::CountValues=>"count_values" }, "limit":self.limit.map(|value|value.to_string()), "predicate":predicate}),
        )
    }
}
#[derive(Clone, Debug)]
pub struct QueryJob {
    pub result: Counter,
    pub correlation: Correlation,
    pub source: ReadVersion,
}
#[derive(Clone, Debug)]
pub struct ResultComplete {
    pub position: Counter,
    pub origin: Origin,
    pub correlation: Correlation,
}
#[derive(Clone, Debug)]
pub struct ResultManifest {
    pub result: Counter,
    pub source: ProcessRef,
    pub destination: ProcessRef,
    pub correlation: Correlation,
    pub table: u32,
    pub policy_revision: u64,
    pub basis: Basis,
    pub source_contract: [u8; 32],
    pub plan: [u8; 32],
    pub segments: u64,
    pub byte_count: u64,
    pub rows: u64,
    pub chain: [u8; 32],
    pub schema: [u8; 32],
}
#[derive(Clone)]
pub struct IpcSegment {
    pub manifest: ResultManifest,
    pub ordinal: u64,
    pub rows: u64,
    pub digest: [u8; 32],
    pub ipc: Box<[u8]>,
    bound: usize,
}
impl IpcSegment {
    /// Decode this bounded owned stream; its manifest carries completeness.
    #[cfg(feature = "arrow")]
    pub fn to_arrow(&self) -> Result<Vec<arrow_array::RecordBatch>> {
        if self.ipc.len() > self.bound {
            return Err(Error::new(ErrorKind::InvalidArgument, "ipc-bound"));
        }
        let invalid = |_| Error::new(ErrorKind::Codec, "arrow-ipc");
        let reader =
            arrow_ipc::reader::StreamReader::try_new(std::io::Cursor::new(&*self.ipc), None)
                .map_err(invalid)?;
        let batches = reader
            .collect::<std::result::Result<Vec<_>, _>>()
            .map_err(invalid)?;
        let rows = batches
            .iter()
            .try_fold(0u64, |sum, batch| sum.checked_add(batch.num_rows() as u64))
            .ok_or_else(|| Error::new(ErrorKind::Codec, "arrow-row-count"))?;
        if rows != self.rows {
            return Err(Error::new(ErrorKind::Codec, "arrow-row-count"));
        }
        Ok(batches)
    }
    pub fn byte_bound(&self) -> usize {
        self.bound
    }
}
impl std::fmt::Debug for IpcSegment {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("IpcSegment")
            .field("manifest", &self.manifest)
            .field("ordinal", &self.ordinal)
            .field("rows", &self.rows)
            .finish_non_exhaustive()
    }
}
pub struct ResultReader<'a> {
    owner: &'a mut dyn Access,
    correlation: Correlation,
}
impl ResultReader<'_> {
    pub fn correlation(&self) -> Correlation {
        self.correlation
    }
    pub fn manifest(&mut self) -> Result<ResultManifest> {
        let value = self.owner.apply(
            json!({"query_completed":self.correlation.get().to_string()}),
            true,
        )?;
        let value = field(&value, "manifest")?;
        let realm = self.owner.process().realm();
        Ok(ResultManifest {
            result: counter(&value["result"], false)?,
            source: ProcessRef::new(realm, number(&value["source"], "result-source", false)?)?,
            destination: ProcessRef::new(
                realm,
                number(&value["destination"], "result-destination", false)?,
            )?,
            correlation: Correlation::new(wide(&value["correlation"])?)?,
            table: u32::try_from(number(&value["table"], "result-table", false)?)
                .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "result-table"))?,
            policy_revision: wide(&value["policy_revision"])?,
            basis: basis(&value["basis"], realm)?,
            source_contract: digest(&value["basis"]["contract"])?,
            plan: digest(&value["plan"])?,
            segments: wide(&value["segments"])?,
            byte_count: wide(&value["bytes"])?,
            rows: wide(&value["rows"])?,
            chain: digest(&value["chain"])?,
            schema: digest(&value["schema"])?,
        })
    }
    pub fn segment(&mut self, ordinal: u64) -> Result<IpcSegment> {
        let manifest = self.manifest()?;
        let value = self.owner.apply(json!({"query_segment":{"correlation":self.correlation.get().to_string(),"ordinal":ordinal.to_string()}}), true)?;
        let value = field(&value, "segment")?;
        let ipc = unhex(
            string(&value["ipc"], "query-ipc")?,
            self.owner.caps().segment,
        )?
        .into_boxed_slice();
        if ipc.len() != size(&value["bytes"], true)? {
            return Err(Error::new(
                ErrorKind::IncompatibleNative,
                "query-segment-length",
            ));
        }
        Ok(IpcSegment {
            manifest,
            ordinal: wide(&value["ordinal"])?,
            rows: number(&value["rows"], "query-rows", true)?,
            digest: digest(&value["digest"])?,
            ipc,
            bound: self.owner.caps().segment,
        })
    }
}
#[derive(Clone, Copy, Debug)]
pub enum QueryCloseReason {
    Cancelled,
    Denied,
}
impl Turn<'_> {
    pub fn allow_query<C: TableValue>(
        &mut self,
        peer: ProcessRef,
        schema: &TableSchema<C>,
        expected_revision: Counter,
        allow: bool,
    ) -> Result<()> {
        self.check()?;
        if peer.realm() != self.process().realm() {
            return Err(Error::new(ErrorKind::InvalidArgument, "query-peer-realm"));
        }
        self.apply(json!({"query_policy":{"peer":peer.pid(),"table":schema.id(),"expected_revision":expected_revision.get(),"allow":allow}}), false).map(|_| ())
    }
    pub fn start_query<C: TableValue>(
        &mut self,
        schema: &TableSchema<C>,
        plan: &QueryPlan,
    ) -> Result<QueryJob> {
        Table::capture(self, schema, None)?;
        let value = self.apply(
            json!({"query_start":{"id":schema.id(),"plan":plan.wire(self.caps().cell)?}}),
            false,
        )?;
        let value = field(&value, "query")?;
        Ok(QueryJob {
            result: counter(&value["result"], false)?,
            correlation: Correlation::new(wide(&value["correlation"])?)?,
            source: read_version(&value["source"])?,
        })
    }
    pub fn close_query(&mut self, result: Counter, reason: QueryCloseReason) -> Result<()> {
        self.apply(json!({"query_close":{"result":result.get(),"reason":match reason { QueryCloseReason::Cancelled=>"cancelled", QueryCloseReason::Denied=>"denied" }}}), false).map(|_| ())
    }
    pub fn result(&mut self, correlation: Correlation) -> Result<ResultReader<'_>> {
        self.check()?;
        Ok(ResultReader {
            owner: self,
            correlation,
        })
    }
}
