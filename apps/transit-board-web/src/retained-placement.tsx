import { useEffect, useId } from "react";
import type { HistoricalCoverage, HistoricalSource } from "@transit/board-client";
import { definitionPlacement, rowPlacement } from "./retained-model";
import { InspectorPanel, useInspector } from "./workbench-layout";
import { ByteSize, ExactBytes } from "./quantity";
import "./retained-placement.css";

export function RetainedPlacement({
  source,
  coverage,
  kind,
}: {
  source: HistoricalSource;
  coverage: HistoricalCoverage;
  kind: "definitions" | "locations";
}) {
  const owner = useId();
  const { selection, select, release } = useInspector();
  useEffect(() => () => release(owner), [owner, release]);
  const items =
    kind === "definitions"
      ? coverage.definitions
        ? definitionPlacement(coverage.definitions, source.schema.columns)
        : []
      : rowPlacement(coverage.locations);
  const selected = selection?.owner === owner ? selection.metric : undefined;
  const item = items.find((row) => row.key === selected);
  const title = kind === "definitions" ? "Physical definitions" : "Row placement";
  const basis = `Object ${coverage.logical.interpretation.object.object} · Definition ${coverage.logical.interpretation.revision} · accepted partition ${coverage.accepted.partition}, next LSN ${coverage.accepted.next_lsn}`;
  const choose = (key: string, trigger: HTMLButtonElement) =>
    select({ owner, kind: "storage", dimension: "evidence", metric: key }, trigger);
  return (
    <section className="storage-evidence retained-placement" aria-label={`${title} evidence`}>
      <h4>{title}</h4>
      <p className="storage-basis">
        {basis}. Selected retained cut; independent of current Table storage.
      </p>
      <p>
        {kind === "definitions"
          ? `One physical generation per page${coverage.definitions ? ` · ${coverage.definitions.rows} rows in this generation` : ""}.`
          : `${items.length} of at most 8 locations on this page. Segment sizes are unavailable.`}
      </p>
      {items.length === 0 ? (
        <p>
          No {kind === "definitions" ? "physical definitions" : "row locations"} in this authorized
          page.
        </p>
      ) : (
        <>
          <div className="placement-diagram" role="group" aria-label={`${title} visualization`}>
            {[...new Set(items.map((row) => row.group))].map((group) => {
              const rows = items.filter((row) => row.group === group);
              return (
                <div className="placement-destination" key={group}>
                  <strong>{rows[0]!.destination}</strong>
                  <div>
                    {rows.map((row) => (
                      <button
                        key={row.key}
                        aria-pressed={selected === row.key}
                        onClick={(event) => choose(row.key, event.currentTarget)}
                      >
                        <span>{row.label}</span>
                        <span aria-hidden="true">→</span>
                        <span>{row.location}</span>
                      </button>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
          <div className="workbench-grid">
            <table>
              <caption>{title} · same selected page as the visualization</caption>
              <thead>
                <tr>
                  <th>{kind === "definitions" ? "Logical column" : "Original row"}</th>
                  <th>Destination</th>
                  <th>Location / origin</th>
                  <th>Physical schema</th>
                  {kind === "locations" && <th>WAL row size</th>}
                </tr>
              </thead>
              <tbody>
                {items.map((row) => (
                  <tr key={row.key} data-selected={selected === row.key}>
                    <th scope="row">
                      <button
                        aria-pressed={selected === row.key}
                        onClick={(event) => choose(row.key, event.currentTarget)}
                      >
                        {row.label}
                      </button>
                    </th>
                    <td>{row.destination}</td>
                    <td>{row.location}</td>
                    <td>{row.schema}</td>
                    {kind === "locations" && (
                      <td>
                        {row.bytes === undefined ? (
                          "Not a WAL location"
                        ) : (
                          <ByteSize value={row.bytes} />
                        )}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
      {item && (
        <InspectorPanel
          owner={owner}
          title={item.label}
          subtitle={title}
          summary={basis}
          dimensions={[{ id: "evidence", label: "Evidence" }]}
        >
          <p>
            {item.destination} · {item.location} · Physical schema {item.schema}
          </p>
          {item.bytes !== undefined && (
            <p>
              <ExactBytes value={item.bytes} label="WAL row size" />
            </p>
          )}
          {kind === "definitions" && (
            <p>
              Physical columns and ADD-time initial states are separate origins. Initial state
              identifies the accepted ADD definition; it does not decode an application value.
            </p>
          )}
          <dl>
            <dt>Retained selector</dt>
            <dd>
              <code>{coverage.snapshot.selector}</code>
            </dd>
            <dt>Catalog digest</dt>
            <dd>
              <code>{coverage.snapshot.catalog_root.sha256}</code>
            </dd>
            <dt>Source digest</dt>
            <dd>
              <code>{coverage.snapshot.sources_root.sha256}</code>
            </dd>
            <dt>Logical definition digest</dt>
            <dd>
              <code>{coverage.logical.interpretation.digest}</code>
            </dd>
          </dl>
          <details open>
            <summary>Exact mapping and physical interpretation</summary>
            <pre>
              {JSON.stringify(
                kind === "definitions"
                  ? {
                      physical: coverage.definitions?.physical,
                      mapping: coverage.definitions?.columns.find(
                        (column) => column.column === item.key,
                      ),
                    }
                  : coverage.locations.find(
                      (row) =>
                        `${row.identity.origin}:${row.identity.operation}:${row.identity.ordinal}` ===
                        item.key,
                    ),
                null,
                2,
              )}
            </pre>
          </details>
          <p>
            Directory evidence does not verify payloads, establish query completion or authorize
            deletion.
          </p>
        </InspectorPanel>
      )}
    </section>
  );
}
