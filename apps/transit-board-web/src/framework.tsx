import { Link } from "@tanstack/react-router";
import type { StateResponse } from "@transit/board-client";
import { present, text } from "./components";

type Lens = NonNullable<StateResponse["framework"][number]>;
function Pid({ id }: { id: number }) {
  return (
    <Link to="/processes/$pid" params={{ pid: String(id) }} search={{ tab: "process" }}>
      PID {id}
    </Link>
  );
}
function Declaration({ lens }: { lens: Lens }) {
  const d = lens.declaration;
  if ("behavior" in d)
    return (
      <>
        <h3>Station GenServer</h3>
        <p>
          Declared behavior v1 · <Pid id={lens.source.pid} />
        </p>
      </>
    );
  if ("table" in d)
    return (
      <>
        <h3>Table {text(d.table.object)}</h3>
        <p>
          Head revision {text(d.table.revision)} · {text(d.table.rows)} recorded rows ·{" "}
          {d.table.retired ? "Retired" : "Active"}
        </p>
        {d.table.pending !== null && <p>Pending operation {text(d.table.pending)}</p>}
        <p>
          Schema record {text(d.table.schema.record)} · {d.table.schema.bytes} bytes
        </p>
        <p>
          Schema publication digest:{" "}
          <code>{d.table.schema.digest.map((b) => b.toString(16).padStart(2, "0")).join("")}</code>
        </p>
      </>
    );
  if ("registry_scope" in d)
    return (
      <>
        <h3>Registry scope {d.registry_scope.id}</h3>
        <p>
          Scoped to <Pid id={lens.source.pid} /> and this associated resource’s lifetime.
        </p>
      </>
    );
  if ("registry_binding" in d)
    return (
      <>
        <h3>Name: {text(d.registry_binding.name)}</h3>
        <p>
          Scope {d.registry_binding.scope} · binding revision {d.registry_binding.revision} ·{" "}
          {d.registry_binding.destination === null ? (
            "Unregistered tombstone"
          ) : (
            <Pid id={d.registry_binding.destination} />
          )}
        </p>
      </>
    );
  if ("child" in d)
    return (
      <>
        <h3>
          Supervised child: <Pid id={d.child.pid} />
        </h3>
        <p>
          {d.child.phase} · generation {d.child.generation} · retries {d.child.attempts}/
          {d.child.limit}
        </p>
        {d.child.retry_at_ms > 0 && (
          <p>Retry observation bound: {new Date(d.child.retry_at_ms).toISOString()}</p>
        )}
        {d.child.successor !== null && (
          <p>
            Explicit successor: <Pid id={d.child.successor} />
          </p>
        )}
      </>
    );
  if ("wait" in d)
    return (
      <>
        <h3>Call {text(d.wait.correlation)}</h3>
        <p>
          {d.wait.phase} · peer <Pid id={d.wait.target} /> ·{" "}
          {d.wait.deadline_ms === null
            ? "Unlimited wait"
            : `Timer deadline ${new Date(d.wait.deadline_ms).toISOString()}`}
        </p>
        {d.wait.resolution_input > 0 && <p>Closed by mailbox input {d.wait.resolution_input}</p>}
      </>
    );
  return <p>Unknown framework declaration; use the kernel records below.</p>;
}
export function Framework({ lenses }: { lenses: StateResponse["framework"] }) {
  const known = lenses.filter(present);
  if (!known.length) return null;
  return (
    <section aria-label="Station framework evidence">
      <h2>Station framework evidence</h2>
      <p>
        Versioned declarations from the records on this page. These describe framework state;
        execution authority remains with Transit.
      </p>
      {known.map((lens) => (
        <article key={lens.source.key}>
          <Declaration lens={lens} />
          <small>
            Source: <Pid id={lens.source.pid} /> · resource {lens.source.resource} revision{" "}
            {lens.source.resource_revision} · record revision {lens.source.entry_revision} ·
            observation {lens.source.position} · key <code>{lens.source.key}</code>
          </small>
        </article>
      ))}
    </section>
  );
}
