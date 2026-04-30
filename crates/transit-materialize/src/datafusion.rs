use crate::prolly::{LeafEntry, ProllyStore, ProllyTreeBuilder};
use datafusion::arrow::array::{ArrayRef, BinaryArray};
use datafusion::arrow::datatypes::{DataType, Field, Schema, SchemaRef};
use datafusion::arrow::record_batch::RecordBatch;
use datafusion::catalog::{Session, TableProvider};
use datafusion::common::{DataFusionError, Result as DataFusionResult};
use datafusion::datasource::memory::MemorySourceConfig;
use datafusion::logical_expr::{Expr, TableProviderFilterPushDown, TableType};
use datafusion::physical_plan::ExecutionPlan;
use std::any::Any;
use std::fmt;
use std::sync::Arc;
use transit_core::storage::ContentDigest;

/// DataFusion table adapter for a Prolly Tree root.
pub struct ProllyTable<S: ProllyStore + 'static> {
    store: Arc<S>,
    root_digest: ContentDigest,
    schema: SchemaRef,
}

impl<S: ProllyStore + 'static> ProllyTable<S> {
    pub fn new(store: Arc<S>, root_digest: ContentDigest) -> Self {
        Self {
            store,
            root_digest,
            schema: prolly_key_value_schema(),
        }
    }

    pub fn root_digest(&self) -> &ContentDigest {
        &self.root_digest
    }

    pub async fn record_batch(&self) -> DataFusionResult<RecordBatch> {
        let builder = ProllyTreeBuilder::new(self.store.as_ref());
        let entries = builder
            .entries(&self.root_digest)
            .await
            .map_err(to_datafusion_error)?;
        prolly_entries_to_record_batch(&entries)
    }
}

impl<S: ProllyStore + 'static> fmt::Debug for ProllyTable<S> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ProllyTable")
            .field("root_digest", &self.root_digest)
            .field("schema", &self.schema)
            .finish_non_exhaustive()
    }
}

#[async_trait::async_trait]
impl<S: ProllyStore + 'static> TableProvider for ProllyTable<S> {
    fn as_any(&self) -> &dyn Any {
        self
    }

    fn schema(&self) -> SchemaRef {
        Arc::clone(&self.schema)
    }

    fn table_type(&self) -> TableType {
        TableType::Base
    }

    async fn scan(
        &self,
        _state: &dyn Session,
        projection: Option<&Vec<usize>>,
        _filters: &[Expr],
        _limit: Option<usize>,
    ) -> DataFusionResult<Arc<dyn ExecutionPlan>> {
        let batch = self.record_batch().await?;
        let partitions = vec![vec![batch]];
        let plan: Arc<dyn ExecutionPlan> =
            MemorySourceConfig::try_new_exec(&partitions, self.schema(), projection.cloned())?;
        Ok(plan)
    }

    fn supports_filters_pushdown(
        &self,
        filters: &[&Expr],
    ) -> DataFusionResult<Vec<TableProviderFilterPushDown>> {
        Ok(vec![
            TableProviderFilterPushDown::Unsupported;
            filters.len()
        ])
    }
}

pub fn prolly_key_value_schema() -> SchemaRef {
    Arc::new(Schema::new(vec![
        Field::new("key", DataType::Binary, false),
        Field::new("value", DataType::Binary, false),
    ]))
}

pub fn prolly_entries_to_record_batch(entries: &[LeafEntry]) -> DataFusionResult<RecordBatch> {
    let keys = BinaryArray::from_iter_values(entries.iter().map(|entry| entry.key.as_slice()));
    let values = BinaryArray::from_iter_values(entries.iter().map(|entry| entry.value.as_slice()));
    RecordBatch::try_new(
        prolly_key_value_schema(),
        vec![Arc::new(keys) as ArrayRef, Arc::new(values) as ArrayRef],
    )
    .map_err(|error| DataFusionError::ArrowError(error, None))
}

fn to_datafusion_error(error: anyhow::Error) -> DataFusionError {
    DataFusionError::Execution(format!("{error:#}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::prolly::{MemoryProllyStore, ProllyTreeBuilder};

    fn entry(key: &str, value: &str) -> LeafEntry {
        LeafEntry {
            key: key.as_bytes().to_vec(),
            value: value.as_bytes().to_vec(),
        }
    }

    #[test]
    fn prolly_entries_map_to_arrow_record_batch() {
        let batch = prolly_entries_to_record_batch(&[entry("alpha", "1"), entry("beta", "2")])
            .expect("record batch");

        assert_eq!(batch.num_rows(), 2);
        assert_eq!(batch.num_columns(), 2);
        assert_eq!(batch.schema().field(0).name(), "key");
        assert_eq!(batch.schema().field(0).data_type(), &DataType::Binary);
        assert_eq!(batch.schema().field(1).name(), "value");
        assert_eq!(batch.schema().field(1).data_type(), &DataType::Binary);
    }

    #[tokio::test]
    async fn prolly_table_wraps_root_and_scans_with_table_provider() {
        let store = Arc::new(MemoryProllyStore::new());
        let builder = ProllyTreeBuilder::new(store.as_ref());
        let root = builder
            .build_from_entries(vec![entry("alpha", "1"), entry("beta", "2")])
            .await
            .expect("build root");
        let table = ProllyTable::new(Arc::clone(&store), root.clone());

        assert_eq!(table.root_digest(), &root);
        assert_eq!(table.schema().fields().len(), 2);

        let batch = table.record_batch().await.expect("record batch");
        assert_eq!(batch.num_rows(), 2);

        let plan = table
            .scan(
                &datafusion::execution::context::SessionContext::new().state(),
                None,
                &[],
                None,
            )
            .await
            .expect("scan");
        assert_eq!(plan.schema().fields().len(), 2);
    }
}
