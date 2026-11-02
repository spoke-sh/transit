import { useState } from "react";
import { Link } from "@tanstack/react-router";
import {
  DataCatalog,
  type HistoricalTables,
  type HistoricalCoverage,
  type CatalogDefinitions,
} from "@transit/board-client";
import { logicalTypeText } from "@transit/query-client";
import { useRead } from "./use-observation";
import { useScope } from "./state";
import { ReadStatus } from "./read-status";
import type { ReadFailure } from "./observation";

import { RetainedPlacement } from "./retained-placement";

const catalog = new DataCatalog();
function useMetadata<T>(key: string, read: (signal: AbortSignal) => Promise<T>) {
  const scope = useScope().scope;
  const state = useRead(JSON.stringify(["retained", scope, key]), read);
  return { value: state.value, error: state.failure, retry: state.retry };
}
function Unavailable({ error, retry }: { error: ReadFailure | null; retry: () => void }) {
  return (
    <>
      <ReadStatus failure={error} retry={retry} subject="Data" />
      {error && <Link to="/operations">Open Operations</Link>}
    </>
  );
}

export function HistoricalCatalog() {
  const scope = useScope().scope;
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState("");
  const [namespace, setNamespace] = useState("public");
  const [selected, setSelected] = useState<{ selector: string; namespace: string } | null>(null);
  return (
    <details className="workbench-history" onToggle={(event) => setOpen(event.currentTarget.open)}>
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
      {open && selected && (
        <HistoricalSelection key={JSON.stringify([scope, selected])} {...selected} />
      )}
    </details>
  );
}

function HistoricalSelection({ selector, namespace }: { selector: string; namespace: string }) {
  const [definitions, setDefinitions] = useState(false);
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
      <details onToggle={(event) => setDefinitions(event.currentTarget.open)}>
        <summary>Inspect retained definitions</summary>
        {definitions && <HistoricalDefinitions selector={selector} namespace={namespace} />}
      </details>
    </section>
  );
}

function HistoricalDefinitions({ selector, namespace }: { selector: string; namespace: string }) {
  const [cursor, setCursor] = useState<CatalogDefinitions["next"]>(null);
  const [name, setName] = useState<string | null>(null);
  const state = useMetadata(JSON.stringify([selector, namespace, cursor]), async (signal) => {
    const selected = await catalog.historical({ namespace: { selector, name: namespace } }, signal);
    if (!("namespace" in selected) || selected.namespace === null)
      throw new Error("Schema is absent from this retained catalog.");
    return {
      namespace: selected.namespace.id,
      page: await catalog.definitions(selected.namespace.id, selector, cursor, signal),
    };
  });
  if (!state.value) return <Unavailable error={state.error} retry={state.retry} />;
  const { page, namespace: namespaceId } = state.value;
  return (
    <section aria-label="Retained definitions">
      <p>
        Accepted views, graph mappings and foreign decoders. Inspecting a definition does not
        execute it.
      </p>
      <ul>
        {page.entries
          .filter((entry) => entry !== null)
          .map((entry) => (
            <li key={entry.interpretation.object.object}>
              <button onClick={() => setName(entry.properties.name)}>
                {entry.properties.name}
              </button>
              {" · "}
              {entry.kind}
              {" · Object "}
              {entry.interpretation.object.object}
              {" · Definition "}
              {entry.interpretation.revision}
            </li>
          ))}
      </ul>
      <p>
        {page.next
          ? "More definitions are available."
          : "End of the selected definition directory."}
      </p>
      <button
        disabled={cursor === null}
        onClick={() => {
          setCursor(null);
          setName(null);
        }}
      >
        First definitions
      </button>
      <button
        disabled={page.next === null}
        onClick={() => {
          setCursor(page.next);
          setName(null);
        }}
      >
        Next definitions
      </button>
      {name && (
        <HistoricalDefinitionDetails
          key={name}
          selector={selector}
          namespace={namespaceId}
          name={name}
        />
      )}
    </section>
  );
}
function HistoricalDefinitionDetails({
  selector,
  namespace,
  name,
}: {
  selector: string;
  namespace: number;
  name: string;
}) {
  const state = useMetadata(JSON.stringify([selector, namespace, name]), (signal) =>
    catalog.historicalDefinition(selector, namespace, name, signal),
  );
  if (!state.value) return <Unavailable error={state.error} retry={state.retry} />;
  const definition = state.value.definition;
  if (!definition) return <p>This definition is absent from the selected catalog.</p>;
  return (
    <section aria-label="Accepted interpretation">
      <h3>{definition.stored.properties.name}</h3>
      <p>
        {definition.stored.kind}
        {" · Definition "}
        {definition.stored.interpretation.revision}
      </p>
      <p>
        Definition digest <code>{definition.stored.interpretation.digest}</code>
      </p>
      <ul>
        {definition.sources.map((source) => (
          <li key={source.declaration.interpretation.object.object}>
            Source {source.declaration.interpretation.object.object}
            {" · Definition "}
            {source.declaration.interpretation.revision}
            <code>{source.declaration.interpretation.digest}</code>
          </li>
        ))}
      </ul>
      <details>
        <summary>Output schema and interpretation</summary>
        <pre>{JSON.stringify({ schema: definition.schema, body: definition.body }, null, 2)}</pre>
      </details>
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
              <RetainedPlacement
                key={JSON.stringify([selector, object, kind, after])}
                source={source}
                coverage={coverage}
                kind={kind}
              />
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
