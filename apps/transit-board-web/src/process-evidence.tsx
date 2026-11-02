import { getRouteApi, Link } from "@tanstack/react-router";
import { useObservation, useStateObservation } from "./inspection-state";
import {
  attention,
  Evidence,
  EventTable,
  Journey,
  present,
  ProcessFacts,
  text,
} from "./components";
import { ByteSize } from "./quantity";
import { QueryDiagnostic } from "./query-diagnostic";
import { StateEvidence, Resources } from "./resources";
import { tabs, type Tab } from "./process-tabs";

export function Overview() {
  const view = useObservation("processes");
  const { status, sort } = getRouteApi("/").useSearch();
  const navigate = getRouteApi("/").useNavigate();
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

const labels = {
  process: "Process",
  associations: "State",
  mailbox: "Arrivals",
  outbox: "Departures",
  effects: "Effects",
  payloads: "Payloads",
  history: "History",
};

export function ProcessPage() {
  const { pid } = getRouteApi("/processes/$pid").useParams();
  const { tab } = getRouteApi("/processes/$pid").useSearch();
  const navigate = getRouteApi("/processes/$pid").useNavigate();
  return (
    <main>
      <Link to="/" search={{ status: "all", sort: "pid" }}>
        ← All processes
      </Link>
      <p className="eyebrow">PROCESS RECORD</p>
      <h1>PID {pid}</h1>
      <nav className="tabs" aria-label="Process evidence">
        {tabs.map((value) => (
          <button
            key={value}
            aria-current={tab === value ? "page" : undefined}
            onClick={() => void navigate({ search: { tab: value } })}
          >
            {labels[value]}
          </button>
        ))}
        <Link to="/processes/$pid/journey" params={{ pid }} search={{ tab: "process" }}>
          Journey
        </Link>
      </nav>
      {tab === "associations" ? (
        <Associations key={pid} pid={Number(pid)} />
      ) : (
        <Resource key={`${pid}-${tab}`} pid={Number(pid)} tab={tab} />
      )}
    </main>
  );
}
function Resource({ pid, tab }: { pid: number; tab: Exclude<Tab, "associations"> }) {
  const view = useObservation(tab, pid);
  const data = view.data;
  const process = data?.observation.processes[0];
  return (
    <>
      <Evidence view={view} />
      {process && <ProcessFacts process={process} />}
      {data && (tab === "mailbox" || tab === "history") && (
        <EventTable events={data.observation.events.filter(present)} />
      )}
      {data && tab === "outbox" && (
        <>
          <h2>Committed departures</h2>
          <p>
            Delivered means destination admission, not destination turn completion. Only routes with
            both endpoints authorized are disclosed.
          </p>
          {data.observation.outbox.filter(present).map((output) => (
            <article key={output.id}>
              <h3>
                Output {output.id} →{" "}
                <Link
                  to="/processes/$pid"
                  params={{ pid: String(output.destination) }}
                  search={{ tab: "mailbox" }}
                >
                  PID {output.destination}
                </Link>
              </h3>
              <p>
                {output.phase} · source turn {output.turn} · resolved at{" "}
                {output.resolved_at ?? "not yet recorded"}
              </p>
              <details>
                <summary>Message bytes</summary>
                <pre>{text(output.value)}</pre>
              </details>
            </article>
          ))}
          <Journey data={data} />
        </>
      )}
      {data && tab === "effects" && (
        <>
          <h2>External work evidence</h2>
          <p>
            Authorization is not proof of a network send. Closed-unknown does not mean remote
            failure or cancellation.
          </p>
          {data.effectDiagnosticsInvalid && (
            <p>
              Some effect diagnostic detail is unavailable. The recorded effect state remains
              visible.
            </p>
          )}
          {data.observation.effects.map(
            (effect, index) =>
              effect && (
                <article key={effect.id}>
                  <h3>
                    Effect {effect.id} · {effect.phase.replaceAll("_", " ")}
                  </h3>
                  <p>
                    Attempt {effect.attempt ?? "not authorized"} · observations{" "}
                    {effect.observations} / {effect.max_observations} · reconciliation deadline{" "}
                    {effect.reconcile_before_ms ?? "unlimited"}
                  </p>
                  <p>Closed at {effect.closed_at ?? "not closed"}</p>
                  {effect.closure && (
                    <p>
                      Closure reason: {effect.closure.reason.replaceAll("_", " ")} · principal{" "}
                      {effect.closure.principal} · policy revision {effect.closure.policy_revision}
                    </p>
                  )}
                  {data.effect_diagnostics[index] && (
                    <QueryDiagnostic
                      value={data.effect_diagnostics[index]}
                      label="Effect diagnostic"
                    />
                  )}
                  <details>
                    <summary>Recorded intent and outcome</summary>
                    <pre>{text(effect.payload)}</pre>
                    <p>{effect.result === null ? "No established outcome" : text(effect.result)}</p>
                  </details>
                </article>
              ),
          )}
        </>
      )}
      {data && tab === "payloads" && (
        <>
          <h2>Payload lifecycle metadata</h2>
          <p>Metadata only. No raw blob access or guarantee of erasure from other copies.</p>
          {data.observation.payloads.filter(present).map((payload) => (
            <article key={payload.id}>
              <h3>
                Payload {payload.id} · {payload.phase}
              </h3>
              <p>
                <ByteSize value={payload.bytes} /> · deletion{" "}
                {payload.allow_delete ? "opted in" : "not authorized"} · retired{" "}
                {payload.retired_at ?? "—"} · deleted {payload.deleted_at ?? "—"}
              </p>
            </article>
          ))}
        </>
      )}
    </>
  );
}

function Associations({ pid }: { pid: number }) {
  const view = useStateObservation("associations", pid);
  return (
    <>
      <StateEvidence view={view} />
      <h2>State associations</h2>
      <p>
        Names locate resources; they do not grant access or imply lifetime ownership. Only
        authorized associations are shown.
      </p>
      {view.data?.observation.associations.filter(present).map((a) => (
        <article key={a.revision}>
          <h3>{text(a.name)}</h3>
          <p>
            {a.required ? "Required for recovery" : "Optional"} · association revision {a.revision}
          </p>
          <Link to="/resources" search={{ resource: a.resource }}>
            Resource {a.resource}
          </Link>
        </article>
      ))}
    </>
  );
}

export function JourneyPage() {
  const { pid } = getRouteApi("/processes/$pid/journey").useParams();
  const view = useObservation("journey", Number(pid));
  return (
    <main>
      <Link to="/processes/$pid" params={{ pid }} search={{ tab: "process" }}>
        ← Process record
      </Link>
      <p className="eyebrow">DURABLE SEQUENCE / CAUSAL LINKS</p>
      <h1>PID {pid} · journey</h1>
      <Evidence view={view} />
      {view.data && (
        <>
          <Journey data={view.data} />
          <EventTable events={view.data.observation.events.filter(present)} />
        </>
      )}
      <p>
        <Link to="/processes/$pid" params={{ pid }} search={{ tab: "outbox" }}>
          Follow departures to other processes →
        </Link>
      </p>
    </main>
  );
}

export function ResourcePage() {
  const { resource } = getRouteApi("/resources").useSearch();
  return (
    <main>
      <Link to="/" search={{ status: "all", sort: "pid" }}>
        ← Processes
      </Link>
      <p className="eyebrow">STATE RESOURCES</p>
      <h1>{resource === undefined ? "Durable state" : `Resource ${resource}`}</h1>
      <p>Authorized resource metadata, lifetime contracts and committing-turn evidence.</p>
      {resource !== undefined && (
        <Link to="/resources" search={{}}>
          All authorized resources
        </Link>
      )}
      <Resources key={resource ?? "all"} resource={resource} />
    </main>
  );
}
