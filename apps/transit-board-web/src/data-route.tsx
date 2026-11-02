import type { ReactNode } from "react";
import { useInterface } from "./interface";
import { DeclaredView } from "./declared";
export function DataRoute({ path, children }: { path: string; children: ReactNode }) {
  const current = useInterface();
  return current?.published &&
    current.compiled.definition.screens.some((screen) => screen.path === path) ? (
    <DeclaredView />
  ) : (
    children
  );
}
