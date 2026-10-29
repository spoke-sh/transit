import { useCallback, useState } from "react";
import { relationalQuery, type RelationalDescription } from "@transit/board-client";
import { storage } from "@transit/board-client";
import { useMetadata } from "./use-metadata";

const load = (_resource: number, _selection: string, signal?: AbortSignal) => storage(signal);
const bytes = (value: number | null | undefined) =>
  value == null ? "Unavailable" : `${value.toLocaleString()} bytes`;

export function Storage() {
  const { page, error } = useMetadata(0, "storage", load);
  return (
    <section aria-label="Storage observation">
      <h2>Storage</h2>
      <p role="status">
        {error || (page ? `Observed at authority position ${page.position}` : "Reading storage…")}
      </p>
      {page && (
        <>
          <dl className="facts">
            <div>
              <dt>Backend</dt>
              <dd>{page.backend}</dd>
            </div>
            <div>
              <dt>Data root</dt>
              <dd>{page.root ?? "Unavailable"}</dd>
            </div>
            <div>
              <dt>Accounted storage</dt>
              <dd>{bytes(page.allocated_bytes)}</dd>
            </div>
            <div>
              <dt>Ordinary storage limit</dt>
              <dd>{bytes(page.limits?.bytes)}</dd>
            </div>
            <div>
              <dt>Storage control reserve</dt>
              <dd>{bytes(page.limits?.control_bytes)}</dd>
            </div>
            <div>
              <dt>Direct request allocation</dt>
              <dd>
                {bytes(page.data_requests?.used)} / {bytes(page.data_requests?.limit)}
              </dd>
            </div>
            <div>
              <dt>Direct request peak</dt>
              <dd>{bytes(page.data_requests?.peak)}</dd>
            </div>
            <div>
              <dt>Recovery request allocation</dt>
              <dd>
                {bytes(page.control_requests?.used)} / {bytes(page.control_requests?.limit)}
              </dd>
            </div>
            <div>
              <dt>Maintenance</dt>
              <dd>{page.maintenance?.state ?? "Unavailable"}</dd>
            </div>
            <div>
              <dt>Completed maintenance steps</dt>
              <dd>{page.maintenance?.completed_steps ?? "Unavailable"}</dd>
            </div>
            <div>
              <dt>Failed maintenance steps</dt>
              <dd>{page.maintenance?.failed_steps ?? "Unavailable"}</dd>
            </div>
            <div>
              <dt>Last maintenance failure</dt>
              <dd>
                {page.maintenance
                  ? (page.maintenance.last_failure ?? "None observed")
                  : "Unavailable"}
              </dd>
            </div>
            <div>
              <dt>Maintenance allocation limit</dt>
              <dd>{bytes(page.settings?.resident_bytes)}</dd>
            </div>
          </dl>
          <p>
            Live counters have independent observation times. Allocation counters exclude process
            stacks, sockets and filesystem caches. Maintenance counters reset when the storage owner
            restarts.
          </p>
        </>
      )}
    </section>
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
  const load = useCallback(
    async (_resource: number, _selection: string, signal?: AbortSignal) => {
      const result = await relationalQuery({ storage: { route, binding: source.binding } }, signal);
      if (!("storage" in result)) throw new Error("Invalid storage observation");
      return result.storage;
    },
    [route, source.binding],
  );
  const { page, error } = useMetadata(0, "table-storage", load);
  const value = page?.observed;
  return (
    <>
      <p role="status">
        {error || (page ? "Current storage observation" : "Reading Table storage…")}
      </p>
      {value && (
        <>
          <p>
            Object {page.binding.interpretation.interpretation.object.object}, definition{" "}
            {page.binding.interpretation.interpretation.revision}. These are independent current
            facts; reading them creates no query or snapshot.
          </p>
          <dl className="facts">
            <div>
              <dt>Accepted position</dt>
              <dd>{value.position.next_lsn}</dd>
            </div>
            <div>
              <dt>Logical change position</dt>
              <dd>{value.changed_lsn}</dd>
            </div>
            <div>
              <dt>Live rows</dt>
              <dd>{value.live_rows}</dd>
            </div>
            <div>
              <dt>Pending rows / bytes</dt>
              <dd>
                {value.pending_rows} / {value.pending_bytes} ·{" "}
                {value.pending_complete ? "complete backlog" : "bounded prefix"}
              </dd>
            </div>
            <div>
              <dt>Oldest pending position</dt>
              <dd>{value.oldest_pending_lsn ?? "None observed"}</dd>
            </div>
            <div>
              <dt>Archived through</dt>
              <dd>{value.archive_through}</dd>
            </div>
            <div>
              <dt>Recovery checkpoint</dt>
              <dd>{value.recovery_through ?? "Unavailable"}</dd>
            </div>
            <div>
              <dt>History floor</dt>
              <dd>{value.history_floor}</dd>
            </div>
            <div>
              <dt>Next segment</dt>
              <dd>{value.next_segment}</dd>
            </div>
            <div>
              <dt>Archive activity / completed</dt>
              <dd>
                {value.archive_source_lsn} / {value.archived_source_lsn}
              </dd>
            </div>
            <div>
              <dt>Archive target</dt>
              <dd>{value.archive_target_through_lsn ?? "None"}</dd>
            </div>
            <div>
              <dt>Compaction activity / completed</dt>
              <dd>
                {value.compaction_source_lsn} / {value.compacted_source_lsn}
              </dd>
            </div>
            <div>
              <dt>Compaction target source</dt>
              <dd>{value.compaction_target_source_lsn ?? "None"}</dd>
            </div>
          </dl>
        </>
      )}
    </>
  );
}
