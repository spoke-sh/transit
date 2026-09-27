import { useEffect, useState } from "react";
import { records, type RecordsResponse } from "@rey/transit-board-client";
import { message } from "./state";
import { HttpMetadata } from "./http-metadata";

type Declaration = NonNullable<RecordsResponse["exchanges"][number]>["declaration"];
function ExchangeEvidence({ detail }: { detail: Declaration }) {
  if ("capture" in detail) {
    const d = detail.capture;
    return (
      <>
        <h3>
          Exchange {d.exchange} · {d.phase}
        </h3>
        <dl>
          <dt>Caller / original input</dt>
          <dd>
            PID {d.caller} / {d.input}
          </dd>
          <dt>Writer / parent exchange</dt>
          <dd>
            PID {d.owner} / {d.parent === "0" ? "Root" : d.parent}
          </dd>
          <dt>Effect / attempt / executor</dt>
          <dd>
            {d.effect || "Unbound"} / {d.attempt || "Unbound"} / {d.executor || "Unbound"}
          </dd>
          <dt>Reconciliation deadline (Unix ms)</dt>
          <dd>{d.reconcile_before_ms}</dd>
          <dt>Captured segments</dt>
          <dd>
            {d.segments} of {d.max_segments} allowed
          </dd>
          <dt>Captured bytes</dt>
          <dd>
            {d.bytes} of {d.capture_bytes} allowed
          </dd>
          <dt>Pending segment kind / reclaimed members</dt>
          <dd>
            {d.pending_kind || "None"} / {d.collected}
          </dd>
          <dt>Protocol / terminal code</dt>
          <dd>
            {d.protocol} / {d.terminal_code || "Unavailable"}
          </dd>
          <dt>Coverage commitment</dt>
          <dd>
            <code>{d.coverage.map((byte) => byte.toString(16).padStart(2, "0")).join("")}</code>
          </dd>
        </dl>
        <p>Capture completion is separate from kernel settlement and remote business success.</p>
      </>
    );
  }
  if ("lineage" in detail) {
    const d = detail.lineage;
    return (
      <>
        <h3>
          Exchange {d.exchange} · {d.reason}
        </h3>
        <dl>
          <dt>Root / parent</dt>
          <dd>
            {d.root} / {d.parent}
          </dd>
          <dt>Attempt ordinal</dt>
          <dd>{d.ordinal}</dd>
          <dt>Policy / revision</dt>
          <dd>
            {d.policy} / {d.policy_revision}
          </dd>
        </dl>
        <p>The recorded policy decision does not grant current dispatch rights.</p>
      </>
    );
  }
  if ("obligations" in detail) {
    const d = detail.obligations;
    return (
      <>
        <h3>
          Exchange {d.exchange} · {d.disposition}
        </h3>
        <dl>
          <dt>Settled effect</dt>
          <dd>{d.effect || "None"}</dd>
          <dt>Caller replay hold</dt>
          <dd>{d.caller}</dd>
          <dt>Other consumer holds</dt>
          <dd>{d.dependents}</dd>
        </dl>
        <p>Closed unknown does not establish remote failure or cancellation.</p>
      </>
    );
  }
  const d = detail.attempts;
  return (
    <>
      <h3>Exchange {d.exchange} · shared attempt budget</h3>
      <dl>
        <dt>Used / limit</dt>
        <dd>
          {d.used} / {d.limit}
        </dd>
        <dt>Unsettled children</dt>
        <dd>{d.unsettled}</dd>
      </dl>
      <p>Unsettled children retain ancestor evidence. Settlement does not refund attempt slots.</p>
    </>
  );
}

export function Records({ resource }: { resource: number }) {
  const [page, setPage] = useState<RecordsResponse | null>(null);
  const [error, setError] = useState("");
  const [cursor, setCursor] = useState<{ revision: number; after: string }>();
  const [refresh, setRefresh] = useState(0);
  const [selectedHttp, setSelectedHttp] = useState<string>();
  useEffect(() => {
    const abort = new AbortController();
    let disposed = false;
    let busy = false;
    let timer: ReturnType<typeof setTimeout>;
    setPage(null);
    setError("");
    async function read() {
      if (disposed || busy || document.hidden) return;
      busy = true;
      try {
        const next = await records(resource, cursor, abort.signal);
        if (!disposed && !document.hidden) {
          setPage(next);
          setError("");
        }
      } catch (cause) {
        if (!disposed) {
          setPage(null);
          setError(message(cause));
        }
      } finally {
        busy = false;
        if (!disposed) timer = setTimeout(() => void read(), 5000);
      }
    }
    function visibility() {
      clearTimeout(timer);
      if (document.hidden) setPage(null);
      else void read();
    }
    void read();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      disposed = true;
      clearTimeout(timer);
      abort.abort();
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [resource, cursor, refresh]);
  return (
    <section aria-label={`Resource ${resource} records`} className="panel">
      <h2>Resource {resource} records</h2>
      <p>
        Eight authorized records per page. Recognized exchange metadata includes source keys and
        revisions.
      </p>
      <button
        onClick={() => {
          setCursor(undefined);
          setRefresh(refresh + 1);
        }}
      >
        Refresh records
      </button>
      <p role="status">
        {error ||
          (page
            ? `Resource revision ${page.resource.revision} · authority position ${page.position}`
            : "Reading current resource grant…")}
      </p>
      {page?.page.entries.map(
        (entry, index) =>
          entry && (
            <article key={entry.key}>
              {page.exchanges[index] && (
                <ExchangeEvidence detail={page.exchanges[index].declaration} />
              )}
              {page.exchanges[index] &&
                "capture" in page.exchanges[index].declaration &&
                page.exchanges[index].declaration.capture.protocol === 1 &&
                page.exchanges[index].declaration.capture.phase !== "retired" && (
                  <button
                    onClick={() => {
                      const detail = page.exchanges[index]!.declaration;
                      if ("capture" in detail) setSelectedHttp(detail.capture.exchange);
                    }}
                  >
                    Inspect HTTP metadata
                  </button>
                )}
              <p>
                Source: writer PID {page.resource.writer}, entry revision {entry.revision}
              </p>
              <details>
                <summary>Source key</summary>
                <dl>
                  <dt>Key (hex)</dt>
                  <dd>
                    <code>{entry.key}</code>
                  </dd>
                </dl>
              </details>
            </article>
          ),
      )}
      {page && page.page.entries.every((entry) => entry === null) && (
        <p>No records on this page.</p>
      )}
      {page && page.page.next !== null && (
        <button
          onClick={() => setCursor({ revision: page.resource.revision, after: page.page.next! })}
        >
          Next records
        </button>
      )}
      {page && selectedHttp && (
        <HttpMetadata key={selectedHttp} resource={resource} exchange={selectedHttp} />
      )}
    </section>
  );
}
