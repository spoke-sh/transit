import { createRootRoute, Outlet } from "@tanstack/react-router";
import { Access } from "../state";
import { FeatureBoundary } from "../feature-boundary";
export const Route = createRootRoute({
  component: () => (
    <Access>
      <FeatureBoundary>
        <Outlet />
      </FeatureBoundary>
    </Access>
  ),
  notFoundComponent: () => (
    <main>
      <h1>View not found</h1>
      <a href="/">Return to Board</a>
    </main>
  ),
});
