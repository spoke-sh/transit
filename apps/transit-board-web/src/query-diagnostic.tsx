import { diagnosticLines, type Diagnostic } from "@rey/transit-query-client";

/** Guidance is text, never an automatic action or authorization source. */
export function QueryDiagnostic({ value }: { value: Diagnostic }) {
  return (
    <div className="query-diagnostic" role="alert" aria-label="Query diagnostic">
      {diagnosticLines(value).map((line, index) => (
        <p key={index}>{line}</p>
      ))}
    </div>
  );
}
