import { WorkbenchScope } from "./workbench-layout";
import { Suspense, useState } from "react";
import { Computations } from "./features";
import { Link } from "@tanstack/react-router";
import { useScope } from "./state";
import { Storage, CatalogStorageExplorer } from "./storage";
import { HistoricalCatalog } from "./retained-storage";
import { Workbench, WorkbenchBody } from "./workbench-layout";
import "./workbench.css";
export function Operations() {
  const { scope } = useScope();
  const [computations, setComputations] = useState(false);
  return (
    <Workbench className="operations-workbench">
      <div className="page-heading">
        <div>
          <p className="eyebrow">OPERATIONS / SYSTEM EVIDENCE</p>
          <h1>Operations</h1>
          <p>Storage, maintenance and the evidence behind current progress.</p>
        </div>
      </div>
      <WorkbenchScope>
        <strong>Realm {scope?.realm}</strong>
        <span>Read-only inspection</span>
        <Link to="/atlas">Processes and resources</Link>
        <Link to="/activity">Activity</Link>
        {scope?.features.relational && (
          <Link to="/recovery/relational">Relational queries and recovery</Link>
        )}
      </WorkbenchScope>
      <WorkbenchBody>
        <Storage />
        <CatalogStorageExplorer />
        <section aria-label="Computation inspection">
          <h2>Computations</h2>
          {scope?.features.catalog ? (
            <>
              <button aria-expanded={computations} onClick={() => setComputations(!computations)}>
                {computations ? "Close computation inspection" : "Inspect a computation"}
              </button>
              {computations && (
                <Suspense fallback={<p role="status">Loading computation inspection…</p>}>
                  <Computations key={JSON.stringify(scope)} />
                </Suspense>
              )}
            </>
          ) : (
            <p>
              A catalog connection is required to inspect a computation.{" "}
              <Link to="/catalog">View setup guidance</Link>
            </p>
          )}
        </section>
        {scope?.features.catalog && <HistoricalCatalog key={JSON.stringify(scope)} />}
      </WorkbenchBody>
      <p>
        Independent observations retain their own basis. Inspection starts no query or maintenance.
      </p>
    </Workbench>
  );
}
