import { useState } from "react";
import { Link } from "@tanstack/react-router";
import { useAtlasObservation, type AtlasCursor } from "./atlas-observation";
import { useInterface } from "./interface";
import { useScope } from "./state";
export function Activity() {
  const [cursor, setCursor] = useState<AtlasCursor>();
  const [revision, refresh] = useState(0);
  const { data, error } = useAtlasObservation(cursor, revision);
  const rows = data?.processes.entries.filter((row) => row !== null) ?? [];
  return (
    <main>
      <p className="eyebrow">WORKSPACE / ACTIVITY</p>
      <h1>Activity</h1>
      <p>Current input progress on one authorized page. This is not a complete event history.</p>
      <p role="status">
        {error ||
          (data
            ? `Authority position ${data.position} · ${rows.length} processes on this page`
            : "Reading current activity…")}
      </p>
      <div className="table-scroll">
        <table>
          <caption>Current process counters · independent PID histories</caption>
          <thead>
            <tr>
              <th>PID</th>
              <th>Lifecycle</th>
              <th>Admitted</th>
              <th>Consumed</th>
              <th>Cancelled</th>
              <th>Waiting</th>
              <th>Revision</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.pid}>
                <td>{row.pid}</td>
                <td>{row.lifecycle}</td>
                <td>{row.admitted}</td>
                <td>{row.consumed}</td>
                <td>{row.cancelled}</td>
                <td>{row.admitted - row.consumed - row.cancelled}</td>
                <td>{row.revision}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <button
        onClick={() => {
          setCursor(undefined);
          refresh((value) => value + 1);
        }}
      >
        Refresh activity
      </button>
      {data?.processes.next != null && (
        <button
          onClick={() =>
            setCursor({ position: data.position, process_after: data.processes.next! })
          }
        >
          Next process page
        </button>
      )}
      <p>
        Per-PID counters do not establish cross-process causality, wall-clock event times or worker
        liveness. Global counts and age are unavailable.
      </p>
    </main>
  );
}
export function Operations() {
  const { scope } = useScope();
  const current = useInterface();
  const { data, error } = useAtlasObservation();
  return (
    <main>
      <p className="eyebrow">OPERATIONS / FOUNDATIONS</p>
      <h1>Operations</h1>
      <p>Current inspection identity and the installed interface's declared dependencies.</p>
      <p role="status">
        {error ||
          (data
            ? `Identity observed at authority position ${data.position}`
            : "Reading current authority…")}
      </p>
      {data && (
        <dl className="facts">
          <div>
            <dt>Inspection principal</dt>
            <dd>{data.identity.principal}</dd>
          </div>
          <div>
            <dt>Policy revision</dt>
            <dd>{data.identity.policy_revision}</dd>
          </div>
          <div>
            <dt>Native permissions</dt>
            <dd>Inspect only ({data.identity.permissions})</dd>
          </div>
        </dl>
      )}
      <h2>Installed surfaces</h2>
      <dl>
        <dt>Inspection profile</dt>
        <dd>{scope?.profile}</dd>
        <dt>Query endpoint</dt>
        <dd>
          {scope?.query_enabled ? "Configured; source rights checked on each read" : "Disabled"}
        </dd>
        <dt>Table follow endpoint</dt>
        <dd>
          {scope?.reactive_table ? "Configured; finite session admission required" : "Disabled"}
        </dd>
      </dl>
      {current && (
        <>
          <h2>Declared dependencies</h2>
          <p>
            Declarations identify intended sources and targets. They do not grant access or confirm
            resource liveness.
          </p>
          <div className="table-scroll">
            <table>
              <caption>
                Bindings in {current.compiled.definition.name} revision{" "}
                {current.compiled.definition.revision}
              </caption>
              <thead>
                <tr>
                  <th>Binding</th>
                  <th>Kind</th>
                  <th>Reference</th>
                </tr>
              </thead>
              <tbody>
                {current.compiled.definition.bindings.map((binding) => (
                  <tr key={binding.name}>
                    <td>{binding.name}</td>
                    <td>{Object.keys(binding.source)[0]}</td>
                    <td>
                      {"inspection" in binding.source
                        ? binding.source.inspection.projection
                        : "query" in binding.source
                          ? `Resource ${binding.source.query.resource} · ${binding.source.query.source_kind} · ${binding.source.query.profile}`
                          : `Service ${binding.source.command.service} · target ${binding.source.command.target} · revision ${binding.source.command.revision}`}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
      <p>
        Connector trust and secret-reference evidence is available through authorized resource
        records. Credentials and captured payloads are excluded.
      </p>
      <Link to="/resources" search={{}}>
        Inspect resource records
      </Link>
      <p>
        <Link to="/definition">Review an interface publication</Link>
      </p>
    </main>
  );
}
