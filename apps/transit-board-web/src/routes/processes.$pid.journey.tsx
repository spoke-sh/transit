import { createFileRoute, Link } from "@tanstack/react-router";
import { useObservation } from "../state";
import { Evidence, EventTable, Journey, present } from "../components";
export const Route = createFileRoute("/processes/$pid/journey")({ component: Page });
function Page() {
  const { pid } = Route.useParams();
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
