import { Link } from "@tanstack/react-router";
import { useState } from "react";
import { useStateObservation } from "./state";
import { present } from "./components";
import { Framework } from "./framework";

export function StateEvidence({ view }: { view: ReturnType<typeof useStateObservation> }) {
  const page = view.data?.observation;
  return (
    <section className="evidence" aria-label="State observation evidence">
      <div role="status">
        {view.error && (
          <p className="warning">
            {view.error}
            {page ? " Last observation is stale." : ""}
          </p>
        )}
        {!page && !view.error && <p>Reading authorized state evidence…</p>}
        {page && (
          <>
            <p>
              {view.error ? "Stale" : "Observed"} · realm {page.realm} · position{" "}
              {page.cut.position} (exclusive) · policy {page.cut.policy_revision} · sampled at{" "}
              {view.observedAt}
            </p>
            <p>
              Retained from {page.cut.retained_from} ·{" "}
              {page.cut.retained_from > 0
                ? "Earlier history reclaimed; current resource data survives."
                : "History retained"}{" "}
              · {page.next === null ? "End of this query" : "More matching records may follow"}
            </p>
          </>
        )}
      </div>
      <div className="actions">
        <button onClick={view.reset}>Refresh from start</button>
        {page?.next != null && <button onClick={view.next}>Next state page</button>}
      </div>
      <small>
        {view.paginated
          ? "Pagination holds this observation; refresh starts a new cut."
          : "Polls every 5 seconds; no cached value is execution authority."}
      </small>
    </section>
  );
}

export function Resources({ resource }: { resource?: number }) {
  const [values, setValues] = useState(false);
  const view = useStateObservation(values ? "entries" : "resources", resource);
  const page = view.data?.observation;
  return (
    <>
      <StateEvidence view={view} />
      {resource !== undefined && (
        <div className="actions">
          <button onClick={() => setValues((v) => !v)}>
            {values ? "Show resource metadata" : "Read framework and opaque entries"}
          </button>
        </div>
      )}
      {page?.resources.filter(present).map((r) => (
        <article key={r.id}>
          <h2>
            <Link to="/resources" search={{ resource: r.id }}>
              KV resource {r.id}
            </Link>
          </h2>
          <div className="facts">
            <div>
              <span>Lifecycle</span>
              <strong>{r.phase}</strong>
            </div>
            <div>
              <span>Revision</span>
              <strong>{r.revision}</strong>
            </div>
            <div>
              <span>Lifetime owner</span>
              <strong>{r.owner === null ? "Independent" : `PID ${r.owner}`}</strong>
            </div>
            <div>
              <span>Writer</span>
              <strong>PID {r.writer}</strong>
            </div>
          </div>
          <p>
            Deadline: {r.deadline_ms === null ? "Unlimited" : new Date(r.deadline_ms).toISOString()}{" "}
            · history retention:{" "}
            {r.history_ms === null
              ? "Unlimited"
              : `${r.history_ms} ms minimum age before safe compaction`}
          </p>
          <p>
            Retirement record: {r.retired_at ?? "None"}. Logical retirement and physical reclamation
            are distinct.
          </p>
          {r.last_turn !== null && (
            <p>
              Last mutation committed by turn {r.last_turn} ·{" "}
              {r.last_turn < page.cut.retained_from ? (
                "turn detail reclaimed"
              ) : (
                <Link
                  to="/processes/$pid/journey"
                  params={{ pid: String(r.writer) }}
                  search={{ tab: "process" }}
                >
                  Inspect writer journey
                </Link>
              )}
            </p>
          )}
        </article>
      ))}
      {values && (
        <>
          {view.data && <Framework lenses={view.data.framework} />}
          <section>
            <h2>Opaque KV entries</h2>
            <p>
              Keys and values below are exact hexadecimal bytes. Application encoding is outside
              Board. An empty page is distinct from an expired or inaccessible resource.
            </p>
            <table>
              <thead>
                <tr>
                  <th>Key (hex)</th>
                  <th>Value (hex)</th>
                  <th>Revision</th>
                </tr>
              </thead>
              <tbody>
                {page?.entries.filter(present).map((e) => (
                  <tr key={e.key}>
                    <td>
                      <code>{e.key}</code>
                    </td>
                    <td>
                      <code>{e.value}</code>
                    </td>
                    <td>{e.revision}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </>
      )}
    </>
  );
}
