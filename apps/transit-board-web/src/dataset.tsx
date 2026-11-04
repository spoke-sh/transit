import { WorkbenchScope } from "./workbench-layout";
import { useEffect, useId, useState } from "react";
import { Link } from "@tanstack/react-router";
import { DataCatalog } from "@transit/board-client/catalog";
import { type CatalogTable, type CatalogDependencies } from "@transit/board-client";
import { logicalTypeText } from "@transit/query-client/logical";
import { ResultPanel, useStatement } from "./workbench-result";
import {
  Workbench,
  WorkbenchBody,
  NavigatorToggle,
  InspectorPanel,
  useInspector,
} from "./workbench-layout";
import { useScope } from "./state";
import { FeatureAccess } from "./feature-access";
import { useMetadata, Unavailable } from "./data-metadata";
import { datasetSelection, type DatasetSearch } from "./dataset-selection";
import "./workbench.css";
const catalog = new DataCatalog();
export function DatasetPage({ object, search }: { object: string; search: DatasetSearch }) {
  return (
    <FeatureAccess feature="catalog">
      <DatasetPageContent object={object} search={search} />
    </FeatureAccess>
  );
}
function DatasetPageContent({ object, search }: { object: string; search: DatasetSearch }) {
  const sqlConfigured = Boolean(useScope().scope?.features.sql);
  const [tab, setTab] = useState<"preview" | "schema" | "dependencies">("preview");
  const owner = useId();
  const [relationshipCursors, setRelationshipCursors] = useState<
    Record<"dependencies" | "dependents", CatalogDependencies["next"]>
  >({ dependencies: null, dependents: null });
  const statement = useStatement(undefined, sqlConfigured);
  const state = useMetadata(
    JSON.stringify([object, search, tab === "dependencies", relationshipCursors]),
    async (signal) => {
      const expected = datasetSelection(object, search);
      const table = await catalog.table(search.namespace, search.name, expected, signal);
      const dependencies =
        tab === "dependencies"
          ? await catalog.dependencies(
              { dependencies: expected.object },
              signal,
              relationshipCursors.dependencies,
            )
          : null;
      const dependents =
        tab === "dependencies"
          ? await catalog.dependencies(
              { dependents: expected.object },
              signal,
              relationshipCursors.dependents,
            )
          : null;
      return { table, dependencies, dependents };
    },
  );
  // A failed metadata read cannot leave a protected preview visible.
  useEffect(() => {
    if (state.error) statement.close();
  }, [state.error]);
  const table = state.value?.table;
  return (
    <Workbench available={Boolean(table)}>
      <Link to="/catalog">← Catalog</Link>
      <div className="page-heading">
        <div>
          <p className="eyebrow">TABLE / DATASET</p>
          <h1>{table?.metadata.binding.name ?? "Dataset"}</h1>
          <p>Definition, typed rows and their observation basis.</p>
        </div>
        <div className="workbench-toolbar">
          <NavigatorToggle label="Dataset navigation" />
          {table && <DatasetDetailsButton owner={owner} />}
        </div>
      </div>
      {!table ? (
        <Unavailable error={state.error} retry={state.retry} />
      ) : (
        <>
          <WorkbenchScope>
            <span>Branch {table.metadata.binding.interpretation.interpretation.object.branch}</span>
            <span>Object {table.metadata.schema.object}</span>
            <span>Definition {table.metadata.schema.revision}</span>
            <span>{table.metadata.row_count} rows at metadata observation</span>
            <span>Namespace {table.metadata.binding.namespace}</span>
          </WorkbenchScope>
          <WorkbenchBody
            navigator={
              <>
                <p className="eyebrow">THIS DATASET</p>
                <strong>{table.metadata.binding.name}</strong>
                <Link to="/catalog">Browse catalog</Link>
                <p>Columns · declared schema</p>
                {table.metadata.schema.columns.map((field, column) => (
                  <SchemaColumnButton
                    key={field.id}
                    owner={owner}
                    column={column}
                    name={field.name}
                  />
                ))}
                <Link to="/operations">Operational evidence</Link>
              </>
            }
          >
            <div className="workbench-tabs" role="tablist" aria-label="Dataset views">
              {(["preview", "schema", "dependencies"] as const).map((name) => (
                <button
                  key={name}
                  role="tab"
                  aria-selected={tab === name}
                  aria-controls="dataset-panel"
                  onClick={() => setTab(name)}
                >
                  {name === "dependencies"
                    ? "Relationships"
                    : name === "schema"
                      ? "Schema"
                      : "Preview"}
                </button>
              ))}
            </div>

            <section id="dataset-panel" role="tabpanel" aria-label={tab}>
              {tab === "preview" && (
                <>
                  <div className="workbench-toolbar">
                    <button
                      className="primary"
                      disabled={statement.busy || !sqlConfigured}
                      onClick={() =>
                        void statement.run(table.preview_sql, table.expected_definition)
                      }
                    >
                      Preview rows
                    </button>
                    <Link to="/workbook">Open workbook</Link>
                    <span className="muted">
                      Explicit read · bounded window · no automatic query
                    </span>
                  </div>
                  {!sqlConfigured && (
                    <p role="status">
                      SQL connection is not configured. Open Workbook for connection setup; dataset
                      definitions and relationships remain available.
                    </p>
                  )}
                  <ResultPanel state={statement} preview parent={table.metadata.binding.name} />
                  {sqlConfigured && !statement.view && !statement.error && !statement.busy && (
                    <div className="workbench-empty">
                      <h2>Explore this dataset</h2>
                      <p>
                        Preview up to 100 typed rows. Inspect column states and distributions for
                        the received window.
                      </p>
                    </div>
                  )}
                </>
              )}
              {tab === "schema" && <Schema table={table} owner={owner} />}
              {tab === "dependencies" && (
                <div className="workbench-relationships">
                  <h2>Registered relationships</h2>
                  <p>
                    Current dependency records. These pages do not infer joins, freshness or a
                    common snapshot.
                  </p>
                  {(["dependencies", "dependents"] as const).map((kind) => {
                    const page = state.value?.[kind];
                    return (
                      <section key={kind}>
                        <h3>{kind === "dependencies" ? "Depends on" : "Used by"}</h3>
                        {page && (
                          <>
                            <p>
                              {page.entries.filter((entry) => entry !== null).length} records in
                              this authorized page
                              {page.next ? " · More records exist" : " · End of page sequence"}
                            </p>
                            <ul>
                              {page.entries
                                .filter((entry) => entry !== null)
                                .map((edge, index) => (
                                  <li key={index}>
                                    Source object {edge.source.object.object}, definition{" "}
                                    {edge.source.revision} → {edge.dependent.kind} object{" "}
                                    {edge.dependent.interpretation.object.object}, definition{" "}
                                    {edge.dependent.interpretation.revision}
                                  </li>
                                ))}
                            </ul>
                            <div className="workbench-toolbar">
                              <button
                                disabled={!relationshipCursors[kind]}
                                onClick={() =>
                                  setRelationshipCursors((previous) => ({
                                    ...previous,
                                    [kind]: null,
                                  }))
                                }
                              >
                                First {kind}
                              </button>
                              <button
                                disabled={!page.next}
                                onClick={() =>
                                  setRelationshipCursors((previous) => ({
                                    ...previous,
                                    [kind]: page.next,
                                  }))
                                }
                              >
                                More {kind}
                              </button>
                            </div>
                          </>
                        )}
                      </section>
                    );
                  })}
                  <Link to="/operations">Open operational evidence →</Link>
                </div>
              )}
            </section>
          </WorkbenchBody>
          <DatasetInspection table={table} owner={owner} />
        </>
      )}
    </Workbench>
  );
}

