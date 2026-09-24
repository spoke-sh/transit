import { Link } from "@tanstack/react-router";
import type { StateResponse } from "@rey/transit-board-client";
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
        <h3>Table {d.table.id}</h3>
        <p>
          Schema v{d.table.schema_version} ·{" "}
          {d.table.columns
            .map((c) => `${text(c.name)}: ${c.data_type}${c.nullable ? " (nullable)" : ""}`)
            .join(" · ")}
        </p>
        <p>
          Source schema fingerprint:{" "}
          <code>{d.table.fingerprint.map((b) => b.toString(16).padStart(2, "0")).join("")}</code>
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
  if ("query" in d)
    return (
      <>
        <h3>
          {d.query.direction === "outgoing" ? "Captured" : "Received"} Arrow result {d.query.id}
        </h3>
        <p>
          {d.query.phase} · correlation {text(d.query.correlation)} · {d.query.rows} rows /{" "}
          {d.query.bytes} bytes
        </p>
        <p>
          Table {d.query.table} ·{" "}
          <Link to="/resources" search={{ resource: d.query.source_resource }}>
            source resource {d.query.source_resource}
          </Link>{" "}
          at revision {d.query.source_revision} · destination <Pid id={d.query.destination} />
        </p>
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
