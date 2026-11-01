# 33. Recorded outbound MCP and application guidance

[Roadmap](README.md) · **Status:** Planned

Let applications use selected external MCP capabilities as governed observations
or effects, and publish reviewed instructions explaining their own resources.
Retain what an investigation actually used without redispatching external tools
during replay. An external MCP endpoint is not automatically a trusted data source.

## Prerequisites and scope

Reuse the existing [connector intent/capture boundary](../handbook/reference/connectors.md),
[access/delegation contract](27-control-and-policy-plane.md),
[published resources](28-published-resources-and-investigations.md) and the
selected [MCP protocol implementation](31-mcp-service-and-apps.md).
[Reactive activation](32-reactive-context-and-agent-activation.md) supplies triggers
where needed; finite explicit calls can be qualified independently.

The next [programming-model milestone](34-programming-model.md) makes recorded
capabilities and their outcomes usable from direct clients, Station behaviors
and mixed applications where the owning service contracts support them. This
connector milestone retains intent, capture, reconciliation and replay semantics;
language convenience cannot replace them with an unrecorded host tool call.

## Delivery sequence

1. **Publish selected external bindings.** Freeze server identity, qualified
   protocol/capability and schema commitments, typed arguments, credential
   references, destination/audience, budgets and capture/reconciliation policy.
   Tool discovery or a changed remote description cannot silently authorize new
   capabilities. Do not provide an unrestricted proxy to discovered tools or URLs.
2. **Record and authorize attempts.** Adapt the shared MCP client through the
   owning transport/exchange layer. Preserve original actor/delegation and intent
   across dispatch, additional input and selected task polling. Authentication
   renewal, status lookup and cancellation are external work under explicit
   policy, never hidden replay actions. Bind outbound credentials through
   catalog `SECRET` declarations (`TYPE oauth2_bearer`, `SCOPE`, `AUDIENCE` and
   `rotation_epoch` in [Milestone 27](27-control-and-policy-plane.md)), where
   OAuth 2.1 + PKCE or RFC 8693 challenge-response and lease-refresh dataflows
   seal refreshed tokens into the secret vault and wake `Suspended
   (CredentialPending)` tasks without forwarding raw inbound caller tokens
   indiscriminately.
3. **Capture evidence with honest coverage.** Retain permitted request/response
   bytes, protocol and business outcomes, timing/basis and omitted fields.
   Redacted capture does not claim byte completeness. Replay consumes authorized
   records without network I/O. Lost replies remain unknown unless a selected
   remote idempotency/status contract establishes the original outcome.
4. **Publish typed observations through resource owners.** Validate captured
   output against its interpretation before making it queryable. A remote URI
   alone is not a snapshot; the connector does not invent upstream CDC, causal
   consistency or freshness. Branching captured data does not isolate future
   external writes. Keep observed facts, computed values and model judgments
   distinct, with provenance governed by current disclosure policy.
5. **Offer reviewed application guidance.** Optionally publish prompts and skills
   associated with exact resource/application definitions. Select and test host
   support before advertising extensions. Instructions help users interpret and
   combine capabilities; they cannot confer privileges, supply approval or
   override tool policy. Keep guidance independent of executable authorization.

## Formal model follow-through

Reassess the [recorded-effect boundary](22-formal-semantics-and-correspondence.md#t4-transaction-decisions-isolation-and-atomic-outbox-publication)
for the selected outbound contract. Model authorized attempts, possible remote
execution without durable observation, capture, reconciliation and closure.
Connect selected checks to production recovery and network-free replay, retaining
unknown outcomes and explicit deferrals. Atomic intent publication and request
identity alone establish neither remote rollback nor at-most-once execution.

## Completion evidence

Use an independent MCP peer with changed schemas, malicious descriptions,
partial replies, duplicate requests, uncertain mutations and selected long-task
behavior. Kill/replace the connector after dispatch and prove replay sends no
network requests. Exercise secret omission, wrong destination, revocation during
capture/read, unavailable reconciliation and bounded retained payloads. Record
exact peer versions and supported profiles.

An investigation must be able to cite the captured observation it used after
the external service changes. This establishes attributable input evidence,
not the truth of external data or reproducibility of a model's conclusion.

Where a workflow promises consequence tracking, qualify a later external
observation against the original action and the declared business question.
Distinguish tool completion from the observed business consequence, and retain
missing or conflicting observations. Apply the shared
[observation measures](42-qualification-and-benchmarks.md#observation-and-consequence-evidence);
record correlation without treating it as proof of causal impact.

See the [Skills extension](https://modelcontextprotocol.io/extensions/skills/overview)
for an optional guidance-discovery binding, separate from Transit execution.
