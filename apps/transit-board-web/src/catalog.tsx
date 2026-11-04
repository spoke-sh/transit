import { WorkbenchScope } from "./workbench-layout";
import { useState } from "react";
import { Link } from "@tanstack/react-router";
import { DataCatalog } from "@transit/board-client/catalog";
import {
  type CatalogEntry,
  type CatalogTables,
  type CatalogNamespaces,
} from "@transit/board-client";
import { Workbench, WorkbenchBody } from "./workbench-layout";
import { FeatureAccess } from "./feature-access";
import { HistoricalCatalog } from "./retained-storage";
import { useMetadata, Unavailable } from "./data-metadata";
import { datasetLink } from "./dataset-selection";
import "./workbench.css";
const catalog = new DataCatalog();
export function CatalogPage() {
  return (
    <FeatureAccess feature="catalog">
      <CatalogPageContent />
    </FeatureAccess>
  );
}
function CatalogPageContent() {
  const [namespace, setNamespace] = useState<number | null>(null);
  const [namespaceCursor, setNamespaceCursor] = useState<CatalogNamespaces["next"]>(null);
  const [cursor, setCursor] = useState<CatalogTables["next"]>(null);
  const [filter, setFilter] = useState("");
  const state = useMetadata(
    JSON.stringify([namespace, namespaceCursor, cursor]),
    async (signal) => {
      const description = await catalog.describe(signal);
      const namespaces = await catalog.namespaces(namespaceCursor, signal);
      const selected = namespace ?? description.configuration.authority.initial_schema;
      const tables = await catalog.tables(selected, cursor, signal);
      return { description, namespaces, tables, selected };
    },
  );
  const data = state.value;
  const entries =
    data?.tables.entries
      .filter((entry): entry is CatalogEntry => entry !== null)
      .filter((entry) => entry.name.toLocaleLowerCase().includes(filter.toLocaleLowerCase())) ?? [];
  return (
    <Workbench>
      <div className="page-heading">
        <div>
          <p className="eyebrow">DATA WORKSPACE</p>
          <h1>Catalog</h1>
          <p>Find data. Understand its definition. Start an investigation.</p>
        </div>
        <Link className="workbench-action" to="/workbook">
          New session workbook
        </Link>
      </div>
      <WorkbenchBody>
        <HistoricalCatalog />
        {!data ? (
          <Unavailable error={state.error} retry={state.retry} />
        ) : (
          <>
            <WorkbenchScope>
              <strong>{data.description.configuration.database_name}</strong>
              <span>Catalog {data.description.configuration.scope.catalog}</span>
              <span>Branch {data.description.configuration.branch}</span>
              <span>Current authorized metadata</span>
            </WorkbenchScope>
            <div className="workbench-toolbar">
              <label>
                Namespace
                <select
                  value={data.selected}
                  onChange={(event) => {
                    setNamespace(Number(event.target.value));
                    setCursor(null);
                  }}
                >
                  {!data.namespaces.entries.some((entry) => entry?.id === data.selected) && (
                    <option value={data.selected}>Namespace {data.selected}</option>
                  )}
                  {data.namespaces.entries
                    .filter((entry) => entry !== null)
                    .map((entry) => (
                      <option key={entry.id} value={entry.id}>
                        {entry.name}
                      </option>
                    ))}
                </select>
              </label>
              <button disabled={!namespaceCursor} onClick={() => setNamespaceCursor(null)}>
                First namespaces
              </button>
              <button
                disabled={!data.namespaces.next}
                onClick={() => setNamespaceCursor(data.namespaces.next)}
              >
                More namespaces
              </button>
              <label className="workbench-search">
                Filter this page
                <input
                  type="search"
                  value={filter}
                  onChange={(event) => setFilter(event.target.value)}
                  placeholder="Dataset name"
                />
              </label>
            </div>
            <div className="workbench-grid">
              <table>
                <caption>Tables · up to 8 authorized definitions per page</caption>
                <thead>
                  <tr>
                    <th>Dataset</th>
                    <th>Kind</th>
                    <th>Definition</th>
                    <th>Observed change</th>
                  </tr>
                </thead>
                <tbody>
                  {entries.map((entry) => {
                    const link = datasetLink(entry);
                    return (
                      <tr key={link.object}>
                        <td>
                          <Link
                            to="/datasets/$object"
                            params={{ object: link.object }}
                            search={link.search}
                          >
                            {entry.name}
                          </Link>
                          <small>Object {entry.interpretation.object.object}</small>
                        </td>
                        <td>
                          <span className="workbench-kind">Table</span>
                        </td>
                        <td>Revision {entry.interpretation.revision}</td>
                        <td>LSN {entry.changed_lsn}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
              {!entries.length && <p>No authorized Tables match this page and filter.</p>}
            </div>
            <div className="workbench-toolbar">
              <button disabled={!cursor} onClick={() => setCursor(null)}>
                First page
              </button>
              <button disabled={!data.tables.next} onClick={() => setCursor(data.tables.next)}>
                Next page
              </button>
              <span className="muted">
                Page filter · independently observed definitions · not a global search
              </span>
            </div>
            <div className="workbench-related">
              <h2>Other data and operational evidence</h2>
              <p>
                Existing KV and Document projections, resource observations and finite Live sessions
                remain available in Resources.
              </p>
              <Link to="/resources" search={{}}>
                Open Resources →
              </Link>
            </div>
          </>
        )}
      </WorkbenchBody>
    </Workbench>
  );
}
