import { CaptureFailure } from "./capture-failure";
import { grpcMetadata } from "@rey/transit-board-client";
import { useMetadata } from "./use-metadata";
const hex = (bytes: readonly number[]) =>
  bytes.map((byte) => byte.toString(16).padStart(2, "0")).join("");
export function GrpcMetadata({ resource, exchange }: { resource: number; exchange: string }) {
  const { page, error } = useMetadata(resource, exchange, grpcMetadata);
  const policy = page?.policy,
    terminal = page?.terminal;
  return (
    <section aria-label={`RPC metadata for exchange ${exchange}`}>
      <h3>RPC metadata · exchange {exchange}</h3>
      <p role="status">
        {error ||
          (page
            ? `Resource revision ${page.source.resource_revision} · authority position ${page.source.position}`
            : "Reading authorized metadata…")}
      </p>
      {page && (
        <>
          <p>
            Member commitments and selected metadata digests are verified. Protobuf bodies are not
            loaded. Indexed message records in a partial capture may lack complete bodies.
          </p>
          {page.failure && <CaptureFailure value={page.failure} />}
          {policy ? (
            <dl>
              <dt>Method shape / TLS</dt>
              <dd>
                {policy.shape} / {policy.tls ? "Required" : "Disabled"}
              </dd>
              <dt>Descriptor digest</dt>
              <dd>
                <code>{hex(policy.descriptor_digest)}</code>
              </dd>
              <dt>Endpoint policy revision / timeout (ms)</dt>
              <dd>
                {policy.endpoint_revision} / {policy.timeout_ms}
              </dd>
              <dt>Outgoing / incoming message limits</dt>
              <dd>
                {policy.limits.request_messages} / {policy.limits.response_messages}
              </dd>
              <dt>Outgoing / incoming framed byte limits</dt>
              <dd>
                {policy.limits.request_bytes} / {policy.limits.response_bytes}
              </dd>
              <dt>Trust bundle digest</dt>
              <dd>
                {policy.trust_digest ? <code>{hex(policy.trust_digest)}</code> : "Not configured"}
              </dd>
              <dt>Retry policy / revision</dt>
              <dd>
                {policy.retry ? `${policy.retry.id} / ${policy.retry.revision}` : "Not granted"}
              </dd>
            </dl>
          ) : (
            <p>Endpoint policy has not been captured.</p>
          )}
          <dl>
            <dt>Outgoing half-close</dt>
            <dd>
              {page.half_close
                ? `${page.half_close.messages} messages / ${page.half_close.wire_bytes} framed bytes`
                : "Not captured"}
            </dd>
            <dt>Incoming indexed message records / body bytes</dt>
            <dd>
              {page.response_message_records} / {page.response_body_bytes}
            </dd>
            <dt>Coverage commitment</dt>
            <dd>
              <code>{hex(page.coverage)}</code>
            </dd>
          </dl>
          {terminal ? (
            <dl>
              <dt>RPC status</dt>
              <dd>{terminal.completion.status}</dd>
              <dt>Sent / received messages</dt>
              <dd>
                {terminal.completion.sent_messages} / {terminal.completion.received_messages}
              </dd>
              <dt>Sent / received framed bytes</dt>
              <dd>
                {terminal.completion.sent_bytes} / {terminal.completion.received_bytes}
              </dd>
              <dt>Attempt started (Unix ms) / elapsed (ns)</dt>
              <dd>
                {terminal.timing.started_ms} / {terminal.timing.elapsed_ns}
              </dd>
              <dt>Omitted response fields / request secrets</dt>
              <dd>
                {terminal.omission.response_fields} / {terminal.omission.request_secrets}
              </dd>
            </dl>
          ) : (
            <p>No complete terminal capture is available.</p>
          )}
          <p>
            Half-close and transport status do not establish remote durable handling, business
            success or rollback. Partial capture preserves uncertainty.
          </p>
          <details>
            <summary>Metadata source records</summary>
            <p>
              Writer PID {page.source.pid}; descriptor revision {page.source.entry_revision}.
            </p>
            {[
              policy?.member,
              page.half_close?.member,
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
