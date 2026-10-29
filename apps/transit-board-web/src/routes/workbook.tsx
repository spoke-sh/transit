import { createFileRoute } from "@tanstack/react-router";
import { WorkbookPage, DataRoute } from "../data-workbench";
export const Route = createFileRoute("/workbook")({
  component: () => (
    <DataRoute path="/workbook">
      <WorkbookPage />
    </DataRoute>
  ),
});
