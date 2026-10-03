import type { HttpResponse } from "@rey/transit-board-client";

const explanation = {
  transport_failure:
    "The connector transport failed. Capture is incomplete and the remote operation may have run.",
  capture_failure:
    "The connector could not retain a complete capture. The remote operation may have run.",
  recovered_incomplete:
    "A replacement worker found incomplete capture. The original local cause was not recorded.",
  controller_release: "An explicit controller release closed incomplete preparation.",
  caller_closed: "The owner explicitly closed capture without a complete transcript.",
  preparation_failure:
    "The accepted request failed preparation before an effect intent or external dispatch.",
} as const;

export function CaptureFailure({ value: f }: { value: NonNullable<HttpResponse["failure"]> }) {
  return (
    <section aria-label={`Capture failure for exchange ${f.exchange}`}>
      <h3>Exchange {f.exchange} · capture closed</h3>
      <p>{explanation[f.reason]}</p>
      {f.cause && (
        <p>
          Original cause: <code>{f.cause}</code>
          {f.cause_truncated && " (truncated)"}.
        </p>
      )}
      <dl>
        <dt>Original phase / closure input</dt>
        <dd>
          {f.phase} / {f.input}
        </dd>
        <dt>Retained prefix</dt>
        <dd>
          {f.segments} segments / {f.bytes} bytes
        </dd>
        <dt>Native effect / attempt at capture closure</dt>
        <dd>{f.effect ? `${f.effect} / ${f.attempt}` : "Not bound"}</dd>
        {f.reason === "preparation_failure" && (
          <>
            <dt>Original request input</dt>
            <dd>{f.origin_input}</dd>
          </>
        )}
        {f.reason === "capture_failure" && (
          <>
            <dt>Capture operation / member / chunk</dt>
            <dd>
              {f.operation === "none" ? "Not recorded" : f.operation} /{" "}
              {f.operation === "begin" || f.operation === "append" || f.operation === "seal"
                ? f.member
                : "Not recorded"}{" "}
              / {f.operation === "append" ? f.chunk : "Not applicable"}
            </dd>
            <dt>Requested bytes / original operation input</dt>
            <dd>
              {f.operation === "begin" || f.operation === "append"
                ? f.requested_bytes
                : "Not recorded"}{" "}
              / {f.origin_input || "Not recorded"}
            </dd>
          </>
        )}
      </dl>
      <p>
        {f.reason === "preparation_failure"
          ? "Inspect the original preparation diagnostic to correct the failing request or policy field."
          : "Inspect native effect settlement and the recorded connector policy before further work. Capture closure does not establish a remote outcome or make another send safe."}
      </p>
    </section>
  );
}
