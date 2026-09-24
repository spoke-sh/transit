import { createFileRoute, Link, Outlet, useMatchRoute } from "@tanstack/react-router";
import { useObservation, useStateObservation } from "../state";
import { StateEvidence } from "../resources";
import { Evidence, EventTable, Journey, present, ProcessFacts, text } from "../components";
const tabs = [
  "process",
  "mailbox",
  "outbox",
  "effects",
  "payloads",
  "history",
  "associations",
] as const;
type Tab = (typeof tabs)[number];
const labels = {
  process: "Process",
  associations: "State",
  mailbox: "Arrivals",
  outbox: "Departures",
  effects: "Effects",
  payloads: "Payloads",
  history: "History",
};
export const Route = createFileRoute("/processes/$pid")({
  validateSearch: (search: Record<string, unknown>): { tab: Tab } => ({
    tab: tabs.includes(search.tab as Tab) ? (search.tab as Tab) : "process",
  }),
  component: ProcessRoute,
});
function ProcessRoute() {
  const matchRoute = useMatchRoute();
  if (matchRoute({ to: "/processes/$pid/journey" })) return <Outlet />;
  return <ProcessPage />;
}
function ProcessPage() {
  const { pid } = Route.useParams();
  const { tab } = Route.useSearch();
  const navigate = Route.useNavigate();
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
          {data.observation.effects.filter(present).map((effect) => (
            <article key={effect.id}>
              <h3>
                Effect {effect.id} · {effect.phase.replaceAll("_", " ")}
              </h3>
              <p>
                Attempt {effect.attempt ?? "not authorized"} · observations {effect.observations} /{" "}
                {effect.max_observations} · reconciliation deadline{" "}
                {effect.reconcile_before_ms ?? "unlimited"}
              </p>
              <p>Closed at {effect.closed_at ?? "not closed"}</p>
              <details>
                <summary>Recorded intent and outcome</summary>
                <pre>{text(effect.payload)}</pre>
                <p>{effect.result === null ? "No established outcome" : text(effect.result)}</p>
              </details>
            </article>
          ))}
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
                {payload.bytes} bytes · deletion{" "}
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
