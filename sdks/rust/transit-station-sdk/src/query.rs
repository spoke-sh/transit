use crate::{
    Counter, Origin, ReadVersion, TableBasis, Turn,
    bridge::{counter, digest, field, size, wide},
    turn::{Access, read_version},
};
use serde_json::{Value, json};
use transit_client::internal::{number, string, unhex};
use transit_client::{Correlation, Error, ErrorKind, ProcessRef, ResourceRef, Result};

#[derive(Clone, Copy, Debug, Default)]
pub enum Aggregate {
    #[default]
    Rows,
    Count,
    Sum,
    CountValues,
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
#[derive(Clone, Debug)]
pub struct QueryPlan {
    value: Value,
}
impl QueryPlan {
    pub fn new(plan: &crate::unified::Plan) -> Result<Self> {
        Ok(Self {
            value: plan.wire()?,
        })
    }
}
#[derive(Clone, Debug)]
pub struct QueryJob {
    pub result: Counter,
    pub correlation: Correlation,
    pub source: ReadVersion,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QueryFailureReason {
    ResultTooLarge,
    WorkspaceExceeded,
    Overflow,
    Cancelled,
    Denied,
}
impl QueryFailureReason {
    pub(crate) fn decode(value: &Value) -> Result<Self> {
        Ok(match string(value, "query-failure-reason")? {
            "result_too_large" => Self::ResultTooLarge,
            "workspace_exceeded" => Self::WorkspaceExceeded,
            "overflow" => Self::Overflow,
            "cancelled" => Self::Cancelled,
            "denied" => Self::Denied,
            _ => {
                return Err(Error::new(
                    ErrorKind::IncompatibleNative,
                    "query-failure-reason",
                ));
            }
        })
    }
}
#[derive(Clone, Debug)]
pub struct QueryFailure {
    pub position: Counter,
    pub origin: Origin,
    pub correlation: Correlation,
    pub result: Counter,
    pub reason: QueryFailureReason,
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
    pub table: u64,
    pub policy_revision: u64,
    pub basis: TableBasis,
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
            table: wide(&value["table"])?,
            policy_revision: wide(&value["policy_revision"])?,
            basis: TableBasis {
                resource: ResourceRef::new(
                    realm,
                    number(&value["basis"]["resource"], "resource", false)?,
                )?,
                revision: counter(&value["basis"]["revision"], false)?,
                object: wide(&value["table"])?,
                head: digest(&value["basis"]["head"])?,
            },
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
    pub fn allow_query(
        &mut self,
        peer: ProcessRef,
        object: u64,
        expected_revision: u64,
        allow: bool,
    ) -> Result<()> {
        self.check()?;
        if peer.realm() != self.process().realm() || object == 0 {
            return Err(Error::new(ErrorKind::InvalidArgument, "query-peer-table"));
        }
        self.apply(json!({"query_policy":{"peer":peer.pid(),"table":object.to_string(),"expected_revision":expected_revision.to_string(),"allow":allow}}),false).map(|_|())
    }
    pub fn start_query(&mut self, object: u64, plan: &QueryPlan) -> Result<QueryJob> {
        if object == 0 {
            return Err(Error::new(ErrorKind::InvalidArgument, "query-table"));
        }
        let value = self.apply(
            json!({"query_start":{"id":object.to_string(),"plan":plan.value.clone()}}),
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::logical::Atom;
    use crate::unified::{Plan, Predicate};
    #[test]
    fn general_query_plan_captures_projection_names_and_exact_predicate() {
        let mut input = Plan {
            projection: vec![3, 0, 2],
            output_names: Some(vec![
                Some("tags".into()),
                Some("identity".into()),
                Some("amount".into()),
            ]),
            predicate: Predicate::Compare {
                column: 2,
                comparison: Comparison::Ge,
                value: Atom::Decimal(12345),
            },
            limit: Some(u64::MAX),
            aggregate: Aggregate::Rows,
        };
        let captured = QueryPlan::new(&input).unwrap();
        input.projection[0] = 1;
        assert_eq!(captured.value["projection"], json!([3, 0, 2]));
        assert_eq!(
            captured.value["predicate"]["compare"]["value"],
            json!({"decimal":"12345"})
        );
        assert_eq!(captured.value["limit"], u64::MAX.to_string());
        input.projection = (0..128).collect();
        input.output_names = None;
        assert_eq!(
            QueryPlan::new(&input).unwrap().value["projection"]
                .as_array()
                .unwrap()
                .len(),
            128
        );
        input.projection.push(128);
        assert!(QueryPlan::new(&input).is_err());
    }
}
