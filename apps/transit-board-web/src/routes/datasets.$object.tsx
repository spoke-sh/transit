import { createFileRoute } from "@tanstack/react-router";
import { DatasetPage } from "../data-workbench";
export const Route = createFileRoute("/datasets/$object")({
  validateSearch: (search: Record<string, unknown>) => ({
    namespace: Number(search.namespace),
    name: String(search.name ?? ""),
    revision: String(search.revision ?? ""),
    digest: String(search.digest ?? ""),
  }),
  component: () => {
    const { object } = Route.useParams();
    return (
      <DatasetPage
        key={object + JSON.stringify(Route.useSearch())}
        object={object}
        search={Route.useSearch()}
      />
    );
  },
});
