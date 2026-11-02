import { Overview } from "../features";
import { createFileRoute, Navigate } from "@tanstack/react-router";
import { DeclaredView } from "../declared";
import { useScope } from "../state";
import { useInterface } from "../interface";
export const Route = createFileRoute("/")({
  validateSearch: (search: Record<string, unknown>) => ({
    status:
      search.status === "running" || search.status === "retired" || search.status === "attention"
        ? search.status
        : "all",
    sort: search.sort === "backlog" ? "backlog" : "pid",
  }),
  component: Landing,
});
function Landing() {
  const current = useInterface();
  const scope = useScope().scope;
  return scope?.profile === "native_v1" ? (
    current?.published ? (
      <DeclaredView />
    ) : (
      <Navigate
        to={scope.features.catalog ? "/catalog" : scope.features.sql ? "/workbook" : "/operations"}
        replace
      />
    )
  ) : (
    <Overview />
  );
}
