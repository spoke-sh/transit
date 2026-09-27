import { useCallback, useState } from "react";
import { documentMetadata, type DocumentCursor } from "@rey/transit-board-client";
import { useMetadata } from "./use-metadata";

export function DocumentMetadata({ resource, document }: { resource: number; document: string }) {
  const [cursor, setCursor] = useState<DocumentCursor>();
  const load = useCallback(
    (id: number, doc: string, signal?: AbortSignal) => documentMetadata(id, doc, cursor, signal),
    [cursor],
  );
  const { page, error } = useMetadata(resource, document, load);
  return (
    <section aria-label={`Document ${document} metadata`} className="panel">
      <h3>Document {document} · accepted metadata</h3>
      <button onClick={() => setCursor(undefined)}>Latest Document metadata</button>
      <p role="status">
        {error ||
          (page
            ? `Resource revision ${page.source.resource_revision} · authority position ${page.source.position}`
            : "Reading current Document grant…")}
      </p>
      {page && (
        <>
          <dl>
            <dt>Accepted revision / epoch</dt>
            <dd>
              {page.declaration.revision} / {page.declaration.epoch}
            </dd>
            <dt>Type / change format</dt>
            <dd>
              {page.declaration.type_revision} / {page.declaration.change_format}
            </dd>
            <dt>Retained history floor</dt>
            <dd>{page.declaration.floor}</dd>
            <dt>Merge window</dt>
            <dd>
              {page.declaration.merge_window === "0" ? "Unlimited" : page.declaration.merge_window}
            </dd>
            <dt>Pending publication job</dt>
            <dd>{page.declaration.active_job === "0" ? "None" : page.declaration.active_job}</dd>
            <dt>Lifecycle</dt>
            <dd>{page.declaration.retired ? "Permanently retired" : "Active"}</dd>
            <dt>Writer / head entry revision</dt>
            <dd>
              PID {page.source.pid} / {page.source.entry_revision}
            </dd>
          </dl>
          {page.declaration.floor !== "0" && (
            <p>
              History before revision {page.declaration.floor} is unavailable for merging. Stale
              replicas require authorized resynchronization.
            </p>
          )}
          {page.registers && (
            <>
              <p>
                Register page: {page.registers.count} registers · {page.registers.conflicts}{" "}
                conflicts · {page.registers.assignments} assignments.
              </p>
              <p>
                Counts cover this page only, including detached and deleted history. They are not
                totals for visible fields. Application values remain opaque.
              </p>
              {page.registers.next !== null && (
                <button
                  onClick={() =>
                    setCursor({
                      revision: page.source.resource_revision,
                      after: page.registers!.next!,
                    })
                  }
                >
                  Next register metadata
                </button>
              )}
            </>
          )}
          <details>
            <summary>Head source key</summary>
            <code>{page.source.key}</code>
          </details>
        </>
      )}
    </section>
  );
}
