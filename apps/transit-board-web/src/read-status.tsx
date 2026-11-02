import type { ReadFailure } from "./observation";

export function ReadStatus({
  failure,
  retry,
  subject = "data",
}: {
  failure: ReadFailure | null;
  retry: () => void;
  subject?: string;
}) {
  const label = !failure
    ? `Reading ${subject}…`
    : {
        unconfigured: `${subject} connection is not configured`,
        denied: `Access to ${subject} denied`,
        expired: `${subject} observation changed or expired`,
        incompatible: `${subject} response is incompatible`,
        limited: `${subject} read capacity reached`,
        unavailable: `${subject} connection unavailable`,
        refused: `${subject} read refused`,
      }[failure.kind];
  return (
    <div className="workbench-empty" role="status">
      <h2>{label}</h2>
      {failure && (
        <>
          <p>{failure.code}</p>
          <p>
            {failure.kind === "unconfigured"
              ? "Configure this connection on the Board service and restart it. Every read still requires current permission."
              : failure.kind === "denied"
                ? "Check the configured connection's read permissions, then recheck access."
                : failure.kind === "incompatible"
                  ? "Check that Board and its upstream service use matching definitions."
                  : failure.kind === "expired"
                    ? "Refresh this observation. Pages from different observations cannot be combined."
                    : "No new authorized observation was received."}
          </p>
          <button onClick={retry}>
            {failure.kind === "unconfigured"
              ? "Check availability"
              : failure.kind === "denied"
                ? "Recheck access"
                : "Retry read"}
          </button>
        </>
      )}
    </div>
  );
}
