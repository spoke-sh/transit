import { useState, useSyncExternalStore } from "react";
import type { DraftSession } from "@rey/transit-query-client";
export function DraftControls({
  session,
  available,
  busy,
}: {
  session: DraftSession;
  available: boolean;
  busy: boolean;
}) {
  const state = useSyncExternalStore(session.subscribe, session.getSnapshot);
  const [limit, setLimit] = useState(2);
  const [error, setError] = useState("");
  const active = ["opening", "active", "running"].includes(state.phase);
  const attempt = async (action: () => Promise<void> | void) => {
    try {
      setError("");
      await action();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Draft control unavailable.");
    }
  };
  return (
    <fieldset className="draft-controls" aria-label="Live draft controls">
      <legend>Live draft · finite Table snapshots</legend>
      <p>
        {state.phase.replaceAll("_", " ")} · {error || state.detail}
      </p>
      <label>
        Evaluation intents{" "}
        <select
          aria-label="Live draft starts"
          disabled={active || state.acceptedWork}
          value={limit}
          onChange={(event) => setLimit(Number(event.target.value))}
        >
          {[1, 2, 4, 8].map((value) => (
            <option key={value} value={value}>
              {value}
            </option>
          ))}
        </select>
      </label>
      <button
        disabled={!available || busy || active || state.acceptedWork}
        onClick={() => void attempt(() => session.open(limit))}
      >
        Enable Live draft
      </button>
      <button
        disabled={!active && !state.acceptedWork && !state.budget?.enabled}
        onClick={() => session.pause()}
      >
        Pause Live draft
      </button>
      {state.acceptedWork && (
        <>
          <button onClick={() => session.recover()}>Recover original draft work</button>
          <button onClick={() => session.cancel()}>Cancel draft query</button>
          <button
            onClick={() =>
              void attempt(() => {
                const url = URL.createObjectURL(
                  new Blob([session.exportRecovery()], { type: "application/json" }),
                );
                const link = document.createElement("a");
                link.href = url;
                link.download = "transit-draft-recovery.json";
                link.click();
                setTimeout(() => URL.revokeObjectURL(url), 1000);
              })
            }
          >
            Save draft recovery
          </button>
        </>
      )}
      <label>
        Restore draft recovery{" "}
        <input
          aria-label="Restore draft recovery"
          type="file"
          accept="application/json,.json"
          disabled={busy || active || state.acceptedWork}
          onChange={(event) => {
            const file = event.target.files?.[0];
            event.target.value = "";
            if (file)
              void attempt(async () => {
                if (file.size > 131072) throw new Error("Draft recovery file exceeds 128 KiB");
                session.restoreRecovery(await file.text());
              });
          }}
        />
      </label>
      {state.budget && (
        <p>
          Generation {state.budget.generation} · {state.budget.starts} / {state.budget.limit} native
          intents used · {state.budget.enabled ? "recorded open" : "recorded closed"}. Editing,
          retries and navigation do not reset this budget.
        </p>
      )}
      {state.namespace && (
        <p>
          Retained namespace {state.namespace}. Closing Live draft does not cancel accepted query
          work.
        </p>
      )}
      {state.result && (
        <p>
          Browser-observed timings: compilation{" "}
          {state.result.compileMs === null
            ? "unavailable after recovery"
            : `${Math.round(state.result.compileMs)} ms`}
          ; upload through observed completion{" "}
          {state.result.readyMs === null
            ? "unavailable after recovery"
            : `${Math.round(state.result.readyMs)} ms`}
          ; complete verification and visible reread {Math.round(state.result.verifyMs)} ms. Server
          execution time and source age are unavailable.
        </p>
      )}
    </fieldset>
  );
}
