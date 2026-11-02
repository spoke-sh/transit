import { useEffect, useState } from "react";
import { Link, useBlocker } from "@tanstack/react-router";
import { describeReads } from "@transit/query-client/read";
import { ResultPanel, useStatement } from "./workbench-result";
import { Workbench, WorkbenchBody, NavigatorToggle, useInspector } from "./workbench-layout";
import { FeatureAccess } from "./feature-access";
import { useMetadata, Unavailable } from "./data-metadata";
import "./workbench.css";
export function WorkbookPage() {
  return (
    <FeatureAccess feature="sql">
      <WorkbookPageContent />
    </FeatureAccess>
  );
}
function WorkbookPageContent() {
  const [cells, setCells] = useState([crypto.randomUUID()]);
  const [title, setTitle] = useState("Untitled investigation");
  const [connected, setConnected] = useState(false);
  const [dirty, setDirty] = useState(false);
  useBlocker({
    shouldBlockFn: () =>
      dirty && !window.confirm("Discard this unsaved workbook and close its results?"),
    enableBeforeUnload: dirty,
  });
  const connection = useMetadata("sql", (signal) => describeReads(signal));
  useEffect(() => {
    if (connection.value) setConnected(true);
  }, [connection.value]);
  return (
    <Workbench className="workbook" available={Boolean(connection.value)}>
      <div className="page-heading">
        <div>
          <p className="eyebrow">SESSION WORKBOOK · UNSAVED</p>
          <h1>Workbook</h1>
          <p>Narrative, SQL and observed results in one place.</p>
        </div>
        <div className="workbench-toolbar">
          <NavigatorToggle label="Cells" />
          <Link to="/catalog">Browse catalog →</Link>
        </div>
      </div>
      <p className="workbench-notice">
        Temporary session. Leaving this page discards its cells and closes its result views. Each
        Run has its own source basis.
      </p>
      {!connection.value && <Unavailable error={connection.error} retry={connection.retry} />}
      {connected && (
        <div hidden={!connection.value}>
          <div className="workbench-scope">
            <strong>{connection.value?.database}</strong>
            <span>{connection.value?.source ?? "Configured SQL namespace"}</span>
            <span>Read-only statements</span>
            <span>Up to {connection.value?.window_rows} rows per window</span>
          </div>
          <WorkbenchBody
            navigator={
              <>
                <p className="eyebrow">THIS WORKBOOK</p>
                <strong>{title}</strong>
                {cells.map((id, index) => (
                  <CellNavigation key={id} id={id} index={index} />
                ))}
                <p>Temporary session · up to four cells</p>
              </>
            }
          >
            <label className="workbook-title">
              Investigation title
              <input
                value={title}
                maxLength={160}
                onChange={(event) => {
                  setTitle(event.target.value);
                  setDirty(true);
                }}
              />
            </label>
            {cells.map((id, index) => (
              <WorkbookCell
                key={id}
                id={id}
                index={index}
                available={Boolean(connection.value)}
                edited={() => setDirty(true)}
                remove={() => {
                  setDirty(true);
                  setCells((previous) => previous.filter((value) => value !== id));
                }}
              />
            ))}
            <button
              disabled={cells.length >= 4}
              onClick={() => {
                setDirty(true);
                setCells((previous) => [...previous, crypto.randomUUID()]);
              }}
            >
              Add SQL cell
            </button>
            <p className="muted">
              Four active result readers are shared by this Board deployment. Close results when
              finished.
            </p>
          </WorkbenchBody>
        </div>
      )}
    </Workbench>
  );
}
function CellNavigation({ id, index }: { id: string; index: number }) {
  const { toggleNavigation } = useInspector();
  return (
    <button
      onClick={() => {
        toggleNavigation();
        requestAnimationFrame(() =>
          document.getElementById(`cell-${id}`)?.querySelector("textarea")?.focus(),
        );
      }}
    >
      Cell {index + 1}
    </button>
  );
}

function WorkbookCell({
  id,
  index,
  remove,
  edited,
  available,
}: {
  id: string;
  index: number;
  remove: () => void;
  edited: () => void;
  available: boolean;
}) {
  const [sql, setSql] = useState("SHOW TABLES");
  const [note, setNote] = useState("");
  const statement = useStatement(() => {
    setSql("");
    setNote("");
  }, available);
  return (
    <section id={`cell-${id}`} className="workbook-cell" aria-label={`SQL cell ${index + 1}`}>
      <div className="workbench-toolbar">
        <h2>Cell {index + 1}</h2>
        <span className="muted">Explicit Run</span>
        <button onClick={remove}>Remove cell</button>
      </div>
      <label>
        Investigation notes
        <textarea
          className="workbook-note"
          value={note}
          maxLength={8000}
          placeholder="What are you investigating?"
          onChange={(event) => {
            setNote(event.target.value);
            edited();
          }}
        />
      </label>
      <label>
        SQL
        <textarea
          className="workbook-sql"
          spellCheck={false}
          value={sql}
          maxLength={60000}
          onChange={(event) => {
            setSql(event.target.value);
            edited();
          }}
          onKeyDown={(event) => {
            if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
              event.preventDefault();
              if (!statement.busy && sql.trim()) void statement.run(sql);
            }
          }}
        />
      </label>
      <div className="workbench-toolbar">
        <button
          className="primary"
          disabled={statement.busy || !sql.trim()}
          onClick={() => void statement.run(sql)}
        >
          Run cell {index + 1}
        </button>
        <span className="muted">Ctrl / ⌘ Enter · SELECT, SHOW, DESCRIBE, EXPLAIN</span>
      </div>
      <ResultPanel state={statement} draft={sql} parent={`Cell ${index + 1}`} />
    </section>
  );
}
