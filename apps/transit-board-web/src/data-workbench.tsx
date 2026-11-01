import { useEffect, useId, useState, type ReactNode } from "react";
import { Link, useBlocker } from "@tanstack/react-router";
import {
  DataCatalog,
  type HistoricalTables,
  type HistoricalCoverage,
  type CatalogEntry,
  type CatalogTable,
  type CatalogTables,
  type CatalogNamespaces,
  type CatalogDependencies,
} from "@transit/board-client";
import { describeReads, logicalTypeText } from "@transit/query-client";
import { ResultPanel, useStatement } from "./workbench-result";
import { useInterface } from "./interface";
import { DeclaredView } from "./declared";
import {
  Workbench,
  WorkbenchBody,
  NavigatorToggle,
  InspectorPanel,
  useInspector,
} from "./workbench-layout";
import "./workbench.css";

const catalog = new DataCatalog();

export function DataRoute({ path, children }: { path: string; children: ReactNode }) {
  const current = useInterface();
  return current?.published &&
    current.compiled.definition.screens.some((screen) => screen.path === path) ? (
    <DeclaredView />
  ) : (
    children
  );
}

/** Replace each observation; hidden, failed or superseded reads disclose no cache. */
function useMetadata<T>(key: string, read: (signal: AbortSignal) => Promise<T>) {
  const [value, setValue] = useState<T | null>(null);
  const [error, setError] = useState("");
  const [retry, setRetry] = useState(0);
  useEffect(() => {
    let disposed = false;
    let controller: AbortController | null = null;
    let timer: ReturnType<typeof setTimeout>;
    setValue(null);
    setError("");
    async function refresh() {
      if (disposed || document.hidden || controller) return;
      const abort = new AbortController();
      controller = abort;
      try {
        const next = await read(abort.signal);
        if (!disposed && !abort.signal.aborted && !document.hidden) {
          setValue(next);
          setError("");
        }
      } catch (cause) {
        if (!disposed && !abort.signal.aborted) {
          setValue(null);
          setError(cause instanceof Error ? cause.message : "Metadata unavailable");
        }
      } finally {
        if (controller === abort) controller = null;
        if (!disposed) timer = setTimeout(() => void refresh(), 5000);
      }
    }
    const visibility = () => {
      clearTimeout(timer);
      if (document.hidden) {
        controller?.abort();
        controller = null;
        setValue(null);
      } else void refresh();
    };
    void refresh();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      disposed = true;
      clearTimeout(timer);
      controller?.abort();
      document.removeEventListener("visibilitychange", visibility);
    };
    // The key explicitly includes every scope and selection captured by read.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, retry]);
  return { value, error, retry: () => setRetry((v) => v + 1) };
}

function Unavailable({ error, retry }: { error: string; retry: () => void }) {
  return (
    <div className="workbench-empty" role="status">
      <h2>{error ? "Data connection unavailable" : "Reading catalog…"}</h2>
      <p>{error || "Reading the current authorized metadata."}</p>
      {error && (
        <>
          <p>
            Board needs an explicitly configured catalog or SQL connection with permission to read
            this scope.
          </p>
          <button onClick={retry}>Retry read</button> <Link to="/operations">Open Operations</Link>
        </>
      )}
    </div>
  );
}

export function datasetLink(entry: CatalogEntry) {
  const object = entry.interpretation.object;
  return {
    object: [
      object.scope.realm,
      object.scope.resource,
      object.scope.catalog,
      object.branch,
      object.object,
    ].join("."),
    search: {
      namespace: entry.namespace,
      name: entry.name,
      revision: entry.interpretation.revision,
      digest: entry.interpretation.digest,
    },
  };
}
export type DatasetSearch = { namespace: number; name: string; revision: string; digest: string };
export function datasetSelection(
  object: string,
  search: DatasetSearch,
): CatalogEntry["interpretation"] {
  const parts = object.split(".");
  if (
    parts.length !== 5 ||
    parts.some((part) => !/^[1-9][0-9]*$/.test(part)) ||
    !Number.isSafeInteger(search.namespace) ||
    search.namespace < 1 ||
    !/^[1-9][0-9]*$/.test(search.revision) ||
    !/^[0-9a-f]{64}$/.test(search.digest)
  )
    throw new Error("Invalid dataset identity");
  const realm = Number(parts[0]),
    resource = Number(parts[1]);
  if (!Number.isSafeInteger(realm) || !Number.isSafeInteger(resource))
    throw new Error("Invalid dataset scope");
  return {
    object: {
      scope: { realm, resource, catalog: parts[2]! },
      branch: parts[3]!,
      object: parts[4]!,
    },
    revision: search.revision,
    digest: search.digest,
  };
}

function HistoricalCatalog() {
  const [draft, setDraft] = useState("");
  const [namespace, setNamespace] = useState("public");
  const [selected, setSelected] = useState<{ selector: string; namespace: string } | null>(null);
  return (
    <details className="workbench-history">
      <summary>Inspect a retained catalog</summary>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          setSelected({ selector: draft.trim(), namespace });
        }}
      >
        <label>
          Snapshot selector{" "}
          <input
            required
            value={draft}
            maxLength={594}
            onChange={(event) => setDraft(event.target.value)}
          />
        </label>
        <label>
          Historical schema{" "}
          <input
            required
            value={namespace}
            maxLength={255}
            onChange={(event) => setNamespace(event.target.value)}
          />
        </label>
        <button type="submit">Inspect snapshot</button>
      </form>
      <p>Inspection uses current permissions. It does not acquire or release retention.</p>
      {selected && <HistoricalSelection key={JSON.stringify(selected)} {...selected} />}
    </details>
  );
}

