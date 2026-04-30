use crate::Reducer;
use crate::datafusion::{ProllyCatalog, ProllySchema, ProllyTable};
use crate::prolly::{ProllyStore, ProllyTreeBuilder};
use anyhow::{Context, Result, bail, ensure};
use datafusion::arrow::array::{Array, BinaryArray};
use datafusion::arrow::record_batch::RecordBatch;
use datafusion::catalog::{CatalogProvider, SchemaProvider, TableProvider};
use datafusion::execution::context::SessionContext;
use datafusion::sql::parser::{DFParser, Statement as DataFusionStatement};
use datafusion::sql::sqlparser::ast::{
    Expr, ObjectName, SetExpr, Statement as SqlStatement, TableObject, Value,
};
use std::collections::{BTreeMap, VecDeque};
use std::future::Future;
use std::sync::Arc;
use transit_core::kernel::Offset;
use transit_core::storage::ContentDigest;

pub const DEFAULT_SQL_CATALOG: &str = "transit";
pub const DEFAULT_SQL_SCHEMA: &str = "public";

/// Serializable SQL materialization state keyed by logical table name.
#[derive(Debug, Clone, Default, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct SqlMaterializerState {
    table_roots: BTreeMap<String, ContentDigest>,
}

impl SqlMaterializerState {
    pub fn table_root(&self, table_name: &str) -> Option<&ContentDigest> {
        self.table_roots.get(table_name)
    }

    pub fn table_roots(&self) -> &BTreeMap<String, ContentDigest> {
        &self.table_roots
    }

    fn set_table_root(&mut self, table_name: String, root_digest: ContentDigest) {
        self.table_roots.insert(table_name, root_digest);
    }
}

/// Reducer that applies SQL DML stream records into Prolly-backed table roots.
pub struct SqlMaterializer<S: ProllyStore + 'static> {
    store: Arc<S>,
    catalog_name: String,
    schema_name: String,
}

pub type SqlReducer<S> = SqlMaterializer<S>;

#[derive(Debug, Clone, PartialEq, Eq)]
struct InsertCommand {
    table_name: String,
    rows: Vec<InsertRow>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct InsertRow {
    key: Vec<u8>,
    value: Vec<u8>,
}

impl<S: ProllyStore + 'static> SqlMaterializer<S> {
    pub fn new(store: Arc<S>) -> Self {
        Self::with_catalog(store, DEFAULT_SQL_CATALOG, DEFAULT_SQL_SCHEMA)
    }

    pub fn with_catalog(
        store: Arc<S>,
        catalog_name: impl Into<String>,
        schema_name: impl Into<String>,
    ) -> Self {
        Self {
            store,
            catalog_name: catalog_name.into(),
            schema_name: schema_name.into(),
        }
    }

    pub fn catalog_name(&self) -> &str {
        &self.catalog_name
    }

    pub fn schema_name(&self) -> &str {
        &self.schema_name
    }

    pub fn session_context(&self, state: &SqlMaterializerState) -> Result<SessionContext> {
        let context = SessionContext::new();
        let schema = Arc::new(ProllySchema::new());

        for (table_name, root_digest) in state.table_roots() {
            let table: Arc<dyn TableProvider> = Arc::new(ProllyTable::new(
                Arc::clone(&self.store),
                root_digest.clone(),
            ));
            schema
                .register_table(table_name.clone(), table)
                .with_context(|| format!("register prolly table '{table_name}'"))?;
        }

        let schema_provider: Arc<dyn SchemaProvider> = schema;
        let catalog: Arc<dyn CatalogProvider> = Arc::new(ProllyCatalog::with_schema(
            self.schema_name.clone(),
            schema_provider,
        ));
        context.register_catalog(self.catalog_name.clone(), catalog);
        Ok(context)
    }

    pub async fn query(&self, state: &SqlMaterializerState, sql: &str) -> Result<Vec<RecordBatch>> {
        let context = self.session_context(state)?;
        let frame = context.sql(sql).await.context("plan SQL query")?;
        frame.collect().await.context("execute SQL query")
    }

    pub async fn query_key_values(
        &self,
        state: &SqlMaterializerState,
        sql: &str,
    ) -> Result<Vec<crate::prolly::LeafEntry>> {
        let batches = self.query(state, sql).await?;
        key_value_rows_from_record_batches(&batches)
    }

