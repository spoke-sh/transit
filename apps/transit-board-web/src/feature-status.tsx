/** Route-owned fallbacks keep the validated shell and navigation mounted. */
export function FeatureLoading() {
  return (
    <main>
      <p role="status">Loading view…</p>
    </main>
  );
}

export function FeatureUnavailable() {
  return (
    <main>
      <h1>View unavailable</h1>
      <p role="alert">Board could not load this view. Reload to try again.</p>
      <button onClick={() => window.location.reload()}>Reload Board</button>
    </main>
  );
}
