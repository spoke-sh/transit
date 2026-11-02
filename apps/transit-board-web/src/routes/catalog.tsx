import { DataRoute } from "../data-route";
import { createFileRoute } from "@tanstack/react-router";
import { CatalogPage } from "../features";
export const Route = createFileRoute("/catalog")({
  component: () => (
    <DataRoute path="/catalog">
      <CatalogPage />
    </DataRoute>
  ),
});
