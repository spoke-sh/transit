import { createRootRoute, Outlet } from "@tanstack/react-router";
import { Access } from "../state";
export const Route = createRootRoute({
  component: () => (
    <Access>
      <Outlet />
    </Access>
  ),
  notFoundComponent: () => (
    <main>
      <h1>View not found</h1>
      <a href="/">Return to Board</a>
    </main>
  ),
});