function HistoricalSelection({ selector, namespace }: { selector: string; namespace: string }) {
  const [after, setAfter] = useState<HistoricalTables["next"]>(null);
  const [object, setObject] = useState<string | null>(null);
  const state = useMetadata(JSON.stringify([selector, namespace, after]), async (signal) => {
    const selected = await catalog.historical({ namespace: { selector, name: namespace } }, signal);
    if (!("namespace" in selected) || selected.namespace === null)
      throw new Error("Schema is absent from this retained catalog.");
    return catalog.historicalTables(selector, selected.namespace.id, after, signal);
  });
  if (!state.value) return <Unavailable error={state.error} retry={state.retry} />;
  const page = state.value;
  return (
    <section aria-label="Retained catalog">
      <p>
        Catalog {page.snapshot.owner.scope.catalog} · Branch {page.snapshot.branch} ·{" "}
        {Object.keys(page.snapshot.consistency)[0]} · {page.snapshot.source_count} retained sources
      </p>
      <p>
        Catalog digest <code>{page.snapshot.catalog_root.sha256}</code>
      </p>
      <p>
        Source digest <code>{page.snapshot.sources_root.sha256}</code>
      </p>
      <ul>
        {page.entries.map((entry) => (
          <li key={entry.declaration.interpretation.object.object}>
            <button onClick={() => setObject(entry.declaration.interpretation.object.object)}>
              {entry.name}
            </button>
            {" · Definition "}
            {entry.declaration.interpretation.revision}
            {" · Accepted LSN "}
            {entry.accepted.next_lsn}
          </li>
        ))}
      </ul>
      <p>
        {page.next
          ? "This page is incomplete; more retained sources are available."
          : "End of the selected schema directory."}
      </p>
      <button
        disabled={after === null}
        onClick={() => {
          setAfter(null);
          setObject(null);
        }}
      >
        First page
      </button>
      <button
        disabled={page.next === null}
        onClick={() => {
          setAfter(page.next);
          setObject(null);
        }}
      >
        Next page
      </button>
      {object && <HistoricalObject key={object} selector={selector} object={object} />}
    </section>
  );
}

