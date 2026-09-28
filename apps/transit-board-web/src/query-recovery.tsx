/** A read reference is not a grant or a signed admission. Export before changing
 * the selected terminal query so its durable identity survives browser loss. */
export function saveQueryReference(
  profile: "table_v1" | "unified_v2",
  resource: number,
  id: string,
) {
  const source = JSON.stringify({ version: 1, origin: location.origin, profile, resource, id });
  const url = URL.createObjectURL(new Blob([source], { type: "application/json" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = "transit-query-reference.json";
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export const terminalQuery = (phase: string | undefined) =>
  phase !== undefined &&
  ["complete", "cancelled", "denied", "expired", "failed", "rejected", "retired", "busy"].includes(
    phase,
  );

export function QueryRecovery({
  id,
  phase,
  busy,
  canSelect = true,
  inspect,
  cancel,
  select,
}: {
  id: string;
  phase?: string;
  busy: boolean;
  canSelect?: boolean;
  inspect: () => void;
  cancel: () => void;
  select: () => void;
}) {
  return (
    <div className="query-recovery" aria-label="Retained query recovery">
      <p>
        Retained query {id}. Current status and cancellation use its original identity even when
        this screen's binding changes.
      </p>
      <button disabled={busy} onClick={inspect}>
        Read retained query status
      </button>
      <button disabled={busy || terminalQuery(phase)} onClick={cancel}>
        Cancel retained query
      </button>
      <button disabled={busy || !canSelect || !terminalQuery(phase)} onClick={select}>
        Save reference and use current binding
      </button>
      <p>
        Switching saves a read reference and clears the selected result. It neither runs a new query
        nor retires the previous one.
      </p>
    </div>
  );
}
