import { useEffect, useRef, useState } from "react";
import { unifiedQuery as query } from "@transit/board-client";
import type { Response } from "@transit/query-client";
type Suggestions = Extract<Response, { suggestions: unknown }>["suggestions"];

export function QueryCandidates({
  resource,
  select,
  denied,
}: {
  resource: number;
  select: (sql: string) => void;
  denied: () => void;
}) {
  const [search, setSearch] = useState("");
  const [result, setResult] = useState<Suggestions | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const controller = useRef<AbortController | null>(null);
  useEffect(() => () => controller.current?.abort(), [resource]);
  const find = async () => {
    controller.current?.abort();
    const selected = new AbortController();
    controller.current = selected;
    setBusy(true);
    setError("");
    setResult(null);
    try {
      const value = await query({ suggest: { search } }, selected.signal);
      if (selected.signal.aborted) return;
      if (!("suggestions" in value) || value.suggestions.resource !== resource)
        throw new Error("Query candidate scope changed");
      setResult(value.suggestions);
    } catch (cause) {
      if (selected.signal.aborted) return;
      setError(cause instanceof Error ? cause.message : "Suggestions unavailable");
      if (
        typeof cause === "object" &&
        cause !== null &&
        "status" in cause &&
        (cause.status === 403 || cause.status === 410)
      )
        denied();
    } finally {
      if (!selected.signal.aborted) setBusy(false);
    }
  };
  return (
    <details className="query-candidates">
      <summary>Complete a draft from the authorized source</summary>
      <p>
        Search up to eight complete grammar-checked SQL candidates. Selecting one edits the draft.
        Run remains explicit unless Live draft is enabled. No other catalog is searched.
      </p>
      <label>
        SQL candidate search{" "}
        <input
          maxLength={128}
          value={search}
          onChange={(event) => {
            controller.current?.abort();
            setBusy(false);
            setSearch(event.target.value);
            setResult(null);
          }}
        />
      </label>
      <button disabled={busy} onClick={() => void find()}>
        Find SQL candidates
      </button>
      {error && <p role="status">{error}</p>}
      {result && (
        <ul>
          {result.items.map((item) => (
            <li key={item.sql}>
              <button
                onClick={() => {
                  select(item.sql);
                  setResult(null);
                }}
              >
                {item.label}: {item.sql}
              </button>
            </li>
          ))}
        </ul>
      )}
      {result?.items.length === 0 && <p>No matching authorized candidates.</p>}
    </details>
  );
}
