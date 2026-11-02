import { createFileRoute } from "@tanstack/react-router";
import { DeclaredView } from "../declared";
import { useScope } from "../state";
import { ResourcePage } from "../features";

export const Route = createFileRoute("/resources")({
  validateSearch: (search: Record<string, unknown>): { resource?: number } => ({
    resource:
      Number.isSafeInteger(Number(search.resource)) && Number(search.resource) > 0
        ? Number(search.resource)
        : undefined,
  }),
  component: () =>
    useScope().scope?.profile === "native_v1" ? <DeclaredView /> : <ResourcePage />,
});
