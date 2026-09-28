import { cellStates, pageProfile, type ResultPage } from "@rey/transit-query-client";

export function QueryProfile({ page }: { page: ResultPage }) {
  const manifest = page.evidence.manifest;
  return (
    <details className="query-profile">
      <summary>Visible page profile and chart</summary>
      <p>
        Exact counts for {page.evidence.rows} visible rows on page{" "}
        {BigInt(page.evidence.ordinal) + 1n} of the same verified result. Query{" "}
        {manifest.correlation}; source revision {manifest.basis.revision}. This page is not a
        population sample or a whole-source summary.
      </p>
      <table aria-label="Visible page cell-state profile">
        <thead>
          <tr>
            <th>Column</th>
            {cellStates.map((state) => (
              <th key={state}>{state.replaceAll("_", " ")}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {pageProfile(page).map((column) => (
            <tr key={column.name}>
              <th>
                {column.name} · {column.type}
              </th>
              {cellStates.map((state) => (
                <td key={state}>
                  <span
                    className="profile-bar"
                    aria-hidden="true"
                    style={{ width: `${(column.counts[state] * 100) / 8}%` }}
                  />
                  {column.counts[state]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      <p>
        Monochrome bars use the fixed page bound of eight rows. Counts preserve null, missing, type
        error and concurrent alternatives separately; no numeric values are rounded into chart
        coordinates.
      </p>
    </details>
  );
}
