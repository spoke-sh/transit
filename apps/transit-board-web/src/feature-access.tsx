import type { ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { useScope } from "./state";
import { ReadStatus } from "./read-status";

export function FeatureAccess({
  feature,
  children,
}: {
  feature: "catalog" | "sql" | "relational";
  children: ReactNode;
}) {
  const { scope, refresh } = useScope();
  if (scope?.features[feature]) return children;
  const name = { catalog: "Catalog", sql: "Workbook SQL", relational: "Relational" }[feature];
  return (
    <main className="data-workbench">
      <h1>{feature === "sql" ? "Workbook" : name}</h1>
      <ReadStatus
        failure={{ kind: "unconfigured", code: "QueryDisabled", retryable: false }}
        retry={refresh}
        subject={name}
      />
      <p>
        {feature === "relational" ? (
          "This deployment has no relational connection."
        ) : (
          <>
            The {feature === "sql" ? "SQL" : "catalog"} connection is configured separately from
            system inspection.
          </>
        )}
      </p>
      <a href="https://github.com/spoke-sh/transit/blob/main/apps/transit-board/docs/workbench.md#configure-data-access">
        Data connection setup
      </a>
      {" · "}
      <Link to="/operations">Open Operations</Link>
    </main>
  );
}
