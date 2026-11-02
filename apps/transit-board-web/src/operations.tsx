import { Link } from "@tanstack/react-router";
import { useScope } from "./state";
import { Storage, CatalogStorageExplorer } from "./storage";
import { HistoricalCatalog } from "./retained-storage";
import { Workbench, WorkbenchBody } from "./workbench-layout";
import "./workbench.css";
export function Operations() {
  const { scope } = useScope();
  return (
    <Workbench className="operations-workbench">
      <div className="page-heading">
        <div>
          <p className="eyebrow">OPERATIONS / SYSTEM EVIDENCE</p>
          <h1>Operations</h1>
          <p>Storage, maintenance and the evidence behind current progress.</p>
        </div>
      </div>
      <div className="workbench-scope">
        <strong>Realm {scope?.realm}</strong>
        <span>Read-only inspection</span>
        <Link to="/atlas">Processes and resources</Link>
        <Link to="/activity">Activity</Link>
        {scope?.features.relational && (
          <Link to="/recovery/relational">Relational queries and recovery</Link>
        )}
      </div>
      <WorkbenchBody>
        <Storage />
        <CatalogStorageExplorer />
        {scope?.features.catalog && <HistoricalCatalog key={JSON.stringify(scope)} />}
      </WorkbenchBody>
      <p>
        Independent observations retain their own basis. Inspection starts no query or maintenance.
      </p>
    </Workbench>
  );
}
