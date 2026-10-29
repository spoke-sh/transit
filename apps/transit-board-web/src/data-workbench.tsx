import { useEffect, useState, type ReactNode } from "react";
import { Link, useBlocker } from "@tanstack/react-router";
import {
  DataCatalog,
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
  const [inspector, setInspector] = useState(false);
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
    <main className="data-workbench">
      <Link to="/catalog">← Catalog</Link>
      <div className="page-heading">
        <div>
          <p className="eyebrow">TABLE / DATASET</p>
          <h1>{table?.metadata.binding.name ?? "Dataset"}</h1>
          <p>Definition, typed rows and their observation basis.</p>
        </div>
        <button aria-expanded={inspector} onClick={() => setInspector(!inspector)}>
          Dataset details
        </button>
      </div>
      {!table ? (
        <Unavailable error={state.error} retry={state.retry} />
      ) : (
        <>
          <div className="workbench-scope">
            <span>Object {table.metadata.schema.object}</span>
            <span>Definition {table.metadata.schema.revision}</span>
            <span>{table.metadata.row_count} rows at metadata observation</span>
            <span>Namespace {table.metadata.binding.namespace}</span>
          </div>
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
          <div className={`dataset-layout ${inspector ? "inspector-open" : ""}`}>
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
                  <ResultPanel state={statement} preview />
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
              {tab === "schema" && <Schema table={table} />}
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
            {inspector && (
              <aside className="workbench-profile">
                <p className="eyebrow">DATASET DETAILS</p>
                <h2>{table.metadata.binding.name}</h2>
                <dl>
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
                      Partition {table.metadata.position.partition} / LSN{" "}
                      {table.metadata.position.next_lsn}
                    </dd>
                  </div>
                </dl>
                <p>Metadata and preview rows have separately reported observation bases.</p>
                <Link to="/operations">Operations →</Link>
              </aside>
            )}
          </div>
        </>
      )}
    </main>
  );
}

function Schema({ table }: { table: CatalogTable }) {
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
          {table.metadata.schema.columns.map((field) => (
            <tr key={field.id}>
              <th scope="row">{field.name}</th>
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
    <main className="data-workbench workbook">
      <div className="page-heading">
        <div>
          <p className="eyebrow">SESSION WORKBOOK · UNSAVED</p>
          <h1>Workbook</h1>
          <p>Narrative, SQL and observed results in one place.</p>
        </div>
        <Link to="/catalog">Browse catalog →</Link>
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
        </div>
      )}
    </main>
  );
}
function WorkbookCell({
  index,
  remove,
  edited,
}: {
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
    <section className="workbook-cell" aria-label={`SQL cell ${index + 1}`}>
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
      <ResultPanel state={statement} draft={sql} />
    </section>
  );
}
