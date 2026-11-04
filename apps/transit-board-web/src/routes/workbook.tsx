import { DataRoute } from "../data-route";
import { createFileRoute } from "@tanstack/react-router";
export const Route = createFileRoute("/workbook")({
  component: () => <DataRoute path="/workbook">{null}</DataRoute>,
});
