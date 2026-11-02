import { Component, Suspense, type ReactNode } from "react";
import { useRouterState } from "@tanstack/react-router";
import { useInterface } from "./interface";

/** A failed feature import leaves the shell and its navigation available. */
class LoadBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  render() {
    return this.state.failed ? (
      <main>
        <h1>View unavailable</h1>
        <p role="alert">Board could not load this view. Reload to try again.</p>
        <button onClick={() => window.location.reload()}>Reload Board</button>
      </main>
    ) : (
      this.props.children
    );
  }
}

export function FeatureBoundary({ children }: { children: ReactNode }) {
  const path = useRouterState({ select: (state) => state.location.pathname });
  const current = useInterface();
  return (
    <LoadBoundary key={`${path}/${current?.identity}`}>
      <Suspense
        fallback={
          <main>
            <p role="status">Loading view…</p>
          </main>
        }
      >
        {children}
      </Suspense>
    </LoadBoundary>
  );
}
