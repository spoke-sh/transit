import { createFileRoute, Link } from "@tanstack/react-router";
import { attention, Evidence, present } from "../components";
import { DeclaredView } from "../declared";
import { useScope, useObservation } from "../state";
export const Route = createFileRoute("/")({
  validateSearch: (search: Record<string, unknown>) => ({
    status:
      search.status === "running" || search.status === "retired" || search.status === "attention"
        ? search.status
        : "all",
    sort: search.sort === "backlog" ? "backlog" : "pid",
  }),
  component: () => (useScope().scope?.profile === "growing_v3" ? <DeclaredView /> : <Overview />),
});
function Overview() {
  const view = useObservation("processes");
  const { status, sort } = Route.useSearch();
  const navigate = Route.useNavigate();
  const processes =
    view.data?.observation.processes
      .filter(present)
      .filter(
        (p) =>
          status === "all" ||
          (status === "running"
            ? p.lifecycle === "running"
            : status === "retired"
              ? p.lifecycle !== "running"
              : p.failure || p.admitted > p.consumed + p.cancelled),
      ) ?? [];
  processes.sort((a, b) =>
    sort === "pid"
      ? a.pid - b.pid
      : b.admitted - b.consumed - b.cancelled - (a.admitted - a.consumed - a.cancelled) ||
        a.pid - b.pid,
  );
  return (
    <main>
      <div className="page-heading">
        <div>
          <p className="eyebrow">LIVE OBSERVATIONS / KERNEL PRIMITIVES</p>
          <h1>Departure board</h1>
          <p>What is waiting, what moved, and what needs attention.</p>
        </div>
        <span className="station-mark" aria-hidden="true">
          01
          <br />
          TRANSIT
        </span>
      </div>
      <Link to="/resources" search={{}}>
        State resources →
      </Link>
      <Evidence view={view} />
      <div className="filters">
        <label>
          Show{" "}
          <select
            value={status}
            onChange={(event) =>
              void navigate({
                search: (previous) => ({
                  ...previous,
                  status: event.target.value as typeof status,
                }),
              })
            }
          >
            <option value="all">All lifecycles</option>
            <option value="running">Running</option>
            <option value="retired">Retired</option>
            <option value="attention">Needs attention</option>
          </select>
        </label>
        <label>
          Order{" "}
          <select
            value={sort}
            onChange={(event) =>
              void navigate({
                search: (previous) => ({ ...previous, sort: event.target.value as typeof sort }),
              })
            }
          >
            <option value="pid">PID</option>
            <option value="backlog">Pending input</option>
          </select>
        </label>
        <span>Filters apply to this authorized page</span>
      </div>
      <div className="table-scroll">
        <table>
          <caption>Transit processes · up to 16 per page</caption>
          <thead>
            <tr>
              <th>PID</th>
              <th>Lifecycle</th>
              <th>Activation</th>
              <th>Arrivals</th>
              <th>Pending</th>
              <th>Attention</th>
            </tr>
          </thead>
          <tbody>
            {processes.map((p) => (
              <tr key={p.pid}>
                <td>
                  <Link
                    to="/processes/$pid"
                    params={{ pid: String(p.pid) }}
                    search={{ tab: "process" }}
                  >
                    PID {p.pid}
                  </Link>
                </td>
                <td>
                  <span className={`badge ${p.lifecycle}`}>{p.lifecycle}</span>
                </td>
                <td>
                  {p.generation} · owner {p.owner ?? "—"}
                </td>
                <td>{p.admitted}</td>
                <td>{p.admitted - p.consumed - p.cancelled}</td>
                <td>{attention(p)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {view.data && processes.length === 0 && (
          <p>No visible processes match this page and filter.</p>
        )}
      </div>
      <footer>
        Durable evidence, bounded observations. Station and HTTP connector interpretations are not
        available in this release.
      </footer>
    </main>
  );
}
