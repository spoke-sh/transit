use crate::prolly::{LeafEntry, ProllyStore, ProllyTreeBuilder};
use datafusion::arrow::array::{ArrayRef, BinaryArray};
use datafusion::arrow::datatypes::{DataType, Field, Schema, SchemaRef};
use datafusion::arrow::record_batch::RecordBatch;
use datafusion::catalog::{CatalogProvider, SchemaProvider, Session, TableProvider};
use datafusion::common::{DataFusionError, Result as DataFusionResult};
use datafusion::datasource::memory::MemorySourceConfig;
use datafusion::logical_expr::{Expr, TableProviderFilterPushDown, TableType};
use datafusion::physical_plan::ExecutionPlan;
use std::any::Any;
use std::collections::BTreeMap;
use std::fmt;
use std::sync::Arc;
use std::sync::RwLock;
use transit_core::storage::ContentDigest;

/// DataFusion table adapter for a Prolly Tree root.
pub struct ProllyTable<S: ProllyStore + 'static> {
    store: Arc<S>,
    root_digest: ContentDigest,
    schema: SchemaRef,
}

/// DataFusion schema provider for a collection of Prolly-backed tables.
pub struct ProllySchema {
    tables: RwLock<BTreeMap<String, Arc<dyn TableProvider>>>,
}

/// DataFusion catalog provider for named Prolly schemas.
pub struct ProllyCatalog {
    schemas: RwLock<BTreeMap<String, Arc<dyn SchemaProvider>>>,
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

impl ProllySchema {
    pub fn new() -> Self {
        Self {
            tables: RwLock::new(BTreeMap::new()),
        }
    }

    pub fn with_table(name: impl Into<String>, table: Arc<dyn TableProvider>) -> Self {
        let schema = Self::new();
        schema
            .register_table(name.into(), table)
            .expect("new schema should accept first table");
        schema
    }
}

impl Default for ProllySchema {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Debug for ProllySchema {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ProllySchema")
            .field("table_names", &self.table_names())
            .finish()
    }
}

#[async_trait::async_trait]
impl SchemaProvider for ProllySchema {
    fn as_any(&self) -> &dyn Any {
        self
    }

    fn table_names(&self) -> Vec<String> {
        self.tables
            .read()
            .expect("prolly schema lock poisoned")
            .keys()
            .cloned()
            .collect()
    }

    async fn table(&self, name: &str) -> DataFusionResult<Option<Arc<dyn TableProvider>>> {
        Ok(self
            .tables
            .read()
            .expect("prolly schema lock poisoned")
            .get(name)
            .cloned())
    }

    fn register_table(
        &self,
        name: String,
        table: Arc<dyn TableProvider>,
    ) -> DataFusionResult<Option<Arc<dyn TableProvider>>> {
        let mut tables = self.tables.write().expect("prolly schema lock poisoned");
        if tables.contains_key(&name) {
            return Err(DataFusionError::Execution(format!(
                "prolly table '{name}' already exists"
            )));
        }
        Ok(tables.insert(name, table))
    }

    fn deregister_table(&self, name: &str) -> DataFusionResult<Option<Arc<dyn TableProvider>>> {
        Ok(self
            .tables
            .write()
            .expect("prolly schema lock poisoned")
            .remove(name))
    }

    fn table_exist(&self, name: &str) -> bool {
        self.tables
            .read()
            .expect("prolly schema lock poisoned")
            .contains_key(name)
    }
}

impl ProllyCatalog {
    pub fn new() -> Self {
        Self {
            schemas: RwLock::new(BTreeMap::new()),
        }
    }

    pub fn with_schema(name: impl Into<String>, schema: Arc<dyn SchemaProvider>) -> Self {
        let catalog = Self::new();
        let name = name.into();
        catalog
            .register_schema(&name, schema)
            .expect("new catalog should accept first schema");
        catalog
    }
}

impl Default for ProllyCatalog {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Debug for ProllyCatalog {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ProllyCatalog")
            .field("schema_names", &self.schema_names())
            .finish()
    }
}

impl CatalogProvider for ProllyCatalog {
    fn as_any(&self) -> &dyn Any {
        self
    }

    fn schema_names(&self) -> Vec<String> {
        self.schemas
            .read()
            .expect("prolly catalog lock poisoned")
            .keys()
            .cloned()
            .collect()
    }

    fn schema(&self, name: &str) -> Option<Arc<dyn SchemaProvider>> {
        self.schemas
            .read()
            .expect("prolly catalog lock poisoned")
            .get(name)
            .cloned()
    }

    fn register_schema(
        &self,
        name: &str,
        schema: Arc<dyn SchemaProvider>,
    ) -> DataFusionResult<Option<Arc<dyn SchemaProvider>>> {
        Ok(self
            .schemas
            .write()
            .expect("prolly catalog lock poisoned")
            .insert(name.to_owned(), schema))
    }