    fn apply_insert(&self, state: &mut SqlMaterializerState, command: InsertCommand) -> Result<()> {
        let store = Arc::clone(&self.store);
        let current_root = state.table_root(&command.table_name).cloned();
        let table_name = command.table_name;

        let new_root = block_on_dedicated_runtime(async move {
            let builder = ProllyTreeBuilder::new(store.as_ref());
            let mut root = match current_root {
                Some(root) => root,
                None => builder
                    .build_from_entries(Vec::new())
                    .await
                    .context("build empty Prolly table root")?,
            };

            for row in command.rows {
                root = builder
                    .insert(&root, row.key, row.value)
                    .await
                    .context("insert SQL row into Prolly tree")?;
            }

            Ok(root)
        })?;

        state.set_table_root(table_name, new_root);
        self.session_context(state)?;
        Ok(())
    }
}

impl<S: ProllyStore + 'static> Reducer for SqlMaterializer<S> {
    type State = SqlMaterializerState;

    fn reduce(&self, state: &mut Self::State, _offset: Offset, payload: &[u8]) -> Result<()> {
        let sql = std::str::from_utf8(payload).context("SQL materializer payload is not UTF-8")?;
        let command = parse_insert_command(sql)?;
        self.apply_insert(state, command)
    }
}

fn parse_insert_command(sql: &str) -> Result<InsertCommand> {
    let mut statements =
        DFParser::parse_sql(sql).with_context(|| format!("parse SQL payload '{sql}'"))?;
    ensure!(
        statements.len() == 1,
        "SQL materializer payload must contain exactly one statement"
    );

    match statements
        .pop_front()
        .expect("statement count was checked to be one")
    {
        DataFusionStatement::Statement(statement) => match *statement {
            SqlStatement::Insert(insert) => {
                ensure!(
                    !insert.overwrite && !insert.ignore && !insert.replace_into,
                    "SQL materializer supports plain INSERT statements only"
                );
                ensure!(
                    insert.assignments.is_empty()
                        && insert.partitioned.is_none()
                        && insert.after_columns.is_empty()
                        && insert.on.is_none()
                        && insert.returning.is_none(),
                    "SQL materializer supports INSERT ... VALUES only"
                );

                let table_name = table_name_from_object(insert.table)?;
                let source = insert.source.context("INSERT must provide VALUES")?;
                let rows = rows_from_insert_source(*source.body, &insert.columns)?;
                Ok(InsertCommand { table_name, rows })
            }
            other => bail!("SQL materializer supports INSERT statements only, found {other}"),
        },
        other => bail!("SQL materializer does not support DataFusion extension statement {other}"),
    }
}

fn table_name_from_object(table: TableObject) -> Result<String> {
    match table {
        TableObject::TableName(name) => table_name_from_object_name(name),
        TableObject::TableFunction(_) => bail!("INSERT table functions are not supported"),
    }
}

fn table_name_from_object_name(name: ObjectName) -> Result<String> {
    name.0
        .last()
        .and_then(|part| part.as_ident())
        .map(|ident| ident.value.clone())
        .context("INSERT table name is empty")
}

fn rows_from_insert_source(
    body: SetExpr,
    columns: &[datafusion::sql::sqlparser::ast::Ident],
) -> Result<Vec<InsertRow>> {
    let SetExpr::Values(values) = body else {
        bail!("SQL materializer supports INSERT ... VALUES only");
    };

    ensure!(
        !values.rows.is_empty(),
        "INSERT must include at least one VALUES row"
    );

    values
        .rows
        .into_iter()
        .map(|row| row_from_values(row, columns))
        .collect()
}

fn row_from_values(
    row: Vec<Expr>,
    columns: &[datafusion::sql::sqlparser::ast::Ident],
) -> Result<InsertRow> {
    if columns.is_empty() {
        ensure!(
            row.len() == 2,
            "INSERT without a column list must provide key and value"
        );
        return Ok(InsertRow {
            key: bytes_from_expr(&row[0])?,
            value: bytes_from_expr(&row[1])?,
        });
    }

    ensure!(
        row.len() == columns.len(),
        "INSERT column list length must match VALUES row length"
    );

    let mut key = None;
    let mut value = None;
    let mut pairs: VecDeque<_> = columns.iter().zip(row.iter()).collect();
    while let Some((column, expr)) = pairs.pop_front() {
        match column.value.to_ascii_lowercase().as_str() {
            "key" => key = Some(bytes_from_expr(expr)?),
            "value" => value = Some(bytes_from_expr(expr)?),
            other => bail!("unsupported SQL materializer column '{other}'"),
        }
    }

    Ok(InsertRow {
        key: key.context("INSERT column list must include key")?,
        value: value.context("INSERT column list must include value")?,
    })
}

