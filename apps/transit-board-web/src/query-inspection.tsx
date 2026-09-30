import type { UnifiedQueryResponse } from "@rey/transit-board-client";

export type Inspection = Extract<UnifiedQueryResponse, { inspection: unknown }>["inspection"];

export function QueryInspection({ value, changed }: { value: Inspection; changed: boolean }) {
  const details = value.details;
  const explanation = "explanation" in details ? details.explanation : null;
  const columns = "description" in details ? details.description.columns : explanation?.columns;
  const predicate = explanation?.predicate;
  return (
    <section className="query-source" aria-label="SQL inspection">
      <h3>{explanation ? "Proposed query plan" : "Source metadata"}</h3>
      <p>
        Configured source {value.name} · {value.source_kind} · resource {value.resource} · observed
        revision {value.resource_revision} · policy {value.policy_revision}
      </p>
      <p>No data snapshot or query admission.</p>
      {changed && <p>Draft changed. Metadata belongs to the earlier inspected statement.</p>}
      {"tables" in details &&
        (details.tables.length ? (
          <ul>
            {details.tables.map((name) => (
              <li key={name}>{name}</li>
            ))}
          </ul>
        ) : (
          <p>No Table in this configured source.</p>
        ))}
      {explanation && (
        <>
          <ol className="query-steps" aria-label="Proposed operators">
            {explanation.operators.map((operator) => (
              <li key={operator}>{operator}</li>
            ))}
          </ol>
          {predicate && "state" in predicate && (
            <p>
              Filter: {predicate.state.column} IS {predicate.state.value.toUpperCase()}
            </p>
          )}
          {predicate && "compare" in predicate && (
            <p>
              Filter: {predicate.compare.column} · {predicate.compare.op} · {predicate.compare.type}{" "}
              literal omitted.
            </p>
          )}
          <p>
            Projection: {explanation.projection.join(", ")} · input limit{" "}
            {explanation.limit ?? "none"} · {explanation.aggregate}
          </p>
          <p>
            Budgets: {explanation.budgets.pages} pages · {explanation.budgets.segments} segments ·{" "}
            {explanation.budgets.result_bytes} result bytes.
          </p>
        </>
      )}
      {columns && (
        <table aria-label="Inspected output columns">
          <thead>
            <tr>
              <th scope="col">Column</th>
              <th scope="col">Type</th>
            </tr>
          </thead>
          <tbody>
            {columns.map((column) => (
              <tr key={column.name}>
                <td>{column.name}</td>
                <td>{column.type}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <details>
        <summary>Source definition evidence</summary>
        <p>
          Contract{" "}
          <code>{value.contract.map((b) => b.toString(16).padStart(2, "0")).join("")}</code>
        </p>
        <p>
          Schema <code>{value.schema.map((b) => b.toString(16).padStart(2, "0")).join("")}</code>
        </p>
      </details>
    </section>
  );
}
