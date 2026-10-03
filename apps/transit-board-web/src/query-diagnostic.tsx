import { diagnosticLines, type Diagnostic } from "@rey/transit-query-client";

/** Guidance is text, never an automatic action or authorization source. */
export function QueryDiagnostic({
  value,
  label = "Query diagnostic",
}: {
  value: Diagnostic;
  label?: string;
}) {
  return (
    <div className="query-diagnostic" role="alert" aria-label={label}>
      {diagnosticLines(value).map((line, index) => (
        <p key={index}>{line}</p>
      ))}
    </div>
  );
}
