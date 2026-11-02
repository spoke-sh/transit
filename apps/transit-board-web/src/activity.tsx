import { useState } from "react";
import { useAtlasObservation, type AtlasCursor } from "./atlas-observation";
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
