import { httpMetadata } from "@rey/transit-board-client";
import { useMetadata } from "./use-metadata";

export function HttpMetadata({ resource, exchange }: { resource: number; exchange: string }) {
  const { page, error } = useMetadata(resource, exchange, httpMetadata);
  const policy = page?.policy;
  const terminal = page?.terminal;
  return (
    <section aria-label={`HTTP metadata for exchange ${exchange}`}>
      <h3>HTTP metadata · exchange {exchange}</h3>
      <p role="status">
        {error ||
          (page
            ? `Resource revision ${page.source.resource_revision} · authority position ${page.source.position}`
            : "Reading authorized metadata…")}
      </p>
      {page && (
        <>
          <p>
            Selected metadata digests are verified. Body contents and the full transcript are not
            loaded.
          </p>
          {policy ? (
            <dl>
              <dt>Endpoint policy revision</dt>
              <dd>{policy.endpoint_revision}</dd>
              <dt>Method / TLS</dt>
              <dd>
                {policy.method} / {policy.tls ? "Required" : "Disabled"}
              </dd>
              <dt>Frozen timeout (ms)</dt>
              <dd>{policy.timeout_ms}</dd>
              <dt>Request / response byte limits</dt>
              <dd>
                {policy.request_bytes} / {policy.response_bytes}
              </dd>
              <dt>Trust bundle digest</dt>
              <dd>
                {policy.trust_digest ? (
                  <code>
                    {policy.trust_digest.map((byte) => byte.toString(16).padStart(2, "0")).join("")}
                  </code>
                ) : (
                  "Not configured"
                )}
              </dd>
              {(["retry", "redirect", "reconcile", "cancel"] as const).map((reason) => (
                <div key={reason}>
                  <dt>{reason} policy / revision</dt>
                  <dd>
                    {policy[reason]
                      ? `${policy[reason].id} / ${policy[reason].revision}`
                      : "Not granted"}
                  </dd>
                </div>
              ))}
            </dl>
          ) : (
            <p>Request policy has not been captured.</p>
          )}
          {terminal ? (
            <dl>
              <dt>Attempt started (Unix ms)</dt>
              <dd>{terminal.timing.started_ms}</dd>
              <dt>Elapsed time (ns)</dt>
              <dd>{terminal.timing.elapsed_ns}</dd>
              <dt>Omitted response headers</dt>
              <dd>{terminal.omission.response_headers}</dd>
              <dt>Omitted request secrets</dt>
              <dd>{terminal.omission.request_secrets}</dd>
              <dt>HTTP status / framing</dt>
              <dd>
                {terminal.completion.status} / {terminal.completion.framing}
              </dd>
              <dt>Request / response body byte counts</dt>
              <dd>
                {terminal.completion.request_bytes} / {terminal.completion.response_bytes}
              </dd>
            </dl>
          ) : (
            <p>Timing and terminal metadata are unavailable for this incomplete capture.</p>
          )}
          <p>
            Omissions are capture gaps. HTTP completion does not establish remote business success
            or cancellation.
          </p>
          <details>
            <summary>Metadata source records</summary>
            <p>
              Writer PID {page.source.pid}; descriptor revision {page.source.entry_revision}.
            </p>
            {[
              policy?.member,
              terminal?.timing.member,
              terminal?.omission.member,
              terminal?.completion.member,
            ].map(
              (member) =>
                member && (
                  <p key={member.key}>
                    {member.kind} · member {member.ordinal} · <code>{member.key}</code>
                  </p>
                ),
            )}
          </details>
        </>
      )}
    </section>
  );
}
