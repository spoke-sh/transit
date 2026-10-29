import { createFileRoute } from "@tanstack/react-router";
import { CatalogPage, DataRoute } from "../data-workbench";
export const Route = createFileRoute("/catalog")({
  component: () => (
    <DataRoute path="/catalog">
      <CatalogPage />
    </DataRoute>
  ),
});