function HistoricalObject({ selector, object }: { selector: string; object: string }) {
  const [kind, setKind] = useState<"definitions" | "locations">("definitions");
  const [after, setAfter] = useState<HistoricalCoverage["next"]>(null);
  const state = useMetadata(JSON.stringify([selector, object, kind, after]), async (signal) => {
    const source = await catalog.historicalSource(selector, object, signal);
    const coverage = await catalog.historicalCoverage(selector, object, kind, after, signal);
    return { source, coverage };
  });
  return (
    <section aria-label="Retained interpretation">
      <h3>Retained interpretation</h3>
      <label>
        Coverage{" "}
        <select
          value={kind}
          onChange={(event) => {
            setKind(event.target.value as "definitions" | "locations");
            setAfter(null);
          }}
        >
          <option value="definitions">Physical definitions</option>
          <option value="locations">Row placement (requires SELECT)</option>
        </select>
      </label>
      {!state.value ? (
        <Unavailable error={state.error} retry={state.retry} />
      ) : (
        (() => {
          const { source, coverage } = state.value;
          return (
            <>
              <p>
                Object {object} · Definition {coverage.logical.interpretation.revision} ·{" "}
                {coverage.total_rows} retained rows
              </p>
              <p>
                Schema digest <code>{coverage.logical.schema_fingerprint}</code>
              </p>
              <table>
                <thead>
                  <tr>
                    <th>Column</th>
                    <th>Type</th>
                    <th>Codec</th>
                    <th>Collation</th>
                  </tr>
                </thead>
                <tbody>
                  {source.schema.columns.map((column) => (
                    <tr key={column.id}>
                      <td>{column.name}</td>
                      <td>{logicalTypeText(column.type)}</td>
                      <td>{JSON.stringify(column.encoding)}</td>
                      <td>{column.collation}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <details>
                <summary>Declared constraints and semantics</summary>
                <pre>
                  {JSON.stringify(
                    {
                      integrity: source.schema.integrity,
                      semantics: source.schema.columns.map((column) => ({
                        column: column.id,
                        semantics: column.semantics,
                      })),
                    },
                    null,
                    2,
                  )}
                </pre>
              </details>
              {coverage.definitions && (
                <>
                  <p>
                    Physical schema {coverage.definitions.schema_revision} ·{" "}
                    {coverage.definitions.rows} rows
                  </p>
                  <ul>
                    {coverage.definitions.columns.map((column) => (
                      <li key={column.column}>
                        Column {column.column}:{" "}
                        {"physical" in column.source
                          ? `physical column ${column.source.physical}`
                          : `ADD-time ${column.source.initial.state}, definition ${column.source.initial.definition.revision}`}
                      </li>
                    ))}
                  </ul>
                </>
              )}
              {coverage.locations.map((location) => (
                <p
                  key={`${location.identity.origin}:${location.identity.operation}:${location.identity.ordinal}`}
                >
                  Row {location.identity.origin}:{location.identity.operation}:
                  {location.identity.ordinal}
                  {" · "}
                  {"segment" in location.location
                    ? `Segment ${location.location.segment.id}, row ${location.location.segment.row}, digest ${location.location.segment.content.sha256}`
                    : `WAL LSN ${location.location.wal.lsn}, offset ${location.location.wal.offset}`}
                </p>
              ))}
              <p>
                {coverage.next
                  ? "Partial directory coverage. More pages remain."
                  : "Directory traversal ends here."}{" "}
                Payload verification and query completion are separate.
              </p>
              <button disabled={after === null} onClick={() => setAfter(null)}>
                First coverage page
              </button>
              <button disabled={coverage.next === null} onClick={() => setAfter(coverage.next)}>
                Next coverage page
              </button>
            </>
          );
        })()
      )}
    </section>
  );
}

export function CatalogPage() {
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
    <main className="data-workbench">
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
      <HistoricalCatalog />
      {!data ? (
        <Unavailable error={state.error} retry={state.retry} />
      ) : (
        <>
          <div className="workbench-scope">
            <strong>{data.description.configuration.database_name}</strong>
            <span>Catalog {data.description.configuration.scope.catalog}</span>
            <span>Branch {data.description.configuration.branch}</span>
            <span>Current authorized metadata</span>
          </div>
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
    </main>
  );
}

export function DatasetPage({ object, search }: { object: string; search: DatasetSearch }) {
  const [tab, setTab] = useState<"preview" | "schema" | "dependencies">("preview");
  const owner = useId();
  const [relationshipCursors, setRelationshipCursors] = useState<
    Record<"dependencies" | "dependents", CatalogDependencies["next"]>
  >({ dependencies: null, dependents: null });
  const statement = useStatement();
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
          <div className="workbench-scope">
            <span>Branch {table.metadata.binding.interpretation.interpretation.object.branch}</span>
            <span>Object {table.metadata.schema.object}</span>
            <span>Definition {table.metadata.schema.revision}</span>
            <span>{table.metadata.row_count} rows at metadata observation</span>
            <span>Namespace {table.metadata.binding.namespace}</span>
          </div>
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
                      disabled={statement.busy}
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
                  <ResultPanel state={statement} preview parent={table.metadata.binding.name} />
                  {!statement.view && !statement.error && !statement.busy && (
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

export function WorkbookPage() {
  const [cells, setCells] = useState([crypto.randomUUID()]);
  const [title, setTitle] = useState("Untitled investigation");
  const [connected, setConnected] = useState(false);
  const [dirty, setDirty] = useState(false);
  useBlocker({
    shouldBlockFn: () =>
      dirty && !window.confirm("Discard this unsaved workbook and close its results?"),
    enableBeforeUnload: dirty,
  });
  const connection = useMetadata("sql", (signal) => describeReads(signal));
  useEffect(() => {
    if (connection.value) setConnected(true);
  }, [connection.value]);
  return (
    <Workbench className="workbook" available={Boolean(connection.value)}>
      <div className="page-heading">
        <div>
          <p className="eyebrow">SESSION WORKBOOK · UNSAVED</p>
          <h1>Workbook</h1>
          <p>Narrative, SQL and observed results in one place.</p>
        </div>
        <div className="workbench-toolbar">
          <NavigatorToggle label="Cells" />
          <Link to="/catalog">Browse catalog →</Link>
        </div>
      </div>
      <p className="workbench-notice">
        Temporary session. Leaving this page discards its cells and closes its result views. Each
        Run has its own source basis.
      </p>
      {!connection.value && <Unavailable error={connection.error} retry={connection.retry} />}
      {connected && (
        <div hidden={!connection.value}>
          <div className="workbench-scope">
            <strong>{connection.value?.database}</strong>
            <span>{connection.value?.source ?? "Configured SQL namespace"}</span>
            <span>Read-only statements</span>
            <span>Up to {connection.value?.window_rows} rows per window</span>
          </div>
          <WorkbenchBody
            navigator={
              <>
                <p className="eyebrow">THIS WORKBOOK</p>
                <strong>{title}</strong>
                {cells.map((id, index) => (
                  <CellNavigation key={id} id={id} index={index} />
                ))}
                <p>Temporary session · up to four cells</p>
              </>
            }
          >
            <label className="workbook-title">
              Investigation title
              <input
                value={title}
                maxLength={160}
                onChange={(event) => {
                  setTitle(event.target.value);
                  setDirty(true);
                }}
              />
            </label>
            {cells.map((id, index) => (
              <WorkbookCell
                key={id}
                id={id}
                index={index}
                edited={() => setDirty(true)}
                remove={() => {
                  setDirty(true);
                  setCells((previous) => previous.filter((value) => value !== id));
                }}
              />
            ))}
            <button
              disabled={cells.length >= 4}
              onClick={() => {
                setDirty(true);
                setCells((previous) => [...previous, crypto.randomUUID()]);
              }}
            >
              Add SQL cell
            </button>
            <p className="muted">
              Four active result readers are shared by this Board deployment. Close results when
              finished.
            </p>
          </WorkbenchBody>
        </div>
      )}
    </Workbench>
  );
}
function CellNavigation({ id, index }: { id: string; index: number }) {
  const { toggleNavigation } = useInspector();
  return (
    <button
      onClick={() => {
        toggleNavigation();
        requestAnimationFrame(() =>
          document.getElementById(`cell-${id}`)?.querySelector("textarea")?.focus(),
        );
      }}
    >
      Cell {index + 1}
    </button>
  );
}

function WorkbookCell({
  id,
  index,
  remove,
  edited,
}: {
  id: string;
  index: number;
  remove: () => void;
  edited: () => void;
}) {
  const [sql, setSql] = useState("SHOW TABLES");
  const [note, setNote] = useState("");
  const statement = useStatement(() => {
    setSql("");
    setNote("");
  });
  return (
    <section id={`cell-${id}`} className="workbook-cell" aria-label={`SQL cell ${index + 1}`}>
      <div className="workbench-toolbar">
        <h2>Cell {index + 1}</h2>
        <span className="muted">Explicit Run</span>
        <button onClick={remove}>Remove cell</button>
      </div>
      <label>
        Investigation notes
        <textarea
          className="workbook-note"
          value={note}
          maxLength={8000}
          placeholder="What are you investigating?"
          onChange={(event) => {
            setNote(event.target.value);
            edited();
          }}
        />
      </label>
      <label>
        SQL
        <textarea
          className="workbook-sql"
          spellCheck={false}
          value={sql}
          maxLength={60000}
          onChange={(event) => {
            setSql(event.target.value);
            edited();
          }}
          onKeyDown={(event) => {
            if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
              event.preventDefault();
              if (!statement.busy && sql.trim()) void statement.run(sql);
            }
          }}
        />
      </label>
      <div className="workbench-toolbar">
        <button
          className="primary"
          disabled={statement.busy || !sql.trim()}
          onClick={() => void statement.run(sql)}
        >
          Run cell {index + 1}
        </button>
        <span className="muted">Ctrl / ⌘ Enter · SELECT, SHOW, DESCRIBE, EXPLAIN</span>
      </div>
      <ResultPanel state={statement} draft={sql} parent={`Cell ${index + 1}`} />
    </section>
  );
}
