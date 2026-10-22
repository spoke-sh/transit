import { useEffect, useMemo, useRef, useState } from "react";
import { unifiedQuery } from "@transit/board-client";
import { AssistanceReader, applySuggestion, type AssistanceState } from "@transit/query-client";

/** Presentation only: native grammar, catalog and capability checks own hints. */
export function SqlEditor({
  value,
  change,
  resource,
  scope,
  contract,
  visible,
  denied,
}: {
  value: string;
  change: (value: string) => void;
  resource: number;
  scope: string;
  contract: number[] | null;
  visible: boolean;
  denied: () => void;
}) {
  const textarea = useRef<HTMLTextAreaElement>(null);
  const [state, setState] = useState<AssistanceState>({ result: null, busy: false, error: "" });
  const [selected, setSelected] = useState(0);
  const undo = useRef<{ before: string; after: string } | null>(null);
  const contractKey = JSON.stringify(contract);
  const reader = useMemo(() => {
    void scope; // A caller/schema context change creates a fresh bounded reader.
    return new AssistanceReader(
      unifiedQuery,
      resource,
      JSON.parse(contractKey) as number[] | null,
      setState,
      denied,
    );
  }, [resource, scope, contractKey, denied]);
  useEffect(() => () => reader.dispose(), [reader]);
  useEffect(() => {
    if (!visible) reader.close();
  }, [visible, reader]);
  useEffect(() => {
    const hidden = () => {
      if (document.hidden) reader.close();
    };
    document.addEventListener("visibilitychange", hidden);
    return () => document.removeEventListener("visibilitychange", hidden);
  }, [reader]);
  const edit = (sql: string, cursor: number, open = false) => {
    setSelected(0);
    try {
      reader.edit(sql, cursor, open);
    } catch (error) {
      reader.close();
      setState({
        result: null,
        busy: false,
        error: error instanceof Error ? error.message : "Assistance unavailable",
      });
    }
  };
  useEffect(() => {
    // Definitions and whole-statement candidates can also replace this draft.
    try {
      reader.edit(value, textarea.current?.selectionStart ?? value.length);
    } catch {
      reader.close();
    }
  }, [value, reader]);
  const accept = (index: number) => {
    if (!state.result) return;
    try {
      const next = applySuggestion(value, state.result, index);
      undo.current = { before: value, after: next.sql };
      reader.close();
      change(next.sql);
      requestAnimationFrame(() => {
        textarea.current?.focus();
        textarea.current?.setSelectionRange(next.cursor, next.cursor);
      });
    } catch {
      reader.close();
    }
  };
  const items = state.result?.response.items ?? [];
  return (
    <>
      <textarea
        id="unified-sql"
        ref={textarea}
        value={value}
        maxLength={4096}
        aria-describedby="sql-assistance-help"
        onChange={(event) => {
          undo.current = null;
          change(event.target.value);
          edit(event.target.value, event.target.selectionStart);
        }}
        onSelect={(event) => edit(value, event.currentTarget.selectionStart)}
        onKeyDown={(event) => {
          if (event.key === "Escape") {
            reader.close();
            return;
          }
          if (event.ctrlKey && event.code === "Space") {
            event.preventDefault();
            edit(value, event.currentTarget.selectionStart, true);
            return;
          }
          if (
            (event.ctrlKey || event.metaKey) &&
            !event.shiftKey &&
            event.key.toLowerCase() === "z" &&
            undo.current?.after === value
          ) {
            event.preventDefault();
            reader.close();
            change(undo.current.before);
            undo.current = null;
            return;
          }
          if (items.length && (event.key === "ArrowDown" || event.key === "ArrowUp")) {
            event.preventDefault();
            setSelected(
              (selected + (event.key === "ArrowDown" ? 1 : items.length - 1)) % items.length,
            );
          } else if (items.length && (event.key === "Tab" || event.key === "Enter")) {
            event.preventDefault();
            accept(selected % items.length);
          }
        }}
      />
      <p id="sql-assistance-help">
        Ctrl-Space completes at the cursor. Arrows select, Tab accepts, Escape dismisses and Ctrl-Z
        undoes acceptance. Completion only edits the draft.
      </p>
      <button onClick={() => edit(value, textarea.current?.selectionStart ?? value.length, true)}>
        Complete SQL
      </button>
      {state.busy && <p role="status">Reading authorized SQL completions…</p>}
      {state.error && <p role="status">{state.error}</p>}
      {state.result && (
        <div role="group" aria-label="SQL completions">
          {items.map((item, index) => (
            <button
              key={`${item.kind}/${item.text}`}
              aria-pressed={selected === index}
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => accept(index)}
            >
              {item.text} · {item.detail}
            </button>
          ))}
          {!items.length && <p>No supported completion at this position.</p>}
        </div>
      )}
    </>
  );
}