function DatasetDetailsButton({ owner }: { owner: string }) {
  const inspector = useInspector();
  return (
    <button
      aria-pressed={inspector.selection?.owner === owner && inspector.selection.kind === "dataset"}
      onClick={(event) =>
        inspector.select({ owner, kind: "dataset", dimension: "definition" }, event.currentTarget)
      }
    >
      Dataset details
    </button>
  );
}

function SchemaColumnButton({
  owner,
  column,
  name,
}: {
  owner: string;
  column: number;
  name: string;
}) {
  const inspector = useInspector();
  return (
    <button
      className="column-select"
      aria-pressed={inspector.selection?.owner === owner && inspector.selection.column === column}
      onClick={(event) =>
        inspector.select(
          { owner, kind: "column", dimension: "definition", column },
          event.currentTarget,
        )
      }
    >
      {name}
    </button>
  );
}

function DatasetInspection({ table, owner }: { table: CatalogTable; owner: string }) {
  const { selection, release } = useInspector();
  useEffect(() => () => release(owner), [release, owner]);
  if (selection?.owner !== owner) return null;
  const field =
    selection.kind === "column" ? table.metadata.schema.columns[selection.column ?? -1] : null;
  return (
    <InspectorPanel
      owner={owner}
      title={field?.name ?? table.metadata.binding.name}
      subtitle={field ? `Column / ${table.metadata.binding.name}` : "Table / Dataset"}
      dimensions={[{ id: "definition", label: "Definition" }]}
      summary={<p>Current authorized metadata · separate from any preview result.</p>}
    >
      <dl>
        {field && (
          <>
            <div>
              <dt>Logical type</dt>
              <dd>{logicalTypeText(field.type)}</dd>
            </div>
            <div>
              <dt>Nullable</dt>
              <dd>{field.nullable ? "Yes" : "No"}</dd>
            </div>
            <div>
              <dt>Physical codec</dt>
              <dd>
                <code>{JSON.stringify(field.encoding)}</code>
              </dd>
            </div>
            <div>
              <dt>Collation</dt>
              <dd>
                <code>{JSON.stringify(field.collation)}</code>
              </dd>
            </div>
          </>
        )}
        <div>
          <dt>Definition digest</dt>
          <dd>
            <code>{table.metadata.binding.interpretation.interpretation.digest}</code>
          </dd>
        </div>
        <div>
          <dt>Schema fingerprint</dt>
          <dd>
            <code>{table.metadata.binding.interpretation.schema_fingerprint}</code>
          </dd>
        </div>
        <div>
          <dt>Authorization resource</dt>
          <dd>{table.metadata.authorization}</dd>
        </div>
        <div>
          <dt>Metadata position</dt>
          <dd>
            Partition {table.metadata.position.partition} / LSN {table.metadata.position.next_lsn}
          </dd>
        </div>
      </dl>
      <p>Metadata and preview rows have separately reported observation bases.</p>
      <Link to="/operations">Operations →</Link>
    </InspectorPanel>
  );
}

function Schema({ table, owner }: { table: CatalogTable; owner: string }) {
  return (
    <div className="workbench-grid">
      <table>
        <caption>Declared logical types, codecs and collations</caption>
        <thead>
          <tr>
            <th>Column</th>
            <th>Logical type</th>
            <th>Nullable</th>
            <th>Codec</th>
            <th>Collation</th>
          </tr>
        </thead>
        <tbody>
          {table.metadata.schema.columns.map((field, column) => (
            <tr key={field.id}>
              <th scope="row">
                <SchemaColumnButton owner={owner} column={column} name={field.name} />
              </th>
              <td>{logicalTypeText(field.type)}</td>
              <td>{field.nullable ? "Yes" : "No"}</td>
              <td>{JSON.stringify(field.encoding)}</td>
              <td>{JSON.stringify(field.collation)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
