import { DataRoute } from "../data-route";
import { createFileRoute } from "@tanstack/react-router";
import { WorkbookPage } from "../features";
export const Route = createFileRoute("/workbook")({
  component: () => (
    <DataRoute path="/workbook">
      <WorkbookPage />
    </DataRoute>
  ),
});
