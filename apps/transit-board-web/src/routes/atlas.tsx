import { createFileRoute } from "@tanstack/react-router";
import { Atlas } from "../atlas";
import { useScope } from "../state";
export const Route = createFileRoute("/atlas")({ component: AtlasPage });
function AtlasPage() {
  return useScope().scope?.profile === "growing_v3" ? (
    <Atlas />
  ) : (
    <main>
      <h1>Relief atlas</h1>
      <p>
        This installation uses the legacy inspection profile. Its process and resource views remain
        available from <a href="/">Board</a>.
      </p>
    </main>
  );
}
