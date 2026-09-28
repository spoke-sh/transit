import { useEffect, useSyncExternalStore } from "react";
import { LiveView, Session, type Inspection } from "@rey/transit-reactive-client";

// One metadata panel per Board origin. Its session and exact pending operation
// survive route remount; hiding the panel stops renewal and joins its stream.
const session = new Session();
const metadata = new LiveView<Inspection["observation"]>(session, async (signal) => {
  const result = await session.inspect(signal);
  return { value: result.observation, basis: result.observation.basis };
});
export function LiveTable() {
  const view = useSyncExternalStore(metadata.subscribe, metadata.getSnapshot);
  useEffect(() => {
    const hide = () => {
      if (document.hidden) void metadata.pause();
    };
    document.addEventListener("visibilitychange", hide);
    return () => {
      document.removeEventListener("visibilitychange", hide);
      void metadata.pause();
    };
  }, []);
  return (
    <section aria-label="Live Table metadata" className="atlas-inspector">
      <h2>Table progress</h2>
      <p role="status">
        {view.phase.replaceAll("_", " ")} · {view.detail}
      </p>
      <button
        disabled={metadata.following || metadata.stopping || !!session.pending}
        onClick={() => void metadata.start().catch(() => {})}
      >
        Follow metadata
      </button>
      <button onClick={() => void metadata.pause()}>Pause metadata</button>
      {session.pending && (
        <button
          disabled={metadata.stopping}
          onClick={() => void metadata.recover().catch(() => {})}
        >
          Recover exact control
        </button>
      )}
      {view.snapshot && (
        <dl>
          <dt>Resource</dt>
          <dd>{view.snapshot.basis.resource}</dd>
          <dt>Observed resource revision</dt>
          <dd>{view.snapshot.basis.revision}</dd>
          <dt>Data progress revision</dt>
          <dd>{view.snapshot.value.data_revision}</dd>
          <dt>Schema fingerprint</dt>
          <dd>
            {view.snapshot.basis.schema.map((byte) => byte.toString(16).padStart(2, "0")).join("")}
          </dd>
        </dl>
      )}
      <p>Metadata only. This panel and the atlas have independent observation positions.</p>
    </section>
  );
}
