import { createFileRoute, Link } from "@tanstack/react-router";
import { RelationalWorkspace } from "../features";
import { Workbench, WorkbenchBody } from "../workbench-layout";
import { FeatureAccess } from "../feature-access";

export const Route = createFileRoute("/recovery/relational")({
  component: () => (
    <FeatureAccess feature="relational">
      <Workbench>
        <h1>Relational queries and recovery</h1>
        <p>
          Inspect the original shared query and close interrupted source ownership. Ordinary SQL
          cells are available in Workbook.
        </p>
        <Link to="/operations">Back to Operations</Link>
        <WorkbenchBody>
          <RelationalWorkspace />
        </WorkbenchBody>
      </Workbench>
    </FeatureAccess>
  ),
});
