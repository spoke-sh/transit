import { createFileRoute } from "@tanstack/react-router";
import { DeclaredView } from "../declared";
import { useScope } from "../state";
export const Route = createFileRoute("/atlas")({ component: AtlasPage });
function AtlasPage() {
  return useScope().scope?.profile === "native_v1" ? (
    <DeclaredView />
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
