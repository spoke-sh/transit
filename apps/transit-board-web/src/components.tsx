import { Link } from "@tanstack/react-router";
import type { Event, Process, Response } from "@rey/transit-board-client";
import type { useObservation } from "./state";
export const present = <T,>(value: T | null): value is T => value !== null;
export function text(hex: string): string {
  const bytes = new Uint8Array(hex.match(/../g)?.map((value) => parseInt(value, 16)) ?? []);
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    return `[binary: ${bytes.length} bytes]`;
  }
}
export function attention(p: Process): string {
  if (p.lifecycle !== "running") return `${p.lifecycle} · permanently retired`;
  if (p.control?.phase === "initializing") return "Initializing · handler activation blocked";
  if (p.control?.phase === "suspended") return "Suspended · bounded resumption window";
  if (p.failure) return `Blocked on input ${p.failure}`;
  if (p.admitted > p.consumed + p.cancelled)
    return p.owner === null ? "Waiting · no owner" : "Waiting · admitted input";
  return "No pending input";
}
export function Evidence({ view }: { view: ReturnType<typeof useObservation> }) {
  const page = view.data?.observation;
  return (
    <section className="evidence" aria-label="Observation evidence">
      <div role="status">
        {view.error && (
          <p className="warning">
            {view.error}
            {page ? " Last observation remains below; it is stale." : ""}
          </p>
        )}
        {!page && !view.error && <p>Reading authorized evidence…</p>}
        {page && (
          <>
            <p>
              <strong>{view.error ? "Stale" : "Observed"}</strong> · realm {page.realm} · position{" "}
              {page.cut.position} (exclusive) · policy {page.cut.policy_revision} · sampled at{" "}
              {view.observedAt}
            </p>
            <p>
              Retained from {page.cut.retained_from} ·{" "}
              {page.history === "prefix_reclaimed"
                ? "History prefix reclaimed — checkpoint state survives; earlier event detail is unavailable."
                : "History retained"}{" "}
              · {page.complete ? "End of this query" : "More matching records may follow"}
              {page.last_collection != null &&
                ` · Working catalogs have collected entries (latest operation ${page.last_collection}); absence does not mean an identity never existed.`}
            </p>
          </>
        )}
      </div>
      <div className="actions">
        <button onClick={view.reset}>Refresh from start</button>
        {page?.next != null && <button onClick={view.next}>Next evidence page</button>}
      </div>
      <small>
        {view.paginated
          ? "Pagination holds this observation; refresh starts a new cut."
          : "Polls every 5 seconds; backs off on errors. Observation time is not event time."}
      </small>
    </section>
  );
}
export function ProcessFacts({ process: p }: { process: Process }) {
  return (
    <>
      <div className="facts">
        <div>
          <span>Lifecycle</span>
          <strong>{p.lifecycle}</strong>
        </div>
        <div>
          <span>Activation</span>
          <strong>Generation {p.generation}</strong>
        </div>
        <div>
          <span>Owner</span>
          <strong>{p.owner ?? "Unassigned"}</strong>
        </div>
        <div>
          <span>State revision</span>
          <strong>{p.revision}</strong>
        </div>
        <div>
          <span>Admissions / consumed / cancelled</span>
          <strong>
            {p.admitted} / {p.consumed} / {p.cancelled}
          </strong>
        </div>
        <div>
          <span>Pending input</span>
          <strong>{p.admitted - p.consumed - p.cancelled}</strong>
        </div>
      </div>
      <p className="attention">{attention(p)}</p>
      <p className="muted">
        “Running” is the protocol lifecycle, not proof that a worker is executing. Expiry does not
        prove physical cleanup.
      </p>
      <dl>
        <dt>Work cutoff / settlement deadline (Unix ms)</dt>
        <dd>
          {p.work_before_ms ?? "Unlimited"} / {p.settle_before_ms ?? "Unlimited"}
        </dd>
        <dt>Working catalog collection</dt>
        <dd>
          {p.allow_collection ? "Opted in · identities never reused" : "Retain catalog evidence"}
        </dd>
        <dt>Execution phase</dt>
        <dd>{p.control?.phase ?? "ready"}</dd>
        {p.control?.resume_before_ms != null && (
          <>
            <dt>Resume before (Unix ms)</dt>
            <dd>{p.control.resume_before_ms}</dd>
          </>
        )}
        <dt>Turn authorization</dt>
        <dd>
          {p.turn_permit ? `Permit ${p.turn_permit.id}, input ${p.turn_permit.input}` : "None"}
        </dd>
      </dl>
      <p>
        <Link to="/processes/$pid" params={{ pid: String(p.pid) }} search={{ tab: "associations" }}>
          Inspect committed state resources
        </Link>
      </p>
      <details>
        <summary>Runtime binding evidence</summary>
        {p.binding ? (
          <pre>{JSON.stringify(p.binding, null, 2)}</pre>
        ) : (
          <p>No runtime binding recorded.</p>
        )}
      </details>
    </>
  );
}
export function EventTable({ events }: { events: Event[] }) {
  return (
    <div className="table-scroll">
      <table>
        <caption>Retained events in durable sequence order</caption>
        <thead>
          <tr>
            <th>Position</th>
            <th>Protocol event</th>
            <th>Disposition / explicit links</th>
            <th>Value preview</th>
          </tr>
        </thead>
        <tbody>
          {events.map((event) => (
            <tr key={event.position}>
              <td>{event.position}</td>
              <td>
                {event.kind}
                {event.failed ? " · failed" : ""}
              </td>
              <td>
                {event.mailbox_status ?? ""}
                {event.input != null && ` input ${event.input}`}
                {event.effect != null && ` effect ${event.effect}`}
                {event.output != null && ` output ${event.output}`}
                {event.generation != null && ` generation ${event.generation}`}
              </td>
              <td>
                {event.value === null ? (
                  "—"
                ) : (
                  <details>
                    <summary>{event.value.length / 2} bytes</summary>
                    <pre>{text(event.value)}</pre>
                  </details>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {events.length === 0 && (
        <p>
          No matching retained events in this page. Check continuation and retained coverage above.
        </p>
      )}
    </div>
  );
}
export function Journey({ data }: { data: Response }) {
  const edges = data.edges.filter(present);
  return (
    <section aria-label="Recorded journey">
      <h2>Recorded connections</h2>
      <p className="muted">
        Sequence lanes use explicit protocol references. Missing history stays missing; nearby
        positions do not imply causation.
      </p>
      {edges.length ? (
        <ol className="lanes">
          {edges.map((edge, index) => (
            <li key={`${edge.relation}-${edge.from.id}-${edge.to.id}-${index}`}>
              <span>
                <Link
                  to="/processes/$pid"
                  params={{ pid: String(edge.from.pid) }}
                  search={{ tab: "process" }}
                >
                  PID {edge.from.pid}
                </Link>{" "}
                · {edge.from.kind} {edge.from.id}
                <small>{edge.from_coverage.replaceAll("_", " ")}</small>
              </span>
              <span className="connection">
                <span aria-hidden="true">→</span>
                <small>{edge.relation.replaceAll("_", " ")}</small>
              </span>
              <span>
                <Link
                  to="/processes/$pid"
                  params={{ pid: String(edge.to.pid) }}
                  search={{ tab: "process" }}
                >
                  PID {edge.to.pid}
                </Link>{" "}
                · {edge.to.kind} {edge.to.id}
                <small>{edge.to_coverage.replaceAll("_", " ")}</small>
              </span>
            </li>
          ))}
        </ol>
      ) : (
        <p>No explicit connections in this page. Read departures for output-to-admission links.</p>
      )}
    </section>
  );
}