    fn deregister_schema(
        &self,
        name: &str,
        _cascade: bool,
    ) -> DataFusionResult<Option<Arc<dyn SchemaProvider>>> {
        Ok(self
            .schemas
            .write()
            .expect("prolly catalog lock poisoned")
            .remove(name))
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
    use datafusion::arrow::array::{Array, ArrayRef, BinaryArray};

    fn entry(key: &str, value: &str) -> LeafEntry {
        LeafEntry {
            key: key.as_bytes().to_vec(),
            value: value.as_bytes().to_vec(),
        }
    }

    fn binary_values(column: &ArrayRef) -> Vec<Vec<u8>> {
        let array = column
            .as_any()
            .downcast_ref::<BinaryArray>()
            .expect("binary column");
        (0..array.len())
            .map(|index| array.value(index).to_vec())
            .collect()
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

    #[tokio::test]
    async fn prolly_schema_manages_prolly_tables() {
        let store = Arc::new(MemoryProllyStore::new());
        let builder = ProllyTreeBuilder::new(store.as_ref());
        let root = builder
            .build_from_entries(vec![entry("alpha", "1")])
            .await
            .expect("build root");
        let table = Arc::new(ProllyTable::new(Arc::clone(&store), root));
        let schema = ProllySchema::new();

        schema
            .register_table("tasks".to_owned(), table)
            .expect("register table");

        assert_eq!(schema.table_names(), vec!["tasks".to_owned()]);
        assert!(schema.table_exist("tasks"));
        assert!(schema.table("tasks").await.expect("lookup table").is_some());
        assert!(
            schema
                .table("missing")
                .await
                .expect("lookup missing")
                .is_none()
        );
    }

    #[test]
    fn prolly_catalog_manages_schemas() {
        let schema = Arc::new(ProllySchema::new());
        let catalog = ProllyCatalog::new();

        catalog
            .register_schema("public", schema)
            .expect("register schema");

        assert_eq!(catalog.schema_names(), vec!["public".to_owned()]);
        assert!(catalog.schema("public").is_some());
        assert!(catalog.schema("missing").is_none());
    }

    #[tokio::test]
    async fn datafusion_resolves_prolly_table_through_catalog() {
        let store = Arc::new(MemoryProllyStore::new());
        let builder = ProllyTreeBuilder::new(store.as_ref());
        let root = builder
            .build_from_entries(vec![entry("alpha", "1"), entry("beta", "2")])
            .await
            .expect("build root");
        let table = Arc::new(ProllyTable::new(Arc::clone(&store), root));
        let schema = Arc::new(ProllySchema::with_table("tasks", table));
        let catalog = Arc::new(ProllyCatalog::with_schema("public", schema));

        let ctx = datafusion::execution::context::SessionContext::new();
        ctx.register_catalog("transit", catalog);
        let batches = ctx
            .sql("SELECT COUNT(*) AS count FROM transit.public.tasks")
            .await
            .expect("plan sql")
            .collect()
            .await
            .expect("collect sql");

        assert_eq!(batches.len(), 1);
        assert_eq!(batches[0].num_rows(), 1);
    }

    #[tokio::test]
    async fn datafusion_select_star_reads_prolly_tree() {
        let store = Arc::new(MemoryProllyStore::new());
        let builder = ProllyTreeBuilder::new(store.as_ref());
        let root = builder
            .build_from_entries(vec![entry("beta", "2"), entry("alpha", "1")])
            .await
            .expect("build root");
        let table = Arc::new(ProllyTable::new(Arc::clone(&store), root));
        let ctx = datafusion::execution::context::SessionContext::new();
        ctx.register_table("tasks", table).expect("register table");

        let batches = ctx
            .sql("SELECT * FROM tasks")
            .await
            .expect("plan select")
            .collect()
            .await
            .expect("collect select");

        assert_eq!(batches.len(), 1);
        assert_eq!(batches[0].num_rows(), 2);
        assert_eq!(
            binary_values(batches[0].column(0)),
            vec![b"alpha".to_vec(), b"beta".to_vec()]
        );
        assert_eq!(
            binary_values(batches[0].column(1)),
            vec![b"1".to_vec(), b"2".to_vec()]
        );
    }

    #[tokio::test]
    async fn datafusion_query_preserves_prolly_arrow_binary_values() {
        let store = Arc::new(MemoryProllyStore::new());
        let builder = ProllyTreeBuilder::new(store.as_ref());
        let root = builder
            .build_from_entries(vec![entry("payload", "bytes")])
            .await
            .expect("build root");
        let table = Arc::new(ProllyTable::new(Arc::clone(&store), root));
        let ctx = datafusion::execution::context::SessionContext::new();
        ctx.register_table("tasks", table).expect("register table");

        let batches = ctx
            .sql("SELECT key, value FROM tasks")
            .await
            .expect("plan select")
            .collect()
            .await
            .expect("collect select");
        let batch = &batches[0];

        assert_eq!(batch.schema().field(0).data_type(), &DataType::Binary);
        assert_eq!(batch.schema().field(1).data_type(), &DataType::Binary);
        assert_eq!(binary_values(batch.column(0)), vec![b"payload".to_vec()]);
        assert_eq!(binary_values(batch.column(1)), vec![b"bytes".to_vec()]);
    }
}
