import { useEffect, useState } from "react";
import { Link } from "@tanstack/react-router";
import { atlas, BoardError, type AtlasResponse } from "@rey/transit-board-client";
import { message, useScope } from "./state";
import { QueryWorkspace } from "./query-workspace";
import { UnifiedWorkspace } from "./unified-workspace";
import { LiveTable } from "./live-table";
import { Records } from "./records";
import "./atlas.css";

type Selection = { kind: "process" | "resource"; id: number };
type Cursor = { position: number; process_after?: number; resource_after?: number };
export function Atlas({
  initialEmphasis = "processes",
}: {
  initialEmphasis?: "processes" | "resources";
}) {
  const { scope, denied } = useScope();
  const [data, setData] = useState<AtlasResponse | null>(null);
  const [error, setError] = useState("");
  const [mode, setMode] = useState<"canvas" | "browse">("canvas");
  const [emphasis, setEmphasis] = useState(initialEmphasis);
  const [selection, setSelection] = useState<Selection | null>(null);
  const [entered, setEntered] = useState(false);
  const [workspace, setWorkspace] = useState<number | null>(null);
  // Keep the selected protocol stable across transient atlas reads. Switching
  // components would discard an uncertain signed query held by that workspace.
  // The workspace independently rechecks its query authorization.
  const [workspaceVersion, setWorkspaceVersion] = useState(1);
  const [recordResource, setRecordResource] = useState<number | null>(null);
  const [flat, setFlat] = useState(false);
  const [zoom, setZoom] = useState(1);
  const [cursor, setCursor] = useState<Cursor>();
  const [revision, setRevision] = useState(0);
  useEffect(() => {
    const abort = new AbortController();
    let timer: ReturnType<typeof setTimeout>;
    let disposed = false;
    let inFlight = false;
    async function refresh() {
      if (disposed || document.hidden || inFlight) return;
      inFlight = true;
      try {
        const next = await atlas(cursor, abort.signal);
        if (!disposed) {
          setData(next);
          setError("");
        }
      } catch (cause) {
        if (!disposed) {
          // A stale cut or denial cannot continue to authorize the old plot.
          setData(null);
          setError(message(cause));
          if (cause instanceof BoardError && cause.status === 403) denied();
        }
      } finally {
        inFlight = false;
        if (!disposed && !cursor) timer = setTimeout(() => void refresh(), 5000);
      }
    }
    const visibility = () => {
      clearTimeout(timer);
      if (document.hidden) setData(null);
      else void refresh();
    };
    void refresh();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      disposed = true;
      clearTimeout(timer);
      abort.abort();
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [cursor, revision, denied]);
  const processes = data?.processes.entries.filter((value) => value !== null) ?? [];
  const resources = data?.resources.entries.filter((value) => value !== null) ?? [];
  const selectedResource = resources.find(
    (resource) => selection?.kind === "resource" && selection.id === resource.id,
  );
  const selectedProcess = processes.find(
    (process) => selection?.kind === "process" && selection.id === process.pid,
  );
  const resourceButtons = resources.map((resource) => (
    <button
      key={resource.id}
      className={`landmark ${resource.id === data?.query_resource ? "table-landmark" : "kv-landmark"} ${selection?.kind === "resource" && selection.id === resource.id ? "selected" : ""}`}
      aria-label={`Select resource ${resource.id}`}
      aria-pressed={selection?.kind === "resource" && selection.id === resource.id}
      onClick={() => setSelection({ kind: "resource", id: resource.id })}
    >
      <span className="resource-roof" aria-hidden="true">
        <i />
        <i />
        <i />
        <i />
      </span>
      <strong>Resource {resource.id}</strong>
      <span>
        {resource.id === data?.query_resource
          ? data?.query_version === 2
            ? "Query source"
            : "Table service"
          : "KV backing resource"}
      </span>
      <small>
        {resource.entries} current keys · writer {resource.writer}
      </small>
      <small>Size relief unavailable</small>
    </button>
  ));
  return (
    <main className="atlas-main">
      <nav aria-label="Board navigation">
        <Link to="/" search={{ status: "all", sort: "pid" }}>
          Process directory
        </Link>
        {" · "}
        <Link to="/resources" search={{}}>
          Resource directory
        </Link>
      </nav>
      <div className="page-heading">
        <div>
          <p className="eyebrow">TRANSIT / AUTHORIZED NEIGHBORHOOD</p>
          <h1>{entered ? "Data workspace" : "Relief atlas"}</h1>
          <p>
            {entered
              ? "One draft. One identified result. Two views."
              : "Processes in the fabric. Resources on shared ground."}
          </p>
        </div>
        <div className="segmented" aria-label="View">
          <button aria-pressed={mode === "canvas"} onClick={() => setMode("canvas")}>
            Canvas
          </button>
          <button aria-pressed={mode === "browse"} onClick={() => setMode("browse")}>
            Browse
          </button>
        </div>
      </div>
      {workspace !== null && workspaceVersion === 2 && (
        <UnifiedWorkspace
          resource={workspace}
          mode={mode}
          visible={entered}
          onBack={() => setEntered(false)}
        />
      )}
      {workspace !== null && workspaceVersion !== 2 && (
        <QueryWorkspace
          resource={workspace}
          mode={mode}
          visible={entered}
          onBack={() => setEntered(false)}
        />
      )}
      {!entered && scope?.reactive_table && <LiveTable />}
      {!entered && (
        <>
          <div className="atlas-toolbar">
            <div className="segmented" aria-label="Emphasis">
              <button
                aria-pressed={emphasis === "processes"}
                onClick={() => setEmphasis("processes")}
              >
                Processes
              </button>
              <button
                aria-pressed={emphasis === "resources"}
                onClick={() => setEmphasis("resources")}
              >
                Resources
              </button>
            </div>
            <label>
              Detail{" "}
              <input
                aria-label="Detail zoom"
                type="range"
                min="1"
                max="3"
                step="1"
                value={zoom}
                onChange={(event) => setZoom(Number(event.target.value))}
              />
            </label>
            <button aria-pressed={flat} onClick={() => setFlat(!flat)}>
              Flat view
            </button>
            <button
              onClick={() => {
                setZoom(1);
                setFlat(false);
              }}
            >
              Reset view
            </button>
            <button
              onClick={() => {
                setCursor(undefined);
                setRevision(revision + 1);
              }}
            >
              Refresh observation
            </button>
          </div>
          <p className="atlas-evidence" role="status">
            {error ||
              (data
                ? `Authority position ${data.position} · ${processes.length} processes and ${resources.length} resources on this page · ${cursor ? "Pinned observation" : "Refreshes every 5 seconds"}`
                : "Reading current inspection scope…")}
          </p>
          {data && (
            <div className="atlas-layout">
              <section
                className={`atlas-surface ${emphasis} ${flat || zoom > 1 ? "flat" : "relief"} detail-${zoom}`}
                aria-label="Authorized neighborhood"
              >
                {mode === "canvas" ? (
                  <>
                    <div className="resource-district">{resourceButtons}</div>
                    <div className="process-fabric">
                      {processes.map((process) => {
                        const pending = process.admitted - process.consumed - process.cancelled;
                        return (
                          <button
                            key={process.pid}
                            aria-label={`Select process ${process.pid}`}
                            className={`process-tile ${selection?.kind === "process" && selection.id === process.pid ? "selected" : ""}`}
                            onClick={() => setSelection({ kind: "process", id: process.pid })}
                          >
                            <span
                              className={`inbox-shoulder ${pending ? "raised" : ""}`}
                              aria-hidden="true"
                            />
                            <span className="outbox-well" aria-hidden="true" />
                            <strong>PID {process.pid}</strong>
                            <span>{pending} waiting inputs</span>
                            <small>{process.lifecycle} · outbox count unavailable</small>
                          </button>
                        );
                      })}
                    </div>
                  </>
                ) : (
                  <div className="atlas-browse">
                    <h2>Processes</h2>
                    <table>
                      <thead>
                        <tr>
                          <th>PID</th>
                          <th>Lifecycle</th>
                          <th>Waiting inputs</th>
                          <th>Generation</th>
                        </tr>
                      </thead>
                      <tbody>
                        {processes.map((process) => (
                          <tr key={process.pid}>
                            <td>
                              <button
                                onClick={() => setSelection({ kind: "process", id: process.pid })}
                              >
                                {process.pid}
                              </button>
                            </td>
                            <td>{process.lifecycle}</td>
                            <td>{process.admitted - process.consumed - process.cancelled}</td>
                            <td>{process.generation}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                    <h2>Resources</h2>
                    <div className="resource-district">{resourceButtons}</div>
                  </div>
                )}
                {!processes.length && !resources.length && (
                  <p>No visible entries on this bounded page.</p>
                )}
              </section>
              <aside className="atlas-inspector" aria-label="Selection">
                <p className="eyebrow">EVIDENCE / SELECTION</p>
                {selectedResource ? (
                  <>
                    <h2>Resource {selectedResource.id}</h2>
                    <dl>
                      <dt>Writer</dt>
                      <dd>PID {selectedResource.writer}</dd>
                      <dt>Lifetime owner</dt>
                      <dd>
                        {selectedResource.owner === null
                          ? "Independent"
                          : `PID ${selectedResource.owner}`}
                      </dd>
                      <dt>Revision</dt>
                      <dd>{selectedResource.revision}</dd>
                      <dt>Phase</dt>
                      <dd>{selectedResource.phase}</dd>
                      <dt>Current keys</dt>
                      <dd>{selectedResource.entries}, including framework records</dd>
                      <dt>Decoded value bytes</dt>
                      <dd>Unavailable</dd>
                    </dl>
                    <button onClick={() => setRecordResource(selectedResource.id)}>
                      Inspect records
                    </button>
                    {scope?.query_enabled && selectedResource.id === data.query_resource ? (
                      <button
                        className="primary"
                        onClick={() => {
                          setWorkspace(selectedResource.id);
                          setWorkspaceVersion(data.query_version ?? 1);
                          setEntered(true);
                        }}
                      >
                        Enter resource
                      </button>
                    ) : (
                      <p>
                        Generic resource inspection. No query adapter is configured for this
                        resource.
                      </p>
                    )}
                  </>
                ) : selectedProcess ? (
                  <>
                    <h2>PID {selectedProcess.pid}</h2>
                    <dl>
                      <dt>Lifecycle</dt>
                      <dd>{selectedProcess.lifecycle}</dd>
                      <dt>Generation</dt>
                      <dd>{selectedProcess.generation}</dd>
                      <dt>Admitted inputs</dt>
                      <dd>{selectedProcess.admitted}</dd>
                      <dt>Consumed inputs</dt>
                      <dd>{selectedProcess.consumed}</dd>
                      <dt>Cancelled inputs</dt>
                      <dd>{selectedProcess.cancelled}</dd>
                    </dl>
                  </>
                ) : (
                  <>
                    <h2>Explore the neighborhood</h2>
                    <p>
                      Select a process or resource. Enter a configured Table to compose a query.
                    </p>
                  </>
                )}
                <p className="muted">
                  Each resource has one plot. Associations do not imply active traffic. Inbox
                  markers show whether a backlog exists; heights are not a scale. Outbox depth, byte
                  heights and ages have no measurement in this profile.
                </p>
              </aside>
            </div>
          )}
          {data && (
            <div className="atlas-pagination">
              <button
                disabled={data.processes.next === null}
                onClick={() =>
                  setCursor({
                    ...cursor,
                    position: data.position,
                    process_after: data.processes.next ?? undefined,
                  })
                }
              >
                Next process page
              </button>
              <button
                disabled={data.resources.next === null}
                onClick={() =>
                  setCursor({
                    ...cursor,
                    position: data.position,
                    resource_after: data.resources.next ?? undefined,
                  })
                }
              >
                Next resource page
              </button>
              <span>Bounded pages, not global totals.</span>
            </div>
          )}
        </>
      )}
      {data &&
        recordResource !== null &&
        resources.some((resource) => resource.id === recordResource) && (
          <Records key={recordResource} resource={recordResource} />
        )}
    </main>
  );
}
