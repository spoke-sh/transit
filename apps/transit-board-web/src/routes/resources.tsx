import { createFileRoute, Link } from "@tanstack/react-router";
import { Atlas } from "../atlas";
import { useScope } from "../state";
import { Resources } from "../resources";

export const Route = createFileRoute("/resources")({
  validateSearch: (search: Record<string, unknown>): { resource?: number } => ({
    resource:
      Number.isSafeInteger(Number(search.resource)) && Number(search.resource) > 0
        ? Number(search.resource)
        : undefined,
  }),
  component: () =>
    useScope().scope?.profile === "growing_v3" ? (
      <Atlas initialEmphasis="resources" />
    ) : (
      <ResourcePage />
    ),
});
function ResourcePage() {
  const { resource } = Route.useSearch();
  return (
    <main>
      <Link to="/" search={{ status: "all", sort: "pid" }}>
        ← Processes
      </Link>
      <p className="eyebrow">STATE RESOURCES</p>
      <h1>{resource === undefined ? "Durable state" : `Resource ${resource}`}</h1>
      <p>Authorized resource metadata, lifetime contracts and committing-turn evidence.</p>
      {resource !== undefined && (
        <Link to="/resources" search={{}}>
          All authorized resources
        </Link>
      )}
      <Resources key={resource ?? "all"} resource={resource} />
    </main>
  );
}