fn bytes_from_expr(expr: &Expr) -> Result<Vec<u8>> {
    match expr {
        Expr::Value(value) => bytes_from_value(&value.value),
        Expr::TypedString { value, .. } => bytes_from_value(value),
        Expr::IntroducedString { value, .. } => bytes_from_value(value),
        Expr::Nested(expr) => bytes_from_expr(expr),
        other => bail!("unsupported SQL materializer value expression {other}"),
    }
}

fn bytes_from_value(value: &Value) -> Result<Vec<u8>> {
    if let Some(value) = value.clone().into_string() {
        return Ok(value.into_bytes());
    }

    match value {
        Value::Number(number, _) => Ok(number.to_string().into_bytes()),
        Value::Boolean(value) => Ok(value.to_string().into_bytes()),
        Value::Null => bail!("SQL materializer values cannot be NULL"),
        other => bail!("unsupported SQL materializer literal {other}"),
    }
}

fn key_value_rows_from_record_batches(
    batches: &[RecordBatch],
) -> Result<Vec<crate::prolly::LeafEntry>> {
    let mut rows = Vec::new();

    for batch in batches {
        ensure!(
            batch.num_columns() >= 2,
            "SQL key/value query must return at least two columns"
        );
        let keys = batch
            .column(0)
            .as_any()
            .downcast_ref::<BinaryArray>()
            .context("SQL key/value query key column must be Binary")?;
        let values = batch
            .column(1)
            .as_any()
            .downcast_ref::<BinaryArray>()
            .context("SQL key/value query value column must be Binary")?;
        ensure!(
            keys.len() == values.len(),
            "SQL key/value query returned mismatched key/value lengths"
        );

        for index in 0..keys.len() {
            rows.push(crate::prolly::LeafEntry {
                key: keys.value(index).to_vec(),
                value: values.value(index).to_vec(),
            });
        }
    }

    Ok(rows)
}

fn block_on_dedicated_runtime<F, T>(future: F) -> Result<T>
where
    F: Future<Output = Result<T>> + Send + 'static,
    T: Send + 'static,
{
    let handle = std::thread::spawn(move || {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .context("build SQL materializer runtime")?;
        runtime.block_on(future)
    });

    handle
        .join()
        .map_err(|error| anyhow::anyhow!("SQL materializer runtime thread panicked: {error:?}"))?
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::prolly::MemoryProllyStore;

    fn binary_values(batch: &RecordBatch, column_index: usize) -> Vec<Vec<u8>> {
        let array = batch
            .column(column_index)
            .as_any()
            .downcast_ref::<BinaryArray>()
            .expect("binary column");
        (0..array.len())
            .map(|index| array.value(index).to_vec())
            .collect()
    }

    fn reduce_with_trait<R: Reducer>(
        reducer: &R,
        state: &mut R::State,
        payload: &[u8],
    ) -> Result<()> {
        reducer.reduce(state, Offset::new(0), payload)
    }

    #[tokio::test]
    async fn sql_materializer_implements_reducer_and_inserts_rows() {
        let store = Arc::new(MemoryProllyStore::new());
        let reducer = SqlMaterializer::new(Arc::clone(&store));
        let mut state = SqlMaterializerState::default();

        reduce_with_trait(
            &reducer,
            &mut state,
            b"INSERT INTO tasks (key, value) VALUES ('alpha', '1')",
        )
        .expect("reduce");

        let root = state.table_root("tasks").expect("tasks root");
        let builder = ProllyTreeBuilder::new(store.as_ref());
        assert_eq!(
            builder.lookup(root, b"alpha").await.expect("lookup"),
            Some(b"1".to_vec())
        );
    }

    #[tokio::test]
    async fn sql_materializer_registers_prolly_catalog_for_queries() {
        let store = Arc::new(MemoryProllyStore::new());
        let reducer = SqlMaterializer::new(Arc::clone(&store));
        let mut state = SqlMaterializerState::default();

        reducer
            .reduce(
                &mut state,
                Offset::new(0),
                b"INSERT INTO tasks VALUES ('alpha', '1'), ('beta', '2')",
            )
            .expect("reduce");

        let context = reducer.session_context(&state).expect("context");
        assert!(
            context
                .catalog_names()
                .contains(&DEFAULT_SQL_CATALOG.to_owned())
        );

        let batches = reducer
            .query(&state, "SELECT key, value FROM transit.public.tasks")
            .await
            .expect("query");

        assert_eq!(batches.len(), 1);
        assert_eq!(
            binary_values(&batches[0], 0),
            vec![b"alpha".to_vec(), b"beta".to_vec()]
        );
        assert_eq!(
            binary_values(&batches[0], 1),
            vec![b"1".to_vec(), b"2".to_vec()]
        );
    }
}
