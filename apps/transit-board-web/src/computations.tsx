import { useEffect, useId, useRef, useState } from "react";
import { Link } from "@tanstack/react-router";
import { DataCatalog, type CatalogNamespaces } from "@transit/board-client/catalog";
import {
  positiveRevision,
  type ComputationSelection,
  type ComputationResponse,
} from "@transit/board-client/computations";
import { ComputationOwner, initialComputation } from "./computation-owner";
import { useRead } from "./use-observation";
import { ReadStatus } from "./read-status";
import { InspectorPanel, useInspector } from "./workbench-layout";
import { datasetLink } from "./dataset-selection";
import { ByteSize } from "./quantity";
import "./computations.css";
const catalog = new DataCatalog();
const count = (value: string) => BigInt(value).toLocaleString();
export function Computations() {
  const [cursor, setCursor] = useState<CatalogNamespaces["next"]>(null);
  const [namespace, setNamespace] = useState<number | null>(null);
  const [name, setName] = useState("");
  const [selected, setSelected] = useState<{
    selection: ComputationSelection;
    generation: number;
  } | null>(null);
  const schemas = useRead(
    JSON.stringify(["computation-schemas", cursor]),
    (signal) => catalog.namespaces(cursor, signal),
    0,
  );
  if (!schemas.value)
    return (
      <ReadStatus failure={schemas.failure} retry={schemas.retry} subject="Computation schemas" />
    );
  const entries = schemas.value.entries.filter((entry) => entry !== null);
  const schema = namespace ?? entries[0]?.id ?? null;
  return (
    <>
      <form
        className="workbench-toolbar"
        onSubmit={(event) => {
          event.preventDefault();
          if (schema !== null && name.trim())
            setSelected((previous) => ({
              selection: { namespace: schema, name: name.trim(), expected: null },
              generation: (previous?.generation ?? 0) + 1,
            }));
        }}
      >
        <label>
          Computation schema{" "}
          <select
            value={schema ?? ""}
            onChange={(event) => setNamespace(Number(event.target.value))}
          >
            {entries.map((entry) => (
              <option key={entry.id} value={entry.id}>
                {entry.name}
              </option>
            ))}
          </select>
        </label>
        <button
          type="button"
          disabled={cursor === null}
          onClick={() => {
            setCursor(null);
            setNamespace(null);
          }}
        >
          First schemas
        </button>
        <button
          type="button"
          disabled={schemas.value.next === null}
          onClick={() => {
            setCursor(schemas.value!.next);
            setNamespace(null);
          }}
        >
          More schemas
        </button>
        <label>
          Computation name{" "}
          <input value={name} maxLength={63} onChange={(event) => setName(event.target.value)} />
        </label>
        <button disabled={schema === null || !name.trim()}>Inspect</button>
      </form>
      <p>
        Choose a published finite Table computation. Inspection reads definitions and completion
        evidence.
      </p>
      {selected && <Computation key={selected.generation} selection={selected.selection} />}
    </>
  );
}
function Computation({ selection }: { selection: ComputationSelection }) {
  const [state, setState] = useState(initialComputation);
  const owner = useRef<ComputationOwner | null>(null);
  const [revision, setRevision] = useState("");
  const inspector = useInspector();
  const id = useId();
  useEffect(() => {
    const next = new ComputationOwner(selection, setState);
    owner.current = next;
    const visibility = () => next.visibility(document.hidden);
    visibility();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      next.dispose();
      owner.current = null;
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [selection]);
  const current = state.current.value;
  useEffect(() => {
    if (!current) inspector.release(id);
  }, [current, id, inspector.release]);
  useEffect(() => () => inspector.release(id), [id, inspector.release]);
  if (state.failure || !current)
    return (
      <ReadStatus
        failure={state.failure ?? state.current.failure}
        retry={() => owner.current?.retry()}
        subject="Computation"
      />
    );
  const observed = current.current!;
  const completed = state.revision === null ? current.completed : state.selected.value?.completed;
  const nodes = [
    { key: "source", label: "Source Table", binding: current.source },
    { key: "computation", label: "Computation", binding: current.binding },
    { key: "output", label: "Output Table", binding: current.output },
  ];
  const selected =
    inspector.selection?.owner === id
      ? nodes.find((node) => node.key === inspector.selection?.metric)
      : null;
  const choose = (key: string, button: HTMLButtonElement) =>
    inspector.select(
      { owner: id, kind: "computation", metric: key, dimension: "definition" },
      button,
    );
  return (
    <section className="computation-evidence" aria-label={`Computation ${current.binding.name}`}>
      <div className="workbench-toolbar">
        <h3>{current.binding.name}</h3>
        <button onClick={() => owner.current?.retry()}>Refresh computation</button>
      </div>
      <div className="computation-diagram" role="group" aria-label="Declared computation flow">
        {nodes.map((node, index) => (
          <div className="computation-node" key={node.key}>
            {index > 0 && (
              <span className="computation-edge">
                {index === 1 ? "Declared input →" : "Declared output →"}
              </span>
            )}
            <button
              aria-pressed={selected?.key === node.key}
              onClick={(event) => choose(node.key, event.currentTarget)}
            >
              <small>{node.label}</small>
              <strong>{node.binding.name}</strong>
            </button>
          </div>
        ))}
      </div>
      <p>
        Edges show declared relationships. Each Table link opens current metadata with its own
        observation basis.
      </p>
      <div className="workbench-grid">
        <table>
          <caption>Declared source, computation and output</caption>
          <thead>
            <tr>
              <th>Role</th>
              <th>Name</th>
              <th>Object</th>
              <th>Definition</th>
            </tr>
          </thead>
          <tbody>
            {nodes.map((node) => (
              <tr key={node.key} data-selected={selected?.key === node.key}>
                <th scope="row">
                  <button
                    aria-pressed={selected?.key === node.key}
                    onClick={(event) => choose(node.key, event.currentTarget)}
                  >
                    {node.label}
                  </button>
                </th>
                <td>{node.binding.name}</td>
                <td>{node.binding.interpretation.object.object}</td>
                <td>{node.binding.interpretation.revision}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="computation-summaries">
        <section aria-label="Last completed result">
          <h4>Last completed result</h4>
          {current.completed ? (
            <p>
              Revision {count(current.completed.revision)} · Completed ·{" "}
              {count(current.completed.rows)} rows
            </p>
          ) : (
            <p>No completed result</p>
          )}
          <p>A committed result describes its recorded source basis.</p>
        </section>
        <section aria-label="Current computation">
          <h4>Current computation</h4>
          <dl>
            <dt>Control</dt>
            <dd>{observed.state}</dd>
            <dt>Control epoch</dt>
            <dd>{count(observed.epoch)}</dd>
            <dt>Pending work</dt>
            <dd>{observed.pending ? `Attempt ${count(observed.attempt)}` : "None observed"}</dd>
            <dt>Blocked reason</dt>
            <dd>
              {observed.blocked === "none"
                ? "None observed"
                : observed.blocked.replaceAll("_", " ")}
            </dd>
            <dt>Observed control position</dt>
            <dd>
              Partition {observed.position.partition} · next LSN {observed.position.next_lsn}
            </dd>
          </dl>
          <p>
            Active control and absence of pending work do not establish freshness or completion.
          </p>
        </section>
      </div>
      <form
        className="workbench-toolbar"
        onSubmit={(event) => {
          event.preventDefault();
          if (positiveRevision(revision)) owner.current?.select(revision);
        }}
      >
        <label>
          Retained revision{" "}
          <input
            inputMode="numeric"
            value={revision}
            maxLength={20}
            onChange={(event) => setRevision(event.target.value)}
          />
        </label>
        <button disabled={!positiveRevision(revision)}>Inspect revision</button>
        <button type="button" onClick={() => owner.current?.select(null)}>
          Latest completed
        </button>
      </form>
      <section aria-label="Selected result">
        <h4>
          {state.revision === null
            ? "Latest observed completion"
            : `Selected revision ${state.revision}`}
        </h4>
        {state.revision !== null && !state.selected.value ? (
          <ReadStatus
            failure={state.selected.failure}
            retry={() => owner.current?.select(state.revision)}
            subject="Retained revision"
          />
        ) : completed ? (
          <Completion value={completed} />
        ) : (
          <p>No completed result</p>
        )}
        <p>
          Selection creates no retention pin. A missing revision never substitutes current output
          rows.
        </p>
      </section>
      {selected && (
        <InspectorPanel
          owner={id}
          title={selected.binding.name}
          subtitle={selected.label}
          dimensions={[
            { id: "definition", label: "Definition" },
            { id: "evidence", label: "Evidence" },
          ]}
        >
          {inspector.selection?.dimension === "definition" ? (
            <>
              <Exact
                label="Definition identity"
                value={JSON.stringify(selected.binding.interpretation, null, 2)}
              />
              {selected.key === "computation" ? (
                <>
                  <h4>Declared SQL</h4>
                  <pre>{current.sql}</pre>
                </>
              ) : (
                <DatasetLink binding={selected.binding} />
              )}
            </>
          ) : selected.key === "computation" ? (
            <>
              <Exact label="Current observation" value={JSON.stringify(observed, null, 2)} />
              {completed && (
                <>
                  <Completion value={completed} />
                  <Exact
                    label="Verified completion evidence"
                    value={JSON.stringify(completed, null, 2)}
                  />
                </>
              )}
            </>
          ) : (
            <>
              <p>
                This identity is part of the computation's declaration. Current Table metadata is a
                separate read.
              </p>
              <DatasetLink binding={selected.binding} />
            </>
          )}
        </InspectorPanel>
      )}
    </section>
  );
}
function DatasetLink({ binding }: { binding: ComputationResponse["source"] }) {
  const link = datasetLink(binding);
  return (
    <Link to="/datasets/$object" params={{ object: link.object }} search={link.search}>
      Open current Table metadata
    </Link>
  );
}
function Completion({ value }: { value: NonNullable<ComputationResponse["completed"]> }) {
  return (
    <dl>
      <dt>Outcome</dt>
      <dd>Completed · {count(value.rows)} rows</dd>
      <dt>Source position</dt>
      <dd>
        Partition {value.source_position.partition} · next LSN {value.source_position.next_lsn}
      </dd>
      <dt>Decision position</dt>
      <dd>
        Partition {value.decision.position.partition} · next LSN {value.decision.position.next_lsn}
      </dd>
      <dt>Manifest size</dt>
      <dd>
        <ByteSize value={value.manifest.bytes} />
      </dd>
      <dt>Schema size</dt>
      <dd>
        <ByteSize value={value.schema.bytes} />
      </dd>
    </dl>
  );
}
function Exact({ label, value }: { label: string; value: string }) {
  const [copied, setCopied] = useState<string | null>(null);
  return (
    <div>
      <h4>{label}</h4>
      <pre>{value}</pre>
      <button
        onClick={() => {
          void navigator.clipboard?.writeText(value).then(
            () => setCopied(value),
            () => setCopied(null),
          );
        }}
      >
        Copy {label.toLowerCase()}
      </button>
      <span role="status">{copied === value ? "Copied." : ""}</span>
    </div>
  );
}
