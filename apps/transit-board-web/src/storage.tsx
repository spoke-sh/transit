import { useEffect, useId, useState } from "react";
import { Link } from "@tanstack/react-router";
import {
  DataCatalog,
  relationalQuery,
  storage,
  type CatalogEntry,
  type CatalogNamespaces,
  type CatalogStorage,
  type CatalogTables,
  type RelationalDescription,
} from "@transit/board-client";
import { QueryError } from "@transit/query-client";
import { useRead } from "./use-observation";
import { useScope } from "./state";
import { ReadStatus } from "./read-status";
import { InspectorPanel, useInspector } from "./workbench-layout";
import { positionPercent, type StorageFact } from "./storage-model";
import "./storage.css";
import { bytes, byteAllowance, formatBytes } from "./quantities";
import { ByteSize, ExactBytes } from "./quantity";
import { maintenanceFacts } from "./maintenance-model";

const quota = (used: number | null | undefined, limit: number | null | undefined) =>
  used != null && limit != null && limit > 0
    ? {
        percent: byteAllowance(used, limit).percent,
        scale: byteAllowance(used, limit).text,
        byteLimit: limit,
      }
    : {};

/** Both views and the inspector project one observation; selection retains only a key. */
function Evidence({ title, basis, facts }: { title: string; basis: string; facts: StorageFact[] }) {
  const owner = useId();
  const { selection, select, release } = useInspector();
  useEffect(() => () => release(owner), [owner, release]);
  const selected = selection?.owner === owner ? selection.metric : undefined;
  const fact = facts.find((item) => item.key === selected);
  return (
    <section className="storage-evidence" aria-label={title}>
      <h3>{title}</h3>
      <p className="storage-basis">{basis}</p>
      {facts.some((item) => item.percent !== undefined || item.visual) && (
        <div className="storage-visual" role="group" aria-label={`${title} visualization`}>
          {facts
            .filter((item) => item.percent !== undefined || item.visual)
            .map((item) => (
              <button
                key={item.key}
                aria-pressed={selected === item.key}
                onClick={(event) =>
                  select(
                    { owner, kind: "storage", dimension: "evidence", metric: item.key },
                    event.currentTarget,
                  )
                }
              >
                <span>{item.label}</span>
                <strong
                  aria-label={
                    item.byteValue != null ? formatBytes(item.byteValue).accessible : undefined
                  }
                >
                  {item.value}
                </strong>
                {item.percent !== undefined && (
                  <span className="storage-track" aria-hidden="true">
                    <span style={{ width: `${item.percent}%` }} />
                  </span>
                )}
                {item.scale && <small>{item.scale}</small>}
              </button>
            ))}
        </div>
      )}
      <div className="workbench-grid">
        <table>
          <caption>{title} · observed values</caption>
          <thead>
            <tr>
              <th>Measure</th>
              <th>Observed value</th>
            </tr>
          </thead>
          <tbody>
            {facts.map((item) => (
              <tr key={item.key} data-selected={selected === item.key}>
                <th scope="row">
                  <button
                    aria-pressed={selected === item.key}
                    onClick={(event) =>
                      select(
                        { owner, kind: "storage", dimension: "evidence", metric: item.key },
                        event.currentTarget,
                      )
                    }
                  >
                    {item.label}
                  </button>
                </th>
                <td>
                  {item.byteValue != null ? <ByteSize value={item.byteValue} /> : item.value}
                  {item.qualifier && <span> · {item.qualifier}</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {fact && (
        <InspectorPanel
          owner={owner}
          title={fact.label}
          subtitle={title}
          summary={basis}
          dimensions={[{ id: "evidence", label: "Evidence" }]}
        >
          <p className="storage-exact">{fact.value}</p>
          {fact.byteValue != null && <ExactBytes value={fact.byteValue} />}
          {fact.byteLimit != null && (
            <p>
              <ExactBytes value={fact.byteLimit} label="Configured limit" />
            </p>
          )}
          {fact.milliseconds !== undefined && (
            <p>Exact duration: {fact.milliseconds.toLocaleString()} milliseconds</p>
          )}
          <p>{fact.explanation}</p>
          {fact.scale && (
            <p>
              Visual scale: {fact.scale}. The drawing is rounded and capped at the scale. Byte
              labels marked ≈ are rounded; exact counts remain available in the details.
            </p>
          )}
        </InspectorPanel>
      )}
    </section>
  );
}

export function Storage() {
  const { scope } = useScope();
  const state = useRead(`storage/${scope?.realm}`, storage);
  const page = state.value;
  const basis = `Realm ${page?.realm} · authority position ${page?.position}. Live counters have independent observation times.`;
  return (
    <section aria-label="Storage observation">
      <div className="workbench-toolbar">
        <h2>Storage</h2>
        <button onClick={state.retry}>Refresh storage</button>
      </div>
      {!page ? (
        <ReadStatus failure={state.failure} retry={state.retry} subject="Storage" />
      ) : (
        <>
          <Evidence
            title="Capacity and allocation"
            basis={basis}
            facts={[
              {
                key: "backend",
                label: "Backend",
                value: page.backend,
                explanation: "Storage backend reported by the authorized node inspection.",
              },
              {
                key: "root",
                label: "Data root",
                value: page.root ?? "Unavailable",
                explanation: "Reported data root; Board does not access provider files.",
              },
              {
                key: "allocated",
                label: "Accounted storage",
                value: bytes(page.allocated_bytes),
                byteValue: page.allocated_bytes,
                explanation:
                  "Backend accounting, not total disk usage. An unavailable counter is not zero.",
                ...quota(page.allocated_bytes, page.limits?.bytes),
              },
              {
                key: "limit",
                label: "Ordinary storage limit",
                value: bytes(page.limits?.bytes),
                byteValue: page.limits?.bytes,
                explanation:
                  "Configured ordinary storage allowance. Capacity pressure does not authorize expiry.",
              },
              {
                key: "reserve",
                label: "Storage control reserve",
                value: bytes(page.limits?.control_bytes),
                byteValue: page.limits?.control_bytes,
                explanation:
                  "Separate allowance for control and recovery progress; not ordinary free capacity.",
              },
              {
                key: "data",
                label: "Direct request allocation",
                value: bytes(page.data_requests?.used),
                byteValue: page.data_requests?.used,
                explanation:
                  "Current accounted direct request allocations. Excludes process stacks, sockets and filesystem caches.",
                ...quota(page.data_requests?.used, page.data_requests?.limit),
              },
              {
                key: "data-peak",
                label: "Direct request peak",
                value: bytes(page.data_requests?.peak),
                byteValue: page.data_requests?.peak,
                explanation: "Peak request allocation since the owner started; not a time series.",
              },
              {
                key: "control",
                label: "Recovery request allocation",
                value: bytes(page.control_requests?.used),
                byteValue: page.control_requests?.used,
                explanation:
                  "Current accounted recovery request allocations, independent of direct requests.",
                ...quota(page.control_requests?.used, page.control_requests?.limit),
              },
              {
                key: "control-peak",
                label: "Recovery request peak",
                value: bytes(page.control_requests?.peak),
                byteValue: page.control_requests?.peak,
                explanation: "Peak recovery request allocation since the owner started.",
              },
            ]}
          />
          <Evidence title="Maintenance" basis={basis} facts={maintenanceFacts(page)} />
        </>
      )}
    </section>
  );
}

export function TableStorageView({ page }: { page: CatalogStorage }) {
  const value = page.observed;
  const identity = page.binding.interpretation.interpretation;
  const position = (
    key: string,
    label: string,
    current: string | null,
    explanation: string,
  ): StorageFact => ({
    key,
    label,
    value: current ?? "Unavailable",
    explanation,
    ...(current !== null
      ? {
          percent: positionPercent(current, value.position.next_lsn),
          scale: `Accepted next position ${value.position.next_lsn} · partition ${value.position.partition}`,
        }
      : {}),
  });
  return (
    <Evidence
      title={`Table storage · ${page.binding.name}`}
      basis={`Branch ${identity.object.branch} · object ${identity.object.object} · definition ${identity.revision} · partition ${value.position.partition}. Independent current facts; no query or snapshot pin is created.`}
      facts={[
        position(
          "accepted",
          "Accepted next position",
          value.position.next_lsn,
          "Next accepted log position. This is a partition-local coordinate, not a row count or a wall-clock time.",
        ),
        position(
          "changed",
          "Logical change position",
          value.changed_lsn,
          "Last logical change reported for this Table. Storage maintenance can advance independently.",
        ),
        position(
          "archive",
          "Archived through",
          value.archive_through,
          "Reported archive frontier. It does not imply that old segments or retained history can be deleted.",
        ),
        position(
          "recovery",
          "Recovery checkpoint",
          value.recovery_through,
          "Reported recovery frontier. Unavailable means no checkpoint was reported, not position zero.",
        ),
        position(
          "history",
          "History floor",
          value.history_floor,
          "Reported retained history floor. This observation does not pin history.",
        ),
        {
          key: "live",
          label: "Live rows",
          value: value.live_rows,
          explanation:
            "Current logical row count at this storage observation, independent of any SQL result.",
        },
        {
          key: "pending-rows",
          label: "Pending rows",
          value: `${value.pending_rows} rows · ${value.pending_complete ? "complete backlog" : "bounded prefix (lower bound)"}`,
          explanation:
            "At most 1,024 pending records are inspected. A bounded prefix is not a total backlog or a completion estimate.",
        },
        {
          key: "pending-bytes",
          label: "Pending data size",
          value: bytes(value.pending_bytes),
          byteValue: value.pending_bytes,
          qualifier: value.pending_complete ? "complete backlog" : "bounded prefix (lower bound)",
          explanation: `${value.pending_complete ? "Complete backlog" : "Bounded prefix (lower bound)"}. At most 1,024 pending records are inspected. No total size or completion time is inferred.`,
        },
        {
          key: "oldest",
          label: "Oldest pending position",
          value: value.oldest_pending_lsn ?? "None observed",
          explanation:
            "Oldest pending position returned by this bounded read. It establishes no elapsed age.",
        },
        {
          key: "segment",
          label: "Next segment",
          value: value.next_segment,
          explanation: "Next segment identity; not a count of live segments.",
        },
        {
          key: "archive-work",
          label: "Archive activity / completed",
          value: `${value.archive_source_lsn} / ${value.archived_source_lsn}`,
          explanation: "Independent archive work coordinates; not comparable row counts.",
        },
        {
          key: "archive-target",
          label: "Archive target",
          value: value.archive_target_through_lsn ?? "None",
          explanation: "Current archive target, if reported. A target is not completed work.",
        },
        {
          key: "compact-work",
          label: "Compaction activity / completed",
          value: `${value.compaction_source_lsn} / ${value.compacted_source_lsn}`,
          explanation: "Independent compaction work coordinates; not percentages of the Table.",
        },
        {
          key: "compact-target",
          label: "Compaction target source",
          value: value.compaction_target_source_lsn ?? "None",
          explanation:
            "Current compaction target, if reported. Compaction does not itself authorize history expiry.",
        },
      ]}
    />
  );
}

const catalog = new DataCatalog();
export function CatalogStorageExplorer() {
  const { scope } = useScope();
  return (
    <section aria-label="Table storage explorer">
      <h2>Table storage</h2>
      {scope?.features.catalog ? (
        <CatalogStorageSelection />
      ) : (
        <p>
          A catalog connection is not configured. <Link to="/catalog">View setup guidance</Link> to
          inspect individual Tables.
        </p>
      )}
    </section>
  );
}
function CatalogStorageSelection() {
  const { scope } = useScope();
  const [namespace, setNamespace] = useState<number | null>(null);
  const [namespaceCursor, setNamespaceCursor] = useState<CatalogNamespaces["next"]>(null);
  const [cursor, setCursor] = useState<CatalogTables["next"]>(null);
  const [selection, setSelection] = useState<CatalogEntry | null>(null);
  const state = useRead(
    JSON.stringify(["storage-tables", scope?.realm, namespace, namespaceCursor, cursor]),
    async (signal) => {
      const description = await catalog.describe(signal);
      const namespaces = await catalog.namespaces(namespaceCursor, signal);
      const selected = namespace ?? description.configuration.authority.initial_schema;
      return { namespaces, selected, tables: await catalog.tables(selected, cursor, signal) };
    },
  );
  const page = state.value;
  if (!page) return <ReadStatus failure={state.failure} retry={state.retry} subject="Catalog" />;
  return (
    <>
      <div className="workbench-toolbar">
        <label>
          Storage namespace{" "}
          <select
            value={page.selected}
            onChange={(event) => {
              setNamespace(Number(event.target.value));
              setCursor(null);
              setSelection(null);
            }}
          >
            {!page.namespaces.entries.some((entry) => entry?.id === page.selected) && (
              <option value={page.selected}>Namespace {page.selected}</option>
            )}
            {page.namespaces.entries
              .filter((entry) => entry !== null)
              .map((entry) => (
                <option key={entry.id} value={entry.id}>
                  {entry.name}
                </option>
              ))}
          </select>
        </label>
        <button
          disabled={!namespaceCursor}
          onClick={() => {
            setNamespaceCursor(null);
            setSelection(null);
          }}
        >
          First namespaces
        </button>
        <button
          disabled={!page.namespaces.next}
          onClick={() => {
            setNamespaceCursor(page.namespaces.next);
            setSelection(null);
          }}
        >
          More namespaces
        </button>
      </div>
      <div className="workbench-grid">
        <table>
          <caption>Choose one Table · up to 8 authorized definitions per page</caption>
          <thead>
            <tr>
              <th>Table</th>
              <th>Object</th>
              <th>Definition</th>
            </tr>
          </thead>
          <tbody>
            {page.tables.entries
              .filter((entry) => entry !== null)
              .map((entry) => (
                <tr key={entry.interpretation.object.object}>
                  <th scope="row">
                    <button onClick={() => setSelection(entry)}>{entry.name}</button>
                  </th>
                  <td>{entry.interpretation.object.object}</td>
                  <td>{entry.interpretation.revision}</td>
                </tr>
              ))}
          </tbody>
        </table>
      </div>
      {!page.tables.entries.some((entry) => entry !== null) && (
        <p>No Tables in this authorized page.</p>
      )}
      <div className="workbench-toolbar">
        <button
          disabled={!cursor}
          onClick={() => {
            setCursor(null);
            setSelection(null);
          }}
        >
          First Tables
        </button>
        <button
          disabled={!page.tables.next}
          onClick={() => {
            setCursor(page.tables.next);
            setSelection(null);
          }}
        >
          More Tables
        </button>
      </div>
      {selection && (
        <CatalogTableStorage key={JSON.stringify(selection.interpretation)} entry={selection} />
      )}
    </>
  );
}
function CatalogTableStorage({ entry }: { entry: CatalogEntry }) {
  const state = useRead(JSON.stringify(["table-storage", entry]), async (signal) => {
    const table = await catalog.table(entry.namespace, entry.name, entry.interpretation, signal);
    return catalog.storage(table.metadata.binding, signal);
  });
  return state.value ? (
    <TableStorageView page={state.value} />
  ) : (
    <ReadStatus failure={state.failure} retry={state.retry} subject="Table storage" />
  );
}

type Source = RelationalDescription["sources"][number];
export function TableStorage({ source, route }: { source: Source; route: number }) {
  const [visible, setVisible] = useState(false);
  return (
    <section aria-label={`Storage for ${source.alias}`}>
      <button onClick={() => setVisible(!visible)}>
        {visible ? "Hide" : "Inspect"} storage for {source.alias}
      </button>
      {visible && <TableStorageRead source={source} route={route} />}
    </section>
  );
}
function TableStorageRead({ source, route }: { source: Source; route: number }) {
  const state = useRead(
    JSON.stringify(["relational-storage", route, source.binding]),
    async (signal) => {
      const result = await relationalQuery({ storage: { route, binding: source.binding } }, signal);
      if (!("storage" in result)) throw new QueryError(0, "InvalidResponse");
      return result.storage;
    },
  );
  return state.value ? (
    <TableStorageView page={state.value} />
  ) : (
    <ReadStatus failure={state.failure} retry={state.retry} subject="Table storage" />
  );
}
