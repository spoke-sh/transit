import { createFileRoute, Outlet, useMatchRoute } from "@tanstack/react-router";
import { ProcessPage } from "../features";
import { tabs, type Tab } from "../process-tabs";
export const Route = createFileRoute("/processes/$pid")({
  validateSearch: (search: Record<string, unknown>): { tab: Tab } => ({
    tab: tabs.includes(search.tab as Tab) ? (search.tab as Tab) : "process",
  }),
  component: ProcessRoute,
});
function ProcessRoute() {
  const matchRoute = useMatchRoute();
  if (matchRoute({ to: "/processes/$pid/journey" })) return <Outlet />;
  return <ProcessPage />;
}
