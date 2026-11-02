import { createContext, useContext, type ReactNode } from "react";
import { deployment } from "@transit/board-client/deployment";
import { type Deployment } from "@transit/board-client";
import { InterfaceShell } from "./interface";
import { useRead } from "./use-observation";
import { ReadStatus } from "./read-status";
const Context = createContext<{ scope: Deployment | null; refresh: () => void }>({
  scope: null,
  refresh: () => {},
});
export const useScope = () => useContext(Context);
export function Access({ children }: { children: ReactNode }) {
  const connection = useRead("deployment", deployment, 0, false);
  // Configuration is not an authorized resource observation. Upstream denial
  // stays with the affected view and never disables an unrelated connection.
  return (
    <Context.Provider value={{ scope: connection.value, refresh: connection.retry }}>
      {connection.value ? (
        <InterfaceShell scope={connection.value}>{children}</InterfaceShell>
      ) : (
        <main className="access">
          <h1>Transit Board</h1>
          <ReadStatus failure={connection.failure} retry={connection.retry} subject="Board" />
        </main>
      )}
    </Context.Provider>
  );
}
